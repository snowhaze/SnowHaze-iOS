//
//  SafebrowsingSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let generalSection = 0
private let enableRow = 0
private let updateSection = 2
private let updateDisplayRow = 0
private let msgFlashTime: TimeInterval = 2

class SafebrowsingSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("safebrowsing settings explanation", comment: "explanations of the safebrowsing settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.safebrowsing]).color
	}

	override var numberOfSections: Int {
		return 3
	}

	private var safebrowsing: Safebrowsing? = nil

	private enum UpdateMessage {
		case updated
		case failed
		case unnecessary
		case updating
	}
	private var updateMessage: (UpdateMessage, Date?)? = nil


	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .medium
		formatter.locale = Locale.current
		formatter.doesRelativeDateFormatting = true
		return formatter
	}()

	private func reloadUpdate(displayOnly: Bool = false, flash: Bool = false) {
		syncToMainThread {
			if displayOnly {
				let indexPaths = [IndexPath(row: updateDisplayRow, section: updateSection)]
				controller.tableView.reloadRows(at: indexPaths, with: .fade)
			} else {
				let section = IndexSet(integer: updateSection)
				controller.tableView.reloadSections(section, with: .fade)
			}
			if flash {
				DispatchQueue.main.asyncAfter(deadline: .now() + msgFlashTime + 0.1) { [weak self] in
					self?.reloadUpdate(displayOnly: true, flash: false)
				}
			}
		}
	}

	private func reloadSafebrowsing() {
		safebrowsing = nil
		reloadUpdate()
		PolicyManager.globalManager().awaitTorIfNecessary(for: nil) { [weak self] success in
			if success {
				let safebrowsing = PolicyManager.globalManager().updateSafebrowsing
				DispatchQueue.global(qos: .userInitiated).async {
					_ = safebrowsing?.lastFullPrefixUpdate
					DispatchQueue.main.async {
						self?.safebrowsing = safebrowsing
						self?.reloadUpdate()
					}
				}
			}
		}
	}

	override func setup() {
		reloadSafebrowsing()
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		assert(generalSection == 0)
		assert(enableRow == 0)
		assert(updateSection == 2)
		assert(updateDisplayRow == 0)
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			let uiSwitch = makeSwitch()
			cell.accessoryView = uiSwitch
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("enable safebrowsing setting title", comment: "title of setting to enable safebrowsing")
				uiSwitch.isOn = bool(for: safebrowsingEnabledKey)
				uiSwitch.addTarget(self, action: #selector(toggleSBEnabled(_:)), for: .valueChanged)
				if !SubscriptionManager.status.confirmed {
					if bool(for: safebrowsingEnabledKey) {
						cell.accessoryView = OneWaySwitch(manager: self, action: #selector(toggleSBEnabled(_:)))
						cell.accessibilityLabel = NSLocalizedString("disable safebrowsing setting missing subscription accessibility label", comment: "accessibility label for the enable safebrowsing setting when the user does not have an active subscription but the setting is enabled")
					} else {
						cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "blocked"))
						cell.accessibilityLabel = NSLocalizedString("enable safebrowsing setting missing subscription accessibility label", comment: "accessibility label for the enable safebrowsing setting when the user does not have an active subscription")
					}
				}
			} else if indexPath.row == 1 {
				cell.textLabel?.text = NSLocalizedString("use safebrowsing proxy setting title", comment: "title of setting to enable proxy for safebrowsing")
				uiSwitch.isOn = bool(for: safebrowsingProxyKey)
				uiSwitch.addTarget(self, action: #selector(toggleProxy(_:)), for: .valueChanged)
			} else {
				assert(indexPath.row == 2)
				cell.textLabel?.text = NSLocalizedString("safebrowsing hard fail setting title", comment: "title of setting to enable hard fails for safebrowsing")
				uiSwitch.isOn = bool(for: safebrowsingHardFailKey)
				uiSwitch.addTarget(self, action: #selector(toggleHardFail(_:)), for: .valueChanged)
			}
		} else if indexPath.section == 1 {
			cell.textLabel?.text = SafebrowsingCacheSharing(rawValue: Int64(indexPath.row))!.name
			if Int64(indexPath.row) == settings.value(for: safebrowsingCacheSharingKey).integer {
				cell.accessoryType = .checkmark
			}
		} else {
			assert(indexPath.section == 2)
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("safebrowsing prefix update date title", comment: "title for the display of the safebrowsing prefix update date")
				if !SubscriptionManager.status.confirmed {
					cell.detailTextLabel?.text = NSLocalizedString("safebrowsing prefix update date not subscribed error message", comment: "placeholder for safebrowsing prefix update date for when no subscription is active")
				} else if safebrowsing == nil {
					cell.detailTextLabel?.text = NSLocalizedString("safebrowsing prefix update date loading message", comment: "placeholder for safebrowsing prefix update date for when safebrowsing data is being loaded")
				} else if let messageData = updateMessage, messageData.1?.timeIntervalSinceNow ?? 0 > -msgFlashTime  {
					let text: String
					switch messageData.0 {
						case .updated:		text = NSLocalizedString("safebrowsing prefix update successful message", comment: "indicator that the safebrowsing prefix update was successful")
						case .failed:		text = NSLocalizedString("safebrowsing prefix update failed message", comment: "indicator that the safebrowsing prefix update was unsuccessful")
						case .unnecessary:	text = NSLocalizedString("safebrowsing prefix update unnecessary message", comment: "indicator that the safebrowsing prefix update was unnecessary")
						case .updating:		text = NSLocalizedString("safebrowsing prefix update pending message", comment: "indicator that the safebrowsing prefix update is pending")
					}
					cell.detailTextLabel?.text = text
				} else if let date = safebrowsing?.lastFullPrefixUpdate {
					cell.detailTextLabel?.text = SafebrowsingSettingsManager.dateFormatter.string(from: date)
				} else {
					cell.detailTextLabel?.text = NSLocalizedString("safebrowsing prefix update date never", comment: "placeholder for safebrowsing prefix update date for when prefixes have not been updated yet")
				}
			} else if indexPath.row == 1 {
				let button = makeButton(for: cell)
				let title = NSLocalizedString("update safebrowsing prefix cache button title", comment: "title of button te update safebrowsing prefix cache")
				button.setTitle(title, for: [])
				button.addTarget(self, action: #selector(updatePrefixes(_:)), for: .touchUpInside)
				button.isEnabled = safebrowsing != nil && SubscriptionManager.status.confirmed
			} else {
				assert(indexPath.row == 2)
				let button = makeButton(for: cell)
				let title = NSLocalizedString("clear safebrowsing cache button title", comment: "title of button te clear safebrowsing cache")
				button.setTitle(title, for: [])
				button.addTarget(self, action: #selector(clearCache(_:)), for: .touchUpInside)
				button.isEnabled = safebrowsing?.lastFullPrefixUpdate != nil
			}
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 3
	}

	override func titleForHeader(inSection section: Int) -> String? {
		if section == 1 {
			return NSLocalizedString("safebrowsing cache sharing settings title", comment: "title of settings section to set the safebrowsing cache sharing mode")
		} else if section == 2 {
			return NSLocalizedString("safebrowsing cache updates settings title", comment: "title of settings section to update the safebrowsing cache")
		} else {
			return super.titleForHeader(inSection: section)
		}
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		return section == 1 ? 40 : super.heightForHeader(inSection: section)
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		let subscribed = SubscriptionManager.status.confirmed
		if indexPath.section == 1 {
			let oldRow = Int(settings.value(for: safebrowsingCacheSharingKey).integer!)
			guard indexPath.row != oldRow else {
				return
			}
			let policy = SafebrowsingCacheSharing(rawValue: Int64(indexPath.row))!
			settings.set(.integer(policy.rawValue), for: safebrowsingCacheSharingKey)
			updateHeaderColor(animated: true)
			tableView.cellForRow(at: IndexPath(row: oldRow, section: indexPath.section))?.accessoryType = .none
			tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
		} else if indexPath.section == generalSection && indexPath.row == enableRow && !subscribed && !bool(for: safebrowsingEnabledKey) {
			controller.switchToSubscriptionSettings()
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
	}

	@objc private func toggleSBEnabled(_ sender: UISwitch) {
		set(sender.isOn, for: safebrowsingEnabledKey)
		updateHeaderColor(animated: true)
		if !SubscriptionManager.status.confirmed {
			let indexPath = IndexPath(row: enableRow, section: generalSection)
			controller.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}

	@objc private func toggleProxy(_ sender: UISwitch) {
		set(sender.isOn, for: safebrowsingProxyKey)
		updateHeaderColor(animated: true)
		reloadSafebrowsing()
	}

	@objc private func toggleHardFail(_ sender: UISwitch) {
		set(sender.isOn, for: safebrowsingHardFailKey)
		updateHeaderColor(animated: true)
	}

	@objc private func updatePrefixes(_ sender: UIButton) {
		updateMessage = (.updating, nil)
		reloadUpdate(displayOnly: true)
		safebrowsing?.updatePrefixes { [weak self] success in
			switch success {
				case .some(true):	self?.updateMessage = (.updated, Date())
				case .some(false):	self?.updateMessage = (.failed, Date())
				case nil:			self?.updateMessage = (.unnecessary, Date())
			}
			self?.reloadUpdate(flash: true)
		}
	}

	@objc private func clearCache(_ sender: UIButton) {
		safebrowsing?.clearStorage()
		reloadUpdate(displayOnly: true)
	}
}
