/// Incremental SSE framing: feed lines as they arrive, receive completed
/// events at blank-line boundaries.
///
/// Pure state machine — no I/O — so stream framing is unit-testable without a
/// server. Comment lines (`:`) and unknown fields are ignored per the SSE
/// specification; multiple `data:` lines accumulate joined by `\n`.
public struct ServerSentEventParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    /// Creates a parser at the start of a stream.
    public init() {}

    /// Consumes one line (without its trailing newline) and returns the event
    /// it completes, if any.
    ///
    /// - Parameter line: The raw line.
    /// - Returns: A finished event when `line` is the blank separator ending
    ///   one, otherwise `nil`.
    public mutating func consume(line: String) -> ServerSentEvent? {
        if line.isEmpty {
            defer {
                eventName = nil
                dataLines = []
            }
            guard !dataLines.isEmpty else { return nil }
            return ServerSentEvent(name: eventName, data: dataLines.joined(separator: "\n"))
        }
        if line.hasPrefix(":") {
            return nil
        }
        let field: Substring
        let value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[line.startIndex..<colon]
            let afterColon = line.index(after: colon)
            let rawValue = line[afterColon...]
            value = rawValue.hasPrefix(" ") ? rawValue.dropFirst() : rawValue
        } else {
            field = line[...]
            value = ""
        }
        switch field {
        case "event":
            eventName = String(value)
        case "data":
            dataLines.append(String(value))
        default:
            break
        }
        return nil
    }

    /// Flushes a trailing event from a stream that ended without a final
    /// blank line.
    ///
    /// - Returns: The unterminated event, if one was in progress.
    public mutating func finish() -> ServerSentEvent? {
        consume(line: "")
    }
}
