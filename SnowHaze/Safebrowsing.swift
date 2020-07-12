//
//  Safebrowsing.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import CommonCrypto

enum SafebrowsingCacheSharing: Int64 {
	case none = 0
	case prefix = 1
	case all = 2

	var name: String {
		switch self {
			case .none:		return NSLocalizedString("safebrowsing cache sharing setting none option", comment: "option to not share the cache of the safebrowsing cache sharing setting")
			case .prefix:	return NSLocalizedString("safebrowsing cache sharing setting prefix option", comment: "option to share prefixes the cache of the safebrowsing cache sharing setting")
			case .all:		return NSLocalizedString("safebrowsing cache sharing setting all option", comment: "option to share the full cache of the safebrowsing cache sharing setting")
		}
	}
}

protocol SafebrowsingStorage {
	func register(wait: Bool, updatedCallback: @escaping (Bool) -> Void) -> ((Bool) -> Void)?
	func lists(for hashes: Set<Data>, filler: Int) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List: (String, Set<Data>)])?
	func set(_ results: [Safebrowsing.List: (String, [Data: Set<Data>]?)])

	var listsForUpdate: [Safebrowsing.List: String?] { get }
	func update(_ lists: [Safebrowsing.List: (String, Set<Data>, Set<Int>?)], oldVersions: [Safebrowsing.List: String?])

	func lastFullPrefixUpdate(for lists: Set<Safebrowsing.List>) -> Date?
	func clear()
}

protocol SafebrowsingNetworking {
	func verify(_ requests: [Safebrowsing.List: (String, Set<Data>)], callback: @escaping ([Safebrowsing.List: (String, [Data: Set<Data>]?)]) -> Void)
	func update(_ list: [Safebrowsing.List: String?], callback: @escaping ([Safebrowsing.List: (String, Set<Data>, Set<Int>?)]?) -> Void)

	var shouldTry: Bool { get }
}

struct Safebrowsing {
	enum Danger: Int64 {
		case fingerprinting		= -4
		case noSubscription		= -3
		case offlineOnly		= -2
		case networkIssue		= -1
		case unspecified		= 0
		case malicious			= 1
		case phish				= 2
		case phishGoogle		= 3
		case malware			= 4
		case harmfulApplication	= 5
		case unwantedSoftware	= 6

		var isError: Bool {
			switch self {
				case .noSubscription:	return true
				case .networkIssue:		return true
				default:				return false
			}
		}

		var incompleteInformation: Bool {
			switch self {
				case .noSubscription:	return true
				case .networkIssue:		return true
				case .unspecified:		return true
				case .fingerprinting:	return true
				default:				return false
			}
		}

		var order: Int {
			switch self {
				case .noSubscription:		return 2
				case .offlineOnly:			return 2
				case .networkIssue:			return 2
				case .unspecified:			return 1
				case .malicious:			return 0
				case .phish:				return 0
				case .phishGoogle:			return 0
				case .malware:				return 0
				case .harmfulApplication:	return 0
				case .unwantedSoftware:		return 0
				case .fingerprinting:		return -1
			}
		}

		var hasSafebrowsingSource: Bool {
			switch self {
				case .noSubscription:		return false
				case .offlineOnly:			return false
				case .networkIssue:			return false
				case .unspecified:			return false
				case .malicious:			return false
				case .phish:				return false
				case .fingerprinting:		return false
				case .phishGoogle:			return true
				case .malware:				return true
				case .harmfulApplication:	return true
				case .unwantedSoftware:		return true
			}
		}
	}

	enum List: Int64 {
		static let all: Set<List> = [.malwareAny, .socialEngineeringAny, .potentiallyHarmfulApplicationsIos, .unwantedSoftwareAny]
		case malwareAny
		case socialEngineeringAny
		case potentiallyHarmfulApplicationsIos
		case unwantedSoftwareAny

		var danger: Danger {
			switch self {
				case .malwareAny:							return .malware
				case .socialEngineeringAny:					return .phishGoogle
				case .potentiallyHarmfulApplicationsIos:	return .harmfulApplication
				case .unwantedSoftwareAny:					return .unwantedSoftware
			}
		}

		var threat: String {
			switch self {
				case .malwareAny:							return "MALWARE"
				case .socialEngineeringAny:					return "SOCIAL_ENGINEERING"
				case .potentiallyHarmfulApplicationsIos:	return "POTENTIALLY_HARMFUL_APPLICATION"
				case .unwantedSoftwareAny:					return "UNWANTED_SOFTWARE"
			}
		}

		var platform: String {
			switch self {
				case .malwareAny, .socialEngineeringAny, .unwantedSoftwareAny:
					return "ANY_PLATFORM"
				case .potentiallyHarmfulApplicationsIos:
					return "IOS"
			}
		}
	}

	static let hashLength = Int(CC_SHA256_DIGEST_LENGTH)

	private let networking: SafebrowsingNetworking
	private let storage: SafebrowsingStorage
	private let checkLocal: Bool
	private let softFail: Bool
	private let hasSubscription: Bool

	init(network: SafebrowsingNetworking, storage: SafebrowsingStorage, local: Bool, softFail: Bool, hasSubscription: Bool) {
		self.networking = network
		self.storage = storage
		self.checkLocal = local
		self.softFail = softFail
		self.hasSubscription = hasSubscription
	}

