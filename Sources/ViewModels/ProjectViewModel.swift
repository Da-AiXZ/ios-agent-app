import Foundation
import Combine
import SwiftUI

// MARK: - ProjectState

/// The complete UI state for the project/file browser screen.
struct ProjectState: ViewState {

    /// The root URL of the currently open project.
    var rootURL: URL?

    /// The list of file items at the current directory level.
    var files: [FileItem] = []

    /// The currently selected file item, if any.
    var selectedFile: FileItem?

    /// Whether the file list is currently loading.
    var isLoading: Bool = false

    /// The list of recently opened projects.
    var recentProjects: [Project] = []

    /// The current project name.
    var projectName: String = ""

    /// An error message to display, if any.
    var error: String?
}

// MARK: - ProjectIntent

/// User actions that the ProjectViewModel can process.
@frozen
enum ProjectIntent: ViewIntent {

    /// Open a project from a directory URL.
    case openProject(URL)

    /// Close the current project and return to the project picker.
    case closeProject

    /// Select a file item to view or edit.
    case selectFile(FileItem)

    /// Refresh the file list from disk.
    case refreshFileList

    /// Open a recently used project.
    case openRecentProject(Project)

    /// Navigate into a subdirectory.
    case navigateToDirectory(FileItem)

    /// Navigate up to the parent directory.
    case navigateUp
}

// MARK: - ProjectEffect

/// One-time side effects from the ProjectViewModel.
@frozen
enum ProjectEffect: ViewEffect {

    /// Open the file at the given URL in the code editor.
    case showFileContent(URL)

    /// Show an error alert with the given message.
    case showError(String)

    /// Navigate to the project picker screen.
    case navigateToProjectPicker
}

// MARK: - ProjectViewModel

/// ViewModel for the project and file browser screen.
///
/// Manages the currently open project's directory structure, file
/// selection, and recent project history. Uses `FileSystemService`
/// to enumerate directories and build the `FileItem` tree.
///
/// The file tree is loaded up to 3 levels deep, sorted with
/// directories first, then alphabetically by name.
@MainActor
final class ProjectViewModel: MVIViewModel, ObservableObject {

    // MARK: - MVIViewModel

    typealias State = ProjectState
    typealias Intent = ProjectIntent
    typealias Effect = ProjectEffect

    @Published var state: ProjectState = ProjectState()

