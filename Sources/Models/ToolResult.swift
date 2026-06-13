import Foundation

// MARK: - ToolResultStatus

/// The execution status of a tool invocation.
@frozen
enum ToolResultStatus: String, Codable, CaseIterable {
    /// The tool executed successfully and produced output.
    case success

    /// The tool encountered an error during execution.
    case error

    /// The tool invocation is queued or in progress.
    case pending
}

// MARK: - ToolResult

/// Encapsulates the result of a tool execution invoked by the AI agent.
///
/// Each `ToolResult` links back to its originating `toolCallId`, records
/// the tool name, execution status, output or error message, and
/// performance timing information.
struct ToolResult: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for this tool result.
    let id: UUID

    /// The ID of the `ToolCall` that this result corresponds to.
    var toolCallId: String

    /// The name of the executed tool.
    var toolName: String

    /// The execution status indicator.
    var status: ToolResultStatus

    /// The textual output produced by the tool on success.
    /// Empty string when status is `.error` or `.pending`.
    var output: String

    /// A human-readable error description when `status` is `.error`.
    /// `nil` for successful or pending executions.
    var errorMessage: String?

    /// The timestamp when the tool execution completed.
    var executedAt: Date

    /// Total execution duration in milliseconds.
    var durationMs: Double

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        toolCallId: String,
        toolName: String,
        status: ToolResultStatus = .pending,
        output: String = "",
        errorMessage: String? = nil,
        executedAt: Date = Date(),
        durationMs: Double = 0
    ) {
        self.id = id
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.status = status
        self.output = output
        self.errorMessage = errorMessage
        self.executedAt = executedAt
        self.durationMs = durationMs
    }

    // MARK: - Computed Properties

    /// Returns `true` if the tool executed without errors.
    var isSuccess: Bool {
        status == .success
    }

    /// Returns a formatted duration string (e.g., "350ms" or "1.2s").
    var formattedDuration: String {
        if durationMs < 1000 {
            return String(format: "%.0fms", durationMs)
        }
        return String(format: "%.1fs", durationMs / 1000)
    }
}
