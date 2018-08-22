//
//  DomainList.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum DomainListType {
	case trackingScripts
	case ads
	case httpsSites
	case privateSites			// does not contain www. prefixes (as a optimization)
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

	static let dbLocation: String = {
		let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
		return (cachePath.first! as NSString).appendingPathComponent("lists.db")
	}()

	static let dbKey = Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")!

	static let dbManager: SQLiteManager = {
		SQLiteManager.freeSQLiteCachesOnMemoryWarning = true
		var manager = SQLiteManager() { _ in
			let updatedDB = SQLCipher(path: DomainList.dbLocation, key: DomainList.dbKey, flags: .readonly)
			let query = "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name IN " +
				"(VALUES ('tracking'), ('ad'), ('https'), ('private'), ('popular'), ('blogspot'), ('danger'), ('danger_hash'), ('content_blocker'), ('parameter_stripping'))"
			let tblCnt = try? updatedDB?.execute(query)[0].integer ?? 0
			let clQuery = "SELECT EXISTS (SELECT * FROM content_blocker WHERE id = ?)"
			let clOK = try? updatedDB?.execute(clQuery, with: [.text(BlockerID.adBlocker1)])[0].boolValue ?? false
			let hasTrackerCount: Bool
			if let _ = try? updatedDB?.execute("SELECT trackers FROM popular LIMIT 0") {
				hasTrackerCount = true
			} else {
				hasTrackerCount = false
			}
			let ok = ((tblCnt ?? 0) == 10) && (clOK ?? false) && hasTrackerCount
			let bundlePath = Bundle.main.path(forResource: "lists", ofType: "db")!
			let db = ok ? updatedDB! : SQLCipher(path: bundlePath, key: DomainList.dbKey, flags: .readonly)!
			try! db.execute("PRAGMA query_only=true")
			return db
		}
		let center = NotificationCenter.default
		let name = DomainList.dbFileChangedNotification
		center.addObserver(forName: name, object: nil, queue: nil) {  _ in
			DomainList.dbManager.reload()
		}
		return manager
	}()

	var db: SQLiteManager {
		return DomainList.dbManager
	}

	private static var listCache: [DomainListType: [String]] = {
		let name = Notification.Name.UIApplicationDidReceiveMemoryWarning
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
		return result.first?.integerValue! ?? 20
	}

	func search(top: Int64, matching: String) -> [(Int64, String)] {
		switch type {
			case .nonPrivatePopularSites, .popularSites, .empty: break
			default: fatalError("top search is only supported for popularSites, allPopularSites and empty domain list types")
		}
		let plainPattern = matching.backslashEscapeLike + "%"
		let wwwPattern = "www." + plainPattern

		// TODO: properly handle \, _ and % in domains (currently only found _ in relevant domains)
		// using escaped like completly destroys performance before SQLite v3.21. SQLCipher currently uses v3.20.
		let query = "SELECT rank, domain FROM \(type.table) WHERE domain LIKE ? OR domain LIKE ? ORDER BY rank LIMIT ?"
		let bindings: [SQLite.Data] = [.text(plainPattern), .text(wwwPattern), .integer(top)]
		let result = try! db.execute(query, with: bindings)
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
		data.withUnsafeBytes {
			_ = CC_SHA256($0, CC_LONG(data.count), &hash)
		}
		return .blob(Data(bytes: hash))
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
		let result = try! dbManager.execute("SELECT EXISTS (SELECT * FROM content_blocker WHERE id = ?) AS list_exists", with: [.text(id)])
		return result[0]["list_exists"]!.boolValue
	}

	static func contentBlockerVersion(for id: String) -> Int64 {
		let result = try! dbManager.execute("SELECT version FROM content_blocker WHERE id = ?", with: [.text(id)])
		return result[0]["version"]!.integer!
	}

	static func contentBlockerSource(for id: String) -> (Int64, String) {
		let result = try! dbManager.execute("SELECT version, source FROM content_blocker WHERE id = ?", with: [.text(id)])
		return (result[0]["version"]!.integer!, result[0]["source"]!.text!)
	}
}
