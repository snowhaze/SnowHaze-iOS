//
//  DataStore.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class DataStore {
	private init() { }
	static let shared = DataStore()
	static let tableName = "kvstore"

	private var store: [String: SQLite.Data] = {
		let queryRes = try! db.execute("SELECT * FROM \(DataStore.tableName)")
		var store: [String: SQLite.Data] = [:]
		for row in queryRes {
			store[row["key"]!.text!] = row["value"]!
		}
		return store
	}()

	private func set(_ value: SQLite.Data, for key: String) {
		assert(Thread.isMainThread)
		try! db.execute("REPLACE INTO \(DataStore.tableName) (key, value) VALUES (?, ?)", with: [.text(key), value])
		store[key] = value
	}

	func delete(_ key: String) {
		assert(Thread.isMainThread)
		store[key] = nil
		try! db.execute("DELETE FROM \(DataStore.tableName) WHERE key = ?", with: [.text(key)])
	}

	func set(_ value: String?, for key: String) {
		set(SQLite.Data(value), for: key)
	}

	func set(_ value: Data?, for key: String) {
		set(SQLite.Data(value), for: key)
	}

	func set(_ value: Double?, for key: String) {
		if let value = value {
			set(SQLite.Data.float(value), for: key)
		} else {
			set(SQLite.Data.null, for: key)
		}
	}

	func set(_ value: Int64?, for key: String) {
		if let value = value {
			set(SQLite.Data.integer(value), for: key)
		} else {
			set(SQLite.Data.null, for: key)
		}
	}

	func set(_ value: Bool?, for key: String) {
		if let value = value {
			set(SQLite.Data(value), for: key)
		} else {
			set(SQLite.Data.null, for: key)
		}
	}

	func getString(for key: String) -> String? {
		return store[key]?.textValue
	}

	func getData(for key: String) -> Data? {
		return store[key]?.blobValue
	}

	func getBool(for key: String) -> Bool? {
		return store[key]?.boolValue
	}

	func getDouble(for key: String) -> Double? {
		return store[key]?.floatValue
	}

	func getInt(for key: String) -> Int64? {
		return store[key]?.integerValue
	}
}
