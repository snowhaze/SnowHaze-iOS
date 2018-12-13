//
//  Bookmark.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let weightMalus = 0.998
private let weightBonus = 1.0
private let startWeight = 80.0

let BOOKMARK_LIST_CHANGED_NOTIFICATION = Notification.Name(rawValue: "BookmarkListChanged")
let BOOKMARK_CHANGED_NOTIFICATION = Notification.Name(rawValue: "BookmarkChanged")
let BOOKMARK_KEY = "bookmark"
let NEW_BOOKMARKS_INDEX_USER_INFO_KEY = "newBookmarks"
let DELETED_BOOKMARKS_INDEX_USER_INFO_KEY = "deletedBookmarks"
let DELETED_BOOKMARK_IDS_USER_INFO_KEY = "deletedBookmarkIDs"
let MOVED_BOOKMARKS_FROM_INDEX_USER_INFO_KEY = "moved bookmarks from"
let MOVED_BOOKMARKS_TO_INDEX_USER_INFO_KEY = "moved bookmarks to"

private enum BookmarkError: Error {
	case databaseError
}

func ==(_ a: Bookmark, _ b: Bookmark) -> Bool {
	return a.id == b.id
}

class Bookmark: Equatable, WorkerWebViewManagerDelegate {
	let id: Int64
	let URL: Foundation.URL

/**
 *	only set from recalculateWeight(_:) (and initializers)
 */
	private(set) var weight: Double {
		didSet {
			BookmarkStore.store.save(weight: weight, forItem: self)
		}
	}

	private(set) var title: String?{
		didSet {
			BookmarkStore.store.save(title: title, forItem: self)
		}
	}

	var name: String? {
		didSet {
			BookmarkStore.store.save(name: name, forItem: self)
		}
	}

	var favicon: UIImage? {
		didSet {
			BookmarkStore.store.save(iconData: iconData, forItem: self)
		}
	}

	var displayName: String? {
		if let name = name , !name.isEmpty {
			return name
		}
		if let title = title , !title.isEmpty {
			return title
		}
		return URL.host
	}

	var displayIcon: UIImage {
		return favicon ?? placeholderImage
	}

	private var placeholderImage: UIImage {
		if let favicon = favicon {
			return favicon
		}
		let size = CGSize(width: 100, height: 100)
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		let name: String
		if let title = title?.localizedUppercase , !title.isEmpty {
			name = title
		} else if let host = URL.host?.localizedUppercase , !host.isEmpty {
			let components = host.components(separatedBy: ".")
			name = components.filter({ $0 != "WWW" && $0 != "W3" && $0 != "WWW3" }).first ?? host
		} else {
			name = " "
		}
		let character = String(name[..<name.index(after: name.startIndex)])
		let font = UIFont.systemFont(ofSize: 100)
		let attributes = [NSAttributedString.Key.foregroundColor: UIColor.title, NSAttributedString.Key.font: font]
		character.draw(in: CGRect(origin: CGPoint(x: 5, y: 0), size: size), withAttributes: attributes)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image!
	}

	fileprivate var iconData: Data? {
		set {
			if newValue == iconData {
				return
			}
			if let imageData = newValue {
				favicon = UIImage(data: imageData)
			} else {
				favicon = nil
			}
		}
		get {
			if let favicon = favicon {
				return favicon.pngData()
			} else {
				return nil
			}
		}
	}

/**
	only call from recalculateWeights(_:) (and initializers)
*/
	fileprivate func recalculateWeight(_ wasChosen: Bool) {
		if wasChosen {
			weight = weight * weightMalus + weightBonus
		} else {
			weight = weight * weightMalus
		}
	}

	private init(id: Int64, url: Foundation.URL, title: String? = nil, name: String? = nil, favicon: UIImage? = nil, weight: Double = startWeight) {
		self.id = id
		self.URL = url
		self.title = title
		self.name = name
		self.favicon = favicon
		self.weight = weight
	}

	fileprivate init?(row: SQLite.Row) {
		guard let id = row["id"]?.integerValue else {
			return nil
		}
		self.id = id
		self.title = row["title"]?.text
		self.name = row["name"]?.text
		guard let urlString = row["url"]?.text else {
			return nil
		}
		guard let url = Foundation.URL(string: urlString) else {
			return nil
		}
		self.URL = url
		guard let weight = row["weight"]?.floatValue else {
			return nil
		}
		self.weight = weight
		if let data = row["favicon"]?.blob {
			self.favicon = UIImage(data: data as Data)
		} else {
			self.favicon = nil
		}
	}

	private var webViewManager: WorkerWebViewManager?

	func reload(in tab: Tab) {
		guard webViewManager == nil else {
			return
		}
		webViewManager = WorkerWebViewManager(tab: tab)
		webViewManager?.delegate = self
		webViewManager?.load(url: URL)
	}

