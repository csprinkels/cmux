internal import Foundation

/// Extracts text deltas from one wire format's SSE events.
///
/// Pure — feed ``ServerSentEvent`` values, receive text or a thrown
/// ``AIProviderError`` for in-stream error events.
public struct AIProviderStreamParser: Sendable {
    private let wireFormat: AIProviderWireFormat

    /// Creates a parser for one dialect.
    ///
    /// - Parameter wireFormat: The dialect of the stream.
    public init(wireFormat: AIProviderWireFormat) {
        self.wireFormat = wireFormat
    }

    /// The text carried by one event, or `nil` for non-text events.
    ///
    /// - Parameter event: A framed SSE event.
    /// - Returns: The delta text, or `nil` (metadata, terminators, empty
    ///   deltas).
    /// - Throws: ``AIProviderError/providerError(message:)`` for error
    ///   events.
    public func textDelta(from event: ServerSentEvent) throws -> String? {
        switch wireFormat {
        case .anthropicMessages:
            return try anthropicTextDelta(from: event)
        case .openAIChatCompletions:
            return try openAITextDelta(from: event)
        }
    }

    /// Whether the event ends the stream.
    ///
    /// - Parameter event: A framed SSE event.
    /// - Returns: `true` for `message_stop` / `[DONE]` terminators.
    public func isTerminal(_ event: ServerSentEvent) -> Bool {
        switch wireFormat {
        case .anthropicMessages:
            return event.name == "message_stop"
        case .openAIChatCompletions:
            return event.data.trimmingCharacters(in: .whitespaces) == "[DONE]"
        }
    }

    private func anthropicTextDelta(from event: ServerSentEvent) throws -> String? {
        guard let object = Self.jsonObject(event.data) else { return nil }
        if event.name == "error" || object["type"] as? String == "error" {
            let error = object["error"] as? [String: Any]
            throw AIProviderError.providerError(
                message: error?["message"] as? String ?? "The AI provider reported an error."
            )
        }
        guard object["type"] as? String == "content_block_delta",
              let delta = object["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta",
              let text = delta["text"] as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private func openAITextDelta(from event: ServerSentEvent) throws -> String? {
        guard !isTerminal(event), let object = Self.jsonObject(event.data) else { return nil }
        if let error = object["error"] as? [String: Any] {
            throw AIProviderError.providerError(
                message: error["message"] as? String ?? "The AI provider reported an error."
            )
        }
        guard let choices = object["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let text = delta["content"] as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func jsonObject(_ data: String) -> [String: Any]? {
        guard let bytes = data.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any]
    }
}
