import { describe, expect, test } from "bun:test";
import { applyHunkStage, hunkStageActionForSource, hunkStageAnnotations } from "./staging";
import type { FileDiffMetadata } from "@pierre/diffs";

function fileDiffWithHunks(hunks: Array<Partial<FileDiffMetadata["hunks"][number]>>): FileDiffMetadata {
  return { hunks } as FileDiffMetadata;
}

describe("hunkStageActionForSource", () => {
  test("maps live worktree sources and rejects the rest", () => {
    expect(hunkStageActionForSource({ kind: "unstaged", repoRoot: "/r" })).toBe("stage");
    expect(hunkStageActionForSource({ kind: "staged", repoRoot: "/r" })).toBe("unstage");
    expect(hunkStageActionForSource({ kind: "branch", repoRoot: "/r" })).toBeNull();
    expect(hunkStageActionForSource({ kind: "patch", path: "p" })).toBeNull();
    expect(hunkStageActionForSource(null)).toBeNull();
  });
});

describe("hunkStageAnnotations", () => {
  const twoHunks = fileDiffWithHunks([
    { deletionStart: 1, deletionCount: 3, additionStart: 1, additionCount: 4 },
    { deletionStart: 10, deletionCount: 2, additionStart: 11, additionCount: 0 },
  ]);

  test("anchors one annotation per hunk on the hunk's last line", () => {
    const annotations = hunkStageAnnotations(twoHunks, "a.txt", "stage", "/repo");
    expect(annotations.length).toBe(2);
    expect(annotations[0].side).toBe("additions");
    expect(annotations[0].lineNumber).toBe(4);
    // Pure-deletion hunks anchor on the deletions side.
    expect(annotations[1].side).toBe("deletions");
    expect(annotations[1].lineNumber).toBe(11);
    expect(annotations[0].metadata).toEqual({
      kind: "hunkStage",
      action: "stage",
      repoRoot: "/repo",
      filePath: "a.txt",
      hunk: { deletionStart: 1, deletionCount: 3, additionStart: 1, additionCount: 4 },
    });
  });

  test("yields nothing without a fileDiff, path, or hunks", () => {
    expect(hunkStageAnnotations(null, "a.txt", "stage", "/repo")).toEqual([]);
    expect(hunkStageAnnotations(twoHunks, "", "stage", "/repo")).toEqual([]);
    expect(hunkStageAnnotations(fileDiffWithHunks([]), "a.txt", "unstage", "/repo")).toEqual([]);
  });
});

describe("applyHunkStage", () => {
  const metadata = {
    kind: "hunkStage" as const,
    action: "stage" as const,
    repoRoot: "/repo",
    filePath: "a.txt",
    hunk: { deletionStart: 1, deletionCount: 1, additionStart: 1, additionCount: 1 },
  };

  function withHandler(postMessage: (message: unknown) => Promise<unknown>) {
    (globalThis as any).window = { webkit: { messageHandlers: { cmuxGitStage: { postMessage } } } };
  }

  test("sends the bridge request and resolves on ok", async () => {
    let sent: unknown;
    withHandler(async (message) => {
      sent = message;
      return { ok: true };
    });
    await applyHunkStage(metadata);
    expect(sent).toEqual({
      method: "staging.applyHunk",
      params: {
        repoRoot: "/repo",
        filePath: "a.txt",
        action: "stage",
        hunk: metadata.hunk,
      },
    });
  });

  test("surfaces the bridge's user message on failure", async () => {
    withHandler(async () => ({ ok: false, error: { code: "hunk_out_of_date", userMessage: "Reload the diff." } }));
    expect(applyHunkStage(metadata)).rejects.toThrow("Reload the diff.");
  });

  test("throws when the handler is missing", async () => {
    (globalThis as any).window = {};
    expect(applyHunkStage(metadata)).rejects.toThrow();
  });
});
