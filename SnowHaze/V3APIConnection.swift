//
//  V3APIConnection.swift
//  SnowHaze
//
//
//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation
import Sodium
import Clibsodium

private extension String {
	var pwNormalized: String {
		return self.precomposedStringWithCompatibilityMapping
	}

	private var emailNormalized: String {
		return self.precomposedStringWithCompatibilityMapping.lowercased()
	}

	var emailSecretHash: Bytes {
		let sodium = Sodium()
		let salt = Bytes(Data(hex: "aceeb5863852f3b1a8af03945c92ef30")!)
		return sodium.pwHash.hash(outputLength: sodium.keyDerivation.KeyBytes, passwd: emailNormalized.bytes, salt: salt, opsLimit: sodium.pwHash.OpsLimitInteractive, memLimit: sodium.pwHash.MemLimitModerate)!
	}
}

private extension UInt16 {
	var high: UInt8 { return UInt8(self >> 8) }
	var low: UInt8 { return UInt8(self & 0xFF) }
}

private extension Array where Element == UInt8 {
	var crc16ccitt: UInt16 {
		let table: [UInt16] = [
			0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7,
			0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF,
			0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6,
			0x9339, 0x8318, 0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE,
			0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4, 0x5485,
			0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D,
			0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4,
			0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC,
			0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
			0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B,
			0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12,
			0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A,
			0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,
			0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49,
			0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13, 0x2E32, 0x1E51, 0x0E70,
			0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78,
			0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F,
			0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,
			0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E,
			0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,
			0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D,
			0x34E2, 0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
			0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E, 0xC71D, 0xD73C,
			0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634,
			0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB,
			0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,
			0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,
			0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92,
			0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9,
			0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1,
			0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,
			0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0,
		]
		assert(table.count == 256)
		var crc: UInt16 = 0xFFFF
		for byte in self {
			crc = table[Int(crc.high ^ byte)] ^ (crc << 8)
		}
		return crc
	}
}

public enum V3APIConnection {
	enum Error: Swift.Error {
		case network
		case missingMasterSecret
		case emailInUse
		case noSuchAccount
		case accountNotAuthorized
		case invalidReceipt
		case clearMasterSecret
		case invalidMasterSecret
		case exessiveUsage
	}

	static let masterSecretChangedNotification = Notification.Name("v3apiMasterSecretChangedNotificationName")

	private static let urlSession = SnowHazeURLSession()

	typealias Timestamp = UInt64

	private static let sodium = Sodium()

	private static let masterSecretID = "ch.illotros.snowhaze.zka.mastersecret"
	private static let receiptUploadedID = "ch.illotros.snowhaze.zka.appstore.receipt.uploaded"

	static func validateCRCedMasterSecret(_ crced: Bytes) -> Bool {
		guard crced.count == sodium.box.SecretKeyBytes + 3 && crced[0] == 1 else {
			return false
		}
		return crced.crc16ccitt == 0
	}

	static var hasSecret: Bool {
		return masterSecret != nil
	}

	static func set(masterSecret new: Bytes) {
		assert(new.count == sodium.box.SecretKeyBytes)
		SubscriptionManager.shared.clearSubscriptionInfoTokens()
		masterSecret = new
		NotificationCenter.default.post(name: masterSecretChangedNotification, object: nil)
	}

	static func clearMasterSecret() {
		masterSecret = nil
		SubscriptionManager.shared.clearSubscriptionInfoTokens()
		invalidateReceipt()
		NotificationCenter.default.post(name: masterSecretChangedNotification, object: nil)
	}

	private static var masterSecret: Bytes? {
		get {
			if let secret = DataStore.shared.getData(for: masterSecretID) {
				return Bytes(secret)
			} else {
				return nil
			}
		}
		set {
			if let secret = newValue {
				DataStore.shared.set(Data(secret), for: masterSecretID)
			} else {
				DataStore.shared.delete(masterSecretID)
			}
		}
	}

	static func invalidateReceipt() {
		receiptUploaded = false
	}

