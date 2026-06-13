import XCTest
import Combine
@testable import ios_agent_app

// MARK: - Mock APIClient for Integration Tests

/// Mock APIClientProtocol that returns configurable SSE streams.
final class MockAPIClient: APIClientProtocol {
    var streamEvents: [SSEEvent] = []
    var shouldThrow: Error?
    var requestCount = 0

    func sendStreamRequest(_ request: AgentRequest) -> AsyncThrowingStream<SSEEvent, Error> {
        requestCount += 1
        return AsyncThrowingStream<SSEEvent, Error> { continuation in
            if let error = shouldThrow {
                continuation.finish(throwing: error)
                return
            }
            for event in streamEvents {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }

    func cancelAllRequests() {}
}

// MARK: - IntegrationTests

/// Integration tests: AgentRuntime + ToolRegistry + PermissionManager.
///
/// Tests the agent execution loop with mocked API client, tool
/// registry, and permission manager to verify the full flow.
final class IntegrationTests: XCTestCase {

    private var tempDir: URL!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        cancellables = []
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IntegrationTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a test file for ReadFileTool.
        let testFile = tempDir.appendingPathComponent("hello.txt")
        try "Hello, World!\nThis is a test file.\n".write(to: testFile, atomically: true, encoding: .utf8)
    }

    override func tearDown() async throws {
        cancellables = nil
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    // MARK: - AgentRuntime: Simple Text Response

    func test_agentRuntime_simpleTextResponse_emitsStreamingAndFinished() {
        let apiClient = MockAPIClient()
        apiClient.streamEvents = [
            SSEEvent(type: .content, data: "Hello".data(using: .utf8)),
            SSEEvent(type: .content, data: " World".data(using: .utf8)),
            SSEEvent(type: .finish),
        ]

        let toolRegistry = ToolRegistry()
        let permissionManager = PermissionManager(autoApproveReadOnly: true)
        let conversationManager = ConversationManager(
            storageURL: tempDir.appendingPathComponent("integration_conv.json")
        )

        let runtime = AgentRuntime(
            apiClient: apiClient,
            toolRegistry: toolRegistry,
            permissionManager: permissionManager,
            conversationManager: conversationManager,
            maxToolRounds: 3
        )

        let conversation = conversationManager.create()

        let expectation = XCTestExpectation(description: "Agent run completes")
        var events: [AgentEvent] = []

        runtime.run(message: "Say hello", modelId: "test-model", conversation: conversation)
            .sink { _ in
                expectation.fulfill()
            } receiveValue: { event in
                events.append(event)
            }
            .store(in: &cancellables)

        // Wait for the async task to complete.
        let result = XCTWaiter.wait(for: [expectation], timeout: 5.0)
        if result == .timedOut {
            // The run() method uses Task which may not complete synchronously.
            // Give it more time.
        }

        // Check that we receive streaming events.
        let streamingEvents = events.filter {
            if case .streaming = $0 { return true }
            return false
        }
        XCTAssertFalse(streamingEvents.isEmpty, "Should receive streaming events")
    }

    // MARK: - ToolRegistry: Register and Execute

    func test_toolRegistry_registerAndExecute_success() async throws {
        let registry = ToolRegistry()
        let mockFS = MockFileSystemService()
        mockFS.files["/tmp/test.txt"] = "file content here"

        let tool = ReadFileTool(fsService: mockFS)
        registry.register(tool)

        let result = try await registry.executeTool(
            id: "tc1",
            name: "read_file",
            arguments: ["path": "/tmp/test.txt"]
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.toolCallId, "tc1")
        XCTAssertEqual(result.toolName, "read_file")
        XCTAssertEqual(result.output, "file content here")
    }

    func test_toolRegistry_executeUnknownTool_returnsError() async throws {
        let registry = ToolRegistry()

        let result = try await registry.executeTool(
            id: "tc1",
            name: "nonexistent_tool",
            arguments: [:]
        )

        XCTAssertEqual(result.status, .error)
        XCTAssertTrue(result.errorMessage?.contains("not registered") ?? false)
    }

    func test_toolRegistry_unregister_removesTool() async throws {
        let registry = ToolRegistry()
        let tool = ReadFileTool()
        registry.register(tool)
        registry.unregister(name: "read_file")

        let retrieved = registry.getTool(name: "read_file")
        XCTAssertNil(retrieved)
    }

    func test_toolRegistry_allToolDefinitions_returnsAll() {
        let registry = ToolRegistry()
        registry.register(ReadFileTool())
        registry.register(WebSearchTool())

        let defs = registry.allToolDefinitions()
        XCTAssertEqual(defs.count, 2)
        let names = defs.map { $0.function.name }.sorted()
        XCTAssertEqual(names, ["read_file", "web_search"])
    }

    // MARK: - ToolRegistry: Parallel Execution

    func test_toolRegistry_executeToolsParallel_executesAll() async {
        let registry = ToolRegistry()
        let mockFS = MockFileSystemService()
        mockFS.files["/tmp/a.txt"] = "A"
        mockFS.files["/tmp/b.txt"] = "B"
        mockFS.files["/tmp/c.txt"] = "C"

        registry.register(ReadFileTool(fsService: mockFS))

        let calls: [(id: String, name: String, arguments: [String: Any])] = [
            (id: "1", name: "read_file", arguments: ["path": "/tmp/a.txt"]),
            (id: "2", name: "read_file", arguments: ["path": "/tmp/b.txt"]),
            (id: "3", name: "read_file", arguments: ["path": "/tmp/c.txt"]),
        ]

        let results = await registry.executeToolsParallel(calls: calls)

        XCTAssertEqual(results.count, 3)
        // Results should be in order.
        XCTAssertEqual(results[0].toolCallId, "1")
        XCTAssertEqual(results[1].toolCallId, "2")
        XCTAssertEqual(results[2].toolCallId, "3")

        let outputs = results.map(\.output).sorted()
        XCTAssertEqual(outputs, ["A", "B", "C"])
    }

    // MARK: - PermissionManager: Auto-Approve

    func test_permissionManager_autoApproveReadOnly_returnsApproved() async {
        let manager = PermissionManager(autoApproveReadOnly: true)

        let decision = await manager.requestPermission(
            toolName: "read_file",
            description: "Read test file",
            path: "/tmp/test.txt"
        )

        XCTAssertEqual(decision, .approved)
    }

    func test_permissionManager_trustedPath_returnsApproved() async {
        let manager = PermissionManager(trustedPaths: ["/safe/dir"])

        let decision = await manager.requestPermission(
            toolName: "edit_file",
            description: "Edit safe file",
            path: "/safe/dir/test.txt"
        )

        XCTAssertEqual(decision, .approved)
    }

    func test_permissionManager_untrustedWriteTool_requiresUserApproval() async {
        let manager = PermissionManager(autoApproveReadOnly: false, trustedPaths: [])

        // Use a timeout expectation since this will await user action.
        let expectation = XCTestExpectation(description: "Permission request")
        expectation.isInverted = true // We expect it NOT to complete quickly.

        Task {
            let _ = await manager.requestPermission(
                toolName: "write_file",
                description: "Write to untrusted location",
                path: "/untrusted/test.txt"
            )
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        // If we reach here, the continuation is still waiting for user action.
        XCTAssertNotNil(manager.pendingRequest)
    }

    func test_permissionManager_isPathTrusted_prefixMatch() {
        let manager = PermissionManager(trustedPaths: ["/home/user/project"])

        XCTAssertTrue(manager.isPathTrusted("/home/user/project/src/main.swift"))
        XCTAssertTrue(manager.isPathTrusted("/home/user/project"))
        XCTAssertFalse(manager.isPathTrusted("/home/user/other"))
        XCTAssertFalse(manager.isPathTrusted("/tmp/test.swift"))
    }

    func test_permissionManager_setAutoApproveReadOnly() {
        let manager = PermissionManager(autoApproveReadOnly: false)
        manager.setAutoApproveReadOnly(true)

        // Verify indirectly: now read_only tools should auto-approve.
        let expectation = XCTestExpectation(description: "Auto-approve")

        Task {
            let decision = await manager.requestPermission(
                toolName: "read_file",
                description: "Read",
                path: "/any/path"
            )
            XCTAssertEqual(decision, .approved)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - AgentRuntime: Cancel

    func test_agentRuntime_cancel_stopsExecution() {
        let apiClient = MockAPIClient()
        let runtime = AgentRuntime(
            apiClient: apiClient,
            maxToolRounds: 3
        )

        let conversation = ConversationManager(
            storageURL: tempDir.appendingPathComponent("cancel_conv.json")
        ).create()

        var events: [AgentEvent] = []
        let expectation = XCTestExpectation(description: "Agent cancelled")

        runtime.run(message: "test", modelId: "model", conversation: conversation)
            .sink { _ in
                expectation.fulfill()
            } receiveValue: { event in
                events.append(event)
            }
            .store(in: &cancellables)

        // Cancel immediately.
        runtime.cancel()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - AgentRuntime: Error Handling

    func test_agentRuntime_apiError_emitsErrorEvent() {
        let apiClient = MockAPIClient()
        apiClient.shouldThrow = APIClientError.httpError(statusCode: 500, body: "Internal Error")

        let runtime = AgentRuntime(apiClient: apiClient, maxToolRounds: 3)

        let conversation = ConversationManager(
            storageURL: tempDir.appendingPathComponent("error_conv.json")
        ).create()

        var events: [AgentEvent] = []
        let expectation = XCTestExpectation(description: "Agent error")

        runtime.run(message: "test", modelId: "model", conversation: conversation)
            .sink { _ in
                expectation.fulfill()
            } receiveValue: { event in
                events.append(event)
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 5.0)

        let errorEvents = events.filter {
            if case .error = $0 { return true }
            return false
        }
        XCTAssertFalse(errorEvents.isEmpty, "Should receive error event on API failure")
    }

    // MARK: - ToolDefinition from ToolProtocol

    func test_toolProtocol_toolDefinition_generatesCorrectJSON() {
        let tool = ReadFileTool()
        let def = tool.toolDefinition()

        XCTAssertEqual(def.type, "function")
        XCTAssertEqual(def.function.name, "read_file")
        XCTAssertFalse(def.function.description.isEmpty)

        let params = def.function.parameters
        XCTAssertEqual(params["type"] as? String, "object")
        XCTAssertNotNil(params["properties"])
        XCTAssertNotNil(params["required"])
    }
}
