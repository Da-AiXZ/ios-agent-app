import SwiftUI

/// Code editor view combining a file tab bar, syntax-highlighted
/// text editor, and a collapsible diff panel.
///
/// Binds to `CodeViewModel`, dispatching edit intents and reacting
/// to effects like save confirmations and navigation.
struct CodeView: View {

    // MARK: - Properties

    /// The code editor ViewModel.
    @ObservedObject var viewModel: CodeViewModel

    /// The global application state.
    @EnvironmentObject var appState: AppState

    /// Whether the diff panel is currently expanded.
    @State private var showDiffPanel: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar.
                editorToolbar

                Divider()

                // File tab bar (placeholder for multi-file).
                if let file = viewModel.state.file {
                    FileTabBar(
                        files: [file],
                        selectedFile: file,
                        onSelect: { _ in },
                        onClose: { _ in viewModel.dispatch(.closeFile) }
                    )
                }

                Divider()

                // Editor content.
                editorContent

                // Diff panel.
                if showDiffPanel && !viewModel.state.diffChunks.isEmpty {
                    Divider()
                    DiffView(
                        chunks: viewModel.state.diffChunks,
                        originalContent: viewModel.state.originalContent,
                        onAccept: { edit in
                            viewModel.dispatch(.acceptEdit(oldString: edit.oldString, newString: edit.newString))
                        },
                        onReject: {
                            viewModel.dispatch(.discardChanges)
                        }
                    )
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.35)
                }
            }
            .navigationTitle(viewModel.state.file?.name ?? "Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { viewModel.dispatch(.saveFile) }) {
                        Text(viewModel.state.isDirty ? "Save *" : "Save")
                            .fontWeight(viewModel.state.isDirty ? .bold : .regular)
                    }
                    .accessibilityLabel(viewModel.state.isDirty ? "Save file with changes" : "Save file")
                }
            }
        }
        .onReceive(viewModel.effects) { effect in
            handleEffect(effect)
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Toolbar

    private var editorToolbar: some View {
        HStack(spacing: 8) {
            if let file = viewModel.state.file {
                Text(fileIcon(for: file.url.pathExtension))
                    .font(.body)
                    .accessibilityHidden(true)

                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Editing: \(file.name)")
            }

            if !viewModel.state.language.isEmpty {
                Text(viewModel.state.language.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityLabel("Language: \(viewModel.state.language)")
            }

            Spacer()

            // Diff toggle.
            Button(action: { viewModel.dispatch(.toggleDiffView) }) {
                Image(systemName: viewModel.state.showingDiff
                      ? "rectangle.split.2x1.fill"
                      : "rectangle.split.2x1")
            }
            .accessibilityLabel(viewModel.state.showingDiff ? "Hide diff view" : "Show diff view")

            // Reload.
            Button(action: { viewModel.dispatch(.reloadFile) }) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Reload file from disk")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        if viewModel.state.file == nil {
            EmptyStateView(
                icon: "doc.text",
                title: "No File Open",
                subtitle: "Select a file from the project browser to start editing."
            )
        } else if viewModel.state.showingDiff {
            DiffView(
                chunks: viewModel.state.diffChunks,
                originalContent: viewModel.state.originalContent,
                onAccept: { edit in
                    viewModel.dispatch(.acceptEdit(
                        oldString: edit.oldString,
                        newString: edit.newString
                    ))
                },
                onReject: {
                    viewModel.dispatch(.discardChanges)
                }
            )
        } else {
            TextEditor(text: Binding(
                get: { viewModel.state.content },
                set: { viewModel.dispatch(.updateContent($0)) }
            ))
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemBackground))
            .accessibilityLabel("Code editor for \(viewModel.state.file?.name ?? "file")")
        }
    }

    // MARK: - Effects

    private func handleEffect(_ effect: CodeEffect) {
        switch effect {
        case .showSaveSuccess:
            Logger.uiInfo("File saved successfully")
        case .showDiffResult:
            showDiffPanel = true
        case .showError(let message):
            Logger.error("Code editor error: \(message)")
        case .navigateAway:
            break
        }
    }

    // MARK: - Helpers

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "swift": return "🔷"
        case "md": return "📝"
        case "json": return "📋"
        case "py": return "🐍"
        case "js", "jsx": return "🟨"
        case "ts", "tsx": return "🟦"
        default: return "📄"
        }
    }
}

// MARK: - Previews

#Preview {
    CodeView(viewModel: CodeViewModel())
        .environmentObject(AppState())
}
