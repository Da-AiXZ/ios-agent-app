import Foundation

// MARK: - FileSystemServiceProtocol

/// Protocol for file system operations, enabling dependency injection
/// and test mocking.
protocol FileSystemServiceProtocol: AnyObject {

    /// Reads the entire contents of a file as a UTF-8 string.
    ///
    /// - Parameter url: The file URL to read.
    /// - Returns: The file contents as a string.
    /// - Throws: `FileSystemError` if the file cannot be read.
    func readFile(at url: URL) throws -> String

    /// Writes a string to a file, creating it if it doesn't exist.
    ///
    /// - Parameters:
    ///   - content: The string content to write.
    ///   - url: The destination file URL.
    /// - Throws: `FileSystemError` if the write fails.
    func writeFile(content: String, at url: URL) throws

    /// Performs an exact string replacement within a file.
    ///
    /// - Parameters:
    ///   - url: The file URL to edit.
    ///   - oldString: The exact string to find and replace.
    ///   - newString: The replacement string.
    ///   - replaceAll: If `true`, replaces all occurrences.
    /// - Throws: `FileSystemError` if the operation fails.
    func editFile(
        at url: URL,
        oldString: String,
        newString: String,
        replaceAll: Bool
    ) throws

    /// Lists the contents of a directory.
    ///
    /// - Parameters:
    ///   - url: The directory URL to list.
    ///   - recursive: If `true`, recursively lists subdirectories.
    /// - Returns: An array of `FileItem` values.
    /// - Throws: `FileSystemError` if the directory cannot be read.
    func listDirectory(at url: URL, recursive: Bool) throws -> [FileItem]

    /// Deletes a file or empty directory at the given URL.
    ///
    /// - Parameter url: The URL to delete.
    /// - Throws: `FileSystemError` if the deletion fails.
    func deleteItem(at url: URL) throws

    /// Returns whether the given URL points to a directory.
    func isDirectory(_ url: URL) -> Bool

    /// Returns the size of the file at the given URL in bytes.
    func fileSize(_ url: URL) -> Int64

    /// Creates an intermediate directory, including parent directories.
    func createDirectory(at url: URL) throws
}

// MARK: - FileSystemError

/// Errors that can occur during file system operations.
enum FileSystemError: LocalizedError {
    case fileNotFound(path: String)
    case permissionDenied(path: String)
    case encodingError(path: String)
    case writeError(path: String, reason: String)
    case readError(path: String, reason: String)
    case notADirectory(path: String)
    case isADirectory(path: String)
    case directoryNotEmpty(path: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .encodingError(let path):
            return "Encoding error at: \(path)"
        case .writeError(let path, let reason):
            return "Failed to write \(path): \(reason)"
        case .readError(let path, let reason):
            return "Failed to read \(path): \(reason)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .isADirectory(let path):
            return "Is a directory: \(path)"
        case .directoryNotEmpty(let path):
            return "Directory not empty: \(path)"
        }
    }
}

// MARK: - FileSystemService

/// Service for file system operations within the project sandbox.
///
/// All paths are resolved relative to the project root directory.
/// The service uses `FileManager` for all operations and handles
/// UTF-8 encoding with fallback attempts for other encodings.
final class FileSystemService: FileSystemServiceProtocol {

    // MARK: - Properties

    /// The underlying file manager.
    private let fileManager: FileManager

    // MARK: - Initialization

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - FileSystemServiceProtocol

    func readFile(at url: URL) throws -> String {
        guard fileManager.fileExists(atPath: url.path) else {
            Logger.fileSystemInfo("File not found: \(url.path)")
            throw FileSystemError.fileNotFound(path: url.path)
        }

        // Try UTF-8 first.
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            Logger.fileSystemInfo("Read file: \(url.lastPathComponent) (\(content.count) chars)")
            return content
        }

        // Fallback: try to read as data and detect encoding.
        let data = try Data(contentsOf: url)

        // Try common encodings.
        let encodings: [String.Encoding] = [
            .utf8, .ascii, .isoLatin1, .windowsCP1252, .japaneseEUC,
        ]

        for encoding in encodings {
            if let content = String(data: data, encoding: encoding) {
                Logger.fileSystemInfo("Read file with fallback encoding: \(url.lastPathComponent)")
                return content
            }
        }

        Logger.error("Failed to decode file: \(url.path)")
        throw FileSystemError.encodingError(path: url.path)
    }

    func writeFile(content: String, at url: URL) throws {
        // Ensure parent directory exists.
        let parentDir = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        Logger.fileSystemInfo("Wrote file: \(url.lastPathComponent) (\(content.count) chars)")
    }

    func editFile(
        at url: URL,
        oldString: String,
        newString: String,
        replaceAll: Bool
    ) throws {
        let originalContent = try readFile(at: url)

        guard originalContent.contains(oldString) else {
            throw FileSystemError.writeError(
                path: url.path,
                reason: "The specified string was not found in the file."
            )
        }

        var newContent: String
        if replaceAll {
            newContent = originalContent.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = originalContent.range(of: oldString) else {
                throw FileSystemError.writeError(
                    path: url.path,
                    reason: "The specified string was not found in the file."
                )
            }
            newContent = originalContent.replacingCharacters(in: range, with: newString)
        }

        try writeFile(content: newContent, at: url)
        Logger.fileSystemInfo("Edited file: \(url.lastPathComponent)")
    }

    func listDirectory(at url: URL, recursive: Bool) throws -> [FileItem] {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound(path: url.path)
        }

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.notADirectory(path: url.path)
        }

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        var items: [FileItem] = []

        for itemURL in contents {
            let resourceValues = try itemURL.resourceValues(forKeys: [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            ])

            let isDir = resourceValues.isDirectory ?? false
            let size = Int64(resourceValues.fileSize ?? 0)
            let modDate = resourceValues.contentModificationDate

            var children: [FileItem]?
            if isDir && recursive {
                children = (try? listDirectory(at: itemURL, recursive: true)) ?? []
            }

            let fileItem = FileItem(
                name: itemURL.lastPathComponent,
                url: itemURL,
                isDirectory: isDir,
                children: children,
                fileSize: size,
                modificationDate: modDate
            )
            items.append(fileItem)
        }

        // Sort: directories first, then by name.
        items.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        Logger.fileSystemInfo("Listed \(items.count) items in \(url.lastPathComponent)")
        return items
    }

    func deleteItem(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileSystemError.fileNotFound(path: url.path)
        }

        try fileManager.removeItem(at: url)
        Logger.fileSystemInfo("Deleted: \(url.lastPathComponent)")
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }

    func fileSize(_ url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        Logger.fileSystemInfo("Created directory: \(url.lastPathComponent)")
    }
}
