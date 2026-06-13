import Foundation

// MARK: - ToolProtocol

/// Protocol that all agent tools must conform to.
///
/// Each tool provides metadata (name, description, JSON Schema for
/// parameters) and an executable `execute` method. Tools are registered
/// with `ToolRegistry` and invoked by `AgentRuntime` when the AI model
/// requests tool calls.
///
/// Conforming types should be stateless or hold only references to
/// services; tool execution state is managed externally.
protocol ToolProtocol: AnyObject {

    /// The unique name of the tool, used in API tool definitions
    /// and for lookup in `ToolRegistry`.
    var name: String { get }

    /// A human-readable description of what the tool does.
    /// This is sent to the AI model to help it decide when to
    /// invoke this tool.
    var description: String { get }

    /// The JSON Schema definition of the tool's input parameters.
    /// Describes the expected shape of the `arguments` dictionary
    /// passed to `execute(arguments:)`.
    var parameters: JSONSchema { get }

    /// Executes the tool with the given arguments.
    ///
    /// - Parameter arguments: A dictionary of parameter name to value,
    ///   matching the structure defined by `parameters`.
    /// - Returns: A `ToolResult` indicating success or failure,
    ///   along with any output.
    func execute(arguments: [String: Any]) async throws -> ToolResult
}

// MARK: - Default Implementations

extension ToolProtocol {

    /// Converts this tool's metadata into an API `ToolDefinition`
    /// suitable for inclusion in chat completion requests.
    func toolDefinition() -> ToolDefinition {
        ToolDefinition(
            name: name,
            description: description,
            parameters: parameters.toDictionary()
        )
    }
}

// MARK: - ToolRegistryProtocol

/// Protocol for the tool registry, enabling dependency injection
/// and test mocking.
protocol ToolRegistryProtocol: AnyObject {

    /// Registers a tool with the registry.
    ///
    /// - Parameter tool: The tool to register.
    func register(_ tool: ToolProtocol)

    /// Unregisters a tool by name.
    ///
    /// - Parameter name: The name of the tool to remove.
    func unregister(name: String)

    /// Retrieves a registered tool by name.
    ///
    /// - Parameter name: The name of the tool to retrieve.
    /// - Returns: The tool if registered, or `nil`.
    func getTool(name: String) -> ToolProtocol?

    /// Returns tool definitions for all registered tools,
    /// formatted for inclusion in API requests.
    ///
    /// - Returns: An array of `ToolDefinition` values.
    func allToolDefinitions() -> [ToolDefinition]

    /// Executes a named tool with the given arguments.
    ///
    /// - Parameters:
    ///   - id: A unique call identifier for tracking.
    ///   - name: The name of the tool to execute.
    ///   - arguments: The arguments to pass to the tool.
    /// - Returns: The result of the tool execution.
    func executeTool(
        id: String,
        name: String,
        arguments: [String: Any]
    ) async throws -> ToolResult

    /// Executes multiple tools in parallel.
    ///
    /// - Parameter calls: Array of (id, name, arguments) tuples.
    /// - Returns: Array of results in the same order as calls.
    func executeToolsParallel(
        calls: [(id: String, name: String, arguments: [String: Any])]
    ) async -> [ToolResult]
}
