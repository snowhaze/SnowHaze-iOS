//
//  SafebrowsingCache.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

private struct Migrator: SQLiteMigrator {
	func sqliteManager(_ manager: SQLiteManager, makeV1SetupForDatabase database: String, of connection: SQLite) throws {
		try connection.execute("PRAGMA auto_vacuum = FULL")
		try connection.execute("PRAGMA journal_mode = DELETE")

		try connection.execute("CREATE TABLE lists (id INTEGER PRIMARY KEY, version TEXT, last_update INTEGER, CHECK ((version IS NULL) = (last_update IS NULL)))")
		for list in Safebrowsing.List.all {
			try connection.execute("INSERT INTO lists (id, version, last_update) VALUES (?, NULL, NULL)", with: [.integer(list.rawValue)])
		}
		try connection.execute("CREATE TABLE prefix_groups (list INTEGER NOT NULL REFERENCES lists ON UPDATE RESTRICT ON DELETE CASCADE, group_nr INTEGER NOT NULL, count INTEGER NOT NULL, size INTEGER NOT NULL, prefixes BLOB NOT NULL, PRIMARY KEY (list, group_nr), CHECK (length(prefixes) = size * count)) WITHOUT ROWID")
		try connection.execute("CREATE TABLE hash_groups (list INTEGER NOT NULL REFERENCES lists ON UPDATE RESTRICT ON DELETE CASCADE, prefix BLOB NOT NULL, hashes BLOB NOT NULL, PRIMARY KEY (list, prefix), CHECK (length(hashes) % 32 = 0)) WITHOUT ROWID")
	}
}

private extension Data {
	func binarySearchPosition(needle: Data, size: Int) -> Int {
		if self.isEmpty {
			return 0
		}
		var min = 0;
		var max = count - 1;
		while min < max {
			let test = (min + max) / 2;
			let cmp = self.extract(test, size: size)
			if cmp == needle {
				return test
			} else if cmp.lexicographicallyPrecedes(needle) {
				min = test + 1
			} else {
				max = test - 1
			}
		}
		if min < count && self.extract(min, size: size).lexicographicallyPrecedes(needle) {
			return min + 1
		} else {
			return  min
		}
	}

	func extract(_ i: Int, size: Int) -> Data {
		assert(count % size == 0)
		return self[i * size ..< (i + 1) * size]
	}
}

