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
        "language_description": "English / 涓枃",
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
        "chat": "瀵硅瘽",
        "start_conversation": "寮€濮嬪璇?,
        "start_conversation_subtitle": "璁?AI 鍔╂墜甯綘缂栧啓銆佽皟璇曟垨鐞嗚В浠ｇ爜銆?,
        "generating": "鐢熸垚涓?..",
        "ask_anything": "杈撳叆浠讳綍鍐呭...",
        "retry": "閲嶈瘯",
        "new_conversation": "鏂板缓瀵硅瘽",
        "send_message": "鍙戦€佹秷鎭?,
        "stop_generation": "鍋滄鐢熸垚",
        "message_input": "娑堟伅杈撳叆",

        // History
        "history": "鍘嗗彶",
        "recent_conversations": "鏈€杩戝璇?,
        "no_conversations": "鏆傛棤瀵硅瘽",
        "no_conversations_subtitle": "浣犵殑瀵硅瘽鍘嗗彶灏嗘樉绀哄湪杩欓噷銆?,
        "messages_count": "%d 鏉℃秷鎭?,

        // Sidebar
        "select_item": "閫夋嫨涓€涓」鐩?,
        "select_item_subtitle": "浠庝晶杈规爮閫夋嫨浠ュ紑濮嬩娇鐢ㄣ€?,
        "project": "椤圭洰",
        "settings": "璁剧疆",
        "open_settings": "鎵撳紑璁剧疆",

        // Settings
        "appearance": "澶栬",
        "theme": "涓婚",
        "theme_description": "閫夋嫨娴呰壊銆佹繁鑹叉垨璺熼殢绯荤粺銆?,
        "language": "璇█",
        "language_description": "English / 涓枃",
        "api_configuration": "API 閰嶇疆",
        "provider": "渚涘簲鍟?,
        "provider_description": "API 鍚庣鏈嶅姟鍟嗐€?,
        "endpoint": "绔偣",
        "endpoint_description": "API 鍩虹 URL銆?,
        "api_key": "API 瀵嗛挜",
        "api_key_description": "瀹夊叏瀛樺偍鍦ㄩ挜鍖欎覆涓€?,
        "model": "妯″瀷",
        "model_description": "榛樿妯″瀷鏍囪瘑绗︺€?,
        "permissions": "鏉冮檺",
        "auto_approve_readonly": "鑷姩鎵瑰噯鍙鎿嶄綔",
        "auto_approve_readonly_description": "瀵瑰畨鍏ㄧ殑璇诲彇鎿嶄綔璺宠繃鏉冮檺鎻愮ず銆?,
        "trusted_paths": "淇′换璺緞",
        "trusted_paths_description": "杩欎簺鐩綍鍐呯殑鎿嶄綔灏嗚鑷姩鎵瑰噯銆?,
        "add_path": "娣诲姞璺緞",
        "remove_path": "绉婚櫎淇′换璺緞",
        "system": "绯荤粺",
        "system_prompt": "绯荤粺鎻愮ず璇?,
        "system_prompt_description": "璁惧畾 AI 鍔╂墜鐨勯粯璁よ涓轰笂涓嬫枃锛堟渶澶?2000 瀛楃锛夈€?,
        "save_changes": "淇濆瓨鏇存敼",
        "saved": "宸蹭繚瀛?,
        "reset_defaults": "鎭㈠榛樿",
        "done": "瀹屾垚",
        "close_settings": "鍏抽棴璁剧疆",
        "settings_saved": "璁剧疆宸蹭繚瀛?,

        // Agent
        "agent_generating": "AI 姝ｅ湪鐢熸垚鍥炲",
        "agent_error": "AI 鍑洪敊",
        "conversation": "瀵硅瘽",
        "streaming_response": "娴佸紡鍥炲",
        "code_editor": "浠ｇ爜缂栬緫鍣?,
    ]
}
