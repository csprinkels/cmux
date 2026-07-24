public import Foundation

/// Where and how to reach one provider endpoint.
///
/// The API key is passed in memory only — persistence belongs to
/// ``AIProviderKeychain``, never to defaults or config files.
public struct AIProviderConfiguration: Sendable {
    /// The endpoint origin, e.g. `https://api.anthropic.com` or
    /// `http://localhost:11434`. A trailing `/v1` is tolerated.
    public let baseURL: URL
    /// The model identifier to request.
    public let model: String
    /// The dialect the endpoint speaks.
    public let wireFormat: AIProviderWireFormat
    /// The API key, or `nil` for keyless local servers such as Ollama.
    public let apiKey: String?

    /// Creates an endpoint description.
    ///
    /// - Parameters:
    ///   - baseURL: Endpoint origin.
    ///   - model: Model identifier.
    ///   - wireFormat: Request/response dialect.
    ///   - apiKey: Key for the endpoint; `nil` when the server needs none.
    public init(baseURL: URL, model: String, wireFormat: AIProviderWireFormat, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.model = model
        self.wireFormat = wireFormat
        self.apiKey = apiKey
    }
}
