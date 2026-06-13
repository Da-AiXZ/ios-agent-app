import Foundation

// MARK: - SSEEvent

/// A parsed Server-Sent Events frame.
///
/// Each SSE event can carry content deltas, tool call data, or
/// control signals (finish, error). The parser accumulates
/// partial data across multiple `feed(bytes:)` calls.
struct SSEEvent {

    /// The type of SSE event.
    let type: SSEEventType

    /// The raw JSON data payload of the event, if any.
    /// Consumers should decode this into the appropriate model.
    let data: Data?

    /// The event ID, if present in the SSE stream.
    let eventId: String?

    // MARK: - Initialization

    init(type: SSEEventType, data: Data? = nil, eventId: String? = nil) {
        self.type = type
        self.data = data
        self.eventId = eventId
    }
}

// MARK: - SSEEventType

/// The types of events that can be received in an SSE stream.
@frozen
enum SSEEventType: String, CaseIterable {
    /// A content delta chunk from the streaming response.
    case content

    /// A tool call detected in the response.
    case toolCall

    /// The stream has finished successfully.
    case finish

    /// An error occurred in the stream.
    case error

    /// A ping/heartbeat event.
    case ping
}

// MARK: - SSEParser

/// A state-machine based parser for Server-Sent Events (SSE).
///
/// The parser processes raw byte chunks incrementally, transitioning
/// through states: `idle → readingField → readingData → done/error`.
/// It outputs fully-formed `SSEEvent` values through an `AsyncStream`.
///
/// SSE protocol format:
/// ```
/// event: <event-type>\n
/// id: <event-id>\n
/// data: <json-data>\n
/// \n
/// ```
final class SSEParser {

    // MARK: - State

    /// Internal parser state.
    private enum State {
        case idle
        case readingField
        case readingData
        case done
        case error
    }

    // MARK: - Properties

    /// Accumulates raw bytes that have not yet been parsed.
    private var buffer: Data

    /// The current parser state.
    private var state: State

    /// The current event type being assembled.
    private var currentEventType: String?

    /// The current event ID being assembled.
    private var currentEventId: String?

    /// The accumulated data content being assembled.
    private var currentDataBuffer: String

    /// Tracks consecutive UTF-8 decode failures to avoid
    /// entering error state on a single split multi-byte character.
    private var consecutiveDecodeFailures: Int

    /// Continuation for the AsyncStream output.
    private var continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation?

    // MARK: - Initialization

    /// Creates a new SSE parser in the idle state.
    init() {
        self.buffer = Data()
        self.state = .idle
        self.currentEventType = nil
        self.currentEventId = nil
        self.currentDataBuffer = ""
        self.consecutiveDecodeFailures = 0
    }

    // MARK: - Public Methods

