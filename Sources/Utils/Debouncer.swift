import Foundation

/// A debounce utility that delays the execution of a closure until
/// a specified time interval has passed since the last invocation.
///
/// Useful for throttling rapid-fire events such as search text input,
/// scroll position updates, or window resize callbacks.
///
/// Usage:
/// ```swift
/// let debouncer = Debouncer(delay: 0.3)
/// debouncer.call {
///     performSearch(query)
/// }
/// ```
final class Debouncer {

    // MARK: - Properties

    /// The delay interval in seconds before the action is executed
    /// after the last `call` invocation.
    private let delay: TimeInterval

    /// The pending work item. Canceled and replaced on each new
    /// `call` invocation before the delay elapses.
    private var workItem: DispatchWorkItem?

    /// The dispatch queue on which the debounced action executes.
    private let queue: DispatchQueue

    // MARK: - Initialization

    /// Creates a new debouncer with the specified delay.
    ///
    /// - Parameters:
    ///   - delay: The debounce interval in seconds.
    ///   - queue: The dispatch queue on which to execute the
    ///     debounced action. Defaults to the main queue.
    init(
        delay: TimeInterval,
        queue: DispatchQueue = .main
    ) {
        self.delay = delay
        self.queue = queue
    }

    // MARK: - Public Methods

    /// Schedules or reschedules the given action to execute after
    /// the debounce delay. If `call` is invoked again before the
    /// delay elapses, the previous action is canceled and the
    /// timer resets.
    ///
    /// - Parameter action: The closure to execute after the
    ///   debounce interval.
    func call(action: @escaping () -> Void) {
        // Cancel any previously scheduled work item.
        workItem?.cancel()

        // Create a new work item with the action.
        let item = DispatchWorkItem(block: action)
        workItem = item

        // Schedule the new work item after the delay.
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Immediately cancels any pending debounced action without
    /// executing it.
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
