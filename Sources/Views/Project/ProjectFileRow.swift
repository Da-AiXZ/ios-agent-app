import SwiftUI

/// A single row in the project file tree, supporting recursive
/// directory expansion via `DisclosureGroup`.
///
/// Files display the appropriate icon based on extension, while
/// directories show a folder icon and can be expanded to reveal
/// children (up to 3 levels deep).
struct ProjectFileRow: View {

    /// The file item to display.
    let item: FileItem

    /// Called when the user taps this row.
    var onSelect: (FileItem) -> Void

    /// The current nesting depth (default: 0).
    var depth: Int = 0

    /// Maximum recursion depth for directory expansion.
    private let maxDepth = 3

    // MARK: - Body

    var body: some View {
        if item.isDirectory {
            // Directories: DisclosureGroup for expansion.
            if let children = item.children, !children.isEmpty, depth < maxDepth {
                DisclosureGroup {
                    ForEach(children) { child in
                        ProjectFileRow(
                            item: child,
                            onSelect: onSelect,
                            depth: depth + 1
                        )
                    }
                } label: {
                    directoryLabel
                }
                .accessibilityLabel("Directory: \(item.name)")
            } else {
                Button(action: { onSelect(item) }) {
                    directoryLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Directory: \(item.name)")
            }
        } else {
            // Files: tap to select.
            Button(action: { onSelect(item) }) {
                fileLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("File: \(item.name)")
        }
    }

    // MARK: - Labels

    private var directoryLabel: some View {
        HStack(spacing: 8) {
            Text("📁")
                .font(.body)
                .accessibilityHidden(true)

            Text(item.name)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if let children = item.children {
                Text("(\(children.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("\(children.count) items")
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, CGFloat(depth) * 16)
    }

    private var fileLabel: some View {
        HStack(spacing: 8) {
            Text(fileIcon)
                .font(.body)
                .accessibilityHidden(true)

            Text(item.name)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Text(item.formattedFileSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("Size: \(item.formattedFileSize)")
        }
        .padding(.vertical, 2)
        .padding(.leading, CGFloat(depth) * 16)
    }

    // MARK: - File Icon

    /// Returns an emoji based on the file extension.
    private var fileIcon: String {
        switch item.url.pathExtension.lowercased() {
        case "swift": return "🔷"
        case "md", "markdown": return "📝"
        case "json": return "📋"
        case "py": return "🐍"
        case "js", "jsx": return "🟨"
        case "ts", "tsx": return "🟦"
        case "html": return "🌐"
        case "css", "scss": return "🎨"
        case "yaml", "yml": return "⚙️"
        case "xml", "plist": return "📋"
        case "txt": return "📄"
        case "png", "jpg", "jpeg", "gif", "svg": return "🖼️"
        case "sh", "bash", "zsh": return "⚡"
        case "rb": return "💎"
        case "go": return "🔵"
        case "rs": return "🦀"
        case "java", "kt": return "☕"
        default: return "📄"
        }
    }
}

// MARK: - Previews

#Preview {
    List {
        ProjectFileRow(item: FileItem(
            name: "Sources",
            url: URL(fileURLWithPath: "/project/Sources"),
            isDirectory: true,
            children: [
                FileItem(name: "App", url: URL(fileURLWithPath: "/project/Sources/App"), isDirectory: true, children: [
                    FileItem(name: "AppMain.swift", url: URL(fileURLWithPath: "/project/Sources/App/AppMain.swift"), fileSize: 2048),
                ]),
                FileItem(name: "Models", url: URL(fileURLWithPath: "/project/Sources/Models"), isDirectory: true, children: [
                    FileItem(name: "Message.swift", url: URL(fileURLWithPath: "/project/Sources/Models/Message.swift"), fileSize: 4096),
                    FileItem(name: "Conversation.swift", url: URL(fileURLWithPath: "/project/Sources/Models/Conversation.swift"), fileSize: 3072),
                ]),
            ]
        ), onSelect: { _ in })

        ProjectFileRow(item: FileItem(
            name: "Package.swift",
            url: URL(fileURLWithPath: "/project/Package.swift"),
            fileSize: 1024
        ), onSelect: { _ in })
    }
}
