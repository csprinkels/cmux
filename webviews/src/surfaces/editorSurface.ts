/**
 * CodeMirror 6 code editor surface, hosted by `CodeEditorWebRenderer` on the
 * Swift side (FilePreview panels with `fileEditor.engine = "code"`).
 *
 * The webview owns the live buffer; Swift owns file IO. Swift pushes disk
 * changes and theme/option updates through `window.cmuxEditorBridge.receive`,
 * pulls the buffer via `window.cmuxEditorHost.getContent()`, and receives
 * debounced dirty-state changes plus Cmd+S saves over the `cmuxEditor` bridge.
 */
import { closeBrackets, closeBracketsKeymap } from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap, indentWithTab } from "@codemirror/commands";
import {
  LanguageDescription,
  bracketMatching,
  defaultHighlightStyle,
  foldGutter,
  foldKeymap,
  indentOnInput,
  syntaxHighlighting,
} from "@codemirror/language";
import { languages } from "@codemirror/language-data";
import { highlightSelectionMatches, search, searchKeymap } from "@codemirror/search";
import { Compartment, EditorState } from "@codemirror/state";
import {
  EditorView,
  drawSelection,
  dropCursor,
  highlightActiveLine,
  highlightActiveLineGutter,
  highlightSpecialChars,
  keymap,
  lineNumbers,
} from "@codemirror/view";
import { oneDarkHighlightStyle } from "@codemirror/theme-one-dark";
import { installWebviewStyles } from "./installWebviewStyles";
import {
  callNative,
  subscribeToHostEvents,
  type EditorCopy,
  type EditorReadyReply,
  type EditorTheme,
} from "./editor/bridge";
import { aiEditFeature } from "./editor/aiEdit";
import { DocumentSession } from "./editor/documentSession";
import { hasUsableTerminalPalette, terminalHighlightStyle } from "./editor/terminalHighlight";

const DIRTY_NOTIFY_DEBOUNCE_MS = 100;

// Chrome inside the webview (banner, search panel) follows the native cmux
// vocabulary: 11px system labels, borderless pill buttons that fill on hover
// (Color.primary at 5-14% in AppKit; color-mix on --cmux-editor-fg here),
// 5px radii, hairline separators. See RightSidebarChromeStyle.swift and
// PanelContentView.swift for the AppKit reference values.
const surfaceStyles = `
  * {
    box-sizing: border-box;
  }
  html, body {
    margin: 0;
    height: 100%;
    background: transparent;
    overscroll-behavior: none;
  }
  #root {
    display: flex;
    flex-direction: column;
    height: 100%;
  }
  button, input {
    font: inherit;
  }
  button {
    cursor: default;
  }
  .cmux-editor-banner {
    display: none;
    align-items: center;
    gap: 8px;
    min-height: 30px;
    padding: 4px 12px;
    font: 11px -apple-system, system-ui, sans-serif;
    color: var(--cmux-editor-fg, #000);
    background: var(--cmux-editor-surface, rgba(127, 127, 127, 0.15));
    border-bottom: 1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25));
  }
  .cmux-editor-banner.cmux-editor-banner-visible {
    display: flex;
  }
  .cmux-editor-banner-message {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .cmux-editor-banner-error {
    background: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 11%, transparent);
    border-bottom-color: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 46%, transparent);
  }
  .cmux-editor-banner-error .cmux-editor-banner-message {
    color: color-mix(in srgb, var(--cmux-editor-danger, #b3261e) 88%, var(--cmux-editor-fg, #000));
  }
  .cmux-editor-banner button {
    font: inherit;
    padding: 3px 10px;
    border-radius: 5px;
    border: none;
    background: transparent;
    color: var(--cmux-editor-fg, #000);
  }
  .cmux-editor-banner button:hover {
    background: color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent);
  }
  .cmux-editor-banner button:active {
    background: color-mix(in srgb, var(--cmux-editor-fg, currentColor) 14%, transparent);
  }
  .cmux-editor-banner button.cmux-editor-banner-primary {
    background: var(--cmux-editor-accent-soft, rgba(127, 127, 127, 0.18));
    color: var(--cmux-editor-fg, #000);
  }
  .cmux-editor-banner button.cmux-editor-banner-primary:hover {
    background: color-mix(in srgb, var(--cmux-editor-accent, currentColor) 30%, transparent);
  }
  .cmux-editor-banner button:focus-visible {
    outline: 2px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 36%, transparent);
    outline-offset: 1px;
  }
  .cmux-editor-container {
    flex: 1;
    min-height: 0;
  }
  .cmux-editor-container .cm-editor {
    height: 100%;
  }
`;

