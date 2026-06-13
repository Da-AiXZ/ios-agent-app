import Foundation

/// Tool for executing shell commands.
///
/// Runs a shell command in a specified working directory with
/// an optional timeout. Returns stdout, stderr, and exit code.
final class ExecuteShellTool: ToolProtocol {

    let name: String = "execute_shell"
    let description: String = "Executes a shell command in the specified "
        + "working directory. Returns stdout, stderr, and exit code. "
        + "Commands are subject to permission checks for security."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "command", type: .string, description: "The shell command to execute.", required: true),
            JSONProperty(name: "cwd", type: .string, description: "The working directory for the command.", required: false),
            JSONProperty(name: "timeout", type: .integer, description: "Maximum execution time in seconds (default: 120).", required: false),
        ],
        required: ["command"]
    )

    private let terminalService: TerminalServiceProtocol

    init(terminalService: TerminalServiceProtocol = TerminalService()) {
        self.terminalService = terminalService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let command = arguments["command"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameter: command"
            )
        }

        let cwd: URL? = (arguments["cwd"] as? String).map { URL(fileURLWithPath: $0) }
        let timeout = arguments["timeout"] as? Int

        do {
            let result = try await terminalService.execute(
                command: command, cwd: cwd, timeout: timeout, environment: nil
            )

            var output = ""
            if !result.stdout.isEmpty {
                output += "STDOUT:\n\(result.stdout)\n"
            }
            if !result.stderr.isEmpty {
                output += "STDERR:\n\(result.stderr)\n"
            }
            output += "Exit code: \(result.exitCode) (duration: \(String(format: "%.0f", result.durationMs))ms)"

            return ToolResult(
                toolCallId: "", toolName: name,
                status: result.exitCode == 0 ? .success : .error,
                output: output, executedAt: Date(), durationMs: result.durationMs
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Command execution failed: \(error.localizedDescription)"
            )
        }
    }
}
