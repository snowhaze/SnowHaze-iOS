//
//  MediaPlaybackSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class MediaPlaybackSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("media playback settings explanation", comment: "explanations of the media playback settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.mediaPlayback]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let uiSwitch = makeSwitch()
		let cell = getCell(for: tableView)
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("require user action for media playback setting title", comment: "title for require user action for media playback setting")
			uiSwitch.isOn = bool(for: requiresUserActionForMediaPlaybackKey)
			uiSwitch.addTarget(self, action: #selector(toggleRequireAction(_:)), for: .valueChanged)
		} else {
			cell.textLabel?.text = NSLocalizedString("allow inline media playback setting title", comment: "title for allow inline media playback setting")
			uiSwitch.isOn = bool(for: allowsInlineMediaPlaybackKey)
			uiSwitch.addTarget(self, action: #selector(toggleAllowInlinePlayback(_:)), for: .valueChanged)
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 2
	}

	@objc private func toggleRequireAction(_ sender: UISwitch) {
		set(sender.isOn, for: requiresUserActionForMediaPlaybackKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleAllowInlinePlayback(_ sender: UISwitch) {
		set(sender.isOn, for: allowsInlineMediaPlaybackKey)
		updateHeaderColor(animated: true)
	}
}
