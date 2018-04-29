//
//  PasscodeSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import LocalAuthentication

private let modeSection = 1
private let typeSection = 2
private let changeLockSection = 3
private let changeCodeRow = 0
private let lockRow = 1

class PasscodeSettingsManager: SettingsViewManager {
	private let labelWidth: CGFloat = 70
	private let margin: CGFloat = 10

	override func html() -> String {
		return NSLocalizedString("passcode settings explanation", comment: "explanations of the passcode settings tab")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.passcode]).color
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
		stepper.maximumValue = 7
		stepper.stepValue = 1
		stepper.tintColor = .switchOn
		stepper.addTarget(self, action: #selector(stepperValueChanged(_:)), for: .valueChanged)
		stepper.value = self.stepperValueFor(time: self.settings.value(for: passcodeLockAfterDurationKey).float!)
		return stepper
	}()

	private var biometricsAvailable: Bool {
		return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		assert(modeSection == 1)
		assert(typeSection == 2)
		assert(changeLockSection == 3)
		assert(changeCodeRow == 0)
		assert(lockRow == 1)
		switch (indexPath.section, indexPath.row) {
			case (1, 0):	cell.textLabel?.text = NSLocalizedString("passcode locking mode off settings title", comment: "title of settings to set passcode locking mode to off")
			case (1, 1):	cell.textLabel?.text = NSLocalizedString("passcode locking mode passcode or biometrics settings title", comment: "title of settings to set passcode locking mode to passcode or biometric authentication")
							if !biometricsAvailable {
								cell.detailTextLabel?.text = NSLocalizedString("passcode locking mode passcode or biometrics settings biometrics not available subtitle", comment: "subtitle of settings to set passcode locking mode to passcode or biometrics that indicates that biometric authentication is unavailable")
							}
			case (1, 2):	cell.textLabel?.text = NSLocalizedString("passcode locking mode passcode only settings title", comment: "title of settings to set passcode locking mode to passcode only")
			case (1, 3):	cell.textLabel?.text = NSLocalizedString("passcode lock after settings title", comment: "title of settings to set after how long in the background the app locks")
							stepper.frame.origin.x = labelWidth + margin
							let view = UIView(frame: CGRect(x: 0, y: 0, width: labelWidth + stepper.frame.width + margin, height: stepper.frame.height))
							view.addSubview(label)
							view.addSubview(stepper)
							cell.accessoryView = view
							updateLabelForStepper()

			case (2, 0):	cell.textLabel?.text = NSLocalizedString("passcode type 6 digits settings title", comment: "title of settings to set passcode type to 6 digit PIN")
			case (2, 1):	cell.textLabel?.text = NSLocalizedString("passcode type long numeric settings title", comment: "title of settings to set passcode type to arbitrary length PIN")
			case (2, 2):	cell.textLabel?.text = NSLocalizedString("passcode type alphanumeric settings title", comment: "title of settings to set passcode type to arbitrary length PIN")

			case (3, 0):	let button = makeButton(for: cell)
							button.addTarget(self, action: #selector(changePasscode(_:)), for: .touchUpInside)
							let title = NSLocalizedString("change passcode button title", comment: "title of button to change the applications passcode")
							button.setTitle(title, for: [])
							if case .off = PasscodeManager.shared.mode {
								button.isEnabled = false
							} else {
								button.isEnabled = true
							}
			case (3, 1):	let button = makeButton(for: cell)
							button.addTarget(self, action: #selector(lock(_:)), for: .touchUpInside)
							let title = NSLocalizedString("lock snowhaze button title", comment: "title of button to manually engage ui lock")
							button.setTitle(title, for: [])
							if case .off = PasscodeManager.shared.mode {
								button.isEnabled = false
							} else {
								button.isEnabled = true
							}

			default:		fatalError("invalid index path")
		}
		if indexPath.section == 1 && indexPath.row == index(for: PasscodeManager.shared.mode) {
			cell.accessoryType = .checkmark
		}
		if indexPath.section == 2 && indexPath.row == index(for: PasscodeManager.shared.type) {
			cell.accessoryType = .checkmark
		}
		return cell
	}

	override func titleForHeader(inSection section: Int) -> String? {
		switch section {
			case 0:		return super.titleForHeader(inSection: section)
			case 1:		return NSLocalizedString("passcode locking mode settings title", comment: "title of settings section to set the apps locking mode")
			case 2:		return NSLocalizedString("passcode type settings title", comment: "title of settings section to set the passcodes type")
			case 3:		return nil
			default:	fatalError("invalid section index")
		}
	}

	override var numberOfSections: Int {
		return 4
	}

	override func numberOfRows(inSection section: Int) -> Int {
		switch section {
			case 0:		return 0
			case 1:		return 4
			case 2:		return 3
			case 3:		return 2
			default:	fatalError("invalid section index")
		}
	}

	private func mode(for index: Int) -> PasscodeManager.LockingMode {
		switch index {
			case 0:		return .off
			case 1:		return .pinOrBiometrics
			case 2:		return .pinOnly
			default:	fatalError("invalid locking mode index")
		}
	}

	private func index(for mode: PasscodeManager.LockingMode) -> Int {
		switch mode {
			case .off:				return 0
			case .pinOrBiometrics:	return 1
			case .pinOnly:			return 2
		}
	}

	private func type(for index: Int) -> PasscodeController.PasscodeType {
		switch index {
			case 0:		return .digit6
			case 1:		return .longDigit
			case 2:		return .alphanumeric
			default:	fatalError("invalid passcode type index")
		}
	}

	private func index(for type: PasscodeController.PasscodeType) -> Int {
		switch type {
			case .digit6:		return 0
			case .longDigit:	return 1
			case .alphanumeric:	return 2
		}
	}

	private var modeAfterSetup: PasscodeManager.LockingMode?
	private var modeAfterVerify: PasscodeManager.LockingMode?
	private var modeAfterController: PasscodeController?

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == 1 && indexPath.row <= 2 {
			let oldMode = PasscodeManager.shared.mode
			let oldIndex = index(for: oldMode)
			let newMode = mode(for: indexPath.row)
			let type = PasscodeManager.shared.type

			if case .pinOrBiometrics = newMode, !biometricsAvailable {
				return
			}

			assert(modeAfterSetup == nil)
			assert(modeAfterVerify == nil)
			assert(modeAfterController == nil)
			switch (oldMode, newMode) {
				case (.off, .off), (.pinOrBiometrics, .pinOrBiometrics), (.pinOnly, .pinOnly):
					return
				case (.off, _):
					modeAfterSetup = newMode
					modeAfterController = displayPasscodeController(withMode: .setup(type))
				case (.pinOnly, _):
					modeAfterVerify = newMode
					modeAfterController = displayPasscodeController(withMode: .verify(type, true))
				case (.pinOrBiometrics, .off):
					modeAfterVerify = .off
					modeAfterController = displayPasscodeController(withMode: .verify(type, true))
				case (.pinOrBiometrics, .pinOnly):
					PasscodeManager.shared.clearBiometrics { [weak self] success in
						if success {
							let oldIndexPath = IndexPath(row: oldIndex, section: indexPath.section)
							self?.controller?.tableView.reloadRows(at: [indexPath, oldIndexPath], with: .none)
							self?.updateHeaderColor(animated: true)
						}
					}
			}
		} else if indexPath.section == 2 {
			let oldIndex = index(for: PasscodeManager.shared.type)
			guard oldIndex != indexPath.row else {
				return
			}
			if case .off = PasscodeManager.shared.mode {
				let newIndex = indexPath.row
				PasscodeManager.shared.set(keyType: type(for: newIndex))
				let old = IndexPath(row: oldIndex, section: typeSection)
				let new = IndexPath(row: newIndex, section: typeSection)
				self.controller?.tableView.reloadRows(at: [old, new], with: .none)
				updateHeaderColor(animated: true)
			} else {
				displayPasscodeController(withMode: .change(PasscodeManager.shared.type, type(for: indexPath.row)))
			}
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
	}

	@objc private func stepperValueChanged(_ sender: UIStepper) {
		let value = timeFor(stepperValue: stepper.value)
		settings.set(.float(value), for: passcodeLockAfterDurationKey)
		updateLabelForStepper()
		updateHeaderColor(animated: true)
	}

	@objc private func changePasscode(_ sender: UIButton) {
		let type = PasscodeManager.shared.type
		displayPasscodeController(withMode: .change(type, type))
	}

	@objc private func lock(_ sender: UIButton) {
		PasscodeManager.shared.manualUILockEngaged()
	}

	private func updateLabelForStepper() {
		let value = timeFor(stepperValue: stepper.value) / 60
		switch value {
		case 0:
			label.text = NSLocalizedString("passcode lock after 0 minutes time", comment: "string used to indicate that the app locks immediately on entering background")
		case 1:
			label.text = NSLocalizedString("passcode lock after 1 minute time", comment: "string used to indicate that the app locks 1 minute after entering background")
		case Double.infinity:
			label.text = NSLocalizedString("passcode lock after infinity minutes time", comment: "string used to indicate that the app only requires unlocking at startup")
		default:
			let format = NSLocalizedString("passcode lock after many minutes time", comment: "string used to indicate how long after entering background the app locks")
			label.text = String(format: format, "\(Int(value + 0.5))")
		}
	}

	private func timeFor(stepperValue: Double) -> Double {
		switch round(stepperValue) {
			case 0:		return 0	* 60
			case 1:		return 1	* 60
			case 2:		return 2	* 60
			case 3:		return 3	* 60
			case 4:		return 5	* 60
			case 5:		return 10	* 60
			case 6:		return 15	* 60
			case 7:		return Double.infinity
			default:	fatalError("invalid value")
		}
	}

	private func stepperValueFor(time: Double) -> Double {
		switch round(time) {
			case 0	* 60:			return 0
			case 1	* 60:			return 1
			case 2	* 60:			return 2
			case 3	* 60:			return 3
			case 5	* 60:			return 4
			case 10	* 60:			return 5
			case 15	* 60:			return 6
			case Double.infinity:	return 7
			default:	fatalError("invalid value")
		}
	}

	@discardableResult private func displayPasscodeController(withMode mode: PasscodeController.Mode) -> PasscodeController {
		assert(modeAfterController == nil)
		let passcodeVC = PasscodeController()
		passcodeVC.backgroundColor = .background
		passcodeVC.backgroundImage = #imageLiteral(resourceName: "Background")
		passcodeVC.mode = mode
		passcodeVC.preferredStatusBarStyle = .lightContent
		passcodeVC.modalPresentationStyle = .formSheet
		passcodeVC.delegate = self
		passcodeVC.autoPromptForBiometrics = true
		switch (PasscodeManager.shared.mode, mode) {
			case (.pinOrBiometrics, .verify):	passcodeVC.keychainID = PasscodeManager.keychainID
			case (.pinOrBiometrics, .change):	passcodeVC.keychainID = PasscodeManager.keychainID
			default:						passcodeVC.keychainID = nil
		}
		controller.present(passcodeVC, animated: true, completion: nil)
		return passcodeVC
	}
}

extension PasscodeSettingsManager: PasscodeControllerDelegate {
	func passcodeController(_ controller: PasscodeController, verifyPasscode code: String, withCompletionHandler completionHandler: @escaping (Bool) -> Void) {
		assert(modeAfterSetup == nil)
		PasscodeManager.shared.verify(code: code) { [weak self] success in
			if success, let me = self, let newMode = me.modeAfterVerify {
				assert(controller == me.modeAfterController)
				let oldMode = PasscodeManager.shared.mode
				let oldIndex = me.index(for: oldMode)
				let newIndex = me.index(for: newMode)
				assert(oldIndex != newIndex)
				let newPath = IndexPath(row: newIndex, section: modeSection)
				let oldPath = IndexPath(row: oldIndex, section: modeSection)
				let changePath = IndexPath(row: changeCodeRow, section: changeLockSection)
				let lockPath = IndexPath(row: lockRow, section: changeLockSection)
				switch newMode {
					case .off:
						PasscodeManager.shared.clearKey { success in
							if let me = self {
								me.controller?.tableView.reloadRows(at: [oldPath, newPath, changePath, lockPath], with: .none)
								me.updateHeaderColor(animated: true)
							}
							completionHandler(success)
						}
					default:
						PasscodeManager.shared.set(mode: newMode, withKey: code) { success in
							if let me = self {
								me.controller?.tableView.reloadRows(at: [oldPath, newPath, changePath, lockPath], with: .none)
								me.updateHeaderColor(animated: true)
							}
							completionHandler(success)
						}
				}
			} else {
				completionHandler(success)
			}
		}
	}

	func passcodeControllerDidComplete(_ controller: PasscodeController) {
		assert(modeAfterSetup == nil || modeAfterVerify == nil)
		assert((modeAfterSetup == nil && modeAfterVerify == nil) || modeAfterController != nil)
		modeAfterSetup = nil
		modeAfterVerify = nil
		modeAfterController = nil

		controller.delegate = controller.dummyDelegate
		controller.dismiss(animated: true, completion: nil)
	}

	func passcodeController(_ controller: PasscodeController, setCode code: String, ofType type: PasscodeController.PasscodeType, withCompletionHandler completionHandler: @escaping (Bool) -> Void) {
		assert(modeAfterVerify == nil)
		if let newMode = modeAfterSetup {
			assert(modeAfterController == controller)
			let oldMode = PasscodeManager.shared.mode
			let oldIndex = index(for: oldMode)
			let newIndex = index(for: newMode)
			assert(oldIndex != newIndex)
			let oldIndexPath = IndexPath(row: oldIndex, section: modeSection)
			let newIndexPath = IndexPath(row: newIndex, section: modeSection)
			let changeIndexPath = IndexPath(row: changeCodeRow, section: changeLockSection)
			let lockIndexPath = IndexPath(row: lockRow, section: changeLockSection)
			PasscodeManager.shared.set(mode: newMode, withKey: code, ofType: type) { [weak self] success in
				self?.controller?.tableView.reloadRows(at: [oldIndexPath, newIndexPath, changeIndexPath, lockIndexPath], with: .none)
				self?.updateHeaderColor(animated: true)
				completionHandler(success)
			}
		} else {
			let oldTypeIndex = index(for: PasscodeManager.shared.type)
			let newTypeIndex = index(for: type)
			PasscodeManager.shared.set(key: code, ofType: type) { [weak self] success in
				if success, newTypeIndex != oldTypeIndex {
					let old = IndexPath(row: oldTypeIndex, section: typeSection)
					let new = IndexPath(row: newTypeIndex, section: typeSection)
					self?.controller?.tableView.reloadRows(at: [old, new], with: .none)
					self?.updateHeaderColor(animated: true)
				}
				completionHandler(success)
			}
		}
	}
}
