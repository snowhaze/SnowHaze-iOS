//
//  JavaScriptSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class JavaScriptSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("javascript settings explanation", comment: "explanations of the javascript settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.javaScript]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let uiSwitch = makeSwitch()
		let cell = getCell(for: tableView)
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("allow javascript setting title", comment: "title of allow javascript setting")
			uiSwitch.isOn = bool(for: allowJavaScriptKey)
			uiSwitch.addTarget(self, action: #selector(toggleAllowJS(_:)), for: .valueChanged)
		} else if indexPath.row == 1 {
			cell.textLabel?.text = NSLocalizedString("allow application script setting title", comment: "title of allow application controlled javascript setting")
			uiSwitch.isOn = bool(for: allowApplicationJavaScriptKey)
			uiSwitch.addTarget(self, action: #selector(toggleAllowApplicationJS(_:)), for: .valueChanged)
		} else if indexPath.row == 2 {
			cell.textLabel?.text = NSLocalizedString("allow password manager gather script setting title", comment: "title of allow password manager gather script setting")
			uiSwitch.isOn = bool(for: allowPasswordManagerIntegrationKey)
			uiSwitch.addTarget(self, action: #selector(togglePasswordManagerIntegration(_:)), for: .valueChanged)
		} else {
			cell.textLabel?.text = NSLocalizedString("allow js urls setting title", comment: "title of allow js urls setting")
			uiSwitch.isOn = bool(for: allowJSURLsInURLBarKey)
			uiSwitch.addTarget(self, action: #selector(toggleAllowJSURLs(_:)), for: .valueChanged)
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 4
	}

	@objc private func toggleAllowJS(_ sender: UISwitch) {
		set(sender.isOn, for: allowJavaScriptKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleAllowApplicationJS(_ sender: UISwitch) {
		set(sender.isOn, for: allowApplicationJavaScriptKey)
		updateHeaderColor(animated: true)
	}

	@objc private func togglePasswordManagerIntegration(_ sender: UISwitch) {
		set(sender.isOn, for: allowPasswordManagerIntegrationKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleAllowJSURLs(_ sender: UISwitch) {
		set(sender.isOn, for: allowJSURLsInURLBarKey)
		updateHeaderColor(animated: true)
	}
}
