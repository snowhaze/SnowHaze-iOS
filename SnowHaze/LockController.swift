//
//  LockController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

let snowhazeUILockWillDisengageNotification = Notification.Name(rawValue: "snowhazeUILockWillDisengageNotification")
let snowhazeUILockDidDisengageNotification = Notification.Name(rawValue: "snowhazeUILockDidDisengageNotification")

private extension UIResponder {
	private class FirstResponderGatherer: NSObject {
		var firstResponder: UIResponder?
	}

	@objc private func identifyFirstResponder(in gatherer: FirstResponderGatherer) {
		gatherer.firstResponder = self
	}

	static var firstResponder: UIResponder? {
		let gatherer = FirstResponderGatherer()
		UIApplication.shared.sendAction(#selector(UIResponder.identifyFirstResponder(in:)), to: nil, from: gatherer, for: nil)
		return gatherer.firstResponder
	}
}

class LockController: PasscodeController, PasscodeControllerDelegate {
	private(set) static var isDisengagingUILock = false

	private static var supportedInterfaceOrientations: UIInterfaceOrientationMask? {
		if overlayWindow.isHidden {
			return nil
		} else {
			return overlayWindow.rootViewController?.supportedInterfaceOrientations
		}
	}

	private static let overlayWindow: UIWindow = {
		let overlayWindow = UIWindow(frame: UIScreen.main.bounds)
		overlayWindow.windowLevel = UIWindow.Level.statusBar
		overlayWindow.backgroundColor = .clear
		overlayWindow.alpha = 1
		overlayWindow.isOpaque = false
		overlayWindow.rootViewController = LockPresenterController()
		overlayWindow.makeKeyAndVisible()
		overlayWindow.isUserInteractionEnabled = true
		overlayWindow.isHidden = true
		return overlayWindow
	}()

	private func setProperMode() {
		guard let type = PasscodeManager.shared?.type else {
			let msg = NSLocalizedString("app launch failed keychain error message", comment: "error message displayed when app launch fails due to keychain error")
			let retryTitle = NSLocalizedString("app launch failed keychain error retry button title", comment: "title of button to retry when app launch fails due to keychain error")
			mode = .error(msg, retryTitle, 0)
			keychainID = nil
			return
		}
		switch PasscodeManager.shared.mode {
			case .off:
				mode = .blank
				keychainID = nil
			case .pinOrBiometrics:
				mode = .verify(type, false)
				keychainID = PasscodeManager.keychainID
			case .pinOnly:
				mode = .verify(type, false)
				keychainID = nil
		}
	}

	private var isMain = true
	private var previousFirstResponder: UIResponder?

