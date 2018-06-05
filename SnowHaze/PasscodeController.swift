//
//  PasscodeController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let servicePrefix = "ch.illotros.ios.passcodecontroller.touchid.keychainservicename.external."

public protocol PasscodeControllerDelegate {
	func passcodeController(_ controller: PasscodeController, verifyPasscode code: String, withCompletionHandler completionHandler: @escaping (Bool) -> Void)
	func passcodeController(_ controller: PasscodeController, setCode code: String, ofType type: PasscodeController.PasscodeType, withCompletionHandler completionHandler: @escaping (Bool) -> Void)
	func passcodeControllerDidComplete(_ controller: PasscodeController)
	func passcodeControllerErrorButtonPressed(_ controller: PasscodeController, for error: Any)
}

extension PasscodeControllerDelegate {
	func passcodeController(_ controller: PasscodeController, verifyPasscode code: String, withCompletionHandler completionHandler: @escaping (Bool) -> Void) {
		completionHandler(false)
	}

	func passcodeController(_ controller: PasscodeController, setCode code: String, ofType type: PasscodeController.PasscodeType, withCompletionHandler completionHandler: @escaping (Bool) -> Void) {
		completionHandler(false)
	}

	func passcodeControllerDidComplete(_ controller: PasscodeController) {
		controller.dismiss(animated: true, completion: nil)
		controller.delegate = controller.dummyDelegate
	}

	func passcodeControllerErrorButtonPressed(_ controller: PasscodeController, for error: Any) { }
}

public class PasscodeController: UIViewController {
	static var pwManagerService = "https://SnowHaze"
	private static func defaultTextOfType(_ type: TextType) -> String {
		switch type {
			case .cancel:
				return NSLocalizedString("passcodecontroller cancel button title", comment: "title of cancel button of passcodecontroller")
			case .verifyPasscodePrompt:
				return NSLocalizedString("passcodecontroller biometrics or passcode prompt", comment: "passcodecontrollers prompt to provide biometric authentication or enter passcode for verification")
			case .verifyPasscodePromptNoBiometrics:
				return NSLocalizedString("passcodecontroller passcode prompt", comment: "passcodecontrollers prompt to enter passcode for verification")
			case .askNewPasscode:
				return NSLocalizedString("passcodecontroller new passcode prompt", comment: "passcodecontrollers prompt to provide new passcode")
			case .askOldPasscode:
				return NSLocalizedString("passcodecontroller biometrics or old passcode prompt", comment: "passcodecontrollers prompt to provide biometric authentication or enter old passcode for verification before passcode change")
			case .askOldPasscodeNoBiometrics:
				return NSLocalizedString("passcodecontroller old passcode prompt", comment: "passcodecontrollers prompt to enter old passcode for verification before passcode change")
			case .confirmNewPasscode:
				return NSLocalizedString("passcodecontroller new passcode confirm prompt", comment: "passcodecontrollers prompt to confirm new passcode before setting it up or changing it")
			case .verifyingPasscode:
				return NSLocalizedString("passcodecontroller verifying passcode notice", comment: "text to indicate that the passcode is currently being verified")
			case .passcodeCorrect:
				return NSLocalizedString("passcodecontroller passcode correct notice", comment: "text to indicate that the provided passcode is correct")
			case .passcodeIncorrect:
				return NSLocalizedString("passcodecontroller passcode incorrect notice", comment: "text to indicate that the provided passcode is incorrect")
			case .passcodesDontMatch:
				return NSLocalizedString("passcodecontroller passcodes do not match notice", comment: "text to indicate that the provided passcodes did not match when setting up or changing passcode")
			case .settingUpPasscode:
				return NSLocalizedString("passcodecontroller setting up passcode notice", comment: "text to indicate that passcode is being set up")
			case .changingPasscode:
				return NSLocalizedString("passcodecontroller changing up passcode notice", comment: "text to indicate that passcode is being changed")
			case .setupComplete:
				return NSLocalizedString("passcodecontroller passcode setup succeeded notice", comment: "text to indicate that the passcode setup succeeded")
			case .changeComplete:
				return NSLocalizedString("passcodecontroller passcode change succeeded notice", comment: "text to indicate that the passcode change succeeded")
			case .setupFailed:
				return NSLocalizedString("passcodecontroller passcode setup failed notice", comment: "text to indicate that the passcode setup failed")
			case .changeFailed:
				return NSLocalizedString("passcodecontroller passcode change failed notice", comment: "text to indicate that the passcode change failed")
			case .updateKeychainPasscode:
				return NSLocalizedString("passcodecontroller update keychain passcode biometrics prompt", comment: "text to indicate why the user should authenticate with biometrics when updating the passcode stored in the keychain")
			case .readKeychainPasscode:
				return NSLocalizedString("passcodecontroller authenticate with biometrics prompt", comment: "text to indicate why the user should authenticate to snowhaze using biometrics")
			case .enterButtonAccessibilityLabel:
				return NSLocalizedString("passcodecontroller enter button accessibility label", comment: "accessibility label of the passcode controllers number pad enter button")
			case .backspaceButtonAccesibilityLabel:
				return NSLocalizedString("passcodecontroller backspace button accessibility label", comment: "accessibility label of the passcode controllers number pad backspace button")
			case .biometricsButtonAccessibilityLabel:
				return NSLocalizedString("passcodecontroller biometrics button accessibility label", comment: "accessibility label of the passcode controllers biometrics button")
			case .secureText0Characters:
				return NSLocalizedString("passcodecontroller code display 0 characters accessibility label", comment: "accessibility label of the passcode controllers code display when it is empty")
			case .secureText1Character:
				return NSLocalizedString("passcodecontroller code display 1 character accessibility label", comment: "accessibility label of the passcode controllers code display when it is has 1 character")
			case .secureTextNCharactersFormat:
				return NSLocalizedString("passcodecontroller code display many characters accessibility label", comment: "accessibility label of the passcode controllers code display when it is has more than 1 character")
		}
	}

