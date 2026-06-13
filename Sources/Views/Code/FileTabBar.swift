import SwiftUI

/// A horizontal scrollable tab bar for open files, similar to
/// Xcode's editor tabs.
///
/// Each tab shows the file name and a close button. The active
/// tab is highlighted with an accent underline indicator.
struct FileTabBar: View {

    /// The list of open file items.
    let files: [FileItem]

    /// The currently selected file item.
    var selectedFile: FileItem?

    /// Called when a tab is tapped.
    var onSelect: (FileItem) -> Void

    /// Called when a tab's close button is tapped.
    var onClose: (FileItem) -> Void

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(files) { file in
                    fileTab(file)
                }
            }
        }
        .frame(height: 36)
        .background(Color(UIColor.secondarySystemBackground))
        .dynamicTypeSize(.small ... .accessibility3)
    }

    // MARK: - Single Tab

    private func fileTab(_ file: FileItem) -> some View {
        let isSelected = selectedFile?.id == file.id

        return Button(action: { onSelect(file) }) {
            HStack(spacing: 4) {
                Text(fileIcon(for: file))
                    .font(.caption2)
                    .accessibilityHidden(true)

                Text(file.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Button(action: { onClose(file) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(file.name)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(UIColor.systemBackground) : Color.clear)
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tab: \(file.name)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Icon

    private func fileIcon(for file: FileItem) -> String {
        switch file.url.pathExtension.lowercased() {
        case "swift": return "🔷"
        case "md": return "📝"
        case "json": return "📋"
        case "py": return "🐍"
        case "js", "jsx": return "🟨"
        case "ts", "tsx": return "🟦"
        case "html": return "🌐"
        case "css": return "🎨"
        default: return "📄"
        }
    }
}

// MARK: - Previews

#Preview {
    FileTabBar(
        files: [
            FileItem(name: "AppMain.swift", url: URL(fileURLWithPath: "/a.swift")),
            FileItem(name: "Message.swift", url: URL(fileURLWithPath: "/b.swift")),
            FileItem(name: "README.md", url: URL(fileURLWithPath: "/c.md")),
        ],
        selectedFile: FileItem(name: "AppMain.swift", url: URL(fileURLWithPath: "/a.swift")),
        onSelect: { _ in },
        onClose: { _ in }
    )
}
