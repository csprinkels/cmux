/// Splits one file's `git diff` output into standalone single-hunk patches —
/// the primitive behind per-hunk stage/unstage in the diff viewer.
///
/// `git apply` locates a lone hunk by its old-side positions and context
/// lines, so a hunk extracted here applies to the index without its siblings.
public struct GitDiffHunkSplitter: Sendable {
    /// Creates a splitter.
    public init() {}

    /// Splits a single file's diff into per-hunk patches.
    ///
    /// Only the first `diff --git` section is considered — run
    /// `git diff -- <path>` per file to produce the input. Binary diffs and
    /// header-only diffs (pure renames, mode changes) yield no hunks.
    ///
    /// - Parameter fileDiff: The complete diff text for one file.
    /// - Returns: One ``GitDiffHunk`` per `@@` section, in order.
    public func split(fileDiff: String) -> [GitDiffHunk] {
        var headerLines: [Substring] = []
        var hunks: [[Substring]] = []
        var sawFileBoundary = false

        for line in fileDiff.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("diff --git") {
                if sawFileBoundary {
                    break
                }
                sawFileBoundary = true
                headerLines.append(line)
                continue
            }
            if line.hasPrefix("@@") {
                hunks.append([line])
                continue
            }
            if hunks.isEmpty {
                headerLines.append(line)
            } else {
                hunks[hunks.count - 1].append(line)
            }
        }

        // A trailing empty element comes from the diff's final newline; drop
        // it so hunk bodies don't carry a phantom blank line.
        while headerLines.last?.isEmpty == true {
            headerLines.removeLast()
        }
        guard !headerLines.isEmpty else { return [] }
        let header = headerLines.joined(separator: "\n")

        return hunks.enumerated().map { index, lines in
            var body = lines
            while body.last?.isEmpty == true {
                body.removeLast()
            }
            let patch = header + "\n" + body.joined(separator: "\n") + "\n"
            return GitDiffHunk(
                index: index,
                header: String(lines[0]),
                patchText: patch
            )
        }
    }
}