private let safebrowsingDB: SQLiteManager = {
	let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
	let dbLocation = (cachePath.first! as NSString).appendingPathComponent("safebrowsing.db")

	struct StaticData {
		static var setupComplete = false
	}

	func authorizer(_ action: SQLite.AuthorizerAction, _ db: String?, _ cause: String?) -> SQLite.AuthorizerResponse {
		if StaticData.setupComplete {
			switch (action, db, cause) {
				case (.transaction("BEGIN"), nil, nil):						return .ok
				case (.transaction("COMMIT"), nil, nil):					return .ok

				case (.select, nil, nil):									return .ok
				case (.read("lists", "id"), "main", nil):					return .ok
				case (.read("lists", "version"), "main", nil):				return .ok
				case (.read("lists", "last_update"), "main", nil):			return .ok
				case (.update("lists", "version"), "main", nil):			return .ok
				case (.update("lists", "last_update"), "main", nil):		return .ok

				case (.insert("prefix_groups"), "main", nil):				return .ok
				case (.delete("prefix_groups"), "main", nil):				return .ok
				case (.read("prefix_groups", "list"), "main", nil):			return .ok
				case (.read("prefix_groups", "size"), "main", nil):			return .ok
				case (.read("prefix_groups", "count"), "main", nil):		return .ok
				case (.read("prefix_groups", "prefixes"), "main", nil):		return .ok
				case (.read("prefix_groups", "group_nr"), "main", nil):		return .ok
				case (.update("prefix_groups", "count"), "main", nil):		return .ok
				case (.update("prefix_groups", "prefixes"), "main", nil):	return .ok
				case (.update("prefix_groups", "group_nr"), "main", nil):	return .ok

				case (.delete("hash_groups"), "main", nil):					return .ok
				case (.insert("hash_groups"), "main", nil):					return .ok
				case (.read("hash_groups", "list"), "main", nil):			return .ok
				case (.read("hash_groups", "hashes"), "main", nil):			return .ok
				case (.read("hash_groups", "prefix"), "main", nil):			return .ok
				default:	fatalError("unauthorized operation \((action, db, cause))")
			}
		} else {
			switch (action, db, cause) {
				case (.transaction("BEGIN"), nil, nil):													return .ok
				case (.transaction("COMMIT"), nil, nil):												return .ok

				case (.function("length"), nil, nil):													return .ok

				case (.pragma("user_version", nil), "main", nil):										return .ok
				case (.pragma("user_version", "1"), "main", nil):										return .ok
				case (.pragma("auto_vacuum", "FULL"), nil, nil):										return .ok
				case (.pragma("journal_mode", "DELETE"), nil, nil):										return .ok

				case (.insert("sqlite_master"), "main", nil):											return .ok
				case (.read("sqlite_master", "ROWID"), "main", nil):									return .ok
				case (.update("sqlite_master", "sql"), "main", nil):									return .ok
				case (.update("sqlite_master", "type"), "main", nil):									return .ok
				case (.update("sqlite_master", "name"), "main", nil):									return .ok
				case (.update("sqlite_master", "tbl_name"), "main", nil):								return .ok
				case (.update("sqlite_master", "rootpage"), "main", nil):								return .ok

				case (.createTable("lists"), "main", nil):												return .ok
				case (.insert("lists"), "main", nil):													return .ok
				case (.read("lists", "version"), "main", nil):											return .ok
				case (.read("lists", "version"), "main", nil):											return .ok
				case (.read("lists", "last_update"), "main", nil):										return .ok

				case (.createTable("prefix_groups"), "main", nil):										return .ok
				case (.createIndex("prefix_groups", "sqlite_autoindex_prefix_groups_1"), "main", nil):	return .ok
				case (.read("prefix_groups", "list"), "main", nil):										return .ok
				case (.read("prefix_groups", "size"), "main", nil):										return .ok
				case (.read("prefix_groups", "count"), "main", nil):									return .ok
				case (.read("prefix_groups", "prefixes"), "main", nil):									return .ok
				case (.read("prefix_groups", "group_nr"), "main", nil):									return .ok

				case (.createTable("hash_groups"), "main", nil):										return .ok
				case (.createIndex("hash_groups", "sqlite_autoindex_hash_groups_1"), "main", nil):		return .ok
				case (.read("hash_groups", "list"), "main", nil):										return .ok
				case (.read("hash_groups", "prefix"), "main", nil):										return .ok
				case (.read("hash_groups", "hashes"), "main", nil):										return .ok
				default:								fatalError("unauthorized operation: \((action, db, cause))")
			}
		}
	}

	SQLiteManager.freeSQLiteCachesOnMemoryWarning = true
	let _ = initSQLite
	let keyingData = try! KeyManager(name: "safebrowsing.db.key").key()

	let manager = SQLiteManager(setup: { _ in
		let setupOptions = SQLite.SetupOptions.secure
		let connection = SQLCipher(path: dbLocation, key: keyingData, setupOptions: setupOptions)!
		try! connection.dropModules()
		try! connection.execute("PRAGMA secure_delete = on")
		try! connection.execute("PRAGMA foreign_keys = on")
		try! connection.busyTimeout(100)
		try! connection.set(authorizer: authorizer)
		connection.limit(.length, value: 1_000_000_000)
		return connection
	})

	manager.migrator = Migrator()
	try! manager.migrate()

	StaticData.setupComplete = true
	try! manager.connection.set(authorizer: authorizer)

	return manager
}()

class SafebrowsingCache {
	static let shared = SafebrowsingCache(db: safebrowsingDB)
	private let internalQueue = DispatchQueue(label: "ch.illotros.safebrowsing.cache.internal")
	private var lists: [Safebrowsing.List: (String, Date, [(count: Int, size: Int, prefixes: Data)], [Data: Data])]
	private var updateCallbacks: [(Bool) -> Void]? = nil
	private let db: SQLiteManager?

