//
//  HTTPSSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

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
			uiSwitch.addTarget(self, action: #selector(toggleHTTPSOnly(_:)), for: .valueChanged)
		} else {
			cell.textLabel?.text = NSLocalizedString("mixed content blocking setting title", comment: "title of mixed content blocking setting")
			uiSwitch.isOn = bool(for: blockMixedContentKey)
			uiSwitch.addTarget(self, action: #selector(toggleMixedContentBlocking(_:)), for: .valueChanged)
			if #available(iOS 11, *) {
				// obviouly don't show the notice
			} else {
				cell.detailTextLabel?.text = NSLocalizedString("mixed content blocking requires ios 11 notice", comment: "notice displayed on iOS 10 and lower devices to indicate that mixed content blocking requires ios 11 or newer")
			}
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 3
	}

	@objc private func toggleHTTPSFirst(_ sender: UISwitch) {
		set(sender.isOn, for: tryHTTPSfirstKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleHTTPSOnly(_ sender: UISwitch) {
		set(sender.isOn, for: useHTTPSExclusivelyWhenPossibleKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleMixedContentBlocking(_ sender: UISwitch) {
		set(sender.isOn, for: blockMixedContentKey)
		updateHeaderColor(animated: true)
	}
}
