//
//  SQLiteManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let threadlocalConnectionKey = "ch.illotros.sqlitemanager.threadlocal.connection"

private let coordinationQueue = DispatchQueue(label: "ch.illotros.sqlitemanager.coordination")

protocol SQLiteMigrator {
	func sqliteManager(_ manager: SQLiteManager, migrateDatabase database: String, of connection: SQLite, fromVersion from: UInt64, to: UInt64) throws
	func sqliteManager(_ manager: SQLiteManager, didMigrateDatabase database: String, of connection: SQLite, fromVersion from: UInt64, to: UInt64) throws

	// simplified handling
	func sqliteManager(_ manager: SQLiteManager, incrementalyUpgradeDatabase database: String, of connection: SQLite, toVersion: UInt64) throws
	func sqliteManager(_ manager: SQLiteManager, incrementalyDowngradeDatabase database: String, of connection: SQLite, toVersion: UInt64) throws
	func sqliteManager(_ manager: SQLiteManager, setupDatabase database: String, of connection: SQLite, toVersion to: UInt64) throws
	func sqliteManager(_ manager: SQLiteManager, makeV1SetupForDatabase database: String, of connection: SQLite) throws
}

extension SQLiteMigrator {
	func sqliteManager(_ manager: SQLiteManager, didMigrateDatabase database: String, of connection: SQLite, fromVersion from: UInt64, to: UInt64) throws { }

	func sqliteManager(_ manager: SQLiteManager, migrateDatabase database: String, of connection: SQLite, fromVersion from: UInt64, to: UInt64) throws {
		var from = from
		guard from != to && to > 0 else {
			throw SQLiteManager.Error.parameterError
		}
		if from == 0 {
			try sqliteManager(manager, setupDatabase: database, of: connection, toVersion: to)
		} else if from < to {
			repeat {
				try sqliteManager(manager, incrementalyUpgradeDatabase: database, of: connection, toVersion: from + 1)
				from += 1
			} while from != to
		} else {
			repeat {
				from -= 1
				try sqliteManager(manager, incrementalyDowngradeDatabase: database, of: connection, toVersion: from)
			} while from != to
		}
	}

	func sqliteManager(_ manager: SQLiteManager, incrementalyUpgradeDatabase database: String, of connection: SQLite, toVersion: UInt64) throws {
			throw SQLiteManager.Error.upgradeNotImplemented
	}

	func sqliteManager(_ manager: SQLiteManager, incrementalyDowngradeDatabase database: String, of connection: SQLite, toVersion: UInt64) throws {
		throw SQLiteManager.Error.downgradeNotImplemented
	}

	func sqliteManager(_ manager: SQLiteManager, setupDatabase database: String, of connection: SQLite, toVersion to: UInt64) throws {
		guard to > 0 else {
			throw SQLiteManager.Error.parameterError
		}
		try sqliteManager(manager, makeV1SetupForDatabase: database, of: connection)
		var from: UInt64 = 1
		while from < to {
			from += 1
			try sqliteManager(manager, incrementalyUpgradeDatabase: database, of: connection, toVersion: from)
		}
	}

	func sqliteManager(_ manager: SQLiteManager, makeV1SetupForDatabase database: String, of connection: SQLite) throws {
		throw SQLiteManager.Error.setupNotImplemented
	}
}

class SQLiteManager {
	private typealias ThreadData = (version: UInt64, connection: SQLite?, cache: SQliteStatementCache?, observer: NSObjectProtocol?)
	private static var managerCnt: UInt64 = 0

	private let dbSetup: (Thread) -> SQLite?
	private let id: UInt64
	private var threads = Set<Thread>()
	private let lock = NSRecursiveLock()
	
	private let cacheSize: UInt

	private(set) var version: UInt64 = 1

	public convenience init(path: String = ":memory:", cacheSize: UInt = 30) {
		self.init(cacheSize: cacheSize) { _ in
			return SQLite(path: path)
		}
	}

	public convenience init(url: URL, cacheSize: UInt = 30) {
		self.init(cacheSize: cacheSize) { _ in
			return SQLite(url: url)
		}
	}

	private static var memoryObserver: NSObjectProtocol?

#if os(iOS)
	public var freeConnectionCachesOnMemoryWarning = true

