//
//  DomainList.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CommonCrypto
import UIKit

enum DomainListType {
	case trackingScripts
	case ads
	case httpsSites
	case privateSites			// does not contain www. prefixes (as an optimization)
	case nonPrivatePopularSites
	case popularSites
	case blogspot
	case danger
	case dangerHash
	case empty

	fileprivate var table: String {
		switch self {
			case .trackingScripts:			return "tracking"
			case .ads:						return "ad"
			case .httpsSites:				return "https"
			case .privateSites:				return "private"
			case .nonPrivatePopularSites:	return "(SELECT * FROM popular WHERE domain NOT IN private AND (substr(domain, 1, 4) != 'www.' OR substr(domain, 5) NOT IN private))"
			case .popularSites:				return "popular"
			case .blogspot:					return "blogspot"
			case .danger:					return "danger"
			case .dangerHash:				return "danger_hash"
			case .empty:					return "(SELECT *, 0 AS type, NULL AS hash FROM popular WHERE 0)"
		}
	}
}

class DomainList {
	let type: DomainListType

	static let dbFileChangedNotification = Notification.Name(rawValue: "DomainListDBFileChangedNotification")

	private static let cbVersionCacheLock = NSRecursiveLock()

	private static var cbVersionBackingCache: [String: Int64]?
	private static var cbVersionCache: [String: Int64] {
		cbVersionCacheLock.lock()
		var result = cbVersionBackingCache
		if result == nil {
			result = [:]
			for row in try! dbManager.execute("SELECT id, version FROM content_blocker") {
				result![row["id"]!.text!] = row["version"]!.integer!
			}
			cbVersionBackingCache = result
		}
		cbVersionCacheLock.unlock()
		return result!
	}

	static let dbLocation: String = {
		let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
		return (cachePath.first! as NSString).appendingPathComponent("lists.db")
	}()

	static let dbKey = Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")!

	private static func authorizer(_ action: SQLite.AuthorizerAction, _ db: String?, _ cause: String?) -> SQLite.AuthorizerResponse {
		switch (action, db, cause) {
			case (.select, nil, nil):									return .ok

			case (.function("substr"), nil, nil):						return .ok
			case (.function("length"), nil, nil):						return .ok
			case (.function("like"), nil, nil):							return .ok

			case (.read("content_blocker", "id"), "main", nil):			return .ok
			case (.read("content_blocker", "source"), "main", nil):		return .ok
			case (.read("content_blocker", "version"), "main", nil):	return .ok

			case (.read("popular", "domain"), "main", nil):				return .ok
			case (.read("popular", "rank"), "main", nil):				return .ok
			case (.read("popular", "trackers"), "main", nil):			return .ok

			case (.read("private", "domain"), "main", nil):				return .ok

			case (.read("https", "domain"), "main", nil):				return .ok

			case (.read("blogspot", "domain"), "main", nil):			return .ok

			case (.read("danger", "type"), "main", nil):				return .ok
			case (.read("danger", "domain"), "main", nil):				return .ok

			case (.read("danger_hash", "type"), "main", nil):			return .ok
			case (.read("danger_hash", "hash"), "main", nil):			return .ok

			case (.read("parameter_stripping", "name"), "main", nil):	return .ok
			case (.read("parameter_stripping", "host"), "main", nil):	return .ok
			case (.read("parameter_stripping", "value"), "main", nil):	return .ok

			case (.read("ad", "domain"), "main", nil):					return .ok

			case (.read("tracking", "domain"), "main", nil):					return .ok

			default:													fatalError("unauthorized operation \((action, db, cause))")
		}
	}

	static let dbManager: SQLiteManager = {
		SQLiteManager.freeSQLiteCachesOnMemoryWarning = true
		_ = initSQLite
		var manager = SQLiteManager() { _ in
			let setupOptions = SQLite.SetupOptions.secure.subtracting([.limitLikePatternLength, .limitLength, .limitVariableNumber])
			let updatedDB = SQLCipher(path: DomainList.dbLocation, key: DomainList.dbKey, flags: .readonly, cipherOptions: .compatibility(3), setupOptions: setupOptions)
			try! updatedDB?.execute("PRAGMA query_only=true")
			let result = (try? updatedDB?.execute(dbVerificationQuery, with: BlockerID.checkBlockers.map { .text($0) })) ?? nil
			let tblCnt = result?[0].integer ?? 0
			let blockerCount = result?[1].integer ?? -1
			let ok = tblCnt == 10 && blockerCount == Int64(BlockerID.checkBlockers.count)

			let bundlePath = Bundle.main.path(forResource: "lists", ofType: "db")!
			let options = SQLCipher.CipherOptions.v4Defaults
			let db = ok ? updatedDB! : SQLCipher(path: bundlePath, key: DomainList.dbKey, flags: .readonly, cipherOptions: options, setupOptions: setupOptions)!
			try! db.dropModules()
			try! db.execute("PRAGMA query_only=true")
			try! db.set(authorizer: authorizer)
			return db
		}
		let center = NotificationCenter.default
		let name = DomainList.dbFileChangedNotification
		center.addObserver(forName: name, object: nil, queue: nil) {  _ in
			cbVersionCacheLock.lock()
			DomainList.dbManager.reload()
			cbVersionBackingCache = nil
			cbVersionCacheLock.unlock()
		}
		return manager
	}()

	var db: SQLiteManager {
		return DomainList.dbManager
	}

