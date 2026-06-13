import XCTest
@testable import ios_agent_app

// MARK: - Test State/Intent/Effect for MVI protocol conformance

/// A minimal ViewState for testing MVI protocol requirements.
struct TestViewState: ViewState {
    var name: String
    var count: Int
    var isActive: Bool
}

/// A minimal ViewIntent for testing MVI protocol requirements.
enum TestViewIntent: ViewIntent {
    case increment
    case decrement
    case setName(String)
    case toggle
}

/// A minimal ViewEffect for testing MVI protocol requirements.
enum TestViewEffect: ViewEffect {
    case showAlert(String)
    case navigateTo(String)
}

// MARK: - MVIProtocolTests

/// Tests for MVI protocol conformance: ViewState Equatable, ViewEffect Equatable.
final class MVIProtocolTests: XCTestCase {

    // MARK: - ViewState Equatable

    func test_viewState_equatable_equalStates() {
        let state1 = TestViewState(name: "test", count: 5, isActive: true)
        let state2 = TestViewState(name: "test", count: 5, isActive: true)

        XCTAssertEqual(state1, state2)
    }

    func test_viewState_equatable_differentName() {
        let state1 = TestViewState(name: "test", count: 5, isActive: true)
        let state2 = TestViewState(name: "other", count: 5, isActive: true)

        XCTAssertNotEqual(state1, state2)
    }

    func test_viewState_equatable_differentCount() {
        let state1 = TestViewState(name: "test", count: 5, isActive: true)
        let state2 = TestViewState(name: "test", count: 10, isActive: true)

        XCTAssertNotEqual(state1, state2)
    }

    func test_viewState_equatable_differentIsActive() {
        let state1 = TestViewState(name: "test", count: 5, isActive: true)
        let state2 = TestViewState(name: "test", count: 5, isActive: false)

        XCTAssertNotEqual(state1, state2)
    }

    // MARK: - ViewEffect Equatable

    func test_viewEffect_equatable_equalEffects() {
        let effect1 = TestViewEffect.showAlert("Error")
        let effect2 = TestViewEffect.showAlert("Error")

        XCTAssertEqual(effect1, effect2)
    }

    func test_viewEffect_equatable_differentMessages() {
        let effect1 = TestViewEffect.showAlert("Error")
        let effect2 = TestViewEffect.showAlert("Warning")

        XCTAssertNotEqual(effect1, effect2)
    }

    func test_viewEffect_equatable_differentCases() {
        let effect1 = TestViewEffect.showAlert("Message")
        let effect2 = TestViewEffect.navigateTo("/path")

        XCTAssertNotEqual(effect1, effect2)
    }

    func test_viewEffect_equatable_equalNavigate() {
        let effect1 = TestViewEffect.navigateTo("/home")
        let effect2 = TestViewEffect.navigateTo("/home")

        XCTAssertEqual(effect1, effect2)
    }

    // MARK: - ChatState Equatable (production type)

    func test_chatState_equatable_equal() {
        let state1 = ChatState(
            messages: [],
            inputText: "hello",
            isStreaming: false,
            streamingText: "",
            currentToolCalls: [],
            error: nil,
            conversation: nil,
            agentStatus: .idle
        )
        let state2 = ChatState(
            messages: [],
            inputText: "hello",
            isStreaming: false,
            streamingText: "",
            currentToolCalls: [],
            error: nil,
            conversation: nil,
            agentStatus: .idle
        )

        XCTAssertEqual(state1, state2)
    }

    func test_chatState_equatable_differentInputText() {
        let state1 = ChatState(inputText: "hello")
        let state2 = ChatState(inputText: "world")

        XCTAssertNotEqual(state1, state2)
    }

    func test_chatState_equatable_differentStreaming() {
        let state1 = ChatState(isStreaming: true)
        let state2 = ChatState(isStreaming: false)

        XCTAssertNotEqual(state1, state2)
    }

    func test_chatState_equatable_differentAgentStatus() {
        let state1 = ChatState(agentStatus: .idle)
        let state2 = ChatState(agentStatus: .running)

        XCTAssertNotEqual(state1, state2)
    }

    func test_chatState_equatable_differentError() {
        let state1 = ChatState(error: "Error A")
        let state2 = ChatState(error: "Error B")

        XCTAssertNotEqual(state1, state2)

        let state3 = ChatState(error: nil)
        XCTAssertNotEqual(state1, state3)
    }

    // MARK: - ChatEffect Equatable (production type)

    func test_chatEffect_equatable_equal() {
        let effect1 = ChatEffect.showError("Something failed")
        let effect2 = ChatEffect.showError("Something failed")

        XCTAssertEqual(effect1, effect2)
    }

    func test_chatEffect_equatable_differentCases() {
        let effect1 = ChatEffect.scrollToBottom
        let effect2 = ChatEffect.showError("Error")

        XCTAssertNotEqual(effect1, effect2)
    }

    func test_chatEffect_scrollToBottom_equal() {
        XCTAssertEqual(ChatEffect.scrollToBottom, ChatEffect.scrollToBottom)
    }

    // MARK: - AgentStatus Equatable

    func test_agentStatus_equatable() {
        XCTAssertEqual(AgentStatus.idle, AgentStatus.idle)
        XCTAssertEqual(AgentStatus.running, AgentStatus.running)
        XCTAssertEqual(AgentStatus.streaming, AgentStatus.streaming)
        XCTAssertNotEqual(AgentStatus.idle, AgentStatus.running)
    }

    func test_agentStatus_allCases() {
        let cases = AgentStatus.allCases
        XCTAssertTrue(cases.contains(.idle))
        XCTAssertTrue(cases.contains(.running))
        XCTAssertTrue(cases.contains(.streaming))
        XCTAssertTrue(cases.contains(.executingTools))
        XCTAssertTrue(cases.contains(.error))
    }

    // MARK: - ToolCallState Equatable

    func test_toolCallState_equatable() {
        let state1 = ToolCallState(id: "1", name: "read", description: "Reading", status: .pending)
        let state2 = ToolCallState(id: "1", name: "read", description: "Reading", status: .pending)
        let state3 = ToolCallState(id: "2", name: "read", description: "Reading", status: .pending)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }

    // MARK: - AgentEvent Equatable

    func test_agentEvent_equatable_streaming() {
        let e1 = AgentEvent.streaming(text: "hello")
        let e2 = AgentEvent.streaming(text: "hello")
        let e3 = AgentEvent.streaming(text: "world")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func test_agentEvent_equatable_thinking() {
        XCTAssertEqual(AgentEvent.thinking, AgentEvent.thinking)
    }

    func test_agentEvent_equatable_cancelled() {
        XCTAssertEqual(AgentEvent.cancelled, AgentEvent.cancelled)
    }

    func test_agentEvent_equatable_differentCases() {
        XCTAssertNotEqual(AgentEvent.thinking, AgentEvent.cancelled)
        XCTAssertNotEqual(AgentEvent.streaming(text: "x"), AgentEvent.thinking)
    }
}