	public static var freeSQLiteCachesOnMemoryWarning: Bool {
		get {
			return memoryObserver != nil
		}
		set {
			guard (memoryObserver != nil) != newValue else {
				return
			}
			coordinationQueue.sync {
				guard (memoryObserver != nil) != newValue else {
					return
				}
				let center = NotificationCenter.default
				if newValue {
					let name = Notification.Name.UIApplicationDidReceiveMemoryWarning
					memoryObserver = center.addObserver(forName: name, object: nil, queue: nil) { _ in
						SQLite.free(Int.max)
					}
				} else {
					center.removeObserver(memoryObserver!)
					memoryObserver = nil
				}
			}
		}
	}
#endif

	public enum Error: Swift.Error {
		case setupError
		case sqliteError
		case parameterError
		case upgradeNotImplemented
		case downgradeNotImplemented
		case setupNotImplemented
	}

	public var migrator: SQLiteMigrator?

	public init(cacheSize: UInt = 30, setup: @escaping (Thread) -> SQLite?) {
		var initID: UInt64 = 0
		coordinationQueue.sync {
			initID = SQLiteManager.managerCnt
			SQLiteManager.managerCnt += 1
		}
		id = initID
		dbSetup = setup
		self.cacheSize = cacheSize
	}

	private var threadData: ThreadData {
		let thread = Thread.current
		let targetVersion = version
		let key = threadlocalConnectionKey + "-\(id)"

		if let stored = thread.threadDictionary.object(forKey: key) as? ThreadData {
			let (isVersion, _, _, observer) = stored
			if isVersion == targetVersion {
				return stored
			} else if let observer = observer {
				NotificationCenter.default.removeObserver(observer)
			}
		}

		lock.lock()

		threads.insert(thread)

		let connection = dbSetup(thread)
		lock.unlock()
		
		let statementCache = connection == nil ? nil : SQliteStatementCache(connection: connection!, size: cacheSize)

		var observer: NSObjectProtocol? = nil

#if os(iOS)
		if let connection = connection, freeConnectionCachesOnMemoryWarning {
			let name = Notification.Name.UIApplicationDidReceiveMemoryWarning
			let center = NotificationCenter.default
			observer = center.addObserver(forName: name, object: nil, queue: nil) { [weak connection, weak thread] _ in
				class Freeer: NSObject {
					let connection: SQLite
					let statementCache: SQliteStatementCache
					init(connection: SQLite, statementCache: SQliteStatementCache) {
						self.connection = connection
						self.statementCache = statementCache
					}
					@objc fileprivate func free() {
						try? connection.free()
						statementCache.clear()
					}
				}
				if let connection = connection, let thread = thread, let statementCache = statementCache {
					let freeer = Freeer(connection: connection, statementCache: statementCache)
					freeer.perform(#selector(Freeer.free), on: thread, with: nil, waitUntilDone: false)
				}
			}
		}
#endif

		let data = (targetVersion, connection, statementCache, observer)
		thread.threadDictionary.setValue(data, forKey: key)
		return data
	}
	
	public var connection: SQLite! {
		return threadData.connection
	}

	public func reload() {
		lock.lock()
		version += 1
		lock.unlock()
	}

	@discardableResult public func migrate(database: String = "main", toVersion: UInt64 = 1) throws -> Bool {
		guard let migrator = migrator, let db = connection else {
			throw Error.setupError
		}
		guard toVersion > 0 else {
			throw SQLiteManager.Error.parameterError
		}
		var didMigrate = false
		var fromVersion: UInt64 = 0
		try db.inTransaction(ofType: .exclusive) {
			let result = try db.execute("PRAGMA \(database.sqliteEscapedIdentifier).user_version")
			guard result.count == 1, let oldVersion = result[0].integer else {
				throw Error.sqliteError
			}
			fromVersion = UInt64(bitPattern: oldVersion)
			if fromVersion != toVersion {
				didMigrate = true
				try migrator.sqliteManager(self, migrateDatabase: database, of: db, fromVersion: fromVersion, to: toVersion)
				try db.execute("PRAGMA \(database.sqliteEscapedIdentifier).user_version = \(toVersion)")
			}
		}
		if didMigrate {
			try migrator.sqliteManager(self, didMigrateDatabase: database, of: db, fromVersion: fromVersion, to: toVersion)
		}
		return didMigrate
	}

	public func inTransaction<T>(ofType type: SQLite.TransactionType = .deferred, perform body: () throws -> T) throws -> T {
		guard let connection = connection else {
			throw SQLite.Error.sqliteSwiftError("No connection for thread \(Thread.current.name ?? "unknow")")
		}
		return try connection.inTransaction(ofType: type, perform: body)
	}

	public func withUniqueBackgroundConnection(qos: DispatchQoS.QoSClass, work: @escaping (SQLite?) -> Void) {
		lock.lock()
		reload()
		DispatchQueue.global(qos: qos).sync {
			work(self.dbSetup(Thread.current))
		}
		lock.unlock()
	}
	
	public func statement(for code: String) throws -> SQLite.Statement? {
		return try threadData.cache?.statement(for: code)
	}

	private func fullStatement(for code: String) throws -> SQLite.Statement {
		guard let statement = try statement(for: code) else {
			throw SQLite.Error.sqliteSwiftError("could not initialize statement for '\(code)'")
		}
		return statement
	}

	public func execute(_ query: String, callback: (SQLite.Row) -> Bool) throws {
		let statement = try fullStatement(for: query)
		try statement.execute(callback: callback)
	}
	
	@discardableResult public func execute(_ query: String) throws -> [SQLite.Row] {
		let statement = try fullStatement(for: query)
		return try statement.execute()
	}
	
	@discardableResult public func execute(_ query: String, with bindings: [SQLite.BindingKey: SQLite.Data]) throws -> [SQLite.Row] {
		let statement = try fullStatement(for: query)
		return try statement.execute(with: bindings)
	}
	
	@discardableResult public func execute(_ query: String, with bindings: [SQLite.Data]) throws -> [SQLite.Row] {
		let statement = try fullStatement(for: query)
		return try statement.execute(with: bindings)
	}
	
	@discardableResult public func execute(_ query: String, with bindings: [Int: SQLite.Data]) throws -> [SQLite.Row] {
		let statement = try fullStatement(for: query)
		return try statement.execute(with: bindings)
	}
	
	@discardableResult public func execute(_ query: String, with bindings: [String: SQLite.Data]) throws -> [SQLite.Row] {
		let statement = try fullStatement(for: query)
		return try statement.execute(with: bindings)
	}

	public func has(table: String) -> Bool? {
		return connection?.has(table: table)
	}
	
	public var lastInsertRowId: Int64! {
		return connection?.lastInsertRowId
	}

	deinit {
		lock.lock()
		let key = threadlocalConnectionKey + "-\(id)"
		for thread in threads {
			guard let stored = thread.threadDictionary.object(forKey: key) as? ThreadData else {
				continue
			}
			let (_, _, _, o) = stored
			if let observer = o {
				NotificationCenter.default.removeObserver(observer)
			}
			thread.threadDictionary.setValue(nil, forKey: key)
		}
		lock.unlock()
	}
}

private class SQliteStatementCache {
	private let connection: SQLite
	private let size: UInt
	private var statements = [String : SQLite.Statement]()

