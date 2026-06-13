import XCTest
@testable import ios_agent_app

// MARK: - ConversationManagerTests

/// Tests for ConversationManager: create, appendMessage, delete, archive,
/// unarchive, and JSON persistence (encode/decode round-trip).
final class ConversationManagerTests: XCTestCase {

    private var tempStorageURL: URL!
    private var manager: ConversationManager!

    override func setUp() async throws {
        try await super.setUp()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ConversationManagerTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        tempStorageURL = tempDir.appendingPathComponent("test_conversations.json")
        manager = ConversationManager(storageURL: tempStorageURL)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempStorageURL.deletingLastPathComponent())
        try await super.tearDown()
    }

    // MARK: - Create

    func test_create_returnsConversationWithDefaults() {
        let conversation = manager.create()

        XCTAssertEqual(conversation.title, "New Conversation")
        XCTAssertEqual(conversation.modelId, AppConstants.defaultModelId)
        XCTAssertFalse(conversation.isArchived)
        XCTAssertEqual(conversation.messages.count, 0)
        XCTAssertNotNil(conversation.id)
    }

    func test_create_withCustomModelId() {
        let conversation = manager.create(modelId: "custom-model")

        XCTAssertEqual(conversation.modelId, "custom-model")
    }

    func test_create_withSystemPrompt() {
        let conversation = manager.create(systemPrompt: "You are a helpful assistant")

        XCTAssertEqual(conversation.systemPrompt, "You are a helpful assistant")
    }

    func test_create_addsToConversationsList() {
        _ = manager.create()
        _ = manager.create()

        XCTAssertEqual(manager.conversations.count, 2)
    }

    func test_create_insertsAtFront() {
        let first = manager.create()
        let second = manager.create()

        // Second should be at index 0 (most recently created).
        XCTAssertEqual(manager.conversations[0].id, second.id)
        XCTAssertEqual(manager.conversations[1].id, first.id)
    }

    // MARK: - Append Message

    func test_appendMessage_addsMessageToConversation() {
        let conversation = manager.create()
        let message = Message(role: .user, content: "Hello, agent!")

        manager.appendMessage(conversation.id, message: message)

        let updated = manager.getConversation(conversation.id)
        XCTAssertEqual(updated?.messages.count, 1)
        XCTAssertEqual(updated?.messages[0].content, "Hello, agent!")
    }

    func test_appendMessage_updatesTimestamp() {
        let conversation = manager.create()
        let originalTimestamp = conversation.updatedAt

        // Small delay to ensure timestamp difference.
        Thread.sleep(forTimeInterval: 0.01)

        manager.appendMessage(conversation.id, message: Message(role: .user, content: "Hi"))

        let updated = manager.getConversation(conversation.id)
        XCTAssertGreaterThan(updated!.updatedAt, originalTimestamp)
    }

    func test_appendMessage_autoTitle_fromFirstUserMessage() {
        let conversation = manager.create()
        XCTAssertEqual(conversation.title, "New Conversation")

        let message = Message(role: .user, content: "How do I use Swift async/await?")
        manager.appendMessage(conversation.id, message: message)

        let updated = manager.getConversation(conversation.id)
        XCTAssertEqual(updated?.title, "How do I use Swift async/await?")
    }

    func test_appendMessage_autoTitle_truncatesAt50Chars() {
        let conversation = manager.create()
        let longContent = String(repeating: "A", count: 100)
        let message = Message(role: .user, content: longContent)

        manager.appendMessage(conversation.id, message: message)

        let updated = manager.getConversation(conversation.id)
        XCTAssertEqual(updated?.title.count, 50)
    }

    func test_appendMessage_ignoresAssistantMessagesForTitle() {
        let conversation = manager.create()
        // Set a title first via user message.
        manager.appendMessage(conversation.id, message: Message(role: .user, content: "User title"))
        // Assistant message should not change title.
        manager.appendMessage(conversation.id, message: Message(role: .assistant, content: "Assistant response"))

        let updated = manager.getConversation(conversation.id)
        XCTAssertEqual(updated?.title, "User title")
    }

    func test_appendMessage_nonexistentConversation_doesNothing() {
        let fakeId = UUID()
        manager.appendMessage(fakeId, message: Message(role: .user, content: "test"))

        XCTAssertEqual(manager.conversations.count, 0)
    }

    // MARK: - Get Conversation

    func test_getConversation_returnsCorrectConversation() {
        let conv = manager.create()
        let retrieved = manager.getConversation(conv.id)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, conv.id)
    }

    func test_getConversation_nonexistent_returnsNil() {
        let retrieved = manager.getConversation(UUID())

        XCTAssertNil(retrieved)
    }

    // MARK: - Delete

    func test_delete_removesConversation() {
        let conv1 = manager.create()
        let conv2 = manager.create()

        manager.deleteConversation(conv1.id)

        XCTAssertEqual(manager.conversations.count, 1)
        XCTAssertEqual(manager.conversations[0].id, conv2.id)
        XCTAssertNil(manager.getConversation(conv1.id))
    }

    func test_delete_nonexistent_doesNothing() {
        manager.create()
        manager.deleteConversation(UUID())

        XCTAssertEqual(manager.conversations.count, 1)
    }

    // MARK: - Archive / Unarchive

    func test_archive_setsIsArchived() {
        let conv = manager.create()

        manager.archiveConversation(conv.id)

        let updated = manager.getConversation(conv.id)
        XCTAssertTrue(updated?.isArchived ?? false)
    }

    func test_unarchive_clearsIsArchived() {
        let conv = manager.create()
        manager.archiveConversation(conv.id)
        manager.unarchiveConversation(conv.id)

        let updated = manager.getConversation(conv.id)
        XCTAssertFalse(updated?.isArchived ?? true)
    }

    func test_archive_nonexistent_doesNothing() {
        manager.create()
        manager.archiveConversation(UUID())

        // No crash; conversation unaffected.
        XCTAssertEqual(manager.conversations.count, 1)
    }

    // MARK: - JSON Persistence

    func test_persistence_roundTrip_encodesAndDecodes() throws {
        // Create conversations with messages.
        let conv1 = manager.create()
        manager.appendMessage(conv1.id, message: Message(role: .user, content: "Hello"))
        manager.appendMessage(conv1.id, message: Message(role: .assistant, content: "Hi there!"))

        let conv2 = manager.create()
        manager.appendMessage(conv2.id, message: Message(role: .user, content: "Code review"))

        // Reload from disk.
        let newManager = ConversationManager(storageURL: tempStorageURL)

        XCTAssertEqual(newManager.conversations.count, 2)

        // First conversation should have 2 messages.
        let loaded1 = newManager.getConversation(conv1.id)
        XCTAssertEqual(loaded1?.messages.count, 2)
        XCTAssertEqual(loaded1?.messages[0].role, .user)
        XCTAssertEqual(loaded1?.messages[1].role, .assistant)

        // Second conversation.
        let loaded2 = newManager.getConversation(conv2.id)
        XCTAssertEqual(loaded2?.messages.count, 1)
    }

    func test_persistence_deletedConversation_notPersisted() {
        let conv1 = manager.create()
        manager.create()
        manager.deleteConversation(conv1.id)

        let newManager = ConversationManager(storageURL: tempStorageURL)

        XCTAssertEqual(newManager.conversations.count, 1)
        XCTAssertNil(newManager.getConversation(conv1.id))
    }

    func test_persistence_archivedConversation_isPreserved() {
        let conv = manager.create()
        manager.archiveConversation(conv.id)

        let newManager = ConversationManager(storageURL: tempStorageURL)

        let loaded = newManager.getConversation(conv.id)
        XCTAssertTrue(loaded?.isArchived ?? false)
    }

    func test_persistence_emptyStorage_returnsEmptyList() {
        // Ensure file doesn't exist.
        try? FileManager.default.removeItem(at: tempStorageURL)

        let newManager = ConversationManager(storageURL: tempStorageURL)
        XCTAssertEqual(newManager.conversations.count, 0)
    }

    func test_persistence_messageWithToolCalls() {
        let conv = manager.create()
        let toolCall = ToolCall(id: "tc1", name: "read_file", arguments: "{\"path\":\"/tmp/test\"}")
        let message = Message(
            role: .assistant,
            content: "Let me read that file",
            toolCalls: [toolCall]
        )
        manager.appendMessage(conv.id, message: message)

        let newManager = ConversationManager(storageURL: tempStorageURL)
        let loaded = newManager.getConversation(conv.id)
        XCTAssertEqual(loaded?.messages.count, 1)
        XCTAssertEqual(loaded?.messages[0].toolCalls?.count, 1)
        XCTAssertEqual(loaded?.messages[0].toolCalls?[0].id, "tc1")
        XCTAssertEqual(loaded?.messages[0].toolCalls?[0].name, "read_file")
    }

    // MARK: - Multiple Appends

    func test_multipleAppends_preservesOrder() {
        let conv = manager.create()
        manager.appendMessage(conv.id, message: Message(role: .user, content: "1"))
        manager.appendMessage(conv.id, message: Message(role: .assistant, content: "2"))
        manager.appendMessage(conv.id, message: Message(role: .user, content: "3"))

        let updated = manager.getConversation(conv.id)
        XCTAssertEqual(updated?.messages.map(\.content), ["1", "2", "3"])
    }

    // MARK: - Codable MessageRole

    func test_messageRole_codable_roundTrip() throws {
        let roles: [MessageRole] = [.user, .assistant, .system, .tool]
        let encoded = try JSONEncoder().encode(roles)
        let decoded = try JSONDecoder().decode([MessageRole].self, from: encoded)

        XCTAssertEqual(decoded, roles)
    }
}
