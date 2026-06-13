import Foundation

// MARK: - ContentType

/// The type of content within a chat message sent to the API.
/// Supports text-only and multimodal (text + tool calls / tool results)
/// message bodies.
enum ContentType: Codable {
    /// Plain text content.
    case text(String)

    /// One or more tool calls requested by the assistant.
    case toolCall([ToolCallJSON])

    /// The result of a tool execution returned to the assistant.
    case toolResult(ToolResultJSON)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type, text, toolCalls, toolCallId, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_call":
            let calls = try container.decode([ToolCallJSON].self, forKey: .toolCalls)
            self = .toolCall(calls)
        case "tool_result":
            let result = try ToolResultJSON(from: decoder)
            self = .toolResult(result)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown ContentType: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolCall(let calls):
            try container.encode("tool_call", forKey: .type)
            try container.encode(calls, forKey: .toolCalls)
        case .toolResult(let result):
            try container.encode("tool_result", forKey: .type)
            try container.encode(result.toolCallId, forKey: .toolCallId)
            try container.encode(result.content, forKey: .content)
        }
    }
}

// MARK: - ToolCallJSON

/// A tool call as it appears in the API request/response JSON.
/// Separate from the domain `ToolCall` model to keep API and
/// domain layers decoupled.
struct ToolCallJSON: Codable {

    /// Unique identifier for this tool call.
    let id: String

    /// The function/tool being invoked.
    let function: FunctionCall

    /// The type of this API entity (always "function").
    let type: String
}

/// The function call details within a tool call JSON object.
struct FunctionCall: Codable {
    /// The name of the function to invoke.
    let name: String

    /// JSON-encoded string of function arguments.
    let arguments: String
}

// MARK: - ToolResultJSON

/// The content of a tool result message sent back to the API.
struct ToolResultJSON: Codable {

    /// The ID of the tool call this result corresponds to.
    let toolCallId: String

    /// The output content from the tool execution.
    let content: String

    /// Indicates whether the tool execution was an error.
    let isError: Bool

    // MARK: - Initialization

    init(toolCallId: String, content: String, isError: Bool = false) {
        self.toolCallId = toolCallId
        self.content = content
        self.isError = isError
    }
}

// MARK: - ToolDefinition

/// The definition of a tool available to the AI model,
/// formatted for the OpenAI/Anthropic tools API.
struct ToolDefinition: Codable {

    /// Always "function" for tool-use APIs.
    let type: String

    /// The function specification (name, description, parameters).
    let function: FunctionDefinition

    // MARK: - Initialization

    init(name: String, description: String, parameters: [String: Any]) {
        self.type = "function"
        self.function = FunctionDefinition(
            name: name,
            description: description,
            parameters: parameters
        )
    }
}

/// The function part of a tool definition.
struct FunctionDefinition: Codable {

    /// The function name (must match a registered tool).
    let name: String

    /// A human-readable description of what the function does.
    let description: String

    /// JSON Schema describing the function's parameters.
    /// Encoded as a [String: Any] dictionary that is serialized
    /// via JSONSerialization when constructing the request body.
    let parameters: [String: Any]

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case name, description, parameters
    }

    init(name: String, description: String, parameters: [String: Any]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        let rawData = try container.decode(Data.self, forKey: .parameters)
        if let dict = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
            parameters = dict
        } else {
            parameters = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        let rawData = try JSONSerialization.data(withJSONObject: parameters)
        try container.encode(rawData, forKey: .parameters)
    }
}

// MARK: - ChatMessage

/// A message in the format expected by the chat completion API.
struct ChatMessage: Codable {

    /// The role of the message sender.
    let role: String

    /// The content of the message. Can be a plain string or
    /// an array of content blocks (for multimodal/tool messages).
    let content: ContentType

    /// Optional name identifier for the message sender.
    var name: String?

    // MARK: - Initialization

    init(role: String, content: ContentType, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}

// MARK: - AgentRequest

/// A complete request to the chat completion API for agent execution.
struct AgentRequest: Codable {

    /// The model identifier to use for this request.
    let model: String

    /// The ordered list of messages in the conversation.
    let messages: [ChatMessage]

    /// Tool definitions available to the model. `nil` means no tools
    /// are provided for this request.
    let tools: [ToolDefinition]?

