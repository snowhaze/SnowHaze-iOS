//
//  PasscodeManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let settingsServiceName = "ch.illotros.snowhaze.passcode.settings"

class PasscodeManager {
	private static let keyManager = KeyManager(qualifiedName: settingsServiceName)
	private static var instance: PasscodeManager? = nil
	static var shared: PasscodeManager! {
		if instance == nil {
			if Thread.isMainThread {
				instance = try? PasscodeManager()
			} else {
				DispatchQueue.main.sync {
					instance = try? PasscodeManager()
				}
			}
		}
		return instance
	}

	static let manualLockRequestNotification = Notification.Name(rawValue: "manualLockRequestNotification")

	private let lock = NSLock()

	private init() throws {
		(type, mode) = try PasscodeManager.loadTypeAndMode()
	}

	private static func loadTypeAndMode() throws -> (PasscodeController.PasscodeType, LockingMode) {
		let encoded: String? = try PasscodeManager.keyManager.keyIfExists()
		let fragments = (encoded ?? "").components(separatedBy: " ").compactMap { element -> (String, String)? in
			let components = element.components(separatedBy: "=")
			if components.count == 2 && !components[0].isEmpty && !components[1].isEmpty {
				return (components[0], components[1])
			} else {
				return nil
			}
		}
		var values = [String: String]()
		for (key, value) in fragments {
			values[key] = value
		}

		let mode: LockingMode
		if let modeString = values["mode"] {
			switch modeString {
				case "off":					mode = .off
				case "passcodeortouchid":	mode = .pinOrBiometrics // compatibility with v2.0 through v2.1
				case "passcodeonly":		mode = .pinOnly
				default:					mode = .off
			}
		} else {
			mode = .off
		}

		let type: PasscodeController.PasscodeType
		if let typeString = values["type"] {
			switch typeString {
				case "6digit":			type = .digit6
				case "longnumeric":		type = .longDigit
				case "alphanumeric":	type = .alphanumeric
				default:				type = .alphanumeric
			}
		} else {
			type = .alphanumeric
		}

		return (type, mode)
	}

	private func set(mode: LockingMode, type: PasscodeController.PasscodeType) {
		self.mode = mode
		self.type = type
		let modeString: String
		switch mode {
			case .off:				modeString = "off"
			case .pinOrBiometrics:	modeString = "passcodeortouchid" // compatibility with v2.0 through v2.1
			case .pinOnly:			modeString = "passcodeonly"
		}
		let typeString: String
		switch type {
			case .digit6:		typeString = "6digit"
			case .longDigit:	typeString = "longnumeric"
			case .alphanumeric:	typeString = "alphanumeric"
		}
		let encoded = "mode=\(modeString) type=\(typeString)"
		PasscodeManager.keyManager.set(key: encoded)
	}

	static let keychainID = "ch.illotros.snowhaze.app-passcode"

	private var closedDate: Date?
	private var manualLock = false

	func appIsClosing() {
		closedDate = closedDate ?? Date()
	}

	private(set) var type: PasscodeController.PasscodeType

	enum LockingMode {
		case off
		case pinOrBiometrics
		case pinOnly
	}

	private(set) var mode: LockingMode

	private func asyncRawSetAndUnlock(key: String, type: PasscodeController.PasscodeType, mode: LockingMode, completionHandler: ((Bool) -> Void)?) {
		DispatchQueue.global(qos: .userInteractive).async {
			db.withUniqueBackgroundConnection(qos: .userInteractive) { connection in
				do {
					try connection!.inTransaction {
						try rekey(connection: connection as! SQLCipher, key: key)
						self.set(mode: mode, type: type)
					}
					DispatchQueue.main.async {
						self.lock.unlock()
						completionHandler?(true)
					}
				} catch {
					DispatchQueue.main.async {
						self.lock.unlock()
						completionHandler?(false)
					}
				}
			}
		}
	}

	private func tryLock(completionHandler: ((Bool) -> Void)?) -> Bool {
		let result = lock.try()
		if let handler = completionHandler, !result {
			DispatchQueue.main.async {
				handler(false)
			}
		}
		return result
	}

