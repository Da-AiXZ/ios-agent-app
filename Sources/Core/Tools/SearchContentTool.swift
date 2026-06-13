import Foundation

/// Tool for searching file contents using regex pattern matching.
///
/// Recursively searches files within a directory for lines matching
/// a regular expression pattern, with optional file type filtering.
final class SearchContentTool: ToolProtocol {

    let name: String = "search_content"
    let description: String = "Searches file contents for a regex pattern. "
        + "Returns matching file paths, line numbers, and line content."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "pattern", type: .string, description: "The regex pattern to search for.", required: true),
            JSONProperty(name: "path", type: .string, description: "The directory to search in.", required: true),
            JSONProperty(name: "fileTypes", type: .array, description: "Optional file extensions to filter by (e.g. ['swift', 'py']).", required: false, items: JSONSchema(type: .string)),
        ],
        required: ["pattern", "path"]
    )

    private let searchService: SearchServiceProtocol

    init(searchService: SearchServiceProtocol = SearchService()) {
        self.searchService = searchService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let pattern = arguments["pattern"] as? String,
              let path = arguments["path"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameters: pattern, path"
            )
        }

        let directory = URL(fileURLWithPath: path)
        let fileTypes = arguments["fileTypes"] as? [String]

        do {
            let matches = try searchService.searchContent(
                pattern: pattern, in: directory, fileTypes: fileTypes
            )

            if matches.isEmpty {
                return ToolResult(
                    toolCallId: "", toolName: name, status: .success,
                    output: "No matches found for pattern '\(pattern)'.",
                    executedAt: Date(), durationMs: 0
                )
            }

            var output = "Found \(matches.count) matches for '\(pattern)':\n"
            for match in matches.prefix(100) {
                let filename = match.fileURL.lastPathComponent
                let trimmedLine = match.line.trimmingCharacters(in: .whitespacesAndNewlines)
                output += "  \(filename):\(match.lineNumber): \(trimmedLine)\n"
            }
            if matches.count > 100 {
                output += "  ... and \(matches.count - 100) more matches.\n"
            }

            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: output, executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Search failed: \(error.localizedDescription)"
            )
        }
    }
}
