import Foundation

// MARK: - WebSearchResult

/// A single web search result item.
struct WebSearchResult: Codable {
    /// The page URL.
    let url: String

    /// The page title.
    let title: String

    /// A snippet of text from the page.
    let snippet: String
}

// MARK: - WebSearchTool

/// Tool for performing web searches.
///
/// P0 implementation returns mock/placeholder results.
/// P1 will integrate a real search API (e.g., Brave Search, SerpAPI).
final class WebSearchTool: ToolProtocol {

    let name: String = "web_search"
    let description: String = "Searches the web for information. "
        + "Returns a list of URLs with titles and snippets. "
        + "(P0: mock implementation; P1: real search API)"

    let parameters: JSONSchema = JSONSchema(
        type: .object,
        properties: [
            JSONProperty(name: "query", type: .string, description: "The search query.", required: true),
            JSONProperty(name: "maxResults", type: .integer, description: "Maximum number of results (default: 5).", required: false),
        ],
        required: ["query"]
    )

    // MARK: - Initialization

    init() {}

    // MARK: - Execution

    func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let query = arguments["query"] as? String else {
            return ToolResult(
                toolCallId: "", toolName: name, status: .error, output: "",
                errorMessage: "Missing required parameter: query"
            )
        }

        let maxResults = arguments["maxResults"] as? Int ?? 5

        Logger.agentInfo("Web search query: \(query)")

        // P0: Mock results.
        let mockResults: [WebSearchResult] = [
            WebSearchResult(
                url: "https://developer.apple.com/documentation/swift",
                title: "Swift Documentation — Apple Developer",
                snippet: "Official Swift programming language documentation including language guide, standard library, and framework references."
            ),
            WebSearchResult(
                url: "https://github.com/apple/swift",
                title: "apple/swift: The Swift Programming Language — GitHub",
                snippet: "The Swift Programming Language. Contribute to apple/swift development by creating an account on GitHub."
            ),
            WebSearchResult(
                url: "https://www.swift.org/documentation/",
                title: "Swift.org — Documentation",
                snippet: "Official documentation for the Swift programming language. Learn Swift, explore the standard library, and discover packages."
            ),
        ]

        let limited = Array(mockResults.prefix(maxResults))

        var output = "Search results for '\(query)':\n\n"
        for (index, result) in limited.enumerated() {
            output += "\(index + 1). \(result.title)\n"
            output += "   URL: \(result.url)\n"
            output += "   \(result.snippet)\n\n"
        }
        output += "\nNote: Web search is in P0 mock mode. Real search API integration coming in P1."

        return ToolResult(
            toolCallId: "", toolName: name, status: .success,
            output: output, executedAt: Date(), durationMs: 0
        )
    }
}
