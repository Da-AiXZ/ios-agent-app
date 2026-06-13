import Foundation

// MARK: - TerminalServiceProtocol

/// Protocol for terminal command execution, enabling dependency injection
/// and test mocking.
protocol TerminalServiceProtocol: AnyObject {

    /// Executes a shell command and returns the result.
    ///
    /// - Parameters:
    ///   - command: The shell command to execute.
    ///   - cwd: The working directory for the command.
    ///   - timeout: Maximum execution time in seconds.
    ///   - environment: Additional environment variables.
    /// - Returns: A `TerminalResult` containing exit code, stdout, and stderr.
    func execute(
        command: String,
        cwd: URL?,
        timeout: Int?,
        environment: [String: String]?
    ) async throws -> TerminalResult

    /// Executes a shell command and streams output in real-time.
    ///
    /// - Parameters:
    ///   - command: The shell command to execute.
    ///   - cwd: The working directory.
    /// - Returns: An `AsyncStream` yielding output chunks as they arrive.
    func executeStreaming(
        command: String,
        cwd: URL?
    ) -> AsyncThrowingStream<TerminalOutputChunk, Error>

    /// Terminates the currently running process, if any.
    func terminate()
}

// MARK: - Terminal Provider Protocol

/// Abstraction for terminal backends, enabling future SSH support.
protocol TerminalProvider {
    func execute(
        command: String,
        cwd: URL?,
        timeout: Int?,
        environment: [String: String]?
    ) async throws -> TerminalResult
}

// MARK: - TerminalResult

/// The result of a terminal command execution.
struct TerminalResult: Codable {
    /// The process exit code (0 = success).
    let exitCode: Int32

    /// Standard output from the command.
    let stdout: String

    /// Standard error from the command.
    let stderr: String

    /// Execution duration in milliseconds.
    let durationMs: Double
}

// MARK: - TerminalOutputChunk

/// A chunk of output from a streaming terminal execution.
struct TerminalOutputChunk: Codable {
    /// The type of output (stdout or stderr).
    let type: OutputType

    /// The text content of this chunk.
    let text: String

    @frozen
    enum OutputType: String, Codable, CaseIterable {
        case stdout
        case stderr
    }
}

// MARK: - TerminalServiceError

enum TerminalServiceError: LocalizedError {
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    case timeout(command: String)
    case invalidCommand
    case notAvailableOnIOS

    var errorDescription: String? {
        switch self {
        case .executionFailed(let cmd, let code, let stderr):
            return "Command '\(cmd)' failed with exit code \(code): \(stderr)"
        case .timeout(let cmd):
            return "Command '\(cmd)' timed out."
        case .invalidCommand:
            return "Invalid or empty command."
        case .notAvailableOnIOS:
            return "Shell execution is not available on iOS."
        }
    }
}

// MARK: - TerminalService

/// Shell execution is not available on iOS. All methods throw.
final class TerminalService: TerminalServiceProtocol, TerminalProvider {

    func execute(
        command: String,
        cwd: URL?,
        timeout: Int?,
        environment: [String: String]?
    ) async throws -> TerminalResult {
        throw TerminalServiceError.notAvailableOnIOS
    }

    func executeStreaming(
        command: String,
        cwd: URL?
    ) -> AsyncThrowingStream<TerminalOutputChunk, Error> {
        AsyncThrowingStream<TerminalOutputChunk, Error> { continuation in
            continuation.finish(throwing: TerminalServiceError.notAvailableOnIOS)
        }
    }

    func terminate() {}

    var isRunning: Bool { false }
}
