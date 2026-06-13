import Foundation

// MARK: - GitServiceProtocol

/// Protocol for Git operations, enabling dependency injection
/// and test mocking.
protocol GitServiceProtocol: AnyObject {

    /// Returns the working tree status.
    ///
    /// - Parameter repositoryURL: The URL of the git repository.
    /// - Returns: A formatted string of `git status` output.
    func status(at repositoryURL: URL) throws -> GitStatusResult

    /// Returns a unified diff of changes.
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the git repository.
    ///   - staged: If `true`, show staged changes only.
    ///   - file: Optional specific file to diff.
    /// - Returns: A `GitDiffResult` containing diff chunks.
    func diff(
        at repositoryURL: URL,
        staged: Bool,
        file: String?
    ) throws -> GitDiffResult

    /// Creates a commit with the given message.
    ///
    /// - Parameters:
    ///   - repositoryURL: The URL of the git repository.
    ///   - message: The commit message.
    ///   - files: Optional specific files to commit.
    /// - Returns: A `GitCommitResult` with the commit hash.
    func commit(
        at repositoryURL: URL,
        message: String,
        files: [String]?
    ) throws -> GitCommitResult

    /// Returns the list of branches.
    func branches(at repositoryURL: URL) throws -> [GitBranch]

    /// Returns the name of the current branch.
    func currentBranch(at repositoryURL: URL) throws -> String

    /// Returns recent commit log entries.
    func log(at repositoryURL: URL, count: Int) throws -> [GitLogEntry]
}

// MARK: - Git Result Types

/// Result of a git status operation.
struct GitStatusResult: Codable {
    /// The raw status output.
    let output: String

    /// Parsed list of changed files.
    let changedFiles: [GitChangedFile]
}

/// A file with changes in the working tree.
struct GitChangedFile: Codable, Identifiable {
    var id: String { path }
    let path: String
    let status: GitFileStatus
    let staged: Bool
}

@frozen
enum GitFileStatus: String, Codable, CaseIterable {
    case modified
    case added
    case deleted
    case renamed
    case untracked
    case conflicted
}

/// Result of a git diff operation.
struct GitDiffResult: Codable {
    let rawDiff: String
    let chunks: [DiffChunk]
}

/// Result of a git commit operation.
struct GitCommitResult: Codable {
    let hash: String
    let message: String
}

/// A git branch reference.
struct GitBranch: Codable, Identifiable {
    var id: String { name }
    let name: String
    let isCurrent: Bool
    let isRemote: Bool
}

/// A git log entry.
struct GitLogEntry: Codable, Identifiable {
    var id: String { hash }
    let hash: String
    let message: String
    let author: String
    let date: Date
}

// MARK: - GitServiceError

enum GitServiceError: LocalizedError {
    case notARepository(path: String)
    case gitNotFound
    case executionFailed(command: String, stderr: String)
    case timeout
    case notAvailableOnIOS

    var errorDescription: String? {
        switch self {
        case .notARepository(let path):
            return "Not a git repository: \(path)"
        case .gitNotFound:
            return "Git executable not found. Please install git."
        case .executionFailed(let cmd, let stderr):
            return "Git command failed: \(cmd)\n\(stderr)"
        case .timeout:
            return "Git operation timed out."
        case .notAvailableOnIOS:
            return "Git operations are not available on iOS."
        }
    }
}

// MARK: - GitService

/// Service for Git operations using the command-line `git` executable.
///
/// All operations are performed via `Process` calling `/usr/bin/git`.
/// Output is parsed into structured result types.
final class GitService: GitServiceProtocol {

    // MARK: - Properties

    /// Path to the git executable.
    private let gitPath: String

    // MARK: - Initialization

    init(gitPath: String = "/usr/bin/git") {
        self.gitPath = gitPath
    }

    // MARK: - GitServiceProtocol

    func status(at repositoryURL: URL) throws -> GitStatusResult {
        let output = try runGit(
            arguments: ["status", "--porcelain"],
            cwd: repositoryURL
        )

        var changedFiles: [GitChangedFile] = []
        for line in output.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            guard line.count >= 3 else { continue }

            let statusIndex = line.index(line.startIndex, offsetBy: 2)
            let stagedChar = line[line.startIndex]
            let unstagedChar = line[line.index(after: line.startIndex)]
            let filePath = String(line[statusIndex...]).trimmingCharacters(in: .whitespaces)

            let status: GitFileStatus = {
                switch (stagedChar, unstagedChar) {
                case ("M", _), (_, "M"): return .modified
                case ("A", _): return .added
                case ("D", _), (_, "D"): return .deleted
                case ("R", _): return .renamed
                case ("?", "?"): return .untracked
                case ("U", _), (_, "U"): return .conflicted
                default: return .modified
                }
            }()

            changedFiles.append(GitChangedFile(
                path: filePath,
                status: status,
                staged: stagedChar != " "
            ))
        }

