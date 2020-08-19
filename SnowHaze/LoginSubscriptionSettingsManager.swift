//
//  LoginSubscriptionSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import Sodium

private let emptySection = 0
private let formSection = 1

private let anyRow = 0

class LoginSubscriptionSettingsManager: SettingsViewManager {
	private weak var parent: SubscriptionSettingsManager?
	private var useKey = false

	private var keyField: UITextField?
	private var emailField: UITextField?
	private var passwordField: UITextField?
	private var loginButton: UIButton?

	init(parent: SubscriptionSettingsManager) {
		self.parent = parent
		super.init()
		controller = parent.controller
	}

	override func setup() {
		super.setup()
		header.icon = parent?.header.icon
		header.delegate = parent?.header.delegate
		header.color = assessmentResultColor
	}

	override func html() -> String {
		return NSLocalizedString("login subscription sub settings explanation", comment: "explanations of the login subscription sub settings tab")
	}

	override var assessmentResultColor: UIColor {
		return parent?.assessmentResultColor ?? PolicyAssessmentResult.color(for: .veryBad)
	}

	override var numberOfSections: Int {
		return 2
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return section == emptySection ? 0 : 1
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		assert(indexPath.section == formSection)
		assert(indexPath.row == anyRow)
		let emailOption = NSLocalizedString("zka2 accout login option title", comment: "title of the option to login to zka2 with email & password")
		let privateKeyOption = NSLocalizedString("zka2 master secret login option title", comment: "title of the option to login to zka2 with only the master secret")
		let items = [emailOption, privateKeyOption]
		let segment = UISegmentedControl(items: items)
		segment.frame = CGRect(x: 30, y: 15, width: cell.bounds.width - 60, height: 40)
		segment.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		segment.selectedSegmentIndex = useKey ? 1 : 0
		segment.tintColor = .button
		segment.addTarget(self, action: #selector(loginTypeChanged(_:)), for: .valueChanged)
		cell.addSubview(segment)

		let height = heightForRow(atIndexPath: indexPath)
		let maxY = height + cell.bounds.minY

		if useKey {
			let key = makeTextField(for: cell)
			key.center.y = 95
			key.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			key.placeholder = NSLocalizedString("zka2 login master secret textfield placeholder", comment: "placeholder for the master secret text field in the zka2 login form")
			key.text = keyField?.text
			key.delegate = self
			keyField = key
		} else {
			let email = makeTextField(for: cell)
			email.center.y = 95
			email.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			email.placeholder = NSLocalizedString("zka2 login email textfield placeholder", comment: "placeholder for the email text field in the zka2 login form")
			email.text = emailField?.text
			email.delegate = self
			email.keyboardType = .emailAddress
			email.autocorrectionType = .no
			email.autocapitalizationType = .none
			email.textContentType = .emailAddress
			emailField = email

			let password = makeTextField(for: cell)
			password.center.y = 155
			password.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			password.placeholder = NSLocalizedString("zka2 login password textfield placeholder", comment: "placeholder for the password text field in the zka2 login form")
			password.text = passwordField?.text
			password.isSecureTextEntry = true
			password.delegate = self
			password.keyboardType = .default
			password.autocorrectionType = .no
			password.autocapitalizationType = .none
			password.textContentType = .password
			passwordField = password

			let forgot = makeButton(for: cell)
			forgot.addTarget(self, action: #selector(forgotPW(_:)), for: .touchUpInside)
			forgot.setTitleColor(.button, for: [])
			let forgotTitle = NSLocalizedString("zka2 login forgot password button title", comment: "title of button for when users forget their zka2 password and want to log in")
			forgot.setTitle(forgotTitle, for: [])
			forgot.frame = CGRect(x: cell.bounds.minX + 20, y: maxY - 65, width: cell.bounds.width / 2 - 30, height: 45)
			forgot.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		}
		let login = makeButton(for: cell)
		login.addTarget(self, action: #selector(login(_:)), for: .touchUpInside)
		login.frame = CGRect(x: cell.bounds.midX + 10, y: maxY - 65, width: cell.bounds.width / 2 - 30, height: 45)
		let loginTitle = NSLocalizedString("zka2 login submit button title", comment: "title of button for submitting the contents of the zka2 login form")
		login.setTitle(loginTitle, for: [])
		login.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		login.clipsToBounds = true
		login.layer.cornerRadius = 45 / 2
		login.backgroundColor = .button
		loginButton = login
		updateUIState()
		return cell
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		if indexPath.section == formSection {
			return useKey ? 200 : 250
		}
		return super.heightForRow(atIndexPath: indexPath)
	}

	override func titleForHeader(inSection section: Int) -> String? {
		let title = NSLocalizedString("zka2 login settings section title", comment: "title of settings section to login to a zka2 account")
		return section == formSection ? title : nil
	}

	@objc private func login(_ sender: UIButton) {
		let svc = controller!.splitMergeController!
		if useKey {
			let key = keyField!.text!
			let split = key.components(separatedBy: .whitespacesAndNewlines)
			let joined = split.joined(separator: "")
			let bytes = Bytes(Data(hex: joined)!)
			assert(V3APIConnection.validateCRCedMasterSecret(bytes))
			V3APIConnection.register(secret: bytes) { [weak self] error in
				if let error = error {
					SubscriptionSettingsManager.show(error: error, in: svc)
				} else {
					self?.parent?.switchToNormal()
				}
			}
		} else {
			let password = passwordField!.text!
			let email = emailField!.text!
			V3APIConnection.getMasterSecret(user: email, password: password) { [weak self] masterSecret, error in
				if let secret = masterSecret {
					V3APIConnection.set(masterSecret: secret)
					self?.parent?.switchToNormal()
				} else {
					SubscriptionSettingsManager.show(error: error!, in: svc)
				}
			}
		}
	}

	private func updateUIState() {
		var keyOK = false
		if let key = keyField?.text, !key.isEmpty {
			let split = key.components(separatedBy: .whitespacesAndNewlines)
			let joined = split.joined(separator: "")

			if let data = Data(hex: joined), V3APIConnection.validateCRCedMasterSecret(Bytes(data)) {
				keyField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
				keyOK = true
			} else {
				keyField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			}
		} else {
			keyField?.layer.borderColor = UIColor.black.cgColor
		}
		let accountOK = !(emailField?.text ?? "").isEmpty && !(passwordField?.text ?? "").isEmpty
		let canLogin = (useKey && keyOK) || (!useKey && accountOK)
		if canLogin && !(loginButton?.isEnabled ?? true) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.loginButton?.backgroundColor = .button
				self?.loginButton?.isEnabled = true
			}
		} else if !canLogin && (loginButton?.isEnabled ?? false) {
			UIView.animate(withDuration: 0.2) { [weak self] in
				self?.loginButton?.backgroundColor = .dimmedTitle
				self?.loginButton?.isEnabled = false
			}
		}
	}

	@objc private func forgotPW(_ sender: UIButton) {
		let language = PolicyManager.globalManager().threeLanguageCode
		open("https://dashboard.snowhaze.com/\(language)/reset_confirm.html")
	}

	@objc private func loginTypeChanged(_ sender: UISegmentedControl) {
		useKey = sender.selectedSegmentIndex == 1
		let indexPath = IndexPath(row: anyRow, section: formSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		controller.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
	}
}

extension LoginSubscriptionSettingsManager: UITextFieldDelegate {
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
			case emailField:	passwordField?.becomeFirstResponder()
			case passwordField:	passwordField?.resignFirstResponder()
			case keyField:		keyField?.resignFirstResponder()
			default:			break
		}
		return false
	}
}
