// KeychainHelper.swift
// HamStationKit — Log Submission Clients
//
// Simple Keychain wrapper for storing API credentials securely.

import Foundation
import Security

/// Errors specific to Keychain operations.
public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
}

/// A lightweight wrapper around the macOS Keychain for storing and retrieving
/// API keys and credentials used by log submission clients.
///
/// All methods are synchronous because the Security framework Keychain API is
/// synchronous. This enum is `Sendable` and safe to call from any context.
public enum KeychainHelper: Sendable {

    /// The Keychain service name used for all stored credentials.
    private static let serviceName = "com.hamstationpro.credentials"

    // MARK: - Save

    /// Saves a credential value to the Keychain.
    ///
    /// If a value already exists for the given key, it is updated.
    ///
    /// - Parameters:
    ///   - key: The unique key identifying this credential (e.g., "qrz-api-key").
    ///   - value: The credential value to store.
    /// - Throws: `KeychainError.saveFailed` if the Keychain operation fails.
    public static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete any existing item first to avoid errSecDuplicateItem
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load

    /// Loads a credential value from the Keychain.
    ///
    /// - Parameter key: The unique key identifying the credential.
    /// - Returns: The stored credential value, or `nil` if not found.
    public static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    // MARK: - Delete

    /// Deletes a credential from the Keychain.
    ///
    /// - Parameter key: The unique key identifying the credential to delete.
    /// - Throws: `KeychainError.deleteFailed` if the operation fails (not thrown
    ///   if the item was not found -- `errSecItemNotFound` is treated as success).
    public static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
