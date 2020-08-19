//
//  EncryptedDBManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CommonCrypto

var dbAvailable: Bool {
	return keyingData != nil
}

private let dbKey = KeyManager(name: "snowhaze.db.passphrase")
private let dbPath = (NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("SnowHaze.db")

private var keyingData: Data!

func trySetupKey(key: String, completionHandler: ((Bool) -> Void)?) {
	DispatchQueue.global(qos: .userInteractive).async {
		let data: Data
		do {
			if try dbKey.keyIfExists() == nil {
				try? FileManager.default.removeItem(atPath: dbPath)
			}
			data = try pbkdf(key)
		} catch {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		_ = initSQLite
		DispatchQueue.main.async {
			if keyingData == nil, let _ = SQLCipher(path: dbPath, key: data, cipherOptions: .compatibility(3), setupOptions: .secure) {
				keyingData = data
				completionHandler?(true)
			} else {
				let keying = keyingData
				completionHandler?(keying == data)
			}
		}
	}
}

func verifyDBKey(_ key: String, completionHandler: @escaping (Bool) -> Void) {
	DispatchQueue.global(qos: .userInteractive).async {
		let data = try? pbkdf(key)
		DispatchQueue.main.async {
			completionHandler(keyingData == data)
		}
	}
}

func rekey(connection: SQLCipher, key: String) throws {
	let data = try pbkdf(key)
	if Thread.isMainThread {
		keyingData = data
	} else {
		DispatchQueue.main.sync {
			keyingData = data
		}
	}
	try connection.rekey(data)
}

private func pbkdf(_ code: String) throws -> Data {
	let salt = try dbKey.key().data(using: .utf8)!
	let data = code.data(using: .utf8)!
	var result = Data(repeating: 0, count: SQLCipher.keySize)

	let status = result.withUnsafeMutableBytes { rawResult in
		salt.withUnsafeBytes { rawSalt -> Int32 in
			data.withUnsafeBytes { rawData -> Int32 in
				// 200000 rounds are just about barable on old devices. Use random value in that range to prevent use of rainbow tables
				let rounds: UInt32 = 199293
				let data = rawData.bindMemory(to: Int8.self)
				let salt = rawSalt.bindMemory(to: UInt8.self)
				let result = rawResult.bindMemory(to: UInt8.self)
				let kdfAlgo = CCPBKDFAlgorithm(kCCPBKDF2)
				let hashAlgo = CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512)
				return CCKeyDerivationPBKDF(kdfAlgo, data.baseAddress, data.count, salt.baseAddress, salt.count, hashAlgo, rounds, result.baseAddress, result.count)
			}
		}
	}
	assert(status == 0)
	return result
}

let initSQLite: Void = {
	try! SQLite.set(option: .multithread)
}()

let db: SQLiteManager = {
	precondition(keyingData != nil)

	struct StaticData {
		static var setupComplete = false
	}

	func authorizer(_ action: SQLite.AuthorizerAction, _ db: String?, _ cause: String?) -> SQLite.AuthorizerResponse {
		if StaticData.setupComplete {
			switch (action, db, cause) {
				case (.select, nil, nil):																return .ok
				case (.function("fts5"), nil, nil):														return .ok
				case (.function("match"), nil, nil):													return .ok
				case (.function("ifnull"), nil, nil):													return .ok
				case (.function("strftime"), nil, nil):													return .ok
				case (.transaction("BEGIN"), nil, nil):													return .ok
				case (.transaction("COMMIT"), nil, nil):												return .ok
				case (.pragma("data_version", nil), "main", nil):										return .ok
				case (.pragma("rekey", let key), nil, nil):
					if key?.matches("x\'[a-f0-9]{64}\'") ?? false {
						return .ok
					}
					fatalError("attempting to encrypt database with invalid key \( key == nil ? "<null>" : "'\(key!)'")")

				case (.insert("kvstore"), "main", nil):													return .ok
				case (.read("kvstore", "key"), "main", nil):											return .ok
				case (.read("kvstore", "value"), "main", nil):											return .ok
				case (.delete("kvstore"), "main", nil):													return .ok

				case (.read("ch_illotros_snowhaze_browsing_tab", "id"), "main", nil):					return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "title"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "active"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "deleted"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "root_id"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "history"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "snapshot"), "main", nil):				return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "title"), "main", nil):				return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "active"), "main", nil):				return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "deleted"), "main", nil):			return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "history"), "main", nil):			return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "root_id"), "main", nil):			return .ok
				case (.update("ch_illotros_snowhaze_browsing_tab", "snapshot"), "main", nil):			return .ok
				case (.insert("ch_illotros_snowhaze_browsing_tab"), "main", nil):						return .ok
				case (.delete("ch_illotros_snowhaze_browsing_tab"), "main", nil):						return .ok

				case (.read("ch_illotros_snowhaze_browsing_history", "id"), "main", "ch_illotros_snowhaze_browsing_history_fts_delete"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "id"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "url"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "title"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "id"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "url"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "title"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "timestamp"), "main", nil):		return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history"), "main", nil):					return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history"), "main", nil):					return .ok

				case (.insert("ch_illotros_snowhaze_settings_tab"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "key"), "main", nil):					return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "value"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "tab_id"), "main", nil):				return .ok
				case (.delete("ch_illotros_snowhaze_settings_tab"), "main", nil):						return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark"), "main", nil):					return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark", "name"), "main", nil):			return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark", "title"), "main", nil):			return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark", "weight"), "main", nil):		return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark", "favicon"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "id"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "title"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "name"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "url"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "favicon"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "weight"), "main", nil):			return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark"), "main", nil):					return .ok

				case (.read("ch_illotros_snowhaze_browsing_bookmark", "id"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "url"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "name"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "title"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "id"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "url"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "name"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "title"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "id"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_delete"):										return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_content"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_content", "id"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_content", "c0"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_content", "c1"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_content", "c2"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark_fts_content"), "main", nil):		return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_docsize"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_docsize", "id"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_docsize", "sz"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark_fts_docsize"), "main", nil):		return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_data"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_data", "id"), "main", nil):		return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark_fts_data"), "main", nil):			return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_idx"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "pgno"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "term"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "segid"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark_fts_idx"), "main", nil):			return .ok

				case (.delete("ch_illotros_snowhaze_settings_page"), "main", nil):						return .ok
				case (.insert("ch_illotros_snowhaze_settings_page"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "key"), "main", nil):					return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "value"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "domain"), "main", nil):				return .ok

				case (.delete("ch_illotros_snowhaze_settings_global"), "main", nil):					return .ok
				case (.insert("ch_illotros_snowhaze_settings_global"), "main", nil):					return .ok
				case (.read("ch_illotros_snowhaze_settings_global", "key"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_global", "value"), "main", nil):				return .ok

				case (.read("ch_illotros_snowhaze_browsing_history_fts", "ROWID"), "main", "ch_illotros_snowhaze_browsing_history_fts_delete"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts", "id"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts", "url"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts", "title"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):									return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history_fts"), "main", "ch_illotros_snowhaze_browsing_history_fts_delete"):										return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok

				case (.read("ch_illotros_snowhaze_browsing_history_fts", "ROWID"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts", "rank"), "main", nil):			return .ok

				case (.read("ch_illotros_snowhaze_browsing_history_fts", "ch_illotros_snowhaze_browsing_history_fts"), "main", nil):											return .ok

				case (.insert("ch_illotros_snowhaze_browsing_history_fts_content"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_content", "id"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_content", "c0"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_content", "c1"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history_fts_content"), "main", nil):		return .ok

				case (.insert("ch_illotros_snowhaze_browsing_history_fts_docsize"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_docsize", "sz"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_docsize", "id"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history_fts_docsize"), "main", nil):		return .ok

				case (.insert("ch_illotros_snowhaze_browsing_history_fts_data"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_data", "id"), "main", nil):		return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history_fts_data"), "main", nil):			return .ok

				case (.insert("ch_illotros_snowhaze_browsing_history_fts_idx"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_idx", "pgno"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_idx", "term"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_idx", "segid"), "main", nil):	return .ok
				case (.delete("ch_illotros_snowhaze_browsing_history_fts_idx"), "main", nil):			return .ok

				case (.read("ch_illotros_snowhaze_browsing_history_fts_config", "k"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_config", "v"), "main", nil):		return .ok

				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_config", "k"), "main", nil):	return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_config", "v"), "main", nil):	return .ok

				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "rank"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "ROWID"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "ch_illotros_snowhaze_browsing_bookmark_fts"), "main", nil):											return .ok

				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "ROWID"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):								return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark_fts", "url"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):								return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark_fts", "name"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):								return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark_fts", "title"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):								return .ok
				case (.update("ch_illotros_snowhaze_browsing_bookmark_fts", "ROWID"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_update"):								return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "id"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_delete"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts", "ROWID"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_delete"):								return .ok
				case (.delete("ch_illotros_snowhaze_browsing_bookmark_fts"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_delete"):										return .ok

				case (.read("sqlite_master", "ROWID"), "main", nil):									return .ok
				case (.update("sqlite_master", "sql"), "main", nil):									return .ok
				case (.update("sqlite_master", "type"), "main", nil):									return .ok
				case (.update("sqlite_master", "name"), "main", nil):									return .ok
				case (.update("sqlite_master", "tbl_name"), "main", nil):								return .ok
				case (.update("sqlite_master", "rootpage"), "main", nil):								return .ok

				default:																				fatalError("unauthorized operation \((action, db, cause))")
			}
		} else {
			switch (action, db, cause) {
				case (.select, nil, nil):																	return .ok
				case (.function("fts5"), nil, nil):															return .ok
				case (.function("substr"), nil, nil):														return .ok
				case (.transaction("BEGIN"), nil, nil):														return .ok
				case (.transaction("COMMIT"), nil, nil):													return .ok
				case (.transaction("ROLLBACK"), nil, nil):													return .ok
				case (.detach("settings"), nil, nil):														return .ok
				case (.detach("browsing"), nil, nil):														return .ok

				case (.pragma("user_version", nil), "main", nil):											return .ok
				case (.pragma("data_version", nil), "main", nil):											return .ok
				case (.pragma("database_list", nil), nil, nil):												return .ok
				case (.pragma("user_version", "1"), "main", nil):											return .ok
				case (.pragma("user_version", "2"), "main", nil):											return .ok
				case (.pragma("auto_vacuum", "FULL"), nil, nil):											return .ok
				case (.pragma("journal_mode", "DELETE"), nil, nil):											return .ok

				case (.insert("sqlite_master"), "main", nil):												return .ok
				case (.read("sqlite_master", "ROWID"), "main", nil):										return .ok
				case (.read("sqlite_master", "sql"), "main", nil):											return .ok
				case (.read("sqlite_master", "type"), "main", nil):											return .ok
				case (.read("sqlite_master", "name"), "main", nil):											return .ok
				case (.update("sqlite_master", "sql"), "main", nil):										return .ok
				case (.update("sqlite_master", "type"), "main", nil):										return .ok
				case (.update("sqlite_master", "name"), "main", nil):										return .ok
				case (.update("sqlite_master", "tbl_name"), "main", nil):									return .ok
				case (.update("sqlite_master", "rootpage"), "main", nil):									return .ok

				case (.createTable("sqlite_sequence"), "main", nil):										return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark"), "main", nil):					return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark"), "main", nil):						return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_bookmark", "ch_illotros_snowhaze_browsing_bookmark_fts_update"), "main", nil):								return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_bookmark", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"), "main", nil):								return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_bookmark", "ch_illotros_snowhaze_browsing_bookmark_fts_delete"), "main", nil):								return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "id"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "url"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "name"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):									return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark", "title"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):									return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history"), "main", nil):					return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_history", "ch_illotros_snowhaze_browsing_history_fts_update"), "main", nil):								return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_history", "ch_illotros_snowhaze_browsing_history_fts_insert"), "main", nil):								return .ok
				case (.createTrigger("ch_illotros_snowhaze_browsing_history", "ch_illotros_snowhaze_browsing_history_fts_delete"), "main", nil):								return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "id"), "main", nil):					return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "id"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "url"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok
				case (.read("ch_illotros_snowhaze_browsing_history", "title"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_tab"), "main", nil):						return .ok
				case (.alterTable("main", "ch_illotros_snowhaze_browsing_tab"), nil, nil):					return .ok
				case (.insert("ch_illotros_snowhaze_browsing_tab"), "main", nil):							return .ok
				case (.read("ch_illotros_snowhaze_browsing_tab", "id"), "main", nil):						return .ok

				case (.createTable("ch_illotros_snowhaze_settings_tab"), "main", nil):						return .ok
				case (.insert("ch_illotros_snowhaze_settings_tab"), "main", nil):							return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "key"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "tab_id"), "main", nil):					return .ok
				case (.createIndex("ch_illotros_snowhaze_settings_tab", "sqlite_autoindex_ch_illotros_snowhaze_settings_tab_1"), "main", nil):									return .ok

				case (.createTable("ch_illotros_snowhaze_settings_global"), "main", nil):					return .ok
				case (.insert("ch_illotros_snowhaze_settings_global"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_settings_global", "key"), "main", nil):					return .ok
				case (.createIndex("ch_illotros_snowhaze_settings_global", "sqlite_autoindex_ch_illotros_snowhaze_settings_global_1"), "main", nil):							return .ok

				case (.createTable("ch_illotros_snowhaze_settings_page"), "main", nil):						return .ok
				case (.insert("ch_illotros_snowhaze_settings_page"), "main", nil):							return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "key"), "main", nil):						return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "domain"), "main", nil):					return .ok
				case (.createIndex("ch_illotros_snowhaze_settings_page", "sqlite_autoindex_ch_illotros_snowhaze_settings_page_1"), "main", nil):								return .ok

				case (.createTable("kvstore"), "main", nil):												return .ok
				case (.read("kvstore", "key"), "main", nil):												return .ok
				case (.createIndex("kvstore", "sqlite_autoindex_kvstore_1"), "main", nil):					return .ok

				case (.createVtable("ch_illotros_snowhaze_browsing_bookmark_fts", "fts5"), "main", nil):	return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts"), "main", "ch_illotros_snowhaze_browsing_bookmark_fts_insert"):										return .ok

				case (.createVtable("ch_illotros_snowhaze_browsing_history_fts", "fts5"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts"), "main", nil):					return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts"), "main", "ch_illotros_snowhaze_browsing_history_fts_insert"):										return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark_fts_data"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_data"), "main", nil):				return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark_fts_content"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_content"), "main", nil):			return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark_fts_docsize"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_docsize"), "main", nil):			return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history_fts_data"), "main", nil):			return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts_data"), "main", nil):				return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history_fts_content"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts_content"), "main", nil):			return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history_fts_docsize"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts_docsize"), "main", nil):			return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history_fts_config"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts_config"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_config", "k"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_config", "v"), "main", nil):			return .ok
				case (.createIndex("ch_illotros_snowhaze_browsing_history_fts_config", "sqlite_autoindex_ch_illotros_snowhaze_browsing_history_fts_config_1"), "main", nil):	return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_history_fts_idx"), "main", nil):			return .ok
				case (.createIndex("ch_illotros_snowhaze_browsing_history_fts_idx", "sqlite_autoindex_ch_illotros_snowhaze_browsing_history_fts_idx_1"), "main", nil):			return .ok
				case (.insert("ch_illotros_snowhaze_browsing_history_fts_idx"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_idx", "term"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_history_fts_idx", "segid"), "main", nil):		return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark_fts_config"), "main", nil):		return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_config"), "main", nil):			return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_config", "k"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_config", "v"), "main", nil):		return .ok
				case (.createIndex("ch_illotros_snowhaze_browsing_bookmark_fts_config", "sqlite_autoindex_ch_illotros_snowhaze_browsing_bookmark_fts_config_1"), "main", nil):	return .ok

				case (.createTable("ch_illotros_snowhaze_browsing_bookmark_fts_idx"), "main", nil):			return .ok
				case (.insert("ch_illotros_snowhaze_browsing_bookmark_fts_idx"), "main", nil):				return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "term"), "main", nil):		return .ok
				case (.read("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "segid"), "main", nil):		return .ok
				case (.createIndex("ch_illotros_snowhaze_browsing_bookmark_fts_idx", "sqlite_autoindex_ch_illotros_snowhaze_browsing_bookmark_fts_idx_1"), "main", nil):		return .ok

				case (.attach(nil), nil, nil):																return .ok
				case (.pragma("cipher_default_compatibility", "3"), nil, nil):								return .ok
				case (.function("replace"), nil, nil):														return .ok

				case (.read("bookmark", "id"), "browsing", nil):											return .ok
				case (.read("bookmark", "url"), "browsing", nil):											return .ok
				case (.read("bookmark", "name"), "browsing", nil):											return .ok
				case (.read("bookmark", "title"), "browsing", nil):											return .ok
				case (.read("bookmark", "weight"), "browsing", nil):										return .ok
				case (.read("bookmark", "favicon"), "browsing", nil):										return .ok

				case (.read("history", "id"), "browsing", nil):												return .ok
				case (.read("history", "url"), "browsing", nil):											return .ok
				case (.read("history", "title"), "browsing", nil):											return .ok
				case (.read("history", "timestamp"), "browsing", nil):										return .ok

				case (.read("tab", "id"), "browsing", nil):													return .ok
				case (.read("tab", "title"), "browsing", nil):												return .ok
				case (.read("tab", "active"), "browsing", nil):												return .ok
				case (.read("tab", "history"), "browsing", nil):											return .ok
				case (.read("tab", "replace"), "browsing", nil):											return .ok
				case (.read("tab", "snapshot"), "browsing", nil):											return .ok

				case (.read("ch_illotros_snowhaze_settings_page", "key"), "settings", nil):					return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "value"), "settings", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_page", "domain"), "settings", nil):				return .ok
				case (.update("ch_illotros_snowhaze_settings_page", "domain"), "settings", nil):			return .ok
				case (.delete("ch_illotros_snowhaze_settings_page"), "main", nil):							return .ok

				case (.read("ch_illotros_snowhaze_settings_global", "key"), "settings", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_global", "value"), "settings", nil):				return .ok

				case (.read("ch_illotros_snowhaze_settings_tab", "key"), "settings", nil):					return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "value"), "settings", nil):				return .ok
				case (.read("ch_illotros_snowhaze_settings_tab", "tab_id"), "settings", nil):				return .ok
				case (.delete("ch_illotros_snowhaze_settings_tab"), "settings", nil):						return .ok

				default:																					fatalError("unauthorized operation \((action, db, cause))")
			}
		}
	}

	SQLiteManager.freeSQLiteCachesOnMemoryWarning = true
	_ = initSQLite
	let manager = SQLiteManager(setup: { _ in
		let excludedOptions: SQLite.SetupOptions = [.limitVariableNumber, .limitLength, .disableTriggers]
		let setupOptions = SQLite.SetupOptions.secure.subtracting(excludedOptions)
		let connection = SQLCipher(path: dbPath, key: keyingData, cipherOptions: .compatibility(3), setupOptions: setupOptions)!
		try! connection.dropModules(except: ["fts5"])
		try! connection.execute("PRAGMA secure_delete = on")
		try! connection.execute("PRAGMA foreign_keys = on")
		try! connection.busyTimeout(100)

		try! connection.set(authorizer: authorizer)

		try! connection.registerFTS5Tokenizer(named: "lemma") { _ in
			return { flags, rawText in
				var result: [(SQLite.FTS5TokenFlags, String, Range<String.Index>)] = []
				let tagger = NSLinguisticTagger(tagSchemes: [NSLinguisticTagScheme.lemma], options: 0)
				let base = rawText.removingPercentEncoding ?? rawText
				let text = base.replacingOccurrences(of: ".", with: " ")
				tagger.string = text
				tagger.enumerateTags(in: NSRange(text.startIndex ..< text.endIndex, in: text), scheme: NSLinguisticTagScheme.lemma, options: [.omitWhitespace, .omitPunctuation]) { tag, range, _, _ in
					if let swiftRange = Range(range, in: text) {
						let token = text[swiftRange].localizedLowercase
						result.append(([], token, swiftRange))
						if let trueTag = tag?.rawValue, trueTag.localizedLowercase != token && !trueTag.isEmpty {
							result.append((.colocated, trueTag.localizedLowercase, swiftRange))
						}
					}
				}
				return result
			}
		}
		return connection
	})

	manager.migrator = Migrator()
	try! manager.migrate(toVersion: 2)

	StaticData.setupComplete = true

	try! manager.connection.set(authorizer: authorizer)

	return manager
}()

