//
//  SafebrowsingNetworking.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

private let clientID = "SnowHaze"
private let clientVersion = "1"
private let apiKey = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

private func parseUpdateResponse(entries listUpdateResponses: [[String: Any]], for lists: [Safebrowsing.List]) -> [Safebrowsing.List: (String, Set<Data>, Set<Int>?)]? {
	guard listUpdateResponses.count == lists.count else {
		return nil
	}
	let results = lists.concurrentCompactMap { i, list -> (Safebrowsing.List, (String, Set<Data>, Set<Int>?))? in
		let entries = listUpdateResponses[i]
		var allAdditions = Set<Data>()
		var allDeletions: Set<Int>!
		guard let updateType = entries["responseType"] as? String else {
			return nil
		}
		guard entries["threatType"] as? String == list.threat else {
			return nil
		}
		guard entries["platformType"] as? String == list.platform else {
			return nil
		}
		guard entries["threatEntryType"] as? String == "URL" else {
			return nil
		}
		if updateType == "FULL_UPDATE" {
			allDeletions = nil
			guard entries["removals"] == nil else {
				return nil
			}
		} else if updateType == "PARTIAL_UPDATE" {
			allDeletions = Set<Int>()
		} else {
			return nil
		}
		if let additions = entries["additions"] as? [[String:Any]] {
			for additionsDict in additions {
				guard let compression = safebrowsingCompression(for: additionsDict["compressionType"]) else {
					return nil
				}
				guard let newAdditions = compression.decode(additions: additionsDict) else {
					return nil
				}
				allAdditions.formUnion(newAdditions)
			}
		}
		if let deletions = entries["removals"] as? [[String:Any]] {
			guard deletions.count == 1 else {
				return nil
			}
			let deletionsDict = deletions[0]
			guard let compression = safebrowsingCompression(for: deletionsDict["compressionType"]) else {
				return nil
			}
			allDeletions = compression.decode(deletions: deletionsDict)
		}
		guard let state = entries["newClientState"] as? String else {
			return nil
		}
		return (list, (state, allAdditions, allDeletions))
	}
	guard results.count == lists.count else {
		return nil
	}
	return Dictionary(uniqueKeysWithValues: results)
}

struct GoogleSafebrowsingNetworking: SafebrowsingNetworking {
	private enum RequestType: Int {
		case update
		case check
	}
	private struct RequestBucket: Hashable {
		let type: RequestType
		let tabId: Int64?
	}
	private static var nextRequest = [RequestBucket: Date]()
	private static var errorCount = [RequestBucket: Int]()
	private static var internalQueue = DispatchQueue(label: "ch.illotros.safebrowsing.networking.internal.static")

	private var tabId: Int64?

	private let session: URLSession
	private let internalQueue = DispatchQueue(label: "ch.illotros.safebrowsing.networking.google.internal")

	var shouldTry: Bool {
		return true
	}

	init(configuration: URLSessionConfiguration, tab: Tab?) {
		session = URLSession(configuration: configuration)
		tabId = tab?.id
	}

	private static func requestWaitTime(for bucket: RequestBucket) -> TimeInterval {
		return internalQueue.sync { nextRequest[bucket, default: .distantPast].timeIntervalSinceNow }
	}

	private static func stepBackoff(for bucket: RequestBucket) {
		internalQueue.sync {
			let timeout = min(Double(1 << errorCount[bucket, default: 0]) * Double.random(in: 1.0 ... 2.0), 24 * 60 * 60)
			errorCount[bucket, default: 0] += 1
			nextRequest[bucket] = max(Date(timeIntervalSinceNow: timeout), nextRequest[bucket, default: .distantPast])
		}
	}

	private static func resetBackoff(for bucket: RequestBucket) {
		internalQueue.sync {
			errorCount[bucket] = 0
		}
	}

	private static func wait(for timeInterval: TimeInterval, bucket: RequestBucket) {
		internalQueue.sync {
			let duration = timeInterval * Double.random(in: 0.9 ... 1.1)
			nextRequest[bucket] = max(nextRequest[bucket, default: .distantPast], Date(timeIntervalSinceNow: duration))
		}
	}

