import Foundation

/// Represents a development project opened in the agent workspace.
///
/// A project tracks the root directory, custom CLAUDE.md instructions,
/// gitignore patterns for file filtering, and the last-opened timestamp
/// for quick access.
struct Project: Codable, Identifiable, Equatable {

    // MARK: - Properties

    /// Unique identifier for the project.
    let id: UUID

    /// Human-readable project name.
    var name: String

    /// The file system URL of the project root directory.
    var rootURL: URL

    /// Content of the CLAUDE.md file that provides project-specific
    /// instructions to the AI agent.
    var claudeMDContent: String

    /// Glob patterns for files and directories that should be
    /// excluded from the agent's file search and diff operations.
    var gitignorePatterns: [String]

    /// Timestamp of when this project was last opened.
    /// `nil` if the project has never been opened.
    var lastOpened: Date?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        rootURL: URL,
        claudeMDContent: String = "",
        gitignorePatterns: [String] = [],
        lastOpened: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.rootURL = rootURL
        self.claudeMDContent = claudeMDContent
        self.gitignorePatterns = gitignorePatterns
        self.lastOpened = lastOpened
    }

    // MARK: - Computed Properties

    /// Returns `true` if the project has valid CLAUDE.md instructions.
    var hasCustomInstructions: Bool {
        !claudeMDContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
