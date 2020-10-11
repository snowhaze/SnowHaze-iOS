//
//  KeyManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let keyManagerNamePrefix = "ch.illotros.snowhaze.keymanager.service.name."

public class KeyManager {
	public enum Error: Swift.Error {
		case interactionNotAllowed
	}

	public let serviceName: String

	public convenience init(name: String) {
		self.init(qualifiedName: keyManagerNamePrefix + name)
	}

	public init(qualifiedName: String) {
		serviceName = qualifiedName
	}

	public func set(key: String?) {
		if let key = key {
			store(key: key)
		} else {
			deleteKey()
		}
	}

	public func hasKey() throws -> Bool {
		return try keyIfExists() != nil
	}

	public func key() throws -> String {
		if let key = try keyIfExists() {
			return key
		}
		let key = String.secureRandom()
		set(key: key)
		return key
	}

	private func store(key: String) {
		let valueData = key.data(using: .utf8)!
		let query = [kSecAttrService: serviceName, kSecClass: kSecClassGenericPassword] as NSDictionary
		let attributes = [kSecValueData: valueData] as NSDictionary
		let updateErr = SecItemUpdate(query, attributes)
		if updateErr == errSecItemNotFound {
			let attributes = [kSecAttrService: serviceName, kSecClass: kSecClassGenericPassword, kSecValueData: valueData, kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked] as NSDictionary
			let addErr = SecItemAdd(attributes, nil)
			if addErr != errSecSuccess {
				fatalError("unexpected keychain error while adding key: \(addErr)")
			}
		} else if updateErr != errSecSuccess {
			fatalError("unexpected keychain error while updating key: \(updateErr)")
		}
	}

	private func deleteKey() {
		let query = [kSecAttrService: serviceName, kSecClass: kSecClassGenericPassword, kSecReturnData: kCFBooleanTrue!] as NSDictionary
		let keychainErr = SecItemDelete(query)
		if keychainErr != errSecSuccess && keychainErr != errSecItemNotFound {
			fatalError("unexpected keychain error while deleting key: \(keychainErr)")
		}
	}

	public func keyIfExists() throws -> String? {
		let query = [kSecAttrService: serviceName, kSecClass: kSecClassGenericPassword, kSecReturnData: kCFBooleanTrue!] as NSDictionary
		var result: AnyObject?
		let keychainErr = SecItemCopyMatching(query, &result)
		if keychainErr == errSecSuccess {
			return String(data: result as! Data, encoding: .utf8)!
		} else if keychainErr == errSecItemNotFound {
			return nil
		} else if keychainErr == errSecInteractionNotAllowed {
			throw Error.interactionNotAllowed
		} else {
			fatalError("unexpected keychain error while loading key: \(keychainErr)")
		}
	}

	var persistentReference: Data? {
		let query = [kSecAttrService: serviceName, kSecClass: kSecClassGenericPassword, kSecReturnPersistentRef: kCFBooleanTrue!] as NSDictionary
		var result: AnyObject?
		guard SecItemCopyMatching(query, &result) == errSecSuccess else {
			return nil
		}
		return result as? Data
	}
}
