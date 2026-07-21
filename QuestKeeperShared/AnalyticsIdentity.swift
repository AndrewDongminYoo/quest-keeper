import CryptoKit
import Foundation
import Security

nonisolated struct AnalyticsIdentity: Sendable {
    static let appGroupIdentifier = "group.kr.donminzzi.QuestKeeper"
    private static let service = "kr.donminzzi.QuestKeeper.analytics"
    private static let installationAccount = "installation-id"
    private static let saltAccount = "quest-salt"

    let installationID: UUID
    private let salt: Data

    init(installationID: UUID, salt: Data) {
        self.installationID = installationID
        self.salt = salt
    }

    static func shared() -> AnalyticsIdentity {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        let installationData = keychainData(account: installationAccount)
            ?? defaults?.data(forKey: installationAccount)
        let installationID = installationData
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap(UUID.init(uuidString:)) ?? UUID()
        let salt = keychainData(account: saltAccount)
            ?? defaults?.data(forKey: saltAccount) ?? randomData(count: 32)

        let idData = Data(installationID.uuidString.utf8)
        saveToKeychain(idData, account: installationAccount)
        saveToKeychain(salt, account: saltAccount)
        // The App Group mirror gives the widget extension the same anonymous identity even though
        // its default Keychain access group differs from the host app's.
        defaults?.set(idData, forKey: installationAccount)
        defaults?.set(salt, forKey: saltAccount)
        return AnalyticsIdentity(installationID: installationID, salt: salt)
    }

    func questKey(for id: UUID) -> String {
        let digest = SHA256.hash(data: salt + Data(id.uuidString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func keychainData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func saveToKeychain(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
