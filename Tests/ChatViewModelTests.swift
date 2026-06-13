import XCTest
import Combine
@testable import ios_agent_app

// MARK: - Mock AgentRuntime

/// Mock AgentRuntimeProtocol for ChatViewModel testing.
final class MockAgentRuntime: AgentRuntimeProtocol {
    var isRunning: Bool = false
    var events: [AgentEvent] = []
    private let subject = PassthroughSubject<AgentEvent, Never>()
    var cancelCallCount = 0

    func run(
        message: String,
        modelId: String,
        conversation: Conversation
    ) -> AnyPublisher<AgentEvent, Never> {
        isRunning = true
        return subject.eraseToAnyPublisher()
    }

    func sendEvent(_ event: AgentEvent) {
        subject.send(event)
    }

    func sendCompletion() {
        subject.send(completion: .finished)
        isRunning = false
    }

    func cancel() {
        cancelCallCount += 1
        isRunning = false
    }
}

// MARK: - Mock PermissionManager

/// Mock PermissionManagerProtocol for ChatViewModel testing.
final class MockPermissionManager: PermissionManagerProtocol {
    var autoApproveReadOnly = false
    var trustedPaths: [String] = []
    var permissionDecision: PermissionDecision = .approved

    func requestPermission(
        toolName: String,
        description: String,
        path: String?
    ) async -> PermissionDecision {
        permissionDecision
    }

    func isPathTrusted(_ path: String) -> Bool {
        trustedPaths.contains(where: { path.hasPrefix($0) })
    }

    func setAutoApproveReadOnly(_ enabled: Bool) {
        autoApproveReadOnly = enabled
    }

    func setTrustedPaths(_ paths: [String]) {
        trustedPaths = paths
    }
}

// MARK: - ChatViewModelTests

/// Tests for ChatViewModel: state transitions, agent event processing,
/// intent dispatch, streaming state management.
@MainActor
final class ChatViewModelTests: XCTestCase {