	func verify(_ requests: [Safebrowsing.List: (String, Set<Data>)], callback: @escaping ([Safebrowsing.List: (String, [Data: Set<Data>]?)]) -> ()) {
		var result = [Safebrowsing.List: (String, [Data: Set<Data>]?)]()
		let internalQueue = self.internalQueue
		for (list, (version, prefixes)) in requests {
			let json: [String: Any] = [
				"client": ["clientId": clientID, "clientVersion":  clientVersion],
				"clientStates": [version],
				"threatInfo": [
					"threatTypes": [list.threat],
					"platformTypes": [list.platform],
					"threatEntryTypes": "URL",
					"threatEntries": prefixes.map { ["hash": $0.base64EncodedString()] }
				]
			]
			let url = URL(string: "https://safebrowsing.googleapis.com/v4/fullHashes:find?key=\(apiKey)")!
			var request = URLRequest(url: url)
			try! request.setJSON(json)
			perform(request, of: .check) { data in
				func parse(_ data: Any?) -> (String, [Data: Set<Data>]?) {
					guard let response = data as? [String: Any] else {
						return (version, nil)
					}
					guard let matches = response["matches"] as? [[String: Any]] else {
						return (version, nil)
					}
					var hashes = Set<Data>()
					for match in matches {
						guard match["threatType"] as? String == list.threat else {
							return (version, nil)
						}
						guard match["platformType"] as? String == list.platform else {
							return (version, nil)
						}
						guard match["threatEntryType"] as? String == "URL" else {
							return (version, nil)
						}
						guard let threat = match["threat"] as? [String: String] else {
							return (version, nil)
						}
						guard let b64 = threat["hash"], let hash = Data(base64Encoded: b64) else {
							return (version, nil)
						}
						hashes.insert(hash)
					}
					var map = [Data: Set<Data>]()
					for prefix in prefixes {
						map[prefix] = Set(hashes.filter { $0[..<prefix.count] == prefix })
					}
					return (version, map)
				}
				let resultItem = parse(data)
				internalQueue.sync {
					result[list] = resultItem
					if result.count == requests.count {
						callback(result)
					}
				}
			}
		}
	}

	func update(_ lists: [Safebrowsing.List: String?], callback: @escaping ([Safebrowsing.List: (String, Set<Data>, Set<Int>?)]?) -> ()) {
		let orderedLists = lists.map { $0.0 }
		let updateRequests: [[String: Any]] = orderedLists.map { list in
			return [
				"threatType": list.threat,
				"platformType":	list.platform,
				"threatEntryType": "URL",
				"state" : lists[list]! ?? "",
				"constraints" : ["supportedCompressions": ["RAW", "RICE"]]
			]
		}
		let json: [String: Any] = [
			"client": ["clientId": clientID, "clientVersion": clientVersion],
			"listUpdateRequests": updateRequests
		]
		let url = URL(string: "https://safebrowsing.googleapis.com/v4/threatListUpdates:fetch?key=\(apiKey)")!
		var request = URLRequest(url: url)
		try! request.setJSON(json)
		perform(request, of: .update) { data in
			guard let response = data as? [String: Any] else {
				callback(nil)
				return
			}
			guard let listUpdateResponses = response["listUpdateResponses"] as? [[String: Any]] else {
				callback(nil)
				return
			}
			guard let results = parseUpdateResponse(entries: listUpdateResponses, for: orderedLists) else {
				callback(nil)
				return
			}
			callback(results)
		}
	}

	private func perform(_ request: URLRequest, of type: RequestType, callback: @escaping (Any?) -> ()) {
		let bucket = RequestBucket(type: type, tabId: tabId)
		guard GoogleSafebrowsingNetworking.requestWaitTime(for: bucket) <= 0 else {
			callback(nil)
			return
		}
		let task = session.dataTask(with: request) { data, response, error in
			guard let response = response as? HTTPURLResponse, let data = data, error == nil else {
				callback(nil)
				return
			}
			guard response.statusCode == 200 else {
				GoogleSafebrowsingNetworking.stepBackoff(for: bucket)
				callback(nil)
				return
			}
			GoogleSafebrowsingNetworking.resetBackoff(for: bucket)
			let json = try? JSONSerialization.jsonObject(with: data)
			if let json = json as? [String: Any], let duration = json["minimumWaitDuration"] as? String {
				guard let secconds = Double(duration.dropLast()) else {
					callback(nil)
					return
				}
				GoogleSafebrowsingNetworking.wait(for: secconds, bucket: bucket)
			}
			callback(json)
		}
		task.resume()
	}
}

struct DummySafebrowsingNetworking: SafebrowsingNetworking {
	var shouldTry: Bool {
		return false
	}

	func verify(_ requests: [Safebrowsing.List : (String, Set<Data>)], callback: @escaping ([Safebrowsing.List : (String, [Data : Set<Data>]?)]) -> ()) {
		callback(requests.mapValues { ($0.0, nil) })
	}

	func update(_ list: [Safebrowsing.List : String?], callback: @escaping ([Safebrowsing.List : (String, Set<Data>, Set<Int>?)]?) -> ()) {
		callback(nil)
	}
}

