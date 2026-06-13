import SwiftUI
import UniformTypeIdentifiers

/// A UIKit bridge that wraps `UIDocumentPickerViewController` for
/// selecting project root directories in SwiftUI.
///
/// Uses `UIViewControllerRepresentable` to present the native iOS
/// folder picker (`.folder` content type). The selected URL is
/// returned through a callback closure.
struct DocumentPickerView: UIViewControllerRepresentable {

    /// Called with the selected folder URL.
    var onPick: (URL) -> Void

    /// Called when the picker is dismissed without selection.
    var onDismiss: (() -> Void)?

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onDismiss: onDismiss)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIDocumentPickerDelegate {

        let onPick: (URL) -> Void
        let onDismiss: (() -> Void)?

        init(onPick: @escaping (URL) -> Void, onDismiss: (() -> Void)?) {
            self.onPick = onPick
            self.onDismiss = onDismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing the security-scoped resource.
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Create a local bookmark for persistent access.
            if let bookmarkData = try? url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                onPick(url)
            } else {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDismiss?()
        }
    }
}

// MARK: - View Modifier

extension View {

    /// Presents a document picker sheet for selecting a folder.
    func folderPicker(
        isPresented: Binding<Bool>,
        onPick: @escaping (URL) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            DocumentPickerView(onPick: onPick, onDismiss: { isPresented.wrappedValue = false })
        }
    }
}
