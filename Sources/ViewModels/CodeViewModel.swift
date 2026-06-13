import Foundation
import Combine
import SwiftUI

// MARK: - CodeState

/// The complete UI state for the code editor screen.
struct CodeState: ViewState {

    /// The file item currently open in the editor.
    var file: FileItem?

    /// The current textual content of the file.
    var content: String = ""

    /// The syntax-highlighted ranges for the current content.
    var highlightedRanges: [HighlightedRange] = []

    /// The diff chunks when comparing original vs modified content.
    var diffChunks: [DiffChunk] = []

    /// Whether the file has unsaved changes.
    var isDirty: Bool = false

    /// The detected programming language for syntax highlighting.
    var language: String = ""

    /// The original content before editing (for diff computation).
    var originalContent: String?

    /// Whether the diff view is currently visible.
    var showingDiff: Bool = false

    /// An error message to display, if any.
    var error: String?
}

// MARK: - CodeIntent

/// User actions that the CodeViewModel can process.
@frozen
enum CodeIntent: ViewIntent {

    /// Open a file for viewing/editing.
    case openFile(FileItem)

    /// Save the current file content to disk.
    case saveFile

    /// Reload the file from disk, discarding local changes.
    case reloadFile

    /// Show a diff between the original content and the given new content.
    case showDiff(originalContent: String, newContent: String)

    /// Accept an edit by performing a string replacement in the content.
    case acceptEdit(oldString: String, newString: String)

    /// Discard all local changes and revert to the original content.
    case discardChanges

    /// Update the editor content (triggered on each keystroke).
    case updateContent(String)

    /// Close the currently open file.
    case closeFile

    /// Toggle the diff view visibility.
    case toggleDiffView
}

// MARK: - CodeEffect

/// One-time side effects from the CodeViewModel.
@frozen
enum CodeEffect: ViewEffect {

    /// File was saved successfully.
    case showSaveSuccess

    /// Show the diff result after computation.
    case showDiffResult

    /// Show an error alert with the given message.
    case showError(String)

    /// Navigate away from the editor (file closed).
    case navigateAway
}

// MARK: - CodeViewModel

/// ViewModel for the code editor screen.
///
/// Manages file content, syntax highlighting, and diff visualization.
/// Orchestrates reads/writes through `FileSystemService`, highlighting
/// through `SyntaxHighlightService`, and diff computation through
/// `DiffService`.
///
/// When a file is opened, the language is auto-detected from the file
/// extension and syntax highlighting is applied. The original content
/// is preserved for diff computation and change tracking.
@MainActor
final class CodeViewModel: MVIViewModel, ObservableObject {

    // MARK: - MVIViewModel

    typealias State = CodeState
    typealias Intent = CodeIntent
    typealias Effect = CodeEffect

    @Published var state: CodeState = CodeState()