	init(db: SQLiteManager? = nil) {
		self.lists = [Safebrowsing.List: (String, Date, [(Int, Int, Data)], [Data: Data])]()
		self.db = db
		if let db = db {
			let lists = try! db.execute("SELECT id, version, last_update FROM lists WHERE version IS NOT NULL AND last_update IS NOT NULL")
			for listData in lists {
				let id = listData[0]!.integer!
				let version = listData[1]!.text!
				let date = Date(timeIntervalSince1970: TimeInterval(listData[2]!.integer!))
				let prefixGroups = try! db.execute("SELECT size, count, prefixes FROM prefix_groups WHERE list = ? ORDER BY group_nr ASC", with: [listData[0]!])
				let allGroups = prefixGroups.map { prefixGroup -> (Int, Int, Data) in
					let size = prefixGroup[0]!.integer!
					let count = prefixGroup[1]!.integer!
					let prefixes = prefixGroup[2]!.blob!
					return (Int(count), Int(size), prefixes)
				}
				self.lists[Safebrowsing.List(rawValue: id)!] = (version, date, allGroups, [:])
			}
		}
	}

	func register(wait: Bool, updatedCallback: @escaping (Bool) -> Void) -> ((Bool) -> Void)? {
		var usable = true
		var needsUpdate = false
		var updating = false
		internalQueue.sync {
			var missingLists = Safebrowsing.List.all
			for (list, (_, updated, _, _)) in lists {
				if updated.timeIntervalSinceNow < -1 * 60 * 60 {
					needsUpdate = true
				}
				if updated.timeIntervalSinceNow < -4 * 7 * 24 * 60 * 60 {
					usable = false
				}
				missingLists.subtract([list])
			}
			if !missingLists.isEmpty {
				needsUpdate = true
				usable = false
			}
			updating = updateCallbacks != nil
			if !usable || (wait && needsUpdate) {
				updateCallbacks = (updateCallbacks ?? []) + [updatedCallback]
			} else if needsUpdate {
				updateCallbacks = updateCallbacks ?? []
			}
		}
		if usable && !(wait && needsUpdate) {
			updatedCallback(usable)
		}
		if !needsUpdate || updating {
			return nil
		}
		let block = BlockCallGuard()
		return { success in
			block.called()
			let callbacks = self.internalQueue.sync { () -> [(Bool) -> Void] in
				let callbacks = self.updateCallbacks
				self.updateCallbacks = nil
				return callbacks!
			}
			for callback in callbacks {
				callback(success)
			}
		}
	}

	var listsForUpdate: [Safebrowsing.List: String?] {
		var missing = Safebrowsing.List.all
		var updates = [Safebrowsing.List: String?]()
		internalQueue.sync {
			for (id, (version, date, _, _)) in lists {
				missing.remove(id)
				if date.timeIntervalSinceNow < -30 * 60 {
					updates[id] = version
				}
			}
		}
		for id in missing {
			updates[id] = .some(nil)
		}
		return updates
	}

	func lookup(list: Safebrowsing.List, version: String, prefix: Data, hash: Data) -> Bool? {
		let listData = lists[list]!
		assert(listData.0 == version)
		if listData.3[prefix] == nil, let db = db {
			let params = [":list": SQLite.Data.integer(list.rawValue), ":prefix": .blob(prefix)]
			let rows = try! db.execute("SELECT hashes FROM hash_groups WHERE list = :list AND prefix = :prefix", with: params)
			if let row = rows.first {
				var map = listData.3
				map[prefix] = row.blob!
				lists[list] = (listData.0, listData.1, listData.2, map)
			}
		}
		guard let set = lists[list]!.3[prefix] else {
			return nil
		}
		for i in 0 ..< set.count / 32 {
			if set.extract(i, size: 32) == hash {
				return true
			}
		}
		return false
	}

	private func prefixSort(prefix: Data, hash: Data) -> ComparisonResult {
		for (i, b) in prefix.enumerated() {
			if b < hash[i] {
				return .orderedAscending
			} else if b > hash[i] {
				return .orderedDescending
			}
		}
		return .orderedSame
	}

