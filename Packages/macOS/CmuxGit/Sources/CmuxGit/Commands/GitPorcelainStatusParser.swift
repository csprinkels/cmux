/// Parses NUL-delimited `git status --porcelain=v1 -z` output into
/// ``GitStatusEntry`` values.
///
/// The `-z` format is two status characters, a space, then the path,
/// NUL-terminated; rename/copy entries are followed by a second
/// NUL-terminated record holding the original path.
public struct GitPorcelainStatusParser: Sendable {
    /// Creates a parser.
    public init() {}

    /// Parses one `git status --porcelain=v1 -z` payload.
    ///
    /// - Parameter output: The raw command output.
    /// - Returns: Entries in git's output order (renames keep their new path).
    public func parse(_ output: String) -> [GitStatusEntry] {
        var entries: [GitStatusEntry] = []
        var records = output.split(separator: "\u{0}", omittingEmptySubsequences: true)[...]
        while let record = records.first {
            records = records.dropFirst()
            guard record.count >= 4 else { continue }
            let indexChar = record[record.startIndex]
            let worktreeChar = record[record.index(after: record.startIndex)]
            let path = String(record.dropFirst(3))
            guard
                let indexState = GitStatusEntry.State(rawValue: indexChar),
                let worktreeState = GitStatusEntry.State(rawValue: worktreeChar)
            else { continue }
            var originalPath: String?
            if indexState == .renamed || indexState == .copied
                || worktreeState == .renamed || worktreeState == .copied {
                if let original = records.first {
                    originalPath = String(original)
                    records = records.dropFirst()
                }
            }
            entries.append(
                GitStatusEntry(
                    path: path,
                    originalPath: originalPath,
                    indexState: indexState,
                    worktreeState: worktreeState
                )
            )
        }
        return entries
    }
}