	/// also sets mode to off
	func clearKey(completionHandler: ((Bool) -> Void)?) {
		guard tryLock(completionHandler: completionHandler) else {
			return
		}
		if case .pinOrBiometrics = mode {
			PasscodeController.clearCode(forKeychainID: PasscodeManager.keychainID) { success in
				if success {
					self.asyncRawSetAndUnlock(key: "", type: self.type, mode: .off, completionHandler: completionHandler)
				} else {
					self.lock.unlock()
					completionHandler?(false)
				}
			}
		} else {
			asyncRawSetAndUnlock(key: "", type: type, mode: .off, completionHandler: completionHandler)
		}
	}

	func clearBiometrics(completionHandler: ((Bool) -> Void)?) {
		guard tryLock(completionHandler: completionHandler) else {
			return
		}
		guard case .pinOrBiometrics = mode else {
			fatalError("Biometrics not actually set")
		}
		PasscodeController.clearCode(forKeychainID: PasscodeManager.keychainID) { success in
			if success {
				self.set(mode: .pinOnly, type: self.type)
			}
			completionHandler?(success)
			self.lock.unlock()
		}
	}

	private func isKey(_ key: String, ofType type: PasscodeController.PasscodeType) -> Bool {
		switch type {
			case .alphanumeric:
				return true
			case .digit6:
				if key.count != 6 {
					return false
				}
				fallthrough
			case .longDigit:
				return !key.contains { char in
					let digits: [Character] = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
					return !digits.contains(char)
				}
		}
	}

	func set(mode: LockingMode, withKey key: String, ofType type: PasscodeController.PasscodeType, completionHandler: ((Bool) -> Void)?) {
		assert(isKey(key, ofType: type))
		guard tryLock(completionHandler: completionHandler) else {
			return
		}
		if case .off = mode {
			fatalError("key cannot be set with locking mode off")
		}
		if case .pinOrBiometrics = mode {
			PasscodeController.set(code: key, forKeychainID: PasscodeManager.keychainID) { success in
				if success {
					self.asyncRawSetAndUnlock(key: key, type: type, mode: mode, completionHandler: completionHandler)
				} else {
					self.lock.unlock()
					completionHandler?(false)
				}
			}
		} else if case .pinOrBiometrics = self.mode {
			PasscodeController.clearCode(forKeychainID: PasscodeManager.keychainID) { success in
				if success {
					self.asyncRawSetAndUnlock(key: key, type: type, mode: mode, completionHandler: completionHandler)
				} else {
					self.lock.unlock()
					completionHandler?(false)
				}
			}
		} else {
			asyncRawSetAndUnlock(key: key, type: type, mode: mode, completionHandler: completionHandler)
		}
	}

	func set(mode: LockingMode, withKey key: String, completionHandler: ((Bool) -> Void)?) {
		set(mode: mode, withKey: key, ofType: type, completionHandler: completionHandler)
	}

	func set(key: String, ofType type: PasscodeController.PasscodeType, completionHandler: ((Bool) -> Void)?) {
		set(mode: mode, withKey: key, ofType: type, completionHandler: completionHandler)
	}

	func set(keyType type: PasscodeController.PasscodeType) {
		guard case .off = mode else {
			fatalError("key type can only be set directly if mode is of")
		}
		set(mode: .off, type: type)
	}

	var openingAppNeedsUnlock: Bool {
		if manualLock {
			return true
		}
		guard let date = closedDate else {
			return false
		}
		let closedTime = -date.timeIntervalSinceNow
		guard closedTime >= 0 else {
			return false
		}
		return PolicyManager.globalManager().lockAfter(duration: closedTime)
	}

	func appDidUnlock() {
		closedDate = nil
		manualLock = false
	}

	func performFullUnlock() {
		if PolicyManager.globalManager().deleteSiteLists {
			try? FileManager.default.removeItem(atPath: DomainList.dbLocation)
		}
	}

	func manualUILockEngaged() {
		if case .off = mode {
			// Ignore request
		} else {
			manualLock = true
			NotificationCenter.default.post(name: PasscodeManager.manualLockRequestNotification, object: self)
		}
	}

	func setupIfCorrect(code: String, completionHandler: ((Bool) -> Void)?) {
		trySetupKey(key: code, completionHandler: completionHandler)
	}

	func verify(code: String, withCompletionHandler completionHandler: @escaping (Bool) -> Void) {
		verifyDBKey(code, completionHandler: completionHandler)
	}
}