const editorChrome = EditorView.theme({
  "&": {
    backgroundColor: "var(--cmux-editor-bg, transparent)",
    color: "var(--cmux-editor-fg, inherit)",
    fontSize: "var(--cmux-editor-font-size, 12px)",
  },
  "&.cm-focused": {
    outline: "none",
  },
  ".cm-scroller": {
    fontFamily: "var(--cmux-editor-font-family, ui-monospace, 'SF Mono', Menlo, monospace)",
    lineHeight: "1.5",
    scrollbarWidth: "thin",
    scrollbarColor: "color-mix(in srgb, var(--cmux-editor-muted, currentColor) 28%, transparent) transparent",
  },
  ".cm-content": {
    caretColor: "var(--cmux-editor-caret, var(--cmux-editor-fg, auto))",
  },
  ".cm-gutters": {
    backgroundColor: "transparent",
    color: "var(--cmux-editor-muted, inherit)",
    border: "none",
  },
  ".cm-activeLineGutter": {
    backgroundColor: "transparent",
    color: "var(--cmux-editor-fg, inherit)",
  },
  ".cm-activeLine": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 5%, transparent)",
  },
  "&.cm-focused .cm-cursor": {
    borderLeftColor: "var(--cmux-editor-caret, var(--cmux-editor-fg, auto))",
  },
  "&.cm-focused > .cm-scroller .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, & ::selection": {
    backgroundColor: "var(--cmux-editor-selection, var(--cmux-editor-accent-soft, rgba(0, 122, 255, 0.2))) !important",
  },
  ".cm-selectionMatch": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 12%, transparent)",
  },
  ".cm-searchMatch": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-accent, currentColor) 25%, transparent)",
  },
  ".cm-searchMatch.cm-searchMatch-selected": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-accent, currentColor) 45%, transparent)",
    outline: "1px solid var(--cmux-editor-accent, currentColor)",
  },
  "&.cm-focused .cm-matchingBracket": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 15%, transparent)",
    outline: "1px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 30%, transparent)",
  },
  "&.cm-focused .cm-nonmatchingBracket": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-danger, currentColor) 30%, transparent)",
  },
  ".cm-foldPlaceholder": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 10%, transparent)",
    border: "1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",
    color: "var(--cmux-editor-muted, inherit)",
    borderRadius: "4px",
    padding: "0 4px",
  },
  ".cmux-ai-edit-panel": {
    display: "flex",
    alignItems: "center",
    gap: "6px",
    padding: "4px 8px",
  },
  ".cmux-ai-edit-panel .cm-textfield": {
    flex: "1",
    minWidth: "120px",
  },
  ".cmux-ai-edit-status": {
    color: "var(--cmux-editor-muted, inherit)",
    fontSize: "11px",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  },
  ".cm-deletedChunk": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-danger, #c0392b) 12%, transparent)",
  },
  ".cm-deletedChunk .cm-deletedText": {
    textDecoration: "line-through",
    textDecorationColor: "color-mix(in srgb, var(--cmux-editor-danger, #c0392b) 60%, transparent)",
  },
  ".cm-changedLine": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-accent, currentColor) 8%, transparent)",
  },
  ".cm-changedText": {
    background: "color-mix(in srgb, var(--cmux-editor-accent, currentColor) 20%, transparent)",
  },
  ".cm-chunkButtons button": {
    border: "none",
    borderRadius: "5px",
    padding: "1px 8px",
    margin: "0 2px",
    font: "500 10px -apple-system, system-ui, sans-serif",
    background: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 10%, transparent)",
    color: "var(--cmux-editor-fg, inherit)",
    cursor: "default",
  },
  ".cm-chunkButtons button[name=accept]": {
    background: "var(--cmux-editor-accent, #3478f6)",
    color: "#fff",
  },
  ".cm-foldGutter span": {
    opacity: "0",
    transition: "opacity 0.1s",
  },
  ".cm-gutters:hover .cm-foldGutter span": {
    opacity: "1",
  },
  ".cm-dropCursor": {
    borderLeftColor: "var(--cmux-editor-caret, var(--cmux-editor-fg, currentColor))",
  },
  ".cm-specialChar": {
    color: "var(--cmux-editor-danger, inherit)",
  },
  // Panels (search, go-to-line) are chrome, not code: native 11px UI font,
  // borderless pill buttons, hairline separators.
  ".cm-panels": {
    backgroundColor: "var(--cmux-editor-panel, Canvas)",
    color: "var(--cmux-editor-fg, inherit)",
    border: "none",
    font: "11px -apple-system, system-ui, sans-serif",
  },
  ".cm-panels.cm-panels-top": {
    borderBottom: "1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",
  },
  ".cm-panels.cm-panels-bottom": {
    borderTop: "1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",
  },
  ".cm-panel.cm-search": {
    padding: "5px 12px 6px 8px",
  },
  ".cm-panels .cm-textfield": {
    backgroundColor: "var(--cmux-editor-input, color-mix(in srgb, var(--cmux-editor-fg, currentColor) 7%, transparent))",
    border: "1px solid var(--cmux-editor-border, rgba(127, 127, 127, 0.25))",
    borderRadius: "5px",
    padding: "3px 8px",
    color: "var(--cmux-editor-fg, inherit)",
    font: "inherit",
    outline: "none",
  },
  ".cm-panels .cm-textfield:focus": {
    borderColor: "color-mix(in srgb, var(--cmux-editor-accent, currentColor) 60%, var(--cmux-editor-border, transparent))",
  },
  ".cm-panels .cm-textfield::placeholder": {
    color: "var(--cmux-editor-muted, inherit)",
  },
  ".cm-panels .cm-button": {
    backgroundImage: "none",
    backgroundColor: "transparent",
    border: "none",
    borderRadius: "5px",
    padding: "3px 10px",
    color: "var(--cmux-editor-fg, inherit)",
    font: "inherit",
  },
  ".cm-panels .cm-button:hover": {
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent)",
  },
  ".cm-panels .cm-button:active": {
    backgroundImage: "none",
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 14%, transparent)",
  },
  ".cm-panels .cm-button:focus-visible, .cm-panels input[type=checkbox]:focus-visible": {
    outline: "2px solid color-mix(in srgb, var(--cmux-editor-fg, currentColor) 36%, transparent)",
    outlineOffset: "1px",
  },
  ".cm-panel.cm-search label": {
    color: "var(--cmux-editor-muted, inherit)",
    fontSize: "inherit",
  },
  ".cm-panel.cm-search input[type=checkbox]": {
    accentColor: "var(--cmux-editor-accent, auto)",
  },
  ".cm-panel.cm-search button[name=close]": {
    color: "var(--cmux-editor-muted, inherit)",
    fontSize: "14px",
    width: "20px",
    height: "20px",
    lineHeight: "20px",
    borderRadius: "5px",
    top: "4px",
    right: "6px",
  },
  ".cm-panel.cm-search button[name=close]:hover": {
    color: "var(--cmux-editor-fg, inherit)",
    backgroundColor: "color-mix(in srgb, var(--cmux-editor-fg, currentColor) 8%, transparent)",
  },
});

