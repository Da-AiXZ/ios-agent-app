import Foundation

/// User-customizable editor and interaction preferences.
///
/// These preferences control the visual appearance and behavior
/// of the code editor, terminal view, and agent interaction patterns.
/// Stored in `UserDefaults` for quick access on app launch.
struct UserPreferences: Codable {

    // MARK: - Properties

    /// When `true`, read-only tool calls (e.g., file reads, searches)
    /// are automatically approved without user confirmation.
    var autoApproveReadOnly: Bool

    /// When `true`, line numbers are displayed in the code editor
    /// and diff views.
    var showLineNumbers: Bool

    /// The editor font size in points. Defaults to 14.
    var fontSize: Double

    /// The monospaced font family used for code display.
    /// Defaults to "SF Mono", Apple's system monospaced font.
    var fontFamily: String

    /// When `true`, long lines wrap within the editor viewport
    /// instead of requiring horizontal scrolling.
    var wordWrap: Bool

    // MARK: - Initialization

    init(
        autoApproveReadOnly: Bool = false,
        showLineNumbers: Bool = true,
        fontSize: Double = 14.0,
        fontFamily: String = "SF Mono",
        wordWrap: Bool = true
    ) {
        self.autoApproveReadOnly = autoApproveReadOnly
        self.showLineNumbers = showLineNumbers
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.wordWrap = wordWrap
    }

    // MARK: - Default Instance

    /// A `UserPreferences` instance populated with safe default values.
    static let `default`: UserPreferences = UserPreferences()
}