class ProxySafebrowsingNetworking: SafebrowsingNetworking {
	private var session: URLSession
	private let rotateConfig: URLSessionConfiguration?
	private let internalQueue = DispatchQueue(label: "ch.illotros.safebrowsing.networking.proxy.internal")

	var shouldTry: Bool {
		return true
	}

	init(configuration: URLSessionConfiguration, rotateCredentials: Bool) {
		if #available(iOS 13, *) {
			configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
		} else {
			configuration.tlsMinimumSupportedProtocol = .tlsProtocol13
		}
		session = URLSession(configuration: configuration)
		rotateConfig = rotateCredentials ? configuration : nil
	}

	public func nextSession() -> URLSession {
		if let config = rotateConfig {
			syncToMainThread {
				var proxy = config.connectionProxyDictionary ?? [:]
				proxy[kCFStreamPropertySOCKSUser] = String.secureRandom()
				proxy[kCFStreamPropertySOCKSPassword] = String.secureRandom()
				config.connectionProxyDictionary = proxy
				session = URLSession(configuration: config)
			}
		}
		return session
	}

	private enum APICallType {
		case update(lists: [(list: Safebrowsing.List, oldVersion: String?)])
		case check(list: Safebrowsing.List, version: String, prefixes: Set<Data>)
	}
	private func apiCall(_ type: APICallType, callback: @escaping (Any?) -> ()) {
		SubscriptionManager.shared.tryWithTokens { token, retry in
			guard let token = token else {
				callback(nil)
				return
			}
			var params = ["t": token, "v": "3", "action": "safebrowsing_proxy"]
			switch type {
				case .update(let lists):
					let listRepresentations: [[String: String]] = lists.map { list, oldVersion in
						var representation = ["id": list.threat, "platform": list.platform]
						representation["version"] = oldVersion
						return representation
					}
					let json = try! JSONSerialization.data(withJSONObject: listRepresentations)
					params["lists"] = String(data: json, encoding: .utf8)!
					params["request"] = "update"
				case .check(list: let l, version: let v, prefixes: let p):
					params["version"] = v
					let json = try! JSONSerialization.data(withJSONObject: p.map { $0.base64EncodedString() })
					params["prefixes"] = String(data: json, encoding: .utf8)!
					params["id"] = l.threat
					params["platform"] = l.platform
					params["request"] = "check"
			}
			var request = URLRequest(url: URL(string: "https://api.snowhaze.com/index.php")!)
			request.setFormEncoded(data: params)
			let dec = InUseCounter.network.inc()
			let task = self.nextSession().dataTask(with: request) { data, response, _ in
				dec()
				guard let response = response as? HTTPURLResponse, let data = data else {
					callback(nil)
					return
				}
				if response.statusCode == 429 {
					retry()
					return
				}
				guard response.statusCode == 200 else {
					callback(nil)
					return
				}
				callback(try? JSONSerialization.jsonObject(with: data))
			}
			task.resume()
		}
	}

	func verify(_ requests: [Safebrowsing.List : (String, Set<Data>)], callback: @escaping ([Safebrowsing.List : (String, [Data : Set<Data>]?)]) -> ()) {
		var results = [Safebrowsing.List : (String, [Data : Set<Data>]?)]()
		let internalQueue = self.internalQueue
		for (list, (version, prefixes)) in requests {
			apiCall(.check(list: list, version: version, prefixes: prefixes)) { result in
				func parse(_ result: Any?) -> (String, [Data : Set<Data>]?) {
					guard let result = result as? [String] else {
						return (version, nil)
					}
					let hashes = result.compactMap({ Data(base64Encoded: $0) })
					guard hashes.count == result.count else {
						return (version, nil)
					}
					var map = [Data: Set<Data>]()
					for prefix in prefixes {
						map[prefix] = Set(hashes.filter { $0[..<prefix.count] == prefix })
					}
					return (version, map)
				}
				let resultItem: (String, [Data : Set<Data>]?) = parse(result)
				internalQueue.sync {
					results[list] = resultItem
					if results.count == requests.count {
						callback(results)
					}
				}
			}
		}
	}

	func update(_ lists: [Safebrowsing.List : String?], callback: @escaping ([Safebrowsing.List : (String, Set<Data>, Set<Int>?)]?) -> ()) {
		let listAray = lists.map { ($0, $1) }
		apiCall(.update(lists: listAray)) { result in
			guard let entries = result as? [[String: Any]] else {
				callback(nil)
				return
			}
			guard let results = parseUpdateResponse(entries: entries, for: listAray.map { $0.0 }) else {
				callback(nil)
				return
			}
			callback(results)
		}
	}
}
