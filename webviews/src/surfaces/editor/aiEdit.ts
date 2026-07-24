import { getChunks, unifiedMergeView } from "@codemirror/merge";
import { Compartment, EditorState, StateEffect, StateField, type Extension } from "@codemirror/state";
import { EditorView, keymap, showPanel, type Panel } from "@codemirror/view";
import { callNative } from "./bridge";

/**
 * Edit Selection (Mod-k): an instruction panel that sends the current
 * selection to the native `ai.editSelection` bridge and reviews the rewrite
 * inline via `unifiedMergeView` — the proposed text lands in the buffer with
 * per-chunk Accept/Reject controls, and the merge chrome tears itself down
 * once every chunk is resolved.
 *
 * All user-facing strings arrive localized from Swift through the editor
 * copy payload; nothing here hardcodes English at render time.
 */

export type AIEditCopy = {
  instructionPlaceholder: string;
  apply: string;
  cancel: string;
  working: string;
  selectFirst: string;
  accept: string;
  reject: string;
};

type AIEditReply = {
  content?: string;
  errorMessage?: string;
  cancelled?: boolean;
};

const setPanelOpen = StateEffect.define<boolean>();

export function aiEditFeature(options: {
  copy: AIEditCopy;
  language: () => string;
}): Extension {
  const { copy } = options;
  const mergeCompartment = new Compartment();
  let mergeActive = false;
  let requestToken = 0;

  const panelField = StateField.define<boolean>({
    create: () => false,
    update(value, transaction) {
      let next = value;
      for (const effect of transaction.effects) {
        if (effect.is(setPanelOpen)) {
          next = effect.value;
        }
      }
      return next;
    },
    provide: (field) => showPanel.from(field, (open) => (open ? createPanel : null)),
  });

  function applyProposal(view: EditorView, from: number, to: number, content: string): void {
    const original = view.state.doc.toString();
    view.dispatch({
      changes: { from, to, insert: content },
      selection: { anchor: from },
    });
    mergeActive = true;
    view.dispatch({
      effects: [
        mergeCompartment.reconfigure(unifiedMergeView({ original, mergeControls: true })),
        setPanelOpen.of(false),
      ],
    });
    view.focus();
  }

  function createPanel(view: EditorView): Panel {
    const dom = document.createElement("div");
    dom.className = "cmux-ai-edit-panel";

    const input = document.createElement("input");
    input.className = "cm-textfield";
    input.placeholder = copy.instructionPlaceholder;

    const applyButton = document.createElement("button");
    applyButton.type = "button";
    applyButton.className = "cm-button";
    applyButton.textContent = copy.apply;

    const cancelButton = document.createElement("button");
    cancelButton.type = "button";
    cancelButton.className = "cm-button";
    cancelButton.textContent = copy.cancel;

    const status = document.createElement("span");
    status.className = "cmux-ai-edit-status";

    let busy = false;

    function close(): void {
      requestToken += 1;
      view.dispatch({ effects: setPanelOpen.of(false) });
      view.focus();
    }

    function submit(): void {
      if (busy) {
        return;
      }
      const instruction = input.value.trim();
      if (instruction === "") {
        input.focus();
        return;
      }
      const selection = view.state.selection.main;
      if (selection.empty) {
        status.textContent = copy.selectFirst;
        return;
      }
      busy = true;
      requestToken += 1;
      const token = requestToken;
      status.textContent = copy.working;
      input.disabled = true;
      applyButton.disabled = true;
      callNative<AIEditReply>("ai.editSelection", {
        selection: view.state.sliceDoc(selection.from, selection.to),
        instruction,
        language: options.language(),
      })
        .then((reply) => {
          if (token !== requestToken) {
            return;
          }
          busy = false;
          input.disabled = false;
          applyButton.disabled = false;
          if (reply.cancelled) {
            return;
          }
          if (reply.errorMessage != null || reply.content == null) {
            status.textContent = reply.errorMessage ?? copy.selectFirst;
            return;
          }
          applyProposal(view, selection.from, selection.to, reply.content);
        })
        .catch((error: unknown) => {
          if (token !== requestToken) {
            return;
          }
          busy = false;
          input.disabled = false;
          applyButton.disabled = false;
          status.textContent = error instanceof Error ? error.message : String(error);
        });
    }

    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        submit();
      } else if (event.key === "Escape") {
        event.preventDefault();
        close();
      }
    });
    applyButton.addEventListener("click", submit);
    cancelButton.addEventListener("click", close);

    dom.append(input, applyButton, cancelButton, status);
    return {
      dom,
      top: true,
      mount: () => input.focus(),
    };
  }

  return [
    mergeCompartment.of([]),
    panelField,
    // The merge package labels its chunk buttons via CM phrases.
    EditorState.phrases.of({ Accept: copy.accept, Reject: copy.reject }),
    keymap.of([
      {
        key: "Mod-k",
        run: (view) => {
          view.dispatch({ effects: setPanelOpen.of(true) });
          return true;
        },
      },
    ]),
    EditorView.updateListener.of((update) => {
      if (!mergeActive) {
        return;
      }
      const chunks = getChunks(update.state);
      if (chunks != null && chunks.chunks.length === 0) {
        mergeActive = false;
        // Reconfiguring dispatches a transaction; defer it out of the
        // current update cycle.
        queueMicrotask(() => {
          update.view.dispatch({ effects: mergeCompartment.reconfigure([]) });
        });
      }
    }),
  ];
}
