import Foundation
import Combine
import SwiftUI

// MARK: - SettingsState

/// The complete UI state for the settings screen.
struct SettingsState: ViewState {

    /// The current UI theme selection.
    var theme: AppTheme = .system

    /// The current display language.
    var language: AppLanguage = .english

    /// The API key, displayed masked for security.
    var apiKey: String = ""

    /// The API endpoint URL.
    var apiEndpoint: String = AppConstants.defaultAnthropicAPIEndpoint

    /// The default model identifier.
    var modelName: String = AppConstants.defaultModelId

    /// Whether read-only tool operations are auto-approved.
    var autoApproveReadOnly: Bool = false

    /// The list of trusted directory paths.
    var trustedPaths: [String] = []

    /// The default system prompt used for new conversations.
    var systemPrompt: String = ""

    /// Whether the settings have unsaved changes.
    var isDirty: Bool = false

    /// The API provider type.
    var apiProvider: APIProvider = .anthropic

    /// Whether the API key is being edited (unmasked).
    var isEditingAPIKey: Bool = false
}

// MARK: - SettingsIntent

/// User actions that the SettingsViewModel can process.
@frozen
enum SettingsIntent: ViewIntent {

    /// Update the UI theme.
    case updateTheme(AppTheme)

    /// Update the display language.
    case updateLanguage(AppLanguage)

    /// Save a new API key.
    case updateAPIKey(String)

    /// Update the API endpoint URL.
    case updateEndpoint(String)

    /// Update the default model identifier.
    case updateModel(String)

    /// Toggle auto-approve for read-only tool operations.
    case toggleAutoApprove(Bool)

    /// Add a path to the trusted paths list.
    case addTrustedPath(String)

    /// Remove a path from the trusted paths list.
    case removeTrustedPath(String)

    /// Update the default system prompt.
    case updateSystemPrompt(String)

    /// Reset all settings to their default values.
    case resetToDefaults

    /// Update the API provider.
    case updateProvider(APIProvider)

    /// Toggle the API key editing mode.
    case toggleAPIKeyEditing

    /// Load persisted settings.
    case loadSettings

    /// Persist all current settings.
    case saveSettings
}

// MARK: - SettingsEffect

/// One-time side effects from the SettingsViewModel.
@frozen
enum SettingsEffect: ViewEffect {
    /// Show a validation error message.
    case showValidationError(String)

    /// Navigate to the API setup/key configuration screen.
    case navigateToAPISetup

    /// Settings were successfully saved.
    case savedSuccessfully
}

// MARK: - SettingsViewModel

/// ViewModel for the application settings screen.
///
/// Manages app-wide configuration including theme, language, API keys,
/// model selection, system prompt, and security permissions. Uses
/// `KeychainHelper` for secure API key storage and `UserDefaults` for
/// non-sensitive preferences.
@MainActor
final class SettingsViewModel: MVIViewModel, ObservableObject {

    // MARK: - MVIViewModel

    typealias State = SettingsState
    typealias Intent = SettingsIntent
    typealias Effect = SettingsEffect

    @Published var state: SettingsState = SettingsState()

    var effects: AnyPublisher<Effect, Never> {
        effectsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let permissionManager: PermissionManagerProtocol
    private var effectsSubject = PassthroughSubject<Effect, Never>()

    /// Keychain key for storing the API key.
    private let apiKeyKeychainKey: String

    /// UserDefaults key for storing non-sensitive settings.
    private let defaultsKey: String

    /// The underlying `AppSettings` domain model.
    private var appSettings: AppSettings = AppSettings()

    // MARK: - Initialization

    init(
        permissionManager: PermissionManagerProtocol = PermissionManager(),
        apiKeyKeychainKey: String = "com.ios-agent-app.anthropic-api-key",
        defaultsKey: String = "com.ios-agent-app.settings"
    ) {
        self.permissionManager = permissionManager
        self.apiKeyKeychainKey = apiKeyKeychainKey
        self.defaultsKey = defaultsKey

        // Load persisted settings on init.
        dispatch(.loadSettings)
    }

    // MARK: - Intent Dispatch

    func dispatch(_ intent: SettingsIntent) {
        switch intent {
        case .updateTheme(let theme):
            applyUpdate { $0.theme = theme }
        case .updateLanguage(let language):
            applyUpdate { $0.language = language }
        case .updateAPIKey(let key):
            handleUpdateAPIKey(key)
        case .updateEndpoint(let endpoint):
            applyUpdate { $0.apiEndpoint = endpoint }
        case .updateModel(let model):
            applyUpdate { $0.modelName = model }
        case .toggleAutoApprove(let enabled):
            handleToggleAutoApprove(enabled)
        case .addTrustedPath(let path):
            handleAddTrustedPath(path)
        case .removeTrustedPath(let path):
            handleRemoveTrustedPath(path)
        case .updateSystemPrompt(let prompt):
            applyUpdate { $0.systemPrompt = prompt }
        case .resetToDefaults:
            handleResetToDefaults()
        case .updateProvider(let provider):
            applyUpdate { $0.apiProvider = provider }
        case .toggleAPIKeyEditing:
            handleToggleAPIKeyEditing()
        case .loadSettings:
            handleLoadSettings()
        case .saveSettings:
            handleSaveSettings()
        }
    }

    // MARK: - Intent Handlers

    private func applyUpdate(_ block: (inout SettingsState) -> Void) {
        var updated = state
        block(&updated)
        updated.isDirty = true
        state = updated
    }

    private func handleUpdateAPIKey(_ key: String) {
        var updated = state
        updated.apiKey = key
        updated.isDirty = true
        state = updated

        // Persist to keychain immediately.
        KeychainHelper.save(key: apiKeyKeychainKey, value: key)
        Logger.info("API key updated")
    }

    private func handleToggleAutoApprove(_ enabled: Bool) {
        var updated = state
        updated.autoApproveReadOnly = enabled
        updated.isDirty = true
        state = updated

        // Sync to permission manager.
        permissionManager.setAutoApproveReadOnly(enabled)
    }

    private func handleAddTrustedPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !state.trustedPaths.contains(trimmed) else { return }
        guard FileManager.default.fileExists(atPath: trimmed) else {
            effectsSubject.send(.showValidationError("Path does not exist: \(trimmed)"))
            return
        }

        var updated = state
        updated.trustedPaths.append(trimmed)
        updated.isDirty = true
        state = updated
    }

