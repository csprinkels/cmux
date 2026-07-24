import Testing

@testable import CmuxAIProviders

@Suite("Stream parsing")
struct AIProviderStreamParserTests {
    @Test("Anthropic text deltas extract; metadata events yield nil")
    func anthropicDeltas() throws {
        let parser = AIProviderStreamParser(wireFormat: .anthropicMessages)
        let delta = ServerSentEvent(
            name: "content_block_delta",
            data: #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"let x"}}"#
        )
        #expect(try parser.textDelta(from: delta) == "let x")

        let start = ServerSentEvent(
            name: "message_start",
            data: #"{"type":"message_start","message":{"id":"m"}}"#
        )
        #expect(try parser.textDelta(from: start) == nil)
        #expect(parser.isTerminal(ServerSentEvent(name: "message_stop", data: #"{"type":"message_stop"}"#)))
    }

    @Test("Anthropic error events throw with the provider message")
    func anthropicErrors() {
        let parser = AIProviderStreamParser(wireFormat: .anthropicMessages)
        let event = ServerSentEvent(
            name: "error",
            data: #"{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#
        )
        #expect(throws: AIProviderError.providerError(message: "Overloaded")) {
            try parser.textDelta(from: event)
        }
    }

    @Test("OpenAI chunks extract deltas; [DONE] is terminal")
    func openAIDeltas() throws {
        let parser = AIProviderStreamParser(wireFormat: .openAIChatCompletions)
        let chunk = ServerSentEvent(
            name: nil,
            data: #"{"choices":[{"delta":{"content":"fn main"},"index":0}]}"#
        )
        #expect(try parser.textDelta(from: chunk) == "fn main")

        let roleOnly = ServerSentEvent(
            name: nil,
            data: #"{"choices":[{"delta":{"role":"assistant"},"index":0}]}"#
        )
        #expect(try parser.textDelta(from: roleOnly) == nil)

        let done = ServerSentEvent(name: nil, data: "[DONE]")
        #expect(parser.isTerminal(done))
        #expect(try parser.textDelta(from: done) == nil)
    }

    @Test("OpenAI error payloads throw with the provider message")
    func openAIErrors() {
        let parser = AIProviderStreamParser(wireFormat: .openAIChatCompletions)
        let event = ServerSentEvent(
            name: nil,
            data: #"{"error":{"message":"model not found","type":"invalid_request_error"}}"#
        )
        #expect(throws: AIProviderError.providerError(message: "model not found")) {
            try parser.textDelta(from: event)
        }
    }
}
