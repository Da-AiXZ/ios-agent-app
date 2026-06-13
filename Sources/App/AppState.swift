import SwiftUI

/// Global observable application state.
///
/// Serves as the single source of truth for app-wide settings that
/// affect the UI layer, including theme, language, and agent
/// execution status.
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// The active UI theme (light, dark, or follow system).
    @Published var theme: AppTheme = .system

    /// The active display language for the application interface.
    @Published var language: AppLanguage = .english

    /// Indicates whether the AI agent is currently executing a task.
    @Published var isAgentRunning: Bool = false

    // MARK: - Initialization

    init(
        theme: AppTheme = .system,
        language: AppLanguage = .english,
        isAgentRunning: Bool = false
    ) {
        self.theme = theme
        self.language = language
        self.isAgentRunning = isAgentRunning
    }
}
