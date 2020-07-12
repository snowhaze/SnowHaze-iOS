//
//  RegisterSubscriptionSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let emptySection = 0
private let formSection = 1
private let privateKeySection = 2

private let formRow = 0
private let confirmRow = 0
private let downloadRow = 1

class RegisterSubscriptionSettingsManager: SettingsViewManager {
	private weak var parent: SubscriptionSettingsManager?
	private var useKey = false
	private var loading = false

	init(parent: SubscriptionSettingsManager) {
		self.parent = parent
		super.init()
		controller = parent.controller
	}

	private var registerButton: UIButton?
	private var copyKeyButton: UIButton?
	private var emailField: UITextField?
	private var emailConfirmField: UITextField?
	private var passwordField: UITextField?
	private var passwordConfirmField: UITextField?
	private var errorLabel: UILabel?
	private var safetySwitch: UISwitch?
	private var uploadCleartexEmailSwitch: UISwitch?

	private var offlineOK = false
	private var pwOK = false

	override func setup() {
		super.setup()
		header.icon = parent?.header.icon
		header.delegate = parent?.header.delegate
		header.color = assessmentResultColor
	}

	override func html() -> String {
		return NSLocalizedString("register subscription sub settings explanation", comment: "explanations of the register subscription sub settings tab")
	}

	override var assessmentResultColor: UIColor {
		return parent?.assessmentResultColor ?? PolicyAssessmentResult.color(for: .veryBad)
	}

	override var numberOfSections: Int {
		return 3
	}

