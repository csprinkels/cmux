/// One parsed server-sent event: the optional `event:` name and the joined
/// `data:` payload.
public struct ServerSentEvent: Sendable, Equatable {
    /// The `event:` field, or `nil` for unnamed events.
    public let name: String?
    /// The `data:` lines joined with newlines.
    public let data: String

    /// Creates an event.
    ///
    /// - Parameters:
    ///   - name: The `event:` field, if present.
    ///   - data: Joined `data:` payload.
    public init(name: String?, data: String) {
        self.name = name
        self.data = data
    }
}
