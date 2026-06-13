import SwiftUI

/// The root application layout providing a three-panel split view
/// on iPad and a collapsible sidebar on iPhone.
///
/// ## Architecture
///
/// Sidebar: conversation history + project file tree.
/// Detail: chat view + code editor (opened via `navigateToFile` Effect).
/// Settings are presented as a sheet from the toolbar.
///
/// ## DI Wiring
///
/// All ViewModels are created with real credentials read from
/// Keychain/UserDefaults at init time. When settings are saved,
/// the `settingsDidChange` notification triggers reconfiguration
/// of the APIClient and AgentRuntime.
///
/// Adapts to size class: `NavigationSplitView` on iPad (regular),
/// `NavigationStack` tabs on iPhone (compact).
struct AppRootView: View {

    // MARK: - Environment

    /// The global dependency injection container.
    @EnvironmentObject var container: DependencyContainer

    /// The shared application state.
    @EnvironmentObject var appState: AppState

    // MARK: - State

    /// ViewModels created with real credentials at init time.
    @StateObject private var chatVM: ChatViewModel
    @StateObject private var settingsVM: SettingsViewModel
    @StateObject private var projectVM: ProjectViewModel
    @StateObject private var codeVM: CodeViewModel

    /// The shared conversation manager for the history sidebar.
    @StateObject private var conversationManager: ConversationManager

    /// Whether the settings sheet is presented.
    @State private var showSettings: Bool = false

    /// The currently selected sidebar item.
    @State private var selectedSidebarItem: SidebarItem? = .chat

    /// The URL most recently requested via `navigateToFile` Effect.
    @State private var pendingFileURL: URL?

    // MARK: - Sidebar Items