	private static func keys(from masterSecret: Bytes?) -> (keys: Box.KeyPair, pseudonym: Bytes)? {
		guard let secret = masterSecret else {
			return nil
		}
		guard let seed = sodium.keyDerivation.derive(secretKey: secret, index: 0, length: sodium.box.SeedBytes, context: "ms->skey") else {
			return nil
		}
		guard let keys = sodium.box.keyPair(seed: seed) else {
			return nil
		}
		guard let pseudonym = sodium.keyDerivation.derive(secretKey: secret, index: 0, length: 32, context: "ms->psdm") else {
			return nil
		}
		return (keys, [1] + pseudonym)
	}

	private(set) static var receiptUploaded: Bool = DataStore.shared.getBool(for: receiptUploadedID) ?? false {
		didSet {
			DataStore.shared.set(receiptUploaded, for: receiptUploadedID)
		}
	}

	static private var keys: Box.KeyPair? {
		return keys(from: masterSecret)?.keys
	}

	static private var receiptKey: Bytes? {
		guard let secret = masterSecret else {
			return nil
		}
		return sodium.keyDerivation.derive(secretKey: secret, index: 0, length: sodium.aead.xchacha20poly1305ietf.KeyBytes, context: "ms->rctk")!
	}

	static var crcedMasterSecretHex: String? {
		guard let secret = masterSecret else {
			return nil
		}
		let msg = [1] + secret
		let crc = msg.crc16ccitt
		return Data(msg + [crc.high, crc.low]).hex
	}

	static func register(secret: Bytes? = nil, callback: @escaping (Error?) -> ()) {
		guard secret == nil || validateCRCedMasterSecret(secret!) else {
			callback(.invalidMasterSecret)
			return
		}
		let rawSecret: Bytes
		if let secret = secret {
			rawSecret = Bytes(secret[1 ..< secret.count - 2])
		} else {
			rawSecret = sodium.randomBytes.buf(length: sodium.box.SecretKeyBytes)!
		}
		getData(command: "register", masterSecret: rawSecret) { statusCode, _ in
			if [201, 409].contains(statusCode) {
				set(masterSecret: rawSecret)
				callback(nil)
			} else if statusCode == 429 {
				callback(.exessiveUsage)
			} else {
				callback(.network)
			}
		}
	}

	private static func masterSecretUploadKeys(for secret: Bytes, password: String) -> (id: Data, key: Bytes) {
		let pwKeyDerivContext = "keyderiv"
		let pwData = password.pwNormalized.bytes
		let salt = sodium.keyDerivation.derive(secretKey: secret, index: 0, length: sodium.pwHash.SaltBytes, context: "kshorten")!
		let hashedPW = sodium.pwHash.hash(outputLength: sodium.keyDerivation.KeyBytes, passwd: pwData, salt: salt, opsLimit: sodium.pwHash.OpsLimitInteractive, memLimit: sodium.pwHash.MemLimitModerate)!
		let encryptionKey = sodium.keyDerivation.derive(secretKey: hashedPW, index: 0, length: sodium.aead.xchacha20poly1305ietf.KeyBytes, context: pwKeyDerivContext)!
		let validationHash = Data([1] + sodium.keyDerivation.derive(secretKey: hashedPW, index: 1, length: 32, context: pwKeyDerivContext)!)
		return (validationHash, encryptionKey)
	}

	private static func publicHashBase64(from secret: Bytes) -> String {
		let deriv = sodium.keyDerivation.derive(secretKey: secret, index: 0, length: 32, context: "hidemail")!
		return ([1] + Data(deriv)).base64EncodedString()
	}

