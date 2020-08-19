//
//  TorSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let sectionIndex = 0
private let useTorRow = 0
private let useTorForAPIRow = 3

class TorSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("tor settings explanation", comment: "explanations of the tor settings tab")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.tor]).color
	}

	private var connectButton: UIButton?

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		assert(sectionIndex == 0)
		assert(useTorRow == 0)
		assert(useTorForAPIRow == 3)
		let cell = getCell(for: tableView)
		if indexPath.row == 0 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("use tor setting title", comment: "title of use tor setting")
			uiSwitch.isOn = bool(for: useTorNetworkKey)
			uiSwitch.addTarget(self, action: #selector(toggleUseTor(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
			if !SubscriptionManager.status.possible {
				if bool(for: useTorNetworkKey) {
					cell.accessoryView = OneWaySwitch(manager: self, action: #selector(toggleUseTor(_:)))
					cell.accessibilityLabel = NSLocalizedString("disable use tor setting missing subscription accessibility label", comment: "accessibility label for the use tor setting when the user does not have an active subscription but the setting is enabled")
				} else {
					cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "blocked"))
					cell.accessibilityLabel = NSLocalizedString("use tor setting missing subscription accessibility label", comment: "accessibility label for the use tor setting when the user does not have an active subscription")
				}
			}
		} else if indexPath.row == 1 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("start tor on launch setting title", comment: "title of start tor on launch setting")
			uiSwitch.isOn = bool(for: startTorOnAppLaunchKey)
			uiSwitch.addTarget(self, action: #selector(toggleStartOnLaunch(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
		} else if indexPath.row == 2 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("send dnt over tor setting title", comment: "title of send dnt header over tor setting")
			uiSwitch.isOn = bool(for: sendDNTHeaderOverTorKey)
			uiSwitch.addTarget(self, action: #selector(toggleDNT(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
		} else if indexPath.row == 3 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("use tor for api calls setting title", comment: "title of use tor for api calls setting")
			uiSwitch.isOn = bool(for: useTorForAPICallsKey)
			uiSwitch.addTarget(self, action: #selector(toggleTorAPI(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
			if !SubscriptionManager.status.possible {
				if bool(for: useTorForAPICallsKey) {
					cell.accessoryView = OneWaySwitch(manager: self, action: #selector(toggleTorAPI(_:)))
					cell.accessibilityLabel = NSLocalizedString("disable use tor for api calls setting missing subscription accessibility label", comment: "accessibility label for the use tor for api calls setting when the user does not have an active subscription but the setting is enabled")
				} else {
					cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "blocked"))
					cell.accessibilityLabel = NSLocalizedString("use tor for api calls setting missing subscription accessibility label", comment: "accessibility label for the use tor for api calls setting when the user does not have an active subscription")
				}
			}
		} else if indexPath.row == 4 {
		   let uiSwitch = makeSwitch()
		   cell.textLabel?.text = NSLocalizedString("rotate tor circuit for new api tokens setting title", comment: "title of rotate tor circuit for new api tokens setting")
		   uiSwitch.isOn = bool(for: rotateCircuitForNewTokensKey)
		   uiSwitch.addTarget(self, action: #selector(toggleRotateCircuitForTokens(_:)), for: .valueChanged)
		   cell.accessoryView = uiSwitch
	   } else if indexPath.row == 5 {
			let progress = makeProgressView(for: cell)
			progress.observedProgress = TorServer.shared.bootstrapProgress
		} else {
			let button = makeButton(for: cell)
			let title = NSLocalizedString("connect tor button title", comment: "title of button to launch the tor thread")
			button.setTitle(title, for: [])
			connectButton = button
			button.isEnabled = !TorServer.shared.running && SubscriptionManager.status.possible
			button.addTarget(self, action: #selector(connect(_:)), for: .touchUpInside)
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 7
	}

	@objc private func toggleUseTor(_ sender: UISwitch) {
		set(sender.isOn, for: useTorNetworkKey)
		updateHeaderColor(animated: true)
		if !SubscriptionManager.status.possible {
			let indexPath = IndexPath(row: useTorRow, section: sectionIndex)
			controller.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}

	@objc private func toggleDNT(_ sender: UISwitch) {
		set(sender.isOn, for: sendDNTHeaderOverTorKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleTorAPI(_ sender: UISwitch) {
		set(sender.isOn, for: useTorForAPICallsKey)
		updateHeaderColor(animated: true)
		if !SubscriptionManager.status.possible {
			let indexPath = IndexPath(row: useTorForAPIRow, section: sectionIndex)
			controller.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}

	@objc private func toggleRotateCircuitForTokens(_ sender: UISwitch) {
		set(sender.isOn, for: rotateCircuitForNewTokensKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleStartOnLaunch(_ sender: UISwitch) {
		set(sender.isOn, for: startTorOnAppLaunchKey)
		if sender.isOn {
			connect(nil)
		}
		updateHeaderColor(animated: true)
	}

	@objc private func connect(_ sender: UIButton?) {
		connectButton?.isEnabled = false
		TorServer.shared.start { [weak self] error in
			self?.connectButton?.isEnabled = error != nil
			if case .noSubscription = error {
				self?.controller?.tableView?.reloadData()
			}
		}
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		let subscribed = SubscriptionManager.status.possible
		if indexPath.section == sectionIndex && indexPath.row == useTorRow && !subscribed && !bool(for: useTorNetworkKey) {
			controller.switchToSubscriptionSettings()
		} else if indexPath.section == sectionIndex && indexPath.row == useTorForAPIRow && !subscribed && !bool(for: useTorForAPICallsKey) {
			controller.switchToSubscriptionSettings()
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
	}
}
