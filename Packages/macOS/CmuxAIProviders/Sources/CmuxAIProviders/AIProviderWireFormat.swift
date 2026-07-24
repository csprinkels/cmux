/// The request/response dialect a provider endpoint speaks.
///
/// Prompt assembly and stream parsing key off the wire format, never off a
/// vendor name, so any OpenAI-compatible server (OpenAI, Ollama, LM Studio,
/// OpenRouter, vLLM…) works through one case.
public enum AIProviderWireFormat: String, Sendable, CaseIterable, Codable {
    /// Anthropic's Messages API (`POST /v1/messages`).
    case anthropicMessages
    /// OpenAI-compatible chat completions (`POST /v1/chat/completions`).
    case openAIChatCompletions
}