function applyThemeVariables(theme: EditorTheme): void {
  const style = document.documentElement.style;
  const terminal = hasUsableTerminalPalette(theme.terminal) ? theme.terminal : null;
  // Terminal-themed mode: the Swift host already paints the Ghostty
  // background (opacity-aware) behind the webview, so the page goes
  // transparent and text/caret/selection take the terminal's colors.
  style.setProperty("--cmux-editor-bg", terminal ? "transparent" : theme.pageBackground);
  style.setProperty("--cmux-editor-fg", terminal ? terminal.foreground : theme.text);
  style.setProperty("--cmux-editor-muted", theme.mutedText);
  style.setProperty("--cmux-editor-accent", theme.accent);
  style.setProperty("--cmux-editor-accent-soft", theme.accentSoft);
  style.setProperty("--cmux-editor-border", theme.border);
  style.setProperty("--cmux-editor-surface", theme.surfaceBackground);
  style.setProperty("--cmux-editor-panel", theme.surfaceElevatedBackground);
  style.setProperty("--cmux-editor-input", theme.inputBackground);
  style.setProperty("--cmux-editor-danger", theme.danger);
  setOrClear(style, "--cmux-editor-caret", terminal?.cursorColor || null);
  setOrClear(style, "--cmux-editor-selection", terminal?.selectionBackground || null);
  setOrClear(
    style,
    "--cmux-editor-font-family",
    terminal?.fontFamily
      ? `"${terminal.fontFamily.replace(/"/g, '\\"')}", ui-monospace, 'SF Mono', Menlo, monospace`
      : null,
  );
  setOrClear(
    style,
    "--cmux-editor-font-size",
    terminal?.fontSize && terminal.fontSize > 0 ? `${terminal.fontSize}px` : null,
  );
  style.setProperty("color-scheme", theme.isDark ? "dark" : "light");
}