    var effects: AnyPublisher<Effect, Never> {
        effectsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let fsService: FileSystemServiceProtocol
    private var effectsSubject = PassthroughSubject<Effect, Never>()

    /// The maximum depth for recursive directory listing.
    private let maxDepth = 3

    /// Key for persisting recent projects in UserDefaults.
    private let recentProjectsKey = "com.ios-agent-app.recent-projects"

    // MARK: - Initialization

    init(fsService: FileSystemServiceProtocol = FileSystemService()) {
        self.fsService = fsService

        // Load recent projects.
        loadRecentProjects()
    }

    // MARK: - Intent Dispatch

    func dispatch(_ intent: ProjectIntent) {
        switch intent {
        case .openProject(let url):
            handleOpenProject(url)
        case .closeProject:
            handleCloseProject()
        case .selectFile(let file):
            handleSelectFile(file)
        case .refreshFileList:
            handleRefreshFileList()
        case .openRecentProject(let project):
            handleOpenRecentProject(project)
        case .navigateToDirectory(let dir):
            handleNavigateToDirectory(dir)
        case .navigateUp:
            handleNavigateUp()
        }
    }

    // MARK: - Intent Handlers

    /// Opens a project at the given root URL, loads the file tree,
    /// and persists it to the recent projects list.
    private func handleOpenProject(_ url: URL) {
        Logger.uiInfo("Opening project: \(url.path)")

        var updated = state
        updated.rootURL = url
        updated.isLoading = true
        updated.error = nil
        updated.projectName = url.lastPathComponent
        updated.selectedFile = nil
        state = updated

        Task {
            do {
                let items = try fsService.listDirectory(at: url, recursive: false)
                var updated = state
                updated.files = items
                updated.isLoading = false

                // Add to recent projects.
                let project = Project(
                    name: url.lastPathComponent,
                    rootURL: url,
                    lastOpened: Date()
                )
                addRecentProject(project)

                state = updated
                Logger.uiInfo("Project opened with \(items.count) root items")
            } catch {
                var updated = state
                updated.isLoading = false
                updated.error = error.localizedDescription
                state = updated
                effectsSubject.send(.showError(error.localizedDescription))
                Logger.error("Failed to open project: \(error.localizedDescription)")
            }
        }
    }

    /// Closes the current project and resets state.
    private func handleCloseProject() {
        state = ProjectState()
        effectsSubject.send(.navigateToProjectPicker)
        Logger.uiInfo("Project closed")
    }

    /// Handles file selection. Directories are navigated into;
    /// files trigger the `showFileContent` effect.
    private func handleSelectFile(_ file: FileItem) {
        var updated = state
        updated.selectedFile = file
        state = updated

        if file.isDirectory {
            handleNavigateToDirectory(file)
        } else {
            effectsSubject.send(.showFileContent(file.url))
        }
    }

    /// Refreshes the file list at the current root or directory level.
    private func handleRefreshFileList() {
        guard let rootURL = state.rootURL else { return }

        var updated = state
        updated.isLoading = true
        state = updated

        Task {
            do {
                let items = try fsService.listDirectory(at: rootURL, recursive: false)
                var updated = state
                updated.files = items
                updated.isLoading = false
                state = updated
            } catch {
                var updated = state
                updated.isLoading = false
                updated.error = error.localizedDescription
                state = updated
            }
        }
    }

    /// Opens a project from the recent projects list.
    private func handleOpenRecentProject(_ project: Project) {
        handleOpenProject(project.rootURL)
    }

    /// Navigates into a subdirectory, loading its contents.
    private func handleNavigateToDirectory(_ dir: FileItem) {
        guard dir.isDirectory else { return }

        var updated = state
        updated.rootURL = dir.url
        updated.isLoading = true
        state = updated

        Task {
            do {
                let items = try fsService.listDirectory(at: dir.url, recursive: false)
                var updated = state
                updated.files = items
                updated.isLoading = false
                state = updated
            } catch {
                var updated = state
                updated.isLoading = false
                updated.error = error.localizedDescription
                state = updated
            }
        }
    }

    /// Navigates up to the parent directory.
    private func handleNavigateUp() {
        guard let currentURL = state.rootURL else { return }
        let parentURL = currentURL.deletingLastPathComponent()

        var updated = state
        updated.rootURL = parentURL
        updated.isLoading = true
        state = updated

        Task {
            do {
                let items = try fsService.listDirectory(at: parentURL, recursive: false)
                var updated = state
                updated.files = items
                updated.isLoading = false
                state = updated
            } catch {
                var updated = state
                updated.isLoading = false
                updated.error = error.localizedDescription
                state = updated
            }
        }
    }

    // MARK: - Recent Projects Persistence

    /// Loads recent projects from UserDefaults.
    private func loadRecentProjects() {
        guard let data = UserDefaults.standard.data(forKey: recentProjectsKey),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else {
            return
        }

        var updated = state
        updated.recentProjects = projects
        state = updated
    }

    /// Adds a project to the recent list and persists it.
    private func addRecentProject(_ project: Project) {
        var recent = state.recentProjects

        // Remove duplicate if exists.
        recent.removeAll(where: { $0.rootURL == project.rootURL })

        // Insert at front.
        recent.insert(project, at: 0)

        // Limit to 10 recent projects.
        if recent.count > 10 {
            recent = Array(recent.prefix(10))
        }

        var updated = state
        updated.recentProjects = recent
        state = updated

        // Persist.
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: recentProjectsKey)
        }
    }
}
