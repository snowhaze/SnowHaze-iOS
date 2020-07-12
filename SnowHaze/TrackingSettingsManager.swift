//
//  TrackingSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class TrackingSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("tracking protection settings explanation", comment: "explanations of the tracking protection settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.tracking]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let uiSwitch = makeSwitch()
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("block referer setting title", comment: "title of block referer setting")
			uiSwitch.isOn = bool(for: blockHTTPReferrersKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockReferrer(_:)), for: .valueChanged)
		} else if indexPath.row == 1 {
			cell.textLabel?.text = NSLocalizedString("block tracking scripts setting title", comment: "title of block tracking scripts setting")
			uiSwitch.isOn = bool(for: blockTrackingScriptsKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockTrackingScripts(_:)), for: .valueChanged)
		}  else if indexPath.row == 2 {
			cell.textLabel?.text = NSLocalizedString("block ads setting title", comment: "title of block ads setting")
			uiSwitch.isOn = bool(for: blockAdsKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockAds(_:)), for: .valueChanged)
		} else if indexPath.row == 3 {
			cell.textLabel?.text = NSLocalizedString("block canvas data access setting title", comment: "title of block canvas data access setting")
			uiSwitch.isOn = bool(for: blockCanvasDataAccessKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockCanvasDataAccess(_:)), for: .valueChanged)
		} else if indexPath.row == 4 {
			cell.textLabel?.text = NSLocalizedString("block fingerprinting setting title", comment: "title of block fingerprinting setting")
			uiSwitch.isOn = bool(for: blockFingerprintingKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockFingerprinting(_:)), for: .valueChanged)
		} else if indexPath.row == 5 {
			cell.textLabel?.text = NSLocalizedString("block social media widgets setting title", comment: "title of block social media widgets setting")
			uiSwitch.isOn = bool(for: blockSocialMediaWidgetsKey)
			uiSwitch.addTarget(self, action: #selector(toggleBlockSocialMediaWidgets(_:)), for: .valueChanged)
		} else if indexPath.row == 6 {
			cell.textLabel?.text = NSLocalizedString("apply hide only rules setting title", comment: "title of apply hide only rules setting")
			uiSwitch.isOn = bool(for: applyHideOnlyBlockRulesKey)
			uiSwitch.addTarget(self, action: #selector(toggleApplyHideOnly(_:)), for: .valueChanged)
		} else {
			cell.textLabel?.text = NSLocalizedString("skip redirects setting title", comment: "title of skip redirects setting")
			uiSwitch.isOn = bool(for: skipRedirectsKey)
			uiSwitch.addTarget(self, action: #selector(toggleSkipRedirectsOnly(_:)), for: .valueChanged)
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 8
	}

	@objc private func toggleBlockReferrer(_ sender: UISwitch) {
		set(sender.isOn, for: blockHTTPReferrersKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleBlockTrackingScripts(_ sender: UISwitch) {
		set(sender.isOn, for: blockTrackingScriptsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleBlockAds(_ sender: UISwitch) {
		set(sender.isOn, for: blockAdsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleBlockCanvasDataAccess(_ sender: UISwitch) {
		set(sender.isOn, for: blockCanvasDataAccessKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleBlockFingerprinting(_ sender: UISwitch) {
		set(sender.isOn, for: blockFingerprintingKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleBlockSocialMediaWidgets(_ sender: UISwitch) {
		set(sender.isOn, for: blockSocialMediaWidgetsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleApplyHideOnly(_ sender: UISwitch) {
		set(sender.isOn, for: applyHideOnlyBlockRulesKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleSkipRedirectsOnly(_ sender: UISwitch) {
		set(sender.isOn, for: skipRedirectsKey)
		updateHeaderColor(animated: true)
	}
}
