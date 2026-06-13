import Foundation

/// Tool for creating git commits.
///
/// Stages and commits changes with a given message, optionally
/// limited to specific files.
final class GitCommitTool: ToolProtocol {

    let name: String = "git_commit"
    let description: String = "Creates a git commit with the specified message. "
        + "Optionally limit to specific files."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The path to the git repository.", required: true),
            JSONProperty(name: "message", type: .string, description: "The commit message.", required: true),
            JSONProperty(name: "files", type: .array, description: "Optional specific files to commit.", required: false, items: JSONSchema(type: .string)),
        ],
        required: ["path", "message"]
    )

    private let gitService: GitServiceProtocol

    init(gitService: GitServiceProtocol = GitService()) {
        self.gitService = gitService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String,
              let message = arguments["message"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameters: path, message"
            )
        }

        let repoURL = URL(fileURLWithPath: path)
        let files = arguments["files"] as? [String]

        do {
            let commitResult = try gitService.commit(at: repoURL, message: message, files: files)
            let hash = commitResult.hash.isEmpty ? "created" : commitResult.hash
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: "Commit \(hash): \(message)",
                executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Git commit failed: \(error.localizedDescription)"
            )
        }
    }
}
