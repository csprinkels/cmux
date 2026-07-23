import Testing

@testable import CmuxGit

@Suite("Porcelain status parser")
struct GitPorcelainStatusParserTests {
    private let parser = GitPorcelainStatusParser()

    @Test("Splits index and worktree sides")
    func splitsSides() {
        let entries = parser.parse("MM a.txt\u{0}A  b.txt\u{0} M c.txt\u{0}?? d.txt\u{0}")
        #expect(entries == [
            GitStatusEntry(path: "a.txt", indexState: .modified, worktreeState: .modified),
            GitStatusEntry(path: "b.txt", indexState: .added, worktreeState: .unmodified),
            GitStatusEntry(path: "c.txt", indexState: .unmodified, worktreeState: .modified),
            GitStatusEntry(path: "d.txt", indexState: .untracked, worktreeState: .untracked),
        ])
        #expect(entries[0].isStaged && entries[0].hasWorktreeChanges)
        #expect(entries[1].isStaged && !entries[1].hasWorktreeChanges)
        #expect(!entries[2].isStaged && entries[2].hasWorktreeChanges)
        #expect(!entries[3].isStaged && entries[3].hasWorktreeChanges)
    }

    @Test("Renames consume the second record as the original path")
    func renamesCarryOriginalPath() {
        let entries = parser.parse("R  new.txt\u{0}old.txt\u{0}M  after.txt\u{0}")
        #expect(entries == [
            GitStatusEntry(path: "new.txt", originalPath: "old.txt", indexState: .renamed, worktreeState: .unmodified),
            GitStatusEntry(path: "after.txt", indexState: .modified, worktreeState: .unmodified),
        ])
    }

    @Test("Paths with spaces and NUL-free unicode survive")
    func pathsWithSpaces() {
        let entries = parser.parse("?? some dir/file name.txt\u{0} M 日本語.md\u{0}")
        #expect(entries.map(\.path) == ["some dir/file name.txt", "日本語.md"])
    }

    @Test("Empty and malformed records are skipped")
    func malformedRecordsSkipped() {
        #expect(parser.parse("").isEmpty)
        #expect(parser.parse("X").isEmpty)
        let entries = parser.parse("ZZ odd.txt\u{0}M  fine.txt\u{0}")
        #expect(entries == [
            GitStatusEntry(path: "fine.txt", indexState: .modified, worktreeState: .unmodified),
        ])
    }
}
