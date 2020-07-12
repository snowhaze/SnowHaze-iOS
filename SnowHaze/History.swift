//
//  HistoryStore.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private enum HistoryError: Error {
	case databaseError
}

private let historyKeeparoundTime = 30.0 * 24 * 60 * 60

let HISTORY_SECTION_INDEX = "historySectionIndex"
let HISTORY_ITEM_INDEX = "historyItemIndex"
let INSERT_HISTORY_NOTIFICATION = Notification.Name(rawValue: "insertHistoryNotification")
let DELETE_HISTORY_NOTIFICATION = Notification.Name(rawValue: "deleteHistoryNotification")

class HistoryItem {
	let id: Int64
	let url: URL
	let timestamp: Date
	let title: String

	fileprivate init?(row: SQLite.Row) {
		var failed = false
		let id = row["id"]?.integerValue
		if id == nil {
			failed = true
			self.id = 0
		} else {
			self.id = id!
		}
		let urlString = row["url"]?.text
		let url = urlString != nil ? URL(string: urlString!) : nil
		if url == nil {
			failed = true
			self.url = URL(string: "https://abc.com")!
		} else {
			self.url = url!
		}
		let title = row["title"]?.text
		if title == nil {
			failed = true
			self.title = ""
		} else {
			self.title = title!
		}
		let timestamp = row["timestamp"]?.floatValue
		if timestamp == nil {
			failed = true
			self.timestamp = Date()
		} else {
			self.timestamp = Date(timeIntervalSince1970: timestamp!)
		}
		guard !failed else {
			return nil
		}
	}
}

class HistoryStore {
	private let database: SQLiteManager
	private let tableName: String = HistoryStore.tableName
	static let tableName = "ch_illotros_snowhaze_browsing_history"
	static let ftsName = "ch_illotros_snowhaze_browsing_history_fts"
	static let ftsUpdateName = "ch_illotros_snowhaze_browsing_history_fts_update"
	static let ftsInsertName = "ch_illotros_snowhaze_browsing_history_fts_insert"
	static let ftsDeleteName = "ch_illotros_snowhaze_browsing_history_fts_delete"

	var items: [HistoryItem]? {
		let query = "SELECT * FROM \(tableName) ORDER BY timestamp DESC"
		guard let rows = try? database.execute(query) else {
			return nil
		}
		return try? rows.map() { (row) -> HistoryItem in
			guard let item = HistoryItem(row: row) else {
				throw HistoryError.databaseError
			}
			return item
		}
	}

	var itemsByDate: [[HistoryItem]]? {
		guard let items = items else {
			return nil
		}
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .none
		var ret = [[HistoryItem]]()
		var onDate = [HistoryItem]()
		var lastDate = ""

		for item in items {
			let date = dateFormatter.string(from: item.timestamp)
			if lastDate == "" {
				lastDate = date
			}
			if date == lastDate{
				onDate.append(item)
			} else {
				ret.append(onDate)
				onDate = [HistoryItem]()
				onDate.append(item)
				lastDate = date
			}
		}
		if !onDate.isEmpty {
			ret.append(onDate)
		}
		return ret
	}

	private init?(db: SQLiteManager) {
		database = db
		do {
			try database.execute("DELETE FROM \(tableName) WHERE timestamp < ? - ?", with: [.float(Date().timeIntervalSince1970), .float(historyKeeparoundTime)])
		} catch {
			return nil
		}
	}

	@discardableResult func addItem(title: String, atURL url: URL, atDate date: Date = Date()) -> Bool {
		assert(Thread.isMainThread)
		do {
			let bindings: [SQLite.Data] = [.text(url.absoluteString), .text(title), .float(date.timeIntervalSince1970)]
			let query = "INSERT INTO \(tableName) (url, title, timestamp) VALUES (?, ?, ?)"
			var newId: Int64 = 0
			var items = [[HistoryItem]]()
			try database.execute(query, with: bindings)
			newId = database.lastInsertRowId
			items = itemsByDate ?? [[]]

			for (sectionIndex, section) in items.enumerated() {
				for (itemIndex, item) in section.enumerated() {
					if item.id == newId {
						let index: Int? = section.count == 1 ? nil : itemIndex
						notifyInsert(section: sectionIndex, item: index)
						return true
					}
				}
			}
		} catch {
			return false
		}
		fatalError("that history entry really should exists")
	}

