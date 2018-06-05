//
//  EncryptedDBManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let settingsDB = "settings"
private let browsingDB = "browsing"

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
		DispatchQueue.main.async {
			if keyingData == nil, let _ = SQLCipher(path: dbPath, key: data) {
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
	let saltCount = salt.count
	let data = code.data(using: .utf8)!
	let dataCount = data.count
	var result = Data(repeating: 0, count: SQLCipher.keySize)
	let resultCount = result.count

	let status = result.withUnsafeMutableBytes { result in
		salt.withUnsafeBytes { (salt: UnsafePointer<UInt8>) -> Int32 in
			data.withUnsafeBytes { (data: UnsafePointer<Int8>) -> Int32 in
				// 200000 rounds are just about barable on old devices. Use random value in that range to prevent use of rainbow tables
				CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), data, dataCount, salt, saltCount, CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512), 199293, result, resultCount)
			}
		}
	}
	assert(status == 0)
	return result
}


let db: SQLiteManager = {
	precondition(keyingData != nil)

	SQLiteManager.freeSQLiteCachesOnMemoryWarning = true
	let manager = SQLiteManager(setup: { _ in
		let connection = SQLCipher(path: dbPath, key: keyingData)!
		try! connection.execute("PRAGMA secure_delete = on")
		try! connection.execute("PRAGMA foreign_keys = on")
		try! connection.busyTimeout(100)

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
	let appSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! as NSString
	let browsingPath = appSupportPath.appendingPathComponent("browsingdata.db")
	let settingsPath = appSupportPath.appendingPathComponent("settingsdata.db")
	let browsingKey = KeyManager(name: "browsingdata.db.passphrase")
	let settingsKey = KeyManager(name: "settingsdata.db.passphrase")

	if let key = try! browsingKey.keyIfExists() {
		let attachBrowsing = "ATTACH DATABASE ? AS \(browsingDB) KEY ?"
		_ = try? manager.execute(attachBrowsing, with: [.text(browsingPath), .text(key)])
	}

	if let key = try! settingsKey.keyIfExists() {
		let attachSettings = "ATTACH DATABASE ? AS \(settingsDB) KEY ?"
		_ = try? manager.execute(attachSettings, with: [.text(settingsPath), .text(key)])
	}

	manager.migrator = Migrator()
	try! manager.migrate()

	_ = try? manager.execute("DETACH \(settingsDB)")
	_ = try? manager.execute("DETACH \(browsingDB)")

	try? FileManager.default.removeItem(atPath: browsingPath)
	try? FileManager.default.removeItem(atPath: settingsPath)

	browsingKey.set(key: nil)
	settingsKey.set(key: nil)
	return manager
}()

private struct Migrator: SQLiteMigrator {
	func sqliteManager(_ manager: SQLiteManager, makeV1SetupForDatabase database: String, of connection: SQLite) throws {
		try connection.execute("PRAGMA auto_vacuum = FULL")
		try connection.execute("PRAGMA journal_mode = DELETE")

		let dbres = try connection.execute("PRAGMA database_list")

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

		// migrate old data
		if dbres.contains(where: { $0[1]?.textValue == browsingDB }) {
			_ = try? connection.execute("INSERT INTO \(BookmarkStore.tableName) (id, title, name, url, favicon, weight) SELECT id, title, name, url, favicon, weight FROM \(browsingDB).bookmark")
			_ = try? connection.execute("INSERT INTO \(HistoryStore.tableName) (id, url, title, timestamp) SELECT id, url, title, timestamp FROM \(browsingDB).history")
			_ = try? connection.execute("INSERT INTO \(TabStore.tableName) (id, root_id, title, history, snapshot, active) SELECT id, NULL, title, history, snapshot, active FROM \(browsingDB).tab")
		}

		if dbres.contains(where: { $0[1]?.textValue == settingsDB }) {
			_ = try? connection.execute("UPDATE \(settingsDB).\(Settings.pageTableName) SET domain = REPLACE(domain, ':', '::') WHERE domain != ?", with: [.text(aboutBlankURL)])
			_ = try? connection.execute("UPDATE \(settingsDB).\(Settings.pageTableName) SET domain = ? WHERE domain == ''", with: [.text(missingHostPseudoDomain)])
			_ = try? connection.execute("INSERT INTO \(Settings.globalTableName) (key, value) SELECT key, value FROM \(settingsDB).\(Settings.globalTableName)")
			_ = try? connection.execute("DELETE FROM \(settingsDB).\(Settings.tabTableName) WHERE tab_id NOT IN (SELECT id FROM \(TabStore.tableName))")
			_ = try? connection.execute("INSERT INTO \(Settings.tabTableName) (tab_id, key, value) SELECT tab_id, key, value FROM \(settingsDB).\(Settings.tabTableName)")
			_ = try? connection.execute("INSERT INTO \(Settings.pageTableName) (domain, key, value) SELECT domain, key, value FROM \(settingsDB).\(Settings.pageTableName)")
		}
	}
}