	init(connection: SQLite, size: UInt) {
		self.connection = connection
		self.size = size
	}

	func statement(for query: String) throws -> SQLite.Statement? {
		if let statement = statements[query] {
			try statement.reset()
			try statement.clearBindings()
			return statement
		}
		let cachable = isCachable(query: query)
		let options = cachable ? SQLite.Statement.PrepareOptions.persistent : []
		let statement = try connection.statement(for: query, options: options)
		if cachable, let statement = statement {
			if statements.count >= size {
				assert(statements.count == size)
				let random = rand(statements.count)
				let key = statements.index(statements.startIndex, offsetBy: random)
				statements.remove(at: key)
			}
			statements[query] = statement
		}
		return statement
	}

	func clear() {
		statements.removeAll()
	}

	private static let pragmaRx = try! NSRegularExpression(pattern: "\\A(--[^\\n]*(?:\\n|\\z)|/\\*([^*]|\\*(?!/))*(?:\\*/|\\z)|\\s)*pragma(--|/\\*|\\s)", options: .caseInsensitive)
	private func isCachable(query: String) -> Bool {
		let nsRange = NSRange(query.startIndex ..< query.endIndex, in: query)
		return SQliteStatementCache.pragmaRx.numberOfMatches(in: query, range: nsRange) == 0
	}

	private func rand(_ range: Int) -> Int {
		var result = -1
		while result < 0 {
			var rand = 0
			let randPtr = UnsafeMutablePointer<Int>(&rand)
			let opaquePtr = OpaquePointer(randPtr)
			let bytePtr = UnsafeMutablePointer<UInt8>(opaquePtr)
			guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<Int>.size, bytePtr) == errSecSuccess else {
				continue
			}
			let coef = Int.max / range
			if rand < 0 {
				rand = -(rand + 1)
			}
			guard rand < coef * range else {
				continue
			}
			result = rand % range
		}
		return result
	}
}