	override func numberOfRows(inSection section: Int) -> Int {
		switch section {
			case 0:		return 0
			case 1:		return 1
			case 2:		return useKey ? 2 : 1
			default:	fatalError("invalid section")
		}
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == formSection {
			assert(indexPath.row == formRow)
			let email = makeTextField(for: cell)
			email.placeholder = NSLocalizedString("zka2 register email textfield placeholder", comment: "placeholder for the email text field in the zka2 registration form")
			email.text = emailField?.text
			email.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			email.center.y = 40
			email.delegate = self
			email.keyboardType = .emailAddress
			email.autocorrectionType = .no
			email.autocapitalizationType = .none
			email.textContentType = .emailAddress
			emailField = email

			let emailConfirm = makeTextField(for: cell)
			emailConfirm.placeholder = NSLocalizedString("zka2 register confirm email textfield placeholder", comment: "placeholder for the confirm email text field in the zka2 registration form")
			emailConfirm.text = emailConfirmField?.text
			emailConfirm.center.y = 100
			emailConfirm.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			emailConfirm.delegate = self
			emailConfirm.keyboardType = .emailAddress
			emailConfirm.autocorrectionType = .no
			emailConfirm.autocapitalizationType = .none
			emailConfirm.textContentType = .emailAddress
			emailConfirmField = emailConfirm

			let password = makeTextField(for: cell)
			password.placeholder = NSLocalizedString("zka2 register password textfield placeholder", comment: "placeholder for the password text field in the zka2 registration form")
			password.isSecureTextEntry = true
			password.text = passwordField?.text
			password.center.y = 160
			password.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			password.delegate = self
			password.keyboardType = .default
			password.autocorrectionType = .no
			password.autocapitalizationType = .none
			password.textContentType = .newPassword
			passwordField = password

			let passwordConfirm = makeTextField(for: cell)
			passwordConfirm.placeholder = NSLocalizedString("zka2 register confirm password textfield placeholder", comment: "placeholder for the confirm password text field in the zka2 registration form")
			passwordConfirm.isSecureTextEntry = true
			passwordConfirm.text = passwordConfirmField?.text
			passwordConfirm.center.y = 220
			passwordConfirm.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			passwordConfirm.delegate = self
			passwordConfirm.keyboardType = .default
			passwordConfirm.autocorrectionType = .no
			passwordConfirm.autocapitalizationType = .none
			passwordConfirm.textContentType = .password
			passwordConfirmField = passwordConfirm

			let upload = makeSwitch()
			upload.isOn = uploadCleartexEmailSwitch?.isOn ?? true
			upload.frame = CGRect(x: cell.bounds.maxX - 20 - upload.frame.width, y: 250, width: upload.frame.width, height: upload.frame.height)
			uploadCleartexEmailSwitch = upload
			upload.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
			cell.addSubview(upload)

			let uploadLabel = UILabel(frame: CGRect(x: cell.bounds.minX + 20, y: 255, width: cell.bounds.width - 120, height: 20))
			uploadLabel.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			uploadLabel.textColor = .title
			uploadLabel.text = NSLocalizedString("zka2 register upload cleartext email switch label", comment: "label of switch to enable the upload of cleartext email in the zka2 registration form")
			cell.addSubview(uploadLabel)

			let label = UILabel(frame: CGRect(x: cell.bounds.minX + 20, y: 285, width: cell.bounds.width - 40, height: 50))
			label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			label.textColor = .title
			label.textAlignment = .center
			label.numberOfLines = 2
			cell.addSubview(label)
			errorLabel = label

			let registerButton = makeButton(for: cell)
			registerButton.addTarget(self, action: #selector(register(_:)), for: .touchUpInside)
			registerButton.frame = CGRect(x: cell.bounds.midX + 20, y: 345, width: cell.bounds.width / 2 - 40, height: 40)
			registerButton.layer.cornerRadius = 20
			registerButton.clipsToBounds = true
			registerButton.backgroundColor = self.registerButton?.backgroundColor ?? .darkTitle
			registerButton.isEnabled = self.registerButton?.isEnabled ?? false
			self.registerButton = registerButton
			let registerTitle = NSLocalizedString("zka2 submit registration button title", comment: "title of button to submit the content of the zka2 registration form")
			registerButton.setTitle(registerTitle, for: [])
			registerButton.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]

			let loginButton = makeButton(for: cell)
			loginButton.setTitleColor(.button, for: [])
			loginButton.addTarget(self, action: #selector(login(_:)), for: .touchUpInside)
			loginButton.frame = CGRect(x: cell.bounds.minX + 20, y: 345, width: cell.bounds.width / 2 - 40, height: 40)
			let loginTitle = NSLocalizedString("zka2 switch to login button title", comment: "title of button to cancel registration and switch to login form")
			loginButton.setTitle(loginTitle, for: [])
			loginButton.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]

			updateUIState()
		} else {
			assert(indexPath.section == privateKeySection)
			if indexPath.row == confirmRow {
				let uiSwitch = makeSwitch()
				uiSwitch.isOn = useKey
				cell.accessoryView = uiSwitch
				uiSwitch.isEnabled = !loading
				uiSwitch.addTarget(self, action: #selector(toggleUseKey(_:)), for: .valueChanged)
				safetySwitch = uiSwitch

				cell.textLabel?.text = NSLocalizedString("use zka2 without an account setting title", comment: "title of setting to use zka 2 with only a master secret")
				cell.detailTextLabel?.text = NSLocalizedString("use zka2 without an account setting subtitle", comment: "subtitle of setting to use zka 2 with only a master secret")
			} else {
				assert(indexPath.row == downloadRow)
				let copyKey = makeButton(for: cell)
				copyKey.addTarget(self, action: #selector(copyKey(_:)), for: .touchUpInside)
				let copyTitle = NSLocalizedString("copy zka2 master secret button title", comment: "title of button to copy zka2 master secret before finalizing registration")
				copyKey.setTitle(copyTitle, for: [])
				copyKey.frame = CGRect(x: cell.bounds.minX + 40, y: cell.bounds.minY + 20, width: cell.bounds.width - 80, height: 45)
				copyKey.clipsToBounds = true
				copyKey.layer.cornerRadius = 45 / 2
				copyKey.backgroundColor = .button
				copyKey.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				copyKeyButton = copyKey
				updateUIState()

				let containerFrame = CGRect(x: cell.bounds.minX, y: cell.bounds.minY + 75, width: cell.bounds.width, height: 85)
				let container = containerView(with: containerFrame)
				container.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				container.backgroundColor = .veryBadPrivacy
				cell.addSubview(container)

				let label = UILabel(frame: container.bounds.inset(by: UIEdgeInsets(top: 5, left: 20, bottom: 5, right: 20)))
				label.numberOfLines = 0
				label.textAlignment = .center
				label.textColor = .title
				label.text = NSLocalizedString("no email account generation warning", comment: "warning when user registers for zka2 with only a master secret")
				label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				container.addSubview(label)
			}
		}
		return cell
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		if indexPath.section == formSection {
			return 400
		} else if indexPath.section == privateKeySection && indexPath.row == downloadRow {
			return 170
		}
		return super.heightForRow(atIndexPath: indexPath)
	}

	override func titleForHeader(inSection section: Int) -> String? {
		let title = NSLocalizedString("zka2 registration settings section title", comment: "title of settings section to register for a zka2 account")
		return section == formSection ? title : nil
	}

	@objc private func toggleUseKey(_ sender: UISwitch) {
		useKey = sender.isOn
		updateUIState()
		let indexPath = IndexPath(row: downloadRow, section: privateKeySection)
		if useKey {
			controller.tableView.insertRows(at: [indexPath], with: .fade)
			controller.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
		} else {
			controller.tableView.deleteRows(at: [indexPath], with: .fade)
			let switchIndexPath = IndexPath(row: confirmRow, section: privateKeySection)
			controller.tableView.scrollToRow(at: switchIndexPath, at: .none, animated: true)
		}
	}

	@objc private func copyKey(_ sender: UIButton) {
		assert(useKey)
		assert(!loading)
		loading = true
		updateUIState()
		let svc = controller!.splitMergeController!
		V3APIConnection.register { [weak self] error in
			self?.loading = false
			if let error = error {
				SubscriptionSettingsManager.show(error: error, in: svc)
			} else {
				let key = V3APIConnection.crcedMasterSecretHex!
				UIPasteboard.general.string = key
				self?.parent?.switchToNormal()
			}
			self?.updateUIState()
		}
	}

	@objc private func login(_ sender: UIButton) {
		parent?.switchToLogin()
	}

	@objc private func register(_ sender: UIButton) {
		loading = true
		updateUIState()
		safetySwitch?.isEnabled = false
		let email = emailField?.text ?? ""
		let emailConfirm = emailConfirmField?.text ?? ""
		let password = passwordField?.text ?? ""
		let passwordConfirm = passwordConfirmField?.text ?? ""
		let upload = uploadCleartexEmailSwitch?.isOn ?? false
		assert(!email.isEmpty)
		assert(!password.isEmpty)
		assert(!passwordConfirm.isEmpty)
		assert(EmailValidator.fullDomains.validate(email))
		PasswordValidator.simpleMedium.validate(password) { assert($0) }
		assert(password == passwordConfirm)
		assert(email == emailConfirm)
		registerButton?.backgroundColor = .darkTitle
		let svc = controller!.splitMergeController!
		V3APIConnection.register { [weak self] error in
			if let error = error {
				self?.loading = false
				SubscriptionSettingsManager.show(error: error, in: svc)
				self?.updateUIState()
			} else {
				let code = PolicyManager.globalManager().threeLanguageCode
				let language = V3APIConnection.Language(rawValue: code)!
				V3APIConnection.addLogin(user: email, password: password, sendCleartextEmail: upload, language: language) { error in
					self?.loading = false
					if let error = error {
						SubscriptionSettingsManager.show(error: error, in: svc)
					} else {
						self?.parent?.switchToNormal()
					}
					self?.updateUIState()
				}
			}
		}
	}

	private func pushError(_ error: String) {
		if errorLabel?.text?.isEmpty ?? false {
			errorLabel?.text = error
		}
	}

	private func updateUIState() {
		offlineOK = !loading && !useKey
		emailField?.isEnabled = offlineOK

		errorLabel?.text = ""

		passwordField?.isEnabled = offlineOK
		passwordConfirmField?.isEnabled = offlineOK
		if let text = emailField?.text, !text.isEmpty {
			if EmailValidator.fullDomains.validate(text) {
				emailField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
			} else {
				emailField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
				offlineOK = false
				pushError(NSLocalizedString("zka registration invalid email error message", comment: "error message to indicate that the entered email is invalid during zka registration"))
			}
		} else {
			emailField?.layer.borderColor = UIColor.black.cgColor
			offlineOK = false
		}
		let emailConfirm = emailConfirmField?.text ?? ""
		if !emailConfirm.isEmpty && emailConfirmField?.text == emailField?.text {
			emailConfirmField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		} else if (emailField?.text ?? "").hasPrefix(emailConfirm) {
			emailConfirmField?.layer.borderColor = UIColor.black.cgColor
			offlineOK = false
		} else {
			emailConfirmField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			offlineOK = false
			pushError(NSLocalizedString("zka registration non matching emails error message", comment: "error message to indicate that the entered emails don't match during zka registration"))
		}
		passwordField?.layer.borderColor = UIColor.black.cgColor
		pwOK = false
		if let text = passwordField?.text, !text.isEmpty {
			PasswordValidator.simpleMedium.issues(for: text, blacklist: [emailField?.text ?? ""]) { [weak self] issues in
				guard let self = self, text == self.passwordField?.text else {
					return
				}
				if issues == .none {
					self.passwordField?.layer.borderColor = UIColor.okPrivacy.cgColor
					self.pwOK = true
					PasswordValidator.strongOffline.validate(text) { success in
						if success {
							self.passwordField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
						} else {
							DispatchQueue.main.async { [weak self] in
								guard text == self?.passwordField?.text else {
									return
								}
								self?.pushError(NSLocalizedString("zka registration weak password warning message", comment: "warning message to indicate that the entered passwords is still weak during zka registration"))
							}
						}
					}
					self.updateOKState()
				} else {
					self.passwordField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
					if issues.contains(.tooShort) {
						self.pushError(NSLocalizedString("zka registration password too short error message", comment: "error message to indicate that the entered password is too short during zka registration"))
					}
					if issues.contains(.foundInList) {
						self.pushError(NSLocalizedString("zka registration horrible password error message", comment: "error message to indicate that the entered password is a variation of a leaked password during zka registration"))
					}
					if issues.contains(.noLowercaseLetter) {
						self.pushError(NSLocalizedString("zka registration password must contain lowercase error message", comment: "error message to indicate that the entered password doesn't contain a lowercase letter during zka registration"))
					}
					if issues.contains(.noUppercaseLetter) {
						self.pushError(NSLocalizedString("zka registration password must contain uppercase error message", comment: "error message to indicate that the entered password doesn't contain an uppercase letter during zka registration"))
					}
					if issues.contains(.noSpecialCharacter) {
						self.pushError(NSLocalizedString("zka registration password must contain special character error message", comment: "error message to indicate that the entered password doesn't contain a special character during zka registration"))
					}
					if issues.contains(.noNumericalDigit) {
						self.pushError(NSLocalizedString("zka registration password must contain digit error message", comment: "error message to indicate that the entered password doesn't contain a numeric digit during zka registration"))
					}
					if issues.contains(.noNonLeadingUppercase) {
						self.pushError(NSLocalizedString("zka registration password must contain non-leading uppercase letter error message", comment: "error message to indicate that the entered password doesn't contain a non-leading uppercase letter during zka registration"))
					}
					if issues.contains(.noNonTailingSpecialCharOrDigit) {
						self.pushError(NSLocalizedString("zka registration password must contain non-tailing special character or digit error message", comment: "error message to indicate that the entered password doesn't contain a non-tailing special character or digit during zka registration"))
					}
					if issues.contains(.tooSimilar) {
						self.pushError(NSLocalizedString("zka registration password resembles email error message", comment: "error message to indicate that the user's password resembles their email"))
					}
					if issues.contains(.networkError) {
						self.pushError(NSLocalizedString("zka registration network error message", comment: "error message to indicate that a network request failed during zka registration"))
					}
				}
			}
		} else {
			offlineOK = false
		}
		let pwConfirm = passwordConfirmField?.text ?? ""
		if !pwConfirm.isEmpty && passwordConfirmField?.text == passwordField?.text {
			passwordConfirmField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		} else if (passwordField?.text ?? "").hasPrefix(pwConfirm) {
			passwordConfirmField?.layer.borderColor = UIColor.black.cgColor
			offlineOK = false
		} else {
			passwordConfirmField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			offlineOK = false
			pushError(NSLocalizedString("zka registration non matching passwords error message", comment: "error message to indicate that the entered passwords don't match during zka registration"))
		}
		updateOKState()
		safetySwitch?.isEnabled = !loading

		if !loading && !(copyKeyButton?.isEnabled ?? true) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.copyKeyButton?.backgroundColor = .button
				self?.copyKeyButton?.isEnabled = true
			}
		} else if loading && (copyKeyButton?.isEnabled ?? false) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.copyKeyButton?.backgroundColor = .darkTitle
				self?.copyKeyButton?.isEnabled = false
			}
		}
	}

	private func updateOKState() {
		let allOK = offlineOK && pwOK
		if allOK && !(registerButton?.isEnabled ?? true) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.registerButton?.backgroundColor = .button
				self?.registerButton?.isEnabled = true
			}
		} else if !allOK && (registerButton?.isEnabled ?? false) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.registerButton?.backgroundColor = .darkTitle
				self?.registerButton?.isEnabled = false
			}
		}
	}
}

extension RegisterSubscriptionSettingsManager: UITextFieldDelegate {
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let text = (textField.text ?? "") as NSString
		let new = text.replacingCharacters(in: range, with: string)
		textField.text = new
		let end = range.lowerBound + (string as NSString).length
		if let position = textField.position(from: textField.beginningOfDocument, offset: end) {
			textField.selectedTextRange = textField.textRange(from: position, to: position)
		}
		updateUIState()
		return false
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		switch textField {
			case emailField:			emailConfirmField?.becomeFirstResponder()
			case emailConfirmField:		passwordField?.becomeFirstResponder()
			case passwordField:			passwordConfirmField?.becomeFirstResponder()
			case passwordConfirmField:	passwordConfirmField?.resignFirstResponder()
			default:			break
		}
		return false
	}
}
