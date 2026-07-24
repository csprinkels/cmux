internal import Foundation
#if canImport(Security)
internal import Security
#endif

/// Data Protection Keychain storage for provider API keys.
///
/// Keys never touch defaults, config files, or logs — this is the only
/// persistence path. One account per provider identifier.
public struct AIProviderKeychain: Sendable {
    private let service: String

    /// Creates a store.
    ///
    /// - Parameter service: The Keychain service name; the default is shared
    ///   by all cmux AI provider keys.
    public init(service: String = "com.cmux.ai-provider-keys") {
        self.service = service
    }

    /// Reads the key for a provider.
    ///
    /// - Parameter provider: The provider identifier, e.g. `"anthropic"`.
    /// - Returns: The stored key, or `nil` when none is stored.
    public func apiKey(provider: String) -> String? {
#if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: provider,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
#else
        return nil
#endif
    }

    /// Writes (or replaces) the key for a provider; an empty key deletes.
    ///
    /// - Parameters:
    ///   - apiKey: The key to store, or empty to remove.
    ///   - provider: The provider identifier.
    /// - Returns: Whether the operation succeeded.
    @discardableResult
    public func setAPIKey(_ apiKey: String, provider: String) -> Bool {
        guard !apiKey.isEmpty else {
            return deleteAPIKey(provider: provider)
        }
#if canImport(Security)
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: provider,
            kSecUseDataProtectionKeychain: true,
        ]
        let secret = Data(apiKey.utf8)
        let updateStatus = SecItemUpdate(
            identity as CFDictionary,
            [kSecValueData: secret] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var insertion = identity
        insertion[kSecValueData] = secret
        insertion[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            return SecItemUpdate(
                identity as CFDictionary,
                [kSecValueData: secret] as CFDictionary
            ) == errSecSuccess
        }
        return addStatus == errSecSuccess
#else
        return false
#endif
    }

    /// Removes the key for a provider.
    ///
    /// - Parameter provider: The provider identifier.
    /// - Returns: Whether the key is absent after the call.
    @discardableResult
    public func deleteAPIKey(provider: String) -> Bool {
#if canImport(Security)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: provider,
            kSecUseDataProtectionKeychain: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
#else
        return false
#endif
    }
}
