import Foundation
import Combine

// MARK: - AgentRuntimeProtocol

/// Protocol for the agent runtime, enabling dependency injection
/// and test mocking.
protocol AgentRuntimeProtocol: AnyObject {

    /// Runs the agent with a user message, streaming results via
    /// a Combine publisher of `AgentEvent` values.
    ///
    /// - Parameters:
    ///   - message: The user's input message.
    ///   - modelId: The model identifier to use.
    ///   - conversation: The conversation context with message history.
    /// - Returns: A publisher that emits `AgentEvent` values.
    func run(
        message: String,
        modelId: String,
        conversation: Conversation
    ) -> AnyPublisher<AgentEvent, Never>

    /// Cancels the currently running agent task.
    func cancel()

    /// Whether the agent is currently executing.
    var isRunning: Bool { get }
}

// MARK: - AgentError

/// Errors that can occur during agent execution.
enum AgentError: LocalizedError {
    case maxToolRoundsExceeded(rounds: Int)
    case apiError(String)
    case toolExecutionFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .maxToolRoundsExceeded(let rounds):
            return "Maximum tool execution rounds (\(rounds)) exceeded."
        case .apiError(let message):
            return "API error: \(message)"
        case .toolExecutionFailed(let message):
            return "Tool execution failed: \(message)"
        case .invalidResponse:
            return "Received an invalid response from the API."
        }
    }
}

// MARK: - AgentRuntime

/// The core agent execution loop.
///
/// `AgentRuntime` orchestrates the full agent workflow:
/// 1. Receives a user message
/// 2. Builds an API request with conversation history, system prompt,
///    and tool definitions
/// 3. Streams the response via `APIClient` and parses SSE events
/// 4. Detects tool calls in the response
/// 5. Executes tools via `ToolRegistry` (with permission checks)
/// 6. Injects tool results into the message history
/// 7. Makes follow-up API requests until the model finishes or
///    `maxToolRounds` is reached
///
/// All events are emitted through a Combine publisher as `AgentEvent` values.
final class AgentRuntime: ObservableObject, AgentRuntimeProtocol {

    // MARK: - Published State

    /// Whether the agent is currently running.
    @Published var isRunning: Bool = false

    // MARK: - Dependencies

    /// The API client for streaming requests.
    private let apiClient: APIClientProtocol

    /// The tool registry for executing tool calls.
    private let toolRegistry: ToolRegistryProtocol

    /// The permission manager for tool execution approval.
    private let permissionManager: PermissionManagerProtocol

    /// The conversation manager for persistence.
    private let conversationManager: ConversationManager

    // MARK: - Configuration

    /// Maximum number of tool execution rounds before forcing a stop.
    private let maxToolRounds: Int

    // MARK: - Cancellation