    /// Feeds raw bytes into the parser for incremental processing.
    ///
    /// Call this method as bytes arrive from the network. The parser
    /// will accumulate partial data and emit complete `SSEEvent`
    /// values when full frames are received.
    ///
    /// - Parameter bytes: The raw data chunk received from the network.
    /// - Returns: An `AsyncStream` that yields `SSEEvent` values as
    ///   they are parsed.
    func feed(bytes: Data) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream<SSEEvent, Error> { continuation in
            self.continuation = continuation
            buffer.append(bytes)
            parseBuffer()

            // If the stream ended, signal completion.
            if state == .done || state == .error {
                continuation.finish()
            }
        }
    }

    /// Starts a new parsing session that outputs events through
    /// the provided continuation.
    ///
    /// - Parameter continuation: The stream continuation to yield events into.
    func parseStream(continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation) {
        self.continuation = continuation
    }

    /// Feeds bytes and processes them through the existing continuation.
    ///
    /// - Parameter bytes: Raw data chunk from the network.
    func feedToStream(bytes: Data) {
        buffer.append(bytes)
        parseBuffer()
    }

    /// Signals that the byte stream has ended. Finalizes any
    /// partial data in the buffer and closes the stream.
    func finishStream() {
        // Process any remaining data.
        if !currentDataBuffer.isEmpty {
            emitEvent()
        }
        state = .done
        continuation?.finish()
        continuation = nil
    }

    /// Resets the parser to its initial idle state for reuse.
    func reset() {
        buffer = Data()
        state = .idle
        currentEventType = nil
        currentEventId = nil
        currentDataBuffer = ""
        consecutiveDecodeFailures = 0
        continuation = nil
    }

    // MARK: - Private Parsing

    /// Processes the accumulated buffer, extracting complete lines
    /// and advancing the state machine.
    private func parseBuffer() {
        guard let string = String(data: buffer, encoding: .utf8) else {
            consecutiveDecodeFailures += 1
            if consecutiveDecodeFailures >= 2 {
                state = .error
                emitError("Failed to decode buffer as UTF-8 after multiple attempts")
            }
            // Keep buffer intact — next feed may complete the multi-byte character.
            return
        }
        consecutiveDecodeFailures = 0

        // Split into lines, preserving empty lines.
        let lines = string.components(separatedBy: "\n")

        // Keep the last (possibly incomplete) line in the buffer.
        var remainingBuffer: [String] = []
        var isComplete = false

        for (index, line) in lines.enumerated() {
            // Check for [DONE] terminator.
            if line == "[DONE]" {
                state = .done
                isComplete = true
                break
            }

            // Empty line signals end of an event.
            if line.isEmpty {
                if !currentDataBuffer.isEmpty {
                    emitEvent()
                }
                resetCurrentEvent()
                state = .idle
                continue
            }

            if line.hasPrefix("event:") {
                let value = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                currentEventType = String(value)
                state = .readingField
            } else if line.hasPrefix("data:") {
                let value = line.dropFirst(5)
                // Data can be prefixed with a space.
                let trimmed = value.hasPrefix(" ") ? String(value.dropFirst()) : String(value)
                if !currentDataBuffer.isEmpty {
                    currentDataBuffer.append("\n")
                }
                currentDataBuffer.append(trimmed)
                state = .readingData
            } else if line.hasPrefix("id:") {
                let value = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                currentEventId = String(value)
            } else if line.hasPrefix(":") {
                // Comment line — skip.
                continue
            } else if line.hasPrefix("retry:") {
                // Retry directive — ignore for now.
                continue
            }

            // Track incomplete line.
            if index == lines.count - 1 && !line.isEmpty && !isComplete {
                remainingBuffer.append(line)
            }
        }

        // Preserve incomplete data for next feed.
        if !remainingBuffer.isEmpty {
            buffer = remainingBuffer.joined(separator: "\n").data(using: .utf8) ?? Data()
        } else {
            buffer = Data()
        }
    }

    /// Emits the currently assembled event through the continuation.
    private func emitEvent() {
        let eventType: SSEEventType
        let data = currentDataBuffer.data(using: .utf8)

        // Determine event type.
        if currentDataBuffer == "[DONE]" {
            eventType = .finish
        } else if let rawType = currentEventType {
            switch rawType {
            case "content_block_delta":
                eventType = .content
            case "content_block_start", "content_block_stop":
                // Tool call events.
                eventType = .toolCall
            case "message_stop":
                eventType = .finish
            case "error":
                eventType = .error
            case "ping":
                eventType = .ping
            default:
                eventType = .content
            }
        } else {
            // No explicit event type — try to infer from data.
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let choices = json["choices"] as? [[String: Any]],
                   let choice = choices.first,
                   let finishReason = choice["finish_reason"] as? String,
                   finishReason == "stop" {
                    eventType = .finish
                } else if json["type"] as? String == "content_block_delta" {
                    eventType = .content
                } else {
                    eventType = .content
                }
            } else {
                eventType = .content
            }
        }

        let event = SSEEvent(
            type: eventType,
            data: data,
            eventId: currentEventId
        )
        continuation?.yield(event)

        if eventType == .finish || eventType == .error {
            state = eventType == .finish ? .done : .error
        }
    }

    /// Emits an error event through the continuation.
    private func emitError(_ message: String) {
        let errorData = try? JSONSerialization.data(
            withJSONObject: ["error": message]
        )
        let event = SSEEvent(type: .error, data: errorData)
        continuation?.yield(event)
    }

    /// Resets the current event assembly state.
    private func resetCurrentEvent() {
        currentEventType = nil
        currentEventId = nil
        currentDataBuffer = ""
    }
}