	enum Language: String {
		case english = "en"
		case german = "de"
		case french = "fr"
	}
	static func addLogin(user: String, password: String, sendCleartextEmail: Bool, language: Language, callback: @escaping (Error?) -> ()) {
		guard let secret = masterSecret else {
			callback(.missingMasterSecret)
			return
		}
		let emailSecret = user.emailSecretHash
		let key = masterSecretUploadKeys(for: emailSecret, password: password)
		let encryptedMS = Data([1] + sodium.aead.xchacha20poly1305ietf.encrypt(message: secret, secretKey: key.key, additionalData: [1])!)
		var parameters = [
			"email_hash": publicHashBase64(from: emailSecret),
			"password_key": key.id.base64EncodedString(),
			"master_secret": encryptedMS.base64EncodedString(),
		]

		let rawConfig: [String: Any] = [
			"email": user,
			"lang": language.rawValue,
			"version": 1,
		]

		let config = try! JSONSerialization.data(withJSONObject: rawConfig)

		if sendCleartextEmail {
			parameters["config"] = String(data: config, encoding: .utf8)!
		} else {
			let configKey = sodium.keyDerivation.derive(secretKey: emailSecret, index: 0, length: sodium.aead.xchacha20poly1305ietf.KeyBytes, context: "confenck")!
			let encrypted: Bytes = sodium.aead.xchacha20poly1305ietf.encrypt(message: user.bytes, secretKey: configKey, additionalData: [1])!
			parameters["encrypted_config"] = Data([1] + encrypted).base64EncodedString()
		}

		getData(for: parameters, command: "set_credentials") { statusCode, _ in
			if statusCode == 200 {
				callback(nil)
			} else if statusCode == 409 {
				callback(.emailInUse)
			} else if statusCode == 403 {
				callback(.clearMasterSecret)
			} else if statusCode == 429 {
				callback(.exessiveUsage)
			} else {
				callback(.network)
			}
		}
	}

	static func getMasterSecret(user: String, password: String, callback: @escaping (Bytes?, Error?) -> ()) {
		let emailSecret = user.emailSecretHash
		let key = masterSecretUploadKeys(for: emailSecret, password: password)
		let parameters = ["email_hash": publicHashBase64(from: emailSecret), "password_key": key.id.base64EncodedString()]
		getData(for: parameters, command: "get_master_secret", addKey: false) { statusCode, response in
			guard statusCode == 200, let base64 = response["master_secret"] as? String, let ciphertext = Data(base64Encoded: base64) else {
				if statusCode == 404 {
					callback(nil, .noSuchAccount)
				} else if statusCode == 429 {
					callback(nil, .exessiveUsage)
				} else {
					callback(nil, .network)
				}
				return
			}
			guard ciphertext.count > 1, ciphertext[0] == 1 else {
				callback(nil, .network)
				return
			}
			let encryptedSecret = Bytes(ciphertext[1 ..< ciphertext.count])
			guard let secret = sodium.aead.xchacha20poly1305ietf.decrypt(nonceAndAuthenticatedCipherText: encryptedSecret, secretKey: key.key, additionalData: [1]) else {
				callback(nil, .network)
				return
			}
			guard secret.count == sodium.box.SecretKeyBytes else {
				callback(nil, .network)
				return
			}
			callback(secret, nil)
		}
	}

	static func getTokens(callback: @escaping ((tokens: [String], expiration: Timestamp, verificationBlob: Data)?, Error?) -> ()) {
		guard let keys = self.keys else {
			callback(nil, .missingMasterSecret)
			return
		}
		getData(command: "tokens") { statusCode, response in
			guard statusCode == 200 else {
				if statusCode == 402 {
					callback(nil, .accountNotAuthorized)
				} else if statusCode == 403 {
					callback(nil, .clearMasterSecret)
				} else if statusCode == 429 {
					callback(nil, .exessiveUsage)
				} else {
					callback(nil, .network)
				}
				return
			}
			guard let separator = response["separator"] as? String, let expiration = response["expiration"] as? Timestamp else {
				callback(nil, .network)
				return
			}
			guard let base64 = response["tokens"] as? String, let ciphertext = Data(base64Encoded: base64), ciphertext.count > sodium.sign.Bytes else {
				callback(nil, .network)
				return
			}
			let bytes = Bytes(ciphertext[sodium.sign.Bytes...])
			guard let plaintext = sodium.box.open(anonymousCipherText: bytes, recipientPublicKey: keys.publicKey, recipientSecretKey: keys.secretKey) else {
				callback(nil, .network)
				return
			}
			guard let string = plaintext.utf8String else {
				callback(nil, .network)
				return
			}

			let tokens = string.components(separatedBy: separator)
			if tokens.contains(where: { $0.isEmpty }) {
				callback(nil, .network)
			} else {
				callback((tokens, expiration, Data([1] + Bytes(ciphertext))), nil)
			}
		}
	}

