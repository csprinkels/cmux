import { Prec, StateEffect, StateField, type Extension } from "@codemirror/state";
import { Decoration, EditorView, ViewPlugin, WidgetType, keymap, type DecorationSet } from "@codemirror/view";
import { callNative } from "./bridge";

/**
 * Inline ghost-text autocomplete.
 *
 * Typing schedules a debounced `ai.complete` request; the reply renders as a
 * dimmed widget after the cursor until Tab accepts it or any edit/cursor move
 * dismisses it. Requests are single-flight through a generation counter — a
 * newer keystroke invalidates in-flight replies rather than racing them into
 * the buffer.
 *
 * When the feature is disabled the plugin never schedules a request, so a
 * disabled editor issues zero network traffic.
 */

/** Context caps: enough signal for a completion, bounded for latency. */
const MAX_PREFIX_BYTES = 2048;
const MAX_SUFFIX_BYTES = 1024;
const DEBOUNCE_MS = 300;

type Suggestion = { from: number; text: string };

type CompletionReply = {
  text?: string;
  cancelled?: boolean;
};

const setSuggestion = StateEffect.define<Suggestion | null>();

class GhostTextWidget extends WidgetType {
  constructor(private readonly text: string) {
    super();
  }

  override eq(other: GhostTextWidget): boolean {
    return other.text === this.text;
  }

  override toDOM(): HTMLElement {
    const wrapper = document.createElement("span");
    wrapper.className = "cmux-ghost-text";
    // Multi-line suggestions keep their newlines: render each line in its own
    // block so the widget grows downward instead of running off the line.
    const lines = this.text.split("\n");
    lines.forEach((line, index) => {
      if (index > 0) {
        wrapper.append(document.createElement("br"));
      }
      wrapper.append(document.createTextNode(line));
    });
    return wrapper;
  }

  override get estimatedHeight(): number {
    return -1;
  }

  override ignoreEvent(): boolean {
    return false;
  }
}

const suggestionField = StateField.define<Suggestion | null>({
  create: () => null,
  update(value, transaction) {
    let next = value;
    for (const effect of transaction.effects) {
      if (effect.is(setSuggestion)) {
        next = effect.value;
      }
    }
    if (next == null) {
      return null;
    }
    // Any document change or cursor move that did not just install this
    // suggestion invalidates it.
    const installed = transaction.effects.some((effect) => effect.is(setSuggestion));
    if (!installed && (transaction.docChanged || transaction.selection != null)) {
      return null;
    }
    if (next.from !== transaction.state.selection.main.head) {
      return null;
    }
    return next;
  },
  provide: (field) =>
    EditorView.decorations.from(field, (suggestion) => {
      if (suggestion == null || suggestion.text === "") {
        return Decoration.none;
      }
      return Decoration.set([
        Decoration.widget({
          widget: new GhostTextWidget(suggestion.text),
          side: 1,
        }).range(suggestion.from),
      ]) as DecorationSet;
    }),
});

/** The suggestion currently shown, if any. Exported for tests. */
export function currentSuggestion(view: EditorView): Suggestion | null {
  return view.state.field(suggestionField, false) ?? null;
}

/**
 * Whether the cursor sits somewhere a completion makes sense: a collapsed
 * selection with only whitespace or a closing delimiter to its right.
 * Completing mid-word or mid-expression produces noise.
 */
export function isCompletionPosition(lineTextAfterCursor: string): boolean {
  return /^[\s)\]}>,;'"`]*$/.test(lineTextAfterCursor);
}

/** Clips text to a byte budget, keeping the end (prefix) or start (suffix). */
export function clipContext(text: string, maxBytes: number, keep: "end" | "start"): string {
  if (new TextEncoder().encode(text).length <= maxBytes) {
    return text;
  }
  // Character-wise walk keeps the slice valid UTF-16 (no split surrogates).
  const characters = Array.from(text);
  let bytes = 0;
  const kept: string[] = [];
  const ordered = keep === "end" ? characters.reverse() : characters;
  for (const character of ordered) {
    const size = new TextEncoder().encode(character).length;
    if (bytes + size > maxBytes) {
      break;
    }
    bytes += size;
    kept.push(character);
  }
  return keep === "end" ? kept.reverse().join("") : kept.join("");
}

export function ghostTextFeature(options: {
  isEnabled: () => boolean;
  language: () => string;
  path: () => string;
}): Extension {
  const plugin = ViewPlugin.fromClass(
    class {
      private timer: ReturnType<typeof setTimeout> | null = null;
      private generation = 0;

      constructor(private readonly view: EditorView) {}

      update(update: { docChanged: boolean; selectionSet: boolean; view: EditorView }): void {
        if (!update.docChanged && !update.selectionSet) {
          return;
        }
        // Every edit invalidates in-flight work; only typing re-arms.
        this.generation += 1;
        this.cancelTimer();
        if (!update.docChanged || !options.isEnabled()) {
          return;
        }
        this.timer = setTimeout(() => {
          this.timer = null;
          void this.request();
        }, DEBOUNCE_MS);
      }

      destroy(): void {
        this.cancelTimer();
        this.generation += 1;
      }

      private cancelTimer(): void {
        if (this.timer != null) {
          clearTimeout(this.timer);
          this.timer = null;
        }
      }

      private async request(): Promise<void> {
        const state = this.view.state;
        const cursor = state.selection.main;
        if (!cursor.empty || !options.isEnabled()) {
          return;
        }
        const line = state.doc.lineAt(cursor.head);
        if (!isCompletionPosition(state.sliceDoc(cursor.head, line.to))) {
          return;
        }
        const generation = this.generation;
        const prefix = clipContext(state.sliceDoc(0, cursor.head), MAX_PREFIX_BYTES, "end");
        const suffix = clipContext(
          state.sliceDoc(cursor.head, state.doc.length),
          MAX_SUFFIX_BYTES,
          "start",
        );
        try {
          const reply = await callNative<CompletionReply>("ai.complete", {
            prefix,
            suffix,
            path: options.path(),
            language: options.language(),
          });
          if (generation !== this.generation || reply.cancelled) {
            return;
          }
          const text = reply.text ?? "";
          if (text === "" || this.view.state.selection.main.head !== cursor.head) {
            return;
          }
          this.view.dispatch({ effects: setSuggestion.of({ from: cursor.head, text }) });
        } catch {
          // A failed completion is not worth interrupting typing over; the
          // next keystroke simply tries again.
        }
      }
    },
  );

  return [
    suggestionField,
    plugin,
    // Higher precedence than indentWithTab so Tab accepts a visible
    // suggestion; with none showing, Tab falls through to indentation.
    Prec.highest(
      keymap.of([
        {
          key: "Tab",
          run: (view) => {
            const suggestion = view.state.field(suggestionField, false);
            if (suggestion == null || suggestion.text === "") {
              return false;
            }
            view.dispatch({
              changes: { from: suggestion.from, insert: suggestion.text },
              selection: { anchor: suggestion.from + suggestion.text.length },
              effects: setSuggestion.of(null),
            });
            return true;
          },
        },
        {
          key: "Escape",
          run: (view) => {
            const suggestion = view.state.field(suggestionField, false);
            if (suggestion == null) {
              return false;
            }
            view.dispatch({ effects: setSuggestion.of(null) });
            return true;
          },
        },
      ]),
    ),
  ];
}
