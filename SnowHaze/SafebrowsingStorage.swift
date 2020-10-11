//
//  SafebrowsingStorage.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

class EphemeralSafebrowsingStorage: SafebrowsingCache, SafebrowsingStorage {
	func lists(for hashes: Set<Data>, filler: Int) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List: (String, Set<Data>)])? {
		return lists(for: hashes, filler: filler, lookup: lookup)
	}
}

class DummySafebrowsingStorage: SafebrowsingStorage {
	func register(wait: Bool, updatedCallback: @escaping (Bool) -> ()) -> ((Bool) -> ())? {
		updatedCallback(true)
		return nil
	}

	func lists(for hashes: Set<Data>, filler: Int) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List : (String, Set<Data>)])? {
		return ([], [:])
	}

	func set(_ results: [Safebrowsing.List: (String, [Data: Set<Data>]?)]) { }

	var listsForUpdate: [Safebrowsing.List : String?] {
		return [:]
	}

	func update(_ lists: [Safebrowsing.List : (String, Set<Data>, Set<Int>?)], oldVersions: [Safebrowsing.List : String?]) { }

	func lastFullUpdate(for lists: Set<Safebrowsing.List>) -> Date? {
		return nil
	}

	func lastFullPrefixUpdate(for lists: Set<Safebrowsing.List>) -> Date? {
		return nil
	}

	func clear() { }
}

class PrefixCachingSafebrowsingStorage: SafebrowsingStorage {
	private var lists = [Safebrowsing.List: (String, [Data: Set<Data>])]()
	private let internalQueue = DispatchQueue(label: "ch.illotros.safebrowsing.storage.prefix-caching.internal")

	func register(wait: Bool, updatedCallback: @escaping (Bool) -> ()) -> ((Bool) -> ())? {
		return SafebrowsingCache.shared.register(wait: wait, updatedCallback: updatedCallback)
	}

	func lists(for hashes: Set<Data>, filler: Int) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List: (String, Set<Data>)])? {
		return SafebrowsingCache.shared.lists(for: hashes, filler: filler) { (list, version, prefix, hash) -> Bool? in
			return internalQueue.sync { () -> Bool? in
				guard let listData = lists[list], listData.0 == version else {
					return nil
				}
				return listData.1[prefix]?.contains(hash)
			}
		}
	}

	func set(_ results: [Safebrowsing.List: (String, [Data: Set<Data>]?)]) {
		internalQueue.sync {
			for (list, (version, responses)) in results {
				if version == lists[list]?.0 ?? version, let responses = responses {
					for (prefix, hashes) in responses {
						lists[list, default: (version, [:])].1[prefix] = hashes
					}
				}
			}
		}
	}

	var listsForUpdate: [Safebrowsing.List: String?] {
		return SafebrowsingCache.shared.listsForUpdate
	}

	func update(_ listUpdates: [Safebrowsing.List: (String, Set<Data>, Set<Int>?)], oldVersions: [Safebrowsing.List: String?]) {
		internalQueue.sync {
			for (list, _) in listUpdates {
				lists[list] = nil
			}
		}
		SafebrowsingCache.shared.update(listUpdates, oldVersions: oldVersions)
	}

	func lastFullPrefixUpdate(for lists: Set<Safebrowsing.List>) -> Date? {
		return SafebrowsingCache.shared.lastFullPrefixUpdate(for: lists)
	}

	func clear() {
		internalQueue.sync { lists = [:] }
		SafebrowsingCache.shared.clear()
	}
}

class CachingSafebrowsingStorage: SafebrowsingStorage {
	func register(wait: Bool, updatedCallback: @escaping (Bool) -> ()) -> ((Bool) -> ())? {
		return SafebrowsingCache.shared.register(wait: wait, updatedCallback: updatedCallback)
	}

	func lists(for hashes: Set<Data>, filler: Int) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List : (String, Set<Data>)])? {
		return SafebrowsingCache.shared.lists(for: hashes, filler: filler, lookup: SafebrowsingCache.shared.lookup)
	}

	func set(_ results: [Safebrowsing.List: (String, [Data: Set<Data>]?)]) {
		SafebrowsingCache.shared.set(results)
	}

	var listsForUpdate: [Safebrowsing.List : String?] {
		return SafebrowsingCache.shared.listsForUpdate
	}

	func update(_ listUpdates: [Safebrowsing.List : (String, Set<Data>, Set<Int>?)], oldVersions: [Safebrowsing.List : String?]) {
		SafebrowsingCache.shared.update(listUpdates, oldVersions: oldVersions)
	}

	func lastFullPrefixUpdate(for lists: Set<Safebrowsing.List>) -> Date? {
		return SafebrowsingCache.shared.lastFullPrefixUpdate(for: lists)
	}

	func clear() {
		SafebrowsingCache.shared.clear()
	}
}