        return GitStatusResult(output: output.stdout, changedFiles: changedFiles)
    }

    func diff(
        at repositoryURL: URL,
        staged: Bool,
        file: String?
    ) throws -> GitDiffResult {
        var arguments = ["diff", "--unified=5"]
        if staged {
            arguments.append("--staged")
        }
        if let file = file {
            arguments.append(file)
        }

        let output = try runGit(arguments: arguments, cwd: repositoryURL)
        let chunks = parseDiffChunks(output.stdout)
        return GitDiffResult(rawDiff: output.stdout, chunks: chunks)
    }

    func commit(
        at repositoryURL: URL,
        message: String,
        files: [String]?
    ) throws -> GitCommitResult {
        var arguments = ["commit", "-m", message]
        if let files = files {
            arguments.append(contentsOf: files)
        }

        let output = try runGit(arguments: arguments, cwd: repositoryURL)

        // Extract commit hash from output.
        var hash = ""
        for line in output.stdout.components(separatedBy: .newlines) {
            if line.hasPrefix("[") {
                if let hashRange = line.range(of: "([a-f0-9]{7,40})", options: .regularExpression) {
                    hash = String(line[hashRange]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                }
            }
        }

        return GitCommitResult(hash: hash, message: message)
    }

    func branches(at repositoryURL: URL) throws -> [GitBranch] {
        let output = try runGit(
            arguments: ["branch", "-a", "--format=%(refname:short)|%(HEAD)"],
            cwd: repositoryURL
        )

        var branches: [GitBranch] = []
        for line in output.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 1 else { continue }
            let name = parts[0]
            let isCurrent = parts.count > 1 && parts[1] == "*"
            let isRemote = name.hasPrefix("remotes/") || name.hasPrefix("origin/")

            branches.append(GitBranch(
                name: name,
                isCurrent: isCurrent,
                isRemote: isRemote
            ))
        }

        return branches
    }

    func currentBranch(at repositoryURL: URL) throws -> String {
        let output = try runGit(
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            cwd: repositoryURL
        )
        return output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func log(at repositoryURL: URL, count: Int) throws -> [GitLogEntry] {
        let output = try runGit(
            arguments: ["log", "-\(count)", "--format=%H|%s|%an|%aI"],
            cwd: repositoryURL
        )

        var entries: [GitLogEntry] = []
        let isoFormatter = ISO8601DateFormatter()

        for line in output.stdout.components(separatedBy: .newlines) where !line.isEmpty {
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }
            let date = isoFormatter.date(from: parts[3]) ?? Date()
            entries.append(GitLogEntry(
                hash: parts[0],
                message: parts[1],
                author: parts[2],
                date: date
            ))
        }

        return entries
    }

    // MARK: - Private

    /// Runs a git command and returns the result.
    private func runGit(
        arguments: [String],
        cwd: URL
    ) throws -> TerminalResult {
        throw GitServiceError.notAvailableOnIOS
    }

    /// Naive parsing of unified diff output into DiffChunk structures.
    private func parseDiffChunks(_ diffOutput: String) -> [DiffChunk] {
        var chunks: [DiffChunk] = []
        var currentType: DiffChunkType = .context
        var currentLines: [DiffLine] = []
        var currentOldLine: Int = 0
        var currentNewLine: Int = 0
        var chunkOldStart: Int = 0
        var chunkNewStart: Int = 0

        for line in diffOutput.components(separatedBy: .newlines) {
            if line.hasPrefix("@@") {
                // Flush previous chunk.
                if !currentLines.isEmpty {
                    chunks.append(DiffChunk(
                        type: currentType,
                        lines: currentLines,
                        oldStartLine: chunkOldStart,
                        newStartLine: chunkNewStart
                    ))
                }

                // Parse @@ -oldStart,oldCount +newStart,newCount @@.
                currentLines = []
                currentType = .context

                let parts = line.components(separatedBy: " ")
                for part in parts {
                    if part.hasPrefix("-") {
                        let nums = part.dropFirst().components(separatedBy: ",")
                        chunkOldStart = Int(nums[0]) ?? 0
                        currentOldLine = chunkOldStart
                    } else if part.hasPrefix("+") {
                        let nums = part.dropFirst().components(separatedBy: ",")
                        chunkNewStart = Int(nums[0]) ?? 0
                        currentNewLine = chunkNewStart
                    }
                }
                continue
            }

            if line.hasPrefix("---") || line.hasPrefix("+++") || line.hasPrefix("diff ") || line.hasPrefix("index ") {
                continue
            }

            if line.hasPrefix("+") {
                currentType = .add
                currentLines.append(DiffLine(
                    content: String(line.dropFirst()),
                    type: .added,
                    newLineNumber: currentNewLine
                ))
                currentNewLine += 1
            } else if line.hasPrefix("-") {
                currentType = .delete
                currentLines.append(DiffLine(
                    content: String(line.dropFirst()),
                    type: .removed,
                    oldLineNumber: currentOldLine
                ))
                currentOldLine += 1
            } else if line.hasPrefix(" ") || line.isEmpty {
                currentLines.append(DiffLine(
                    content: line.isEmpty ? "" : String(line.dropFirst()),
                    type: .unchanged,
                    oldLineNumber: currentOldLine,
                    newLineNumber: currentNewLine
                ))
                currentOldLine += 1
                currentNewLine += 1
            }
        }

        // Flush final chunk.
        if !currentLines.isEmpty {
            chunks.append(DiffChunk(
                type: currentType,
                lines: currentLines,
                oldStartLine: chunkOldStart,
                newStartLine: chunkNewStart
            ))
        }

        return chunks
    }

    /// Minimal TerminalResult for internal use.
    private struct TerminalResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        let durationMs: Double
    }
}
