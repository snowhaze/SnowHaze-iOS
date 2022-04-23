//
//  AppearanceSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class AppearanceSettingsManager: SettingsViewManager {
	private let labelWidth: CGFloat = 25
	private let margin: CGFloat = 10

	override func html() -> String {
		return NSLocalizedString("appearance settings explanation", comment: "explanations of the appearance settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.appearance]).color
	}

	private lazy var labels: (fontSize: UILabel, readerFontSize: UILabel, scale: UILabel) = {
		let font = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.steppers.fontSize.frame.height))
		font.textColor = .subtitle
		font.textAlignment = .right

		let reader = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.steppers.readerFontSize.frame.height))
		reader.textColor = .subtitle
		reader.textAlignment = .right

		let scale = UILabel(frame: CGRect(x: 0, y: 0, width: self.labelWidth, height: self.steppers.scale.frame.height))
		scale.textColor = .subtitle
		scale.textAlignment = .right
		return (font, reader, scale)
	}()

	private lazy var steppers: (fontSize: UIStepper, readerFontSize: UIStepper, scale: UIStepper) = {
		let font = UIStepper()
		font.minimumValue = 0
		font.maximumValue = 75
		font.stepValue = 5
		font.tintColor = .switchOn
		font.addTarget(self, action: #selector(fontSizeStepperValueChanged(_:)), for: .valueChanged)
		font.value = self.settings.value(for: minFontSizeKey).floatValue!

		let reader = UIStepper()
		reader.minimumValue = -5
		reader.maximumValue = 75
		reader.stepValue = 5
		reader.tintColor = .switchOn
		reader.addTarget(self, action: #selector(readerFontSizeStepperValueChanged(_:)), for: .valueChanged)
		reader.value = self.settings.value(for: minReaderFontSizeKey).floatValue!

		let scale = UIStepper()
		scale.minimumValue = Double(3 * scaleStorageFactor / 10)
		scale.maximumValue = Double(3 * scaleStorageFactor)
		scale.stepValue = Double(scaleStorageFactor / 10)
		scale.tintColor = .switchOn
		scale.addTarget(self, action: #selector(scaleStepperValueChanged(_:)), for: .valueChanged)
		scale.value = Double(self.settings.value(for: webContentScaleKey).integer!)

		// workaround for iOS 13 "feature"
		font.setIncrementImage(font.incrementImage(for: .normal), for: .normal)
		font.setDecrementImage(font.decrementImage(for: .normal), for: .normal)
		reader.setIncrementImage(reader.incrementImage(for: .normal), for: .normal)
		reader.setDecrementImage(reader.decrementImage(for: .normal), for: .normal)
		scale.setIncrementImage(scale.incrementImage(for: .normal), for: .normal)
		scale.setDecrementImage(scale.decrementImage(for: .normal), for: .normal)

		return (font, reader, scale)
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
			let stepper = steppers.fontSize
			stepper.frame.origin.x = labelWidth + margin
			let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + stepper.frame.width + margin, height: stepper.frame.height))
			view.addSubview(labels.fontSize)
			view.addSubview(stepper)
			cell.accessoryView = view
			updateLabelForSteppers()
		} else if indexPath.row == 2 {
			cell.textLabel?.text = NSLocalizedString("reader mode minimum font size setting title", comment: "title of minimum font size in reader mode setting")
			let stepper = steppers.readerFontSize
			stepper.frame.origin.x = labelWidth + margin
			let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + stepper.frame.width + margin, height: stepper.frame.height))
			view.addSubview(labels.readerFontSize)
			view.addSubview(stepper)
			cell.accessoryView = view
		} else if indexPath.row == 3 {
			cell.textLabel?.text = NSLocalizedString("content scale setting title", comment: "title of content scale setting")
			let stepper = steppers.scale
			stepper.frame.origin.x = labelWidth + margin
			let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + stepper.frame.width + margin, height: stepper.frame.height))
			view.addSubview(labels.scale)
			view.addSubview(stepper)
			cell.accessoryView = view
			updateLabelForSteppers()
		} else {
			let uiSwitch = makeSwitch()
			cell.textLabel?.text = NSLocalizedString("ignore scale limits setting title", comment: "title of ignore scale limits setting")
			uiSwitch.isOn = bool(for: ignoresViewportScaleLimitsKey)
			uiSwitch.addTarget(self, action: #selector(toggleIgnoreScaleLimits(_:)), for: .valueChanged)
			cell.accessoryView = uiSwitch
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 5
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

	@objc private func fontSizeStepperValueChanged(_ sender: UIStepper) {
		settings.set(.float(sender.value), for: minFontSizeKey)
		updateLabelForSteppers()
		updateHeaderColor(animated: true)
	}

	@objc private func readerFontSizeStepperValueChanged(_ sender: UIStepper) {
		settings.set(.float(sender.value), for: minReaderFontSizeKey)
		updateLabelForSteppers()
		updateHeaderColor(animated: true)
	}

	@objc private func scaleStepperValueChanged(_ sender: UIStepper) {
		settings.set(.integer(Int64(sender.value)), for: webContentScaleKey)
		updateLabelForSteppers()
		updateHeaderColor(animated: true)
	}

	private func updateLabelForSteppers() {
		labels.fontSize.text = "\(Int(steppers.fontSize.value))"
		if steppers.readerFontSize.value < 0 {
			labels.readerFontSize.text = NSLocalizedString("minimum reader mode disabled stepper label value", comment: "value of the minimum reader mode stepper label when separate minimum font size is disabled")
		} else {
			labels.readerFontSize.text = "\(Int(steppers.readerFontSize.value))"
		}
		labels.scale.text = String(format: "%.1f", steppers.scale.value / Double(scaleStorageFactor))
	}
}