	var lastFullPrefixUpdate: Date? {
		return storage.lastFullPrefixUpdate(for: List.all)
	}

	func clearStorage() {
		storage.clear()
	}

	func updatePrefixes(callback: @escaping (Bool?) -> Void) {
		var updated = false
		withUsableCache(wait: true) { callback(updated ? $0 : nil) }
		updated = true
	}

	private func withUsableCache(wait: Bool = false, callback: @escaping (Bool) -> Void) {
		let completion = storage.register(wait: wait, updatedCallback: callback)
		if let completion = completion {
			let storedVersions = storage.listsForUpdate
			networking.update(storedVersions) { data in
				if let lists = data {
					self.storage.update(lists, oldVersions: storedVersions)
					completion(true)
				} else {
					completion(false)
				}
			}
		}
	}

	func types(for url: URL, callback: @escaping (Set<Safebrowsing.Danger>) -> Void) {
		let hashes = hashQueries(for: url)
		var dangerTypes = Set<Safebrowsing.Danger>()
		if checkLocal {
			if let domain = url.host {
				let types = DomainList(type: .danger).types(forDomain: domain)
				dangerTypes.formUnion(types.compactMap { Danger(rawValue: $0) })
			}
			let types = DomainList(type: .dangerHash).types(for: hashes)
			dangerTypes.formUnion(types.compactMap { Danger(rawValue: $0) })
		}
		guard networking.shouldTry else {
			callback(dangerTypes)
			return
		}
		if !dangerTypes.isEmpty {
			dangerTypes.insert(.offlineOnly)
			callback(dangerTypes)
			return
		}
		guard self.hasSubscription else {
			dangerTypes.insert(.noSubscription)
			callback(dangerTypes)
			return
		}
		withUsableCache { success in
			if !success && !self.softFail {
				dangerTypes.insert(.networkIssue)
			}
			guard let (certain, requests) = self.storage.lists(for: hashes, filler: 50) else {
				dangerTypes.insert(.fingerprinting)
				DispatchQueue.main.async { callback(dangerTypes) }
				return
			}
			dangerTypes.formUnion(certain.map { $0.danger })
			if !requests.isEmpty {
				self.networking.verify(requests) { results in
					self.storage.set(results)
					for (id, (_, blockData)) in results {
						if let blockData = blockData {
							for (_, resultHashes) in blockData {
								if !resultHashes.intersection(hashes).isEmpty {
									dangerTypes.insert(id.danger)
									break
								}
							}
						} else if !self.softFail {
						   dangerTypes.insert(.networkIssue)
					   }
					}
					DispatchQueue.main.async { callback(dangerTypes) }
				}
			} else {
				DispatchQueue.main.async { callback(dangerTypes) }
			}
		}
	}
}

/// MARK: hashes
private extension Safebrowsing {
	static let fragRx = Regex(pattern: "#.*")
	static let IPv4Rx = Regex(pattern: "^([0-9]+|0[xX][0-9a-fA-F]*)(?:.([0-9]+|0[xX][0-9a-fA-F]*)){0,3}$")
	static let numRx = Regex(pattern: "[0-9]+|0[xX][0-9a-fA-F]*")
	static let rx = Regex(pattern: "%(?![a-fA-F0-9]{2})")
	static let finalSlashRx = Regex(pattern: "//[^/]+/[^?#]*/(?:$|\\?|#)")

	func parseIP(_ host: String) -> String? {
		if host.matches(Safebrowsing.IPv4Rx) {
			let components = host.matchData(Safebrowsing.numRx)
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

	func canonicalizeHost(_ string: String?) -> String? {
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

	func canonicalizePath(_ string: String?, finalSlash: Bool) -> String {
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

	func unescape(_ string: String?) -> String? {
		guard var string = string else {
			return nil
		}
		var old: String
		repeat {
			old = string
			string = string.replace(Safebrowsing.rx, template: "%25")
			string = string.removingPercentEncoding ?? old
		} while old != string
		return string
	}

	func canonicalize(_ paramURL: URL) -> (String, String, String?) {
		var url = paramURL.absoluteString.replacingOccurrences(of: "\t", with: "")
		url = url.replacingOccurrences(of: "\n", with: "")
		url = url.replacingOccurrences(of: "\r", with: "")
		url = url.replace(Safebrowsing.fragRx, template: "")
		url = url.replace(Safebrowsing.rx, template: "%25")
		guard let realURL = URL(string: url) else {
			return ("", "", nil)
		}
		guard var host = canonicalizeHost(unescape(realURL.host)) else {
			return ("", "", nil)
		}
		var path = canonicalizePath(unescape(realURL.path), finalSlash: url.matches(Safebrowsing.finalSlashRx))
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

	private func sha256(_ string: String) -> Data {
		var hash = [UInt8](repeating: 0,  count: Safebrowsing.hashLength)
		let data = string.data(using: .utf8)!
		_ = data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG($0.count), &hash) }
		return Data(hash)
	}

	func hashQueries(for url: URL) -> Set<Data> {
		let (host, path, query) = canonicalize(url)
		let hosts = hostQueries(host)
		let paths = pathQueries(path, query: query)
		var hashes = Set<Data>()
		for host in hosts {
			for path in paths {
				hashes.insert(sha256(host + path))
			}
		}
		return hashes
	}
}