	static func withUploadedReceipt(callback: @escaping (Error?) -> ()) {
		guard !receiptUploaded else {
			callback(nil)
			return
		}
		registerSubscription { error in
			guard let error = error else {
				callback(nil)
				return
			}
			if case .invalidReceipt = error {
				callback(nil)
			} else {
				callback(error)
			}
		}
	}

	static func registerSubscription(callback: @escaping (Error?) -> ()) {
		guard let url = Bundle.main.appStoreReceiptURL else {
			invalidateReceipt()
			callback(.invalidReceipt)
			return
		}
		guard let receipt = try? Data(contentsOf: url) else {
			invalidateReceipt()
			callback(.invalidReceipt)
			return
		}
		guard let key = receiptKey else {
			callback(.missingMasterSecret)
			return
		}
		getData(for: ["type": "applestore", "receipt": receipt.base64EncodedString(), "paytype": "set_receipt", "receipt_key": Data(key).base64EncodedString()], command: "payment") { statusCode, _ in
			if [200, 202].contains(statusCode) {
				receiptUploaded = true
				callback(nil)
			} else if statusCode == 402 {
				callback(.invalidReceipt)
			} else if statusCode == 403 {
				callback(.clearMasterSecret)
			} else if statusCode == 429 {
				callback(.exessiveUsage)
			} else {
				callback(.network)
			}
		}
	}

	// returns the date at which the next subscription will renew or (if none renews) the date at which the last will expire
	static func getSubscriptionDuration(callback: @escaping ((expiration: Date, renews: Bool)?, Error?) -> ()) {
		getPayments { payments, error in
			if let error = error {
				callback(nil, error)
				return
			}
			var timestamp: UInt64? = nil
			var duration = UInt64()
			var renewTs: UInt64? = nil
			var renewDuration: UInt64? = nil
			for payment in payments! {
				switch payment.status {
					case .active(let ts):		timestamp = max(timestamp ?? ts, ts)
					case .suspended(let time):	duration += time
				}
				if payment.renews {
					switch payment.status {
						case .active(let ts):		renewTs = max(renewTs ?? ts, ts)
						case .suspended(let time):	renewDuration = (renewDuration ?? 0) + time
					}
				}
			}
			if let ts = renewTs {
				callback((Date(timeIntervalSince1970: Double(ts)), true), nil)
			} else if let ts = timestamp {
				callback((Date(timeIntervalSince1970: Double(ts + (renewDuration ?? duration))), renewDuration != nil), nil)
			} else {
				callback(nil, renewDuration == nil ? nil : .network)
			}
		}
	}

	private enum PaymentStatus {
		case active(Timestamp)
		case suspended(UInt64)
	}
	private static func getPayments(callback: @escaping ([(type: [String: String], status: PaymentStatus, renews: Bool)]?, Error?) -> ()) {
		getData(command: "get_payment_info") { statusCode, response in
			guard statusCode == 200 else {
				if statusCode == 403 {
					callback(nil, .clearMasterSecret)
				} else if statusCode == 429 {
					callback(nil, .exessiveUsage)
				} else {
					callback(nil, .network)
				}
				return
			}
			guard let subscriptions = response["subscriptions"] as? [[String: Any]] else {
				callback(nil, .network)
				return
			}
			var result = [(type: [String: String], status: PaymentStatus, renews: Bool)]()
			for subscription in subscriptions {
				guard subscription["status"] as? String == "success" else {
					continue
				}
				guard let type = subscription["type"] as? [String: String] else {
					callback(nil, .network)
					return
				}
				guard let active = subscription["active"] as? Bool else {
					callback(nil, .network)
					return
				}
				let key = "paid_" + (active ? "until" : "for")
				guard let timingData = subscription[key] as? UInt64 else {
					callback(nil, .network)
					return
				}
				guard let renews = subscription["recurring"] as? Bool else {
					callback(nil, .network)
					return
				}
				let timing = active ? PaymentStatus.active(timingData) : .suspended(timingData)
				result.append((type: type, status: timing, renews: renews))
			}
			callback(result, nil)
		}
	}