    /// Whether to stream the response via SSE.
    let stream: Bool

    /// Maximum number of tokens in the response.
    let maxTokens: Int

    /// Sampling temperature (0.0–2.0). Lower values are more deterministic.
    let temperature: Double

    /// System prompt that sets the assistant's behavior.
    /// Sent separately from `messages` for Anthropic API; injected
    /// as a system message for OpenAI-compatible APIs.
    var systemPrompt: String?

    /// Tool choice mode. "auto" lets the model decide, "none" disables
    /// tool calling, or a specific tool name can be forced.
    var toolChoice: String?

    // MARK: - Initialization

    init(
        model: String = AppConstants.defaultModelId,
        messages: [ChatMessage],
        tools: [ToolDefinition]? = nil,
        stream: Bool = true,
        maxTokens: Int = 8192,
        temperature: Double = 0.7,
        systemPrompt: String? = nil,
        toolChoice: String? = nil
    ) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.systemPrompt = systemPrompt
        self.toolChoice = toolChoice
    }

    // MARK: - URLRequest Construction

    /// Converts this request into a `URLRequest` configured for the
    /// specified API provider.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - baseURL: The base URL of the API endpoint.
    ///   - provider: The API provider type (anthropic or openai).
    /// - Returns: A configured `URLRequest`, or `nil` if construction fails.
    func toURLRequest(
        apiKey: String,
        baseURL: String,
        provider: APIProvider = .anthropic
    ) -> URLRequest? {
        let endpoint: String
        let modelField: String

        switch provider {
        case .anthropic:
            endpoint = "\(baseURL)/v1/messages"
            modelField = "model"
        case .openai:
            endpoint = "\(baseURL)/v1/chat/completions"
            modelField = "model"
        }

        guard let url = URL(string: endpoint) else {
            Logger.networkError("Invalid API endpoint URL: \(endpoint)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = AppConstants.sseTimeout

        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch provider {
        case .anthropic:
            request.setValue("\(apiKey)", forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .openai:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Body
        var bodyDict: [String: Any] = [
            modelField: model,
            "stream": stream,
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]

        // Encode messages
        let messagesJSON: [[String: Any]] = messages.map { msg in
            var msgDict: [String: Any] = ["role": msg.role]
            switch msg.content {
            case .text(let text):
                msgDict["content"] = text
            case .toolCall(let calls):
                msgDict["tool_calls"] = calls.map { call in
                    [
                        "id": call.id,
                        "type": call.type,
                        "function": [
                            "name": call.function.name,
                            "arguments": call.function.arguments,
                        ],
                    ]
                }
            case .toolResult(let result):
                msgDict["tool_call_id"] = result.toolCallId
                msgDict["content"] = result.content
            }
            if let name = msg.name {
                msgDict["name"] = name
            }
            return msgDict
        }
        bodyDict["messages"] = messagesJSON

        // System prompt
        if let systemPrompt = systemPrompt {
            switch provider {
            case .anthropic:
                bodyDict["system"] = systemPrompt
            case .openai:
                // For OpenAI, inject as a system-role message at the front.
                let systemMessage: [String: Any] = [
                    "role": "system",
                    "content": systemPrompt
                ]
                if var msgs = bodyDict["messages"] as? [[String: Any]] {
                    msgs.insert(systemMessage, at: 0)
                    bodyDict["messages"] = msgs
                }
            }
        }

        // Tools
        if let tools = tools {
            let toolsJSON: [[String: Any]] = tools.map { tool in
                [
                    "type": tool.type,
                    "function": [
                        "name": tool.function.name,
                        "description": tool.function.description,
                        "parameters": tool.function.parameters,
                    ],
                ]
            }
            bodyDict["tools"] = toolsJSON
        }

        // Tool choice
        if let toolChoice = toolChoice {
            bodyDict["tool_choice"] = toolChoice
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
        } catch {
            Logger.networkError("Failed to serialize request body: \(error.localizedDescription)")
            return nil
        }

        return request
    }
}

// MARK: - APIProvider

/// The supported AI API providers.
@frozen
enum APIProvider: String, Codable, CaseIterable {
    /// Anthropic Claude API.
    case anthropic

    /// OpenAI Chat Completions API.
    case openai
}
