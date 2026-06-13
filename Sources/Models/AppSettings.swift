import Foundation

// MARK: - AppTheme

/// The visual theme mode for the application interface.
@frozen
enum AppTheme: String, Codable, CaseIterable {
    /// Light color scheme with bright backgrounds.
    case light

    /// Dark color scheme with dim backgrounds.
    case dark

    /// Follow the system-level appearance setting.
    case system
}

// MARK: - AppLanguage

/// The display language for the application user interface.
@frozen
enum AppLanguage: String, Codable, CaseIterable {
    /// English (en) localization.
    case english

    /// Simplified Chinese (zh-Hans) localization.
    case chinese
}

// MARK: - AppSettings

/// Persistent application settings that control API keys, model
/// selection, and security-related preferences.
///
/// Stored securely using `KeychainHelper` for sensitive fields
/// (API keys) and `UserDefaults` for non-sensitive preferences.
struct AppSettings: Codable {

    // MARK: - Properties

    /// The current UI theme selection.
    var theme: AppTheme

    /// The current display language.
    var language: AppLanguage

    /// The default AI model identifier used for new conversations.
    var defaultModelId: String

    /// The OpenAI API key for GPT model access.
    var openAIAPIKey: String

    /// The Anthropic API key for Claude model access.
    var anthropicAPIKey: String

    /// The base URL for OpenAI-compatible API endpoints.
    /// Allows use of proxies or self-hosted endpoints.
    var openAIBaseURL: String

    /// When `true`, the agent first creates a plan before executing
    /// any file modifications.
    var planModeEnabled: Bool

    /// List of directory paths that the agent is trusted to access
    /// without requiring explicit user approval.
    var trustedPaths: [String]

    // MARK: - Initialization

    init(
        theme: AppTheme = .system,
        language: AppLanguage = .english,
        defaultModelId: String = AppConstants.defaultModelId,
        openAIAPIKey: String = "",
        anthropicAPIKey: String = "",
        openAIBaseURL: String = AppConstants.defaultOpenAIBaseURL,
        planModeEnabled: Bool = true,
        trustedPaths: [String] = []
    ) {
        self.theme = theme
        self.language = language
        self.defaultModelId = defaultModelId
        self.openAIAPIKey = openAIAPIKey
        self.anthropicAPIKey = anthropicAPIKey
        self.openAIBaseURL = openAIBaseURL
        self.planModeEnabled = planModeEnabled
        self.trustedPaths = trustedPaths
    }
}
