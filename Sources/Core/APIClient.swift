import Foundation

// MARK: - APIClientProtocol

/// Protocol for the API client, enabling dependency injection
/// and test mocking.
protocol APIClientProtocol: AnyObject {

    /// Sends a streaming chat completion request and returns
    /// an `AsyncThrowingStream` of `SSEEvent` values.
    ///
    /// - Parameter request: The agent request to send.
    /// - Returns: An async stream yielding SSE events as they arrive.
    func sendStreamRequest(
        _ request: AgentRequest
    ) -> AsyncThrowingStream<SSEEvent, Error>

    /// Cancels all in-flight requests.
    func cancelAllRequests()
}

// MARK: - APIClientError

/// Errors that can occur during API communication.
enum APIClientError: LocalizedError {
    /// The URL could not be constructed from the given parameters.
    case invalidURL

    /// The API key was missing or empty.
    case missingAPIKey

    /// The server returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, body: String?)

    /// The connection timed out.
    case timeout

    /// The request was cancelled by the user.
    case cancelled

    /// The SSE parser encountered an error.
    case parseError(String)

    /// An unexpected error occurred.
    case unknown(Error)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .missingAPIKey:
            return "API key is missing. Please configure it in Settings."
        case .httpError(let statusCode, let body):
            let detail = body.map { ": \($0)" } ?? ""
            return "HTTP error \(statusCode)\(detail)"
        case .timeout:
            return "The request timed out. Please try again."
        case .cancelled:
            return "The request was cancelled."
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - APIClient

/// HTTP client for streaming chat completion API requests.
///
/// Uses `URLSession` with a custom delegate to receive raw bytes
/// incrementally, feeding them to an `SSEParser` for event extraction.
/// Supports both Anthropic and OpenAI-compatible API providers.
final class APIClient: NSObject, APIClientProtocol {

    // MARK: - Properties

    /// The API key used for authentication.
    private let apiKey: String

    /// The base URL of the API endpoint.
    private let baseURL: String

    /// The API provider type.
    private let provider: APIProvider

    /// The SSE parser instance.
    private let parser: SSEParser

    /// The URL session used for requests.
    private var session: URLSession?

    /// Active data tasks, keyed by a unique identifier for cancellation.
    private var activeTasks: [UUID: URLSessionDataTask] = [:]

    /// Lock for thread-safe task management.
    private let taskLock = NSLock()

    // MARK: - Initialization

    /// Creates a new API client.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - baseURL: The base URL of the API endpoint.
    ///   - provider: The API provider type (default: `.anthropic`).
    init(
        apiKey: String,
        baseURL: String = AppConstants.defaultAnthropicAPIEndpoint,
        provider: APIProvider = .anthropic
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.provider = provider
        self.parser = SSEParser()
        super.init()
    }

    // MARK: - APIClientProtocol

    func sendStreamRequest(
        _ request: AgentRequest
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream<SSEEvent, Error> { continuation in
            let taskId = UUID()

            guard let urlRequest = request.toURLRequest(
                apiKey: apiKey,
                baseURL: baseURL,
                provider: provider
            ) else {
                continuation.finish(throwing: APIClientError.invalidURL)
                return
            }

            Logger.networkInfo("Starting stream request to \(urlRequest.url?.absoluteString ?? "unknown")")

            let session = URLSession(
                configuration: .default,
                delegate: StreamDelegate(
                    parser: parser,
                    continuation: continuation,
                    taskId: taskId,
                    onComplete: { [weak self] taskId in
                        self?.removeTask(taskId)
                    }
                ),
                delegateQueue: nil
            )
            self.session = session

            let dataTask = session.dataTask(with: urlRequest)
            taskLock.lock()
            activeTasks[taskId] = dataTask
            taskLock.unlock()

            dataTask.resume()
        }
    }

    func cancelAllRequests() {
        taskLock.lock()
        let tasks = activeTasks
        activeTasks.removeAll()
        taskLock.unlock()

        for (_, task) in tasks {
            task.cancel()
        }
        session?.invalidateAndCancel()
        Logger.networkInfo("Cancelled all in-flight requests")
    }

    // MARK: - Private

    private func removeTask(_ taskId: UUID) {
        taskLock.lock()
        activeTasks.removeValue(forKey: taskId)
        taskLock.unlock()
    }
}

// MARK: - StreamDelegate

/// Internal URLSessionDataDelegate that receives raw bytes and
/// routes them to the SSE parser.
private final class StreamDelegate: NSObject, URLSessionDataDelegate {

    /// The SSE parser instance.
    private let parser: SSEParser

    /// The AsyncThrowingStream continuation.
    private let continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation

    /// The task identifier for tracking.
    private let taskId: UUID

    /// Callback invoked when the stream completes.
    private let onComplete: (UUID) -> Void

    /// Whether the continuation has been finished.
    private var isFinished: Bool = false

    // MARK: - Initialization

    init(
        parser: SSEParser,
        continuation: AsyncThrowingStream<SSEEvent, Error>.Continuation,
        taskId: UUID,
        onComplete: @escaping (UUID) -> Void
    ) {
        self.parser = parser
        self.continuation = continuation
        self.taskId = taskId
        self.onComplete = onComplete
        super.init()
        parser.parseStream(continuation: continuation)
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        parser.feedToStream(bytes: data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard !isFinished else { return }
        isFinished = true

        if let error = error {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                continuation.finish(throwing: APIClientError.cancelled)
            } else if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                continuation.finish(throwing: APIClientError.timeout)
            } else {
                continuation.finish(throwing: APIClientError.unknown(error))
            }
        } else {
            parser.finishStream()
            continuation.finish()
        }

        onComplete(taskId)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            Logger.networkInfo("Received HTTP \(httpResponse.statusCode)")

            if httpResponse.statusCode >= 400 {
                isFinished = true
                let body = "HTTP status \(httpResponse.statusCode)"
                continuation.finish(
                    throwing: APIClientError.httpError(
                        statusCode: httpResponse.statusCode,
                        body: body
                    )
                )
                onComplete(taskId)
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }
}
