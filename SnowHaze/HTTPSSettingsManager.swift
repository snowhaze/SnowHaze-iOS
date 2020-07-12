//
//  HTTPSSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class HTTPSSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("https settings explanation", comment: "explanations of the https settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.https]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let uiSwitch = makeSwitch()
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("try https first setting title", comment: "title of try https first setting")
			uiSwitch.isOn = bool(for: tryHTTPSfirstKey)
			uiSwitch.addTarget(self, action: #selector(toggleHTTPSFirst(_:)), for: .valueChanged)
		} else if indexPath.row == 1 {
			cell.textLabel?.text = NSLocalizedString("use https exclusively when possible setting title", comment: "title of use https exclusively when possible setting")
			uiSwitch.isOn = bool(for: useHTTPSExclusivelyWhenPossibleKey)
			uiSwitch.addTarget(self, action: #selector(toggleExtendedHSTSPreload(_:)), for: .valueChanged)
		} else if indexPath.row == 2 {
			cell.textLabel?.text = NSLocalizedString("mixed content blocking setting title", comment: "title of mixed content blocking setting")
			uiSwitch.isOn = bool(for: blockMixedContentKey)
			uiSwitch.addTarget(self, action: #selector(toggleMixedContentBlocking(_:)), for: .valueChanged)
		} else if indexPath.row == 3 {
		   cell.textLabel?.text = NSLocalizedString("require https for trusted sites setting title", comment: "title of setting to force the use of https on trusted sites")
		   uiSwitch.isOn = bool(for: requireHTTPSForTrustedSitesKey)
		   uiSwitch.addTarget(self, action: #selector(toggleHTTPSOnTrusted(_:)), for: .valueChanged)
		} else {
			cell.textLabel?.text = NSLocalizedString("upgrade all http connections setting title", comment: "title of upgrade all http connections setting")
			uiSwitch.isOn = bool(for: upgradeAllHTTPKey)
			uiSwitch.addTarget(self, action: #selector(toggleHTTPSOnly(_:)), for: .valueChanged)
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 5
	}

	@objc private func toggleHTTPSFirst(_ sender: UISwitch) {
		set(sender.isOn, for: tryHTTPSfirstKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleExtendedHSTSPreload(_ sender: UISwitch) {
		set(sender.isOn, for: useHTTPSExclusivelyWhenPossibleKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleMixedContentBlocking(_ sender: UISwitch) {
		set(sender.isOn, for: blockMixedContentKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleHTTPSOnTrusted(_ sender: UISwitch) {
		set(sender.isOn, for: requireHTTPSForTrustedSitesKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleHTTPSOnly(_ sender: UISwitch) {
		set(sender.isOn, for: upgradeAllHTTPKey)
		updateHeaderColor(animated: true)
	}
}
