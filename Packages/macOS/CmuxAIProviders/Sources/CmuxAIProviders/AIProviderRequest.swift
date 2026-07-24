/// One generation request, independent of wire format.
public struct AIProviderRequest: Sendable {
    /// The prompt turns in order; at most one `.system` message is honored
    /// and it may appear anywhere (Anthropic hoists it out of `messages`).
    public let messages: [AIChatMessage]
    /// Upper bound on generated tokens.
    public let maxTokens: Int
    /// Sampling temperature, or `nil` for the provider default.
    public let temperature: Double?
    /// Sequences that stop generation, e.g. fill-in-middle suffix markers.
    public let stopSequences: [String]

    /// Creates a generation request.
    ///
    /// - Parameters:
    ///   - messages: Prompt turns in order.
    ///   - maxTokens: Generated-token cap.
    ///   - temperature: Sampling temperature; `nil` uses the provider default.
    ///   - stopSequences: Stop strings; empty for none.
    public init(
        messages: [AIChatMessage],
        maxTokens: Int,
        temperature: Double? = nil,
        stopSequences: [String] = []
    ) {
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.stopSequences = stopSequences
    }
}
