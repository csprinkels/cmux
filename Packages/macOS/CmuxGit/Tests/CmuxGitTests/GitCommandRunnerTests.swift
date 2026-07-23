import Foundation
import Testing

@testable import CmuxGit

@Suite("Git command runner", .serialized)
struct GitCommandRunnerTests {
    private func makeFixture() throws -> (LiveGitRepositoryFixture, GitCommandRunner) {
        let fixture = try LiveGitRepositoryFixture()
        let runner = GitCommandRunner(environment: fixture.environment)
        return (fixture, runner)
    }

    @Test("Stage adds tracked and untracked paths to the index")
    func stageAddsPathsToIndex() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("hello\n", to: "a.txt")
        try await runner.stage(paths: ["a.txt"], in: fixture.root)
        #expect(try fixture.porcelainStatus().contains("A  a.txt"))
    }

    @Test("Unstage restores a staged path to unstaged")
    func unstageRestoresPath() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("one\n", to: "a.txt")
        try fixture.commitAll(message: "initial")
        try fixture.write("two\n", to: "a.txt")
        try await runner.stage(paths: ["a.txt"], in: fixture.root)
        #expect(try fixture.porcelainStatus().contains("M  a.txt"))
        try await runner.unstage(paths: ["a.txt"], in: fixture.root)
        #expect(try fixture.porcelainStatus().contains(" M a.txt"))
    }

    @Test("Commit records staged changes and reports failure without any")
    func commitRecordsStagedChanges() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("one\n", to: "a.txt")
        try await runner.stageAll(in: fixture.root)
        try await runner.commit(message: "first", in: fixture.root)
        #expect(try fixture.git(["log", "--format=%s"]).contains("first"))

        await #expect(throws: GitCommandFailure.self) {
            try await runner.commit(message: "empty", in: fixture.root)
        }
    }

    @Test("Discard restores tracked content; clean removes untracked files")
    func discardAndCleanSeparateResponsibilities() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("original\n", to: "a.txt")
        try fixture.commitAll(message: "initial")
        try fixture.write("edited\n", to: "a.txt")
        try fixture.write("scratch\n", to: "untracked.txt")

        try await runner.discardWorktreeChanges(paths: ["a.txt"], in: fixture.root)
        #expect(try fixture.read("a.txt") == "original\n")
        #expect(fixture.exists("untracked.txt"))

        try await runner.removeUntracked(paths: ["untracked.txt"], in: fixture.root)
        #expect(!fixture.exists("untracked.txt"))
    }

    @Test("Branch listing marks the current branch; checkout switches")
    func branchListingAndCheckout() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("one\n", to: "a.txt")
        try fixture.commitAll(message: "initial")
        try fixture.git(["branch", "feature/editor"])

        let branches = try await runner.branches(in: fixture.root)
        #expect(branches == [
            GitBranch(name: "feature/editor", isCurrent: false),
            GitBranch(name: "main", isCurrent: true),
        ])

        try await runner.checkout(branch: "feature/editor", in: fixture.root)
        let after = try await runner.branches(in: fixture.root)
        #expect(after.first(where: \.isCurrent)?.name == "feature/editor")
    }

    @Test("Push publishes the branch to origin and pull fast-forwards")
    func pushAndPullRoundTrip() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("one\n", to: "a.txt")
        try fixture.commitAll(message: "initial")
        let bare = try fixture.addBareOrigin()
        try fixture.git(["push", "-u", "origin", "main"])

        try fixture.write("two\n", to: "a.txt")
        try fixture.commitAll(message: "second")
        try await runner.push(in: fixture.root)

        let bareLog = try fixture.git(["--git-dir", bare.path, "log", "--format=%s", "main"])
        #expect(bareLog.contains("second"))

        try fixture.git(["reset", "--hard", "HEAD~1"])
        try await runner.pull(in: fixture.root)
        #expect(try fixture.git(["log", "--format=%s"]).contains("second"))
    }

    @Test("A patch applies to the index only, and reverses with -R")
    func applyPatchToIndexStagesHunk() async throws {
        let (fixture, runner) = try makeFixture()
        try fixture.write("line one\nline two\n", to: "a.txt")
        try fixture.commitAll(message: "initial")
        try fixture.write("line one changed\nline two\n", to: "a.txt")

        let patch = try fixture.git(["diff", "--", "a.txt"])
        try await runner.applyPatchToIndex(patch, in: fixture.root)
        #expect(try fixture.git(["diff", "--cached", "--", "a.txt"]).contains("line one changed"))

        try await runner.applyPatchToIndex(patch, reverse: true, in: fixture.root)
        #expect(try fixture.git(["diff", "--cached", "--", "a.txt"]).isEmpty)
    }

    @Test("Failures carry git's stderr and the exit code")
    func failureCarriesStderr() async throws {
        let (fixture, runner) = try makeFixture()
        do {
            try await runner.checkout(branch: "does-not-exist", in: fixture.root)
            Issue.record("checkout of a missing branch should throw")
        } catch let failure as GitCommandFailure {
            #expect(failure.exitCode != 0)
            #expect(failure.errorDescription?.isEmpty == false)
        }
    }
}