	public static var textOfType: (TextType) -> String = defaultTextOfType

	public static var pinTextColor = UIColor.title
	public static var keyPadButtonColor = UIColor.title
	public static var textFieldTintColor = UIColor.button
	public static var errorMessageColor = UIColor.title
	public static var errorButtonColor = UIColor.button

	public static var entryTextfielFont = UIFont.snowHazeFont(size: 25)
	public static var pinDisplayFont = UIFont.snowHazeFont(size: 30)
	public static var errorMessageFont = UIFont.snowHazeFont(size: 15)
	public static var errorButtonFont = UIFont.snowHazeFont(size: 15)
	public static var cancelButtonFont = UIFont.snowHazeFont(size: 18)
	public static var promptLabelFont = UIFont.snowHazeFont(size: 17)

	public enum TextType {
		case cancel
		case verifyPasscodePrompt
		case verifyPasscodePromptNoBiometrics
		case askNewPasscode
		case askOldPasscode
		case askOldPasscodeNoBiometrics
		case confirmNewPasscode
		case verifyingPasscode
		case passcodeCorrect
		case passcodeIncorrect
		case passcodesDontMatch
		case settingUpPasscode
		case changingPasscode
		case setupComplete
		case changeComplete
		case setupFailed
		case changeFailed
		case updateKeychainPasscode
		case readKeychainPasscode

		case enterButtonAccessibilityLabel
		case backspaceButtonAccesibilityLabel
		case biometricsButtonAccessibilityLabel
		case secureText0Characters
		case secureText1Character
		case secureTextNCharactersFormat

		fileprivate var text: String {
			return PasscodeController.textOfType(self)
		}
	}

	var autoPromptForBiometrics = false {
		didSet {
			if oldValue == false && autoPromptForBiometrics {
				maybePromptForBiometrics()
			}
		}
	}

	var keychainID: String? {
		didSet {
			if case .done = stage {
				// everything ok
			} else if case .verify = stage {
				if autoPromptForBiometrics {
					maybePromptForBiometrics()
				}
				entry.biometricsEnabled = keychainID != nil
			} else {
				fatalError("keychainID cannot be set while controller is in progress")
			}
		}
	}

	private func maybePromptForBiometrics() {
		guard let keychainID = keychainID else {
			return
		}
		DispatchQueue.global(qos: .userInteractive).async { [weak self] in
			let query = [kSecAttrService: servicePrefix + keychainID, kSecClass: kSecClassGenericPassword, kSecUseOperationPrompt: TextType.readKeychainPasscode.text, kSecReturnData: true] as NSDictionary
			var result: AnyObject?
			let loadErr = SecItemCopyMatching(query, &result)
			if loadErr == errSecSuccess {
				DispatchQueue.main.async {
					let code = String(data: result as! Data, encoding: .utf8)!
					self?.biometricsProvided(code: code)
				}
			} else if ![errSecItemNotFound, errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed].contains(loadErr) {
				fatalError("unexpected keychain error while loading key: \(loadErr)")
			}
		}
	}

