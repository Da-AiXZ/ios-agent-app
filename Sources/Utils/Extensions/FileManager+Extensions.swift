import Foundation

// MARK: - FileManager Extensions

extension FileManager {

    /// Determines whether the given URL points to a directory.
    ///
    /// - Parameter url: The file URL to check.
    /// - Returns: `true` if the URL is a directory; `false` if it is
    ///   a regular file or the path does not exist.
    func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }

    /// Retrieves the size of the file at the given URL in bytes.
    ///
    /// For directories, this returns the size of the directory
    /// entry itself (not the aggregate size of contents). Use
    /// `directorySize(_:)` for recursive size calculation.
    ///
    /// - Parameter url: The file URL.
    /// - Returns: The file size in bytes, or `0` if the size
    ///   cannot be determined.
    func fileSize(_ url: URL) -> Int64 {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return 0
        }
        return size
    }

    /// Retrieves the last modification date of the file at the
    /// given URL.
    ///
    /// - Parameter url: The file URL.
    /// - Returns: The modification date, or `nil` if the date
    ///   cannot be determined (e.g., the file does not exist).
    func modificationDate(_ url: URL) -> Date? {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              let date = attributes[.modificationDate] as? Date else {
            return nil
        }
        return date
    }
}
