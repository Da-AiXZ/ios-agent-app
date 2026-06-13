import XCTest
@testable import ios_agent_app

// MARK: - Mock FileSystemService

/// Mock implementation of FileSystemServiceProtocol for tool testing.
final class MockFileSystemService: FileSystemServiceProtocol {
    var files: [String: String] = [:]
    var readError: Error?
    var writeError: Error?
    var editError: Error?
    var listError: Error?
    var deleteError: Error?

    func readFile(at url: URL) throws -> String {
        if let error = readError { throw error }
        guard let content = files[url.path] else {
            throw FileSystemError.fileNotFound(path: url.path)
        }
        return content
    }

    func writeFile(content: String, at url: URL) throws {
        if let error = writeError { throw error }
        files[url.path] = content
    }

    func editFile(at url: URL, oldString: String, newString: String, replaceAll: Bool) throws {
        if let error = editError { throw error }
        guard let content = files[url.path] else {
            throw FileSystemError.fileNotFound(path: url.path)
        }
        guard content.contains(oldString) else {
            throw FileSystemError.writeError(path: url.path, reason: "String not found")
        }
        if replaceAll {
            files[url.path] = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = content.range(of: oldString) else {
                throw FileSystemError.writeError(path: url.path, reason: "String not found")
            }
            files[url.path] = content.replacingCharacters(in: range, with: newString)
        }
    }

    func listDirectory(at url: URL, recursive: Bool) throws -> [FileItem] {
        if let error = listError { throw error }
        return []
    }

    func deleteItem(at url: URL) throws {
        if let error = deleteError { throw error }
        files.removeValue(forKey: url.path)
    }

    func isDirectory(_ url: URL) -> Bool { false }
    func fileSize(_ url: URL) -> Int64 { Int64(files[url.path]?.utf8.count ?? 0) }
    func createDirectory(at url: URL) throws {}
}

// MARK: - Mock TerminalService

/// Mock implementation of TerminalServiceProtocol for tool testing.
final class MockTerminalService: TerminalServiceProtocol {
    var result: TerminalResult?
    var error: Error?

    func execute(
        command: String,
        cwd: URL?,
        timeout: Int?,
        environment: [String: String]?
    ) async throws -> TerminalResult {
        if let error = error { throw error }
        return result ?? TerminalResult(exitCode: 0, stdout: "", stderr: "", durationMs: 0)
    }

    func executeStreaming(
        command: String,
        cwd: URL?
    ) -> AsyncThrowingStream<TerminalOutputChunk, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func terminate() {}
}

// MARK: - ToolProtocolTests

/// Tests for ToolProtocol implementations: ReadFileTool, EditFileTool, WebSearchTool.
final class ToolProtocolTests: XCTestCase {

    // MARK: - ReadFileTool

