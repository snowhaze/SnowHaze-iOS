//
//  DomainList.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CommonCrypto

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
		let _ = initSQLite
		var manager = SQLiteManager() { _ in
			let setupOptions = SQLite.SetupOptions.secure.subtracting([.limitLikePatternLength, .limitLength, .limitVariableNumber])
			let updatedDB = SQLCipher(path: DomainList.dbLocation, key: DomainList.dbKey, flags: .readonly, cipherOptions: .compatibility(3), setupOptions: setupOptions)
			try! updatedDB?.execute("PRAGMA query_only=true")
			let result = (try? updatedDB?.execute(dbVerificationQuery, with: [.text(BlockerID.adBlocker1), .text(BlockerID.hstsPreloadUpgrader1)])) ?? nil
			let tblCnt = result?[0].integer ?? 0
			let clOK1 = result?[1].boolValue ?? false
			let clOK2 = result?[2].boolValue ?? false
			let ok = tblCnt == 10 && clOK1 && clOK2

			let bundlePath = Bundle.main.path(forResource: "lists", ofType: "db")!
			let options = SQLCipher.CipherOptions.v4Defaults
			let db = ok ? updatedDB! : SQLCipher(path: bundlePath, key: DomainList.dbKey, flags: .readonly, cipherOptions: options, setupOptions: setupOptions)!
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
		return result.first?.integerValue! ?? 17
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

	private func sha256(_ string: String) -> SQLite.Data {
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
		let data = string.data(using: .utf8)!
		_ = data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG($0.count), &hash) }
		return .blob(Data(hash))
	}

	private let IPv4Rx = Regex(pattern: "^([0-9]+|0[xX][0-9a-fA-F]*)(?:.([0-9]+|0[xX][0-9a-fA-F]*)){0,3}$")
	private let numRx = Regex(pattern: "[0-9]+|0[xX][0-9a-fA-F]*")

	private func parseIP(_ host: String) -> String? {
		if host.matches(IPv4Rx) {
			let components = host.matchData(numRx)
			var num: UInt32 = 0
			var multiplier: UInt32 = 256 * 256 * 256
			for (i, component) in components.enumerated() {
				var compstr = component.match()!
				let radix: Int
				if compstr.hasPrefix("0x") || compstr.hasPrefix("0X") {
					compstr.remove(at: compstr.index(after: compstr.startIndex))
					radix = 16
				} else if compstr.hasPrefix("0") {
					radix = 8
				} else {
					radix = 10
				}
				guard let comp = UInt32(compstr, radix: radix) else {
					return nil
				}
				if i == components.count - 1 {
					multiplier = 1
				} else if comp >= 256 {
					return nil
				}
				let add = multiplier * comp
				multiplier /= 256
				let (newNum, overflow) = num.addingReportingOverflow(add)
				guard !overflow else {
					return nil
				}
				num = newNum
			}
			return "\(num / (256 * 256 * 256)).\((num / (256 * 256)) % 256).\((num / 256) % 256).\(num % 256)"
		} else {
			return nil
		}
	}

	private func canonicalizeHost(_ string: String?) -> String? {
		guard var host = string else {
			return nil
		}
		while host.hasPrefix(".") {
			host = String(host[host.index(after: host.startIndex)...])
		}
		while host.hasSuffix(".") {
			host = String(host[..<host.index(before: host.endIndex)])
		}
		while host.contains("..") {
			host = host.replacingOccurrences(of: "..", with: ".")
		}
		host = parseIP(host) ?? host
		return host.lowercased()
	}

	private func canonicalizePath(_ string: String?, finalSlash: Bool) -> String {
		var path = string ?? "/"
		var reducedComponents = [String]()
		let pathComps = (path as NSString).pathComponents
		for comp in pathComps {
			if "." == comp {
				continue
			} else if ".." == comp {
				if !reducedComponents.isEmpty {
					reducedComponents.removeLast()
				}
			} else {
				reducedComponents.append(comp)
			}
		}
		path = NSString.path(withComponents: reducedComponents)
		if path.isEmpty || reducedComponents.last == "/" {
			path += "/"
		}
		while path.contains("//") {
			path = path.replacingOccurrences(of: "//", with: "/")
		}
		if finalSlash && !path.hasSuffix("/") {
			path += "/"
		}
		return path
	}

	private func unescape(_ string: String?) -> String? {
		guard var string = string else {
			return nil
		}
		var old: String
		repeat {
			old = string
			string = string.replace(rx, template: "%25")
			string = string.removingPercentEncoding ?? old
		} while old != string
		return string
	}

	private let rx = Regex(pattern: "%(?![a-fA-F0-9]{2})")
	private let finalSlashRx = Regex(pattern: "//[^/]+/[^?#]*/(?:$|\\?|#)")
	private let fragRx = Regex(pattern: "#.*")

	private func canonicalize(_ paramURL: URL) -> (String, String, String?) {
		var url = paramURL.absoluteString.replacingOccurrences(of: "\t", with: "")
		url = url.replacingOccurrences(of: "\n", with: "")
		url = url.replacingOccurrences(of: "\r", with: "")
		url = url.replace(fragRx, template: "")
		url = url.replace(rx, template: "%25")
		guard let realURL = URL(string: url) else {
			return ("", "", nil)
		}
		guard var host = canonicalizeHost(unescape(realURL.host)) else {
			return ("", "", nil)
		}
		var path = canonicalizePath(unescape(realURL.path), finalSlash: url.matches(finalSlashRx))
		if path.isEmpty {
			path = "/"
		}
		var query = realURL.query
		let allowedChars = CharacterSet.safebrowsingAllowedCharacters
		host = host.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? host
		path = path.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? path
		query = query?.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? query
		return (host, path, query)
	}

	private func hostQueries(_ host: String) -> [String] {
		var result = [host]
		if let _ = parseIP(host) {
			return result
		}
		let components = host.components(separatedBy: ".")
		for i in 2 ... 5 {
			if components.count > i {
				let comps = components[components.count - i ... components.count - 1]
				let domain = comps.joined(separator: ".")
				result.append(domain)
			}
		}
		return result
	}

	private func pathQueries(_ path: String, query: String?) -> [String] {
		var result = [path]
		if let query = query {
			result.append(path + "?" + query)
		}
		let components = (path as NSString).pathComponents.filter { $0 != "/" }
		for i in 0 ... 3 {
			if components.count > i {
				let comps = Array(components[0 ..< i])
				var path = "/" + NSString.path(withComponents: comps)
				if !path.hasSuffix("/") {
					path += "/"
				}
				result.append(path)
			}
		}
		return result
	}

	private func hashQueries(for url: URL) -> [SQLite.Data] {
		let (host, path, query) = canonicalize(url)
		let hosts = hostQueries(host)
		let paths = pathQueries(path, query: query)
		var hashes: [SQLite.Data] = []
		for host in hosts {
			for path in paths {
				hashes.append(sha256(host + path))
			}
		}
		return hashes
	}

	func types(forURL url: URL) -> [Int64] {
		switch type {
			case .dangerHash, .empty: break
			default: fatalError("top search is only supported for danger and empty domain list types")
		}
		let queryBlobs = hashQueries(for: url)
		let values = Array<String>(repeating: "(?)", count: queryBlobs.count).joined(separator: ", ")
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
				EXISTS
					(
						SELECT
							*
						FROM
							content_blocker
						WHERE
							id = ?
					)
		UNION ALL
			SELECT
				2,
				EXISTS
					(
						SELECT
							*
						FROM
							content_blocker
						WHERE
							id = ?
					)
		UNION ALL
			SELECT
				3,
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