	static func set(code: String, forKeychainID keychainID: String, completionHandler: ((Bool) -> Void)?) {
		let completed: (Bool) -> Void = { ok in
			DispatchQueue.main.async { completionHandler?(ok) }
		}
		DispatchQueue.global(qos: .userInteractive).async {
			let data = code.data(using: .utf8)!
			let query = [kSecAttrService: servicePrefix + keychainID, kSecClass: kSecClassGenericPassword, kSecUseOperationPrompt: TextType.updateKeychainPasscode.text] as NSDictionary
			let updates = [kSecValueData: data] as NSDictionary
			let updateErr = SecItemUpdate(query, updates)
			if updateErr == errSecItemNotFound {
				guard let accessControll = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .touchIDCurrentSet, nil) else {
					completed(false)
					return
				}
				let attributes = [kSecAttrService: servicePrefix + keychainID, kSecClass: kSecClassGenericPassword, kSecValueData: data, kSecUseAuthenticationUI: kSecUseAuthenticationUIAllow, kSecAttrAccessControl: accessControll] as NSDictionary
				let addErr = SecItemAdd(attributes, nil)
				if addErr == errSecAuthFailed || addErr == errSecUserCanceled {
					completed(false)
				} else if addErr == errSecSuccess {
					completed(true)
				} else {
					fatalError("unexpected keychain error while adding key: \(addErr)")
				}
			} else if updateErr == errSecAuthFailed || updateErr == errSecUserCanceled {
				completed(false)
			} else if updateErr == errSecSuccess {
				completed(true)
			} else {
				fatalError("unexpected keychain update error: \(updateErr)")
			}
		}
	}

	static func clearCode(forKeychainID keychainID: String, completionHandler: ((Bool) -> Void)?) {
		let completed: (Bool) -> Void = { ok in
			DispatchQueue.main.async { completionHandler?(ok) }
		}
		DispatchQueue.global(qos: .userInteractive).async {
			let query = [kSecAttrService: servicePrefix + keychainID, kSecClass: kSecClassGenericPassword] as NSDictionary
			let delErr = SecItemDelete(query)
			if delErr == errSecSuccess || delErr == errSecItemNotFound {
				completed(true)
			} else if delErr == errSecAuthFailed || delErr == errSecUserCanceled {
				completed(false)
			} else {
				fatalError("unexpected keychain delete error: \(delErr)")
			}
		}
	}

	public enum PasscodeType {
		case digit6
		case longDigit
		case alphanumeric
	}

	private enum Stage {
		case done
		case verify(Int)
		case confirmOld(Int)
		case askNew
		case confirmNew(String)
		case emergencyVerify
		case emergencyConfirmOld

		var incremented: Stage {
			switch self {
				case .done:					return self
				case .verify(let cnt):		return .verify(cnt + 1)
				case .confirmOld(let cnt):	return .confirmOld(cnt + 1)
				case .askNew:				return self
				case .confirmNew(_):		return self
				case .emergencyVerify:		return self
				case .emergencyConfirmOld:	return self
			}
		}

		var emergencyVersion: Stage? {
			switch self {
				case .done:					return nil
				case .verify(let cnt):		return cnt >= 10 ? .emergencyVerify : nil
				case .confirmOld(let cnt):	return cnt >= 10 ? .emergencyConfirmOld : nil
				case .askNew:				return nil
				case .confirmNew(_):		return nil
				case .emergencyVerify:		return nil
				case .emergencyConfirmOld:	return nil
			}
		}
	}

	private var stage: Stage = .done

	override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return UI_USER_INTERFACE_IDIOM() == .pad ? .all : .portrait
	}

	public enum Mode {
		case setup(PasscodeType)
		case verify(PasscodeType, Bool)
		case change(PasscodeType, PasscodeType)
		case blank
		case error(String, String?, Any)
	}

	public enum NormalizationMode {
		case d
		case kd
		case c
		case kc
	}

	var normalizationMode: NormalizationMode = .kc

	private func normalize(_ input: String) -> String {
		switch normalizationMode {
			case .d:	return input.decomposedStringWithCanonicalMapping
			case .kd:	return input.decomposedStringWithCompatibilityMapping
			case .c:	return input.precomposedStringWithCanonicalMapping
			case .kc:	return input.precomposedStringWithCompatibilityMapping
		}
	}

	private struct DummyDelegate: PasscodeControllerDelegate { }

	public let dummyDelegate: PasscodeControllerDelegate = DummyDelegate()
	public var delegate: PasscodeControllerDelegate = DummyDelegate()

	private var viewDidLoadWasCalled = false

	var mode: Mode = .blank {
		didSet {
			if case .done = stage, viewDidLoadWasCalled {
				entry.removeFromSuperview()
				entry = PasscodeEntry()
				entry.owner = self
				entry.frame = view.bounds
				entry.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				view.addSubview(entry)

				errorContainer.removeFromSuperview()

				switch mode {
					case .change(let type, _):
						entry.codeType = type
						entry.canCancel = true
						if let _ = keychainID {
							entry.prompt = TextType.askOldPasscode.text
							entry.biometricsEnabled = true
						} else {
							entry.prompt = TextType.askOldPasscodeNoBiometrics.text
							entry.biometricsEnabled = false
						}
						stage = .confirmOld(0)
						if autoPromptForBiometrics {
							maybePromptForBiometrics()
						}
					case .setup(let type):
						entry.codeType = type
						entry.canCancel = true
						entry.prompt = TextType.askNewPasscode.text
						entry.createLogin = true
						stage = .askNew
					case .verify(let type, let canCancel):
						entry.codeType = type
						entry.canCancel = canCancel
						if let _ = keychainID {
							entry.prompt = TextType.verifyPasscodePrompt.text
							entry.biometricsEnabled = true
						} else {
							entry.prompt = TextType.verifyPasscodePromptNoBiometrics.text
							entry.biometricsEnabled = false
						}
						stage = .verify(0)
						if autoPromptForBiometrics {
							maybePromptForBiometrics()
						}
					case .blank:
						entry.removeFromSuperview()
					case .error(let msg, let title, _):
						entry.removeFromSuperview()
						errorContainer.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
						view.addSubview(errorContainer)
						errorLabel.text = msg
						errorButton.setTitle(title, for: .normal)
						errorButton.isHidden = title == nil
				}
			} else if viewDidLoadWasCalled {
				fatalError("cannot set mode while controller is in progress")
			}
		}
	}

	var backgroundColor: UIColor? {
		didSet {
			viewIfLoaded?.backgroundColor = backgroundColor
		}
	}

	var backgroundImage: UIImage? {
		set {
			bgImageView.image = newValue
		}
		get {
			return bgImageView.image
		}
	}

	private var statusBarStyle: UIStatusBarStyle = .default

	override public var preferredStatusBarStyle: UIStatusBarStyle {
		get {
			return statusBarStyle
		}
		set {
			statusBarStyle = newValue
		}
	}

	private let bgImageView = UIImageView()

	fileprivate func didCancel() {
		entry.disableCancel()
		delegate.passcodeControllerDidComplete(self)
		stage = .done
	}

	private var entry = PasscodeEntry() {
		willSet {
			entry.owner = nil
		}
		didSet {
			entry.owner = self
		}
	}

	private lazy var errorContainer: UIView = {
		let ret = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 150))
		errorLabel.frame = CGRect(x: 0, y: 0, width: 250, height: 100)
		errorButton.frame = CGRect(x: 0, y: 100, width: 250, height: 50)

		ret.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]

		errorLabel.textAlignment = .center
		errorLabel.numberOfLines = 0

		errorLabel.font = PasscodeController.errorMessageFont
		errorButton.titleLabel!.font = PasscodeController.errorButtonFont

		errorLabel.textColor = PasscodeController.errorMessageColor
		errorButton.tintColor = PasscodeController.errorButtonColor

		errorButton.addTarget(self, action: #selector(errorButtonPressed(_:)), for: .touchUpInside)

		ret.addSubview(errorLabel)
		ret.addSubview(errorButton)

		return ret
	}()
	private lazy var errorLabel = UILabel()
	private lazy var errorButton = UIButton(type: .system)

	private func set(passcode: String) {
		let type: PasscodeType
		let isSetup: Bool
		switch self.mode {
			case .change(_, let newType):
				type = newType
				isSetup = false
			case .setup(let newType):
				type = newType
				isSetup = true
			default:
				fatalError("only passcode changes & setups should set passcode")
		}
		self.entry.prompt = isSetup ? TextType.settingUpPasscode.text : TextType.changingPasscode.text
		self.entry.disableCancel()
		self.delegate.passcodeController(self, setCode: passcode, ofType: type) { success in
			DispatchQueue.main.async {
				if success {
					self.entry.prompt = isSetup ? TextType.setupComplete.text : TextType.changeComplete.text
					self.delegate.passcodeControllerDidComplete(self)
					self.stage = .done
				} else {
					self.animate(to: .askNew)
					self.entry.flash(isSetup ? TextType.setupFailed.text : TextType.changeFailed.text)
				}
			}
		}
	}

	private func biometricsProvided(code: String) {
		if case .verify = stage {
			prosses(code: code, confirmed: false)
		} else if case .confirmOld = stage {
			prosses(code: code, confirmed: false)
		}
	}

	fileprivate func biometricsRequested() {
		maybePromptForBiometrics()
	}

	fileprivate func didReturn(withCode code: String, confirmed: Bool) {
		let normalized = normalize(code)
		prosses(code: normalized, confirmed: confirmed)
	}

	private func prosses(code: String, confirmed: Bool) {
		entry.block()
		switch stage {
			case .verify, .confirmOld, .emergencyVerify, .emergencyConfirmOld:
				DispatchQueue.main.async {
					self.entry.prompt = TextType.verifyingPasscode.text
					self.entry.disableCancel()
					self.delegate.passcodeController(self, verifyPasscode: code) { codeOK in
						DispatchQueue.main.async {
							if codeOK {
								self.entry.prompt = TextType.passcodeCorrect.text
								if case .verify = self.stage {
									self.delegate.passcodeControllerDidComplete(self)
									self.stage = .done
								} else if case .emergencyVerify = self.stage {
									self.delegate.passcodeControllerDidComplete(self)
									self.stage = .done
								} else  {
									self.animate(to: .askNew)
								}
							} else {
								self.entry.reset()
								self.stage = self.stage.incremented
								if let newStage = self.stage.emergencyVersion {
									self.animate(to: newStage)
								}
								let biometricsPrompt: String
								let noBiometricsPrompt: String
								switch self.stage {
									case .verify, .emergencyVerify:
										biometricsPrompt = TextType.verifyPasscodePrompt.text
										noBiometricsPrompt = TextType.verifyPasscodePromptNoBiometrics.text
									case .confirmOld, .emergencyConfirmOld:
										biometricsPrompt = TextType.askOldPasscode.text
										noBiometricsPrompt = TextType.askOldPasscodeNoBiometrics.text
									default:
										fatalError("invalid stage sequence")
								}
								if let _ = self.keychainID {
									self.entry.prompt = biometricsPrompt
								} else {
									self.entry.prompt = noBiometricsPrompt
								}
								self.entry.flash(TextType.passcodeIncorrect.text)
							}
						}
					}
				}
			case .askNew:
				DispatchQueue.main.async {
					if confirmed {
						self.set(passcode: code)
					} else {
						self.animate(to: .confirmNew(code))
					}
				}
			case .confirmNew(let first):
				DispatchQueue.main.async {
					if first == code {
						self.set(passcode: code)
					} else {
						self.animate(to: .askNew)
						self.entry.flash(TextType.passcodesDontMatch.text)
					}
				}
			case .done:
				fatalError("nothing should happen while in done stage")
		}
	}

	private func animate(to newStage: Stage) {
		stage = newStage
		var type: PasscodeType
		let canCancel: Bool
		switch mode {
			case .change(_, let newType):
				type = newType
				canCancel = true
			case .setup(let newType):
				type = newType
				canCancel = true
			case .verify(let newType, let newCanCancel):
				type = newType
				canCancel = newCanCancel
			default:
				fatalError("only passcode changes & setups should cause animations")
		}
		let oldEntry = entry
		oldEntry.owner = nil
		entry = PasscodeEntry()
		switch newStage {
			case .askNew:
				entry.prompt = TextType.askNewPasscode.text
				entry.createLogin = true
			case .confirmNew(_):
				entry.prompt = TextType.confirmNewPasscode.text
			case .emergencyConfirmOld:
				type = .alphanumeric
				if let _ = self.keychainID {
					self.entry.prompt = TextType.askOldPasscode.text
				} else {
					self.entry.prompt = TextType.askOldPasscodeNoBiometrics.text
				}
			case .emergencyVerify:
				type = .alphanumeric
				if let _ = self.keychainID {
					self.entry.prompt = TextType.verifyPasscodePrompt.text
				} else {
					self.entry.prompt = TextType.verifyPasscodePromptNoBiometrics.text
				}
			default:
				fatalError("should only ever have to animate to 'new' stages")
		}
		entry.owner = self
		entry.frame = view.bounds
		entry.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		entry.canCancel = canCancel
		entry.codeType = type
		entry.frame.origin.x = view.bounds.maxX
		view.addSubview(entry)
		UIView.animate(withDuration: 0.3, animations: { 
			oldEntry.frame.origin.x = self.view.bounds.minX - oldEntry.frame.width
			self.entry.frame = self.view.bounds
		}, completion: { _ in
			oldEntry.removeFromSuperview()
		})
	}

	override public func viewDidLoad() {
		viewDidLoadWasCalled = true
		view.backgroundColor = backgroundColor
		bgImageView.frame = view.bounds
		bgImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(bgImageView)
		bgImageView.contentMode = .scaleAspectFill

		entry.owner = self
		entry.frame = view.bounds
		entry.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(entry)

		errorContainer.removeFromSuperview()

		switch mode {
			case .change(let type, _):
				entry.codeType = type
				entry.canCancel = true
				if let _ = keychainID {
					entry.prompt = TextType.askOldPasscode.text
					entry.biometricsEnabled = true
				} else {
					entry.prompt = TextType.askOldPasscodeNoBiometrics.text
					entry.biometricsEnabled = false
				}
				stage = .confirmOld(0)
				if autoPromptForBiometrics {
					maybePromptForBiometrics()
				}
			case .setup(let type):
				entry.codeType = type
				entry.canCancel = true
				entry.prompt = TextType.askNewPasscode.text
				entry.createLogin = true
				stage = .askNew
			case .verify(let type, let canCancel):
				entry.codeType = type
				entry.canCancel = canCancel
				if let _ = keychainID {
					entry.prompt = TextType.verifyPasscodePrompt.text
					entry.biometricsEnabled = true
				} else {
					entry.prompt = TextType.verifyPasscodePromptNoBiometrics.text
					entry.biometricsEnabled = false
				}
				stage = .verify(0)
				if autoPromptForBiometrics {
					maybePromptForBiometrics()
				}
			case .blank:
				entry.removeFromSuperview()
			case .error(let msg, let title, _):
				entry.removeFromSuperview()
				errorContainer.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
				view.addSubview(errorContainer)
				errorLabel.text = msg
				errorButton.setTitle(title, for: .normal)
				errorButton.isHidden = title == nil
		}
		super.viewDidLoad()
	}

	@objc private func errorButtonPressed(_ sender: UIButton) {
		if case .error(_, _, let tag) = mode {
			delegate.passcodeControllerErrorButtonPressed(self, for: tag)
		}
	}
}

