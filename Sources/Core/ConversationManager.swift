import Foundation
import Combine

/// Manages the lifecycle and persistence of conversations.
///
/// Provides CRUD operations for conversations and handles
/// persistence via JSON serialization to the app's documents
/// directory. Publishes conversation list changes via `@Published`
/// for SwiftUI binding.
final class ConversationManager: ObservableObject {

    // MARK: - Published Properties

    /// The list of all conversations, ordered by most recently updated.
    @Published var conversations: [Conversation] = []

    // MARK: - Private Properties

    /// File URL for conversation persistence.
    private let storageURL: URL

    /// JSON encoder configured for ISO 8601 dates.
    private let encoder: JSONEncoder

    /// JSON decoder configured for ISO 8601 dates.
    private let decoder: JSONDecoder

    // MARK: - Initialization

    /// Creates a new conversation manager.
    ///
    /// - Parameter storageURL: The file URL for persisting conversations.
    ///   Defaults to `conversations.json` in the app's documents directory.
    init(storageURL: URL? = nil) {
        if let storageURL = storageURL {
            self.storageURL = storageURL
        } else {
            let documentsDir = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first!
            self.storageURL = documentsDir.appendingPathComponent("conversations.json")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        // Load persisted conversations on init.
        conversations = load()
    }

    // MARK: - Public Methods

    /// Creates a new conversation with default settings.
    ///
    /// - Parameters:
    ///   - modelId: The model to use for this conversation.
    ///   - systemPrompt: Optional system prompt for agent behavior.
    /// - Returns: The newly created `Conversation`.
    @discardableResult
    func create(
        modelId: String = AppConstants.defaultModelId,
        systemPrompt: String? = nil
    ) -> Conversation {
        let conversation = Conversation(
            modelId: modelId,
            systemPrompt: systemPrompt
        )
        conversations.insert(conversation, at: 0)
        save(conversations)
        Logger.info("Created conversation: \(conversation.id)")
        return conversation
    }

    /// Appends a message to the specified conversation.
    ///
    /// - Parameters:
    ///   - id: The ID of the conversation to update.
    ///   - message: The message to append.
    func appendMessage(_ id: UUID, message: Message) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            Logger.warning("Conversation not found for append: \(id)")
            return
        }

        conversations[index].messages.append(message)
        conversations[index].updatedAt = Date()

        // Auto-title: use first user message as title.
        if conversations[index].title == "New Conversation",
           message.role == .user {
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = String(content.prefix(50))
            conversations[index].title = title.isEmpty ? "New Conversation" : title
        }

        save(conversations)
    }

    /// Retrieves a conversation by ID.
    ///
    /// - Parameter id: The conversation ID.
    /// - Returns: The conversation, or `nil` if not found.
    func getConversation(_ id: UUID) -> Conversation? {
        conversations.first(where: { $0.id == id })
    }

    /// Deletes a conversation by ID.
    ///
    /// - Parameter id: The ID of the conversation to delete.
    func deleteConversation(_ id: UUID) {
        conversations.removeAll(where: { $0.id == id })
        save(conversations)
        Logger.info("Deleted conversation: \(id)")
    }

    /// Archives a conversation by ID.
    ///
    /// - Parameter id: The ID of the conversation to archive.
    func archiveConversation(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        conversations[index].isArchived = true
        conversations[index].updatedAt = Date()
        save(conversations)
        Logger.info("Archived conversation: \(id)")
    }

    /// Unarchives a conversation by ID.
    ///
    /// - Parameter id: The ID of the conversation to unarchive.
    func unarchiveConversation(_ id: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            return
        }
        conversations[index].isArchived = false
        conversations[index].updatedAt = Date()
        save(conversations)
    }

    // MARK: - Persistence

    /// Loads all conversations from persistent storage.
    ///
    /// - Returns: An array of `Conversation` values, or an empty array
    ///   if no persisted data exists.
    func load() -> [Conversation] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            Logger.debug("No conversations file at \(storageURL.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let conversations = try decoder.decode([Conversation].self, from: data)
            Logger.info("Loaded \(conversations.count) conversations")
            return conversations
        } catch {
            Logger.error("Failed to load conversations: \(error.localizedDescription)")
            return []
        }
    }

    /// Saves the conversation list to persistent storage.
    ///
    /// - Parameter conversations: The conversations to persist.
    private func save(_ conversations: [Conversation]) {
        do {
            let data = try encoder.encode(conversations)
            try data.write(to: storageURL, options: [.atomic, .completeFileProtection])
            Logger.debug("Saved \(conversations.count) conversations")
        } catch {
            Logger.error("Failed to save conversations: \(error.localizedDescription)")
        }
    }
}
