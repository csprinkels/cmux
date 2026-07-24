/// One turn of the prompt sent to a provider.
public struct AIChatMessage: Sendable, Equatable {
    /// The speaker of a chat turn.
    public enum Role: String, Sendable {
        /// Instructions that frame the whole request.
        case system
        /// Content authored by the user (or the feature on their behalf).
        case user
        /// A prior model reply, used to prefill or continue.
        case assistant
    }

    /// The turn's speaker.
    public let role: Role
    /// The turn's plain-text content.
    public let text: String

    /// Creates a chat turn.
    ///
    /// - Parameters:
    ///   - role: The speaker.
    ///   - text: Plain-text content.
    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}