private struct Migrator: SQLiteMigrator {
	func sqliteManager(_ manager: SQLiteManager, makeV1SetupForDatabase database: String, of connection: SQLite) throws {
		try connection.execute("PRAGMA auto_vacuum = FULL")
		try connection.execute("PRAGMA journal_mode = DELETE")

		// create tables
		try connection.execute("CREATE TABLE \(BookmarkStore.tableName) (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, name TEXT, url TEXT NOT NULL, favicon BLOB, weight FLOAT NOT NULL)")
		try connection.execute("CREATE TABLE \(HistoryStore.tableName) (id INTEGER PRIMARY KEY, url TEXT NOT NULL, title TEXT, timestamp FLOAT NOT NULL)")
		try connection.execute("CREATE TABLE \(TabStore.tableName) (id INTEGER PRIMARY KEY AUTOINCREMENT, root_id INTEGER, title TEXT, history TEXT NOT NULL, snapshot BLOB, active INTEGER NOT NULL)")
		try connection.execute("CREATE TABLE \(Settings.globalTableName) (key TEXT PRIMARY KEY, value) WITHOUT ROWID")
		try connection.execute("CREATE TABLE \(Settings.tabTableName) (tab_id INTEGER REFERENCES \(TabStore.tableName) ON UPDATE CASCADE ON DELETE CASCADE, key TEXT, value, PRIMARY KEY (tab_id, key)) WITHOUT ROWID")
		try connection.execute("CREATE TABLE \(Settings.pageTableName) (domain TEXT, key TEXT, value, PRIMARY KEY (domain, key)) WITHOUT ROWID")

		try connection.execute("CREATE TABLE \(DataStore.tableName) (key TEXT PRIMARY KEY, value) WITHOUT ROWID")

		// create fts indexes
		try connection.execute("CREATE VIRTUAL TABLE \(BookmarkStore.ftsName) USING fts5(title, name, url, tokenize='lemma')")
		try connection.execute("CREATE VIRTUAL TABLE \(HistoryStore.ftsName) USING fts5(title, url, tokenize='lemma')")

		// keep fts indexes up to date
		try connection.execute("CREATE TRIGGER \(BookmarkStore.ftsUpdateName) AFTER UPDATE ON \(BookmarkStore.tableName) FOR EACH ROW WHEN NEW.id IS NOT OLD.id OR NEW.title IS NOT OLD.title OR NEW.name IS NOT OLD.name OR NEW.url IS NOT OLD.url BEGIN UPDATE \(BookmarkStore.ftsName) SET rowid = NEW.id, title = NEW.title, name = NEW.name, url = NEW.url WHERE rowid = OLD.id; END")
		try connection.execute("CREATE TRIGGER \(BookmarkStore.ftsInsertName) AFTER INSERT ON \(BookmarkStore.tableName) FOR EACH ROW BEGIN INSERT INTO \(BookmarkStore.ftsName) (rowid, title, name, url) VALUES (NEW.id, NEW.title, NEW.name, NEW.url); END")
		try connection.execute("CREATE TRIGGER \(BookmarkStore.ftsDeleteName) AFTER DELETE ON \(BookmarkStore.tableName) FOR EACH ROW BEGIN DELETE FROM \(BookmarkStore.ftsName) WHERE rowid = OLD.id; END")

		try connection.execute("CREATE TRIGGER \(HistoryStore.ftsUpdateName) AFTER UPDATE ON \(HistoryStore.tableName) FOR EACH ROW WHEN NEW.id IS NOT OLD.id OR NEW.title IS NOT OLD.title OR NEW.url IS NOT OLD.url BEGIN UPDATE \(HistoryStore.ftsName) SET rowid = NEW.id, title = NEW.title, url = NEW.url WHERE rowid = OLD.id; END")
		try connection.execute("CREATE TRIGGER \(HistoryStore.ftsInsertName) AFTER INSERT ON \(HistoryStore.tableName) FOR EACH ROW BEGIN INSERT INTO \(HistoryStore.ftsName) (rowid, title, url) VALUES (NEW.id, NEW.title, NEW.url); END")
		try connection.execute("CREATE TRIGGER \(HistoryStore.ftsDeleteName) AFTER DELETE ON \(HistoryStore.tableName) FOR EACH ROW BEGIN DELETE FROM \(HistoryStore.ftsName) WHERE rowid = OLD.id; END")
	}

	func sqliteManager(_ manager: SQLiteManager, incrementalyUpgradeDatabase database: String, of connection: SQLite, toVersion version: UInt64) throws {
		precondition(version == 2)
		try connection.execute("ALTER TABLE \(TabStore.tableName) ADD COLUMN deleted INTEGER DEFAULT FALSE")
		try connection.execute("DELETE FROM \(Settings.pageTableName) WHERE domain = ?", with: [.text(PolicyDomain.aboutBlankURL)])
	}
}
