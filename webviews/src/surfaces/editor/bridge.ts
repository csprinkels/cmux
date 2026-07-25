/**
 * Typed JS↔Swift bridge for the code editor surface.
 *
 * Mirrors `agent-session/shared/bridge.ts`: requests go through the
 * `cmuxEditor` WKScriptMessageHandlerWithReply, host-initiated events arrive
 * via `window.cmuxEditorBridge.receive`.
 */

/**
 * Ghostty terminal theme slice mirrored into the editor so code renders with
 * the same colors and font as the terminal and the diff viewer. Shape matches
 * the fields `AgentChatThemePayload` exposes on the Swift side.
 */
export type EditorTerminalTheme = {
  background: string;
  foreground: string;
  /** 16 ANSI colors; syntax scopes map onto these like the diff viewer. */
  palette: string[];
  selectionBackground?: string | null;
  cursorColor?: string | null;
  fontFamily?: string | null;
  fontSize?: number | null;
};

export type EditorTheme = {
  isDark: boolean;
  pageBackground: string;
  surfaceBackground: string;
  surfaceElevatedBackground: string;
  inputBackground: string;
  border: string;
  borderStrong: string;
  text: string;
  mutedText: string;
  softText: string;
  accent: string;
  accentSoft: string;
  danger: string;
  shadow: string;
  /** Present when the host resolved the Ghostty terminal theme. */
  terminal?: EditorTerminalTheme | null;
};

export type EditorCopy = {
  fileChangedOnDisk: string;
  reloadFromDisk: string;
  keepMyChanges: string;
  saveFailed: string;
  aiEditPlaceholder: string;
  aiEditApply: string;
  aiEditCancel: string;
  aiEditWorking: string;
  aiEditSelectFirst: string;
  aiEditAccept: string;
  aiEditReject: string;
};

export type EditorReadyReply = {
  /** Buffer to open with (may carry unsaved edits from the plain engine). */
  content: string;
  /** Last content known to be on disk; the initial dirty baseline. */
  diskContent: string;
  path: string;
  wordWrap: boolean;
  /** Whether inline ghost-text autocomplete is enabled (`ai.autocomplete.enabled`). */
  aiAutocomplete: boolean;
  /** App UI locale (e.g. "en", "ja") for CodeMirror's built-in phrases. */
  locale: string;
  theme: EditorTheme;
  copy: EditorCopy;
};

export type EditorHostEvent =
  | { type: "document.external"; content: string }
  | { type: "document.saved"; content: string }
  | { type: "app.theme"; theme: EditorTheme }
  | { type: "app.options"; wordWrap: boolean; aiAutocomplete?: boolean };

type NativeReply<T> =
  | { ok: true; value: T }
  | { ok: false; error?: { code?: string; userMessage?: string } };

type HostEventListener = (event: EditorHostEvent) => void;

declare global {
  interface Window {
    cmuxEditorBridge?: {
      receive(event: EditorHostEvent): void;
    };
    cmuxEditorHost?: {
      getContent(): string;
    };
  }
}

const listeners = new Set<HostEventListener>();

if (typeof window !== "undefined") {
  window.cmuxEditorBridge = {
    receive(event: EditorHostEvent) {
      for (const listener of listeners) {
        listener(event);
      }
    },
  };
}

export function subscribeToHostEvents(listener: HostEventListener): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

let nextRequestId = 0;

export async function callNative<T>(method: string, params: Record<string, unknown> = {}): Promise<T> {
  const handler = typeof window === "undefined" ? undefined : window.webkit?.messageHandlers?.cmuxEditor;
  if (!handler || typeof handler.postMessage !== "function") {
    throw new Error("Native editor bridge is unavailable.");
  }
  nextRequestId += 1;
  const reply = (await handler.postMessage({
    id: `editor-${nextRequestId}`,
    method,
    params,
  })) as NativeReply<T>;
  if (!reply.ok) {
    throw new Error(reply.error?.userMessage || "Native editor bridge request failed.");
  }
  return reply.value;
}
