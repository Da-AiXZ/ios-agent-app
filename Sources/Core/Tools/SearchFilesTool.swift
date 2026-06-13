import Foundation

/// Tool for searching files by glob pattern.
///
/// Finds files matching a glob pattern (e.g., "*.swift", "**/*.md")
/// within a specified directory.
final class SearchFilesTool: ToolProtocol {

    let name: String = "search_files"
    let description: String = "Searches for files matching a glob pattern "
        + "(e.g., '*.swift', '**/*.test.swift') within a directory."

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "pattern", type: .string, description: "The glob pattern to match.", required: true),
            JSONProperty(name: "directory", type: .string, description: "The directory to search in.", required: true),
        ],
        required: ["pattern", "directory"]
    )

    private let searchService: SearchServiceProtocol

    init(searchService: SearchServiceProtocol = SearchService()) {
        self.searchService = searchService
    }

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let pattern = arguments["pattern"] as? String,
              let directory = arguments["directory"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameters: pattern, directory"
            )
        }

        let dirURL = URL(fileURLWithPath: directory)

        do {
            let results = try searchService.searchFiles(pattern: pattern, in: dirURL)

            if results.isEmpty {
                return ToolResult(
                    toolCallId: "", toolName: name, status: .success,
                    output: "No files matching '\(pattern)' found.",
                    executedAt: Date(), durationMs: 0
                )
            }

            var output = "Found \(results.count) files matching '\(pattern)':\n"
            for url in results.prefix(200) {
                output += "  \(url.path)\n"
            }
            if results.count > 200 {
                output += "  ... and \(results.count - 200) more files.\n"
            }

            return ToolResult(
                toolCallId: "", toolName: name, status: .success,
                output: output, executedAt: Date(), durationMs: 0
            )
        } catch {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "File search failed: \(error.localizedDescription)"
            )
        }
    }
}
