//
//  Setting.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum SettingsLevel {
	case page
	case tab
	case global
}

protocol SettingsListener: class {
	/**
	 *	Is called before the value is changed. Meaning the old value can be deternined via settings.value(for: key) if necessary
	*/
	func settings(_ settings: Settings, willChangeValueFor key: String, toValue: SQLite.Data?)
	func settings(_ settings: Settings, didChangeValueFor key: String, toValue: SQLite.Data?)
}

extension SettingsListener {
	func settings(_ settings: Settings, willChangeValueFor key: String, toValue: SQLite.Data?) { }
	func settings(_ settings: Settings, didChangeValueFor key: String, toValue: SQLite.Data?) { }
}

private class WeakListener {
	weak var value : SettingsListener?
	init (value: SettingsListener) {
		self.value = value
	}
}

class Settings {
	static let dbName = "settings"
	static let globalTableName = "ch_illotros_snowhaze_settings_global"
	static let tabTableName = "ch_illotros_snowhaze_settings_tab"
	static let pageTableName = "ch_illotros_snowhaze_settings_page"

	fileprivate var listeners = [String: [WeakListener]]()

	private var observer: NSObjectProtocol!

	static func atomically(perform: () -> Void) {
		try! db.inTransaction(perform: perform)
	}

	init() {
		observer = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] _ in
			self?.receivedMemoryWarning()
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(observer)
	}

	class var dataAvailable: Bool {
		return dbAvailable
	}

	static func globalSettings() -> Settings {
		return GlobalSettings.instance
	}

	static func settings(for tab: Tab) -> Settings {
		return TabSettings.instance(for: tab)
	}

	static func settings(for domain: PolicyDomain, in tab: Tab) -> Settings {
		return TabPageSettings.instance(for: domain, in: tab)
	}

	static func settings(for domain: PolicyDomain) -> Settings {
		return GlobalPageSettings.instance(for: domain.domain)
	}

	static func dropChache(for tab: Tab) {
		TabSettings.dropChacheFor(tab: tab)
	}

	static func deleteSettings(for domain: PolicyDomain) {
		GlobalPageSettings.clearSettings(for: domain)
	}

	/**
	*	Sets the settings of 'to' to the settings of 'from' without notifing listeners
	*/
	static func copySettings(from: Tab, to: Tab) {
		TabSettings.copyData(from: from, to: to)
		TabPageSettings.copyData(from: from, to: to)
	}

	static func unsetAllPageSettings() {
		GlobalPageSettings.clearAllPageSettings()
	}

	func value(for key: String) -> SQLite.Data? {
		fatalError("Settings is a Abstract Superclass")
	}

	var allValues: [String: SQLite.Data] {
		fatalError("Settings is a Abstract Superclass")
	}

	func set(_ value: SQLite.Data, for key: String) {
		fatalError("Settings is a Abstract Superclass")
	}

	func unsetValue(for key: String) {
		fatalError("Settings is a Abstract Superclass")
	}

	func unsetAllValues() {
		fatalError("Settings is a Abstract Superclass")
	}

	func add(listener: SettingsListener, for key: String) {
		_ = addListenerAlreadyHadListener(listener, for: key)
	}

	func remove(listener: SettingsListener, for key: String) {
		_ = removeListenerHasListenerLeft(listener, for: key)
	}

	fileprivate func addListenerAlreadyHadListener(_ listener: SettingsListener, for key: String) -> Bool {
		if !(listeners[key]?.contains(where: { $0.value === listener }) ?? false) {
			if listeners[key] == nil {
				listeners[key] = []
			}
			var array = listeners[key]!
			var deadIndexes = [Int]()
			for (index, weakListener) in array.enumerated() {
				if weakListener.value == nil {
					deadIndexes.append(index)
				}
			}
			for index in deadIndexes.reversed() {
				array.remove(at: index)
			}
			array.append(WeakListener(value: listener))
			return array.count > 1
		}
		return true
	}

	fileprivate func removeListenerHasListenerLeft(_ listener: SettingsListener, for key: String) -> Bool {
		guard var array = listeners[key] else {
			return false
		}
		if let index = array.index(where: { $0.value === listener }) {
			array.remove(at: index)
		}
		var deadIndexes = [Int]()
		for (index, weakListener) in array.enumerated() {
			if weakListener.value == nil {
				deadIndexes.append(index)
			}
		}
		for index in deadIndexes.reversed() {
			array.remove(at: index)
		}
		return !array.isEmpty
	}

	fileprivate func notifyListenersOfNewValue(_ value: SQLite.Data?, for key: String, alreadySet: Bool) {
		if let keyListeners = listeners[key] {
			for listener in keyListeners {
				if alreadySet {
					listener.value?.settings(self, didChangeValueFor: key, toValue: value)
				} else {
					listener.value?.settings(self, willChangeValueFor: key, toValue: value)
				}
			}
		}
	}

	fileprivate func notifyAllListenersOfClear(finished: Bool) {
		for (key, keyListeners) in listeners {
			for listener in keyListeners {
				if finished {
					listener.value?.settings(self, didChangeValueFor: key, toValue: nil)
				} else {
					listener.value?.settings(self, willChangeValueFor: key, toValue: nil)
				}
			}
		}
	}

	fileprivate func receivedMemoryWarning() { }

	fileprivate func makeCache(from rows: [SQLite.Row]) -> [String: SQLite.Data] {
		var cache: [String: SQLite.Data] = [:]
		for row in rows {
			if let key = row["key"]?.text, let value = row["value"] {
				cache[Settings.unescape(key)] = value
			}
		}
		return cache
	}

	static func unescape(_ string: String) -> String {
		let zeroUnesc = string.replacingOccurrences(of: "\\0", with: "\0")
		return zeroUnesc.replacingOccurrences(of: "\\\\", with: "\\")
	}

	static func escape(_ key: String) -> String {
		let backEsc = key.replacingOccurrences(of: "\\", with: "\\\\")
		return backEsc.replacingOccurrences(of: "\0", with: "\\0")
	}

	fileprivate func sanitize(_ string: String) -> SQLite.Data {
		return .text(Settings.escape(string))
	}
}

