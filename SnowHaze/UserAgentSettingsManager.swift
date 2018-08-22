//
//  UserAgentSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class UserAgentSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("user agent settings explanation", comment: "explanations of the user agent settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.userAgent]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let agent = UserAgent(type: UserAgent.mobileAgents[indexPath.row])
		let agents = UserAgent.decode(settings.value(for: userAgentsKey).text!)
		cell.textLabel?.text = agent.displayName
		let selected = agents.contains(agent.type)
		cell.accessoryType = selected ? .checkmark : .none
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return UserAgent.mobileAgents.count
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
}
