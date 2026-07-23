/// A local branch as listed by ``GitCommandRunner/branches(in:)``.
public struct GitBranch: Sendable, Equatable, Identifiable {
    /// The short branch name (`main`, `feature/editor`).
    public let name: String
    /// Whether `HEAD` currently points at this branch.
    public let isCurrent: Bool

    /// The branch name; branch names are unique within a repository.
    public var id: String { name }

    /// Creates a branch listing entry.
    ///
    /// - Parameters:
    ///   - name: The short branch name.
    ///   - isCurrent: Whether `HEAD` points at the branch.
    public init(name: String, isCurrent: Bool) {
        self.name = name
        self.isCurrent = isCurrent
    }
}
