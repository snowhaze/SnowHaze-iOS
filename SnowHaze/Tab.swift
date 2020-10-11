//
//  Tab.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

let TAB_CHANGED_NOTIFICATION = Notification.Name(rawValue: "tabChanged")
let TAB_LIST_CHANGED_NOTIFICATION = Notification.Name(rawValue: "tabListChanged")
let TAB_KEY = "tab"
let NEW_TABS_INDEX_KEY = "newTabs"
let DELETED_TABS_INDEX_KEY = "deletedTabs"
let MOVED_TABS_FROM_INDEX_KEY = "movedTabsFromIndex"
let MOVED_TABS_TO_INDEX_KEY = "movedTabsToIndex"

private enum TabError: Error {
	case databaseError
	case conversionError
}

func ==(_ a: Tab, _ b: Tab) -> Bool {
	return a.id == b.id
}

class Tab: Equatable {
	let id: Int64
	let root: Int64?
	var history: [URL]  {
		didSet {
			save()
		}
	}

	var title: String? {
		didSet {
			save()
		}
	}

	fileprivate(set) var deleted = false
	private var internalUseTor: Bool?

	enum TLSStatus {
		case http
		case mixed
		case other
		case secure
		case ev(String)
	}
	var tlsStatus: TLSStatus {
		guard let controller = controller, !controller.unused else {
			return .other
		}
		let isAboutBlank = PolicyDomain.isAboutBlank(controller.url)
		let isHTTPS = displayURL?.normalizedScheme == "https"
		let manager = ContentBlockerManager.shared
		let policy = PolicyManager.manager(for: displayURL, in: self)
		let hasMixedBlocker = manager.blockers[BlockerID.mixedContentBlocker] != nil
		let blockMixedContent = (policy.blockMixedContent && hasMixedBlocker) || useTor
		let secure = ((controller.hasOnlySecureContent ?? false) || (useTor && isHTTPS)) && (controller.serverTrust != nil)
		if let _ = controller.url, !secure && !(isHTTPS && blockMixedContent) {
			if !(controller.isLoading ?? true) && isHTTPS && !isAboutBlank {
				return .mixed
			} else if !isAboutBlank && !(isHTTPS && controller.isLoading ?? false) {
				return .http
			}
		}
		if isHTTPS {
			if let organization = controller.serverTrust?.evOrganization {
				return .ev(organization)
			}
			return .secure
		}
		return .other
	}

	var useTor: Bool {
		precondition(Thread.isMainThread)
		if let useTor = internalUseTor {
			return useTor
		}
		internalUseTor = PolicyManager.manager(for: self).useTor
		return internalUseTor!
	}

	private var displayTitle: ([UIImage], String) {
		guard let controller = controller, !controller.unused else {
			let title = NSLocalizedString("home screen page title", comment: "title of home page displayed in url bar")
			return (useTor ? [UIImage(named: "tor_indicator")!] : [], title)
		}
		let url = displayURL
		let isAboutBlank = PolicyDomain.isAboutBlank(controller.url)
		let policy = PolicyManager.manager(for: displayURL, in: self)

		var attachments = [UIImage]()
		if policy.trust || isAboutBlank {
			attachments.append(UIImage(named: "trusted")!)
		}
		if useTor {
			attachments.append(UIImage(named: "tor_indicator")!)
		}
		switch tlsStatus {
			case .http:		attachments.append(UIImage(named: "http_warning")!)
			case .mixed:	attachments.append(UIImage(named: "mixed_content_warning")!)
			default:		break
		}
		if let title = title , !title.isEmpty {
			return (attachments, title)
		} else {
			return (attachments, url?.host ?? "")
		}
	}

	var displayURL: URL? {
		if let url = controller?.url, !PolicyDomain.isAboutBlank(url) {
			return url
		}
		return history.last ?? controller?.url
	}

	var formatedDisplayTitle: NSAttributedString {
		return format(displayTitle)
	}

	var uppercaseFormatedDisplayTitle: NSAttributedString {
		let data = displayTitle
		return format((data.0, data.1.localizedUppercase))
	}

	var torProxyCredentials: (String, String)? {
		return controller?.torProxyCredentials
	}