	override func viewDidLoad() {
		backgroundColor = .background
		backgroundImage = #imageLiteral(resourceName: "Background")
		if isMain {
			autoPromptForBiometrics = true
			setProperMode()
			_ = LockController.overlayWindow // Ensure that window is created before ui lock is engaged. It doesn't appear in snapshot otherwise
			navigationController!.delegate = self
		}
		preferredStatusBarStyle = .lightContent
		delegate = self

		if isMain {
			NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
			NotificationCenter.default.addObserver(self, selector: #selector(manualLockEngage(_:)), name: PasscodeManager.manualLockRequestNotification, object: nil)
		} else {
			NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
		}

		super.viewDidLoad()

		if case .off = PasscodeManager.shared?.mode ?? .pinOnly {
			DispatchQueue.main.async {
				PasscodeManager.shared.setupIfCorrect(code: "") { success in
					if success {
						self.fullUnlock()
					} else {
						self.mode = .verify(.alphanumeric, false)
					}
				}
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let nvc = navigationController {
			if let main = MainViewController.controller {
				nvc.setNavigationBarHidden(true, animated: true)
				nvc.pushViewController(main, animated: true)
			} else {
				nvc.setNavigationBarHidden(true, animated: false)
			}
		}
	}

	func passcodeController(_ controller: PasscodeController, verifyPasscode code: String, withCompletionHandler completionHandler: @escaping (Bool) -> ()) {
		if isMain {
			PasscodeManager.shared.setupIfCorrect(code: code, completionHandler: completionHandler)
		} else {
			PasscodeManager.shared.verify(code: code, withCompletionHandler: completionHandler)
		}
	}

	func passcodeControllerDidComplete(_ controller: PasscodeController) {
		controller.delegate = controller.dummyDelegate
		PasscodeManager.shared.appDidUnlock()
		if isMain {
			fullUnlock()
		} else {
			uiUnlock()
		}
	}

	func passcodeControllerErrorButtonPressed(_ controller: PasscodeController, for error: Any) {
		if error as? Int == 0 {
			setProperMode()
		}
	}

	private func fullUnlock() {
		assert(isMain)
		PasscodeManager.shared.performFullUnlock()
		performSegue(withIdentifier: "unlock", sender: self)
	}

	private func uiUnlock() {
		assert(!isMain)
		unhideVideos()
		NotificationCenter.default.post(name: snowhazeUILockWillDisengageNotification, object: self)
		LockController.isDisengagingUILock = true
		previousFirstResponder?.becomeFirstResponder()
		dismiss(animated: true) {
			assert(LockController.isDisengagingUILock)
			LockController.isDisengagingUILock = false
			LockController.overlayWindow.isHidden = true
			NotificationCenter.default.post(name: snowhazeUILockDidDisengageNotification, object: self)
		}
	}

	private func lockApp(manual: Bool) {
		assert(isMain)
		guard let nvc = navigationController, nvc.topViewController != self else {
			return
		}
		PasscodeManager.shared.appIsClosing()
		let overlayVC = LockController.overlayWindow.rootViewController!
		if overlayVC.presentedViewController == nil {
			let lvc = LockController()
			lvc.previousFirstResponder = UIResponder.firstResponder
			lvc.previousFirstResponder?.resignFirstResponder()
			lvc.isMain = false
			if manual {
				lvc.autoPromptForBiometrics = false
				lvc.setProperMode()
			} else {
				lvc.mode = .blank
			}
			LockController.overlayWindow.isHidden = false
			lvc.modalPresentationStyle = .fullScreen
			overlayVC.present(lvc, animated: manual, completion: nil)
		}
	}

	@objc private func didEnterBackground(_ notification: Notification) {
		let policy = PolicyManager.globalManager()
		guard Settings.dataAvailable && policy.needsScreenLockPreparation, let _ = PasscodeManager.shared else {
			return
		}
		lockApp(manual: false)
		hideVideos()
	}

	@objc private func manualLockEngage(_ notification: Notification) {
		lockApp(manual: true)
	}

	private func hideVideos() {
		let allWindows = UIApplication.shared.windows
		guard !allWindows.isEmpty else {
			return
		}
		let windows = allWindows.suffix(from: 1)
		for window in windows {
			if let root = window.rootViewController {
				if root is LockPresenterController {
					continue
				}
			}
			window.isHidden = true
		}
	}

	private func unhideVideos() {
		let allWindows = UIApplication.shared.windows
		guard !allWindows.isEmpty else {
			return
		}
		let windows = allWindows.suffix(from: 1)
		for window in windows {
			if let root = window.rootViewController {
				if root is LockPresenterController {
					continue
				}
			}
			window.isHidden = false
		}
	}

	@objc private func willEnterForeground(_ notification: Notification) {
		assert(!isMain)
		if !(PasscodeManager.shared?.openingAppNeedsUnlock ?? false) {
			uiUnlock()
		} else {
			autoPromptForBiometrics = true
			if case .blank = mode {
				setProperMode()
			}
		}
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

extension LockController: UINavigationControllerDelegate {
	public func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
		return LockController.supportedInterfaceOrientations ?? navigationController.topViewController?.supportedInterfaceOrientations ?? super.supportedInterfaceOrientations
	}
}

class LockPresenterController: UIViewController {
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return UIDevice.current.userInterfaceIdiom == .pad ? .all : .portrait
	}
}
