//
//  AppSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let updateSiteListsSection = 1
private let updateSiteListsRow = 0

private let tabMaskingSection = 3

class AppSettingsManager: SettingsViewManager, UITextFieldDelegate {
	private let labelWidth: CGFloat = 65
	private let margin: CGFloat = 10

	private var observer: NSObjectProtocol?

	override func html() -> String {
		return NSLocalizedString("application settings explanation", comment: "explanations of the application settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.application]).color
	}

	private lazy var labels: (undo: UILabel, preview: UILabel) = {
		let undoLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.steppers.undo.frame.height))
		undoLabel.textColor = .subtitle
		undoLabel.textAlignment = .right

		let previewLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.steppers.preview.frame.height))
		previewLabel.textColor = .subtitle
		previewLabel.textAlignment = .right
		return (undoLabel, previewLabel)
	}()

	private lazy var steppers: (undo: UIStepper, preview: UIStepper) = {
		let undoStepper = UIStepper()
		undoStepper.minimumValue = 0
		undoStepper.maximumValue = 9
		undoStepper.stepValue = 1
		undoStepper.tintColor = .switchOn
		undoStepper.addTarget(self, action: #selector(undoStepperValueChanged(_:)), for: .valueChanged)
		undoStepper.value = self.stepperValueFor(time: self.settings.value(for: tabClosingUndoTimeLimitKey).floatValue!)

		// workaround for iOS 13 "feature"
		undoStepper.setIncrementImage(undoStepper.incrementImage(for: .normal), for: .normal)
		undoStepper.setDecrementImage(undoStepper.decrementImage(for: .normal), for: .normal)

		let previewStepper = UIStepper()
		previewStepper.minimumValue = 0
		previewStepper.maximumValue = 9
		previewStepper.stepValue = 1
		previewStepper.tintColor = .switchOn
		previewStepper.addTarget(self, action: #selector(previewStepperValueChanged(_:)), for: .valueChanged)
		previewStepper.value = self.stepperValueFor(time: self.settings.value(for: previewDelayKey).floatValue!)

		// workaround for iOS 13 "feature"
		previewStepper.setIncrementImage(previewStepper.incrementImage(for: .normal), for: .normal)
		previewStepper.setDecrementImage(previewStepper.decrementImage(for: .normal), for: .normal)

		return (undoStepper, previewStepper)
	}()

	override func setup() {
		super.setup()
		let center = NotificationCenter.default
		observer = center.addObserver(forName: DomainList.dbFileChangedNotification, object: nil, queue: nil) { [weak self] _ in
			let indexPath = IndexPath(row: updateSiteListsRow, section: updateSiteListsSection)
			self?.controller?.tableView?.reloadRows(at: [indexPath], with: .fade)
		}
	}

	deinit {
		if let observer = observer {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			if indexPath.row == 0 {
				let uiSwitch = makeSwitch()
				cell.textLabel?.text = NSLocalizedString("show local site suggestions setting title", comment: "title of show local site suggestions setting")
				uiSwitch.isOn = bool(for: showLocalSiteSuggestionsKey)
				uiSwitch.addTarget(self, action: #selector(toggleShowLocalSiteSuggestions(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == 1 {
				let uiSwitch = makeSwitch()
				cell.textLabel?.text = NSLocalizedString("suggest private sites setting title", comment: "title of suggest private sites setting")
				uiSwitch.isOn = bool(for: suggestPrivateSitesKey)
				uiSwitch.addTarget(self, action: #selector(toggleSuggestPrivate(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == 2 {
				cell.textLabel?.text = NSLocalizedString("preview wait setting title", comment: "title of setting to delay the loading of a page preview for a few secconds")
				steppers.preview.frame.origin.x = labelWidth + margin
				let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + steppers.preview.frame.width + margin, height: steppers.preview.frame.height))
				view.addSubview(labels.preview)
				view.addSubview(steppers.preview)
				cell.accessoryView = view
				updateLabelForPreviewStepper()
			} else {
				let textField = makeTextField(for: cell)
				textField.placeholder = NSLocalizedString("home page url setting title", comment: "title of home page url setting")
				textField.text = settings.value(for: homepageURLKey).text
				textField.delegate = self
				textField.keyboardType = .URL
				textField.autocorrectionType = .no
				textField.autocapitalizationType = .none
				textField.textContentType = .URL
				updatedBorder(of: textField, for: settings.value(for: homepageURLKey).text ?? "")
			}
		} else if indexPath.section == updateSiteListsSection {
			if indexPath.row == updateSiteListsRow {
				let uiSwitch = makeSwitch()
				uiSwitch.isOn = bool(for: updateSiteListsKey)
				if let date = PolicyManager.globalManager().lastSiteListUpdate {
					let weeks = Int(-date.timeIntervalSinceNow / 60 / 60 / 24 / 7)
					if weeks == 0 {
						 cell.detailTextLabel?.text = NSLocalizedString("site lists 0 weeks old notice", comment: "indication that the currently installed site lists are up to date")
					} else if weeks == 1 {
						cell.detailTextLabel?.text = NSLocalizedString("site lists 1 week old notice", comment: "indication that the currently installed site lists are 1 week old")
					} else {
						let format = NSLocalizedString("site lists > 1 week old notice format", comment: "format string of indication that the currently installed site lists are > 1 week old")
						cell.detailTextLabel?.text = String(format: format, "\(weeks)")
					}
				}
				cell.textLabel?.text = NSLocalizedString("update site lists setting title", comment: "title of update site lists setting")
				uiSwitch.addTarget(self, action: #selector(toggleUpdateSiteLists(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			} else {
				let uiSwitch = makeSwitch()
				uiSwitch.isOn = !bool(for: useCellularForSiteListsUpdateKey)
				cell.textLabel?.text = NSLocalizedString("no cellular data for site lists update setting title", comment: "title of setting to prevent site lists updates from using cellular data")
				uiSwitch.addTarget(self, action: #selector(toggleUseCellularForSiteListsUpdate(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			}
		} else if indexPath.section == 2 {
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("allow tab closing undo duration settings title", comment: "title of setting for the duration during which closing a tab can be undone")
				steppers.undo.frame.origin.x = labelWidth + margin
				let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + steppers.undo.frame.width + margin, height: steppers.undo.frame.height))
				view.addSubview(labels.undo)
				view.addSubview(steppers.undo)
				cell.accessoryView = view
				updateLabelForUndoStepper()
			} else {
				let uiSwitch = makeSwitch()
				cell.textLabel?.text = NSLocalizedString("allow tab closing undo for all tabs settings title", comment: "title of setting to allow tab closing to be undone for all tabs")
				uiSwitch.isOn = bool(for: allowTabClosingUndoForAllTabsKey)
				uiSwitch.addTarget(self, action: #selector(toggleAllowTabClosingUndoForAllTabs(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			}
		} else if indexPath.section == tabMaskingSection {
			assert(tabMaskingSection == 3)
			cell.accessoryView = nil
			let selected = settings.value(for: tabMaskingRuleKey).integer!
			let index = Int64(indexPath.row)
			cell.accessoryType = selected == index ? .checkmark : .none
			cell.textLabel?.text = TabMaskingRule(rawValue: index)?.name
		} else {
			if indexPath.row == 0 {
				let uiSwitch = makeSwitch()
				cell.textLabel?.text = NSLocalizedString("keep usage stats settings title", comment: "title of setting to keep usage stats")
				uiSwitch.isOn = bool(for: updateUsageStatsKey)
				uiSwitch.addTarget(self, action: #selector(toggleKeepUsageStats(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
			} else {
				let button = makeButton(for: cell)
				let title = NSLocalizedString("reset usage stats button title", comment: "title of button to reset usage stats")
				button.setTitle(title, for: [])
				button.isEnabled = !Stats.shared.isCleared
				button.addTarget(self, action: #selector(clearUsageStats(_:)), for: .touchUpInside)
			}
		}
		return cell
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		if section == tabMaskingSection {
			return super.heightForFooter(inSection: section)
		} else if section == updateSiteListsSection && !SubscriptionManager.status.possible {
			return 30
		} else {
			return 0
		}
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		if section == 0 {
			return super.heightForHeader(inSection: section)
		}
		return 40
	}

	override func titleForHeader(inSection section: Int) -> String? {
		assert(tabMaskingSection == 3)
		assert(updateSiteListsSection == 1)
		switch section {
			case 0:		return super.titleForHeader(inSection: section)
			case 1:		return NSLocalizedString("site lists settings title", comment: "title of settings to manage site lists")
			case 2:		return NSLocalizedString("allow tab closing undo settings title", comment: "title of settings for undoing tab closing")
			case 3:		return NSLocalizedString("tab masking settings title", comment: "title of settings for tab masking")
			case 4:		return NSLocalizedString("usage stats settings title", comment: "title of settings for usage stats")
			default:	fatalError("invalid section")
		}
	}

	override func titleForFooter(inSection section: Int) -> String? {
		if section == updateSiteListsSection && !SubscriptionManager.status.possible {
			return NSLocalizedString("subscribe to premium for frequent site lists update notice", comment: "indication that subscribing to premium gives access to frequent site lists updates")
		} else {
			return nil
		}
	}

	override var numberOfSections: Int {
		return 5
	}

	override func numberOfRows(inSection section: Int) -> Int {
		assert(tabMaskingSection == 3)
		assert(updateSiteListsSection == 1)
		switch section {
			case 0:		return 4
			case 1:		return 2
			case 2:		return 2
			case 3:		return 3
			case 4:		return 2
			default:	fatalError("invalid section")
		}
	}

	@objc private func toggleSuggestPrivate(_ sender: UISwitch) {
		set(sender.isOn, for: suggestPrivateSitesKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleUpdateSiteLists(_ sender: UISwitch) {
		DomainList.set(updating: sender.isOn)
		updateHeaderColor(animated: true)
		if !sender.isOn {
			let indexPath = IndexPath(row: updateSiteListsRow, section: updateSiteListsSection)
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) { [weak self] in
				self?.controller?.tableView?.reloadRows(at: [indexPath], with: .fade)
			}
		}
	}

	@objc private func toggleUseCellularForSiteListsUpdate(_ sender: UISwitch) {
		set(!sender.isOn, for: useCellularForSiteListsUpdateKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleShowLocalSiteSuggestions(_ sender: UISwitch) {
		set(sender.isOn, for: showLocalSiteSuggestionsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleAllowTabClosingUndoForAllTabs(_ sender: UISwitch) {
		set(sender.isOn, for: allowTabClosingUndoForAllTabsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleKeepUsageStats(_ sender: UISwitch) {
		set(sender.isOn, for: updateUsageStatsKey)
		Stats.shared.reset()
		updateHeaderColor(animated: true)
	}

	@objc private func clearUsageStats(_ sender: UIControl) {
		Stats.shared.reset()
		sender.isEnabled = !Stats.shared.isCleared
	}

	private func timeFor(stepperValue: Double) -> Double {
		switch round(stepperValue) {
			case 0:		return 0
			case 1:		return 1
			case 2:		return 2
			case 3:		return 3
			case 4:		return 5
			case 5:		return 10
			case 6:		return 15
			case 7:		return 20
			case 8:		return 30
			case 9:		return 60
			default:	fatalError("invalid value")
		}
	}

	private func stepperValueFor(time: Double) -> Double {
		switch round(time) {
			case 0:		return 0
			case 1:		return 1
			case 2:		return 2
			case 3:		return 3
			case 5:		return 4
			case 10:	return 5
			case 15:	return 6
			case 20:	return 7
			case 30:	return 8
			case 60:	return 9
			default:	fatalError("invalid value")
		}
	}

	@objc private func undoStepperValueChanged(_ sender: UIStepper) {
		settings.set(.float(timeFor(stepperValue: sender.value)), for: tabClosingUndoTimeLimitKey)
		updateLabelForUndoStepper()
		updateHeaderColor(animated: true)
	}

	@objc private func previewStepperValueChanged(_ sender: UIStepper) {
		settings.set(.float(timeFor(stepperValue: sender.value)), for: previewDelayKey)
		updateLabelForPreviewStepper()
		updateHeaderColor(animated: true)
	}

	private func updateLabelForUndoStepper() {
		let value = Int(timeFor(stepperValue: steppers.undo.value))
		switch value {
			case 0:
				labels.undo.text = NSLocalizedString("tab closing undo time limit 0 seconds time", comment: "string used to indicate that tab closing cannot be undone")
			case 1:
				labels.undo.text = NSLocalizedString("tab closing undo time limit 1 second time", comment: "string used to indicate that tab closing can be undone for 1 second")
			default:
				let format = NSLocalizedString("tab closing undo time limit many seconds time format", comment: "format string used to indicate how long tab closing can be undone")
				labels.undo.text = String(format: format, "\(value)")
		}
	}

	private func updateLabelForPreviewStepper() {
		let value = Int(timeFor(stepperValue: steppers.preview.value))
		switch value {
			case 0:
				labels.preview.text = NSLocalizedString("preview delay 0 seconds time", comment: "string used to indicate that page preview loads are not delayed")
			case 1:
				labels.preview.text = NSLocalizedString("preview delay 1 second time", comment: "string used to indicate that page preview loads are delayed for 1 second")
			default:
				let format = NSLocalizedString("preview delay many seconds time format", comment: "format string used to indicate for how long page preview loads are delayed")
				labels.preview.text = String(format: format, "\(value)")
		}
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		guard indexPath.section == tabMaskingSection else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
			return
		}
		tableView.deselectRow(at: indexPath, animated: false)
		let newValue = Int64(indexPath.row)
		settings.set(.integer(Int64(indexPath.row)), for: tabMaskingRuleKey)
		for cell in tableView.visibleCells {
			if let indexPath = tableView.indexPath(for: cell), indexPath.section == tabMaskingSection {
				let cellSelected = Int64(indexPath.row) == newValue
				cell.accessoryType = cellSelected ? .checkmark : .none
			}
		}
		updateHeaderColor(animated: true)
	}

	private func isValid(_ text: String) -> Bool {
		if !text.isEmpty, let url = URL(string: text), let host = url.host, ["http", "https"].contains(url.normalizedScheme) {
			return host.contains(".") && !host.contains(" ")
		}
		return false
	}

	private func updatedBorder(of textField: UITextField, for text: String) {
		if text.isEmpty {
			textField.layer.borderColor = UIColor.black.cgColor
		} else if isValid(text) {
			textField.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		} else {
			textField.layer.borderColor = UIColor.veryBadPrivacy.cgColor
		}
	}

	private func update(url text: String?) {
		if let text = text, isValid(text) {
			settings.set(.text(text), for: homepageURLKey)
		} else {
			settings.set(.null, for: homepageURLKey)
		}
		updateHeaderColor(animated: true)
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		update(url: textField.text)
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		update(textField, range: range, replacement: string)
		updatedBorder(of: textField, for: textField.text ?? "")
		return false
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
}
