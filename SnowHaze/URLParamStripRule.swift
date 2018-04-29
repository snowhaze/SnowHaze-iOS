//
//  URLParamStripRule.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private extension URL {
	private static let queryRx = Regex(pattern: "(^[^?]+)(\\?([^#]*))(#.*$|$)")

	var query: String? {
		get {
			if absoluteString.matches(URL.queryRx) {
				return absoluteString.replace(URL.queryRx, template: "$3")
			} else {
				return nil
			}
		}
		set {
			let insert = newValue == nil ? "" : "?" + newValue!
			let escaped = Regex.escapedTemplate(for: insert)
			let template = "$1" + escaped + "$4"
			let original = absoluteString
			let replaced = original.replace(URL.queryRx, template: template)
			self = URL(string: replaced)!
		}
	}

	var queryItems: [(String, String?)]? {
		get {
			return URL.params(from: query)
		}
		set {
			query = URL.query(from: newValue)
		}
	}

	private static func params(from query: String?) -> [(String, String?)]? {
		guard let query = query else {
			return nil
		}
		guard !query.isEmpty else {
			return []
		}
		let components = query.components(separatedBy: "&")
		return components.map { component in
			if let range = component.range(of: "=") {
				let name = component[component.startIndex ..< range.lowerBound]
				let value = component[range.upperBound...]
				return (String(name), String(value))
			} else {
				return (component, nil)
			}
		}
	}

	private static func query(from params: [(String, String?)]?) -> String? {
		guard let params = params else {
			return nil
		}
		let components = params.map { param -> String in
			let (name, value) = param
			if let value = value {
				return name + "=" + value
			} else {
				return String(name)
			}
		}
		return components.joined(separator: "&")
	}
}

public struct URLParamStripRule {
	let matchesSubdomains: Bool
	let host: String?
	let nameRx: String
	let valueRule: String?

	private func host(matches urlHost: String) -> Bool {
		guard let host = host else {
			return true
		}
		if urlHost == host {
			return true
		} else if matchesSubdomains {
			return urlHost.hasSuffix("." + host)
		}
		return false
	}

	private func name(matches paramName: String) -> Bool {
		return paramName.matches(RegexCache.shared.get(for: nameRx))
	}

	private func value(matches paramValue: String?) -> Bool {
		return valueRule == nil
	}

	func applies(to item: URLQueryItem, on urlHost: String) -> Bool {
		return host(matches: urlHost) && name(matches: item.name) && value(matches: item.value)
	}

	func applies(to item: URLQueryItem) -> Bool {
		return applies(to: (item.name, item.value))
	}

	func applies(to param: (name: String, value: String?)) -> Bool {
		return name(matches: param.name) && value(matches: param.value)
	}

	init(hostRule: String?, nameRx: String, valueRule: String?) {
		self.nameRx = nameRx
		self.valueRule = valueRule
		if let hostRule = hostRule {
			matchesSubdomains = hostRule.hasPrefix("*")
			if matchesSubdomains {
				host = String(hostRule.dropFirst())
			} else {
				host = hostRule
			}
		} else {
			host = nil
			matchesSubdomains = true
		}
	}

	init?(row: SQLite.Row) {
		guard let hostRule = row["host"]?.textValue else {
			return nil
		}
		guard let nameRx = row["name"]?.textValue else {
			return nil
		}
		guard let valueRule = row["value"]?.textValue else {
			return nil
		}
		self.init(hostRule: hostRule, nameRx: nameRx, valueRule: valueRule)
	}

	init?(reducedRow row: SQLite.Row) {
		guard let nameRx = row["name"]?.textValue else {
			return nil
		}
		guard let valueRow = row["value"] else {
			return nil
		}
		let valueRule = valueRow.textValue
		self.init(hostRule: nil, nameRx: nameRx, valueRule: valueRule)
	}

	static func changedURL(for url: URL, from db: SQLiteManager, table: String) -> (url: URL, stripped: [(name: String, value: String?)]) {
		guard var allParams = url.queryItems else {
			return (url, [])
		}
		var indexes = [Int]()
		var stripped = [(String, String?)]()
		let rules = getRules(for: url.host, from: db, table: table)
		for (i, param) in allParams.enumerated() {
			for rule in rules {
				if rule.applies(to: param) {
					indexes.append(i)
					stripped.append((param.0, param.1))
					break
				}
			}
		}
		for i in indexes.reversed() {
			allParams.remove(at: i)
		}
		var url = url
		url.queryItems = allParams
		return (url, stripped)
	}

	private static func checkDomainsData(for host: String) -> [SQLite.Data] {
		var ret = [SQLite.Data.text(host)]
		let comps = host.components(separatedBy: ".")
		for i in 0 ... comps.count {
			let used = comps[i ..< comps.count]
			let domain = used.joined(separator: ".")
			ret.append(.text("*" + domain))
		}
		return ret
	}

	private static func getRules(for host: String?, from db: SQLiteManager, table: String) -> [URLParamStripRule] {
		guard let host = host else {
			return []
		}
		let data = checkDomainsData(for: host)
		let array = [String](repeating: "(?)", count: data.count)
		let query = array.joined(separator: ",")
		guard let result = try? db.execute("SELECT name, value FROM \(table.sqliteEscapedIdentifier) WHERE host IN (VALUES \(query)) AND value IS NULL", with: data) else {
			return []
		}
		return result.compactMap { URLParamStripRule(reducedRow: $0) }
	}
}
