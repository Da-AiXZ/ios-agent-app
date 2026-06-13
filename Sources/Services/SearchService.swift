import Foundation

// MARK: - SearchServiceProtocol

/// Protocol for file search operations, enabling dependency injection
/// and test mocking.
protocol SearchServiceProtocol: AnyObject {

    /// Searches for files matching a glob pattern within a directory.
    ///
    /// - Parameters:
    ///   - pattern: The glob pattern (e.g., "*.swift", "**/*.md").
    ///   - directory: The directory to search within.
    /// - Returns: An array of matching file URLs.
    func searchFiles(pattern: String, in directory: URL) throws -> [URL]

    /// Searches file contents for a regular expression pattern.
    ///
    /// - Parameters:
    ///   - pattern: The regex pattern to search for.
    ///   - directory: The directory to search within.
    ///   - fileTypes: Optional array of file extensions to filter by.
    /// - Returns: An array of `SearchMatch` results.
    func searchContent(
        pattern: String,
        in directory: URL,
        fileTypes: [String]?
    ) throws -> [SearchMatch]
}

// MARK: - SearchMatch

/// A single match result from a content search.
struct SearchMatch: Codable, Identifiable {
    var id: String { "\(fileURL.path):\(lineNumber)" }

    /// The file containing the match.
    let fileURL: URL

    /// The line number of the match (1-based).
    let lineNumber: Int

    /// The matching line content.
    let line: String

    /// The range of the match within the line.
    let matchRange: Range<Int>?
}

// MARK: - SearchServiceError

enum SearchServiceError: LocalizedError {
    case invalidPattern(String)
    case directoryNotFound(URL)
    case searchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPattern(let pattern):
            return "Invalid search pattern: \(pattern)"
        case .directoryNotFound(let url):
            return "Directory not found: \(url.path)"
        case .searchFailed(let reason):
            return "Search failed: \(reason)"
        }
    }
}

// MARK: - SearchService

/// Service for searching files by name (glob) and content (regex).
///
/// Content search recursively traverses directories, filtering by
/// file extension, and matches lines using `NSRegularExpression`.
final class SearchService: SearchServiceProtocol {

    // MARK: - Properties

    private let fileManager: FileManager
    private let fsService: FileSystemService

    // MARK: - Initialization

    init(
        fileManager: FileManager = .default,
        fsService: FileSystemService = FileSystemService()
    ) {
        self.fileManager = fileManager
        self.fsService = fsService
    }

    // MARK: - SearchServiceProtocol

    func searchFiles(pattern: String, in directory: URL) throws -> [URL] {
        Logger.info("Glob search: '\(pattern)' in \(directory.lastPathComponent)")

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
            throw SearchServiceError.directoryNotFound(directory)
        }

        // Simple glob implementation supporting * and **.
        var results: [URL] = []

        if pattern.contains("**") {
            // Recursive search.
            results = globRecursive(pattern: pattern, baseDirectory: directory)
        } else {
            // Single-level search.
            let contents = (try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []

            for url in contents {
                let filename = url.lastPathComponent
                if matchesGlob(filename, pattern: pattern) {
                    results.append(url)
                }
            }
        }

        Logger.info("Glob found \(results.count) matches")
        return results
    }

    func searchContent(
        pattern: String,
        in directory: URL,
        fileTypes: [String]?
    ) throws -> [SearchMatch] {
        Logger.info("Grep search: '\(pattern)' in \(directory.lastPathComponent)")

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
            throw SearchServiceError.directoryNotFound(directory)
        }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            throw SearchServiceError.invalidPattern(pattern)
        }

        var results: [SearchMatch] = []
        searchContentRecursive(
            directory: directory,
            regex: regex,
            fileTypes: fileTypes,
            results: &results
        )

        Logger.info("Grep found \(results.count) matches")
        return results
    }

    // MARK: - Private

    /// Recursively searches file contents.
    private func searchContentRecursive(
        directory: URL,
        regex: NSRegularExpression,
        fileTypes: [String]?,
        results: inout [SearchMatch]
    ) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }

        for url in contents {
            let isDir = fsService.isDirectory(url)

            if isDir {
                // Skip hidden directories.
                if !url.lastPathComponent.hasPrefix(".") {
                    searchContentRecursive(
                        directory: url,
                        regex: regex,
                        fileTypes: fileTypes,
                        results: &results
                    )
                }
            } else {
                // Filter by file extension.
                if let fileTypes = fileTypes, !fileTypes.isEmpty {
                    let ext = url.pathExtension.lowercased()
                    if !fileTypes.contains(ext) {
                        continue
                    }
                }

                // Skip files that are too large.
                let size = fsService.fileSize(url)
                if size > AppConstants.maxDisplayableFileSize {
                    continue
                }

                // Skip binary files.
                guard AppConstants.textFileExtensions.contains(url.pathExtension.lowercased()) ||
                      size < 1024 else {
                    continue
                }

                // Read and search.
                guard let content = try? fsService.readFile(at: url) else {
                    continue
                }

                let lines = content.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    let range = NSRange(location: 0, length: line.utf16.count)
                    let matches = regex.matches(in: line, options: [], range: range)

                    if !matches.isEmpty {
                        for match in matches {
                            let swiftRange = Range(match.range, in: line).map {
                                line.distance(from: line.startIndex, to: $0.lowerBound) ..<
                                line.distance(from: line.startIndex, to: $0.upperBound)
                            }
                            results.append(SearchMatch(
                                fileURL: url,
                                lineNumber: index + 1,
                                line: line,
                                matchRange: swiftRange
                            ))
                        }
                    }
                }
            }
        }
    }

    /// Simple glob pattern matching.
    private func matchesGlob(_ string: String, pattern: String) -> Bool {
        // Handle ** pattern.
        if pattern == "**" || pattern == "*" {
            return true
        }

        // Handle extension matching: *.swift
        if pattern.hasPrefix("*.") {
            let ext = String(pattern.dropFirst(2))
            return string.hasSuffix(".\(ext)")
        }

        // Handle prefix matching: prefix*
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return string.hasPrefix(prefix)
        }

        // Handle suffix matching: *suffix
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return string.hasSuffix(suffix)
        }

        // Exact match.
        return string == pattern
    }

    /// Recursive glob matching for ** patterns.
    private func globRecursive(
        pattern: String,
        baseDirectory: URL
    ) -> [URL] {
        var results: [URL] = []

        // Extract the actual file pattern from **/pattern.
        let filePattern: String
        if let range = pattern.range(of: "**/") {
            filePattern = String(pattern[range.upperBound...])
        } else {
            filePattern = pattern
        }

        guard let enumerator = fileManager.enumerator(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return results
        }

        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if !isDir && matchesGlob(url.lastPathComponent, pattern: filePattern) {
                results.append(url)
            }
        }

        return results
    }
}
