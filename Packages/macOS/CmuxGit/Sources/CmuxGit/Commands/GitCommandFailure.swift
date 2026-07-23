public import Foundation

/// A git command that exited non-zero (or could not be launched).
public struct GitCommandFailure: Error, Sendable {
    /// The git arguments that were executed, without the leading `git`.
    public let arguments: [String]
    /// The process exit code; `nil` when the process could not be launched.
    public let exitCode: Int32?
    /// The command's decoded standard error, usually git's own explanation.
    public let standardError: String
    /// The command's decoded standard output at the time of failure.
    public let standardOutput: String

    /// Creates a failure describing a non-zero git exit.
    ///
    /// - Parameters:
    ///   - arguments: The git arguments that were executed.
    ///   - exitCode: The process exit code, or `nil` for a launch failure.
    ///   - standardError: Decoded standard error contents.
    ///   - standardOutput: Decoded standard output contents.
    public init(
        arguments: [String],
        exitCode: Int32?,
        standardError: String,
        standardOutput: String = ""
    ) {
        self.arguments = arguments
        self.exitCode = exitCode
        self.standardError = standardError
        self.standardOutput = standardOutput
    }
}

extension GitCommandFailure: LocalizedError {
    /// Git's own stderr when present, else a generic exit-code description.
    public var errorDescription: String? {
        let trimmed = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let exitCode {
            return "git \(arguments.joined(separator: " ")) exited with code \(exitCode)"
        }
        return "git could not be launched"
    }
}
