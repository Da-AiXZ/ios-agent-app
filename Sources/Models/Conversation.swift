import Foundation

/// Represents a conversation thread between the user and the AI agent.
///
/// A conversation contains an ordered list of messages, tracks the model
/// and system prompt used, and supports archiving for organization.
struct Conversation: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the conversation.
    let id: UUID

    /// Human-readable title for the conversation, typically derived
    /// from the first user message or manually set.
    var title: String

    /// The ordered list of messages in this conversation.
    var messages: [Message]

    /// Timestamp when the conversation was first created.
    let createdAt: Date

    /// Timestamp of the most recent modification to the conversation.
    var updatedAt: Date

    /// The identifier of the AI model used for this conversation.
    var modelId: String

    /// The system prompt that sets the agent's behavior context.
    /// A `nil` value means the default system prompt is used.
    var systemPrompt: String?

    /// Indicates whether the conversation has been archived.
    /// Archived conversations are hidden from the main list but
    /// remain recoverable.
    var isArchived: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        modelId: String = AppConstants.defaultModelId,
        systemPrompt: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.isArchived = isArchived
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case messages
        case createdAt
        case updatedAt
        case modelId
        case systemPrompt
        case isArchived
    }
}