	var snapshot: UIImage?  {
		didSet {
			snapshotData = snapshot?.pngData()
		}
	}

	fileprivate var snapshotData: Data? {
		didSet {
			save()
		}
	}

	fileprivate var active: Bool = false {
		didSet {
			save()
		}
	}

	var isActive: Bool {
		return active
	}

	func makeActive() {
		try! db.inTransaction {
			TabStore.store.makeActive(self)
		}
	}

	func save() {
		TabStore.store.save(item: self)
	}

	func cleanup() {
		controller?.stopLoading()
		controller?.cleanup()
		controller = nil
	}

	private(set) lazy var controller: TabController? = TabController(tab: self)

	private init(id: Int64, root: Int64?, history: [URL], title: String?, snapshot: UIImage?, active: Bool) {
		self.id = id
		self.root = root
		self.history = history
		self.title = title
		self.snapshot = snapshot
		self.snapshotData = snapshot?.pngData()
		self.active = active
	}

	fileprivate init?(row: SQLite.Row) {
		let id = row["id"]?.integerValue
		if id == nil {
			return nil
		} else {
			self.id = id!
		}
		root = row["root_id"]?.integerValue
		title = row["title"]?.text
		if let jsonData = row["history"]?.text?.data(using: .utf8) {
			let deserialized = try? JSONSerialization.jsonObject(with: jsonData)
			let strings = deserialized as? [String] ?? []
			let urls = try? strings.map() { (string: String) -> URL in
				guard let url = URL(string: string) else {
					throw TabError.conversionError
				}
				return url
			}
			history = urls ?? []
		} else {
			history = []
		}
		active = row["active"]?.boolValue ?? false
		if let imageData = row["snapshot"]?.blob {
			snapshot = UIImage(data: imageData)
			snapshotData = imageData
		} else {
			snapshot = nil
			snapshotData = nil
		}
	}

	private func format(_ data: ([UIImage], String)) -> NSAttributedString {
		let title = data.1
		let images = data.0
		let attachments = images.map { image -> NSAttributedString in
			let attachment = NSTextAttachment()
			attachment.image = image
			attachment.bounds = CGRect(x: 0, y: -9, width: 30, height: 30)
			return NSAttributedString(attachment: attachment)
		}
		let result = NSMutableAttributedString()
		for attachment in attachments {
			result.append(attachment)
		}
		result.append(NSAttributedString(string: title))
		return result
	}

	fileprivate var bindings: [String: SQLite.Data] {
		let id: SQLite.Data = .integer(self.id)
		let title = SQLite.Data(self.title)
		let snapshot = SQLite.Data(snapshotData)
		let active: SQLite.Data = .integer(self.active ? 1 : 0)
		let strings = history.map() { (url) -> String in
			return url.absoluteString
		}
		let root: SQLite.Data
		if let root_id = self.root {
			root = .integer(root_id)
		} else {
			root = .null
		}
		let jsonData = try! JSONSerialization.data(withJSONObject: strings)
		let json = String(data: jsonData, encoding: .utf8)!
		let jsonBinding: SQLite.Data = .text(json)
		return [":id": id, ":root_id": root, ":snapshot": snapshot, ":active": active, ":history": jsonBinding, ":title": title]
	}
}

class TabStore {
	private var undoStack: [([(Tab, Date)], Date, Int64)] = []
	private var deletionId: Int64 = 0
	private var nextDeletionId: Int64 {
		deletionId += 1
		return deletionId
	}

	private let database: SQLiteManager
	static let tableName = "ch_illotros_snowhaze_browsing_tab"
	private let tableName: String = TabStore.tableName
	private var tabCache = [Int64: Tab]()

	private var internalItems: [Tab]?

	var items: [Tab] {
		assert(Thread.isMainThread)
		if internalItems == nil {
			let query = "SELECT * FROM \(tableName) WHERE NOT deleted ORDER BY IFNULL(root_id, id) ASC, id ASC"
			guard let rows = try? database.execute(query) else {
				return []
			}
			let tabs = try? rows.map() { (row) -> Tab in
				if let id = row["id"]?.integerValue, let cachedTab = tabCache[id] {
					return cachedTab
				}
				guard let item = Tab(row: row) else {
					throw TabError.databaseError
				}
				tabCache[item.id] = item
				return item
			}
			internalItems = tabs ?? []
		}
		return internalItems!
	}