	private static var listCache: [DomainListType: [String]] = {
		let name = UIApplication.didReceiveMemoryWarningNotification
		let center = NotificationCenter.default
		center.addObserver(forName: name, object: nil, queue: nil, using: { _ in
			DomainList.listCache = [:]
		})
		return [DomainListType: [String]]()
	}()

	init(type: DomainListType) {
		self.type = type
	}

	func contains(_ domain: String) -> Bool {
		if case .dangerHash = type {
			fatalError("cannot search for domains in danger hash list")
		}
		let query = "SELECT EXISTS (SELECT * FROM \(type.table) WHERE domain = ?)"
		let result = try! db.execute(query, with: [.text(domain)])
		return result.first![0]!.boolValue
	}

	func trackerCount(for domain: String) -> Int64 {
		switch type {
			case .nonPrivatePopularSites, .popularSites, .empty: break
			default: fatalError("tracker count is only supported for popularSites, allPopularSites and empty domain list types")
		}
		let components = domain.components(separatedBy: ".")
		var bindings = [SQLite.Data.text("")]
		for i in 0 ..< components.count {
			let suffix = components[i ..< components.count].joined(separator: ".")
			bindings.append(.text(suffix))
		}
		let query = [String](repeating: "(?)", count: bindings.count).joined(separator: ",")
		let result = try! db.execute("SELECT trackers FROM \(type.table) WHERE domain IN (VALUES \(query)) AND trackers IS NOT NULL ORDER BY length(domain) DESC LIMIT 1", with: bindings)
		return result.first?.integerValue! ?? 13
	}

	func search(top: Int64, matching: String) -> [(Int64, String)] {
		switch type {
			case .nonPrivatePopularSites, .popularSites, .empty: break
			default: fatalError("top search is only supported for popularSites, allPopularSites and empty domain list types")
		}
		let plainPattern = matching.backslashEscapeLike + "%"
		let wwwPattern = "www." + plainPattern

		let query = "SELECT rank, domain FROM \(type.table) WHERE domain LIKE ? ESCAPE '\\' OR domain LIKE ? ESCAPE '\\' ORDER BY rank LIMIT ?"
		let bindings: [SQLite.Data] = [.text(plainPattern), .text(wwwPattern), .integer(top)]
		let result = (try? db.execute(query, with: bindings)) ?? []
		return result.map { ($0[0]!.integer!, $0[1]!.text!) }
	}

	func types(forDomain domain: String) -> [Int64] {
		switch type {
			case .danger, .empty: break
			default: fatalError("top search is only supported for danger and empty domain list types")
		}
		let query = "SELECT type FROM \(type.table) WHERE domain = ?"
		let result = try! db.execute(query, with: [.text(domain)])
		return result.map { $0["type"]!.integer! }
	}

	func types(for hashes: Set<Data>) -> [Int64] {
		switch type {
			case .dangerHash, .empty: break
			default: fatalError("top search is only supported for danger and empty domain list types")
		}
		let queryBlobs = hashes.map { SQLite.Data.blob($0) }
		let values = [String](repeating: "(?)", count: queryBlobs.count).joined(separator: ", ")
		let query = "SELECT DISTINCT type FROM \(type.table) WHERE hash IN (VALUES \(values))"
		let result = try! db.execute(query, with: queryBlobs)
		return result.map { $0["type"]!.integer! }
	}

	var domains: [String] {
		if let list = DomainList.listCache[type] {
			return list
		}
		if case .dangerHash = type {
			fatalError("cannot list domains of danger hash list")
		}
		let query = "SELECT domain FROM \(type.table) ORDER BY domain"
		let result = try! db.execute(query)
		let list = result.map { $0[0]!.text! }
		DomainList.listCache[type] = list
		return list
	}

	static func hasContentBlocker(with id: String) -> Bool {
		return cbVersionCache[id] != nil
	}

	static func contentBlockerVersion(for id: String) -> Int64 {
		return cbVersionCache[id]!
	}

	static func contentBlockerSource(for id: String) -> (Int64, String) {
		let result = try! dbManager.execute("SELECT version, source FROM content_blocker WHERE id = ?", with: [.text(id)])
		return (result[0]["version"]!.integer!, result[0]["source"]!.text!)
	}

	static func set(updating: Bool) {
		let oldUpdating = !PolicyManager.globalManager().deleteSiteLists
		guard oldUpdating != updating else {
			return
		}
		Settings.globalSettings().set(SQLite.Data(updating), for: updateSiteListsKey)
		if updating {
			DownloadManager.shared.triggerSiteListsUpdate()
		} else {
			DownloadManager.shared.stopSiteListsUpdate()
			try? FileManager.default.removeItem(atPath: DomainList.dbLocation)
			NotificationCenter.default.post(name: DomainList.dbFileChangedNotification, object: nil)
		}
	}
}

private let dbVerificationQuery = """
SELECT
	value
FROM
	(
			SELECT
				0 AS ord,
				count(*) AS value
			FROM
				sqlite_master
			WHERE
					type = 'table'
				AND
						name
					IN
						(
							'tracking',
							'ad',
							'https',
							'private',
							'popular',
							'blogspot',
							'danger',
							'danger_hash',
							'content_blocker',
							'parameter_stripping'
						)
		UNION ALL
			SELECT
				1,
				(
					SELECT
						COUNT(DISTINCT id)
					FROM
						content_blocker
					WHERE
						id IN (?, ?, ?, ?)
				)
		UNION ALL
			SELECT
				2,
				*
			FROM
				(
					SELECT
						trackers
					FROM
						popular
					LIMIT 0
				)
	)
ORDER BY
	ord
"""