private class GlobalSettings: Settings {
	static let table = Settings.globalTableName
	var table: String {
		return GlobalSettings.table
	}

	private var internalCache: [String: SQLite.Data]?
	private var cache: [String: SQLite.Data] {
		get {
			assert(Thread.isMainThread)
			if let cache = internalCache {
				return cache
			}
			let result = try! db.execute("SELECT key, value FROM \(table)")
			internalCache = makeCache(from: result)
			return internalCache!
		}
		set {
			assert(Thread.isMainThread)
			internalCache = newValue
		}
	}

	static let instance = GlobalSettings()

	override func value(for key: String) -> SQLite.Data? {
		return cache[key]
	}

	override var allValues: [String: SQLite.Data] {
		return cache
	}

	override func set(_ value: SQLite.Data, for key: String) {
		assert(Thread.isMainThread)
		notifyListenersOfNewValue(value, for: key, alreadySet: false)
		try! db.execute("REPLACE INTO \(table) (key, value) VALUES (?, ?)", with: [sanitize(key), value])
		internalCache?[key] = value
		notifyListenersOfNewValue(value, for: key, alreadySet: true)
	}

	override func unsetValue(for key: String) {
		assert(Thread.isMainThread)
		notifyListenersOfNewValue(nil, for: key, alreadySet: false)
		internalCache?[key] = nil
		try! db.execute("DELETE FROM \(table) WHERE key = ?", with: [sanitize(key)])
		notifyListenersOfNewValue(nil, for: key, alreadySet: true)
	}

	override func unsetAllValues() {
		internalCache = [:]
		try! db.execute("DELETE FROM \(table)")
		notifyAllListenersOfClear(finished: true)
	}
}

private class TabSettings: Settings, SettingsListener {
	static let table = Settings.tabTableName
	var table: String {
		return TabSettings.table
	}
	var globalSettings: GlobalSettings {
		return GlobalSettings.instance
	}

	let tabId: Int64
	private var internalCache: [String: SQLite.Data]?
	private var cache: [String: SQLite.Data] {
		get {
			assert(Thread.isMainThread)
			if let cache = internalCache {
				return cache
			}
			let result = try! db.execute("SELECT key, value FROM \(table) WHERE tab_id = ?", with: [.integer(tabId)])
			internalCache = makeCache(from: result)
			return internalCache!
		}
		set {
			assert(Thread.isMainThread)
			internalCache = newValue
		}
	}

	init(tab: Tab) {
		tabId = tab.id
	}

	static var cache = [Int64: TabSettings]()
	static func instance(for tab: Tab) -> TabSettings {
		assert(Thread.isMainThread)
		if let settings = cache[tab.id] {
			return settings
		}
		let settings = TabSettings(tab: tab)
		cache[tab.id] = settings
		return settings
	}

	static func dropChacheFor(tab: Tab) {
		cache[tab.id] = nil
	}

	static func copyData(from: Tab, to: Tab) {
		assert(Thread.isMainThread)
		try! db.execute("DELETE FROM \(table) WHERE tab_id = ?", with: [.integer(to.id)])
		let query = "INSERT INTO \(table) (tab_id, key, value) SELECT ?, key, value FROM \(table) WHERE tab_id = ?"
		try! db.execute(query, with: [.integer(to.id), .integer(from.id)])
		TabSettings.instance(for: to).internalCache = nil
	}

	override func value(for key: String) -> SQLite.Data? {
		if let value = cache[key] {
			return value
		}
		return globalSettings.value(for: key)
	}

