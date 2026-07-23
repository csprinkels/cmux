import CmuxGit
import Foundation
import Observation

/// State and actions for the Source Control sidebar tool: the change list
/// (staged/unstaged sections), branch switching, commit, and push/pull,
/// backed by `GitCommandRunner` against the selected workspace's repository.
@MainActor
@Observable
final class SourceControlStore {
    /// The resolved repository working-tree root; `nil` when the workspace
    /// directory is not inside a git repository.
    private(set) var repositoryRoot: URL?
    /// Change entries in git's porcelain order.
    private(set) var entries: [GitStatusEntry] = []
    /// Local branches, current one marked.
    private(set) var branches: [GitBranch] = []
    /// Whether a mutating command is in flight (disables the action UI).
    private(set) var isBusy = false
    /// Git's stderr from the last failed command, cleared on success.
    private(set) var lastErrorMessage: String?
    /// The commit message draft, bound to the commit box.
    var commitMessage = ""

    private let runner: GitCommandRunner
    private var workspaceDirectory: String?
    private var refreshGeneration = 0

    init(runner: GitCommandRunner = GitCommandRunner()) {
        self.runner = runner
    }

    var stagedEntries: [GitStatusEntry] { entries.filter(\.isStaged) }
    var unstagedEntries: [GitStatusEntry] { entries.filter(\.hasWorktreeChanges) }
    var currentBranchName: String? { branches.first(where: \.isCurrent)?.name }
    var canCommit: Bool {
        !isBusy && !stagedEntries.isEmpty
            && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Points the store at a workspace directory (or clears it), resolving
    /// the enclosing repository root and refreshing.
    func setWorkspaceDirectory(_ path: String?) {
        guard path != workspaceDirectory else { return }
        workspaceDirectory = path
        repositoryRoot = nil
        entries = []
        branches = []
        lastErrorMessage = nil
        refresh()
    }

    /// Re-reads status and branches for the current repository.
    func refresh() {
        refreshGeneration += 1
        let generation = refreshGeneration
        guard let workspaceDirectory else { return }
        let directoryURL = URL(fileURLWithPath: workspaceDirectory, isDirectory: true)
        Task {
            guard let root = await runner.repositoryTopLevel(containing: directoryURL) else {
                if generation == refreshGeneration {
                    repositoryRoot = nil
                    entries = []
                    branches = []
                }
                return
            }
            let status = (try? await runner.status(in: root)) ?? []
            let branchList = (try? await runner.branches(in: root)) ?? []
            guard generation == refreshGeneration else { return }
            repositoryRoot = root
            entries = status
            branches = branchList
        }
    }

    func stage(_ entry: GitStatusEntry) {
        perform { runner, root in
            try await runner.stage(paths: [entry.path], in: root)
        }
    }

    func stageAll() {
        perform { runner, root in
            try await runner.stageAll(in: root)
        }
    }

    func unstage(_ entry: GitStatusEntry) {
        perform { runner, root in
            try await runner.unstage(paths: [entry.path], in: root)
        }
    }

    /// Discards the entry's worktree changes: untracked files are deleted,
    /// tracked modifications restored from the index. The view confirms
    /// before calling this — it is destructive.
    func discard(_ entry: GitStatusEntry) {
        perform { runner, root in
            if entry.worktreeState == .untracked {
                try await runner.removeUntracked(paths: [entry.path], in: root)
            } else {
                try await runner.discardWorktreeChanges(paths: [entry.path], in: root)
            }
        }
    }

    func commit() {
        let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        perform { [weak self] runner, root in
            try await runner.commit(message: message, in: root)
            await MainActor.run { self?.commitMessage = "" }
        }
    }

    func push() {
        perform { runner, root in
            try await runner.push(in: root)
        }
    }

    func pull() {
        perform { runner, root in
            try await runner.pull(in: root)
        }
    }

    func checkout(branch: String) {
        perform { runner, root in
            try await runner.checkout(branch: branch, in: root)
        }
    }

    private func perform(_ operation: @escaping @Sendable (GitCommandRunner, URL) async throws -> Void) {
        guard !isBusy, let repositoryRoot else { return }
        isBusy = true
        lastErrorMessage = nil
        let runner = runner
        Task {
            do {
                try await operation(runner, repositoryRoot)
            } catch let failure as GitCommandFailure {
                lastErrorMessage = failure.errorDescription
            } catch {
                lastErrorMessage = error.localizedDescription
            }
            isBusy = false
            refresh()
        }
    }
}
