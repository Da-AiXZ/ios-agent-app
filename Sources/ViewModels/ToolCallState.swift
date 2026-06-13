import Foundation

// MARK: - ToolCallStatus

/// The lifecycle status of a tool invocation within the agent execution loop.
@frozen
enum ToolCallStatus: String, Equatable, CaseIterable {

    /// The tool call has been detected but not yet processed.
    case pending

    /// The tool is waiting for user permission approval.
    case waitingPermission

    /// The tool is currently executing.
    case executing

    /// The tool completed successfully.
    case completed

    /// The tool execution failed with an error.
    case failed

    /// The user denied permission for this tool call.
    case denied
}

// MARK: - ToolCallState

/// Observable state for a single tool invocation in the UI.
///
/// Tracks the tool's identity, description, execution status,
/// and any result or error output. The `ChatViewModel` manages
/// a collection of these to display tool call cards.
struct ToolCallState: Identifiable, Equatable {

    /// Unique identifier matching the tool call ID from the API.
    let id: String

    /// The name of the tool being invoked.
    let name: String

    /// A human-readable description of what the tool is doing.
    let description: String

    /// The current lifecycle status of this tool call.
    var status: ToolCallStatus

    /// The output produced by the tool, if it completed successfully.
    var output: String?

    /// An error message if the tool failed.
    var errorMessage: String?

    // MARK: - Initialization

    init(
        id: String,
        name: String,
        description: String = "",
        status: ToolCallStatus = .pending,
        output: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.output = output
        self.errorMessage = errorMessage
    }
}
