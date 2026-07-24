import Foundation
import Testing

@testable import CmuxAIProviders

@Suite("Request encoding")
struct AIProviderRequestEncoderTests {
    private let encoder = AIProviderRequestEncoder()
    private let request = AIProviderRequest(
        messages: [
            AIChatMessage(role: .system, text: "You edit code."),
            AIChatMessage(role: .user, text: "Rename x to y."),
        ],
        maxTokens: 256,
        temperature: 0.2,
        stopSequences: ["<END>"]
    )

    private func body(of urlRequest: URLRequest) throws -> [String: Any] {
        let data = try #require(urlRequest.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("Anthropic: /v1/messages, version header, hoisted system, stream on")
    func anthropicShape() throws {
        let configuration = AIProviderConfiguration(
            baseURL: URL(string: "https://api.anthropic.com")!,
            model: "claude-sonnet-5",
            wireFormat: .anthropicMessages,
            apiKey: "sk-test"
        )
        let urlRequest = try encoder.urlRequest(for: request, configuration: configuration)
        #expect(urlRequest.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(urlRequest.value(forHTTPHeaderField: "x-api-key") == "sk-test")
        #expect(urlRequest.value(forHTTPHeaderField: "anthropic-version") == AIProviderRequestEncoder.anthropicVersion)

        let body = try body(of: urlRequest)
        #expect(body["model"] as? String == "claude-sonnet-5")
        #expect(body["max_tokens"] as? Int == 256)
        #expect(body["stream"] as? Bool == true)
        #expect(body["system"] as? String == "You edit code.")
        #expect(body["temperature"] as? Double == 0.2)
        #expect(body["stop_sequences"] as? [String] == ["<END>"])
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 1)
        #expect(messages?.first?["role"] as? String == "user")
    }

    @Test("OpenAI-compatible: /v1/chat/completions, Bearer only with a key")
    func openAIShape() throws {
        let configuration = AIProviderConfiguration(
            baseURL: URL(string: "https://api.openai.com/v1/")!,
            model: "gpt-4.1",
            wireFormat: .openAIChatCompletions,
            apiKey: "sk-oai"
        )
        let urlRequest = try encoder.urlRequest(for: request, configuration: configuration)
        #expect(urlRequest.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer sk-oai")

        let body = try body(of: urlRequest)
        #expect(body["stream"] as? Bool == true)
        #expect(body["stop"] as? [String] == ["<END>"])
        let messages = body["messages"] as? [[String: Any]]
        #expect(messages?.count == 2)
        #expect(messages?.first?["role"] as? String == "system")
    }

    @Test("Keyless local endpoints get no auth header (Ollama)")
    func keylessOllama() throws {
        let configuration = AIProviderConfiguration(
            baseURL: URL(string: "http://localhost:11434")!,
            model: "qwen2.5-coder",
            wireFormat: .openAIChatCompletions,
            apiKey: nil
        )
        let urlRequest = try encoder.urlRequest(for: request, configuration: configuration)
        #expect(urlRequest.url?.absoluteString == "http://localhost:11434/v1/chat/completions")
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