	func lists(for hashes: Set<Data>, filler: Int, lookup: (Safebrowsing.List, String, Data, Data) -> Bool?) -> (certain: Set<Safebrowsing.List>, requests: [Safebrowsing.List: (String, Set<Data>)])? {
		var certain = Set<Safebrowsing.List>()
		var requests = [Safebrowsing.List: (String, Set<Data>)]()
		var fingerprinting = false
		internalQueue.sync {
			lists: for (id, (version, _, prefixGroups, _)) in lists {
				var prefixes = Set<Data>()
				hashes: for hash in hashes {
					var possiblePrefixes = Set<Data>()
					for prefixGroup in prefixGroups {
						var min = 0
						var max = prefixGroup.count - 1
						let size = prefixGroup.size
						while min < max {
							let i = (min + max) / 2
							let prefix = prefixGroup.prefixes.extract(i, size: size)
							switch prefixSort(prefix: prefix, hash: hash) {
								case .orderedAscending:		min = i + 1
								case .orderedDescending:	max = i - 1
								case .orderedSame:			min = i; max = i
							}
						}
						guard min == max else {
							continue
						}
						let prefix = prefixGroup.prefixes.extract(min, size: size)
						guard prefix == hash[..<size] else {
							continue
						}
						switch lookup(id, version, prefix, hash) {
							case .some(true):
								requests[id] = nil
								certain.insert(id)
								continue lists
							case .some(false):
								continue hashes
							case nil:
								possiblePrefixes.insert(prefix)
						}
					}
					prefixes.formUnion(possiblePrefixes)
				}
				if !prefixes.isEmpty {
					let totalLength = prefixes.reduce(0) { $0 + $1.count }
					let maxLength = prefixes.max(by: { $1.count > $0.count })!.count
					if totalLength - maxLength >= 8 {
						fingerprinting = true
						return
					}
					let count = prefixGroups.reduce(0) { $0 + $1.count }
					while prefixes.count < filler && prefixes.count < count {
						var index = (0 ..< count).randomElement()!
						for group in prefixGroups {
							if index < group.count {
								prefixes.insert(group.prefixes.extract(index, size: group.size))
								break
							} else {
								index -= group.count
							}
						}
					}
					requests[id] = (version, prefixes)
				}
			}
		}
		return fingerprinting ? nil : (certain, requests)
	}

