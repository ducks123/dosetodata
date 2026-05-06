import Foundation
import Security
import Supabase
import Auth

/// Keychain-backed storage for the Supabase auth session.
///
/// Supabase persists the JWT + refresh token blob by writing one key
/// (`supabase.auth.token`). We forward each call straight to the iOS
/// keychain so the session survives app relaunches and is protected by
/// the device's secure enclave.
///
/// Accessibility is `afterFirstUnlock` so sync can happen opportunistically
/// in the background once the user has unlocked the device once post-boot.
struct KeychainLocalStorage: AuthLocalStorage {
    /// Service identifier used to scope our keychain items. Distinct from the
    /// bundle id so renaming the app wouldn't orphan existing sessions.
    private let service = "com.stewartsherpa.dosetodata.supabase.auth"

    func store(key: String, value: Data) throws {
        // Upsert: delete any existing item for this key, then add the new one.
        // Two-step because SecItemUpdate won't create a missing item.
        let baseQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData] = value
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status: status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status: status)
        }
    }

    func remove(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        // Missing items are fine — remove is idempotent from the caller's POV.
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    enum KeychainError: Error {
        case unhandled(status: OSStatus)
    }
}