	func tab(with id: Int64) -> Tab? {
		assert(Thread.isMainThread)
		if let cachedTab = tabCache[id] {
			return cachedTab
		}
		guard let row = (try? database.execute("SELECT * FROM \(tableName) WHERE id = ?", with: [.integer(id)]).first) ?? nil else {
			return nil
		}
		guard let tab = Tab(row: row) else {
			return nil
		}
		tabCache[id] = tab
		return tab
	}

	fileprivate func makeActive(_ tab: Tab) {
		tab.active = true
		for item in items {
			let oldActive = item.active
			let newActive = item.id == tab.id
			if oldActive != newActive {
				item.active = newActive
			}
		}
	}

	private init?(db: SQLiteManager) {
		database = db
		do {
			try database.execute("DELETE FROM \(tableName) WHERE deleted")
		} catch {
			return nil
		}
	}

	@discardableResult func add(withSettings values: [String: SQLite.Data] = [:], parent: Tab? = nil, loadHomepage: Bool = true) -> Tab? {
		var result: Tab?
		var notify: (() -> ())?
		try! database.inTransaction {
			if let tmpNotify = addItem(with: [], snapshot: nil, title: nil, root: parent?.root ?? parent?.id) {
				notify = tmpNotify
				let newTab = tab(with: database.lastInsertRowId)!
				let settings = Settings.settings(for: newTab)
				for (key, value) in values {
					settings.set(value, for: key)
				}
				result = newTab
			}
		}
		notify?()
		if loadHomepage, let tab = result, let url = PolicyManager.manager(for: tab).homepageURL {
			tab.controller?.load(url: url)
		}
		return result
	}

	func add(with request: URLRequest, copySettingsFromParent parent: Tab, customization: (Tab) -> () = { _ in }) -> Tab? {
		assert(Thread.isMainThread)
		let history: [URL]
		if let url = request.url {
			history = [url]
		} else {
			history = []
		}
		var newTab: Tab!
		var notify: (() -> ())!
		do {
			try database.inTransaction {
				let res = addItem(with: history, snapshot: nil, title: nil, root: parent.root ?? parent.id)
				let id = database.lastInsertRowId!
				guard let tmpNotify = res, let tab = tab(with: id) else {
					throw TabError.databaseError
				}
				notify = tmpNotify
				newTab = tab
				Settings.copySettings(from: parent, to: newTab)
			}
		} catch {
			return nil
		}
		notify()
		if let controller = parent.controller {
			try! newTab.controller?.set(userAgent: controller.userAgent)
			try! newTab.controller?.set(dataStore: controller.dataStore)
			try! newTab.controller?.set(safebrowsingStorage: controller.safebrowsingStorage)
		}
		customization(newTab)
		newTab.controller?.load(request: request)
		return newTab
	}

	private func addItem(with history: [URL], snapshot: UIImage?, title: String?, root: Int64?) -> (() -> ())? {
		assert(Thread.isMainThread)
		do {
			let strings = history.map() { return $0.absoluteString }
			let oldItems = items
			let jsonData = try! JSONSerialization.data(withJSONObject: strings)
			let json = String(data: jsonData, encoding: .utf8)!
			let snapshotBinding = SQLite.Data(snapshot?.pngData())
			let titleBinding = SQLite.Data(title)
			let rootBinding: SQLite.Data
			if let root = root {
				rootBinding = .integer(root)
			} else {
				rootBinding = .null
			}
			let bindings = [rootBinding, .text(json), snapshotBinding, .false, titleBinding]
			let query = "INSERT INTO \(tableName) (root_id, history, snapshot, active, title) VALUES (?, ?, ?, ?, ?)"
			try database.execute(query, with: bindings)
			internalItems = nil
			let callguard = SyncBlockCallGuard()
			return {
				callguard.called()
				self.notifyDiff(from: oldItems)
			}
		} catch {
			return nil
		}
	}

