import type { DiffLineAnnotation, FileDiffMetadata } from "@pierre/diffs";
import { useState } from "react";
import type { DiffSource } from "./diff/generated/protocol";
import type { DiffViewerLabelResolver } from "./labels";

/**
 * Per-hunk stage/unstage support for the diff viewer.
 *
 * The webview never builds patch text: each hunk is named by its `@@` header
 * numbers and the native `cmuxGitStage` bridge recomputes the diff with git,
 * matches the hunk, and applies it to the index. Annotations are derived per
 * item and only for live worktree sources (unstaged → stage, staged →
 * unstage); patch files and branch diffs get none.
 */

export type HunkStageTarget = {
  deletionStart: number;
  deletionCount: number;
  additionStart: number;
  additionCount: number;
};

export type HunkStageMetadata = {
  kind: "hunkStage";
  action: "stage" | "unstage";
  repoRoot: string;
  filePath: string;
  hunk: HunkStageTarget;
};

export type HunkStageAnnotation = DiffLineAnnotation<HunkStageMetadata>;

type StagingReply = { ok: true } | { ok: false; error?: { code?: string; userMessage?: string } };

type StagingHandler = { postMessage(message: unknown): Promise<unknown> };

function stagingHandler(): StagingHandler | undefined {
  return window.webkit?.messageHandlers?.cmuxGitStage;
}

export function stagingBridgeAvailable(): boolean {
  return typeof stagingHandler()?.postMessage === "function";
}

/** The hunk action the current diff source supports, or null when none. */
export function hunkStageActionForSource(
  source: DiffSource | null | undefined,
): "stage" | "unstage" | null {
  if (source?.kind === "unstaged") {
    return "stage";
  }
  if (source?.kind === "staged") {
    return "unstage";
  }
  return null;
}

/**
 * Derives one stage/unstage annotation per hunk, anchored on the hunk's last
 * line so the action row reads as the hunk's footer.
 */
export function hunkStageAnnotations(
  fileDiff: FileDiffMetadata | null | undefined,
  filePath: string,
  action: "stage" | "unstage",
  repoRoot: string,
): HunkStageAnnotation[] {
  if (fileDiff == null || filePath === "" || !Array.isArray(fileDiff.hunks)) {
    return [];
  }
  return fileDiff.hunks.map((hunk) => {
    const side = hunk.additionCount > 0 ? "additions" : "deletions";
    const lineNumber = side === "additions"
      ? hunk.additionStart + Math.max(hunk.additionCount - 1, 0)
      : hunk.deletionStart + Math.max(hunk.deletionCount - 1, 0);
    return {
      side,
      lineNumber,
      metadata: {
        kind: "hunkStage",
        action,
        repoRoot,
        filePath,
        hunk: {
          deletionStart: hunk.deletionStart,
          deletionCount: hunk.deletionCount,
          additionStart: hunk.additionStart,
          additionCount: hunk.additionCount,
        },
      },
    };
  });
}

/** Sends one hunk to the native bridge; throws with a user-facing message. */
export async function applyHunkStage(metadata: HunkStageMetadata): Promise<void> {
  const handler = stagingHandler();
  if (!handler) {
    throw new Error("Staging is unavailable in this viewer.");
  }
  const reply = (await handler.postMessage({
    method: "staging.applyHunk",
    params: {
      repoRoot: metadata.repoRoot,
      filePath: metadata.filePath,
      action: metadata.action,
      hunk: metadata.hunk,
    },
  })) as StagingReply | null;
  if (reply == null || reply.ok !== true) {
    const message = reply?.ok === false ? reply.error?.userMessage : undefined;
    throw new Error(message || "Could not update the git index.");
  }
}

export function HunkStageActions({
  metadata,
  label,
  onApplied,
}: {
  metadata: HunkStageMetadata;
  label: DiffViewerLabelResolver;
  onApplied: (filePath: string) => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <div className="hunk-stage-row">
      {error != null ? <span className="hunk-stage-error">{error}</span> : null}
      <button
        type="button"
        className="hunk-stage-button"
        disabled={busy}
        onClick={() => {
          setBusy(true);
          setError(null);
          applyHunkStage(metadata)
            .then(() => onApplied(metadata.filePath))
            .catch((cause: unknown) => {
              setError(cause instanceof Error ? cause.message : label("stagingFailed"));
              setBusy(false);
            });
        }}
      >
        {label(metadata.action === "stage" ? "stageHunk" : "unstageHunk")}
      </button>
    </div>
  );
}