    var effects: AnyPublisher<Effect, Never> {
        effectsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let fsService: FileSystemServiceProtocol
    private let syntaxService: SyntaxHighlightServiceProtocol
    private let diffService: DiffServiceProtocol
    private var effectsSubject = PassthroughSubject<Effect, Never>()

    // MARK: - Initialization

    init(
        fsService: FileSystemServiceProtocol = FileSystemService(),
        syntaxService: SyntaxHighlightServiceProtocol = SyntaxHighlightService(),
        diffService: DiffServiceProtocol = DiffService()
    ) {
        self.fsService = fsService
        self.syntaxService = syntaxService
        self.diffService = diffService
    }

    // MARK: - Intent Dispatch

    func dispatch(_ intent: CodeIntent) {
        switch intent {
        case .openFile(let file):
            handleOpenFile(file)
        case .saveFile:
            handleSaveFile()
        case .reloadFile:
            handleReloadFile()
        case .showDiff(let original, let new):
            handleShowDiff(original: original, new: new)
        case .acceptEdit(let oldString, let newString):
            handleAcceptEdit(oldString: oldString, newString: newString)
        case .discardChanges:
            handleDiscardChanges()
        case .updateContent(let content):
            handleUpdateContent(content)
        case .closeFile:
            handleCloseFile()
        case .toggleDiffView:
            handleToggleDiffView()
        }
    }

    // MARK: - Intent Handlers

    /// Opens a file: reads its content, detects the language, and applies
    /// syntax highlighting. The original content is preserved for diffing.
    private func handleOpenFile(_ file: FileItem) {
        guard !file.isDirectory else {
            effectsSubject.send(.showError("Cannot open a directory as a file."))
            return
        }

        Logger.uiInfo("Opening file: \(file.name)")

        let language = syntaxService.detectLanguage(
            fileExtension: file.url.pathExtension
        ) ?? ""

        let content: String
        do {
            content = try fsService.readFile(at: file.url)
        } catch {
            effectsSubject.send(.showError("Failed to open file: \(error.localizedDescription)"))
            return
        }

        // Apply syntax highlighting.
        let highlightedRanges = syntaxService.highlight(
            source: content,
            language: language,
            theme: .light
        )

        var updated = state
        updated.file = file
        updated.content = content
        updated.originalContent = content
        updated.highlightedRanges = highlightedRanges
        updated.language = language
        updated.isDirty = false
        updated.diffChunks = []
        updated.showingDiff = false
        updated.error = nil
        state = updated

        Logger.uiInfo("Opened file: \(file.name) (\(content.count) chars, language: \(language))")
    }

    /// Saves the current content to disk, clears the dirty flag,
    /// and updates the original content reference.
    private func handleSaveFile() {
        guard let file = state.file else {
            effectsSubject.send(.showError("No file is currently open."))
            return
        }

        do {
            try fsService.writeFile(content: state.content, at: file.url)
            var updated = state
            updated.originalContent = state.content
            updated.isDirty = false
            state = updated
            effectsSubject.send(.showSaveSuccess)
            Logger.uiInfo("Saved file: \(file.name)")
        } catch {
            effectsSubject.send(.showError("Failed to save file: \(error.localizedDescription)"))
            Logger.error("Save failed: \(error.localizedDescription)")
        }
    }

    /// Reloads the file from disk, discarding any local changes.
    private func handleReloadFile() {
        guard let file = state.file else { return }

        let content: String
        do {
            content = try fsService.readFile(at: file.url)
        } catch {
            effectsSubject.send(.showError("Failed to reload file: \(error.localizedDescription)"))
            return
        }

        let highlightedRanges = syntaxService.highlight(
            source: content,
            language: state.language,
            theme: .light
        )

        var updated = state
        updated.content = content
        updated.originalContent = content
        updated.highlightedRanges = highlightedRanges
        updated.isDirty = false
        updated.diffChunks = []
        updated.showingDiff = false
        state = updated

        Logger.uiInfo("Reloaded file: \(file.name)")
    }

    /// Computes the diff between the original content and the given
    /// new content string.
    private func handleShowDiff(original: String, new: String) {
        let chunks = diffService.diff(
            old: original,
            new: new,
            contextLines: 3
        )

        var updated = state
        updated.diffChunks = chunks
        updated.showingDiff = true
        state = updated
        effectsSubject.send(.showDiffResult)

        Logger.uiInfo("Computed diff: \(chunks.count) chunks")
    }

    /// Applies an edit by replacing a string in the current content.
    /// This is used when accepting a diff suggestion from the agent.
    private func handleAcceptEdit(oldString: String, newString: String) {
        guard state.content.contains(oldString) else {
            effectsSubject.send(.showError("The specified string was not found in the current content."))
            return
        }

        let updatedContent = state.content.replacingOccurrences(of: oldString, with: newString)

        // Re-apply syntax highlighting.
        let highlightedRanges = syntaxService.highlight(
            source: updatedContent,
            language: state.language,
            theme: .light
        )

        var updated = state
        updated.content = updatedContent
        updated.highlightedRanges = highlightedRanges
        updated.isDirty = true
        updated.showingDiff = false
        state = updated

        Logger.uiInfo("Applied edit (\(oldString.count) → \(newString.count) chars)")
    }

    /// Discards all local changes, reverting to the original content.
    private func handleDiscardChanges() {
        guard let original = state.originalContent else { return }

        let highlightedRanges = syntaxService.highlight(
            source: original,
            language: state.language,
            theme: .light
        )

        var updated = state
        updated.content = original
        updated.highlightedRanges = highlightedRanges
        updated.isDirty = false
        updated.diffChunks = []
        updated.showingDiff = false
        state = updated

        Logger.uiInfo("Discarded changes")
    }

    /// Handles real-time content updates from the editor.
    /// Marks the file as dirty if content differs from original.
    private func handleUpdateContent(_ newContent: String) {
        var updated = state
        updated.content = newContent
        updated.isDirty = newContent != updated.originalContent

        // Re-highlight on content change for real-time syntax coloring.
        if !updated.language.isEmpty {
            updated.highlightedRanges = syntaxService.highlight(
                source: newContent,
                language: updated.language,
                theme: .light
            )
        }

        state = updated
    }

    /// Closes the currently open file.
    private func handleCloseFile() {
        state = CodeState()
        effectsSubject.send(.navigateAway)
        Logger.uiInfo("File closed")
    }

    /// Toggles the diff view between shown and hidden.
    private func handleToggleDiffView() {
        var updated = state
        updated.showingDiff.toggle()
        state = updated
    }
}
