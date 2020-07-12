//
//  ContentBlockerSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class ContentBlockerSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("content blockers settings explanation", comment: "explanations of the content blockers settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.contentTypeBlocker]).color
	}

	private var blockedTypes: ContentTypes {
		get {
			let rawTypes = settings.value(for: contentTypeBlockerBlockedTypesKey).integer!
			return ContentTypes(rawValue: rawTypes)
		}
		set {
			let rawTypes = SQLite.Data.integer(newValue.rawValue)
			settings.set(rawTypes, for: contentTypeBlockerBlockedTypesKey)
			updateHeaderColor(animated: true)
		}
	}

	private func types(for index: Int) -> ContentTypes {
		switch index {
			case 0:		return .imageTypes
			case 1:		return .styleSheet
			case 2:		return .script
			case 3:		return .thirdPartyScripts
			case 4:		return .font
			case 5:		return .raw
			case 6:		return .media
			default:	fatalError("invalid index")
		}
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			let title: String
			switch indexPath.row {
				case 0:		title = NSLocalizedString("content blocker image content type", comment: "title of setting to block image content from being loaded")
				case 1:		title = NSLocalizedString("content blocker style sheet content type", comment: "title of setting to block style sheet content from being loaded")
				case 2:		title = NSLocalizedString("content blocker script content type", comment: "title of setting to block script content from being loaded")
				case 3:		title = NSLocalizedString("content blocker third party script content type", comment: "title of setting to block third party script content from being loaded")
				case 4:		title = NSLocalizedString("content blocker font content type", comment: "title of setting to block font content from being loaded")
				case 5:		title = NSLocalizedString("content blocker raw content type", comment: "title of setting to block raw content from being loaded")
				case 6:		title = NSLocalizedString("content blocker media content type", comment: "title of setting to block media content from being loaded")
				default:	fatalError("invalid index path")
			}
			let selected = blockedTypes.isSuperset(of: types(for: indexPath.row))
			cell.accessoryType = selected ? .checkmark : .none
			cell.textLabel?.text = title
		} else {
			cell.textLabel?.text = NSLocalizedString("block doh servers setting title", comment: "title of setting to block raw request to known doh servers")
			let uiSwitch = makeSwitch()
			cell.accessoryView = uiSwitch
			uiSwitch.isOn = bool(for: blockDOHServersKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockDOH(_:)), for: .valueChanged)
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return section == 0 ? 7 : 1
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == 0 {
			let oldTypes = blockedTypes
			let selectedTypes = types(for: indexPath.row)
			if oldTypes.isDisjoint(with: selectedTypes) {
				blockedTypes = oldTypes.union(selectedTypes)
			} else {
				blockedTypes = oldTypes.subtracting(selectedTypes)
			}
			tableView.reloadRows(at: [indexPath], with: .automatic)
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
	}

	override var numberOfSections: Int {
		return 2
	}

	@objc private func toggleBlockDOH(_ sender: UISwitch) {
		set(sender.isOn, for: blockDOHServersKey)
		updateHeaderColor(animated: true)
	}
}