	private static func proofOfOwnership(callback: @escaping ((Data, String)?) -> ()) {
		getData(command: "get_server_token", addKey: false) { statusCode, response in
			guard statusCode == 200, let keyBase64 = response["server_key"] as? String, let token = response["server_token"] as? String else {
				callback(nil)
				return
			}
			guard let key = Data(base64Encoded: keyBase64), key.count == sodium.box.PublicKeyBytes else {
				callback(nil)
				return
			}
			callback((key, token))
		}
	}

	private static func uploadReceiptKey(try tryCount: Int, callback: @escaping (Bool) -> ()) {
		guard let key = receiptKey else {
			callback(false)
			return
		}
		getData(for: ["receipt_key": Data(key).base64EncodedString(), "type": "applestore", "paytype": "revalidate_receipt"], command: "payment", try: tryCount) { status, response in
			DispatchQueue.main.async { callback([200, 202].contains(status)) }
		}
	}

	private static func getData(for originalParameters: [String: String] = [:], command: String, addKey: Bool = true, masterSecret: Bytes? = nil, try tryCount: Int = 3, callback: @escaping (Int, [String: Any]) -> ()) {
		var parameters = originalParameters
		parameters["action"] = command
		let run: ([String: String]) -> () = { parameters in
			var request = URLRequest(url: URL(string: "https://api.snowhaze.com/index.php")!)
			var parameters = parameters
			parameters["v"] = "3"
			request.setFormEncoded(data: parameters)
			let dec = InUseCounter.network.inc()
			urlSession.performDataTask(with: request) { data, response, _ in
				dec()
				guard let response = response as? HTTPURLResponse else {
					DispatchQueue.main.async { callback(0, [:]) }
					return
				}
				guard response.statusCode != 403 else {
					DispatchQueue.main.async {
						clearMasterSecret()
						callback(403, [:])
					}
					return
				}
				guard response.statusCode != 423 || tryCount <= 0 else {
					DispatchQueue.main.async {
						uploadReceiptKey(try: 0) { success in
							if success {
								getData(for: originalParameters, command: command, addKey: addKey, masterSecret: masterSecret, try: tryCount - 1, callback: callback)
							} else {
								callback(423, [:])
							}
						}
					}
					return
				}
				let dictionary: [String: Any]
				if let data = data {
					dictionary = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
				} else {
					dictionary = [:]
				}
				DispatchQueue.main.async { callback(response.statusCode, dictionary) }
			}
		}
		if addKey {
			guard let keys = keys(from: masterSecret ?? self.masterSecret) else {
				callback(0, [:])
				return
			}
			var parameters = parameters as [String: Any]
			parameters["v"] = 3
			proofOfOwnership { data in
				if let (key, token) = data {
					parameters["server_token"] = token
					parameters["pseudonym"] = Data(keys.pseudonym).base64EncodedString()
					let plaintext = try! JSONSerialization.data(withJSONObject: parameters)
					guard let ciphertext: Bytes = sodium.box.seal(message: Bytes(plaintext), recipientPublicKey: Bytes(key), senderSecretKey: keys.keys.secretKey) else {
						callback(0, [:])
						return
					}
					run(["app": Data(ciphertext).base64EncodedString(), "key": Data(keys.keys.publicKey).base64EncodedString()])
				} else {
					callback(0, [:])
				}
			}
		} else {
			run(parameters)
		}
	}
}
