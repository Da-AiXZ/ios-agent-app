import Foundation
import Combine
import SwiftUI

/// The global dependency injection container for the application.
///
/// Creates and manages singletons for all services, core engine
/// components, and provides factory methods for ViewModels. This
/// container ensures the correct dependency chain is wired:
///
/// ```
/// Services → Core Engine (APIClient, ToolRegistry, etc.)
///          → Tools (injected into ToolRegistry)
///          → AgentRuntime (receives all Core components)
///          → ViewModels (receive concrete dependencies)
/// ```
///
/// All ViewModel factory methods return fresh instances that share
/// the same underlying singletons (services, core engine).
@MainActor
final class DependencyContainer: ObservableObject {

    // MARK: - Published Properties

    /// The global application state (theme, language, agent status).
    @Published var appState = AppState()

    // MARK: - Services (Singletons)

    /// File system operations within the project sandbox.
    let fileSystemService: FileSystemServiceProtocol

    /// Git operations via CLI.
    let gitService: GitServiceProtocol

    /// Terminal command execution.
    let terminalService: TerminalServiceProtocol

    /// Syntax highlighting (P0: keyword tokenizer).
    let syntaxHighlightService: SyntaxHighlightServiceProtocol

    /// Diff computation (LCS-based).
    let diffService: DiffServiceProtocol

    /// File name and content search.
    let searchService: SearchServiceProtocol

    // MARK: - Core Engine (Singletons)

    /// SSE protocol parser.
    let sseParser: SSEParser

    /// HTTP SSE API client.
    private(set) var apiClient: APIClientProtocol

    /// Tool registration and execution registry.
    let toolRegistry: ToolRegistry

    /// Tool execution permission manager.
    let permissionManager: PermissionManager

    /// Conversation persistence manager.
    let conversationManager: ConversationManager

    /// Core agent execution loop.
    private(set) var agentRuntime: AgentRuntimeProtocol

    // MARK: - Initialization

    init() {
        // ── Phase 1: Services ──
        let fsService = FileSystemService()
        let gitSvc = GitService()
        let termSvc = TerminalService()
        let syntaxSvc = SyntaxHighlightService()
        let diffSvc = DiffService()
        let searchSvc = SearchService()

        self.fileSystemService = fsService
        self.gitService = gitSvc
        self.terminalService = termSvc
        self.syntaxHighlightService = syntaxSvc
        self.diffService = diffSvc
        self.searchService = searchSvc

        // ── Phase 2: Core Engine ──
        let parser = SSEParser()
        self.sseParser = parser

        let apiKey = KeychainHelper.load(key: "com.ios-agent-app.anthropic-api-key")
            ?? KeychainHelper.load(key: "com.ios-agent-app.openai-api-key")
            ?? ""
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: "com.ios-agent-app.api-endpoint")
            ?? AppConstants.defaultAnthropicAPIEndpoint
        let providerRaw = defaults.string(forKey: "com.ios-agent-app.api-provider") ?? "anthropic"
        let provider: APIProvider = (providerRaw == "openai") ? .openai : .anthropic
        let apiClient = APIClient(apiKey: apiKey, baseURL: baseURL, provider: provider)
        self.apiClient = apiClient

        let toolReg = ToolRegistry()
        self.toolRegistry = toolReg

        let permMgr = PermissionManager()
        self.permissionManager = permMgr

        let convMgr = ConversationManager()
        self.conversationManager = convMgr

        let agent = AgentRuntime(
            apiClient: apiClient,
            toolRegistry: toolReg,
            permissionManager: permMgr,
            conversationManager: convMgr
        )
        self.agentRuntime = agent

        // ── Phase 3: Register Tools ──
        registerAllTools(
            fsService: fsService,
            gitService: gitSvc,
            terminalService: termSvc,
            searchService: searchSvc
        )

        Logger.info("DependencyContainer initialized — all services, core, and tools wired.")
    }

    // MARK: - Tool Registration

    /// Registers all 12 tools into the ToolRegistry with their
    /// corresponding service dependencies.
    private func registerAllTools(
        fsService: FileSystemServiceProtocol,
        gitService: GitServiceProtocol,
        terminalService: TerminalServiceProtocol,
        searchService: SearchServiceProtocol
    ) {
        toolRegistry.register(ReadFileTool(fsService: fsService))
        toolRegistry.register(WriteFileTool(fsService: fsService))
        toolRegistry.register(EditFileTool(fsService: fsService))
        toolRegistry.register(ListDirectoryTool(fsService: fsService))
        toolRegistry.register(DeleteFileTool(fsService: fsService))
        toolRegistry.register(SearchContentTool(searchService: searchService))
        toolRegistry.register(SearchFilesTool(searchService: searchService))
        toolRegistry.register(ExecuteShellTool(terminalService: terminalService))
        toolRegistry.register(GitDiffTool(gitService: gitService))
        toolRegistry.register(GitStatusTool(gitService: gitService))
        toolRegistry.register(GitCommitTool(gitService: gitService))
        toolRegistry.register(WebSearchTool())

        Logger.info("All 12 tools registered in ToolRegistry.")
    }

    // MARK: - ViewModel Factories

    /// Creates a ChatViewModel wired to the shared agent runtime,
    /// permission manager, and conversation manager.
    func makeChatViewModel() -> ChatViewModel {
        ChatViewModel(
            agentRuntime: agentRuntime,
            conversationManager: conversationManager,
            permissionManager: permissionManager
        )
    }

    /// Creates a SettingsViewModel wired to the shared permission
    /// manager and KeychainHelper.
    func makeSettingsViewModel() -> SettingsViewModel {
        let vm = SettingsViewModel(permissionManager: permissionManager)
        return vm
    }

    /// Creates a ProjectViewModel wired to the shared file system service.
    func makeProjectViewModel() -> ProjectViewModel {
        ProjectViewModel(fsService: fileSystemService)
    }

    /// Creates a CodeViewModel wired to the shared file system,
    /// syntax highlighting, and diff services.
    func makeCodeViewModel() -> CodeViewModel {
        CodeViewModel(
            fsService: fileSystemService,
            syntaxService: syntaxHighlightService,
            diffService: diffService
        )
    }

    // MARK: - Dynamic Reconfiguration

    /// Reads the latest API key, endpoint, model, and provider from
    /// UserDefaults / Keychain and recreates the APIClient and
    /// AgentRuntime with the updated credentials.
    ///
    /// Call this after SettingsViewModel saves new settings so that
    /// subsequent requests use the correct authentication.
    func reconfigureAPIClient() {
        let apiKey = KeychainHelper.load(key: "com.ios-agent-app.anthropic-api-key")
            ?? KeychainHelper.load(key: "com.ios-agent-app.openai-api-key")
            ?? ""
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: "com.ios-agent-app.api-endpoint")
            ?? AppConstants.defaultAnthropicAPIEndpoint
        let modelId = defaults.string(forKey: "com.ios-agent-app.model-id")
            ?? AppConstants.defaultModelId
        let providerRaw = defaults.string(forKey: "com.ios-agent-app.api-provider") ?? ""
        let provider: APIProvider = (providerRaw == "openai") ? .openai : .anthropic

        let newClient = APIClient(apiKey: apiKey, baseURL: baseURL, provider: provider)
        self.apiClient = newClient

        let newAgent = AgentRuntime(
            apiClient: newClient,
            toolRegistry: toolRegistry,
            permissionManager: permissionManager,
            conversationManager: conversationManager
        )
        self.agentRuntime = newAgent

        Logger.info("APIClient reconfigued — endpoint: \(baseURL), provider: \(provider.rawValue)")
    }
}
