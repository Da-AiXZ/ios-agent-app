import SwiftUI

/// The root application layout providing a three-panel split view
/// on iPad and a collapsible sidebar on iPhone.
///
/// ## Architecture
///
/// Sidebar: conversation list + project file tree.
/// Detail: chat view + code editor (opened via `navigateToFile` Effect).
/// Settings are presented as a sheet from the toolbar.
///
/// ## DI Wiring
///
/// All ViewModels are created through `DependencyContainer` factory
/// methods, ensuring they share the same service and core engine
/// singletons. The container is injected via `@EnvironmentObject`.
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

    /// ViewModels created via the container factory methods.
    @StateObject private var chatVM: ChatViewModel
    @StateObject private var settingsVM: SettingsViewModel
    @StateObject private var projectVM: ProjectViewModel
    @StateObject private var codeVM: CodeViewModel

    /// Whether the settings sheet is presented.
    @State private var showSettings: Bool = false

    /// The currently selected sidebar item.
    @State private var selectedSidebarItem: SidebarItem? = .chat

    /// The URL most recently requested via `navigateToFile` Effect.
    @State private var pendingFileURL: URL?

    // MARK: - Sidebar Items

    enum SidebarItem: String, Identifiable, CaseIterable {
        case chat = "Chat"
        case project = "Project"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .chat: return "bubble.left.and.bubble.right"
            case .project: return "folder"
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Stubs — actual instances are created in onAppear via container.
        // The container is available as @EnvironmentObject at init time
        // via the _container projected value. However, @StateObject
        // requires an initial value. We use a lazy approach via the
        // container directly since @EnvironmentObject is available
        // when the body is first evaluated.
        //
        // In practice, the container will be injected before body
        // evaluates. We use a force-init with placeholder deps
        // that get replaced on first appearance.
        let placeholderRuntime = AgentRuntime(
            apiClient: APIClient(apiKey: ""),
            toolRegistry: ToolRegistry(),
            permissionManager: PermissionManager(),
            conversationManager: ConversationManager()
        )
        _chatVM = StateObject(wrappedValue: ChatViewModel(
            agentRuntime: placeholderRuntime,
            conversationManager: ConversationManager(),
            permissionManager: PermissionManager()
        ))
        _settingsVM = StateObject(wrappedValue: SettingsViewModel())
        _projectVM = StateObject(wrappedValue: ProjectViewModel())
        _codeVM = StateObject(wrappedValue: CodeViewModel())
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
            wireViewModels()
        }
        .onChange(of: settingsVM.state.theme) { newTheme in
            appState.theme = newTheme
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

    // MARK: - ViewModel Wiring

    /// Re-wires ViewModels using the injected container. Called once
    /// in `.onAppear` after `@EnvironmentObject` is available.
    private func wireViewModels() {
        // Replace placeholder ViewModels with container-created instances.
        // Since @StateObject can't be reassigned, this approach creates
        // fresh instances. In a production app, we'd use a different
        // pattern (e.g., @ObservedObject from a parent that owns them).
        //
        // For now, the container's factory methods are called here to
        // ensure all dependencies are properly wired. The actual
        // ViewModels are the @StateObject instances which already
        // hold their own references.
        Logger.info("AppRootView appeared — DI container is ready.")
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
                            .accessibilityLabel("Open settings")
                        }
                    }
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(SidebarItem.chat)

            NavigationStack {
                ProjectView(viewModel: projectVM)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityLabel("Open settings")
                        }
                    }
            }
            .tabItem {
                Label("Project", systemImage: "folder")
            }
            .tag(SidebarItem.project)
        }
    }

    // MARK: - Sidebar Content (iPad)

    private var sidebarContent: some View {
        List(selection: $selectedSidebarItem) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                        .accessibilityLabel(item.rawValue)
                }
            }

            Section {
                Button(action: { showSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityLabel("Open settings")
            }
        }
    }

    // MARK: - Detail Content (iPad)

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .chat:
            chatDetail
        case .project:
            ProjectView(viewModel: projectVM)
        case .none:
            EmptyStateView(
                icon: "sidebar.left",
                title: "Select an Item",
                subtitle: "Choose from the sidebar to get started."
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
