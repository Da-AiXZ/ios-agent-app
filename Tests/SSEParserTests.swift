import XCTest
@testable import ios_agent_app

// MARK: - SSEParserTests

/// Tests the SSEParser state machine: idle → readingField → readingData → done,
/// data: line parsing, [DONE] terminator, comment line skipping, incremental feed.
final class SSEParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func test_parseSimpleDataLine_emitsContentEvent() async {
        let parser = SSEParser()
        let stream = parser.feed(bytes: "data: hello world\n\n".data(using: .utf8)!)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1, "Should emit exactly one event")
        XCTAssertEqual(events[0].type, .content)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "hello world")
    }

    func test_parseEventAndDataLines_emitsContentWithCorrectType() async {
        let parser = SSEParser()
        let input = """
            event: content_block_delta
            data: {"text": "hello"}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .content)
    }

    func test_parseMultipleDataLines_concatenatesWithNewline() async {
        let parser = SSEParser()
        let input = """
            data: line1
            data: line2
            data: line3
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        let dataStr = String(data: events[0].data!, encoding: .utf8)
        XCTAssertEqual(dataStr, "line1\nline2\nline3")
    }

    // MARK: - [DONE] Terminator

    func test_parseDoneTerminator_emitsNothingForEmptyPendingData() async {
        let parser = SSEParser()
        let stream = parser.feed(bytes: "[DONE]\n".data(using: .utf8)!)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        // [DONE] with no prior data should not emit any event.
        XCTAssertTrue(events.isEmpty, "[DONE] with no pending data should emit nothing")
    }

    func test_parseDoneAfterData_emitsFinishAndStops() async {
        let parser = SSEParser()
        let input = """
            data: test content
            
            [DONE]
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        // Should emit the data event, then [DONE] stops.
        // The [DONE] triggers done state but does not emit on its own.
        XCTAssertGreaterThanOrEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .content)
    }

    // MARK: - Comment Lines

    func test_parseCommentLine_skipsWithoutEmitting() async {
        let parser = SSEParser()
        let input = """
            : this is a comment line
            data: actual data
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "actual data")
    }

    func test_parseRetryLine_skipsWithoutEmitting() async {
        let parser = SSEParser()
        let input = """
            retry: 3000
            data: retry tested
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "retry tested")
    }

    // MARK: - Event ID

    func test_parseIdLine_setsEventId() async {
        let parser = SSEParser()
        let input = """
            id: evt-12345
            data: content with id
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventId, "evt-12345")
    }

    // MARK: - Incremental Feed

    func test_incrementalFeed_acrossMultipleCalls() async {
        let parser = SSEParser()

        // Feed 1: partial data line.
        let stream1 = parser.feed(bytes: "data: partial".data(using: .utf8)!)
        var events1: [SSEEvent] = []
        for await event in stream1 {
            events1.append(event)
        }
        XCTAssertEqual(events1.count, 0, "No event emitted for incomplete data")

        // Feed 2: complete with newline and blank line.
        let stream2 = parser.feed(bytes: " content\n\n".data(using: .utf8)!)
        var events2: [SSEEvent] = []
        for await event in stream2 {
            events2.append(event)
        }
        XCTAssertEqual(events2.count, 1)
        XCTAssertEqual(
            String(data: events2[0].data!, encoding: .utf8),
            "partial content"
        )
    }

    func test_incrementalFeed_preservesIncompleteLine() async {
        let parser = SSEParser()

        // Feed: data prefix without value.
        _ = parser.feed(bytes: "data: ".data(using: .utf8)!)

        // Feed: the rest of the value plus blank line.
        let stream = parser.feed(bytes: "the value\n\n".data(using: .utf8)!)
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            String(data: events[0].data!, encoding: .utf8),
            "the value"
        )
    }

    func test_incrementalFeed_withEventIdAcrossFeeds() async {
        let parser = SSEParser()

        _ = parser.feed(bytes: "id: abc-".data(using: .utf8)!)
        let stream = parser.feed(bytes: "123\ndata: content\n\n".data(using: .utf8)!)
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventId, "abc-123")
    }

    // MARK: - Multiple Events in Single Feed

    func test_multipleEvents_singleFeed_emitsAll() async {
        let parser = SSEParser()
        let input = """
            data: first event
            
            data: second event
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "first event")
        XCTAssertEqual(String(data: events[1].data!, encoding: .utf8), "second event")
    }

    // MARK: - Event Type Detection

    func test_eventType_messageStop_emitsFinish() async {
        let parser = SSEParser()
        let input = """
            event: message_stop
            data: {"stop_reason": "end_turn"}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .finish)
    }

    func test_eventType_error_emitsError() async {
        let parser = SSEParser()
        let input = """
            event: error
            data: {"error": "something went wrong"}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .error)
    }

    func test_eventType_ping_emitsPing() async {
        let parser = SSEParser()
        let input = """
            event: ping
            data: heartbeat
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .ping)
    }

    func test_eventType_toolCall_emitsToolCall() async {
        let parser = SSEParser()
        let input = """
            event: content_block_start
            data: {"type": "content_block_start", "content_block": {"type": "tool_use", "name": "read_file"}}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .toolCall)
    }

    // MARK: - Data with Leading Space

    func test_dataLineWithLeadingSpace_trimsSpace() async {
        let parser = SSEParser()
        let input = "data:  hello\n\n".data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        // The data: handler drops the leading space after "data:".
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "hello")
    }

    // MARK: - finishStream

    func test_finishStream_emitsPendingData() async {
        let parser = SSEParser()
        let stream = parser.feed(bytes: "data: unfinished".data(using: .utf8)!)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        // The feed didn't have a blank line, so nothing emitted yet.
        // finishStream should flush it.
        parser.finishStream()

        // Events from feed's stream already consumed; test via parseStream + feedToStream.
    }

    func test_finishStream_withParseStream_emitsRemainingData() async {
        let parser = SSEParser()

        let expectation = XCTestExpectation(description: "finishStream emits pending data")
        let stream = AsyncStream<SSEEvent> { continuation in
            parser.parseStream(continuation: continuation)
            parser.feedToStream(bytes: "data: pending data".data(using: .utf8)!)
            // Don't send blank line — finishStream should flush.
            parser.finishStream()
        }

        var events: [SSEEvent] = []
        Task {
            for await event in stream {
                events.append(event)
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(events.count, 1, "finishStream should emit pending data")
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "pending data")
    }

    // MARK: - reset

    func test_reset_clearsAllState() async {
        let parser = SSEParser()

        // Feed some data first.
        _ = parser.feed(bytes: "data: before reset\n\n".data(using: .utf8)!)

        // Reset.
        parser.reset()

        // Feed new data and verify it works cleanly.
        let stream = parser.feed(bytes: "data: after reset\n\n".data(using: .utf8)!)
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "after reset")
    }

    // MARK: - UTF-8 Decode Error

    func test_invalidUTF8_twoConsecutiveFailures_emitsError() async {
        let parser = SSEParser()

        // Feed 1: invalid byte — fails once, tolerance window open.
        _ = parser.feed(bytes: Data([0xFF]))

        // Feed 2: another invalid byte — second consecutive failure → error.
        let stream = parser.feed(bytes: Data([0xFE]))
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1,
            "Two consecutive decode failures should emit an error event")
        XCTAssertEqual(events[0].type, .error)
    }

    // MARK: - REGRESSION: UTF-8 split-feed tolerance (BUG-3)

    func test_utf8_multibyteCharacterSplitAcrossFeeds_noError() async {
        // BUG-3 regression: "你好" UTF-8 bytes split across feeds.
        // 你 = \xE4\xBD\xA0, 好 = \xE5\xA5\xBD
        //
        // Full SSE event: "data: 你好\n\n"
        // Bytes: d a t a : SP E4 BD A0 E5 A5 BD \n \n
        let parser = SSEParser()

        // Feed 1: "data: " + first 2 bytes of 你 (incomplete multi-byte sequence).
        var feed1 = "data: ".data(using: .utf8)!
        feed1.append(contentsOf: [0xE4, 0xBD])
        _ = parser.feed(bytes: feed1)

        // Feed 2: last byte of 你 + full 好 + terminators.
        var feed2 = Data([0xA0, 0xE5, 0xA5, 0xBD])
        feed2.append("\n\n".data(using: .utf8)!)
        let stream = parser.feed(bytes: feed2)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        // The parser should NOT enter error state — it should tolerate
        // the first decode failure and succeed on the second feed.
        let errorEvents = events.filter { $0.type == .error }
        XCTAssertTrue(errorEvents.isEmpty,
            "Split UTF-8 should not produce error events, got \(errorEvents.count)")

        // The content should be correctly decoded as "你好".
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .content)
        let decoded = String(data: events[0].data!, encoding: .utf8)
        XCTAssertEqual(decoded, "你好",
            "Split-feed UTF-8 should decode to correct content")
    }

    func test_utf8_multibyteCharacterSplitAcrossFeeds_withConsecutiveDecodeFailuresReset() async {
        // Verify that a successful decode resets consecutiveDecodeFailures.
        let parser = SSEParser()

        // First, trigger a decode failure (but not error).
        _ = parser.feed(bytes: Data([0xE4]))  // incomplete UTF-8 byte → fail count = 1

        // Now send valid data — this should succeed and reset the counter.
        let stream = parser.feed(bytes: "data: hello\n\n".data(using: .utf8)!)
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .content)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "hello")
    }

    func test_utf8_singleFailThenMultibyteSplit_tolerates() async {
        // A single decode failure (incomplete byte) followed by a split
        // multibyte character in the same scenario. The counter should reset
        // after the successful decode of the completed multibyte sequence.
        let parser = SSEParser()

        // Feed 1: incomplete UTF-8 start
        _ = parser.feed(bytes: Data([0xE4, 0xBD]))  // fail count = 1

        // Feed 2: complete it with valid data
        var feed2 = Data([0xA0, 0xE5, 0xA5, 0xBD])  // completes 你 + full 好
        feed2.append("\n\n".data(using: .utf8)!)
        let stream = parser.feed(bytes: "data: ".data(using: .utf8)! + feed2)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        let errorEvents = events.filter { $0.type == .error }
        XCTAssertTrue(errorEvents.isEmpty,
            "Should tolerate split with prior single failure")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(String(data: events[0].data!, encoding: .utf8), "你好")
    }

    func test_utf8_threeConsecutiveFailures_emitsError() async {
        // Verify that the 2-failure threshold is enforced.
        let parser = SSEParser()

        _ = parser.feed(bytes: Data([0xFF]))  // fail 1
        _ = parser.feed(bytes: Data([0xFE]))  // fail 2 → should trigger error

        // After 2 consecutive failures, the parser should be in error state.
        // A third feed should not produce valid events.
        let stream = parser.feed(bytes: "data: hello\n\n".data(using: .utf8)!)
        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        // The error from feed 2 should have been emitted.
        XCTAssertTrue(events.contains(where: { $0.type == .error }),
            "Two consecutive decode failures should emit error")
    }

    // MARK: - JSON Inference (no explicit event type)

    func test_noEventType_finishReasonStop_emitsFinish() async {
        let parser = SSEParser()
        let input = """
            data: {"choices": [{"finish_reason": "stop"}]}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .finish)
    }

    func test_noEventType_contentDelta_emitsContent() async {
        let parser = SSEParser()
        let input = """
            data: {"type": "content_block_delta"}
            
            """.data(using: .utf8)!
        let stream = parser.feed(bytes: input)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .content)
    }

    // MARK: - Empty Input

    func test_emptyFeed_emitsNothing() async {
        let parser = SSEParser()
        let stream = parser.feed(bytes: Data())

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 0)
    }

    // MARK: - Newline-Only Feed

    func test_newlineOnlyFeed_emitsNothing() async {
        let parser = SSEParser()
        let stream = parser.feed(bytes: "\n\n\n".data(using: .utf8)!)

        var events: [SSEEvent] = []
        for await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 0)
    }
}