    private func handleRemoveTrustedPath(_ path: String) {
        var updated = state
        updated.trustedPaths.removeAll(where: { $0 == path })
        updated.isDirty = true
        state = updated
    }

    private func handleToggleAPIKeyEditing() {
        var updated = state
        updated.isEditingAPIKey.toggle()
        state = updated
    }

    private func handleLoadSettings() {
        var updated = SettingsState()

        // Load from UserDefaults.
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: defaultsKey),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            appSettings = settings
            updated.theme = settings.theme
            updated.language = settings.language
            updated.modelName = settings.defaultModelId
            updated.apiEndpoint = settings.openAIBaseURL
            updated.trustedPaths = settings.trustedPaths
        }

        // Load API key from keychain (masked).
        if let key = KeychainHelper.load(key: apiKeyKeychainKey) {
            updated.apiKey = maskAPIKey(key)
            appSettings.anthropicAPIKey = key
        }

        // Load system prompt from UserDefaults.
        updated.systemPrompt = defaults.string(forKey: "com.ios-agent-app.system-prompt") ?? ""

        // Load auto-approve setting.
        updated.autoApproveReadOnly = defaults.bool(forKey: "com.ios-agent-app.auto-approve-readonly")

        updated.isDirty = false
        state = updated

        // Sync to permission manager.
        permissionManager.setAutoApproveReadOnly(updated.autoApproveReadOnly)
        permissionManager.setTrustedPaths(updated.trustedPaths)

        Logger.info("Settings loaded")
    }

    private func handleSaveSettings() {
        // Update domain model.
        appSettings.theme = state.theme
        appSettings.language = state.language
        appSettings.defaultModelId = state.modelName
        appSettings.openAIBaseURL = state.apiEndpoint
        appSettings.trustedPaths = state.trustedPaths

        // Persist to UserDefaults.
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(appSettings) {
            defaults.set(data, forKey: defaultsKey)
        }

        // Persist system prompt.
        defaults.set(state.systemPrompt, forKey: "com.ios-agent-app.system-prompt")

        // Persist auto-approve.
        defaults.set(state.autoApproveReadOnly, forKey: "com.ios-agent-app.auto-approve-readonly")

        // Sync to permission manager.
        permissionManager.setAutoApproveReadOnly(state.autoApproveReadOnly)
        permissionManager.setTrustedPaths(state.trustedPaths)

        var updated = state
        updated.isDirty = false
        state = updated

        effectsSubject.send(.savedSuccessfully)
        Logger.info("Settings saved")
    }

    private func handleResetToDefaults() {
        var updated = SettingsState()
        updated.theme = .system
        updated.language = .english
        updated.modelName = AppConstants.defaultModelId
        updated.apiEndpoint = AppConstants.defaultAnthropicAPIEndpoint
        updated.apiProvider = .anthropic
        updated.autoApproveReadOnly = false
        updated.trustedPaths = []
        updated.systemPrompt = ""
        updated.isDirty = true
        state = updated
        Logger.info("Settings reset to defaults")
    }

    // MARK: - Helpers

    /// Masks an API key for secure display, showing only the last 4 characters.
    private func maskAPIKey(_ key: String) -> String {
        guard key.count > 4 else { return String(repeating: "•", count: key.count) }
        let prefix = String(repeating: "•", count: min(12, key.count - 4))
        let suffix = String(key.suffix(4))
        return prefix + suffix
    }
}
