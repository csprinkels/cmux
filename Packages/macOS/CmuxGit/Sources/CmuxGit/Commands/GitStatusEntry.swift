/// One changed path from `git status --porcelain -z`, keeping the index and
/// worktree states separate so a source-control UI can show "Staged Changes"
/// and "Changes" sections the way `git status` does.
public struct GitStatusEntry: Sendable, Equatable, Identifiable {
    /// A single porcelain status letter for one side (index or worktree).
    public enum State: Character, Sendable {
        /// No change on this side (porcelain space).
        case unmodified = " "
        /// Content changed (`M`).
        case modified = "M"
        /// Newly added to the index (`A`).
        case added = "A"
        /// Deleted (`D`).
        case deleted = "D"
        /// Renamed in the index (`R`).
        case renamed = "R"
        /// Copied in the index (`C`).
        case copied = "C"
        /// Type change, e.g. file ↔ symlink (`T`).
        case typeChanged = "T"
        /// Unmerged conflict entry (`U`).
        case unmerged = "U"
        /// Untracked (`?`).
        case untracked = "?"
        /// Ignored (`!`).
        case ignored = "!"
    }

    /// Repository-relative path of the entry (the new path for renames).
    public let path: String
    /// The previous path when the index recorded a rename or copy.
    public let originalPath: String?
    /// The index (staged) side of the porcelain code.
    public let indexState: State
    /// The worktree (unstaged) side of the porcelain code.
    public let worktreeState: State

    /// The path; a path appears at most once in porcelain output.
    public var id: String { path }

    /// Whether the entry has something recorded in the index
    /// (shows in a "Staged Changes" section).
    public var isStaged: Bool {
        switch indexState {
        case .unmodified, .untracked, .ignored:
            return false
        case .modified, .added, .deleted, .renamed, .copied, .typeChanged, .unmerged:
            return true
        }
    }

    /// Whether the entry has worktree changes on top of the index
    /// (shows in a "Changes" section). Untracked files count.
    public var hasWorktreeChanges: Bool {
        switch worktreeState {
        case .unmodified, .ignored:
            return false
        case .modified, .added, .deleted, .renamed, .copied, .typeChanged, .unmerged, .untracked:
            return true
        }
    }

    /// Creates a status entry.
    ///
    /// - Parameters:
    ///   - path: Repository-relative path (new path for renames).
    ///   - originalPath: The pre-rename path, when applicable.
    ///   - indexState: The staged side of the code.
    ///   - worktreeState: The unstaged side of the code.
    public init(
        path: String,
        originalPath: String? = nil,
        indexState: State,
        worktreeState: State
    ) {
        self.path = path
        self.originalPath = originalPath
        self.indexState = indexState
        self.worktreeState = worktreeState
    }
}
