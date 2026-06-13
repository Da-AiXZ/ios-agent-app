import Foundation

/// Represents a file or directory in the project file tree.
///
/// `FileItem` models the hierarchical structure of the filesystem,
/// supporting recursive directory children for tree rendering
/// in the file browser UI.
struct FileItem: Codable, Identifiable, Hashable {

    // MARK: - Properties

    /// Unique identifier for the file item.
    let id: UUID

    /// The display name of the file or directory (not the full path).
    var name: String

    /// The absolute file system URL of this item.
    var url: URL

    /// `true` if this item is a directory; `false` if it is a file.
    var isDirectory: Bool

    /// Child items for directories. `nil` for files and for
    /// directories that have not been expanded/loaded.
    var children: [FileItem]?

    /// The size of the file in bytes. For directories, this
    /// represents the aggregate size of all contained files.
    var fileSize: Int64

    /// The last modification date of the file or directory.
    /// `nil` if the date cannot be determined.
    var modificationDate: Date?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        isDirectory: Bool = false,
        children: [FileItem]? = nil,
        fileSize: Int64 = 0,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
        self.fileSize = fileSize
        self.modificationDate = modificationDate
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    /// Returns a human-readable file size string (e.g., "2.4 KB").
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
