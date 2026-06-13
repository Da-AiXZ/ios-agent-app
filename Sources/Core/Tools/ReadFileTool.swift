import Foundation

/// Tool for reading file contents.
///
/// Returns the full or partial content of a file at the specified path,
/// with optional offset and limit parameters for reading specific sections.
final class ReadFileTool: ToolProtocol {

    // MARK: - ToolProtocol

    let name: String = "read_file"
    let description: String = "Reads the contents of a file at the given path. "
        + "Supports reading specific sections via offset and limit parameters."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(
                name: "path",
                type: .string,
                description: "The absolute path to the file to read.",
                required: true
            ),
            JSONProperty(
                name: "offset",
                type: .integer,
                description: "The line number to start reading from (1-based). "
                    + "If omitted, reads from the beginning.",
                required: false
            ),
            JSONProperty(
                name: "limit",
                type: .integer,
                description: "The maximum number of lines to read. "
                    + "If omitted, reads to the end of the file.",
                required: false
            ),
        ],
        required: ["path"]
    )

    // MARK: - Properties

    private let fsService: FileSystemServiceProtocol

    // MARK: - Initialization

    init(fsService: FileSystemServiceProtocol = FileSystemService()) {
        self.fsService = fsService
    }

    // MARK: - Execution

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let path = arguments["path"] as? String else {
            return ToolResult(
                toolCallId: "",
                toolName: name,
                status: .error,
                output: "",
                errorMessage: "Missing required parameter: path"
            )
        }

        let url = URL(fileURLWithPath: path)
        let offset = arguments["offset"] as? Int
        let limit = arguments["limit"] as? Int

        let content: String
        do {
            content = try fsService.readFile(at: url)
        } catch {
            return ToolResult(
                toolCallId: "",
                toolName: name,
                status: .error,
                output: "",
                errorMessage: "Failed to read file: \(error.localizedDescription)"
            )
        }

        var lines = content.components(separatedBy: .newlines)
        let totalLines = lines.count

        // Apply offset.
        if let offset = offset {
            let startIndex = max(0, offset - 1)
            lines = Array(lines.dropFirst(startIndex))
        }

        // Apply limit.
        if let limit = limit {
            lines = Array(lines.prefix(limit))
        }

        let result = lines.joined(separator: "\n")
        let startLine = max(1, offset ?? 1)
        let endLine = min(startLine + lines.count - 1, totalLines)
        let summary = offset != nil || limit != nil
            ? " (lines \(startLine)-\(endLine) of \(totalLines))"
            : ""

        return ToolResult(
            toolCallId: "",
            toolName: name,
            status: .success,
            output: result,
            executedAt: Date(),
            durationMs: 0
        )
    }
}
