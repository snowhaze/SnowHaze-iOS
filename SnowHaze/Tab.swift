//
//  Tab.swift
//  SnowHaze
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

private extension UIImage {
	var pngData: Data {
		return self.pngData()!
	}
}

func ==(_ a: Tab, _ b: Tab) -> Bool {
	return a.id == b.id
}

class Tab: Equatable {
	private static let lockCharacter = "\u{F100}"
	private static let incompleteLockCharacter = "\u{F101}"
	private static let barCharacter = "\u{F102}"
	private static let trustedCharacter = "\u{F104}"
	private static let unsafeCharacter = "\u{F105}"
	private static let lockCharacters = CharacterSet(charactersIn: lockCharacter + incompleteLockCharacter + barCharacter + trustedCharacter + unsafeCharacter)

	static func sanitize(title: String?) -> String? {
		let filteredTitle = title?.components(separatedBy: Tab.lockCharacters).joined()
		return filteredTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
	}

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

	private var displayTitle: String {
		if controller?.unused ?? true {
			return NSLocalizedString("home screen page title", comment: "title of home page displayed in url bar")
		} else {
			let title: String
			let url = displayURL
			if let organization = controller?.evOrganization {
				title = organization
			} else if let tabTitle = self.title , !tabTitle.isEmpty {
				title = tabTitle
			} else {
				title = url?.host ?? ""
			}
			let titleComponents = title.components(separatedBy: Tab.lockCharacters)
			let safeTitle = titleComponents.joined(separator: "")
			var insert = ""
			if PolicyManager.manager(for: displayURL, in: self).trust {
				insert += Tab.trustedCharacter + " "
			}
			let isHTTPS = url?.scheme?.lowercased() == "https"
			let blockMixedContent: Bool
			if #available(iOS 11, *) {
				let policy = PolicyManager.manager(for: displayURL, in: self)
				let manager = ContentBlockerManager.shared
				let mixedBlocker = BlockerID.mixedContentBlocker
				blockMixedContent = policy.blockMixedContent && manager.blockers[mixedBlocker] != nil
			} else {
				blockMixedContent = false
			}
			if controller?.hasOnlySecureContent ?? false || (isHTTPS && blockMixedContent) {
				insert += Tab.lockCharacter + " "
			} else if let realURL = controller?.url, !(controller?.isLoading ?? true) && isHTTPS && !PolicyManager.isAboutBlank(realURL) {
				insert += Tab.incompleteLockCharacter + Tab.barCharacter + " "
			} else if let realURL = controller?.url, !PolicyManager.isAboutBlank(realURL) && !isHTTPS {
				insert += Tab.unsafeCharacter + " "
			}
			return " " + insert + safeTitle
		}
	}

	var displayURL: URL? {
		if let url = controller?.url {
			if !PolicyManager.isAboutBlank(url) {
				return url
			}
		}
		return history.last
	}

	var formatedDisplayTitle: NSAttributedString {
		return format(displayTitle, isEV: controller?.evOrganization != nil)
	}

	var uppercaseFormatedDisplayTitle: NSAttributedString {
		return format(displayTitle.localizedUppercase, isEV: controller?.evOrganization != nil)
	}

	var snapshot: UIImage?  {
		didSet {
			snapshotData = snapshot?.pngData
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
		controller?.clearMediaInfo()
		controller = nil
	}

	private(set) lazy var controller: TabController? = TabController(tab: self)

	private init(id: Int64, root: Int64?, history: [URL], title: String?, snapshot: UIImage?, active: Bool) {
		self.id = id
		self.root = root
		self.history = history
		self.title = title
		self.snapshot = snapshot
		self.snapshotData = snapshot?.pngData
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
		if let jsonData = row["history"]?.text?.data(using: String.Encoding.utf8) {
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


	private func format(_ title: String, isEV: Bool) -> NSAttributedString {
		let formated = NSMutableAttributedString(string: title)

		if isEV {
			let range = NSRange(title.startIndex ..< title.endIndex, in: title)
			formated.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.safetyIndicator, range: range)
		}

		let barRange = (title as NSString).range(of: String(Tab.barCharacter))
		if barRange.location != NSNotFound {
			formated.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.mixedContentBar, range: barRange)
		}

		let checkRange = (title as NSString).range(of: String(Tab.trustedCharacter))
		if checkRange.location != NSNotFound {
			formated.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.safetyIndicator, range: checkRange)
		}

		let warningRange = (title as NSString).range(of: String(Tab.unsafeCharacter))
		if warningRange.location != NSNotFound {
			formated.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.httpWarning, range: warningRange)
		}
		return formated
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
	private var undoStack: [(Tab, Date, Int64, [String: SQLite.Data])] = []
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
			let query = "SELECT * FROM \(tableName) ORDER BY IFNULL(root_id, id) ASC, id ASC"
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

	private init(db: SQLiteManager) {
		database = db
	}

	@discardableResult func addEmptyItem(withSettings values: [String: SQLite.Data] = [:], parent: Tab? = nil) -> Tab? {
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
		return result
	}

	func addEmptyItem(with request: URLRequest, copySettingsFromParent parent: Tab) -> Tab? {
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
		}
		newTab.controller?.load(request: request)
		return newTab
	}

	private func addItem(with history: [URL], snapshot: UIImage?, title: String?, root: Int64?) -> (() -> ())? {
		assert(Thread.isMainThread)
		class Callguard {
			var called = false
			init() {
				DispatchQueue.main.async {
					self.check()
				}
			}
			func check() {
				if !called {
					fatalError("update notification was deffered for too long")
				}
			}
		}
		do {
			let strings = history.map() { return $0.absoluteString }
			let oldItems = items
			let jsonData = try! JSONSerialization.data(withJSONObject: strings)
			let json = String(data: jsonData, encoding: .utf8)!
			let snapshotBinding = SQLite.Data(snapshot?.pngData)
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
			let callguard = Callguard()
			return {
				callguard.called = true
				self.notifyDiff(from: oldItems)
			}
		} catch {
			return nil
		}
	}

	static let store: TabStore = TabStore(db: db)

	@discardableResult func remove(_ item: Tab, undoTime: TimeInterval) -> Bool {
		assert(Thread.isMainThread)
		let oldItems = items
		let id = item.id
		do {
			try database.execute("DELETE FROM \(tableName) WHERE id = ?", with: [.integer(id)])
			Settings.dropChache(for: item)
		} catch {
			return false
		}
		internalItems = internalItems?.filter { $0.id != item.id }
		tabCache[id] = nil
		notifyDiff(from: oldItems)
		if undoTime > 0.1 {
			let delId = nextDeletionId
			undoStack.append((item, Date(timeIntervalSinceNow: undoTime), delId, Settings.settings(for: item).allValues))
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + undoTime) {
				let now = Date()
				self.undoStack = self.undoStack.filter { (tab, date, id, _) -> Bool in
					if (tab == item && id == delId) || date <= now {
						item.cleanup()
						return false
					}
					return true
				}
			}
		} else {
			item.cleanup()
		}
		return true
	}

	var canUndoDeletion: Bool {
		return !undoStack.isEmpty
	}

	@discardableResult func undoDeletion() -> Tab? {
		assert(Thread.isMainThread)
		guard canUndoDeletion else {
			return nil
		}
		let (tab, _, _, settingsValues) = undoStack.popLast()!
		var res: Tab? = nil

		let oldItems = items
		try! database.inTransaction {
			guard insertNoNotify(item: tab) else {
				return
			}
			res = tab

			if tab.active {
				makeActive(tab)
			}

			let settings = Settings.settings(for: tab)
			for (key, value) in settingsValues {
				settings.set(value, for: key)
			}
		}
		if res != nil {
			notifyDiff(from: oldItems)
		}
		return res
	}

	private func insertNoNotify(item: Tab) -> Bool {
		assert(Thread.isMainThread)
		let query = "INSERT INTO \(tableName) (id, root_id, history, snapshot, active, title) VALUES (:id, :root_id, :history, :snapshot, :active, :title)"
		let bindings = item.bindings
		do {
			try database.execute(query, with: bindings)
			internalItems = nil
			tabCache[item.id] = item
			return true
		} catch {
			return false
		}
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