function setOrClear(style: CSSStyleDeclaration, name: string, value: string | null): void {
  if (value) {
    style.setProperty(name, value);
  } else {
    style.removeProperty(name);
  }
}

function themedExtensions(theme: EditorTheme) {
  const highlight = hasUsableTerminalPalette(theme.terminal)
    ? terminalHighlightStyle(theme.terminal)
    : theme.isDark
      ? oneDarkHighlightStyle
      : defaultHighlightStyle;
  return [editorChrome, syntaxHighlighting(highlight, { fallback: true })];
}

// CodeMirror's built-in UI phrases (search panel, go-to-line, fold
// placeholders) for non-English app locales, applied via EditorState.phrases.
const japanesePhrases: Record<string, string> = {
  // @codemirror/search
  "Find": "検索",
  "Replace": "置換",
  "next": "次へ",
  "previous": "前へ",
  "all": "すべて",
  "match case": "大文字と小文字を区別",
  "by word": "単語単位",
  "regexp": "正規表現",
  "replace": "置換",
  "replace all": "すべて置換",
  "close": "閉じる",
  "current match": "現在の一致",
  "replaced $ matches": "$ 件置換しました",
  "replaced match on line $": "$ 行目の一致を置換しました",
  "on line": "行",
  "Go to line": "行へ移動",
  "go": "移動",
  // @codemirror/language + @codemirror/view
  "Folded lines": "折りたたまれた行",
  "unfold": "展開",
  "Fold line": "行を折りたたむ",
  "Unfold line": "行を展開",
  "Control character": "制御文字",
  "Selection deleted": "選択範囲を削除しました"
};

function localePhrases(locale: string) {
  return locale.toLowerCase().startsWith("ja") ? [EditorState.phrases.of(japanesePhrases)] : [];
}

function wrapExtensions(wordWrap: boolean) {
  return wordWrap ? [EditorView.lineWrapping] : [];
}

interface Banner {
  show(kind: "conflict" | "error"): void;
  hide(): void;
  element: HTMLElement;
}

function makeBanner(copy: EditorCopy, onReload: () => void, onKeepMine: () => void): Banner {
  const element = document.createElement("div");
  element.className = "cmux-editor-banner";
  const message = document.createElement("span");
  message.className = "cmux-editor-banner-message";
  const reload = document.createElement("button");
  reload.className = "cmux-editor-banner-primary";
  reload.textContent = copy.reloadFromDisk;
  reload.addEventListener("click", onReload);
  const keep = document.createElement("button");
  keep.textContent = copy.keepMyChanges;
  keep.addEventListener("click", onKeepMine);
  element.append(message, reload, keep);
  return {
    element,
    show(kind) {
      const isConflict = kind === "conflict";
      message.textContent = isConflict ? copy.fileChangedOnDisk : copy.saveFailed;
      element.classList.toggle("cmux-editor-banner-error", !isConflict);
      reload.style.display = isConflict ? "" : "none";
      keep.style.display = isConflict ? "" : "none";
      element.classList.add("cmux-editor-banner-visible");
    },
    hide() {
      element.classList.remove("cmux-editor-banner-visible");
    },
  };
}