    /// Subject for cancelling the current run.
    private var cancellable: AnyCancellable?
    private let cancelSubject = PassthroughSubject<Void, Never>()

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol,
        toolRegistry: ToolRegistryProtocol = ToolRegistry(),
        permissionManager: PermissionManagerProtocol = PermissionManager(),
        conversationManager: ConversationManager = ConversationManager(),
        maxToolRounds: Int = 10
    ) {
        self.apiClient = apiClient
        self.toolRegistry = toolRegistry
        self.permissionManager = permissionManager
        self.conversationManager = conversationManager
        self.maxToolRounds = maxToolRounds
    }

    // MARK: - AgentRuntimeProtocol

    func run(
        message: String,
        modelId: String,
        conversation: Conversation
    ) -> AnyPublisher<AgentEvent, Never> {
        let subject = PassthroughSubject<AgentEvent, Never>()

        cancellable?.cancel()
        isRunning = true

        Task { [weak self] in
            guard let self = self else { return }

            Logger.agentInfo("Agent run started (model: \(modelId))")

            // Build initial messages from conversation history + new user message.
            var messages = conversation.messages

            let userMessage = Message(
                role: .user,
                content: message,
                timestamp: Date()
            )
            messages.append(userMessage)

            // Append the user message to the persistent conversation.
            self.conversationManager.appendMessage(conversation.id, message: userMessage)

            // Send initial thinking event.
            subject.send(.thinking)

            // Get tool definitions.
            let toolDefinitions = self.toolRegistry.allToolDefinitions()

            // Build the initial API request.
            var apiMessages = self.buildChatMessages(from: messages)

            // Run the agent loop.
            var toolRound = 0
            var accumulatedContent = ""

            while toolRound < self.maxToolRounds {
                // Check cancellation.
                if Task.isCancelled {
                    subject.send(.cancelled)
                    break
                }

                let request = AgentRequest(
                    model: modelId,
                    messages: apiMessages,
                    tools: toolDefinitions.isEmpty ? nil : toolDefinitions,
                    stream: true,
                    maxTokens: 8192,
                    temperature: 0.7,
                    systemPrompt: conversation.systemPrompt,
                    toolChoice: toolDefinitions.isEmpty ? nil : "auto"
                )

                do {
                    var detectedToolCalls: [ToolCall] = []
                    var currentAssistantContent = ""
                    var receivedFinish = false

                    let stream = self.apiClient.sendStreamRequest(request)

                    for try await event in stream {
                        guard !Task.isCancelled else { break }

                        switch event.type {
                        case .content:
                            if let data = event.data {
                                if let text = self.parseContentDelta(data) {
                                    currentAssistantContent += text
                                    accumulatedContent += text
                                    subject.send(.streaming(text: text))
                                }
                            }

                        case .toolCall:
                            if let data = event.data {
                                let toolCalls = self.parseToolCalls(data)
                                if !toolCalls.isEmpty {
                                    detectedToolCalls.append(contentsOf: toolCalls)
                                    subject.send(.toolCallDetected(toolCalls: toolCalls))
                                }
                            }

                        case .finish:
                            receivedFinish = true

                        case .error:
                            if let data = event.data,
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errMsg = json["error"] as? String {
                                subject.send(.error(message: errMsg, underlyingError: nil))
                            }

                        case .ping:
                            break
                        }

                        if receivedFinish { break }
                    }

                    // If tool calls were detected, execute them.
                    if !detectedToolCalls.isEmpty {
                        Logger.agentInfo("Detected \(detectedToolCalls.count) tool calls (round \(toolRound + 1))")

                        // Build assistant message with tool calls.
                        let assistantMsg = Message(
                            role: .assistant,
                            content: currentAssistantContent,
                            toolCalls: detectedToolCalls,
                            timestamp: Date()
                        )
                        apiMessages.append(self.messageToChatMessage(assistantMsg))

                        // Execute tools in parallel.
                        let toolCallsToExecute: [(id: String, name: String, arguments: [String: Any])] =
                            detectedToolCalls.compactMap { tc in
                                guard let args = self.parseArguments(tc.arguments) else { return nil }
                                return (id: tc.id, name: tc.name, arguments: args)
                            }

                        let results = await self.toolRegistry.executeToolsParallel(
                            calls: toolCallsToExecute
                        )

                        // Notify about each result.
                        for result in results {
                            subject.send(.toolCompleted(result: result))
                        }
                        subject.send(.toolRoundCompleted(results: results))

                        // Append tool result messages.
                        for result in results {
                            let content = result.isSuccess
                                ? result.output
                                : "Error: \(result.errorMessage ?? "Unknown error")"

                            let toolMsg = Message(
                                role: .tool,
                                content: content,
                                toolCallId: result.toolCallId,
                                timestamp: Date()
                            )
                            apiMessages.append(self.messageToChatMessage(toolMsg))
                        }

                        toolRound += 1
                        subject.send(.thinking)
                        continue
                    }

                    // No tool calls: final response received.
                    let finalAssistantMsg = Message(
                        role: .assistant,
                        content: accumulatedContent.isEmpty
                            ? currentAssistantContent
                            : accumulatedContent + currentAssistantContent,
                        timestamp: Date()
                    )
                    self.conversationManager.appendMessage(
                        conversation.id,
                        message: finalAssistantMsg
                    )

                    subject.send(.finished(finalMessage: finalAssistantMsg))
                    Logger.agentInfo("Agent run completed successfully")
                    break

                } catch {
                    if let apiError = error as? APIClientError,
                       apiError.localizedDescription.contains("cancelled") {
                        subject.send(.cancelled)
                    } else {
                        Logger.error("Agent error: \(error.localizedDescription)")
                        subject.send(
                            .error(
                                message: error.localizedDescription,
                                underlyingError: error
                            )
                        )
                    }
                    break
                }
            }

            if toolRound >= self.maxToolRounds {
                let error = AgentError.maxToolRoundsExceeded(rounds: toolRound)
                subject.send(.error(message: error.localizedDescription, underlyingError: error))
            }

            subject.send(completion: .finished)
            Logger.agentInfo("Agent run ended")
            self.isRunning = false
        }

        return subject
            .handleEvents(receiveCancel: { [weak self] in
                self?.isRunning = false
            })
            .eraseToAnyPublisher()
    }

    func cancel() {
        isRunning = false
        apiClient.cancelAllRequests()
        Logger.agentInfo("Agent run cancelled by user")
    }

    // MARK: - Private Helpers

    /// Converts domain `Message` objects to API `ChatMessage` objects.
    private func buildChatMessages(from messages: [Message]) -> [ChatMessage] {
        messages.map { messageToChatMessage($0) }
    }

    /// Converts a single domain `Message` to an API `ChatMessage`.
    private func messageToChatMessage(_ message: Message) -> ChatMessage {
        let role: String
        let content: ContentType

        switch message.role {
        case .user:
            role = "user"
            content = .text(message.content)
        case .assistant:
            role = "assistant"
            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                let toolCallJSONs: [ToolCallJSON] = toolCalls.map { tc in
                    ToolCallJSON(
                        id: tc.id,
                        function: FunctionCall(name: tc.name, arguments: tc.arguments),
                        type: "function"
                    )
                }
                content = .toolCall(toolCallJSONs)
            } else {
                content = .text(message.content)
            }
        case .system:
            role = "system"
            content = .text(message.content)
        case .tool:
            role = "tool"
            content = .toolResult(ToolResultJSON(
                toolCallId: message.toolCallId ?? "",
                content: message.content,
                isError: message.content.hasPrefix("Error:")
            ))
        }

        return ChatMessage(role: role, content: content)
    }

    /// Parses a content delta from an SSE data payload.
    private func parseContentDelta(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Anthropic format: { "type": "content_block_delta", "delta": { "type": "text_delta", "text": "..." } }
        if let type = json["type"] as? String, type == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }

        // OpenAI format: { "choices": [{ "delta": { "content": "..." } }] }
        if let choices = json["choices"] as? [[String: Any]],
           let choice = choices.first,
           let delta = choice["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            return content
        }

        return nil
    }

    /// Parses tool calls from an SSE data payload.
    private func parseToolCalls(_ data: Data) -> [ToolCall] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var calls: [ToolCall] = []

        // Anthropic format.
        if let type = json["type"] as? String,
           type == "content_block_start",
           let contentBlock = json["content_block"] as? [String: Any],
           let blockType = contentBlock["type"] as? String,
           blockType == "tool_use",
           let name = contentBlock["name"] as? String,
           let callId = contentBlock["id"] as? String {
            var args: [String: Any] = [:]
            if let input = contentBlock["input"] as? [String: Any] {
                args = input
            }
            let argsJSON = (try? String(
                data: JSONSerialization.data(withJSONObject: args),
                encoding: .utf8
            )) ?? "{}"
            calls.append(ToolCall(id: callId, name: name, arguments: argsJSON))
        }

        // OpenAI format: { "choices": [{ "delta": { "tool_calls": [...] } }] }
        if let choices = json["choices"] as? [[String: Any]],
           let choice = choices.first,
           let delta = choice["delta"] as? [String: Any],
           let toolCalls = delta["tool_calls"] as? [[String: Any]] {
            for tc in toolCalls {
                if let id = tc["id"] as? String,
                   let function = tc["function"] as? [String: Any],
                   let name = function["name"] as? String {
                    let arguments = function["arguments"] as? String ?? "{}"
                    calls.append(ToolCall(id: id, name: name, arguments: arguments))
                }
            }
        }

        return calls
    }

    /// Parses a JSON-encoded arguments string into a dictionary.
    private func parseArguments(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}
