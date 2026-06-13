import XCTest
@testable import ios_agent_app

// MARK: - SearchServiceTests

/// Tests for SearchService: NSRegularExpression content search and glob file name matching.
final class SearchServiceTests: XCTestCase {

    private var tempDir: URL!
    private var searchService: SearchService!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchServiceTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files.
        let files: [(String, String)] = [
            ("hello.swift", "import Foundation\n\nfunc hello() {\n    print(\"Hello, World!\")\n}\n"),
            ("goodbye.swift", "import Foundation\n\nfunc goodbye() {\n    print(\"Goodbye!\")\n}\n"),
            ("readme.md", "# Test Project\n\nThis is a test project for search service.\n"),
            ("config.json", "{\n  \"name\": \"test\",\n  \"version\": \"1.0.0\"\n}\n"),
            ("notes.txt", "Important notes:\n- func is a keyword\n- another note\n"),
        ]

        for (name, content) in files {
            let url = tempDir.appendingPathComponent(name)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }

        searchService = SearchService(
            fileManager: .default,
            fsService: FileSystemService(fileManager: .default)
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - Glob: searchFiles

    func test_glob_swiftExtension_matchesOnlySwiftFiles() throws {
        let results = try searchService.searchFiles(pattern: "*.swift", in: tempDir)

        let names = results.map { $0.lastPathComponent }.sorted()
        XCTAssertEqual(names, ["goodbye.swift", "hello.swift"])
    }

    func test_glob_mdExtension_matchesMarkdown() throws {
        let results = try searchService.searchFiles(pattern: "*.md", in: tempDir)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].lastPathComponent, "readme.md")
    }

    func test_glob_exactName_matchesSingleFile() throws {
        let results = try searchService.searchFiles(pattern: "config.json", in: tempDir)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].lastPathComponent, "config.json")
    }

    func test_glob_prefixWildcard_matchesByPrefix() throws {
        let results = try searchService.searchFiles(pattern: "hello*", in: tempDir)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].lastPathComponent, "hello.swift")
    }

    func test_glob_suffixWildcard_matchesBySuffix() throws {
        let results = try searchService.searchFiles(pattern: "*.md", in: tempDir)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].lastPathComponent, "readme.md")
    }

    func test_glob_wildcardOnly_matchesAll() throws {
        let results = try searchService.searchFiles(pattern: "*", in: tempDir)

        XCTAssertEqual(results.count, 5)
    }

    func test_glob_doubleStar_recursiveSearch() throws {
        // Create a subdirectory with files.
        let subDir = tempDir.appendingPathComponent("subdir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "sub content".write(to: subDir.appendingPathComponent("sub.swift"), atomically: true, encoding: .utf8)

        let results = try searchService.searchFiles(pattern: "**/*.swift", in: tempDir)

        // Should find swift files in root and subdirectory.
        let names = results.map { $0.lastPathComponent }.sorted()
        XCTAssertTrue(names.contains("hello.swift"))
        XCTAssertTrue(names.contains("goodbye.swift"))
        XCTAssertTrue(names.contains("sub.swift"))
        XCTAssertEqual(results.count, 3)

        // Cleanup.
        try? FileManager.default.removeItem(at: subDir)
    }

    func test_glob_noMatch_returnsEmpty() throws {
        let results = try searchService.searchFiles(pattern: "*.rb", in: tempDir)
        XCTAssertTrue(results.isEmpty)
    }

    func test_glob_directoryNotFound_throwsError() {
        let nonexistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertThrowsError(try searchService.searchFiles(pattern: "*", in: nonexistent)) { error in
            guard case SearchServiceError.directoryNotFound = error else {
                XCTFail("Expected directoryNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Content Search: searchContent

    func test_searchContent_simplePattern_findsMatches() throws {
        let results = try searchService.searchContent(
            pattern: "func",
            in: tempDir,
            fileTypes: ["swift"]
        )

        // hello.swift: func hello() { and goodbye.swift: func goodbye() {
        XCTAssertEqual(results.count, 2)
        for result in results {
            XCTAssertTrue(result.line.contains("func"))
            XCTAssertTrue(result.fileURL.lastPathComponent.hasSuffix(".swift"))
        }
    }

    func test_searchContent_caseInsensitive_findsAll() throws {
        let results = try searchService.searchContent(
            pattern: "IMPORT",
            in: tempDir,
            fileTypes: ["swift"]
        )

        // Both swift files have "import Foundation".
        XCTAssertEqual(results.count, 2)
    }

    func test_searchContent_noFileTypeFilter_searchesAllTextFiles() throws {
        let results = try searchService.searchContent(
            pattern: "print",
            in: tempDir,
            fileTypes: nil
        )

        // hello.swift has print, goodbye.swift has print.
        let swiftMatches = results.filter { $0.fileURL.pathExtension == "swift" }
        XCTAssertEqual(swiftMatches.count, 2)
    }

    func test_searchContent_nonMatchingPattern_returnsEmpty() throws {
        let results = try searchService.searchContent(
            pattern: "NONEXISTENT_PATTERN_XYZ",
            in: tempDir,
            fileTypes: nil
        )

        XCTAssertTrue(results.isEmpty)
    }

    func test_searchContent_invalidPattern_throwsError() {
        XCTAssertThrowsError(try searchService.searchContent(
            pattern: "[invalid(regex",
            in: tempDir,
            fileTypes: nil
        )) { error in
            guard case SearchServiceError.invalidPattern = error else {
                XCTFail("Expected invalidPattern, got \(error)")
                return
            }
        }
    }

    func test_searchContent_directoryNotFound_throwsError() {
        let nonexistent = tempDir.appendingPathComponent("nonexistent")
        XCTAssertThrowsError(try searchService.searchContent(
            pattern: "test",
            in: nonexistent,
            fileTypes: nil
        )) { error in
            guard case SearchServiceError.directoryNotFound = error else {
                XCTFail("Expected directoryNotFound, got \(error)")
                return
            }
        }
    }

    func test_searchContent_jsonFile_alsoSearched() throws {
        let results = try searchService.searchContent(
            pattern: "version",
            in: tempDir,
            fileTypes: nil
        )

        let jsonMatches = results.filter { $0.fileURL.pathExtension == "json" }
        // config.json contains "version".
        XCTAssertTrue(jsonMatches.contains(where: { $0.line.contains("version") }))
    }

    // MARK: - SearchMatch Properties

    func test_searchMatch_lineNumber_isOneBased() throws {
        let results = try searchService.searchContent(
            pattern: "func",
            in: tempDir,
            fileTypes: ["swift"]
        )

        for result in results {
            XCTAssertGreaterThanOrEqual(result.lineNumber, 1, "Line numbers should be 1-based")
        }
    }

    func test_searchMatch_id_isUnique() throws {
        let results = try searchService.searchContent(
            pattern: "import",
            in: tempDir,
            fileTypes: ["swift"]
        )

        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids.count, results.count, "Each match should have a unique ID")
    }

    func test_searchMatch_matchRange_isValid() throws {
        let results = try searchService.searchContent(
            pattern: "func",
            in: tempDir,
            fileTypes: ["swift"]
        )

        for result in results {
            if let range = result.matchRange {
                let substring = result.line[result.line.index(
                    result.line.startIndex, offsetBy: range.lowerBound
                )..<result.line.index(
                    result.line.startIndex, offsetBy: range.upperBound
                )]
                XCTAssertEqual(substring.lowercased(), "func")
            }
        }
    }

    // MARK: - Multiple Matches Per Line

    func test_searchContent_multipleMatchesInLine() throws {
        // Create a file with multiple matches on one line.
        let url = tempDir.appendingPathComponent("multi.swift")
        try "let x = func1() + func2()".write(to: url, atomically: true, encoding: .utf8)

        let results = try searchService.searchContent(
            pattern: "func\\d",
            in: tempDir,
            fileTypes: ["swift"]
        )

        let multiResults = results.filter { $0.fileURL.lastPathComponent == "multi.swift" }
        XCTAssertEqual(multiResults.count, 2, "Should find both func1 and func2")
    }

    // MARK: - File Extension Filtering

    func test_searchContent_swiftOnly_excludesJsonAndMd() throws {
        let results = try searchService.searchContent(
            pattern: "import",
            in: tempDir,
            fileTypes: ["swift"]
        )

        for result in results {
            XCTAssertEqual(result.fileURL.pathExtension, "swift")
        }
    }

    func test_searchContent_multipleFileTypes() throws {
        let results = try searchService.searchContent(
            pattern: "test",
            in: tempDir,
            fileTypes: ["md", "json"]
        )

        let extensions = Set(results.map { $0.fileURL.pathExtension })
        XCTAssertTrue(extensions.isSubset(of: ["md", "json"]))
        // readme.md has "test", config.json has "test"
        XCTAssertFalse(results.isEmpty)
    }
}