    enum SidebarItem: String, Identifiable, CaseIterable {
        case chat
        case history
        case project

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .chat: return "Chat"
            case .history: return "History"
            case .project: return "Project"
            }
        }

        @ViewBuilder
        func label(lang: AppLanguage) -> some View {
            switch self {
            case .chat:
                Label(L10n.chat(lang: lang), systemImage: "bubble.left.and.bubble.right")
            case .history:
                Label(L10n.history(lang: lang), systemImage: "clock.arrow.circlepath")
            case .project:
                Label(L10n.project(lang: lang), systemImage: "folder")
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Build real dependencies from Keychain / UserDefaults.
        let apiKey = KeychainHelper.load(key: "com.ios-agent-app.anthropic-api-key")
            ?? KeychainHelper.load(key: "com.ios-agent-app.openai-api-key")
            ?? ""
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: "com.ios-agent-app.api-endpoint")
            ?? AppConstants.defaultAnthropicAPIEndpoint
        let providerRaw = defaults.string(forKey: "com.ios-agent-app.api-provider") ?? "anthropic"
        let provider: APIProvider = (providerRaw == "openai") ? .openai : .anthropic

        let apiClient = APIClient(apiKey: apiKey, baseURL: baseURL, provider: provider)
        let toolReg = ToolRegistry()
        let permMgr = PermissionManager()
        let convMgr = ConversationManager()
        let fsService = FileSystemService()

        // Register tools (static helper, called before self is available in struct init).
        Self.registerAllTools(to: toolReg)

        let agent = AgentRuntime(
            apiClient: apiClient,
            toolRegistry: toolReg,
            permissionManager: permMgr,
            conversationManager: convMgr
        )

        _chatVM = StateObject(wrappedValue: ChatViewModel(
            agentRuntime: agent,
            conversationManager: convMgr,
            permissionManager: permMgr
        ))
        _settingsVM = StateObject(wrappedValue: SettingsViewModel(permissionManager: permMgr))
        _projectVM = StateObject(wrappedValue: ProjectViewModel())
        _codeVM = StateObject(wrappedValue: CodeViewModel(
            fsService: fsService,
            syntaxService: SyntaxHighlightService(),
            diffService: DiffService()
        ))
        _conversationManager = StateObject(wrappedValue: convMgr)
    }

    // MARK: - Body

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .preferredColorScheme(colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: settingsVM)
        }
        .onAppear {
            syncContainerState()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .settingsDidChange)
        ) { _ in
            refreshCredentials()
        }
        .onChange(of: settingsVM.state.theme) { newTheme in
            appState.theme = newTheme
        }
        .onChange(of: settingsVM.state.language) { newLang in
            appState.language = newLang
        }
        .onReceive(chatVM.effects) { effect in
            if case .navigateToFile(let url) = effect {
                openFileInCodeEditor(url)
            }
        }
        .onReceive(projectVM.effects) { effect in
            if case .showFileContent(let url) = effect {
                openFileInCodeEditor(url)
            }
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Credential Refresh

    /// Re-reads API credentials from Keychain/UserDefaults and creates
    /// a fresh AgentRuntime, updating both the ChatViewModel and the
    /// DependencyContainer.
    private func refreshCredentials() {
        let apiKey = KeychainHelper.load(key: "com.ios-agent-app.anthropic-api-key")
            ?? KeychainHelper.load(key: "com.ios-agent-app.openai-api-key")
            ?? ""
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: "com.ios-agent-app.api-endpoint")
            ?? AppConstants.defaultAnthropicAPIEndpoint
        let providerRaw = defaults.string(forKey: "com.ios-agent-app.api-provider") ?? "anthropic"
        let provider: APIProvider = (providerRaw == "openai") ? .openai : .anthropic

        let newClient = APIClient(apiKey: apiKey, baseURL: baseURL, provider: provider)

        // Build a fresh tool registry with all tools registered.
        let toolReg = ToolRegistry()
        Self.registerAllTools(to: toolReg)

        let newAgent = AgentRuntime(
            apiClient: newClient,
            toolRegistry: toolReg,
            permissionManager: PermissionManager(),
            conversationManager: conversationManager
        )

        chatVM.reconfigureAgentRuntime(newAgent)
        container.reconfigureAPIClient()

        Logger.info("Credentials refreshed — endpoint: \(baseURL), provider: \(provider.rawValue)")
    }

    /// Registers all 12 tools into the given ToolRegistry.
    static func registerAllTools(to registry: ToolRegistry) {
        let fsService = FileSystemService()
        registry.register(ReadFileTool(fsService: fsService))
        registry.register(WriteFileTool(fsService: fsService))
        registry.register(EditFileTool(fsService: fsService))
        registry.register(ListDirectoryTool(fsService: fsService))
        registry.register(DeleteFileTool(fsService: fsService))
        registry.register(SearchContentTool(searchService: SearchService()))
        registry.register(SearchFilesTool(searchService: SearchService()))
        registry.register(ExecuteShellTool(terminalService: TerminalService()))
        registry.register(GitDiffTool(gitService: GitService()))
        registry.register(GitStatusTool(gitService: GitService()))
        registry.register(GitCommitTool(gitService: GitService()))
        registry.register(WebSearchTool())
    }

    /// Syncs initial state: sync theme/language from settings to appState,
    /// and sync the DI container's APIClient.
    private func syncContainerState() {
        appState.theme = settingsVM.state.theme
        appState.language = settingsVM.state.language
        Logger.info("AppRootView appeared — initial state synced.")
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            sidebarContent
                .navigationTitle("Agent")
        } detail: {
            detailContent
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        TabView(selection: $selectedSidebarItem) {
            NavigationStack {
                chatDetail
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel(L10n.openSettings(lang: appState.language))
                        }
                    }
            }
            .tabItem {
                Label(L10n.chat(lang: appState.language), systemImage: "bubble.left.and.bubble.right")
            }
            .tag(SidebarItem.chat)

            NavigationStack {
                historyList
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel(L10n.openSettings(lang: appState.language))
                        }
                    }
            }
            .tabItem {
                Label(L10n.history(lang: appState.language), systemImage: "clock.arrow.circlepath")
            }
            .tag(SidebarItem.history)

            NavigationStack {
                ProjectView(viewModel: projectVM)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel(L10n.openSettings(lang: appState.language))
                        }
                    }
            }
            .tabItem {
                Label(L10n.project(lang: appState.language), systemImage: "folder")
            }
            .tag(SidebarItem.project)
        }
    }

    // MARK: - Sidebar Content (iPad)

    private var sidebarContent: some View {
        List(selection: $selectedSidebarItem) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    item.label(lang: appState.language)
                        .tag(item)
                }
            }

            Section(L10n.recentConversations(lang: appState.language)) {
                ForEach(conversationManager.conversations.filter { !$0.isArchived }) { conv in
                    Button(action: {
                        chatVM.dispatch(.loadConversation(conv))
                        selectedSidebarItem = .chat
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(conv.title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            Text(formatDate(conv.updatedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Conversation: \(conv.title)")
                }
            }

            Section {
                Button(action: { showSettings = true }) {
                    Label(L10n.settings(lang: appState.language), systemImage: "gearshape")
                }
                .accessibilityLabel(L10n.openSettings(lang: appState.language))
            }
        }
    }

    // MARK: - History List (iPhone)

    private var historyList: some View {
        List {
            if conversationManager.conversations.filter({ !$0.isArchived }).isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: L10n.noConversations(lang: appState.language),
                    subtitle: L10n.noConversationsSubtitle(lang: appState.language)
                )
            }

            ForEach(conversationManager.conversations.filter { !$0.isArchived }) { conv in
                Button(action: {
                    chatVM.dispatch(.loadConversation(conv))
                    selectedSidebarItem = .chat
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conv.title)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        HStack {
                            Text(String(format: L10n.messagesCount(lang: appState.language), conv.messages.count))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(formatDate(conv.updatedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel("Conversation: \(conv.title), \(conv.messages.count) messages")
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let conv = conversationManager.conversations.filter { !$0.isArchived }[index]
                    conversationManager.deleteConversation(conv.id)
                }
            }
        }
        .navigationTitle(L10n.history(lang: appState.language))
    }

    // MARK: - Detail Content (iPad)

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .chat:
            chatDetail
        case .history:
            historyList
        case .project:
            ProjectView(viewModel: projectVM)
        case .none:
            EmptyStateView(
                icon: "sidebar.left",
                title: L10n.selectItem(lang: appState.language),
                subtitle: L10n.selectItemSubtitle(lang: appState.language)
            )
        }
    }

    // MARK: - Chat Detail

    private var chatDetail: some View {
        VStack(spacing: 0) {
            ChatView(viewModel: chatVM)

            // Code editor at bottom when a file is open.
            if codeVM.state.file != nil {
                Divider()
                CodeView(viewModel: codeVM)
                    .frame(minHeight: 200)
            }
        }
    }

    // MARK: - File Navigation

    /// Opens the given file URL in the code editor by dispatching
    /// an `openFile` intent to the CodeViewModel.
    private func openFileInCodeEditor(_ url: URL) {
        pendingFileURL = url
        let fileItem = FileItem(
            name: url.lastPathComponent,
            url: url
        )
        codeVM.dispatch(.openFile(fileItem))
        Logger.uiInfo("Navigating to file: \(url.lastPathComponent)")

        // Switch to chat tab to show the code editor (which appears below chat).
        if horizontalSizeClass == .compact {
            selectedSidebarItem = .chat
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var colorScheme: ColorScheme? {
        switch appState.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - L10n Helpers

private enum L10n {
    static func chat(lang: AppLanguage) -> String {
        LocalizedString.get("chat", lang: lang)
    }
    static func history(lang: AppLanguage) -> String {
        LocalizedString.get("history", lang: lang)
    }
    static func project(lang: AppLanguage) -> String {
        LocalizedString.get("project", lang: lang)
    }
    static func settings(lang: AppLanguage) -> String {
        LocalizedString.get("settings", lang: lang)
    }
    static func openSettings(lang: AppLanguage) -> String {
        LocalizedString.get("open_settings", lang: lang)
    }
    static func recentConversations(lang: AppLanguage) -> String {
        LocalizedString.get("recent_conversations", lang: lang)
    }
    static func noConversations(lang: AppLanguage) -> String {
        LocalizedString.get("no_conversations", lang: lang)
    }
    static func noConversationsSubtitle(lang: AppLanguage) -> String {
        LocalizedString.get("no_conversations_subtitle", lang: lang)
    }
    static func messagesCount(lang: AppLanguage) -> String {
        LocalizedString.get("messages_count", lang: lang)
    }
    static func selectItem(lang: AppLanguage) -> String {
        LocalizedString.get("select_item", lang: lang)
    }
    static func selectItemSubtitle(lang: AppLanguage) -> String {
        LocalizedString.get("select_item_subtitle", lang: lang)
    }
}
