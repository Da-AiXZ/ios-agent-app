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

    var errorDescription: String? {
        switch self {
        case .executionFailed(let cmd, let code, let stderr):
            return "Command '\(cmd)' failed with exit code \(code): \(stderr)"
        case .timeout(let cmd):
            return "Command '\(cmd)' timed out."
        case .invalidCommand:
            return "Invalid or empty command."
        }
    }
}

// MARK: - TerminalService

/// Executes shell commands using the system `Process` API.
///
/// Supports both batch execution (wait for complete result) and
/// streaming execution (real-time output via `AsyncStream`).
/// Includes timeout support and environment variable configuration.
final class TerminalService: TerminalServiceProtocol, TerminalProvider {

    // MARK: - Properties

    /// The currently running process, if any.
    private var currentProcess: Process?

    /// Lock for thread-safe process access.
    private let lock = NSLock()

    /// Default shell path.
    private let shellPath: String

    // MARK: - Initialization

    init(shellPath: String = "/bin/zsh") {
        self.shellPath = shellPath
    }

    // MARK: - TerminalServiceProtocol

    func execute(
        command: String,
        cwd: URL?,
        timeout: Int?,
        environment: [String: String]?
    ) async throws -> TerminalResult {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TerminalServiceError.invalidCommand
        }

        let startTime = Date()
        Logger.info("Executing command: \(command.prefix(80))...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-c", command]
        process.currentDirectoryURL = cwd

        if let env = environment {
            var processEnv = ProcessInfo.processInfo.environment
            for (key, value) in env {
                processEnv[key] = value
            }
            process.environment = processEnv
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        lock.lock()
        currentProcess = process
        lock.unlock()

        defer {
            lock.lock()
            currentProcess = nil
            lock.unlock()
        }

        do {
            try process.run()
        } catch {
            Logger.error("Failed to launch process: \(error.localizedDescription)")
            throw TerminalServiceError.executionFailed(
                command: command,
                exitCode: -1,
                stderr: error.localizedDescription
            )
        }

        // Apply timeout if specified.
        let timeoutSec = timeout ?? 120
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutSec) * 1_000_000_000)
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        let duration = Date().timeIntervalSince(startTime) * 1000

        Logger.info("Command completed in \(String(format: "%.0f", duration))ms (exit: \(process.terminationStatus))")

        return TerminalResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            durationMs: duration
        )
    }

    func executeStreaming(
        command: String,
        cwd: URL?
    ) -> AsyncThrowingStream<TerminalOutputChunk, Error> {
        AsyncThrowingStream<TerminalOutputChunk, Error> { continuation in
            guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continuation.finish(throwing: TerminalServiceError.invalidCommand)
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: shellPath)
            process.arguments = ["-c", command]
            process.currentDirectoryURL = cwd

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            lock.lock()
            currentProcess = process
            lock.unlock()

            // Set up async reading.
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let text = String(data: data, encoding: .utf8) {
                    continuation.yield(TerminalOutputChunk(type: .stdout, text: text))
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let text = String(data: data, encoding: .utf8) {
                    continuation.yield(TerminalOutputChunk(type: .stderr, text: text))
                }
            }

            process.terminationHandler = { [weak self] proc in
                // Close pipes.
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                // Read remaining data.
                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if let text = String(data: remainingStdout, encoding: .utf8), !text.isEmpty {
                    continuation.yield(TerminalOutputChunk(type: .stdout, text: text))
                }

                self?.lock.lock()
                self?.currentProcess = nil
                self?.lock.unlock()

                if proc.terminationStatus != 0 {
                    continuation.finish(
                        throwing: TerminalServiceError.executionFailed(
                            command: command,
                            exitCode: proc.terminationStatus,
                            stderr: ""
                        )
                    )
                } else {
                    continuation.finish()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func terminate() {
        lock.lock()
        defer { lock.unlock() }
        currentProcess?.terminate()
    }

    /// Whether a process is currently running.
    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentProcess?.isRunning ?? false
    }
}