    private var viewModel: ChatViewModel!
    private var mockAgent: MockAgentRuntime!
    private var mockPermission: MockPermissionManager!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        mockAgent = MockAgentRuntime()
        mockPermission = MockPermissionManager()
        cancellables = []
        viewModel = ChatViewModel(
            agentRuntime: mockAgent,
            permissionManager: mockPermission
        )
    }

    override func tearDown() async throws {
        cancellables = nil
        viewModel = nil
        mockAgent = nil
        mockPermission = nil
        try await super.tearDown()
    }

    // MARK: - State Initial Values

    func test_initialState_isIdle() {
        XCTAssertEqual(viewModel.state.agentStatus, .idle)
        XCTAssertFalse(viewModel.state.isStreaming)
        XCTAssertEqual(viewModel.state.streamingText, "")
        XCTAssertEqual(viewModel.state.messages.count, 0)
        XCTAssertNil(viewModel.state.error)
    }

    // MARK: - sendMessage Intent

    func test_sendMessage_setsIsStreamingTrue() {
        viewModel.dispatch(.updateInputText("Hello, agent!"))
        viewModel.dispatch(.sendMessage("Hello, agent!"))

        XCTAssertTrue(viewModel.state.isStreaming)
        XCTAssertEqual(viewModel.state.agentStatus, .running)
        XCTAssertEqual(viewModel.state.inputText, "")
    }

    func test_sendMessage_appendsUserMessage() {
        viewModel.dispatch(.updateInputText("Test message"))
        viewModel.dispatch(.sendMessage("Test message"))

        XCTAssertEqual(viewModel.state.messages.count, 1)
        XCTAssertEqual(viewModel.state.messages[0].role, .user)
        XCTAssertEqual(viewModel.state.messages[0].content, "Test message")
    }

    func test_sendMessage_emptyText_doesNothing() {
        viewModel.dispatch(.sendMessage("   "))

        XCTAssertEqual(viewModel.state.messages.count, 0)
        XCTAssertFalse(viewModel.state.isStreaming)
    }

    func test_sendMessage_whenNotIdle_doesNothing() {
        // Simulate agent already running.
        viewModel.dispatch(.updateInputText("First"))
        viewModel.dispatch(.sendMessage("First"))

        // Try to send while streaming.
        viewModel.dispatch(.updateInputText("Second"))
        viewModel.dispatch(.sendMessage("Second"))

        // Only one message should exist.
        XCTAssertEqual(viewModel.state.messages.count, 1)
    }

    func test_sendMessage_createsConversation_whenNil() {
        XCTAssertNil(viewModel.state.conversation)

        viewModel.dispatch(.updateInputText("Start"))
        viewModel.dispatch(.sendMessage("Start"))

        XCTAssertNotNil(viewModel.state.conversation)
    }

    // MARK: - AgentEvent.streaming

    func test_streamingEvent_updatesStreamingText() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        // Events must be sent AFTER subscription (after sendMessage calls agentRuntime.run()).
        mockAgent.sendEvent(.streaming(text: "Hello"))
        mockAgent.sendEvent(.streaming(text: " World"))

        // Events should accumulate streaming text.
        XCTAssertTrue(viewModel.state.streamingText.contains("Hello"))
    }

    func test_streamingEvent_setsAgentStatusToStreaming() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        mockAgent.sendEvent(.streaming(text: "response"))

        XCTAssertEqual(viewModel.state.agentStatus, .streaming)
    }

    // MARK: - AgentEvent.finished

    func test_finishedEvent_setsIsStreamingFalse() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        let finalMessage = Message(role: .assistant, content: "Response")
        mockAgent.sendEvent(.finished(finalMessage: finalMessage))

        XCTAssertFalse(viewModel.state.isStreaming)
        XCTAssertEqual(viewModel.state.agentStatus, .idle)
        XCTAssertEqual(viewModel.state.streamingText, "")
    }

    func test_finishedEvent_appendsAssistantMessage() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        let finalMessage = Message(role: .assistant, content: "The response")
        mockAgent.sendEvent(.finished(finalMessage: finalMessage))

        XCTAssertEqual(viewModel.state.messages.count, 2)
        XCTAssertEqual(viewModel.state.messages[1].role, .assistant)
        XCTAssertEqual(viewModel.state.messages[1].content, "The response")
    }

    // MARK: - AgentEvent.error

    func test_errorEvent_setsErrorState() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        mockAgent.sendEvent(.error(message: "Something broke", underlyingError: nil))

        XCTAssertEqual(viewModel.state.agentStatus, .error)
        XCTAssertFalse(viewModel.state.isStreaming)
        XCTAssertEqual(viewModel.state.error, "Something broke")
    }

    // MARK: - AgentEvent.cancelled

    func test_cancelledEvent_resetsState() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        mockAgent.sendEvent(.cancelled)

        XCTAssertEqual(viewModel.state.agentStatus, .idle)
        XCTAssertFalse(viewModel.state.isStreaming)
        XCTAssertEqual(viewModel.state.streamingText, "")
    }

    // MARK: - AgentEvent.toolCallDetected

    func test_toolCallDetected_addsToolCallStates() {
        viewModel.dispatch(.updateInputText("Read my file"))
        viewModel.dispatch(.sendMessage("Read my file"))

        let toolCall = ToolCall(id: "tc1", name: "read_file", arguments: "{\"path\":\"/tmp/test.txt\"}")
        mockAgent.sendEvent(.toolCallDetected(toolCalls: [toolCall]))

        XCTAssertEqual(viewModel.state.agentStatus, .executingTools)
        XCTAssertEqual(viewModel.state.currentToolCalls.count, 1)
        XCTAssertEqual(viewModel.state.currentToolCalls[0].id, "tc1")
        XCTAssertEqual(viewModel.state.currentToolCalls[0].name, "read_file")
    }

    func test_toolCallDetected_updatesExistingToolCall() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        let toolCall = ToolCall(id: "tc1", name: "edit_file", arguments: "{}")
        mockAgent.sendEvent(.toolCallDetected(toolCalls: [toolCall]))
        // Send again with same ID.
        mockAgent.sendEvent(.toolCallDetected(toolCalls: [toolCall]))

        // Should not duplicate.
        XCTAssertEqual(viewModel.state.currentToolCalls.count, 1)
    }

    // MARK: - AgentEvent.toolCompleted

    func test_toolCompleted_updatesToolCallStatus() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        let toolCall = ToolCall(id: "tc1", name: "read_file", arguments: "{}")
        mockAgent.sendEvent(.toolCallDetected(toolCalls: [toolCall]))

        let result = ToolResult(toolCallId: "tc1", toolName: "read_file", status: .success, output: "file content")
        mockAgent.sendEvent(.toolCompleted(result: result))

        XCTAssertEqual(viewModel.state.currentToolCalls[0].status, .completed)
        XCTAssertEqual(viewModel.state.currentToolCalls[0].output, "file content")
    }

    func test_toolCompleted_failed_setsFailedStatus() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        let toolCall = ToolCall(id: "tc1", name: "read_file", arguments: "{}")
        mockAgent.sendEvent(.toolCallDetected(toolCalls: [toolCall]))

        let result = ToolResult(
            toolCallId: "tc1",
            toolName: "read_file",
            status: .error,
            output: "",
            errorMessage: "File not found"
        )
        mockAgent.sendEvent(.toolCompleted(result: result))

        XCTAssertEqual(viewModel.state.currentToolCalls[0].status, .failed)
        XCTAssertEqual(viewModel.state.currentToolCalls[0].errorMessage, "File not found")
    }

    // MARK: - clearConversation Intent

    func test_clearConversation_resetsAllState() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        viewModel.dispatch(.clearConversation)

        XCTAssertEqual(viewModel.state.messages.count, 0)
        XCTAssertEqual(viewModel.state.agentStatus, .idle)
        XCTAssertEqual(viewModel.state.streamingText, "")
        XCTAssertNil(viewModel.state.error)
        XCTAssertTrue(viewModel.state.currentToolCalls.isEmpty)
    }

    // MARK: - stopGeneration Intent

    func test_stopGeneration_callsAgentCancel() {
        viewModel.dispatch(.updateInputText("Hi"))
        viewModel.dispatch(.sendMessage("Hi"))

        viewModel.dispatch(.stopGeneration)

        XCTAssertEqual(mockAgent.cancelCallCount, 1)
        XCTAssertEqual(viewModel.state.agentStatus, .idle)
        XCTAssertFalse(viewModel.state.isStreaming)
    }

    // MARK: - loadConversation Intent

    func test_loadConversation_populatesState() {
        let conversation = Conversation(
            id: UUID(),
            title: "Test Conversation",
            messages: [
                Message(role: .user, content: "Hello"),
                Message(role: .assistant, content: "Hi there!"),
            ]
        )

        viewModel.dispatch(.loadConversation(conversation))

        XCTAssertEqual(viewModel.state.conversation?.title, "Test Conversation")
        XCTAssertEqual(viewModel.state.messages.count, 2)
        XCTAssertEqual(viewModel.state.agentStatus, .idle)
    }

    // MARK: - CanSend Computed Property

    func test_canSend_true_whenIdleAndHasInput() {
        viewModel.dispatch(.updateInputText("Hello"))

        XCTAssertTrue(viewModel.state.canSend)
    }

    func test_canSend_false_whenStreaming() {
        viewModel.dispatch(.updateInputText("Hello"))
        viewModel.dispatch(.sendMessage("Hello"))

        XCTAssertFalse(viewModel.state.canSend)
    }

    func test_canSend_false_whenInputEmpty() {
        XCTAssertFalse(viewModel.state.canSend)
    }
}