private class NumberPad: UIView {
	weak var owner: PasscodeEntry?

	enum KeyType {
		case enter
		case delete
	}

	var keyType: KeyType = .enter {
		didSet {
			switch keyType {
				case .enter:
					buttons[10].setImage(#imageLiteral(resourceName: "enter_button"), for: .normal)
					buttons[10].accessibilityLabel = PasscodeController.TextType.enterButtonAccessibilityLabel.text
			case .delete:
					buttons[10].setImage(#imageLiteral(resourceName: "backspace_button"), for: .normal)
					buttons[10].accessibilityLabel = PasscodeController.TextType.backspaceButtonAccesibilityLabel.text
			}
		}
	}

	private static let buttonSize: CGFloat = 60
	private static let setupFrame: CGRect = CGRect(x: 0, y: 0, width: 3 * 1.5 * NumberPad.buttonSize + NumberPad.buttonSize / 2, height: 4 * 1.5 * NumberPad.buttonSize + NumberPad.buttonSize / 2)

	private let buttons: [UIButton]
	override init(frame: CGRect) {
		let buttonSize = NumberPad.buttonSize
		var buttons = [UIButton]()
		for i in 0 ... 9 {
			let button = UIButton(type: .system)
			button.setImage(UIImage(named: "\(i)_button"), for: .normal)
			button.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
			button.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
			button.tag = i
			button.accessibilityLabel = "\(i)"
			buttons.append(button)
		}
		let button = UIButton(type: .system)
		button.setImage(#imageLiteral(resourceName: "enter_button"), for: .normal)
		button.accessibilityLabel = PasscodeController.TextType.enterButtonAccessibilityLabel.text
		button.frame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
		button.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
		button.tag = -1
		buttons.append(button)
		self.buttons = buttons
		super.init(frame: NumberPad.setupFrame)

		for (i, button) in buttons.enumerated() {
			if i == 0 {
				button.center = CGPoint(x: 2.5 * buttonSize, y: 5.5 * buttonSize)
			} else if i <= 9 {
				button.center = CGPoint(x: (CGFloat((i - 1) % 3 + 1) * 1.5 - 0.5) * buttonSize, y: (CGFloat((i - 1) / 3 + 1) * 1.5 - 0.5) * buttonSize)
			} else {
				button.center = CGPoint(x: 4 * buttonSize, y: 5.5 * buttonSize)
			}
			button.tintColor = PasscodeController.keyPadButtonColor
			button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
			addSubview(button)
		}

		self.frame = frame
	}

	convenience init() {
		self.init(frame: NumberPad.setupFrame)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func buttonPressed(_ sender: UIButton) {
		if sender.tag < 0 {
			owner?.numpadDidReturnOrDelete()
		} else {
			owner?.numpadDigitPressed(sender.tag)
		}
	}
}

private class PasscodeEntry: UIView {
	var createLogin: Bool {
		get {
			return textDisplay.createLogin
		}
		set {
			textDisplay.createLogin = newValue
		}
	}
	weak var owner: PasscodeController?
	private static let width: CGFloat = 300
	private static let maxHeight: CGFloat = 390 + 240

	private var promptRestore: String = ""

	func flash(_ flash: String) {
		promptRestore = prompt
		prompt = flash
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
			if self.prompt == flash {
				self.prompt = self.promptRestore
			}
		}
	}

	var prompt: String {
		get {
			return label.text ?? ""
		}
		set {
			label.text = newValue
		}
	}

	func block() {
		numpad.isUserInteractionEnabled = false
		textDisplay.block()
	}

	func reset() {
		numpad.isUserInteractionEnabled = true
		cancelButton.isEnabled = true
		UIView.animate(withDuration: 0.2) { [weak self] in
			self?.cancelButton.alpha = 1
		}
		textDisplay.reset()
	}

	func disableCancel() {
		cancelButton.isEnabled = false
		UIView.animate(withDuration: 0.2) { [weak self] in
			self?.cancelButton.alpha = 0.3
		}
	}

	var canCancel: Bool {
		set {
			cancelButton.isHidden = !newValue
		}
		get {
			return !cancelButton.isHidden
		}
	}

	var biometricsEnabled: Bool {
		set {
			biometrics.isUserInteractionEnabled = newValue
		}
		get {
			return biometrics.isUserInteractionEnabled
		}
	}

	var codeType: PasscodeController.PasscodeType = .longDigit {
		didSet {
			setNeedsLayout()
			textDisplay.codeType = codeType
			switch codeType {
				case .digit6:
					numpad.isHidden = false
					numpad.keyType = .delete
				case .longDigit:
					numpad.isHidden = false
					numpad.keyType = .enter
				case .alphanumeric:
					numpad.isHidden = true
			}
			reset()
		}
	}

	init() {
		super.init(frame: CGRect(x: 0, y: 0, width: PasscodeEntry.width, height: PasscodeEntry.maxHeight))
		addSubview(numpad)
		numpad.owner = self

		addSubview(textDisplay)
		textDisplay.owner = self

		addSubview(biometrics)
		biometrics.tintColor = .title
		biometrics.setImage(#imageLiteral(resourceName: "fingerprint"), for: .normal)
		biometrics.accessibilityLabel = PasscodeController.TextType.biometricsButtonAccessibilityLabel.text
		biometrics.imageView?.contentMode = .scaleAspectFit
		biometrics.isUserInteractionEnabled = false
		biometrics.addTarget(self, action: #selector(pressedBiometrics(_:)), for: .touchUpInside)

		addSubview(cancelButton)
		cancelButton.setTitle(PasscodeController.TextType.cancel.text, for: .normal)
		cancelButton.titleLabel!.font = PasscodeController.cancelButtonFont
		cancelButton.addTarget(self, action: #selector(didCancel(_:)), for: .touchUpInside)

		addSubview(label)
		label.textColor = .title
		label.textAlignment = .center
		label.font = PasscodeController.promptLabelFont
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private let numpad = NumberPad()
	private let textDisplay = CodeDisplay()
	private let biometrics = UIButton(type: .system)
	private let cancelButton = UIButton()
	private let label = UILabel()

	override func layoutSubviews() {
		let width: CGFloat = 300
		let showNumpad: Bool
		if case .alphanumeric = codeType  {
			showNumpad = false
		} else {
			showNumpad = true
		}
		let height = min(PasscodeEntry.maxHeight, bounds.height - 20)
		let xOffset = (bounds.width - width) / 2 + bounds.minX
		let yOffset = (showNumpad ? 0 : 25) + (bounds.height - height) / 2 + bounds.minY + 10 // half of saved height is already there

		let topHeight = max(showNumpad ? 160 : 260, height - 390)

		numpad.frame = CGRect(x: xOffset, y: yOffset + topHeight, width: width, height: height - topHeight)
		textDisplay.frame = CGRect(x: xOffset + width / 2 - 125, y: yOffset + topHeight - 30, width: 250, height: 30)
		label.frame = CGRect(x: xOffset, y: yOffset + topHeight - 75, width: width, height: 40)
		biometrics.frame = CGRect(x: xOffset, y: yOffset, width: width, height: topHeight - 70)
		cancelButton.frame = CGRect(x: xOffset + width - 100, y: yOffset, width: 100, height: 40)
	}

	@objc private func didCancel(_: UIButton) {
		owner?.didCancel()
	}

	@objc private func pressedBiometrics(_: UIButton) {
		owner?.biometricsRequested()
	}

	func numpadDidReturnOrDelete() {
		switch codeType {
			case .digit6:
				if !textDisplay.text.isEmpty {
					let range = ..<textDisplay.text.index(before: textDisplay.text.endIndex)
					textDisplay.text = textDisplay.text.isEmpty ? "" : String(textDisplay.text[range])
				}
			case .longDigit:
				owner?.didReturn(withCode: textDisplay.text, confirmed: false)
			case .alphanumeric:
				fatalError("num pad has nothing to do with alphanumeric codes")
		}
	}

	func codeDisplayDidReturn(confirmed: Bool) {
		owner?.didReturn(withCode: textDisplay.text, confirmed: confirmed)
	}

	func numpadDigitPressed(_ digit: Int) {
		assert(digit >= 0 && digit <= 9)
		textDisplay.text = textDisplay.text + "\(digit)"
	}
}

private class CodeDisplay: UIView, UITextFieldDelegate {
	var createLogin = false

	var text: String = "" {
		didSet {
			textField.rightViewMode = text.isEmpty ? .always : .never
			let length = text.count
			if case .digit6 = codeType, length >= 6 {
				owner?.codeDisplayDidReturn(confirmed: false)
			}
			if case .longDigit = codeType {
				if length <= 15 {
					textField.text = [String](repeating: "\u{F106}", count: length).joined()
				} else {
					textField.text = "…" + [String](repeating: "\u{F106}", count: 14).joined()
				}
			}
			typealias TextType = PasscodeController.TextType
			let accessLabel: String
			switch length {
				case 0:		accessLabel = TextType.secureText0Characters.text
				case 1:		accessLabel = TextType.secureText1Character.text
				default:	accessLabel = String(format: TextType.secureTextNCharactersFormat.text, "\(length)")
			}
			switch codeType {
				case .digit6:
					label.accessibilityLabel = accessLabel
				case .longDigit:
					textField.accessibilityValue = accessLabel
				case .alphanumeric:
					textField.accessibilityValue = nil
			}
			let points = [String](repeating: "●", count: length)
			let dashes = [String](repeating: "-", count: max(0, 6 - length))
			let chars = points + dashes
			label.text = chars.joined(separator: " ")
		}
	}

	weak var owner: PasscodeEntry?

	func block() {
		textField.isEnabled = false
		textField.resignFirstResponder()
	}

	func reset() {
		text = ""
		textField.text = ""
		textField.isEnabled = true
		if case .alphanumeric = codeType {
			textField.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
		}
	}

	var codeType: PasscodeController.PasscodeType = .longDigit {
		didSet {
			switch codeType {
				case .digit6:
					label.isHidden = false
					textField.isHidden = true
				case .alphanumeric:
					textField.isSecureTextEntry = true
					label.isHidden = true
					textField.isHidden = false
					textField.rightView = oPWButton
				case .longDigit:
					textField.isSecureTextEntry = false
					label.isHidden = true
					textField.isHidden = false
					textField.rightView = nil
			}
		}
	}

	init() {
		super.init(frame: CGRect(x: 0, y: 0, width: 250, height: 35))
		oPWButton?.setImage(#imageLiteral(resourceName: "onepassword-button"), for: .normal)
		oPWButton?.tintColor = .black
		oPWButton?.addTarget(self, action: #selector(oPWButtonPressed(_:)), for: .touchUpInside)

		textField.frame = bounds
		textField.backgroundColor = .white
		textField.delegate = self
		textField.textAlignment = .center
		textField.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
		textField.font = PasscodeController.entryTextfielFont
		textField.keyboardAppearance = .dark
		textField.clearButtonMode = .always
		textField.rightViewMode = .always
		textField.tintColor = PasscodeController.textFieldTintColor
		if #available(iOS 11, *) {
			textField.textContentType = .password
		}
		addSubview(textField)

		label.frame = bounds
		label.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
		label.isHidden = true
		label.textColor = PasscodeController.pinTextColor
		label.textAlignment = .center
		label.font = PasscodeController.pinDisplayFont
		addSubview(label)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private static var showPasscodeButton: Bool {
		return OnePasswordExtension.shared().isAppExtensionAvailable() || DashlaneHelper.shared.dashlaneInstalled
	}

	private let oPWButton = CodeDisplay.showPasscodeButton ? UIButton(type: .system) : nil
	private let textField = FixedTextFiel()
	private let label = UILabel()

	@objc private func oPWButtonPressed(_ sender: UIButton) {
		guard let controller = owner?.owner else {
			return
		}
		if OnePasswordExtension.shared().isAppExtensionAvailable() {
			if createLogin {
				OnePasswordExtension.shared().changePasswordForLogin(forURLString: PasscodeController.pwManagerService, loginDetails: nil, passwordGenerationOptions: nil, for: controller, sender: sender) { [weak self] data, _ in
					guard let data = data, let pw = data[AppExtensionPasswordKey] as? String else {
						return
					}
					self?.text = pw
					self?.owner?.codeDisplayDidReturn(confirmed: true)
				}
			} else {
				OnePasswordExtension.shared().findLogin(forURLString: PasscodeController.pwManagerService, for: controller, sender: sender) { [weak self] data, _ in
					guard let data = data, let pw = data[AppExtensionPasswordKey] as? String else {
						return
					}
					self?.text = pw
					self?.owner?.codeDisplayDidReturn(confirmed: false)
				}
			}
		} else {
			let creating = createLogin
			DashlaneHelper.shared.promptForPasscode(for: PasscodeController.pwManagerService, new: creating, sourceView: sender, in: controller) { [weak self] passcode in
				guard let pw = passcode else {
					return
				}
				self?.text = pw
				self?.owner?.codeDisplayDidReturn(confirmed: creating)
			}
		}
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		owner?.codeDisplayDidReturn(confirmed: false)
		return true
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let newstring = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
		text = newstring
		return true
	}

	func textFieldShouldClear(_ textField: UITextField) -> Bool {
		text = ""
		return true
	}

	func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
		if case .alphanumeric = codeType {
			return true
		} else {
			return false
		}
	}
}

private class FixedTextFiel: UITextField {
	override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
		return CGRect(x: bounds.maxX - bounds.height + 5, y: bounds.minY + 5, width: bounds.height - 10, height: bounds.height - 10)
	}
}