	override var allValues: [String: SQLite.Data] {
		return cache
	}

	override func set(_ value: SQLite.Data, for key: String) {
		assert(Thread.isMainThread)
		notifyListenersOfNewValue(value, for: key, alreadySet: false)
		try! db.execute("REPLACE INTO \(table) (tab_id, key, value) VALUES (?, ?, ?)", with: [.integer(tabId), sanitize(key), value])
		internalCache?[key] = value
		notifyListenersOfNewValue(value, for: key, alreadySet: true)
	}

	override func unsetValue(for key: String) {
		assert(Thread.isMainThread)
		let globalValue = globalSettings.value(for: key)
		notifyListenersOfNewValue(globalValue, for: key, alreadySet: false)
		internalCache?[key] = nil
		try! db.execute("DELETE FROM \(table) WHERE tab_id = ? AND key = ?", with: [.integer(tabId), sanitize(key)])
		notifyListenersOfNewValue(globalValue, for: key, alreadySet: true)
	}

	override func unsetAllValues() {
		assert(Thread.isMainThread)
		notifyAllListenersOfClear(finished: false)
		internalCache = [:]
		try! db.execute("DELETE FROM \(table) WHERE tab_id = ?", with: [.integer(tabId)])
		notifyAllListenersOfClear(finished: true)
	}

	override func notifyAllListenersOfClear(finished: Bool) {
		for (key, keyListeners) in listeners {
			for listener in keyListeners {
				let globalValue = globalSettings.value(for: key)
				if finished {
					listener.value?.settings(self, didChangeValueFor: key, toValue: globalValue)
				} else {
					listener.value?.settings(self, willChangeValueFor: key, toValue: globalValue)
				}
			}
		}
	}

	override func add(listener: SettingsListener, for key: String) {
		if !addListenerAlreadyHadListener(listener, for: key) {
			globalSettings.add(listener: self, for: key)
		}
	}

	override func remove(listener: SettingsListener, for key: String) {
		if !removeListenerHasListenerLeft(listener, for: key) {
			globalSettings.remove(listener: listener, for: key)
		}
	}

	func settings(_ settings: Settings, willChangeValueFor key: String, toValue: SQLite.Data?) {
		if cache[key] == nil {
			notifyListenersOfNewValue(toValue, for: key, alreadySet: false)
		}
	}

	func settings(_ settings: Settings, didChangeValueFor key: String, toValue: SQLite.Data?) {
		if cache[key] == nil {
			notifyListenersOfNewValue(toValue, for: key, alreadySet: true)
		}
	}

	override func receivedMemoryWarning() {
		internalCache = nil
	}
}

private class GlobalPageSettings: Settings {
	static let table = Settings.pageTableName
	var table: String {
		return GlobalPageSettings.table
	}

	let domain: String
	private var internalCache: [String: SQLite.Data]?
	private var cache: [String: SQLite.Data] {
		get {
			assert(Thread.isMainThread)
			if let cache = internalCache {
				return cache
			}
			let result = try! db.execute("SELECT key, value FROM \(table) WHERE domain = ?", with: [sanitize(domain)])
			internalCache = makeCache(from: result)
			return internalCache!
		}
		set {
			assert(Thread.isMainThread)
			internalCache = newValue
		}
	}

	init(domain: String) {
		self.domain = domain
	}

	static var cache = [String: GlobalPageSettings]()
	static func instance(for domain: String) -> GlobalPageSettings {
		assert(Thread.isMainThread)
		if let settings = cache[domain] {
			return settings
		}
		let settings = GlobalPageSettings(domain: domain)
		cache[domain] = settings
		return settings
	}

	static func clearSettings(for domain: PolicyDomain) {
		let wasCached = cache[domain.domain] != nil
		let settings = GlobalPageSettings.instance(for: domain.domain)
		settings.unsetAllValues()
		if !wasCached {
			cache[domain.domain] = nil
		}
	}

	static func clearAllPageSettings() {
		assert(Thread.isMainThread)
		try! db.execute("DELETE FROM \(table)")
		for (_, settings) in cache {
			settings.internalCache = [:]
		}
	}

	override func value(for key: String) -> SQLite.Data? {
		return cache[key]
	}

	override var allValues: [String: SQLite.Data] {
		return cache
	}

	override func set(_ value: SQLite.Data, for key: String) {
		assert(Thread.isMainThread)
		notifyListenersOfNewValue(value, for: key, alreadySet: false)
		try! db.execute("REPLACE INTO \(table) (domain, key, value) VALUES (?, ?, ?)", with: [sanitize(domain), sanitize(key), value])
		internalCache?[key] = value
		notifyListenersOfNewValue(value, for: key, alreadySet: true)
	}

