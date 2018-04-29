//
//  AppearanceSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class AppearanceSettingsManager: SettingsViewManager {
	private let labelWidth: CGFloat = 20
	private let margin: CGFloat = 10

	override func html() -> String {
		return NSLocalizedString("appearance settings explanation", comment: "explanations of the appearance settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.appearance]).color
	}

	private lazy var label: UILabel = {
		let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.stepper.frame.height))
		label.textColor = .subtitle
		UIFont.setSnowHazeFont(on: label)
		label.textAlignment = .right
		return label
	}()

	private lazy var stepper: UIStepper = {
		let stepper = UIStepper()
		stepper.minimumValue = 0
		stepper.maximumValue = 75
		stepper.stepValue = 5
		stepper.tintColor = .switchOn
		stepper.addTarget(self, action: #selector(stepperValueChanged(_:)), for: .valueChanged)
		stepper.value = self.settings.value(for: minFontSizeKey).floatValue!
		return stepper
	}()

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.row == 0 {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("night mode setting title", comment: "title of night mode setting")
			uiSwitch.isOn = bool(for: nightModeKey)
			uiSwitch.addTarget(self, action: #selector(toggleNightMode(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
		} else if indexPath.row == 1 {
			cell.textLabel?.text = NSLocalizedString("minimum font size setting title", comment: "title of minimum font size setting")
			stepper.frame.origin.x = labelWidth + margin
			let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + stepper.frame.width + margin, height: stepper.frame.height))
			view.addSubview(label)
			view.addSubview(stepper)
			cell.accessoryView = view
			updateLabelForStepper()
		} else {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("ignore scale limits setting title", comment: "title of ignore scale limits setting")
			uiSwitch.isOn = bool(for: ignoresViewportScaleLimitsKey)
			uiSwitch.addTarget(self, action: #selector(toggleIgnoreScaleLimits(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
			if #available(iOS 10, *) {
				// obviouly don't show the notice
			} else {
				cell.detailTextLabel?.text = NSLocalizedString("ignore scale limits requires ios 10 notice", comment: "notice displayed on iOS 9 devices to indicate that ignoring scale limits requires ios 10 or newer")
			}
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 3
	}

	@objc private func toggleNightMode(_ sender: UISwitch) {
		set(sender.isOn, for: nightModeKey)
		updateHeaderColor(animated: true)
		
		// Also is done in DefaultsSettingsManager on Settings Reset
		MainViewController.controller.updateNightMode()
	}

	@objc private func toggleIgnoreScaleLimits(_ sender: UISwitch) {
		set(sender.isOn, for: ignoresViewportScaleLimitsKey)
		updateHeaderColor(animated: true)
	}

	@objc private func stepperValueChanged(_ sender: UIStepper) {
		settings.set(.float(sender.value), for: minFontSizeKey)
		updateLabelForStepper()
		updateHeaderColor(animated: true)
	}

	private func updateLabelForStepper() {
		label.text = "\(Int(stepper.value))"
	}
}
