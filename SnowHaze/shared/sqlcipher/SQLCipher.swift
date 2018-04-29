//
//  SQLCipher.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

public class SQLCipher: SQLite {
	public static let keySize = 32

	public init?(path: String, key: String, flags: OpenFlags = .rwCreate) {
		super.init(path: path, finalSetup: "PRAGMA key = \(key.sqliteEscaped)", openName: path, flags: flags)
	}

	public init?(url: URL, key: String, flags: OpenFlags = .rwCreate) {
		guard url.isFileURL else {
			return nil
		}
		super.init(path: url.path, finalSetup: "PRAGMA key = \(key.sqliteEscaped)", openName: url.absoluteString, flags: [flags, .uri])
	}

	public init?(path: String, key: Foundation.Data, flags: OpenFlags = .rwCreate) {
		super.init(path: path, finalSetup: "PRAGMA key = \"\(key.sqliteEscaped)\"", openName: path, flags: flags)
	}

	public init?(url: URL, key: Foundation.Data, flags: OpenFlags = .rwCreate) {
		guard url.isFileURL else {
			return nil
		}
		super.init(path: url.path, finalSetup: "PRAGMA key = \"\(key.sqliteEscaped)\"", openName: url.absoluteString, flags: [flags, .uri])
	}

	public func rekey(_ new: String) throws {
		try execute("PRAGMA rekey = \(new.sqliteEscaped)")
	}

	public func rekey(_ new: Foundation.Data) throws {
		try execute("PRAGMA rekey = \"\(new.sqliteEscaped)\"")
	}
}
