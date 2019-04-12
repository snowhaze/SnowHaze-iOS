//
//  SettingsDefaultWrapper.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private class WeakListener {
	weak var value : SettingsListener?
	init (value: SettingsListener) {
		self.value = value
	}
}

class SettingsDefaultWrapper: SettingsListener {
	let defaults: [String: SQLite.Data]
	let settings: Settings
	static var standardDefaults: [String: SQLite.Data]!
	private var listeners = [String: [WeakListener]]()

	class var dataAvailable: Bool {
		return Settings.dataAvailable
	}

	static func wrapGlobalSettings() -> SettingsDefaultWrapper {
		let settings = Settings.globalSettings()
		return SettingsDefaultWrapper(defaults: standardDefaults, settings: settings)
	}

	static func wrapSettings(for tab: Tab) -> SettingsDefaultWrapper {
		let settings = Settings.settings(for: tab)
		return SettingsDefaultWrapper(defaults: standardDefaults, settings: settings)
	}

	static func wrapSettings(for domain: PolicyDomain, inTab tab: Tab) -> SettingsDefaultWrapper {
		let settings = Settings.settings(for: domain, in: tab)
		return SettingsDefaultWrapper(defaults: standardDefaults, settings: settings)
	}

	init(defaults: [String: SQLite.Data], settings: Settings) {
		self.defaults = defaults
		self.settings = settings
	}

	func add(listener: SettingsListener, for key: String) {
		if !addListenerAlreadyHadListener(listener, for: key) {
			settings.add(listener: self, for: key)
		}
	}

	func remove(listener: SettingsListener, for key: String) {
		if !removeListenerHasListenerLeft(listener, for: key) {
			settings.remove(listener: self, for: key)
		}
	}

	func settings(_ settings: Settings, willChangeValueFor key: String, toValue: SQLite.Data?) {
		notifyListenersOfNewValue(toValue, for: key, alreadySet: false)
	}

	func settings(_ settings: Settings, didChangeValueFor key: String, toValue: SQLite.Data?) {
		notifyListenersOfNewValue(toValue, for: key, alreadySet: true)
	}

	func value(for key: String) -> SQLite.Data {
		return settings.value(for: key) ?? defaults[key]!
	}

	func set(_ value: SQLite.Data, for key: String) {
		settings.set(value, for: key)
	}

	func unsetValue(for key: String) {
		settings.unsetValue(for: key)
	}

	func unsetAllValues() {
		settings.unsetAllValues()
	}

	private func addListenerAlreadyHadListener(_ listener: SettingsListener, for key: String) -> Bool {
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

	private func removeListenerHasListenerLeft(_ listener: SettingsListener, for key: String) -> Bool {
		guard var array = listeners[key] else {
			return false
		}
		if let index = array.firstIndex(where: { $0.value === listener }) {
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

	private func notifyListenersOfNewValue(_ value: SQLite.Data?, for key: String, alreadySet: Bool) {
		let newValue = value ?? defaults[key]!
		if let keyListeners = listeners[key] {
			for listener in keyListeners {
				if alreadySet {
					listener.value?.settings(settings, didChangeValueFor: key, toValue: newValue)
				} else {
					listener.value?.settings(settings, willChangeValueFor: key, toValue: newValue)
				}
			}
		}
	}
}
