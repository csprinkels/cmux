/// One hunk of a single-file diff, packaged as a standalone patch so it can
/// be staged or unstaged independently via
/// ``GitCommandRunner/applyPatchToIndex(_:reverse:in:)``.
public struct GitDiffHunk: Sendable, Equatable, Identifiable {
    /// Zero-based position of the hunk within the file's diff.
    public let index: Int
    /// The hunk's `@@ -old +new @@` header line (with any trailing context).
    public let header: String
    /// A complete apply-ready patch: the file's diff headers plus only this
    /// hunk, newline-terminated.
    public let patchText: String

    /// The hunk's position; unique within one split.
    public var id: Int { index }

    /// Creates a hunk record.
    ///
    /// - Parameters:
    ///   - index: Zero-based hunk position.
    ///   - header: The `@@` header line.
    ///   - patchText: Apply-ready single-hunk patch text.
    public init(index: Int, header: String, patchText: String) {
        self.index = index
        self.header = header
        self.patchText = patchText
    }
}
