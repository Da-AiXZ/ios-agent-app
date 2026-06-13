import SwiftUI

/// Application settings form with sections for appearance,
/// API configuration, permissions, and system preferences.
///
/// Dispatches all user actions as `SettingsIntent` values to the
/// `SettingsViewModel` and handles effects via `.onReceive`.
struct SettingsView: View {

    // MARK: - Properties

    /// The settings ViewModel driving this view.
    @ObservedObject var viewModel: SettingsViewModel

    /// The global application state.
    @EnvironmentObject var appState: AppState

    /// Dismiss action from the sheet presentation.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                apiConfigurationSection
                permissionsSection
                systemSection

                // Save / Reset.
                Section {
                    Button(action: {
                        viewModel.dispatch(.saveSettings)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text(viewModel.state.isDirty
                                ? L10n.saveChanges(lang: appState.language)
                                : L10n.saved(lang: appState.language))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.state.isDirty)
                    .accessibilityLabel(viewModel.state.isDirty
                        ? L10n.saveChanges(lang: appState.language)
                        : L10n.saved(lang: appState.language))

                    Button(role: .destructive, action: {
                        viewModel.dispatch(.resetToDefaults)
                    }) {
                        HStack {
                            Spacer()
                            Text(L10n.resetDefaults(lang: appState.language))
                            Spacer()
                        }
                    }
                    .accessibilityLabel(L10n.resetDefaults(lang: appState.language))
                }
            }
            .navigationTitle(L10n.settings(lang: appState.language))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done(lang: appState.language)) { dismiss() }
                        .accessibilityLabel(L10n.closeSettings(lang: appState.language))
                }
            }
        }
        .onReceive(viewModel.effects) { effect in
            handleEffect(effect)
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            SettingsRow(label: L10n.theme(lang: appState.language),
                        description: L10n.themeDescription(lang: appState.language)) {
                Picker("Theme", selection: Binding(
                    get: { viewModel.state.theme },
                    set: { viewModel.dispatch(.updateTheme($0)) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(themeName(theme)).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(L10n.theme(lang: appState.language))
            }

            SettingsRow(label: L10n.language(lang: appState.language),
                        description: L10n.languageDescription(lang: appState.language)) {
                Picker("Language", selection: Binding(
                    get: { viewModel.state.language },
                    set: { viewModel.dispatch(.updateLanguage($0)) }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(languageName(lang)).tag(lang)
                    }
                }
                .accessibilityLabel(L10n.language(lang: appState.language))
            }

            ThemePreviewCard(theme: viewModel.state.theme)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text(L10n.appearance(lang: appState.language))
        }
    }

    // MARK: - API Configuration Section

    private var apiConfigurationSection: some View {
        Section {
            SettingsRow(label: L10n.provider(lang: appState.language),
                        description: L10n.providerDescription(lang: appState.language)) {
                Picker("Provider", selection: Binding(
                    get: { viewModel.state.apiProvider },
                    set: { viewModel.dispatch(.updateProvider($0)) }
                )) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
                .accessibilityLabel(L10n.provider(lang: appState.language))
            }

            SettingsRow(label: L10n.endpoint(lang: appState.language),
                        description: L10n.endpointDescription(lang: appState.language)) {
                TextField("https://api.anthropic.com", text: Binding(
                    get: { viewModel.state.apiEndpoint },
                    set: { viewModel.dispatch(.updateEndpoint($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel(L10n.endpoint(lang: appState.language))
            }

            SettingsRow(label: L10n.apiKey(lang: appState.language),
                        description: L10n.apiKeyDescription(lang: appState.language)) {
                SecureField("sk-...", text: Binding(
                    get: { viewModel.state.apiKey },
                    set: { viewModel.dispatch(.updateAPIKey($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel(L10n.apiKey(lang: appState.language))
            }

            SettingsRow(label: L10n.model(lang: appState.language),
                        description: L10n.modelDescription(lang: appState.language)) {
                TextField("claude-sonnet-4-20250514", text: Binding(
                    get: { viewModel.state.modelName },
                    set: { viewModel.dispatch(.updateModel($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel(L10n.model(lang: appState.language))
            }
        } header: {
            Text(L10n.apiConfiguration(lang: appState.language))
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        Section {
            SettingsRow(
                label: L10n.autoApproveReadonly(lang: appState.language),
                description: L10n.autoApproveReadonlyDescription(lang: appState.language)
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.state.autoApproveReadOnly },
                    set: { viewModel.dispatch(.toggleAutoApprove($0)) }
                ))
                .labelsHidden()
                .accessibilityLabel(L10n.autoApproveReadonly(lang: appState.language))
            }

            // Trusted paths.
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.trustedPaths(lang: appState.language))
                    .font(.body)
                    .foregroundColor(.primary)
                Text(L10n.trustedPathsDescription(lang: appState.language))
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(viewModel.state.trustedPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(path)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Button(action: { viewModel.dispatch(.removeTrustedPath(path)) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .accessibilityLabel("\(L10n.removePath(lang: appState.language)) \(path)")
                    }
                    .padding(.vertical, 2)
                }

                Button(action: {
                    viewModel.dispatch(.addTrustedPath("/Users/"))
                }) {
                    Label(L10n.addPath(lang: appState.language), systemImage: "plus.circle")
                        .font(.caption)
                }
                .accessibilityLabel(L10n.addPath(lang: appState.language))
            }
            .padding(.vertical, 4)
        } header: {
            Text(L10n.permissions(lang: appState.language))
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.systemPrompt(lang: appState.language))
                    .font(.body)
                    .foregroundColor(.primary)
                Text(L10n.systemPromptDescription(lang: appState.language))
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: Binding(
                    get: { viewModel.state.systemPrompt },
                    set: { viewModel.dispatch(.updateSystemPrompt(String($0.prefix(2000)))) }
                ))
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 100)
                .padding(4)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(L10n.systemPrompt(lang: appState.language))
            }
            .padding(.vertical, 4)
        } header: {
            Text(L10n.system(lang: appState.language))
        }
    }

    // MARK: - Helpers

    private func themeName(_ theme: AppTheme) -> String {
        switch theme {
        case .light: return "鈽€锔?Light"
        case .dark: return "馃寵 Dark"
        case .system: return "鈿欙笍 System"
        }
    }

    private func languageName(_ lang: AppLanguage) -> String {
        switch lang {
        case .english: return "English"
        case .chinese: return "涓枃"
        }
    }

    private func handleEffect(_ effect: SettingsEffect) {
        switch effect {
        case .showValidationError(let msg):
            Logger.warning("Settings validation: \(msg)")
        case .navigateToAPISetup:
            break
        case .savedSuccessfully:
            Logger.info("Settings saved successfully")
        }
    }
}

// MARK: - L10n Helpers

/// Convenience wrapper for localizing SettingsView strings.
private enum L10n {
    static func settings(lang: AppLanguage) -> String {
        LocalizedString.get("settings", lang: lang)
    }
    static func appearance(lang: AppLanguage) -> String {
        LocalizedString.get("appearance", lang: lang)
    }
    static func theme(lang: AppLanguage) -> String {
        LocalizedString.get("theme", lang: lang)
    }
    static func themeDescription(lang: AppLanguage) -> String {
        LocalizedString.get("theme_description", lang: lang)
    }
    static func language(lang: AppLanguage) -> String {
        LocalizedString.get("language", lang: lang)
    }
    static func languageDescription(lang: AppLanguage) -> String {
        LocalizedString.get("language_description", lang: lang)
    }
    static func apiConfiguration(lang: AppLanguage) -> String {
        LocalizedString.get("api_configuration", lang: lang)
    }
    static func provider(lang: AppLanguage) -> String {
        LocalizedString.get("provider", lang: lang)
    }
    static func providerDescription(lang: AppLanguage) -> String {
        LocalizedString.get("provider_description", lang: lang)
    }
    static func endpoint(lang: AppLanguage) -> String {
        LocalizedString.get("endpoint", lang: lang)
    }
    static func endpointDescription(lang: AppLanguage) -> String {
        LocalizedString.get("endpoint_description", lang: lang)
    }
    static func apiKey(lang: AppLanguage) -> String {
        LocalizedString.get("api_key", lang: lang)
    }
    static func apiKeyDescription(lang: AppLanguage) -> String {
        LocalizedString.get("api_key_description", lang: lang)
    }
    static func model(lang: AppLanguage) -> String {
        LocalizedString.get("model", lang: lang)
    }
    static func modelDescription(lang: AppLanguage) -> String {
        LocalizedString.get("model_description", lang: lang)
    }
    static func permissions(lang: AppLanguage) -> String {
        LocalizedString.get("permissions", lang: lang)
    }
    static func autoApproveReadonly(lang: AppLanguage) -> String {
        LocalizedString.get("auto_approve_readonly", lang: lang)
    }
    static func autoApproveReadonlyDescription(lang: AppLanguage) -> String {
        LocalizedString.get("auto_approve_readonly_description", lang: lang)
    }
    static func trustedPaths(lang: AppLanguage) -> String {
        LocalizedString.get("trusted_paths", lang: lang)
    }
    static func trustedPathsDescription(lang: AppLanguage) -> String {
        LocalizedString.get("trusted_paths_description", lang: lang)
    }
    static func addPath(lang: AppLanguage) -> String {
        LocalizedString.get("add_path", lang: lang)
    }
    static func removePath(lang: AppLanguage) -> String {
        LocalizedString.get("remove_path", lang: lang)
    }
    static func system(lang: AppLanguage) -> String {
        LocalizedString.get("system", lang: lang)
    }
    static func systemPrompt(lang: AppLanguage) -> String {
        LocalizedString.get("system_prompt", lang: lang)
    }
    static func systemPromptDescription(lang: AppLanguage) -> String {
        LocalizedString.get("system_prompt_description", lang: lang)
    }
    static func saveChanges(lang: AppLanguage) -> String {
        LocalizedString.get("save_changes", lang: lang)
    }
    static func saved(lang: AppLanguage) -> String {
        LocalizedString.get("saved", lang: lang)
    }
    static func resetDefaults(lang: AppLanguage) -> String {
        LocalizedString.get("reset_defaults", lang: lang)
    }
    static func done(lang: AppLanguage) -> String {
        LocalizedString.get("done", lang: lang)
    }
    static func closeSettings(lang: AppLanguage) -> String {
        LocalizedString.get("close_settings", lang: lang)
    }
}