	func update(_ listUpdates: [Safebrowsing.List: (String, Set<Data>, Set<Int>?)], oldVersions: [Safebrowsing.List: String?]) {
		let mappedUpdates = listUpdates.mapValues { update -> (String, [Data], [Int]?) in
			return (update.0, update.1.sorted { $0.lexicographicallyPrecedes($1) }, update.2?.sorted())
		}
		internalQueue.sync {
			func performUpdate() {
				let date = Date()
				list: for (list, (version, additions, deletions)) in mappedUpdates {
					let oldVersion = lists[list]?.0
					guard oldVersion == nil || oldVersion != version else {
						if let _ = oldVersion {
							lists[list]!.1 = date
						}
						continue list
					}
					guard oldVersion == oldVersions[list] else {
						continue list
					}
					let rawPrefixGroups = lists[list]?.2 ?? []
					var trackedPrefixGroups = [(changed: Bool, oldIndex: Int?, count: Int, size: Int, prefixes: Data)]()
					for (i, group) in rawPrefixGroups.enumerated() {
						trackedPrefixGroups.append((false, i, group.count, group.size, group.prefixes))
					}
					if let deletions = deletions {
						guard !trackedPrefixGroups.isEmpty else {
							continue list
						}
						var offset = 0
						var index = 0
						var lastRemaining: Int? = nil
						deletion: for deletion in deletions {
							for group in trackedPrefixGroups[index...] {
								let offsetDeletion = deletion - offset
								guard offsetDeletion < group.count else {
									if group.count > 0 {
										lastRemaining = index
									}
									index += 1
									offset += group.count
									continue
								}
								let (_, oldIndex, count, size, prefixes) = group
								let newPrefixes = prefixes[0 ..< offsetDeletion * size] + prefixes[(offsetDeletion + 1) * size ..< prefixes.count]
								offset += 1
								trackedPrefixGroups[index] = (true, oldIndex, count - 1, size, newPrefixes)
								if group.count == 1, let previous = lastRemaining, index + 1 < trackedPrefixGroups.count {
									if trackedPrefixGroups[previous].size == trackedPrefixGroups[index + 1].size {
										let prevGroup = trackedPrefixGroups[previous]
										let nextGroup = trackedPrefixGroups[index + 1]
										trackedPrefixGroups[previous] = (true, prevGroup.oldIndex, 0, 0, Data())
										trackedPrefixGroups[index + 1] = (true, nextGroup.oldIndex, prevGroup.count + nextGroup.count, prevGroup.size, prevGroup.prefixes + nextGroup.prefixes)
										lastRemaining = nil
									}
								}
								continue deletion
							}
							continue list
						}

						index = 0
						for addition in additions {
							while true {
								if index == trackedPrefixGroups.count {
									trackedPrefixGroups.append((true, nil, 1, addition.count, addition))
									break
								}
								let group = trackedPrefixGroups[index]
								if group.count == 0 {
									index += 1
									continue
								}
								let first = group.prefixes.extract(group.count - 1, size: group.size)
								if first.lexicographicallyPrecedes(addition) {
									if group.size == addition.count {
										var append = index == trackedPrefixGroups.count - 1
										if !append {
											let nextGroup = trackedPrefixGroups[index + 1]
											let next = nextGroup.prefixes.extract(nextGroup.count - 1, size: nextGroup.size)
											if addition.lexicographicallyPrecedes(next) {
												append = true
											}
										}
										if append {
											trackedPrefixGroups[index].changed = true
											trackedPrefixGroups[index].count += 1
											trackedPrefixGroups[index].prefixes += addition
											break
										}
									}
									index += 1
									continue
								}
								if addition.lexicographicallyPrecedes(first) {
									if group.size == addition.count {
										trackedPrefixGroups[index].changed = true
										trackedPrefixGroups[index].count += 1
										trackedPrefixGroups[index].prefixes = addition + trackedPrefixGroups[index].prefixes
									} else {
										trackedPrefixGroups.insert((true, nil, 1, addition.count, addition), at: index)
									}
									break
								}
								let split = group.prefixes.binarySearchPosition(needle: addition, size: group.size)
								if group.size == addition.count {
									if group.prefixes.extract(split, size: group.size) == addition {
										continue list
									}
									let prefixes = group.prefixes
									let newPrefixes = prefixes[0 ..< split * group.size] + addition + prefixes[split * group.size ..< prefixes.count]
									trackedPrefixGroups[index].changed = true
									trackedPrefixGroups[index].count += 1
									trackedPrefixGroups[index].prefixes = newPrefixes
								} else {
									trackedPrefixGroups[index].changed = true
									trackedPrefixGroups[index].count = split
									trackedPrefixGroups[index].prefixes = group.prefixes[0 ..< split * group.size]
									index += 1
									trackedPrefixGroups.insert((true, nil, 1, addition.count, addition), at: index)
									let prefixes = group.prefixes[split * group.size ..< group.prefixes.count]
									trackedPrefixGroups.insert((true, nil, group.count - split, group.size, prefixes), at: index + 1)
								}
								break
							}
						}
					} else {
						trackedPrefixGroups = trackedPrefixGroups.map { (true, $0.oldIndex, 0, 0, Data()) }

						var start = 0
						for (i, addition) in additions.enumerated() {
							if additions[start].count != addition.count {
								var prefixes = Data()
								prefixes.reserveCapacity(additions[start].count * (i - start))
								for i in start ..< i {
									prefixes += additions[i]
								}
								trackedPrefixGroups.append((true, nil, i - start, additions[start].count, prefixes))
								start = i
							}
						}
						if start < additions.count {
							var prefixes = Data()
							prefixes.reserveCapacity(additions[start].count * (additions.count - start))
							for i in start ..< additions.count {
								prefixes += additions[i]
							}
							trackedPrefixGroups.append((true, nil, additions.count - start, additions[start].count, prefixes))
						}
					}

					assert(trackedPrefixGroups.allSatisfy { $0.size * $0.count == $0.prefixes.count } )
					assert(trackedPrefixGroups.allSatisfy { ($0.size == 0) == ($0.count == 0) } )
					assert(trackedPrefixGroups.allSatisfy { $0.changed || ($0.count != 0) } )

					if let db = db {
						for index in trackedPrefixGroups.compactMap({ $0.count == 0 ? $0.oldIndex : nil }) {
							let delete: [String: SQLite.Data] = [
								":list":	.integer(list.rawValue),
								":index":	.integer(Int64(index)),
							]
							try! db.execute("DELETE FROM prefix_groups WHERE list = :list AND group_nr = :index", with: delete)
						}
						for (index, group) in trackedPrefixGroups.filter({ $0.count != 0 }).enumerated() {
							if let oldIndex = group.oldIndex {
								if group.changed {
									let update: [String: SQLite.Data] = [
										":list":		.integer(list.rawValue),
										":old_index":	.integer(Int64(oldIndex)),
										":new_index":	.integer(index == oldIndex ? Int64(index) : (-1 - Int64(index))),
										":count":		.integer(Int64(group.count)),
										":prefixes":	.blob(group.prefixes),
									]
									try! db.execute("UPDATE prefix_groups SET group_nr = :new_index, count = :count, prefixes = :prefixes WHERE list = :list AND group_nr = :old_index", with: update)
								} else if oldIndex != index {
									let update: [String: SQLite.Data] = [
										":list":		.integer(list.rawValue),
										":old_index":	.integer(Int64(oldIndex)),
										":new_index":	.integer(-1 - Int64(index)),
									]
									try! db.execute("UPDATE prefix_groups SET group_nr = :new_index WHERE list = :list AND group_nr = :old_index", with: update)
								}
							} else {
								let insert: [String: SQLite.Data] = [
									":list":		.integer(list.rawValue),
									":index":		.integer(-1 - Int64(index)),
									":count":		.integer(Int64(group.count)),
									":size":		.integer(Int64(group.size)),
									":prefixes":	.blob(group.prefixes),
								]
								try! db.execute("INSERT INTO prefix_groups (list, group_nr, size, count, prefixes) VALUES (:list, :index, :size, :count, :prefixes)", with: insert)
							}
						}
						try! db.execute("UPDATE prefix_groups SET group_nr = -1 - group_nr WHERE group_nr < 0 AND list = ?", with: [.integer(list.rawValue)])
						try! db.execute("DELETE FROM hash_groups WHERE list = ?", with: [.integer(list.rawValue)])
						let update: [String: SQLite.Data] = [
							":id":		.integer(list.rawValue),
							":version":	.text(version),
							":date":	.integer(Int64(date.timeIntervalSince1970)),
						]
						try! db.execute("UPDATE lists SET version = :version, last_update = :date WHERE id = :id", with: update)
					}
					let finalPrefixGroups = trackedPrefixGroups.compactMap { $0.count == 0 ? nil : ($0.count, $0.size, $0.prefixes) }
					lists[list] = (version, date, finalPrefixGroups, [:])
				}
			}
			if let db = db {
				try! db.inTransaction { performUpdate() }
			} else {
				performUpdate()
			}
		}
	}

