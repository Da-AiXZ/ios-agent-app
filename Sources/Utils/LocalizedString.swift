import Foundation

/// A lightweight localization system that returns UI strings in
/// English or Simplified Chinese based on `AppLanguage`.
///
/// Usage:
/// ```swift
/// Text(LocalizedString.get("start_conversation", lang: appState.language))
/// ```
enum LocalizedString {

    /// Returns the localized string for the given key.
    static func get(_ key: String, lang: AppLanguage) -> String {
        switch lang {
        case .english:
            return en[key] ?? zh[key] ?? key
        case .chinese:
            return zh[key] ?? en[key] ?? key
        }
    }

    // MARK: - English Dictionary

    static let en: [String: String] = [
        // Chat
        "chat": "Chat",
        "start_conversation": "Start a Conversation",
        "start_conversation_subtitle": "Ask the AI agent to help you write, debug, or understand code.",
        "generating": "Generating...",
        "ask_anything": "Ask anything...",
        "retry": "Retry",
        "new_conversation": "New conversation",
        "send_message": "Send message",
        "stop_generation": "Stop generation",
        "message_input": "Message input",

        // History
        "history": "History",
        "recent_conversations": "Recent Conversations",
        "no_conversations": "No Conversations",
        "no_conversations_subtitle": "Your chat history will appear here.",
        "messages_count": "%d messages",

        // Sidebar
        "select_item": "Select an Item",
        "select_item_subtitle": "Choose from the sidebar to get started.",
        "project": "Project",
        "settings": "Settings",
        "open_settings": "Open settings",

        // Settings
        "appearance": "Appearance",
        "theme": "Theme",
        "theme_description": "Choose light, dark, or follow system.",
        "language": "Language",
        "language_description": "English / 中文",
        "api_configuration": "API Configuration",
        "provider": "Provider",
        "provider_description": "API backend provider.",
        "endpoint": "Endpoint",
        "endpoint_description": "API base URL.",
        "api_key": "API Key",
        "api_key_description": "Stored securely in Keychain.",
        "model": "Model",
        "model_description": "Default model identifier.",
        "permissions": "Permissions",
        "auto_approve_readonly": "Auto-Approve Read-Only",
        "auto_approve_readonly_description": "Skip permission prompts for safe read operations.",
        "trusted_paths": "Trusted Paths",
        "trusted_paths_description": "Operations within these directories are auto-approved.",
        "add_path": "Add Path",
        "remove_path": "Remove trusted path",
        "system": "System",
        "system_prompt": "System Prompt",
        "system_prompt_description": "Sets the default behavior context for the AI agent (max 2000 characters).",
        "save_changes": "Save Changes",
        "saved": "Saved",
        "reset_defaults": "Reset to Defaults",
        "done": "Done",
        "close_settings": "Close settings",
        "settings_saved": "Settings saved successfully",

        // Agent
        "agent_generating": "Agent is generating a response",
        "agent_error": "Agent error",
        "conversation": "Conversation",
        "streaming_response": "Streaming response",
        "code_editor": "Code Editor",
    ]

    // MARK: - Chinese Dictionary

    static let zh: [String: String] = [
        // Chat
        "chat": "对话",
        "start_conversation": "开始对话",
        "start_conversation_subtitle": "让 AI 助手帮你编写、调试或理解代码。",
        "generating": "生成中...",
        "ask_anything": "输入任何内容...",
        "retry": "重试",
        "new_conversation": "新建对话",
        "send_message": "发送消息",
        "stop_generation": "停止生成",
        "message_input": "消息输入",

        // History
        "history": "历史",
        "recent_conversations": "最近对话",
        "no_conversations": "暂无对话",
        "no_conversations_subtitle": "你的对话历史将显示在这里。",
        "messages_count": "%d 条消息",

        // Sidebar
        "select_item": "选择一个项目",
        "select_item_subtitle": "从侧边栏选择以开始使用。",
        "project": "项目",
        "settings": "设置",
        "open_settings": "打开设置",

        // Settings
        "appearance": "外观",
        "theme": "主题",
        "theme_description": "选择浅色、深色或跟随系统。",
        "language": "语言",
        "language_description": "English / 中文",
        "api_configuration": "API 配置",
        "provider": "供应商",
        "provider_description": "API 后端服务商。",
        "endpoint": "端点",
        "endpoint_description": "API 基础 URL。",
        "api_key": "API 密钥",
        "api_key_description": "安全存储在钥匙串中。",
        "model": "模型",
        "model_description": "默认模型标识符。",
        "permissions": "权限",
        "auto_approve_readonly": "自动批准只读操作",
        "auto_approve_readonly_description": "对安全的读取操作跳过权限提示。",
        "trusted_paths": "信任路径",
        "trusted_paths_description": "这些目录内的操作将被自动批准。",
        "add_path": "添加路径",
        "remove_path": "移除信任路径",
        "system": "系统",
        "system_prompt": "系统提示词",
        "system_prompt_description": "设定 AI 助手的默认行为上下文（最多 2000 字符）。",
        "save_changes": "保存更改",
        "saved": "已保存",
        "reset_defaults": "恢复默认",
        "done": "完成",
        "close_settings": "关闭设置",
        "settings_saved": "设置已保存",

        // Agent
        "agent_generating": "AI 正在生成回复",
        "agent_error": "AI 出错",
        "conversation": "对话",
        "streaming_response": "流式回复",
        "code_editor": "代码编辑器",
    ]
}
