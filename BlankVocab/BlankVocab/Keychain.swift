import Foundation
import Security

/// AI API 키를 기기 키체인에 저장해요.
enum Keychain {
    private static let service = "BlankVocab"

    /// Claude API 키 (sk-ant-...)
    static var apiKey: String? {
        get { read("anthropic-api-key") }
        set { write("anthropic-api-key", newValue) }
    }

    /// Gemini API 키 (AQ.... 또는 예전 형식 AIza...)
    static var geminiKey: String? {
        get { read("gemini-api-key") }
        set { write("gemini-api-key", newValue) }
    }

    private static func read(_ account: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private static func write(_ account: String, _ value: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(v.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
