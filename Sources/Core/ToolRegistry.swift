import Foundation

/// Central registry for all agent tools.
///
/// `ToolRegistry` maintains the canonical set of available tools,
/// provides tool definitions for API requests, and dispatches
/// tool execution calls. It supports parallel execution of
/// multiple tools via Swift Concurrency's `TaskGroup`.
final class ToolRegistry: ToolRegistryProtocol {

    // MARK: - Properties

    /// Internal map of tool name to tool instance.
    private var tools: [String: ToolProtocol] = [:]

    /// Serial queue for thread-safe access to the tools dictionary.
    private let lockQueue = DispatchQueue(label: "com.ios-agent-app.toolregistry")

    // MARK: - Initialization

    init() {}

    // MARK: - ToolRegistryProtocol

    func register(_ tool: ToolProtocol) {
        lockQueue.sync {
            tools[tool.name] = tool
        }
        Logger.info("Registered tool: \(tool.name)")
    }

    func unregister(name: String) {
        lockQueue.sync {
            tools.removeValue(forKey: name)
        }
        Logger.info("Unregistered tool: \(name)")
    }

    func getTool(name: String) -> ToolProtocol? {
        lockQueue.sync {
            tools[name]
        }
    }

    func allToolDefinitions() -> [ToolDefinition] {
        lockQueue.sync {
            tools.values.map { $0.toolDefinition() }
        }
    }

    func executeTool(
        id: String,
        name: String,
        arguments: [String: Any]
    ) async throws -> ToolResult {
        guard let tool = getTool(name: name) else {
            Logger.error("Tool not found: \(name)")
            return ToolResult(
                toolCallId: id,
                toolName: name,
                status: .error,
                output: "",
                errorMessage: "Tool '\(name)' is not registered.",
                durationMs: 0
            )
        }

        let startTime = Date()
        Logger.agentInfo("Executing tool: \(name)")

        do {
            let result = try await tool.execute(arguments: arguments)
            let duration = Date().timeIntervalSince(startTime) * 1000

            var updatedResult = result
            updatedResult.toolCallId = id
            updatedResult.toolName = name
            updatedResult.durationMs = duration

            Logger.agentInfo("Tool '\(name)' completed in \(String(format: "%.0f", duration))ms")
            return updatedResult
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            Logger.error("Tool '\(name)' failed: \(error.localizedDescription)")

            return ToolResult(
                toolCallId: id,
                toolName: name,
                status: .error,
                output: "",
                errorMessage: error.localizedDescription,
                durationMs: duration
            )
        }
    }

    // MARK: - Parallel Execution

    /// Executes multiple tools in parallel using `TaskGroup`.
    ///
    /// Each tool is executed concurrently. Results are collected
    /// and returned in the same order as the input calls.
    ///
    /// - Parameter calls: An array of tuples (callId, toolName, arguments).
    /// - Returns: An array of `ToolResult` values in the same order.
    func executeToolsParallel(
        calls: [(id: String, name: String, arguments: [String: Any])]
    ) async -> [ToolResult] {
        Logger.agentInfo("Executing \(calls.count) tools in parallel")

        var allResults: [(Int, ToolResult)] = []
        let batchSize = 8  // Prevent resource exhaustion from excessive tool calls.

        for batchStart in stride(from: 0, to: calls.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, calls.count)
            let batch = Array(calls[batchStart..<batchEnd])

            let batchResults = await withTaskGroup(of: (Int, ToolResult).self) { group in
                for (offset, call) in batch.enumerated() {
                    let index = batchStart + offset
                    group.addTask {
                        let result: ToolResult
                        do {
                            result = try await self.executeTool(
                                id: call.id,
                                name: call.name,
                                arguments: call.arguments
                            )
                        } catch {
                            result = ToolResult(
                                toolCallId: call.id,
                                toolName: call.name,
                                status: .error,
                                output: "",
                                errorMessage: error.localizedDescription,
                                durationMs: 0
                            )
                        }
                        return (index, result)
                    }
                }

                var results: [(Int, ToolResult)] = []
                for await pair in group {
                    results.append(pair)
                }
                return results
            }
            allResults.append(contentsOf: batchResults)
        }

        allResults.sort { $0.0 < $1.0 }
        return allResults.map { $0.1 }
    }
    }
}
