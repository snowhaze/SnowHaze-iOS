//
//  SubscriptionSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class SubscriptionSettingsManager: MultiviewSettingsManager<SubscriptionSettingsManager.Mode> {
	internal enum Mode: Int, MultiviewSettingsManagerMode {
		static func defaultValue() -> SubscriptionSettingsManager.Mode {
			return .normal
		}

		case normal
		case register
		case login
	}

	private lazy var normalManager: DefaultSubscriptionSettingsManager = {
		DefaultSubscriptionSettingsManager(parent: self)
	}()

	private lazy var registerManager: RegisterSubscriptionSettingsManager = {
		RegisterSubscriptionSettingsManager(parent: self)
	}()

	private lazy var loginManager: LoginSubscriptionSettingsManager = {
		LoginSubscriptionSettingsManager(parent: self)
	}()

	override func createManager(for mode: Mode) -> SettingsViewManager {
		switch mode {
			case .normal:	return normalManager
			case .register:	return registerManager
			case .login:	return loginManager
		}
	}

	private lazy var cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
	override func barButton(for mode: Mode) -> UIBarButtonItem? {
		switch mode {
			case .normal:	return nil
			case .register:	return cancelButton
			case .login:	return cancelButton
		}
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.subscription]).color
	}

	func switchToLogin() {
		switchTo(.login)
	}

	func switchToRegister() {
		guard case .normal = mode else {
			return
		}
		switchTo(.register)
	}

	func switchToNormal() {
		switchTo(.normal)
	}

	@objc private func cancel() {
		switchToNormal()
	}

	class func canShow(_ error: V3APIConnection.Error) -> Bool {
		switch error {
			case .network:			return true
			case .noSuchAccount:	return true
			case .emailInUse:		return true
			default: 				return false
		}
	}

	class func show(error: V3APIConnection.Error, in hostVC: UIViewController) {
		let type: AlertType
		switch error {
			case .network:				type = .subscriptionNetworkError
			case .noSuchAccount:		type = .subscriptionNoSuchAccountError
			case .emailInUse:			type = .subscriptionEmailInUseError
			case .clearMasterSecret:	type = .subscriptionLogout
			default:					fatalError("no error message for error \(error) implemented")
		}
		hostVC.present(type.build(), animated: true, completion: nil)
	}
}