	func webViewManaget(_ manager: WorkerWebViewManager, didUpgradeLoadOf url: URL) {
		Stats.shared.upgradedLoad(of: url, in: manager.tab)
	}

	func webViewManaget(_ manager: WorkerWebViewManager, isLoading url: URL?) {
		Stats.shared.loading(url, in: manager.tab)
	}

	func webViewManagerDidFailLoad(_ manager: WorkerWebViewManager) {
		webViewManager = nil
	}

	func webViewManagerDidFinishLoad(_ manager: WorkerWebViewManager) {
		title = manager.webView.title
		FaviconFetcher(manager: manager).fetch { data in
			if let data = data, let image = UIImage(data: data as Data) {
				DispatchQueue.main.async {
					self.favicon = image
				}
			}
		}
		webViewManager = nil
	}

	func webViewManager(_ manager: WorkerWebViewManager, didMakeProgress progress: Double) {

	}

	func wasSelected() {
		BookmarkStore.store.recalculateWeights(selectedItem: self)
	}
}

class BookmarkStore {
	private let database: SQLiteManager
	static let tableName = "ch_illotros_snowhaze_browsing_bookmark"
	static let ftsName = "ch_illotros_snowhaze_browsing_bookmark_fts"
	static let ftsUpdateName = "ch_illotros_snowhaze_browsing_bookmark_fts_update"
	static let ftsInsertName = "ch_illotros_snowhaze_browsing_bookmark_fts_insert"
	static let ftsDeleteName = "ch_illotros_snowhaze_browsing_bookmark_fts_delete"
	private let tableName: String = BookmarkStore.tableName
	private var bookmarkCache = [Int64: Bookmark]()
	private var internalItems: [Bookmark]?
	private var externalManager: ExternalBookmarkManager!

	var items: [Bookmark] {
		assert(Thread.isMainThread)
		if internalItems == nil {
			let query = "SELECT * FROM \(tableName) ORDER BY weight DESC"
			guard let rows = try? database.execute(query) else {
				return []
			}
			let bookmarks = try? rows.map() { (row) -> Bookmark in
				if let id = row["id"]?.integerValue, let cachedBookmark = bookmarkCache[id] {
					return cachedBookmark
				}
				guard let item = Bookmark(row: row) else {
					throw BookmarkError.databaseError
				}
				bookmarkCache[item.id] = item
				return item
			}
			internalItems = bookmarks ?? []
		}
		return internalItems!
	}

	func bookmark(forId id: Int64) -> Bookmark? {
		assert(Thread.isMainThread)
		if let cachedBookmark = bookmarkCache[id] {
			return cachedBookmark
		}
		guard let row = (try? database.execute("SELECT * FROM \(tableName) WHERE id = ?", with: [.integer(id)]).first) ?? nil else {
			return nil
		}
		guard let bookmark = Bookmark(row: row) else {
			return nil
		}
		bookmarkCache[id] = bookmark
		return bookmark
	}

	fileprivate func recalculateWeights(selectedItem item: Bookmark) {
		items.forEach { $0.recalculateWeight($0.id == item.id) }
		listChanged()
	}

	static let store: BookmarkStore = BookmarkStore(db: db)

	private init(db: SQLiteManager) {
		database = db
		externalManager = ExternalBookmarkManager(store: self)
	}

	@discardableResult func addItem(forTab tab: Tab) -> Bool {
		assert(Thread.isMainThread)
		guard let controller = tab.controller, let url = tab.displayURL else {
			return false
		}
		var id: Int64 = 0
		do {
			let title = SQLite.Data(tab.title)
			let bindings = [.text(url.absoluteString), title, .float(startWeight)]
			let query = "INSERT INTO \(tableName) (url, title, weight) VALUES (?, ?, ?)"
			try database.execute(query, with: bindings)
			id = database.lastInsertRowId
		} catch {
			return false
		}
		guard let bookmark = bookmark(forId: id) else {
			return false
		}
		listChanged()
		FaviconFetcher(manager: controller).fetch { imageData -> Void in
			DispatchQueue.main.async {
				bookmark.iconData = imageData as Data?
			}
		}
		return true
	}

	@discardableResult func addItem(for url: URL, loadWith tab: Tab) -> Bool {
		assert(Thread.isMainThread)
		var id: Int64 = 0
		do {
			let bindings = [SQLite.Data.text(url.absoluteString), .float(startWeight)]
			let query = "INSERT INTO \(tableName) (url, weight) VALUES (?, ?)"
			try database.execute(query, with: bindings)
			id = database.lastInsertRowId
		} catch {
			return false
		}
		guard let bookmark = bookmark(forId: id) else {
			return false
		}
		listChanged()
		bookmark.reload(in: tab)
		return true
	}

