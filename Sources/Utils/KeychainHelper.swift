import Foundation
import Security

/// Secure storage utility using the iOS Keychain.
///
/// Provides static methods to save, load, and delete string values
/// in the system keychain. Used primarily for storing API keys and
/// other sensitive credentials that should not reside in `UserDefaults`.
enum KeychainHelper {

    // MARK: - Public Methods

    /// Saves a string value to the keychain under the given key.
    ///
    /// If a value already exists for the key, it is overwritten.
    ///
    /// - Parameters:
    ///   - key: The key to associate with the stored value.
    ///   - value: The string value to store.
    /// - Returns: `true` if the save operation succeeded.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            Logger.warning("Failed to encode value for keychain key: \(key)")
            return false
        }

        // Delete any existing item with the same key before adding.
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            Logger.error("Keychain save failed for key '\(key)': status \(status)")
            return false
        }

        Logger.debug("Keychain value saved for key: \(key)")
        return true
    }

    /// Loads a string value from the keychain for the given key.
    ///
    /// - Parameter key: The key whose associated value to retrieve.
    /// - Returns: The stored string value, or `nil` if no value
    ///   exists for the key.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                Logger.warning("Keychain load failed for key '\(key)': status \(status)")
            }
            return nil
        }

        Logger.debug("Keychain value loaded for key: \(key)")
        return value
    }

    /// Deletes a value from the keychain for the given key.
    ///
    /// - Parameter key: The key whose associated value to delete.
    /// - Returns: `true` if the value was deleted or did not exist.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.warning("Keychain delete failed for key '\(key)': status \(status)")
            return false
        }

        Logger.debug("Keychain value deleted for key: \(key)")
        return true
    }
}
