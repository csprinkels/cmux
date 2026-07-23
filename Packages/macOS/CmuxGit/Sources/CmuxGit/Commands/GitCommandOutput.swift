/// Captured output of a completed git command.
public struct GitCommandOutput: Sendable {
    /// Everything the command wrote to standard output, UTF-8 decoded.
    public let standardOutput: String
    /// Everything the command wrote to standard error, UTF-8 decoded.
    ///
    /// Git routinely writes progress and advisory text here even on success
    /// (`push` transfer stats, `checkout` switch notices), so a non-empty
    /// value is not an error signal on its own.
    public let standardError: String

    /// Creates an output pair from decoded pipe contents.
    ///
    /// - Parameters:
    ///   - standardOutput: The command's decoded standard output.
    ///   - standardError: The command's decoded standard error.
    public init(standardOutput: String, standardError: String) {
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}
