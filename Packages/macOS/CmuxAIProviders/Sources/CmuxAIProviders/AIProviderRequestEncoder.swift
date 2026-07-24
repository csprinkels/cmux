public import Foundation

/// Builds the `URLRequest` for one generation call, per wire format.
///
/// Pure — no I/O — so header and body shapes are unit-testable. Prompt
/// assembly differences live here and in ``AIProviderStreamParser``, keyed by
/// ``AIProviderWireFormat`` only (never by vendor name).
public struct AIProviderRequestEncoder: Sendable {
    /// The Messages API version header Anthropic requires.
    public static let anthropicVersion = "2023-06-01"

    /// Creates an encoder.
    public init() {}

    /// Builds the streaming request.
    ///
    /// - Parameters:
    ///   - request: The generation request.
    ///   - configuration: The endpoint to call.
    /// - Returns: A ready-to-send `URLRequest` with `stream: true`.
    public func urlRequest(
        for request: AIProviderRequest,
        configuration: AIProviderConfiguration
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: endpointURL(configuration: configuration))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let body: [String: Any]
        switch configuration.wireFormat {
        case .anthropicMessages:
            if let apiKey = configuration.apiKey {
                urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            }
            urlRequest.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
            body = anthropicBody(for: request, configuration: configuration)
        case .openAIChatCompletions:
            if let apiKey = configuration.apiKey {
                urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            body = openAIBody(for: request, configuration: configuration)
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return urlRequest
    }

    /// The full endpoint URL for the configuration, tolerating a base URL
    /// that already ends in `/v1`.
    ///
    /// - Parameter configuration: The endpoint description.
    /// - Returns: The URL to POST to.
    public func endpointURL(configuration: AIProviderConfiguration) -> URL {
        let path: String
        switch configuration.wireFormat {
        case .anthropicMessages: path = "v1/messages"
        case .openAIChatCompletions: path = "v1/chat/completions"
        }
        var base = configuration.baseURL.absoluteString
        while base.hasSuffix("/") {
            base = String(base.dropLast())
        }
        if base.hasSuffix("/v1") {
            base = String(base.dropLast(3))
            while base.hasSuffix("/") {
                base = String(base.dropLast())
            }
        }
        return URL(string: "\(base)/\(path)") ?? configuration.baseURL
    }

    private func anthropicBody(
        for request: AIProviderRequest,
        configuration: AIProviderConfiguration
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": request.maxTokens,
            "stream": true,
            "messages": request.messages
                .filter { $0.role != .system }
                .map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        let system = request.messages.first { $0.role == .system }?.text
        if let system, !system.isEmpty {
            body["system"] = system
        }
        if let temperature = request.temperature {
            body["temperature"] = temperature
        }
        if !request.stopSequences.isEmpty {
            body["stop_sequences"] = request.stopSequences
        }
        return body
    }

    private func openAIBody(
        for request: AIProviderRequest,
        configuration: AIProviderConfiguration
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": request.maxTokens,
            "stream": true,
            "messages": request.messages
                .map { ["role": $0.role.rawValue, "content": $0.text] },
        ]
        if let temperature = request.temperature {
            body["temperature"] = temperature
        }
        if !request.stopSequences.isEmpty {
            body["stop"] = request.stopSequences
        }
        return body
    }
}
