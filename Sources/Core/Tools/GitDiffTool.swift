import Foundation

/// Tool for viewing git diff output.
///
/// Returns the unified diff of changes in a git repository,
/// optionally filtered to staged changes or a specific file.
final class GitDiffTool: ToolProtocol {

    let name: String = "git_diff"
    let description: String = "Shows the git diff of changes in the working "
        + "tree. Use staged: true for staged changes, and file to limit "
        + "to a specific file."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The path to the git repository.", required: true),
            JSONProperty(name: "staged", type: .boolean, description: "If true, show staged changes only.", required: false),
            JSONProperty(name: "file", type: .string, description: "Optional specific file to diff.", required: false),
        ],
        required: ["path"]
    )

    private let gitService: GitServiceProtocol

    init(gitService: GitServiceProtocol = GitService()) {
        self.gitService = gitService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameter: path"
            )
        }

        let repoURL = URL(fileURLWithPath: path)
        let staged = arguments["staged"] as? Bool ?? false
        let file = arguments["file"] as? String

        do {
            let diffResult = try gitService.diff(at: repoURL, staged: staged, file: file)
            if diffResult.rawDiff.isEmpty {
                return ToolResult(
                    toolCallId: "", toolName: name, status: .success,
                    output: "No changes to show.", executedAt: Date(), durationMs: 0
                )
            }
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: diffResult.rawDiff, executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Git diff failed: \(error.localizedDescription)"
            )
        }
    }
}
