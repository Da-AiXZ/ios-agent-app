import Foundation

/// Events emitted by the AgentRuntime during the agent execution loop.
///
/// These events are delivered through a Combine publisher and consumed
/// by the ViewModel layer to update the UI. Each event represents a
/// state transition in the agent's message processing pipeline.
enum AgentEvent {

    /// A chunk of streaming text from the AI model.
    /// The ViewModel should accumulate these for display.
    case streaming(text: String)

    /// The AI model has requested one or more tool invocations.
    /// The UI should display tool call cards and await execution.
    case toolCallDetected(toolCalls: [ToolCall])

    /// A specific tool invocation has started executing.
    /// The UI can show an in-progress indicator for this tool.
    case toolExecuting(callId: String)

    /// A tool invocation has completed with a result.
    /// The UI should update the tool card with the result.
    case toolCompleted(result: ToolResult)

    /// All tool executions for this round have completed.
    /// The agent is preparing the next API request.
    case toolRoundCompleted(results: [ToolResult])

    /// The agent has finished processing and produced a final message.
    /// This is the terminal event for a successful agent run.
    case finished(finalMessage: Message)

    /// An error occurred during agent execution.
    /// Contains the error description and optionally the original error.
    case error(message: String, underlyingError: Error?)

    /// The agent run was cancelled by the user.
    case cancelled

    /// Plan mode: the agent has produced a plan and is awaiting
    /// user approval before proceeding with tool execution.
    case planProposed(actions: [String])

    /// The agent is thinking or processing between steps.
    /// The UI can show a typing indicator.
    case thinking
}

// MARK: - Equatable

extension AgentEvent: Equatable {
    static func == (lhs: AgentEvent, rhs: AgentEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.streaming(lhsText), .streaming(rhsText)):
            return lhsText == rhsText
        case let (.toolCallDetected(lhsCalls), .toolCallDetected(rhsCalls)):
            return lhsCalls.map(\.id) == rhsCalls.map(\.id)
        case let (.toolExecuting(lhsId), .toolExecuting(rhsId)):
            return lhsId == rhsId
        case let (.toolCompleted(lhsResult), .toolCompleted(rhsResult)):
            return lhsResult.id == rhsResult.id
        case let (.toolRoundCompleted(lhsResults), .toolRoundCompleted(rhsResults)):
            return lhsResults.map(\.id) == rhsResults.map(\.id)
        case let (.finished(lhsMsg), .finished(rhsMsg)):
            return lhsMsg.id == rhsMsg.id
        case let (.error(lhsMsg, _), .error(rhsMsg, _)):
            return lhsMsg == rhsMsg
        case (.cancelled, .cancelled):
            return true
        case let (.planProposed(lhsActions), .planProposed(rhsActions)):
            return lhsActions == rhsActions
        case (.thinking, .thinking):
            return true
        default:
            return false
        }
    }
}