	override func unsetValue(for key: String) {
		assert(Thread.isMainThread)
		notifyListenersOfNewValue(nil, for: key, alreadySet: false)
		internalCache?[key] = nil
		try! db.execute("DELETE FROM \(table) WHERE domain = ? AND key = ?", with: [sanitize(domain), sanitize(key)])
		notifyListenersOfNewValue(nil, for: key, alreadySet: true)
	}

	override func unsetAllValues() {
		assert(Thread.isMainThread)
		notifyAllListenersOfClear(finished: false)
		internalCache = [:]
		try! db.execute("DELETE FROM \(table) WHERE domain = ?", with: [sanitize(domain)])
		notifyAllListenersOfClear(finished: true)
	}

	override func receivedMemoryWarning() {
		internalCache = nil
	}
}

private class TabPageSettings: Settings, SettingsListener {
	let pageSettings: GlobalPageSettings
	let tabSettings: TabSettings

	private struct TabPage: Hashable {
		let tab: Int64
		let page: String

		var hashValue: Int {
			return tab.hashValue ^ page.hashValue
		}

		static func ==(_ lhs: TabPage, _ rhs: TabPage) -> Bool {
			return lhs.tab == rhs.tab && lhs.page == rhs.page
		}
	}

	private static var values: [TabPage: [String: SQLite.Data]] = [:]

	static func copyData(from: Tab, to: Tab) {
		let tabData = values.filter { $0.key.tab == from.id }
		let toData = values.filter { $0.key.tab == to.id }
		for (key, _) in toData {
			TabPageSettings(domain: key.page, tab: to).values = [:]
		}
		for (key, values) in tabData {
			let toSetting = TabPageSettings(domain: key.page, tab: to)
			toSetting.values = values
		}
	}

	private var valuesKey: TabPage {
		return TabPage(tab: tabSettings.tabId, page: pageSettings.domain)
	}

	private var values: [String: SQLite.Data] {
		get {
			return TabPageSettings.values[valuesKey] ?? [:]
		}
		set {
			TabPageSettings.values[valuesKey] = newValue
		}
	}

	private init(domain: String, tab: Tab) {
		pageSettings = GlobalPageSettings.instance(for: domain)
		tabSettings = TabSettings.instance(for: tab)
	}

	static func instance(for domain: PolicyDomain, in tab: Tab) -> TabPageSettings {
		return TabPageSettings(domain: domain.domain, tab: tab)
	}

	override func value(for key: String) -> SQLite.Data? {
		if let value = values[key] {
			return value
		} else if let value = pageSettings.value(for: key) {
			return value
		} else {
			return tabSettings.value(for: key)
		}
	}

	override var allValues: [String: SQLite.Data] {
		var values = tabSettings.allValues
		for (key, value) in pageSettings.allValues {
			values[key] = value
		}
		for (key, value) in values {
			values[key] = value
		}
		return values
	}

	override func add(listener: SettingsListener, for key: String) {
		if !addListenerAlreadyHadListener(listener, for: key) {
			tabSettings.add(listener: self, for: key)
			pageSettings.add(listener: self, for: key)
		}
	}

	override func remove(listener: SettingsListener, for key: String) {
		if !removeListenerHasListenerLeft(listener, for: key) {
			tabSettings.remove(listener: listener, for: key)
			pageSettings.remove(listener: listener, for: key)
		}
	}

	func settings(_ settings: Settings, willChangeValueFor key: String, toValue: SQLite.Data?) {
		if settings === tabSettings {
			if pageSettings.value(for: key) == nil {
				notifyListenersOfNewValue(toValue, for: key, alreadySet: false)
			}
		} else {
			let newValue = toValue ?? tabSettings.value(for: key)
			notifyListenersOfNewValue(newValue, for: key, alreadySet: false)
		}
	}

	func settings(_ settings: Settings, didChangeValueFor key: String, toValue: SQLite.Data?) {
		guard values[key] == nil else {
			return
		}
		if settings === tabSettings {
			if pageSettings.value(for: key) == nil {
				notifyListenersOfNewValue(toValue, for: key, alreadySet: true)
			}
		} else {
			let newValue = toValue ?? tabSettings.value(for: key)
			notifyListenersOfNewValue(newValue, for: key, alreadySet: true)
		}
	}

	override func set(_ value: SQLite.Data, for key: String) {
		notifyListenersOfNewValue(value, for: key, alreadySet: false)
		values[key] = value
		notifyListenersOfNewValue(value, for: key, alreadySet: true)
	}

	override func unsetValue(for key: String) {
		notifyListenersOfNewValue(nil, for: key, alreadySet: false)
		values[key] = nil
		notifyListenersOfNewValue(nil, for: key, alreadySet: true)
	}

	override func unsetAllValues() {
		notifyAllListenersOfClear(finished: false)
		values = [:]
		notifyAllListenersOfClear(finished: true)
	}
}
