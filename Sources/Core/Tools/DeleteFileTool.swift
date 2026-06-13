import Foundation

/// Tool for deleting files.
///
/// Permanently removes a file at the specified path.
/// Subject to permission checks before execution.
final class DeleteFileTool: ToolProtocol {

    let name: String = "delete_file"
    let description: String = "Deletes a file at the specified path. "
        + "This operation is irreversible."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The absolute path to the file to delete.", required: true),
        ],
        required: ["path"]
    )

    private let fsService: FileSystemServiceProtocol

    init(fsService: FileSystemServiceProtocol = FileSystemService()) {
        self.fsService = fsService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameter: path"
            )
        }

        let url = URL(fileURLWithPath: path)

        do {
            try fsService.deleteItem(at: url)
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: "Successfully deleted \(path).",
                executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Failed to delete file: \(error.localizedDescription)"
            )
        }
    }
}