	static let store: TabStore = TabStore(db: db)!

	private func delete(_ tabs: [(Tab, Date)]) {
		for (tab, _) in tabs {
			assert(!tab.deleted)
			tab.cleanup()
		}

		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			Settings.atomically {
				for (tab, _) in tabs {
					assert(!tab.deleted)
					try! self.database.execute("DELETE FROM \(self.tableName) WHERE id = ?", with: [.integer(tab.id)])
					tab.deleted = true
					Settings.dropChache(for: tab)
				}
			}
		}
	}

	func remove(_ item: Tab, undoTime: TimeInterval) {
		remove([(item, undoTime)])
	}

	func remove(_ tabs: [(Tab, TimeInterval)]) {
		assert(Thread.isMainThread)
		let oldItems = items
		let ids = tabs.map { $0.0.id }
		let deletedIds = Set(ids)
		try! database.inTransaction(ofType: .exclusive) {
			for (tab, _) in tabs {
				try! database.execute("UPDATE \(tableName) SET deleted = 1 WHERE id = ?", with: [.integer(tab.id)])
				tabCache[tab.id] = nil
			}
		}
		internalItems = internalItems?.filter { !deletedIds.contains($0.id) }
		notifyDiff(from: oldItems)
		let now = Date()
		let storable = tabs.map { ($0.0, Date(timeInterval: $0.1, since: now)) }
		if let undoTime = tabs.map({ $0.1 }).max(), undoTime > 0.1 {
			let delId = nextDeletionId
			undoStack.append((storable, Date(timeIntervalSinceNow: undoTime), delId))
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + undoTime) {
				let now = Date()
				self.undoStack = self.undoStack.filter { tabs, date, id -> Bool in
					if id == delId || date <= now {
						self.delete(tabs)
						return false
					}
					return true
				}
			}
		} else {
			delete(storable)
		}
	}

	var canUndoDeletion: Bool {
		return !undoStack.isEmpty
	}

	func undoDeletion() -> [Tab] {
		precondition(Thread.isMainThread)
		guard canUndoDeletion else {
			return []
		}
		let tabs = undoStack.popLast()!.0

		let now = Date()
		let needDelete = tabs.filter { $0.1.timeIntervalSince(now) <= 0 }
		delete(needDelete)

		let recoverable = tabs.compactMap { $0.1.timeIntervalSince(now) > 0 ? $0.0 : nil }

		let oldItems = items
		try! database.inTransaction(ofType: .exclusive) {
			for tab in recoverable {
				assert(!tab.deleted)
				try! database.execute("UPDATE \(tableName) SET deleted = 0 WHERE id = ?", with: [.integer(tab.id)])
				internalItems = nil
				tabCache[tab.id] = tab

				if tab.active {
					makeActive(tab)
				}
			}
		}
		notifyDiff(from: oldItems)
		return recoverable
	}

	@discardableResult fileprivate func save(item: Tab) -> Bool {
		assert(Thread.isMainThread)
		let bindings = item.bindings
		let query = "UPDATE \(tableName) SET history = :history, root_id = :root_id, snapshot = :snapshot, active = :active, title = :title WHERE id = :id"
		do {
			try database.execute(query, with: bindings)
			NotificationCenter.default.post(name: TAB_CHANGED_NOTIFICATION, object: self, userInfo: [TAB_KEY: item])
			return true
		} catch {
			return false
		}
	}

	private func notifyDiff(from: [Tab]) {
		let changes = items.diff(from: from)
		let newIndexes = changes.new.map { $0.index }
		let deletedIndexes = changes.deleted.map { $0.index }
		let fromIndexes = changes.moved.map { $0.fromIndex }
		let toIndexes = changes.moved.map { $0.toIndex }
		let userInfo = [NEW_TABS_INDEX_KEY: newIndexes, DELETED_TABS_INDEX_KEY: deletedIndexes, MOVED_TABS_FROM_INDEX_KEY: fromIndexes, MOVED_TABS_TO_INDEX_KEY: toIndexes]
		NotificationCenter.default.post(name: TAB_LIST_CHANGED_NOTIFICATION, object: self, userInfo: userInfo)
	}
}
