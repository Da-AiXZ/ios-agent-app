import Foundation

/// Tool for listing directory contents.
///
/// Returns the files and subdirectories within a given directory,
/// optionally recursively.
final class ListDirectoryTool: ToolProtocol {

    let name: String = "list_directory"
    let description: String = "Lists the contents of a directory, with optional "
        + "recursive listing of subdirectories."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The absolute path to the directory.", required: true),
            JSONProperty(name: "recursive", type: .boolean, description: "If true, recursively list subdirectories.", required: false),
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
        let recursive = arguments["recursive"] as? Bool ?? false

        do {
            let items = try fsService.listDirectory(at: url, recursive: recursive)
            var output = "Contents of \(path) (\(items.count) items):\n"
            for item in items {
                let type = item.isDirectory ? "[DIR]" : "[FILE]"
                let size = item.formattedFileSize
                output += "  \(type) \(item.name) (\(size))\n"
            }
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: output, executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Failed to list directory: \(error.localizedDescription)"
            )
        }
    }
}
