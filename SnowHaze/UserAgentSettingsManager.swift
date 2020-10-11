//
//  UserAgentSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class UserAgentSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("user agent settings explanation", comment: "explanations of the user agent settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.userAgent]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			let agent = UserAgent(type: UserAgent.mobileAgents[indexPath.row])
			let agents = UserAgent.decode(settings.value(for: userAgentsKey).text!)
			cell.textLabel?.text = agent.displayName
			let selected = agents.contains(agent.type)
			cell.accessoryType = selected ? .checkmark : .none
		} else {
			cell.textLabel?.text = NSLocalizedString("render pages as desktop sites setting title", comment: "title of setting to render webpages as desktop sites")
			let uiSwitch = makeSwitch()
			uiSwitch.isOn = bool(for: renderAsDesktopSiteKey)
			uiSwitch.addTarget(self, action: #selector(toggleDesktopRendering(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
			if #available(iOS 13, *) {
				// feature is supported
			} else {
				cell.detailTextLabel?.text = NSLocalizedString("render pages as desktop sites requires ios 13 notice", comment: "notice to inform users that rendering webpages as desktop sites requires ios 13")
			}
		}
		return cell
	}

	override var numberOfSections: Int {
		return 2
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return section == 0 ? UserAgent.mobileAgents.count : 1
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		tableView.deselectRow(at: indexPath, animated: false)
		var agents = UserAgent.decode(settings.value(for: userAgentsKey).text!)
		let toggledAgent = UserAgent.mobileAgents[indexPath.row]
		let wasSelected = agents.contains(toggledAgent)
		guard !(agents.count == 1 && wasSelected) else {
			return
		}
		if wasSelected {
			agents = UserAgent.remove(toggledAgent, from: agents)
		} else {
			agents = UserAgent.add(toggledAgent, to: agents)
		}
		let encodedAgents = UserAgent.encode(agents)
		settings.set(.text(encodedAgents), for: userAgentsKey)
		updateHeaderColor(animated: true)
		if let cell = tableView.cellForRow(at: indexPath) {
			let selected = agents.contains(toggledAgent)
			cell.accessoryType = selected ? .checkmark : .none
		}
	}

	@objc private func toggleDesktopRendering(_ sender: UISwitch) {
		set(sender.isOn, for: renderAsDesktopSiteKey)
		updateHeaderColor(animated: true)
	}
}