	func set(_ results: [Safebrowsing.List: (String, [Data: Set<Data>]?)]) {
		let mappedResults = results.mapValues { old -> (String, [Data: Data]?) in
			let version = old.0
			guard let hashes = old.1 else {
				return (version, nil)
			}
			let mappedHashes = hashes.mapValues { hashes -> Data in
				let sorted = hashes.sorted { $0.lexicographicallyPrecedes($1) }
				return sorted.reduce(Data()) { $0 + $1 }
			}
			return (version, mappedHashes)
		}
		internalQueue.sync {
			func set() {
				for (list, (version, responses)) in mappedResults {
					if version == lists[list]?.0, let responses = responses {
						for (prefix, hashes) in responses {
							if let db = db {
								let insert: [String: SQLite.Data] = [
									":id":		.integer(list.rawValue),
									":prefix":	.blob(prefix),
									":hashes":	.blob(hashes),
								]
								try! db.execute("INSERT OR IGNORE INTO hash_groups (list, prefix, hashes) VALUES (:id, :prefix, :hashes)", with: insert)
							}
							lists[list]!.3[prefix] = hashes
						}
					}
				}
			}
			if let db = db {
				try! db.inTransaction { set() }
			} else {
				set()
			}
		}
	}

	func lastFullPrefixUpdate(for lists: Set<Safebrowsing.List>) -> Date? {
		return internalQueue.sync {
			var oldest: Date? = nil
			for list in lists {
				guard let updated = self.lists[list]?.1 else {
					return nil
				}
				oldest = min(updated, oldest ?? updated)
			}
			return oldest
		}
	}

	func clear() {
		internalQueue.sync {
			lists = [:]
			if let db = db {
				try! db.execute("DELETE FROM prefix_groups")
				try! db.execute("DELETE FROM hash_groups")
				try! db.execute("UPDATE lists SET version = NULL, last_update = NULL")
			}
		}
	}
}
