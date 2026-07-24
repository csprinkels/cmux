public import Foundation

/// Failures surfaced by ``AIProviderClient``, with user-facing messages.
public enum AIProviderError: Error, LocalizedError, Sendable, Equatable {
    /// The endpoint returned a non-success HTTP status.
    case httpStatus(code: Int, body: String)
    /// The endpoint's stream carried an error event.
    case providerError(message: String)
    /// The response was not an HTTP response or was otherwise malformed.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let body):
            let detail = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "The AI provider returned HTTP \(code)." : "HTTP \(code): \(detail)"
        case .providerError(let message):
            return message
        case .invalidResponse:
            return "The AI provider returned an invalid response."
        }
    }
}
