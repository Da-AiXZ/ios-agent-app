import Foundation
import Combine
import SwiftUI

// MARK: - AgentStatus

/// The current operational status of the agent runtime.
@frozen
enum AgentStatus: String, Equatable, CaseIterable {
    /// The agent is idle and ready to receive input.
    case idle

    /// The agent is running (processing a message).
    case running

    /// The agent is currently streaming text from the API.
    case streaming

    /// The agent is executing tool calls.
    case executingTools

    /// The agent encountered an error.
    case error
}

// MARK: - ChatState

/// The complete UI state for the chat screen.
struct ChatState: ViewState {

    /// The ordered list of messages in the active conversation.
    var messages: [Message] = []

    /// The text currently in the user input field.
    var inputText: String = ""

    /// Whether the agent is currently streaming a response.
    var isStreaming: Bool = false

    /// The accumulated streaming text for the current response.
    var streamingText: String = ""

    /// The tool calls currently active in the UI.
    var currentToolCalls: [ToolCallState] = []

    /// An error message to display, if any.
    var error: String?

    /// The currently active conversation.
    var conversation: Conversation?

    /// The operational status of the agent.
    var agentStatus: AgentStatus = .idle

    /// Whether the user can send a new message right now.
    var canSend: Bool {
        agentStatus == .idle && inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

// MARK: - ChatIntent

/// User actions that the ChatViewModel can process.
@frozen
enum ChatIntent: ViewIntent {
    /// Send a message with the given text.
    case sendMessage(String)

    /// Retry the last failed message.
    case retryLastMessage

    /// Clear all messages and start a new conversation.
    case clearConversation

    /// Stop the currently running agent generation.
    case stopGeneration

    /// Approve a pending tool call identified by ID.
    case approveTool(toolCallId: String)

    /// Deny a pending tool call identified by ID.
    case denyTool(toolCallId: String)

    /// Load a specific conversation from history.
    case loadConversation(Conversation)

    /// Update the text in the input field.
    case updateInputText(String)

    /// Refresh the conversation list from the manager.
    case refreshConversations
}

// MARK: - ChatEffect

/// One-time side effects from the ChatViewModel.
@frozen
enum ChatEffect: ViewEffect {
    /// Show an error alert with the given message.
    case showError(String)

    /// Scroll the message list to the bottom.
    case scrollToBottom

    /// Navigate to open a file at the given URL.
    case navigateToFile(URL)

    /// Show a tool approval dialog.
    case showToolApproval(ToolCallState)
}

// MARK: - ChatViewModel

/// ViewModel for the core chat interface.
///
/// Manages message history, agent communication streaming, tool call
/// state, and user input. Subscribes to `AgentRuntime` events and maps
/// them to state transitions following the MVI pattern.
///
/// State is published via `@Published chatState` for SwiftUI observation.
/// Effects are emitted through a `PassthroughSubject` for one-time actions.
@MainActor
final class ChatViewModel: MVIViewModel, ObservableObject {

    // MARK: - MVIViewModel

    typealias State = ChatState
    typealias Intent = ChatIntent
    typealias Effect = ChatEffect

    @Published var state: ChatState = ChatState()

    var effects: AnyPublisher<Effect, Never> {
        effectsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var agentRuntime: AgentRuntimeProtocol
    private let conversationManager: ConversationManager
    private let permissionManager: PermissionManagerProtocol

    private var effectsSubject = PassthroughSubject<Effect, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        agentRuntime: AgentRuntimeProtocol,
        conversationManager: ConversationManager = ConversationManager(),
        permissionManager: PermissionManagerProtocol = PermissionManager()
    ) {
        self.agentRuntime = agentRuntime
        self.conversationManager = conversationManager
        self.permissionManager = permissionManager

        // Subscribe to permission manager pending requests.
        observePermissionRequests()
    }

    // MARK: - Dynamic Reconfiguration

    /// Updates the agent runtime with a new instance (e.g., after
    /// settings save with new API credentials).
    func reconfigureAgentRuntime(_ newRuntime: AgentRuntimeProtocol) {
        self.agentRuntime = newRuntime
        Logger.info("ChatViewModel AgentRuntime reconfigured")
    }

    // MARK: - Intent Dispatch

    func dispatch(_ intent: ChatIntent) {
        switch intent {
        case .sendMessage(let text):
            handleSendMessage(text)
        case .retryLastMessage:
            handleRetry()
        case .clearConversation:
            handleClearConversation()
        case .stopGeneration:
            handleStopGeneration()
        case .approveTool(let callId):
            handleApproveTool(callId)
        case .denyTool(let callId):
            handleDenyTool(callId)
        case .loadConversation(let conversation):
            handleLoadConversation(conversation)
        case .updateInputText(let text):
            var updated = state
            updated.inputText = text
            state = updated
        case .refreshConversations:
            conversationManager.load()
        }
    }

    // MARK: - Intent Handlers

    /// Creates a new conversation, dispatches the user message to the
    /// agent runtime, and subscribes to agent events for streaming.
    private func handleSendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard state.agentStatus == .idle else { return }

        Logger.uiInfo("Sending message: \(trimmed.prefix(50))...")

        // Ensure we have an active conversation.
        var conversation = state.conversation
        if conversation == nil {
            conversation = conversationManager.create()
        }

        // Append user message.
        let userMessage = Message(role: .user, content: trimmed)
        conversationManager.appendMessage(conversation!.id, message: userMessage)

        // Update state: add user message, clear input, start streaming.
        var updated = state
        updated.conversation = conversation
        updated.messages.append(userMessage)
        updated.inputText = ""
        updated.isStreaming = true
        updated.streamingText = ""
        updated.currentToolCalls = []
        updated.error = nil
        updated.agentStatus = .running
        state = updated

        effectsSubject.send(.scrollToBottom)

        // Start the agent run.
        var accumulatedText = ""

        agentRuntime.run(
            message: trimmed,
            modelId: conversation?.modelId ?? AppConstants.defaultModelId,
            conversation: updated.conversation!
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            // Completion — handled in individual events.
        } receiveValue: { [weak self] event in
            self?.processAgentEvent(event, accumulatedText: &accumulatedText)
        }
        .store(in: &cancellables)
    }

    /// Retries the last agent interaction by resending the most recent
    /// user message after stopping any in-progress generation.
    private func handleRetry() {
        // Stop any current generation first.
        if state.isStreaming {
            agentRuntime.cancel()
        }

        guard let lastUserMessage = state.messages.last(where: { $0.role == .user }) else {
            return
        }
        // Remove the last assistant/tool messages before retrying.
        var updated = state
        while let last = updated.messages.last, last.role != .user {
            updated.messages.removeLast()
        }
        updated.isStreaming = false
        updated.streamingText = ""
        updated.agentStatus = .idle
        updated.error = nil
        state = updated
        handleSendMessage(lastUserMessage.content)
    }

    /// Clears the current conversation and creates a new one.
    private func handleClearConversation() {
        var updated = state
        updated.messages = []
        updated.streamingText = ""
        updated.currentToolCalls = []
        updated.error = nil
        updated.agentStatus = .idle
        updated.conversation = conversationManager.create()
        state = updated
        Logger.uiInfo("Conversation cleared")
    }

    /// Stops the current agent generation.
    private func handleStopGeneration() {
        agentRuntime.cancel()
        var updated = state
        updated.agentStatus = .idle
        updated.isStreaming = false
        state = updated
        Logger.uiInfo("Generation stopped by user")
    }

    /// Approves a tool call that is waiting for user permission.
    private func handleApproveTool(_ callId: String) {
        guard let index = state.currentToolCalls.firstIndex(where: { $0.id == callId }) else {
            return
        }
        var updated = state
        updated.currentToolCalls[index].status = .executing
        state = updated

        // Resolve the permission request.
        if let pending = permissionManager as? PermissionManager,
           let request = pending.pendingRequest,
           request.toolCallId == callId {
            request.onApprove()
        }
    }

    /// Denies a tool call that is waiting for user permission.
    private func handleDenyTool(_ callId: String) {
        guard let index = state.currentToolCalls.firstIndex(where: { $0.id == callId }) else {
            return
        }
        var updated = state
        updated.currentToolCalls[index].status = .denied
        state = updated

        // Resolve the permission request.
        if let pending = permissionManager as? PermissionManager,
           let request = pending.pendingRequest,
           request.toolCallId == callId {
            request.onDeny()
        }
    }

    /// Loads a conversation from history into the UI.
    private func handleLoadConversation(_ conversation: Conversation) {
        var updated = state
        updated.conversation = conversation
        updated.messages = conversation.messages
        updated.streamingText = ""
        updated.currentToolCalls = []
        updated.error = nil
        updated.agentStatus = .idle
        state = updated
        effectsSubject.send(.scrollToBottom)
        Logger.uiInfo("Loaded conversation: \(conversation.title)")
    }

    // MARK: - Agent Event Processing

    /// Maps an `AgentEvent` from the runtime to state mutations.
    private func processAgentEvent(_ event: AgentEvent, accumulatedText: inout String) {
        var updated = state

        switch event {
        case .streaming(let text):
            accumulatedText += text
            updated.streamingText = accumulatedText
            updated.agentStatus = .streaming
            state = updated

        case .thinking:
            updated.agentStatus = .running
            state = updated

        case .toolCallDetected(let toolCalls):
            updated.agentStatus = .executingTools
            // Create or update tool call states.
            for tc in toolCalls {
                if let index = updated.currentToolCalls.firstIndex(where: { $0.id == tc.id }) {
                    updated.currentToolCalls[index].status = .pending
                } else {
                    updated.currentToolCalls.append(ToolCallState(
                        id: tc.id,
                        name: tc.name,
                        description: "Executing \(tc.name)...",
                        status: .pending
                    ))
                }
            }
            state = updated

        case .toolExecuting(let callId):
            if let index = updated.currentToolCalls.firstIndex(where: { $0.id == callId }) {
                updated.currentToolCalls[index].status = .executing
            }
            state = updated

        case .toolCompleted(let result):
            if let index = updated.currentToolCalls.firstIndex(where: { $0.id == result.toolCallId }) {
                updated.currentToolCalls[index].status = result.isSuccess ? .completed : .failed
                updated.currentToolCalls[index].output = result.output
                updated.currentToolCalls[index].errorMessage = result.errorMessage
            }
            state = updated

        case .toolRoundCompleted(let results):
            // All tools for this round done. If there were errors, note them.
            let failures = results.filter { !$0.isSuccess }
            if !failures.isEmpty {
                Logger.warning("\(failures.count) tool(s) failed")
            }
            state = updated

        case .finished(let finalMessage):
            accumulatedText = ""
            updated.messages.append(finalMessage)
            updated.streamingText = ""
            updated.isStreaming = false
            updated.agentStatus = .idle
            state = updated
            effectsSubject.send(.scrollToBottom)
            Logger.uiInfo("Agent response complete")

        case .error(let message, let underlyingError):
            accumulatedText = ""
            updated.error = message
            updated.isStreaming = false
            updated.agentStatus = .error
            updated.streamingText = ""
            state = updated
            effectsSubject.send(.showError(message))
            Logger.error("Agent error: \(message)")

        case .cancelled:
            accumulatedText = ""
            updated.isStreaming = false
            updated.agentStatus = .idle
            updated.streamingText = ""
            state = updated

        case .planProposed(let actions):
            updated.agentStatus = .running
            state = updated
            Logger.uiInfo("Plan proposed with \(actions.count) actions")
        }
    }

    // MARK: - Permission Observation

    /// Observes the `PermissionManager.pendingRequest` publisher
    /// to update the corresponding tool call state when permission
    /// is required.
    private func observePermissionRequests() {
        guard let permMgr = permissionManager as? PermissionManager else { return }

        permMgr.$pendingRequest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request in
                guard let self = self, let request = request else { return }

                var updated = self.state
                if let index = updated.currentToolCalls.firstIndex(where: { $0.id == request.toolCallId }) {
                    updated.currentToolCalls[index].status = .waitingPermission
                } else {
                    // Create a new tool call state for the permission request.
                    updated.currentToolCalls.append(ToolCallState(
                        id: request.toolCallId,
                        name: request.toolName,
                        description: request.description,
                        status: .waitingPermission
                    ))
                }
                self.state = updated
            }
            .store(in: &cancellables)
    }
}
