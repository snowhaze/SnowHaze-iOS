//
//  DefaultsSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class DefaultsSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("defaults settings explanation", comment: "explanations of the defaults settings")
	}

	override var assessmentResultColor: UIColor {
		let categories = PolicyAssessor.allCategories
		return PolicyAssessor(wrapper: settings).assess(categories).color
	}

	override func viewWillAppear(_ animated: Bool) {
		updateHeaderColor(animated: animated)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let button = makeButton(for: cell)
		if indexPath.row == 0 {
			let title = NSLocalizedString("reset global settings button title", comment: "title of button to reset global settings to defaults")
			button.setTitle(title, for: [])
			button.addTarget(self, action: #selector(resetSettings(_:)), for: .touchUpInside)
		} else if indexPath.row == 1 {
			let title = NSLocalizedString("reset page settings button title", comment: "title of button to reset per page settings to defaults")
			button.setTitle(title, for: [])
			button.addTarget(self, action: #selector(resetPageSettings(_:)), for: .touchUpInside)
		} else {
			let title = NSLocalizedString("restart tutorial settings button title", comment: "title of button to restart the tutorial")
			button.setTitle(title, for: [])
			button.addTarget(self, action: #selector(showTutorial(_:)), for: .touchUpInside)
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 3
	}

	@objc private func resetSettings(_ sender: UIButton) {
		let reset = {
			var resoreKeys = [lastTutorialVersionKey, lastOpenedVersionKey, lastEOLWarningVersionKey, doNotResetAutoUpdateKey]
			if self.bool(for: doNotResetAutoUpdateKey) {
				resoreKeys += [updateSiteListsKey, updateVPNListKey, updateAuthorizationTokenKey, updateSubscriptionProductListKey]
			} else {
				DomainList.set(updating: false)
			}
			let resore = resoreKeys.map { ($0, self.settings.value(for: $0)) }
			Settings.atomically {
				self.settings.unsetAllValues()
				for (key, value) in resore {
					self.settings.set(value, for: key)
				}
			}
			self.updateHeaderColor(animated: true)
			MainViewController.controller.updateNightMode()
			ReviewPrompt.settingsReset()
		}
		let alert = AlertType.resetSettings(reset: reset).build()
		alert.popoverPresentationController?.sourceView = sender
		alert.popoverPresentationController?.sourceRect = sender.bounds
		controller.present(alert, animated: true, completion: nil)
	}

	@objc private func resetPageSettings(_ sender: UIButton) {
		let reset = {
			Settings.unsetAllPageSettings()
			ReviewPrompt.settingsReset()
		}
		let alert = AlertType.resetPageSettings(reset: reset).build()
		alert.popoverPresentationController?.sourceView = sender
		alert.popoverPresentationController?.sourceRect = sender.bounds
		controller.present(alert, animated: true, completion: nil)
	}

	@objc private func showTutorial(_ sender: UIButton) {
		let tutorial = InstallTutorialViewController()
		controller.present(tutorial, animated: true, completion: nil)
	}
}
