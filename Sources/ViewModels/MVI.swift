import Foundation
import Combine

// MARK: - ViewState

/// Protocol that every ViewModel's state type must conform to.
///
/// State represents the complete UI-relevant data snapshot at any
/// given moment. It must be `Equatable` so that SwiftUI can
/// efficiently determine when to re-render.
protocol ViewState: Equatable {}

// MARK: - ViewIntent

/// Protocol that every ViewModel's intent type must conform to.
///
/// Intents represent user actions or system events that the
/// ViewModel should process. They are typically implemented
/// as an enum with associated values for payloads.
protocol ViewIntent {}

// MARK: - ViewEffect

/// Protocol that every ViewModel's effect type must conform to.
///
/// Effects represent one-time events that the View layer should
/// react to (e.g., showing a toast, navigating to a screen,
/// scrolling to a position). They must be `Equatable` so
/// duplicates can be filtered.
protocol ViewEffect: Equatable {}

// MARK: - MVIViewModel

/// Protocol for all ViewModels following the MVI (Model-View-Intent)
/// architecture pattern.
///
/// Each ViewModel exposes:
/// - A **State** that the View observes for rendering.
/// - An **Effects** publisher for one-time side effects.
/// - A **dispatch** method to process intents from the View.
///
/// ViewModels are always `@MainActor` to ensure UI updates
/// happen on the main thread.
protocol MVIViewModel: AnyObject, ObservableObject {

    /// The ViewModel's state type.
    associatedtype State: ViewState

    /// The ViewModel's intent type.
    associatedtype Intent: ViewIntent

    /// The ViewModel's effect type.
    associatedtype Effect: ViewEffect

    /// The current UI state snapshot.
    var state: State { get }

    /// A publisher that emits one-time effects for the View to handle.
    var effects: AnyPublisher<Effect, Never> { get }

    /// Dispatches a user or system intent to the ViewModel for processing.
    ///
    /// - Parameter intent: The intent to process.
    func dispatch(_ intent: Intent)
}
