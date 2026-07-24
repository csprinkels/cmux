import Testing

@testable import CmuxAIProviders

@Suite("SSE framing")
struct ServerSentEventParserTests {
    @Test("Events complete at blank lines with joined data")
    func framesEvents() {
        var parser = ServerSentEventParser()
        #expect(parser.consume(line: "event: content_block_delta") == nil)
        #expect(parser.consume(line: "data: {\"a\":1}") == nil)
        let event = parser.consume(line: "")
        #expect(event == ServerSentEvent(name: "content_block_delta", data: "{\"a\":1}"))

        #expect(parser.consume(line: "data: first") == nil)
        #expect(parser.consume(line: "data: second") == nil)
        #expect(parser.consume(line: "") == ServerSentEvent(name: nil, data: "first\nsecond"))
    }

    @Test("Comments and unknown fields are ignored; blank runs emit nothing")
    func ignoresNoise() {
        var parser = ServerSentEventParser()
        #expect(parser.consume(line: ": keep-alive") == nil)
        #expect(parser.consume(line: "retry: 500") == nil)
        #expect(parser.consume(line: "") == nil)
        #expect(parser.consume(line: "") == nil)
        #expect(parser.consume(line: "data:tight") == nil)
        #expect(parser.consume(line: "") == ServerSentEvent(name: nil, data: "tight"))
    }

    @Test("finish flushes an unterminated trailing event")
    func finishFlushes() {
        var parser = ServerSentEventParser()
        #expect(parser.consume(line: "data: [DONE]") == nil)
        #expect(parser.finish() == ServerSentEvent(name: nil, data: "[DONE]"))
        #expect(parser.finish() == nil)
    }
}
