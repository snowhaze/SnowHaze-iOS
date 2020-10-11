//
//  WebsiteDataSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit
import UIKit

class WebsiteDataSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("website data settings explanation", comment: "explanations of the website data settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.websiteData]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("save website data setting title", comment: "title of save website data records setting")
			uiSwitch.isOn = bool(for: allowPermanentDataStorageKey)
			uiSwitch.addTarget(self, action: #selector(toggleDataStorage(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
		} else if indexPath.section == 1 {
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("block cookies setting none option", comment: "option to not block cookies of the block cookies setting")
			} else if indexPath.row == 1 {
				cell.textLabel?.text = NSLocalizedString("block cookies setting third party option", comment: "option to block third party cookies of the block cookies setting")
			} else {
				cell.textLabel?.text = NSLocalizedString("block cookies setting all option", comment: "option to block all cookies of the block cookies setting")
			}
			let currentRow = Int(settings.value(for: cookieBlockingPolicyKey).integer!)
			cell.accessoryType = indexPath.row == currentRow ? .checkmark : .none
		} else if indexPath.section == 2 {
			let button = makeButton(for: cell)
			let title: String
			if indexPath.row == 0 {
				title = NSLocalizedString("delete all data button title", comment: "title of button to delete all website data records")
				button.addTarget(self, action: #selector(clearAllData(_:)), for: .touchUpInside)
			} else if indexPath.row == 1 {
				title = NSLocalizedString("delete cache data button title", comment: "title of button to delete website cache data records")
				button.addTarget(self, action: #selector(clearCacheData(_:)), for: .touchUpInside)
			} else if indexPath.row == 2 {
				title = NSLocalizedString("delete cookies button title", comment: "title of button to delete website cookies")
				button.addTarget(self, action: #selector(clearCookies(_:)), for: .touchUpInside)
			} else if indexPath.row == 3 {
				title = NSLocalizedString("delete data stores button title", comment: "title of button to delete website data stores records")
				button.addTarget(self, action: #selector(clearDataStores(_:)), for: .touchUpInside)
			} else {
				title = NSLocalizedString("delete tracking cookies button title", comment: "title of button to delete tracking cookies")
				button.addTarget(self, action: #selector(clearTrackingCookies(_:)), for: .touchUpInside)
			}
			button.setTitle(title, for: [])
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		if section == 0 {
			return 1
		} else if section == 1 {
			return 3
		} else {
			return 5
		}
	}

	override var numberOfSections: Int {
		return 3
	}

	override func titleForHeader(inSection section: Int) -> String? {
		if section == 1 {
			return NSLocalizedString("cookie blocking settings title", comment: "title of settings section to set the cookie blocking mode")
		} else {
			return super.titleForHeader(inSection: section)
		}
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		return section == 1 ? 40 : super.heightForHeader(inSection: section)
	}

	@objc private func toggleDataStorage(_ sender: UISwitch) {
		set(sender.isOn, for: allowPermanentDataStorageKey)
		updateHeaderColor(animated: true)
	}

	@objc private func clearAllData(_ sender: UIButton) {
		let store = WKWebsiteDataStore.default()
		let types = WKWebsiteDataStore.allWebsiteDataTypes()
		store.fetchDataRecords(ofTypes: types) { [weak self] records in
			let alert = AlertType.deleteAllWebsiteData(count: records.count, delete: { store.removeData(ofTypes: types, for: records) { } }).build()
			alert.popoverPresentationController?.sourceView = sender
			alert.popoverPresentationController?.sourceRect = sender.bounds
			self?.controller?.present(alert, animated: true, completion: nil)
		}
	}

	@objc private func clearCacheData(_ sender: UIButton) {
		let store = WKWebsiteDataStore.default()
		let types = Set<String>(arrayLiteral: WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeOfflineWebApplicationCache)
		store.fetchDataRecords(ofTypes: types) { [weak self] records in
			let alert = AlertType.deleteCacheWebsiteData(count: records.count, delete: { store.removeData(ofTypes: types, for: records) { } }).build()
			alert.popoverPresentationController?.sourceView = sender
			alert.popoverPresentationController?.sourceRect = sender.bounds
			self?.controller?.present(alert, animated: true, completion: nil)
		}
	}

	@objc private func clearCookies(_ sender: UIButton) {
		let store = WKWebsiteDataStore.default()
		let types = Set<String>(arrayLiteral: WKWebsiteDataTypeCookies)
		store.fetchDataRecords(ofTypes: types) { [weak self] records in
			let alert = AlertType.deleteCookieWebsiteData(count: records.count, delete: { store.removeData(ofTypes: types, for: records) { } }).build()
			alert.popoverPresentationController?.sourceView = sender
			alert.popoverPresentationController?.sourceRect = sender.bounds
			self?.controller?.present(alert, animated: true, completion: nil)
		}
	}

	@objc private func clearDataStores(_ sender: UIButton) {
		let store = WKWebsiteDataStore.default()
		let types = Set<String>(arrayLiteral: WKWebsiteDataTypeSessionStorage, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeWebSQLDatabases, WKWebsiteDataTypeIndexedDBDatabases)
		store.fetchDataRecords(ofTypes: types) { [weak self] records in
			let alert = AlertType.deleteOtherWebsiteData(count: records.count, delete: { store.removeData(ofTypes: types, for: records) { } }).build()
			alert.popoverPresentationController?.sourceView = sender
			alert.popoverPresentationController?.sourceRect = sender.bounds
			self?.controller?.present(alert, animated: true, completion: nil)
		}
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == 1 {
			let oldRow = Int(settings.value(for: cookieBlockingPolicyKey).integer!)
			guard indexPath.row != oldRow else {
				return
			}
			let policy = CookieBlockingPolicy(rawValue: Int64(indexPath.row))!
			settings.set(.integer(policy.rawValue), for: cookieBlockingPolicyKey)
			updateHeaderColor(animated: true)
			tableView.cellForRow(at: IndexPath(row: oldRow, section: indexPath.section))?.accessoryType = .none
			tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
	}

	@objc private func clearTrackingCookies(_ sender: UIButton) {
		let store = WKWebsiteDataStore.default()
		let types = Set<String>(arrayLiteral: WKWebsiteDataTypeCookies)
		store.fetchDataRecords(ofTypes: types) { [weak self] unfilteredRecords in
			let ads = DomainList(type: .ads)
			let tracking = DomainList(type: .trackingScripts)
			let records = unfilteredRecords.filter { ads.contains($0.displayName) || tracking.contains($0.displayName) }
			let alert = AlertType.deleteTrackingCookieWebsiteData(count: records.count, delete: { store.removeData(ofTypes: types, for: records) { } }).build()
			alert.popoverPresentationController?.sourceView = sender
			alert.popoverPresentationController?.sourceRect = sender.bounds
			self?.controller?.present(alert, animated: true, completion: nil)
		}
	}
}
