import Foundation
import os

/// Unified logging utility for the iOS AI Programming Agent application.
///
/// Wraps Apple's `os.Logger` (OSLog) to provide structured logging
/// with subsystem and category support. All log messages are routed
/// through the system logging infrastructure, appearing in Console.app
/// and Xcode's debug console.
///
/// Usage:
/// ```swift
/// Logger.info("Agent started processing request")
/// Logger.error("Network request failed: \(error.localizedDescription)")
/// ```
enum Logger {

    // MARK: - Subsystem & Categories

    /// The unified logging subsystem identifier for the application.
    private static let subsystem: String = "com.ios-agent-app"

    // MARK: - Logger Instances

    /// General-purpose logger for application-level messages.
    private static let general = os.Logger(
        subsystem: subsystem,
        category: "general"
    )

    /// Logger for network-related messages (API calls, SSE streams).
    private static let network = os.Logger(
        subsystem: subsystem,
        category: "network"
    )

    /// Logger for agent execution messages (tool calls, reasoning).
    private static let agent = os.Logger(
        subsystem: subsystem,
        category: "agent"
    )

    /// Logger for file system operations (read, write, diff).
    private static let fileSystem = os.Logger(
        subsystem: subsystem,
        category: "filesystem"
    )

    /// Logger for UI-related events (navigation, state changes).
    private static let ui = os.Logger(
        subsystem: subsystem,
        category: "ui"
    )

    // MARK: - Public Logging Methods

    /// Logs an informational message to the general category.
    /// Use for high-level operational events.
    static func info(_ message: String) {
        general.info("\(message, privacy: .public)")
    }

    /// Logs a debug message to the general category.
    /// Use for detailed diagnostic information during development.
    static func debug(_ message: String) {
        general.debug("\(message, privacy: .public)")
    }

    /// Logs a warning message to the general category.
    /// Use for non-critical issues that should be reviewed.
    static func warning(_ message: String) {
        general.warning("\(message, privacy: .public)")
    }

    /// Logs an error message to the general category and sends
    /// a fault-level signal to the system logging infrastructure.
    /// Use for critical failures that require attention.
    static func error(_ message: String) {
        general.error("\(message, privacy: .public)")
    }

    // MARK: - Category-Specific Logging

    /// Logs a network-level informational event.
    static func networkInfo(_ message: String) {
        network.info("\(message, privacy: .public)")
    }

    /// Logs a network-level error.
    static func networkError(_ message: String) {
        network.error("\(message, privacy: .public)")
    }

    /// Logs an agent execution event.
    static func agentInfo(_ message: String) {
        agent.info("\(message, privacy: .public)")
    }

    /// Logs a file system operation event.
    static func fileSystemInfo(_ message: String) {
        fileSystem.info("\(message, privacy: .public)")
    }

    /// Logs a UI event.
    static func uiInfo(_ message: String) {
        ui.info("\(message, privacy: .public)")
    }
}
