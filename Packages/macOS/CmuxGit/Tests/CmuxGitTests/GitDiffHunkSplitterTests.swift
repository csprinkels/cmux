import Foundation
import Testing

@testable import CmuxGit

@Suite("Diff hunk splitter")
struct GitDiffHunkSplitterTests {
    private let splitter = GitDiffHunkSplitter()

    private let twoHunkDiff = """
    diff --git a/a.txt b/a.txt
    index 1111111..2222222 100644
    --- a/a.txt
    +++ b/a.txt
    @@ -1,3 +1,3 @@
    -one
    +ONE
     two
     three
    @@ -10,3 +10,4 @@ context marker
     ten
    +ten point five
     eleven
     twelve
    """

    @Test("Each hunk becomes a standalone patch with the file headers")
    func splitsIntoStandalonePatches() {
        let hunks = splitter.split(fileDiff: twoHunkDiff)
        #expect(hunks.count == 2)
        #expect(hunks[0].header == "@@ -1,3 +1,3 @@")
        #expect(hunks[1].header == "@@ -10,3 +10,4 @@ context marker")
        for hunk in hunks {
            #expect(hunk.patchText.hasPrefix("diff --git a/a.txt b/a.txt\n"))
            #expect(hunk.patchText.contains("--- a/a.txt\n+++ b/a.txt\n"))
            #expect(hunk.patchText.hasSuffix("\n"))
        }
        #expect(hunks[0].patchText.contains("+ONE"))
        #expect(!hunks[0].patchText.contains("ten point five"))
        #expect(hunks[1].patchText.contains("+ten point five"))
        #expect(!hunks[1].patchText.contains("+ONE"))
    }

    @Test("No-newline markers stay with their hunk")
    func noNewlineMarkerRetained() {
        let diff = """
        diff --git a/b.txt b/b.txt
        index 1111111..2222222 100644
        --- a/b.txt
        +++ b/b.txt
        @@ -1 +1 @@
        -old
        \\ No newline at end of file
        +new
        \\ No newline at end of file
        """
        let hunks = splitter.split(fileDiff: diff)
        #expect(hunks.count == 1)
        #expect(hunks[0].patchText.contains("\\ No newline at end of file"))
    }

    @Test("Binary and header-only diffs produce no hunks")
    func binaryAndHeaderOnlyDiffs() {
        let binary = """
        diff --git a/img.png b/img.png
        index 1111111..2222222 100644
        Binary files a/img.png and b/img.png differ
        """
        #expect(splitter.split(fileDiff: binary).isEmpty)
        #expect(splitter.split(fileDiff: "").isEmpty)
    }

    @Test("Only the first file section is considered")
    func firstFileSectionOnly() {
        let multi = twoHunkDiff + "\n" + """
        diff --git a/z.txt b/z.txt
        index 3333333..4444444 100644
        --- a/z.txt
        +++ b/z.txt
        @@ -1 +1 @@
        -zed
        +ZED
        """
        let hunks = splitter.split(fileDiff: multi)
        #expect(hunks.count == 2)
        #expect(!hunks.contains(where: { $0.patchText.contains("ZED") }))
    }

    @Test("A lone second hunk applies to the index without the first")
    func loneSecondHunkAppliesToIndex() async throws {
        let fixture = try LiveGitRepositoryFixture()
        let runner = GitCommandRunner(environment: fixture.environment)
        let original = (1...20).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try fixture.write(original, to: "a.txt")
        try fixture.commitAll(message: "initial")

        var lines = original.split(separator: "\n").map(String.init)
        lines[0] = "line 1 CHANGED"
        lines[18] = "line 19 CHANGED"
        try fixture.write(lines.joined(separator: "\n") + "\n", to: "a.txt")

        let diff = try fixture.git(["diff", "--", "a.txt"])
        let hunks = splitter.split(fileDiff: diff)
        #expect(hunks.count == 2)

        try await runner.applyPatchToIndex(hunks[1].patchText, in: fixture.root)
        let staged = try fixture.git(["diff", "--cached", "--", "a.txt"])
        #expect(staged.contains("line 19 CHANGED"))
        #expect(!staged.contains("line 1 CHANGED"))

        try await runner.applyPatchToIndex(hunks[1].patchText, reverse: true, in: fixture.root)
        #expect(try fixture.git(["diff", "--cached", "--", "a.txt"]).isEmpty)
    }
}
