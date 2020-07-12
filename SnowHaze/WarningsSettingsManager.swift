//
//  WarningsSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class WarningsSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("warnings settings explanation", comment: "explanations of the warings settings tab")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.warnings]).color
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 5
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let uiSwitch = makeSwitch()
		cell.accessoryView = uiSwitch
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("show dangerous sites warnings setting title", comment: "title of show dangerous sites warnings setting")
			uiSwitch.addTarget(self, action: #selector(toggleDangerWarnings(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: showDangerousSitesWarningsKey)
		} else if indexPath.row == 1 {
			cell.textLabel?.text = NSLocalizedString("show tls certificate warnings setting title", comment: "title of show tls certificate warnings setting")
			uiSwitch.addTarget(self, action: #selector(toggleTLSCertWarnings(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: showTLSCertificateWarningsKey)
		} else if indexPath.row == 2 {
			cell.textLabel?.text = NSLocalizedString("show tracking parameters warnings setting title", comment: "title of show tracking parameters warnings setting")
			uiSwitch.addTarget(self, action: #selector(toggleTrackingParametersWarnings(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: stripTrackingURLParametersKey)
		} else if indexPath.row == 3 {
			cell.textLabel?.text = NSLocalizedString("prevent xss setting title", comment: "title of prevent xss setting")
			uiSwitch.addTarget(self, action: #selector(toggleXSSWarnings(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: preventXSSKey)
		} else {
			cell.textLabel?.text = NSLocalizedString("warn cross frame navigation setting title", comment: "title of warn cross frame navigation setting")
			uiSwitch.addTarget(self, action: #selector(toggleCrossFrameNavigation(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: warnCrossFrameNavigationKey)
		}
		return cell
	}

	@objc private func toggleDangerWarnings(_ sender: UISwitch) {
		set(sender.isOn, for: showDangerousSitesWarningsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleTLSCertWarnings(_ sender: UISwitch) {
		set(sender.isOn, for: showTLSCertificateWarningsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleTrackingParametersWarnings(_ sender: UISwitch) {
		set(sender.isOn, for: stripTrackingURLParametersKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleXSSWarnings(_ sender: UISwitch) {
		set(sender.isOn, for: preventXSSKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleCrossFrameNavigation(_ sender: UISwitch) {
		set(sender.isOn, for: warnCrossFrameNavigationKey)
		updateHeaderColor(animated: true)
	}
}
