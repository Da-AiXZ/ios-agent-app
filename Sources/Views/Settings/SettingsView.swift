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
                            Text(viewModel.state.isDirty ? "Save Changes" : "Saved")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.state.isDirty)
                    .accessibilityLabel(viewModel.state.isDirty ? "Save changes" : "Already saved")

                    Button(role: .destructive, action: {
                        viewModel.dispatch(.resetToDefaults)
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Reset all settings to default values")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close settings")
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
            SettingsRow(label: "Theme", description: "Choose light, dark, or follow system.") {
                Picker("Theme", selection: Binding(
                    get: { viewModel.state.theme },
                    set: { viewModel.dispatch(.updateTheme($0)) }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(themeName(theme)).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Theme selection")
            }

            SettingsRow(label: "Language", description: "English / 中文") {
                Picker("Language", selection: Binding(
                    get: { viewModel.state.language },
                    set: { viewModel.dispatch(.updateLanguage($0)) }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(languageName(lang)).tag(lang)
                    }
                }
                .accessibilityLabel("Language selection")
            }

            ThemePreviewCard(theme: viewModel.state.theme)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Appearance")
        }
    }

    // MARK: - API Configuration Section

    private var apiConfigurationSection: some View {
        Section {
            SettingsRow(label: "Provider", description: "API backend provider.") {
                Picker("Provider", selection: Binding(
                    get: { viewModel.state.apiProvider },
                    set: { viewModel.dispatch(.updateProvider($0)) }
                )) {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue.capitalized).tag(provider)
                    }
                }
                .accessibilityLabel("API provider selection")
            }

            SettingsRow(label: "Endpoint", description: "API base URL.") {
                TextField("https://api.anthropic.com", text: Binding(
                    get: { viewModel.state.apiEndpoint },
                    set: { viewModel.dispatch(.updateEndpoint($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("API endpoint URL")
            }

            SettingsRow(label: "API Key", description: "Stored securely in Keychain.") {
                SecureField("sk-...", text: Binding(
                    get: { viewModel.state.apiKey },
                    set: { viewModel.dispatch(.updateAPIKey($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("API key input")
            }

            SettingsRow(label: "Model", description: "Default model identifier.") {
                TextField("claude-sonnet-4-20250514", text: Binding(
                    get: { viewModel.state.modelName },
                    set: { viewModel.dispatch(.updateModel($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Model identifier")
            }
        } header: {
            Text("API Configuration")
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        Section {
            SettingsRow(
                label: "Auto-Approve Read-Only",
                description: "Skip permission prompts for safe read operations."
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.state.autoApproveReadOnly },
                    set: { viewModel.dispatch(.toggleAutoApprove($0)) }
                ))
                .labelsHidden()
                .accessibilityLabel("Auto-approve read-only tools")
            }

            // Trusted paths.
            VStack(alignment: .leading, spacing: 8) {
                Text("Trusted Paths")
                    .font(.body)
                    .foregroundColor(.primary)
                Text("Operations within these directories are auto-approved.")
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
                        .accessibilityLabel("Remove trusted path \(path)")
                    }
                    .padding(.vertical, 2)
                }

                Button(action: {
                    // Add path — in a real app this would use a file picker.
                    viewModel.dispatch(.addTrustedPath("/Users/"))
                }) {
                    Label("Add Path", systemImage: "plus.circle")
                        .font(.caption)
                }
                .accessibilityLabel("Add trusted path")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Permissions")
        }
    }

    // MARK: - System Section

    private var systemSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                    .font(.body)
                    .foregroundColor(.primary)
                Text("Sets the default behavior context for the AI agent (max 2000 characters).")
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
                .accessibilityLabel("System prompt editor")
            }
            .padding(.vertical, 4)
        } header: {
            Text("System")
        }
    }

    // MARK: - Helpers

    private func themeName(_ theme: AppTheme) -> String {
        switch theme {
        case .light: return "☀️ Light"
        case .dark: return "🌙 Dark"
        case .system: return "⚙️ System"
        }
    }

    private func languageName(_ lang: AppLanguage) -> String {
        switch lang {
        case .english: return "English"
        case .chinese: return "中文"
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
