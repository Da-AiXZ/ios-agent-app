import Foundation

/// Tool for writing content to files.
///
/// Creates a new file or overwrites an existing file at the specified
/// path with the provided content.
final class WriteFileTool: ToolProtocol {

    let name: String = "write_file"
    let description: String = "Writes content to a file, creating it if it "
        + "doesn't exist or overwriting it if it does. Parent directories "
        + "are created automatically."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The absolute path to write to.", required: true),
            JSONProperty(name: "content", type: .string, description: "The content to write.", required: true),
        ],
        required: ["path", "content"]
    )

    private let fsService: FileSystemServiceProtocol

    init(fsService: FileSystemServiceProtocol = FileSystemService()) {
        self.fsService = fsService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String,
              let content = arguments["content"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameters: path, content"
            )
        }

        let url = URL(fileURLWithPath: path)
        let lines = content.components(separatedBy: .newlines).count

        do {
            try fsService.writeFile(content: content, at: url)
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: "Successfully wrote \(lines) lines to \(path).",
                executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Failed to write file: \(error.localizedDescription)"
            )
        }
    }
}
