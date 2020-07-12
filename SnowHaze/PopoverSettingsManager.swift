//
//  PopoverSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class PopoverSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("popover settings explanation", comment: "explanations of the popover settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.popover]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let value = settings.value(for: popoverBlockingPolicyKey).integer!
		let isSelected = Int64(indexPath.row) == value
		cell.accessoryType = isSelected ? .checkmark : .none
		let type = PopoverBlockingPolicyType(rawValue: Int64(indexPath.row))!
		cell.textLabel?.text = PopoverBlockingPolicy(type: type).displayName
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 3
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		tableView.deselectRow(at: indexPath, animated: false)
		let newValue = Int64(indexPath.row)
		settings.set(.integer(Int64(indexPath.row)), for: popoverBlockingPolicyKey)
		for cell in tableView.visibleCells {
			if let indexPath = tableView.indexPath(for: cell) {
				let cellSelected = Int64(indexPath.row) == newValue
				cell.accessoryType = cellSelected ? .checkmark : .none
			}
		}
		updateHeaderColor(animated: true)
	}
}