	private func listChanged() {
		let oldItems = items
		internalItems = nil
		let changes = items.diff(from: oldItems)
		let newIndexes = changes.new.map { $0.index }
		let deletedIndexes = changes.deleted.map { $0.index }
		let movedFromIndexes = changes.moved.map { $0.fromIndex }
		let movedToIndexes = changes.moved.map { $0.toIndex }
		let deletedIDs = deletedIndexes.map { NSNumber(value: oldItems[$0].id as Int64) }
		if !(newIndexes.isEmpty && deletedIndexes.isEmpty && movedFromIndexes.isEmpty && movedToIndexes.isEmpty) {
			let dict: [String : Any] = [NEW_BOOKMARKS_INDEX_USER_INFO_KEY: newIndexes, DELETED_BOOKMARKS_INDEX_USER_INFO_KEY: deletedIndexes, MOVED_BOOKMARKS_FROM_INDEX_USER_INFO_KEY: movedFromIndexes, MOVED_BOOKMARKS_TO_INDEX_USER_INFO_KEY: movedToIndexes, DELETED_BOOKMARK_IDS_USER_INFO_KEY: deletedIDs]
			NotificationCenter.default.post(name: BOOKMARK_LIST_CHANGED_NOTIFICATION, object: self, userInfo: dict)
		}
	}

	private func itemChanged(_ item: Bookmark) {
		NotificationCenter.default.post(name: BOOKMARK_CHANGED_NOTIFICATION, object: self, userInfo: [BOOKMARK_KEY: item])
	}

	@discardableResult fileprivate func save(weight: Double, forItem item: Bookmark) -> Bool {
		assert(Thread.isMainThread)
		let bindings: [SQLite.Data] = [.float(weight), .integer(item.id)]
		let query = "UPDATE \(tableName) SET weight = ? WHERE id = ?"
		do {
			try database.execute(query, with: bindings)
			itemChanged(item)
			return true
		} catch {
			return false
		}
	}

	@discardableResult fileprivate func save(title: String?, forItem item: Bookmark) -> Bool {
		assert(Thread.isMainThread)
		let titleBinding = SQLite.Data(title)
		let bindings: [SQLite.Data] = [titleBinding, .integer(item.id)]
		let query = "UPDATE \(tableName) SET title = ? WHERE id = ?"
		do {
			try database.execute(query, with: bindings)
			itemChanged(item)
			return true
		} catch {
			return false
		}
	}

	@discardableResult fileprivate func save(name: String?, forItem item: Bookmark) -> Bool {
		assert(Thread.isMainThread)
		let nameBinding = SQLite.Data(name)
		let bindings: [SQLite.Data] = [nameBinding, .integer(item.id)]
		let query = "UPDATE \(tableName) SET name = ? WHERE id = ?"
		do {
			try database.execute(query, with: bindings)
			itemChanged(item)
			return true
		} catch {
			return false
		}
	}

	@discardableResult fileprivate func save(iconData: Data?, forItem item: Bookmark) -> Bool {
		assert(Thread.isMainThread)
		let iconBinding = SQLite.Data(iconData)
		let bindings: [SQLite.Data] = [iconBinding, .integer(item.id)]
		let query = "UPDATE \(tableName) SET favicon = ? WHERE id = ?"
		do {
			try database.execute(query, with: bindings)
			itemChanged(item)
			return true
		} catch {
			return false
		}
	}

	@discardableResult func remove(item: Bookmark) -> Bool {
		assert(Thread.isMainThread)
		do {
			try database.execute("DELETE FROM \(tableName) WHERE id = ?", with: [.integer(item.id)])
			itemChanged(item)
			bookmarkCache[item.id] = nil
			listChanged()
			return true
		} catch {
			return false
		}
	}

	func bookmarks(forSearch search: String, limit: UInt) -> [Bookmark] {
		assert(Thread.isMainThread)
		var components = search.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
		components = components.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
		if !(components.last?.isEmpty ?? true) {
			let lastIndex = components.count - 1
			components[lastIndex] = components[lastIndex] + "*"
		}
		let fts = components.joined(separator: " OR ")
		let query = "SELECT \(tableName).id FROM \(tableName), \(BookmarkStore.ftsName) WHERE \(BookmarkStore.ftsName).rowid = \(tableName).id AND \(BookmarkStore.ftsName) MATCH :query ORDER BY rank / weight LIMIT :limit"
		let bindings: [String: SQLite.Data] = [":query": .text(fts), ":limit": .integer(Int64(limit))]
		let rows = (try? database.execute(query, with: bindings)) ?? []
		let bookmarks = try? rows.map() { (row) -> Bookmark in
			if let id = row["id"]?.integerValue, let cachedBookmark = bookmarkCache[id] {
				return cachedBookmark
			}
			guard let item = Bookmark(row: row) else {
				throw BookmarkError.databaseError
			}
			bookmarkCache[item.id] = item
			return item
		}
		return bookmarks ?? []
	}
}