async function start(rootElement: HTMLElement): Promise<void> {
  const ready = await callNative<EditorReadyReply>("editor.ready");
  applyThemeVariables(ready.theme);
  installWebviewStyles("editor", surfaceStyles);

  const session = new DocumentSession(ready.diskContent);
  let currentLanguageName = "";
  const languageCompartment = new Compartment();
  const themeCompartment = new Compartment();
  const wrapCompartment = new Compartment();

  let lastNotifiedDirty = session.isDirty(ready.content);
  let dirtyNotifyTimer: ReturnType<typeof setTimeout> | null = null;
  let saveInFlight = false;

  const notifyDirtyIfChanged = () => {
    const isDirty = session.isDirty(view.state.doc.toString());
    if (isDirty === lastNotifiedDirty) {
      return;
    }
    lastNotifiedDirty = isDirty;
    void callNative("editor.dirtyChanged", { isDirty }).catch(() => {});
  };

  const scheduleDirtyNotify = () => {
    if (dirtyNotifyTimer !== null) {
      clearTimeout(dirtyNotifyTimer);
    }
    dirtyNotifyTimer = setTimeout(() => {
      dirtyNotifyTimer = null;
      notifyDirtyIfChanged();
    }, DIRTY_NOTIFY_DEBOUNCE_MS);
  };

  const replaceBuffer = (content: string) => {
    const previousSelection = view.state.selection.main.head;
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: content },
      selection: { anchor: Math.min(previousSelection, content.length) },
    });
  };

  const performSave = async (): Promise<void> => {
    if (saveInFlight) {
      return;
    }
    saveInFlight = true;
    const content = view.state.doc.toString();
    try {
      const reply = await callNative<{ saved: boolean }>("editor.save", { content });
      if (reply.saved) {
        session.noteSaved(content);
        banner.hide();
      } else {
        banner.show("error");
      }
    } catch {
      banner.show("error");
    } finally {
      saveInFlight = false;
      notifyDirtyIfChanged();
    }
  };

  const banner = makeBanner(
    ready.copy,
    () => {
      replaceBuffer(session.resolveConflictReload());
      banner.hide();
      notifyDirtyIfChanged();
      view.focus();
    },
    () => {
      session.resolveConflictKeepMine();
      banner.hide();
      notifyDirtyIfChanged();
      view.focus();
    },
  );

  const view = new EditorView({
    state: EditorState.create({
      doc: ready.content,
      extensions: [
        lineNumbers(),
        highlightActiveLineGutter(),
        highlightSpecialChars(),
        history(),
        foldGutter(),
        drawSelection(),
        dropCursor(),
        indentOnInput(),
        bracketMatching(),
        closeBrackets(),
        highlightActiveLine(),
        highlightSelectionMatches(),
        search({ top: true }),
        keymap.of([
          {
            key: "Mod-s",
            run: () => {
              void performSave();
              return true;
            },
          },
          ...closeBracketsKeymap,
          ...defaultKeymap,
          ...searchKeymap,
          ...historyKeymap,
          ...foldKeymap,
          indentWithTab,
        ]),
        languageCompartment.of([]),
        themeCompartment.of(themedExtensions(ready.theme)),
        wrapCompartment.of(wrapExtensions(ready.wordWrap)),
        aiEditFeature({
          copy: {
            instructionPlaceholder: ready.copy.aiEditPlaceholder,
            apply: ready.copy.aiEditApply,
            cancel: ready.copy.aiEditCancel,
            working: ready.copy.aiEditWorking,
            selectFirst: ready.copy.aiEditSelectFirst,
            accept: ready.copy.aiEditAccept,
            reject: ready.copy.aiEditReject,
          },
          language: () => currentLanguageName,
        }),
        localePhrases(ready.locale ?? "en"),
        EditorView.updateListener.of((update) => {
          if (update.docChanged) {
            scheduleDirtyNotify();
          }
        }),
      ],
    }),
  });

  const container = document.createElement("div");
  container.className = "cmux-editor-container";
  container.append(view.dom);
  rootElement.append(banner.element, container);

  window.cmuxEditorHost = {
    getContent: () => view.state.doc.toString(),
  };

  subscribeToHostEvents((event) => {
    switch (event.type) {
      case "document.external": {
        const action = session.applyExternal(view.state.doc.toString(), event.content);
        if (action.kind === "replaceBuffer") {
          replaceBuffer(action.content);
          banner.hide();
        } else if (action.kind === "showConflict") {
          banner.show("conflict");
        } else {
          banner.hide();
        }
        notifyDirtyIfChanged();
        break;
      }
      case "document.saved": {
        session.noteSaved(event.content);
        banner.hide();
        notifyDirtyIfChanged();
        break;
      }
      case "app.theme": {
        applyThemeVariables(event.theme);
        view.dispatch({ effects: themeCompartment.reconfigure(themedExtensions(event.theme)) });
        break;
      }
      case "app.options": {
        view.dispatch({ effects: wrapCompartment.reconfigure(wrapExtensions(event.wordWrap)) });
        break;
      }
    }
  });

  const fileName = ready.path.split("/").pop() ?? ready.path;
  const description = LanguageDescription.matchFilename(languages, fileName);
  if (description) {
    currentLanguageName = description.name;
  }
  if (description) {
    description
      .load()
      .then((support) => {
        view.dispatch({ effects: languageCompartment.reconfigure(support) });
      })
      .catch((error: unknown) => {
        // Degrade to plain text; the buffer stays fully editable.
        console.warn("cmux editor: language load failed", error);
      });
  }

  window.addEventListener("focus", () => {
    view.focus();
  });
  if (document.hasFocus()) {
    view.focus();
  }
}

export function mountEditorSurface(rootElement: HTMLElement): void {
  start(rootElement).catch((error: unknown) => {
    console.error("cmux editor: surface bootstrap failed", error);
  });
}