	static let store: HistoryStore = HistoryStore(db: db)!

	func hasRecent(with url: URL, seconds: Int64) -> Bool {
		do {
			let urlText = url.absoluteString
			let lowerBound = Date().timeIntervalSince1970 - Double(seconds)
			let query = "SELECT EXISTS (SELECT * FROM \(tableName) WHERE url = ? AND timestamp >= ?) AS has_recent"
			let result = try database.execute(query, with: [.text(urlText), .float(lowerBound)])
			return result[0]["has_recent"]!.boolValue
		} catch {
			return false
		}
	}

	func removeItems(with host: String?, maxAge: TimeInterval?) {
		let oldest = maxAge == nil ? Date.distantPast : Date(timeIntervalSinceNow: -maxAge!)
		guard let host = host?.lowercased(), let dayItems = itemsByDate else {
			return
		}
		var dayIndex = dayItems.count

		while dayIndex > 0 {
			dayIndex -= 1
			let count = dayItems[dayIndex].count
			var itemIndex = count
			var keep = false

			while itemIndex > 0 {
				itemIndex -= 1
				let item = dayItems[dayIndex][itemIndex]
				if item.url.normalizedHost == host && item.timestamp >= oldest {
					if keep {
						removeItem(at: IndexPath(item: itemIndex, section: dayIndex))
					}
				} else if !keep {
					keep = true
					for i in 1 ..< count - itemIndex {
						removeItem(at: IndexPath(item: count - i, section: dayIndex))
					}
				}
			}
			if !keep {
				removeSection(at: dayIndex)
			}
		}
	}

	func removeItem(at indexPath: IndexPath) {
		assert(Thread.isMainThread)
		guard let section = itemsByDate?[indexPath.section] else {
			return
		}
		let item = section[indexPath.item]
		if section.count == 1 {
			remove(section: section, atIndex: indexPath.section)
		} else {
			if let _ = try? database.execute("DELETE FROM \(tableName) WHERE id = ?", with: [.integer(item.id)]) {
				notifyDeletion(section: indexPath.section, item: indexPath.item)
			}
		}
	}

	func removeSection(at index: Int) {
		guard let section = itemsByDate?[index] else {
			return
		}
		remove(section: section, atIndex: index)
	}

	func items(forSearch search: String) -> [HistoryItem] {
		var components = search.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		components = components.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
		if !(components.last?.isEmpty ?? true) {
			let lastIndex = components.count - 1
			components[lastIndex] = components[lastIndex] + "*"
		}

		let fts = components.joined(separator: " OR ")
		let query = "SELECT \(tableName).id, \(tableName).url, \(tableName).title, \(tableName).timestamp FROM \(tableName), \(HistoryStore.ftsName) WHERE \(tableName).id = \(HistoryStore.ftsName).rowid AND \(HistoryStore.ftsName) MATCH :query ORDER BY rank * (3600 + strftime('%s','now') - timestamp)"

		let rows = (try? database.execute(query, with: [":query": .text(fts)])) ?? []
		let items = try? rows.map() { (row) -> HistoryItem in
			guard let item = HistoryItem(row: row) else {
				throw HistoryError.databaseError
			}
			return item
		}
		return items ?? []
	}

	private func remove(section: [HistoryItem], atIndex index: Int) {
		assert(Thread.isMainThread)
		for item in section {
			guard let _ = try? database.execute("DELETE FROM \(tableName) WHERE id = ?", with: [.integer(item.id)]) else {
				return
			}
		}
		notifyDeletion(section: index)
	}

	private func notifyDeletion(section: Int, item: Int? = nil) {
		var info = [HISTORY_SECTION_INDEX: section]
		info[HISTORY_ITEM_INDEX] = item
		NotificationCenter.default.post(name: DELETE_HISTORY_NOTIFICATION, object: self, userInfo: info)
	}

	private func notifyInsert(section: Int, item: Int? = nil) {
		var info = [HISTORY_SECTION_INDEX: section]
		info[HISTORY_ITEM_INDEX] = item
		NotificationCenter.default.post(name: INSERT_HISTORY_NOTIFICATION, object: self, userInfo: info)
	}
}
