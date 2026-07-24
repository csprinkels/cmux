public import Foundation

/// Streams text generations from an AI provider endpoint.
///
/// One client speaks both supported dialects (``AIProviderWireFormat``) over
/// SSE via `URLSession.bytes(for:)`. Cancel by cancelling the task iterating
/// the returned stream — the underlying connection tears down with it.
///
/// ```swift
/// let client = AIProviderClient()
/// for try await delta in try await client.streamText(request, configuration: config) {
///     buffer += delta
/// }
/// ```
public actor AIProviderClient {
    private let urlSession: URLSession

    /// Creates a client.
    ///
    /// - Parameter urlSession: The session to use; defaults to an ephemeral
    ///   session so provider traffic never lands in shared caches.
    public init(urlSession: URLSession? = nil) {
        self.urlSession = urlSession ?? URLSession(configuration: .ephemeral)
    }

    /// Opens the request and streams text deltas.
    ///
    /// Connection and HTTP-status failures throw from this call; in-stream
    /// provider errors throw from the returned sequence.
    ///
    /// - Parameters:
    ///   - request: The generation request.
    ///   - configuration: The endpoint to call.
    /// - Returns: The generated text, one delta at a time.
    public func streamText(
        _ request: AIProviderRequest,
        configuration: AIProviderConfiguration
    ) async throws -> AsyncThrowingStream<String, any Error> {
        let urlRequest = try AIProviderRequestEncoder().urlRequest(
            for: request,
            configuration: configuration
        )
        let (bytes, response) = try await urlSession.bytes(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            var body = ""
            for try await line in bytes.lines {
                body += body.isEmpty ? line : "\n\(line)"
                if body.utf8.count > 2048 { break }
            }
            throw AIProviderError.httpStatus(code: httpResponse.statusCode, body: body)
        }

        let parser = AIProviderStreamParser(wireFormat: configuration.wireFormat)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var framing = ServerSentEventParser()
                do {
                    for try await line in bytes.lines {
                        guard let event = framing.consume(line: line) else { continue }
                        if parser.isTerminal(event) { break }
                        if let text = try parser.textDelta(from: event) {
                            continuation.yield(text)
                        }
                    }
                    if let event = framing.finish(),
                       !parser.isTerminal(event),
                       let text = try parser.textDelta(from: event) {
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
