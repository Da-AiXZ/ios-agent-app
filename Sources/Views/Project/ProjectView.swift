import SwiftUI

/// Project file browser showing the current project's directory tree,
/// recent projects list, and folder picker for opening new projects.
///
/// Binds to `ProjectViewModel` and dispatches file selection and
/// project management intents.
struct ProjectView: View {

    // MARK: - Properties

    /// The project ViewModel driving this view.
    @ObservedObject var viewModel: ProjectViewModel

    /// The global application state.
    @EnvironmentObject var appState: AppState

    /// Whether the folder picker sheet is presented.
    @State private var showFolderPicker = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.state.rootURL == nil {
                    // No project open: show recent projects + picker.
                    noProjectView
                } else {
                    // Project open: show file tree.
                    projectContentView
                }
            }
            .navigationTitle(viewModel.state.projectName.isEmpty ? "Project" : viewModel.state.projectName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 4) {
                        if viewModel.state.rootURL != nil {
                            Button(action: { viewModel.dispatch(.refreshFileList) }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Refresh file list")
                            .disabled(viewModel.state.isLoading)
                        }

                        Button(action: { showFolderPicker = true }) {
                            Image(systemName: "folder.badge.plus")
                        }
                        .accessibilityLabel("Open project folder")
                    }
                }
            }
        }
        .folderPicker(isPresented: $showFolderPicker) { url in
            viewModel.dispatch(.openProject(url))
        }
        .onReceive(viewModel.effects) { effect in
            handleEffect(effect)
        }
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - No Project View

    private var noProjectView: some View {
        VStack(spacing: 0) {
            // Recent projects.
            if !viewModel.state.recentProjects.isEmpty {
                List {
                    Section {
                        ForEach(viewModel.state.recentProjects) { project in
                            Button(action: { viewModel.dispatch(.openRecentProject(project)) }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.title3)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(project.rootURL.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if let lastOpened = project.lastOpened {
                                        Text(lastOpened, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .accessibilityLabel("Open recent project: \(project.name)")
                        }
                    } header: {
                        Text("Recent Projects")
                    }
                }
            } else {
                EmptyStateView(
                    icon: "folder",
                    title: "No Project Open",
                    subtitle: "Open a project folder to browse files and start coding with the AI agent.",
                    actionLabel: "Open Folder",
                    action: { showFolderPicker = true }
                )
            }
        }
    }

    // MARK: - Project Content View

    private var projectContentView: some View {
        Group {
            if viewModel.state.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading files...")
                        .accessibilityLabel("Loading project files")
                    Spacer()
                }
            } else if viewModel.state.files.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "Empty Directory",
                    subtitle: "This directory contains no files."
                )
            } else {
                List {
                    Section {
                        // Navigate up.
                        Button(action: { viewModel.dispatch(.navigateUp) }) {
                            HStack {
                                Image(systemName: "arrow.up")
                                    .foregroundColor(.accentColor)
                                Text("..")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .accessibilityLabel("Navigate to parent directory")

                        ForEach(viewModel.state.files) { item in
                            ProjectFileRow(item: item, onSelect: { file in
                                viewModel.dispatch(.selectFile(file))
                            })
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Effects

    private func handleEffect(_ effect: ProjectEffect) {
        switch effect {
        case .showFileContent(let url):
            Logger.uiInfo("File selected: \(url.path)")
            // The parent view should handle navigation to the code editor.
        case .showError(let message):
            Logger.error("Project error: \(message)")
        case .navigateToProjectPicker:
            break
        }
    }
}

// MARK: - Previews

#Preview {
    ProjectView(viewModel: ProjectViewModel())
        .environmentObject(AppState())
}
