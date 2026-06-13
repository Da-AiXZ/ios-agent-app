import SwiftUI

/// The main chat interface showing the message list, input field,
/// and agent status indicators.
///
/// Binds to `ChatViewModel` via `@ObservedObject`, dispatches user
/// actions as intents, and handles one-time effects through
/// `.onReceive(viewModel.effects)`.
struct ChatView: View {

    // MARK: - Properties

    /// The chat ViewModel driving this view.
    @ObservedObject var viewModel: ChatViewModel

    /// The global application state for theme/language.
    @EnvironmentObject var appState: AppState

    /// The pending permission tool call for the dialog overlay.
    @State private var pendingPermissionTool: ToolCallState?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Conversation header.
            conversationHeader

            Divider()

            // Message list.
            messageList

            Divider()

            // Input area.
            inputArea
        }
        .background(Color(UIColor.systemBackground))
        .permissionDialog(
            toolCall: pendingPermissionTool,
            onApprove: {
                if let tool = pendingPermissionTool {
                    viewModel.dispatch(.approveTool(toolCallId: tool.id))
                }
                pendingPermissionTool = nil
            },
            onDeny: {
                if let tool = pendingPermissionTool {
                    viewModel.dispatch(.denyTool(toolCallId: tool.id))
                }
                pendingPermissionTool = nil
            }
        )
        .onReceive(viewModel.effects) { effect in
            handleEffect(effect)
        }
        .onReceive(viewModel.$state.map(\.currentToolCalls)) { calls in
            if let waiting = calls.first(where: { $0.status == .waitingPermission }) {
                pendingPermissionTool = waiting
            }
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Conversation Header

    private var conversationHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.state.conversation?.title ?? L10n.chat(lang: appState.language))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Conversation: \(viewModel.state.conversation?.title ?? "Chat")")

                if viewModel.state.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text(L10n.generating(lang: appState.language))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(L10n.agentGenerating(lang: appState.language))
                }
            }

            Spacer()

            // New conversation button.
            Button(action: { viewModel.dispatch(.clearConversation) }) {
                Image(systemName: "square.and.pencil")
                    .font(.body)
            }
            .accessibilityLabel(L10n.newConversation(lang: appState.language))
            .disabled(viewModel.state.isStreaming)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.state.messages.isEmpty {
                        EmptyStateView(
                            icon: "bubble.left.and.bubble.right",
                            title: L10n.startConversation(lang: appState.language),
                            subtitle: L10n.startConversationSubtitle(lang: appState.language)
                        )
                        .padding(.top, 60)
                    }

                    ForEach(viewModel.state.messages) { message in
                        MessageRow(
                            message: message,
                            toolCallStates: viewModel.state.currentToolCalls,
                            onApproveTool: { id in viewModel.dispatch(.approveTool(toolCallId: id)) },
                            onDenyTool: { id in viewModel.dispatch(.denyTool(toolCallId: id)) }
                        )
                        .id(message.id)
                    }

                    // Streaming text indicator.
                    if viewModel.state.isStreaming && !viewModel.state.streamingText.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text("🤖")
                                .font(.title3)
                                .accessibilityHidden(true)

                            MarkdownRenderer(text: viewModel.state.streamingText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .accessibilityLabel(L10n.streamingResponse(lang: appState.language))

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .id("streaming")
                    }

                    // Scroll anchor.
                    Color.clear
                        .frame(height: 1)
                        .id("scrollAnchor")
                }
            }
            .onChange(of: viewModel.state.messages.count) { _ in
                withAnimation {
                    proxy.scrollTo("scrollAnchor", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.state.streamingText) { _ in
                withAnimation {
                    proxy.scrollTo("scrollAnchor", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            // Error banner.
            if let error = viewModel.state.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    Spacer()
                    Button(action: { viewModel.dispatch(.retryLastMessage) }) {
                        Text(L10n.retry(lang: appState.language))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .accessibilityLabel(L10n.retry(lang: appState.language))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))

                Divider()
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(L10n.askAnything(lang: appState.language), text: Binding(
                    get: { viewModel.state.inputText },
                    set: { viewModel.dispatch(.updateInputText($0)) }
                ), axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...6)
                .accessibilityLabel(L10n.messageInput(lang: appState.language))
                .disabled(viewModel.state.isStreaming)
                .onSubmit {
                    viewModel.dispatch(.sendMessage(viewModel.state.inputText))
                }

                if viewModel.state.isStreaming {
                    Button(action: { viewModel.dispatch(.stopGeneration) }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .accessibilityLabel(L10n.stopGeneration(lang: appState.language))
                } else {
                    Button(action: {
                        viewModel.dispatch(.sendMessage(viewModel.state.inputText))
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.state.canSend ? .accentColor : .secondary)
                    }
                    .accessibilityLabel(L10n.sendMessage(lang: appState.language))
                    .disabled(!viewModel.state.canSend)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Effects

    private func handleEffect(_ effect: ChatEffect) {
        switch effect {
        case .scrollToBottom:
            break // Handled by onChange above.
        case .showError(let message):
            Logger.error("Chat error: \(message)")
        case .navigateToFile(let url):
            Logger.uiInfo("Navigate to file: \(url.path)")
        case .showToolApproval(let tool):
            pendingPermissionTool = tool
        }
    }
}

// MARK: - L10n Helpers

/// Convenience wrapper for localizing ChatView strings.
private enum L10n {
    static func chat(lang: AppLanguage) -> String {
        LocalizedString.get("chat", lang: lang)
    }
    static func startConversation(lang: AppLanguage) -> String {
        LocalizedString.get("start_conversation", lang: lang)
    }
    static func startConversationSubtitle(lang: AppLanguage) -> String {
        LocalizedString.get("start_conversation_subtitle", lang: lang)
    }
    static func generating(lang: AppLanguage) -> String {
        LocalizedString.get("generating", lang: lang)
    }
    static func askAnything(lang: AppLanguage) -> String {
        LocalizedString.get("ask_anything", lang: lang)
    }
    static func retry(lang: AppLanguage) -> String {
        LocalizedString.get("retry", lang: lang)
    }
    static func newConversation(lang: AppLanguage) -> String {
        LocalizedString.get("new_conversation", lang: lang)
    }
    static func sendMessage(lang: AppLanguage) -> String {
        LocalizedString.get("send_message", lang: lang)
    }
    static func stopGeneration(lang: AppLanguage) -> String {
        LocalizedString.get("stop_generation", lang: lang)
    }
    static func messageInput(lang: AppLanguage) -> String {
        LocalizedString.get("message_input", lang: lang)
    }
    static func agentGenerating(lang: AppLanguage) -> String {
        LocalizedString.get("agent_generating", lang: lang)
    }
    static func streamingResponse(lang: AppLanguage) -> String {
        LocalizedString.get("streaming_response", lang: lang)
    }
}
