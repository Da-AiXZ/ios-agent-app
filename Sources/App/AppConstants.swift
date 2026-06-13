import Foundation

/// Static application constants used throughout the app.
///
/// Centralizes all compile-time configuration values including API
/// endpoints, default model identifiers, version information, and
/// network timeout settings.
enum AppConstants {

    // MARK: - API Configuration

    /// The default Anthropic API endpoint for Claude model requests.
    static let defaultAnthropicAPIEndpoint: String = "https://api.anthropic.com"

    /// The default OpenAI-compatible API base URL.
    static let defaultOpenAIBaseURL: String = "https://api.openai.com"

    // MARK: - Model Configuration

    /// The default model identifier used for agent conversations.
    static let defaultModelId: String = "claude-sonnet-4-20250514"

    /// The fallback model identifier when the default is unavailable.
    static let fallbackModelId: String = "claude-sonnet-3-5-20241022"

    // MARK: - Version

    /// The current application version string (major.minor.patch).
    static let appVersion: String = "1.0.0"

    /// The build number for the current release.
    static let buildNumber: String = "1"

    // MARK: - Network Configuration

    /// Timeout duration for Server-Sent Events (SSE) streaming connections.
    static let sseTimeout: TimeInterval = 120.0

    /// The maximum number of retry attempts for transient network failures.
    static let maxRetryCount: Int = 3

    /// Base delay for exponential backoff on retries (in seconds).
    static let retryBaseDelay: TimeInterval = 1.0

    /// Maximum delay cap for exponential backoff (in seconds).
    static let retryMaxDelay: TimeInterval = 30.0

    // MARK: - UI Configuration

    /// Default font size for code display in points.
    static let defaultCodeFontSize: Double = 14.0

    /// Maximum number of visible lines in the terminal output view.
    static let terminalMaxVisibleLines: Int = 1000

    // MARK: - File System

    /// Maximum file size (in bytes) that can be displayed inline.
    static let maxDisplayableFileSize: Int64 = 1_048_576  // 1 MB

    /// File extensions that should be treated as text for display purposes.
    static let textFileExtensions: Set<String> = [
        "swift", "m", "h", "c", "cpp", "py", "js", "ts", "tsx", "jsx",
        "html", "css", "scss", "json", "xml", "yaml", "yml", "md", "txt",
        "rb", "go", "rs", "java", "kt", "sh", "bash", "zsh", "plist",
    ]
}
