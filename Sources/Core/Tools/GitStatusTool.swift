import Foundation

/// Tool for viewing git working tree status.
///
/// Returns the current state of the working directory and staging area,
/// showing which files are modified, added, deleted, or untracked.
final class GitStatusTool: ToolProtocol {

    let name: String = "git_status"
    let description: String = "Shows the working tree status of a git repository, "
        + "including modified, added, deleted, and untracked files."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The path to the git repository.", required: true),
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

        do {
            let statusResult = try gitService.status(at: repoURL)

            if statusResult.changedFiles.isEmpty {
                return ToolResult(
                    toolCallId: "", toolName: name, status: .success,
                    output: "Working tree clean. Nothing to commit.",
                    executedAt: Date(), durationMs: 0
                )
            }

            let currentBranch = (try? gitService.currentBranch(at: repoURL)) ?? "unknown"

            var output = "On branch \(currentBranch)\n\n"
            let staged = statusResult.changedFiles.filter(\.staged)
            let unstaged = statusResult.changedFiles.filter { !$0.staged }

            if !staged.isEmpty {
                output += "Changes to be committed:\n"
                for file in staged {
                    output += "  \(file.status.rawValue.uppercased()): \(file.path)\n"
                }
                output += "\n"
            }

            if !unstaged.isEmpty {
                output += "Changes not staged for commit:\n"
                for file in unstaged {
                    output += "  \(file.status.rawValue.uppercased()): \(file.path)\n"
                }
            }

            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: output, executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Git status failed: \(error.localizedDescription)"
            )
        }
    }
}
