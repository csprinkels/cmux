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

    /// The four `@@ -old,count +new,count @@` numbers parsed from a hunk
    /// header, the coordinate a UI can use to name a hunk without shipping
    /// patch text.
    public struct HeaderNumbers: Sendable, Equatable {
        /// Start line on the old (deletion) side.
        public let deletionStart: Int
        /// Line count on the old side; git omits `,count` when it is 1.
        public let deletionCount: Int
        /// Start line on the new (addition) side.
        public let additionStart: Int
        /// Line count on the new side; git omits `,count` when it is 1.
        public let additionCount: Int

        /// Creates a coordinate.
        ///
        /// - Parameters:
        ///   - deletionStart: Start line on the old side.
        ///   - deletionCount: Line count on the old side.
        ///   - additionStart: Start line on the new side.
        ///   - additionCount: Line count on the new side.
        public init(deletionStart: Int, deletionCount: Int, additionStart: Int, additionCount: Int) {
            self.deletionStart = deletionStart
            self.deletionCount = deletionCount
            self.additionStart = additionStart
            self.additionCount = additionCount
        }
    }

    /// The parsed `@@` numbers of this hunk's header, or `nil` for a
    /// malformed header line.
    public var headerNumbers: HeaderNumbers? {
        // "@@ -12,3 +14,4 @@ optional context" — counts default to 1.
        let pattern = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/
        guard let match = header.firstMatch(of: pattern),
              let deletionStart = Int(match.1),
              let additionStart = Int(match.3) else {
            return nil
        }
        return HeaderNumbers(
            deletionStart: deletionStart,
            deletionCount: match.2.flatMap { Int($0) } ?? 1,
            additionStart: additionStart,
            additionCount: match.4.flatMap { Int($0) } ?? 1
        )
    }

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