    func test_readFile_happyPath_returnsContent() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3\nline4\nline5"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: ["path": "/tmp/test.txt"])

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.output, "line1\nline2\nline3\nline4\nline5")
    }

    func test_readFile_missingPath_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [:])

        XCTAssertEqual(result.status, .error)
        XCTAssertEqual(result.errorMessage, "Missing required parameter: path")
    }

    func test_readFile_withOffset_skipsLines() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3\nline4\nline5"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 3,
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.output, "line3\nline4\nline5")
    }

    func test_readFile_withLimit_returnsSubset() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3\nline4\nline5"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "limit": 2,
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.output, "line1\nline2")
    }

    func test_readFile_withOffsetAndLimit() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3\nline4\nline5"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 2,
            "limit": 2,
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.output, "line2\nline3")
    }

    func test_readFile_fileNotFound_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: ["path": "/nonexistent.txt"])

        XCTAssertEqual(result.status, .error)
        XCTAssertTrue(result.errorMessage?.contains("Failed to read file") ?? false)
    }

    func test_readFile_offsetBeyondLength_returnsEmpty() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 100,
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.output, "")
    }

    func test_readFile_toolDefinition_hasCorrectName() {
        let tool = ReadFileTool()
        XCTAssertEqual(tool.name, "read_file")
    }

    func test_readFile_toolDefinition_hasParameters() {
        let tool = ReadFileTool()
        let def = tool.toolDefinition()
        XCTAssertEqual(def.function.name, "read_file")
        XCTAssertEqual(def.type, "function")
    }

    // MARK: - EditFileTool

    func test_editFile_singleReplacement_happyPath() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/edit.txt"] = "Hello world, hello universe"
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/edit.txt",
            "oldString": "world",
            "newString": "Swift",
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.output.contains("Successfully replaced"))
        XCTAssertTrue(result.output.contains("first occurrence"))
        XCTAssertEqual(mock.files["/tmp/edit.txt"], "Hello Swift, hello universe")
    }

    func test_editFile_replaceAll_replacesAllOccurrences() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/edit.txt"] = "foo bar foo baz foo"
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/edit.txt",
            "oldString": "foo",
            "newString": "qux",
            "replaceAll": true,
        ])

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.output.contains("all occurrences"))
        XCTAssertEqual(mock.files["/tmp/edit.txt"], "qux bar qux baz qux")
    }

    func test_editFile_oldStringNotFound_returnsError() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/edit.txt"] = "hello world"
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/edit.txt",
            "oldString": "nonexistent",
            "newString": "replacement",
        ])

        XCTAssertEqual(result.status, .error)
        XCTAssertTrue(result.errorMessage?.contains("Edit failed") ?? false)
    }

    func test_editFile_missingParameters_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [:])

        XCTAssertEqual(result.status, .error)
        XCTAssertTrue(result.errorMessage?.contains("Missing required parameters") ?? false)
    }

    func test_editFile_missingPath_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "oldString": "x",
            "newString": "y",
        ])

        XCTAssertEqual(result.status, .error)
    }

    func test_editFile_missingOldString_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "newString": "y",
        ])

        XCTAssertEqual(result.status, .error)
    }

    func test_editFile_fileNotFound_returnsError() async throws {
        let mock = MockFileSystemService()
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/nonexistent.txt",
            "oldString": "x",
            "newString": "y",
        ])

        XCTAssertEqual(result.status, .error)
    }

    func test_editFile_defaultReplaceAllIsFalse() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/edit.txt"] = "a a a"
        let tool = EditFileTool(fsService: mock)

        _ = try await tool.execute(arguments: [
            "path": "/tmp/edit.txt",
            "oldString": "a",
            "newString": "b",
            // replaceAll not specified — should default to false
        ])

        // Only first "a" should be replaced.
        XCTAssertEqual(mock.files["/tmp/edit.txt"], "b a a")
    }

    // MARK: - WebSearchTool (P0 Mock)

    func test_webSearch_happyPath_returnsMockResults() async throws {
        let tool = WebSearchTool()

        let result = try await tool.execute(arguments: ["query": "Swift programming"])

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.output.contains("Search results for 'Swift programming'"))
        XCTAssertTrue(result.output.contains("developer.apple.com"))
        XCTAssertTrue(result.output.contains("Note: Web search is in P0 mock mode"))
    }

    func test_webSearch_withMaxResults_limitsResults() async throws {
        let tool = WebSearchTool()

        let result = try await tool.execute(arguments: [
            "query": "test",
            "maxResults": 1,
        ])

        XCTAssertEqual(result.status, .success)
        // Should only have result #1, not #2.
        XCTAssertTrue(result.output.contains("1. "))
        XCTAssertFalse(result.output.contains("2. "))
    }

    func test_webSearch_defaultMaxResults_isFive() async throws {
        let tool = WebSearchTool()

        let result = try await tool.execute(arguments: ["query": "test"])

        XCTAssertEqual(result.status, .success)
        // Mock has 3 results; all should appear.
        XCTAssertTrue(result.output.contains("3. "))
        XCTAssertFalse(result.output.contains("4. "))
    }

    func test_webSearch_missingQuery_returnsError() async throws {
        let tool = WebSearchTool()

        let result = try await tool.execute(arguments: [:])

        XCTAssertEqual(result.status, .error)
        XCTAssertEqual(result.errorMessage, "Missing required parameter: query")
    }

    func test_webSearch_toolDefinition_hasCorrectName() {
        let tool = WebSearchTool()
        XCTAssertEqual(tool.name, "web_search")
    }

    // MARK: - ReadFileTool offset=0 edge case

    func test_readFile_offsetZero_readsFromBeginning() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 0,
        ])

        XCTAssertEqual(result.status, .success)
        // offset=0 should effectively start from line 1.
        XCTAssertEqual(result.output, "line1\nline2\nline3")
    }

    // MARK: - REGRESSION: ExecuteShellTool non-zero exit code

    func test_executeShell_nonZeroExitCode_returnsErrorStatus() async throws {
        let mock = MockTerminalService()
        mock.result = TerminalResult(exitCode: 1, stdout: "some output", stderr: "error output", durationMs: 42)
        let tool = ExecuteShellTool(terminalService: mock)

        let result = try await tool.execute(arguments: ["command": "false"])

        // BUG-1 regression: non-zero exit code must now return .error.
        XCTAssertEqual(result.status, .error,
            "Non-zero exit code should return .error status")
        XCTAssertTrue(result.output.contains("Exit code: 1"))
        XCTAssertTrue(result.output.contains("STDERR:"))
    }

    func test_executeShell_zeroExitCode_returnsSuccessStatus() async throws {
        let mock = MockTerminalService()
        mock.result = TerminalResult(exitCode: 0, stdout: "ok", stderr: "", durationMs: 10)
        let tool = ExecuteShellTool(terminalService: mock)

        let result = try await tool.execute(arguments: ["command": "echo hello"])

        XCTAssertEqual(result.status, .success,
            "Zero exit code should return .success status")
    }

    func test_executeShell_emptyStderr_omitsStderrFromOutput() async throws {
        let mock = MockTerminalService()
        mock.result = TerminalResult(exitCode: 0, stdout: "clean output", stderr: "", durationMs: 5)
        let tool = ExecuteShellTool(terminalService: mock)

        let result = try await tool.execute(arguments: ["command": "echo clean"])

        XCTAssertFalse(result.output.contains("STDERR:"))
        XCTAssertTrue(result.output.contains("STDOUT:"))
    }

    // MARK: - REGRESSION: ReadFileTool simplified summary

    func test_readFile_summary_offset1_correctRange() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "a\nb\nc\nd\ne"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 1,
            "limit": 3,
        ])

        // BUG-2 regression: summary should use simplified max(1, offset) calculation.
        // With offset=1, limit=3: lines 1-3 of 5.
        XCTAssertTrue(result.output?.contains("(lines 1-3 of 5)") ?? false,
            "Summary should show 'lines 1-3 of 5', got: \(result.output ?? "nil")")
    }

    func test_readFile_summary_offset5_correctRange() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "1\n2\n3\n4\n5\n6\n7\n8\n9\n10"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 5,
            "limit": 3,
        ])

        // BUG-2 regression: with offset=5, limit=3: lines 5-7 of 10.
        XCTAssertTrue(result.output?.contains("(lines 5-7 of 10)") ?? false,
            "Summary should show 'lines 5-7 of 10', got: \(result.output ?? "nil")")
    }

    func test_readFile_summary_noOffsetOrLimit_noSummary() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "line1\nline2\nline3"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: ["path": "/tmp/test.txt"])

        // When neither offset nor limit is specified, no summary string expected.
        XCTAssertFalse(result.output?.contains("(lines") ?? true,
            "Should not include summary when no offset/limit, got: \(result.output ?? "nil")")
    }

    func test_readFile_summary_limitExceedsTotal_clampsToTotal() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/test.txt"] = "a\nb\nc"
        let tool = ReadFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/test.txt",
            "offset": 2,
            "limit": 100,
        ])

        // offset=2, limit=100 on 3-line file → lines 2-3 of 3.
        XCTAssertTrue(result.output?.contains("(lines 2-3 of 3)") ?? false,
            "Summary should clamp endLine to totalLines, got: \(result.output ?? "nil")")
    }

    // MARK: - EditFileTool replaceAll=false on non-existent string

    func test_editFile_singleReplacement_stringNotFoundWithRangeCheck() async throws {
        let mock = MockFileSystemService()
        mock.files["/tmp/edit.txt"] = "aaa bbb ccc"
        let tool = EditFileTool(fsService: mock)

        let result = try await tool.execute(arguments: [
            "path": "/tmp/edit.txt",
            "oldString": "zzz",
            "newString": "yyy",
            "replaceAll": false,
        ])

        XCTAssertEqual(result.status, .error)
        XCTAssertTrue(result.errorMessage?.contains("Edit failed") ?? false)
        // Original content should be unchanged.
        XCTAssertEqual(mock.files["/tmp/edit.txt"], "aaa bbb ccc")
    }
}
