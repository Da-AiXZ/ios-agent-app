import Foundation

/// Tool for precise string replacement editing in files.
///
/// Performs exact string matching and replacement within a file,
/// with support for single or global (replaceAll) replacement.
final class EditFileTool: ToolProtocol {

    let name: String = "edit_file"
    let description: String = "Performs an exact string replacement in a file. "
        + "Use replaceAll: true to replace all occurrences."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "path", type: .string, description: "The absolute path to the file to edit.", required: true),
            JSONProperty(name: "oldString", type: .string, description: "The exact string to find and replace.", required: true),
            JSONProperty(name: "newString", type: .string, description: "The replacement string.", required: true),
            JSONProperty(name: "replaceAll", type: .boolean, description: "If true, replace all occurrences.", required: false),
        ],
        required: ["path", "oldString", "newString"]
    )

    private let fsService: FileSystemServiceProtocol

    init(fsService: FileSystemServiceProtocol = FileSystemService()) {
        self.fsService = fsService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String,
              let oldString = arguments["oldString"] as? String,
              let newString = arguments["newString"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameters: path, oldString, newString"
            )
        }

        let url = URL(fileURLWithPath: path)
        let replaceAll = arguments["replaceAll"] as? Bool ?? false

        do {
            try fsService.editFile(at: url, oldString: oldString, newString: newString, replaceAll: replaceAll)
            let mode = replaceAll ? "all occurrences" : "first occurrence"
            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: "Successfully replaced \(mode) of '\(oldString.prefix(50))...' in \(path).",
                executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Edit failed: \(error.localizedDescription)"
            )
        }
    }
}
