import Foundation
import Security

public struct OneDriveTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

public protocol TokenVault: Sendable {
    func load() throws -> OneDriveTokens?
    func save(_ tokens: OneDriveTokens) throws
    func remove() throws
}

public struct KeychainTokenVault: TokenVault {
    private let account: String
    public init(clientID: String) { account = clientID }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "dev.musicloud.onedrive",
         kSecAttrAccount as String: account]
    }
    public func load() throws -> OneDriveTokens? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw VaultError(status) }
        return try JSONDecoder().decode(OneDriveTokens.self, from: data)
    }
    public func save(_ tokens: OneDriveTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw VaultError(status) }
    }
    public func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw VaultError(status) }
    }
}

private struct VaultError: LocalizedError {
    let status: OSStatus
    init(_ status: OSStatus) { self.status = status }
    var errorDescription: String? { "Keychain access failed (\(status))." }
}
