//
//  DefaultSubscriptionSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

let optionsSection = 0
let optionsRow = 0
let accountRow = 1

let settingsSection = 1
let optionsUpdateSettingsRow = 0
let tokenUpdateSettingsRow = 1
let loadOptionsButtonRow = 2
let restorePurchasesButtonRow = 3

let miscSection = 2
let dashboardButtonRow = 0
let tutorialsButtonRow = 1
let manageSubscriptionsButtonRow = 2
let tosButtonRow = 3
let privacyPolicyButtonRow = 4

let tokenSection = 3
let tokenRow = 0

let verificationSection = 4
let verificationScriptRow = 0
let verificationBlobRow = 1

class DefaultSubscriptionSettingsManager: SettingsViewManager {
	private weak var parent: SubscriptionSettingsManager?
	private var observers = [NSObjectProtocol]()
	init(parent: SubscriptionSettingsManager) {
		self.parent = parent
		super.init()
		controller = parent.controller

		let tokenObserver = NotificationCenter.default.addObserver(forName: SubscriptionManager.tokenUpdatedNotification, object: nil, queue: nil) { [weak self] _ in
			self?.reloadZKA1Token()
		}
		observers.append(tokenObserver)

		let statusObserver = NotificationCenter.default.addObserver(forName: SubscriptionManager.statusUpdatedNotification, object: nil, queue: nil) { [weak self] _ in
			self?.reloadZKA1Token()
			self?.reloadOptions()
			self?.updateHeaderColor(animated: true)
		}
		observers.append(statusObserver)

		let secretObserver = NotificationCenter.default.addObserver(forName: V3APIConnection.masterSecretChangedNotification, object: nil, queue: nil) { [weak self] _ in
			self?.reloadLoginRow()
		}
		observers.append(secretObserver)
	}

	private func reloadOptions() {
		guard parent?.isActive(self) ?? false else {
			return
		}
		let indexPath = IndexPath(row: optionsRow, section: optionsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
	}

	private func reloadZKA1Token() {
		guard parent?.isActive(self) ?? false else {
			return
		}
		if !V3APIConnection.hasSecret {
			let indexPath = IndexPath(row: tokenRow, section: tokenSection)
			controller?.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}

	private func reloadLoginRow() {
		guard parent?.isActive(self) ?? false else {
			return
		}
		let indexPath = IndexPath(row: accountRow, section: optionsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
	}

	private enum ActionStatus {
		case none
		case running
		case failed(Date)
		case succeded(Date)
	}

	private var updateStatus: ActionStatus = .none
	private var restoreStatus: ActionStatus = .none

	private var tokenOkDisappearDate: Date?
	private var blobOkDisappearDate: Date?
	private var isLoadingAuthToken = false

	override func html() -> String {
		return NSLocalizedString("subscription settings explanation", comment: "explanations of the subscription settings tab")
	}

	override var numberOfSections: Int {
		return 5
	}

	override func setup() {
		super.setup()
		header.icon = parent?.header.icon
		header.delegate = parent?.header.delegate
		header.color = assessmentResultColor
		SubscriptionManager.shared.delegate = self
	}

	override var assessmentResultColor: UIColor {
		return parent?.assessmentResultColor ?? PolicyAssessmentResult.color(for: .veryBad)
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		assert(optionsSection == 0)
		switch indexPath.section {
			case 0:		if indexPath.row == optionsRow {
							return 220
						} else {
							assert(indexPath.row == accountRow)
							let hasSecret = V3APIConnection.hasSecret
							return hasSecret ? super.heightForRow(atIndexPath: indexPath) : 100
						}
			default:	return super.heightForRow(atIndexPath: indexPath)
		}
	}

	override func numberOfRows(inSection section: Int) -> Int {
		assert(optionsSection == 0)
		assert(settingsSection == 1)
		assert(miscSection == 2)
		assert(tokenSection == 3)
		assert(verificationSection == 4)
		switch section {
			case 0:		return 2
			case 1:		return 4
			case 2:		return 5
			case 3:		return 1
			case 4:		return SubscriptionManager.shared.hasVerificationBlob ? 2 : 1
			default:	fatalError("incorrect section")
		}
	}

	override func titleForFooter(inSection section: Int) -> String? {
		assert(verificationSection == numberOfSections - 1)
		if section == verificationSection {
			return NSLocalizedString("premium subscription conditions", comment: "conditions for the snowhaze premium autorenewing subscription")
		}
		return nil
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		assert(verificationSection == numberOfSections - 1)
		if section == verificationSection {
			let size = CGSize(width: contentWidth, height: 0)
			let text = titleForFooter(inSection: section)!
			let label = UILabel()
			label.text = text
			label.numberOfLines = 0
			return label.sizeThatFits(size).height + 25
		}
		return super.heightForFooter(inSection: section)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == optionsSection {
			if indexPath.row == optionsRow {
				let titleLabel = UILabel()
				titleLabel.text = NSLocalizedString("snowhaze premium settings title", comment: "title of settings to subscribe to snowhaze premium")
				titleLabel.frame = CGRect(x: cell.separatorInset.left, y: 0, width: cell.bounds.width - 40, height: 40)
				titleLabel.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				titleLabel.textColor = .title
				cell.addSubview(titleLabel)

				let subscriptionLabel = UILabel()
				subscriptionLabel.text = subscriptionStatus
				subscriptionLabel.frame = CGRect(x: cell.separatorInset.left, y: cell.bounds.height - 60, width: cell.bounds.width - 40, height: 60)
				subscriptionLabel.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
				subscriptionLabel.textColor = .title
				subscriptionLabel.numberOfLines = 2
				cell.addSubview(subscriptionLabel)

				let manager = SubscriptionManager.shared
				if let products = manager.products {
					if let yearly = products.yearly {
						let yearlyButton = makeButton(for: cell)
						let yearlyColor = yearly.id == manager.activeSubscription ? UIColor.veryGoodPrivacy : UIColor.button
						yearlyButton.layer.backgroundColor = yearlyColor.cgColor
						yearlyButton.layer.cornerRadius = 25
						yearlyButton.addTarget(self, action: #selector(yearlyOptionButtonPressed(_:)), for: .touchUpInside)
						yearlyButton.setTitle("\(yearly.description) (\(yearly.priceString))", for: [])
						yearlyButton.frame = CGRect(x: cell.bounds.width * 0.1, y: 40, width: cell.bounds.width * 0.8, height: 50)
						yearlyButton.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
					}

					if let monthly = products.monthly {
						let monthlyButton = makeButton(for: cell)
						let monthlyColor = monthly.id == manager.activeSubscription ? UIColor.veryGoodPrivacy : UIColor.button
						monthlyButton.layer.backgroundColor = monthlyColor.cgColor
						monthlyButton.layer.cornerRadius = 25
						monthlyButton.addTarget(self, action: #selector(monthlyOptionButtonPressed(_:)), for: .touchUpInside)
						monthlyButton.setTitle("\(monthly.description) (\(monthly.priceString))", for: [])
						monthlyButton.frame = CGRect(x: cell.bounds.width * 0.15, y: 110, width: cell.bounds.width * 0.7, height: 50)
						monthlyButton.autoresizingMask = [.flexibleWidth, .flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
					}
				} else {
					let button = makeButton(for: cell)
					button.setTitleColor(.button, for: [])
					button.addTarget(self, action: #selector(loadOptionsButtonPressed(_:)), for: .touchUpInside)
					let loadTitle = NSLocalizedString("load snowhaze premium options button title", comment: "title of button to manually load the list of snowhaze premium subscription options")
					button.setTitle(loadTitle, for: [])
				}
			} else if indexPath.row == accountRow {
				let hasSecret = V3APIConnection.hasSecret
				let logInOutButton = makeButton(for: cell)
				logInOutButton.setTitleColor(.button, for: [])
				logInOutButton.addTarget(self, action: #selector(logInOutButtonPressed(_:)), for: .touchUpInside)
				let logoutTitle = NSLocalizedString("zka2 logout button title", comment: "title of button to logout of zka2")
				let loginTitle = NSLocalizedString("zka2 login button title", comment: "title of button to login to zka2")
				let title = hasSecret ? logoutTitle : loginTitle
				logInOutButton.setTitle(title, for: [])
				let buttonHeight = hasSecret ? cell.bounds.height - 6 : 44
				logInOutButton.frame = CGRect(x: 0, y: 3, width: cell.bounds.width, height: buttonHeight)
				if hasSecret {
					logInOutButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
				} else {
					logInOutButton.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				}

				if !hasSecret {
					let setupButton = makeButton(for: cell)
					setupButton.setTitleColor(.button, for: [])
					setupButton.addTarget(self, action: #selector(useOnOtherDevicesButtonPressed(_:)), for: .touchUpInside)
					let registerTitle = NSLocalizedString("zka2 register button title", comment: "title of button to register for zka2")
					setupButton.setTitle(registerTitle, for: [])
					setupButton.frame = CGRect(x: 0, y: 53, width: cell.bounds.width, height: 44)
					setupButton.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				}
			} else {
				fatalError("invalid row")
			}
		} else if indexPath.section == settingsSection {
			if indexPath.row == optionsUpdateSettingsRow {
				cell.textLabel?.text = NSLocalizedString("update snowhaze premium subscription options settings title", comment: "title of settings to auto-update the list of snowhaze premium subscription options")
				let uiSwitch = makeSwitch()
				uiSwitch.addTarget(self, action: #selector(toggleUpdateProductList(_:)), for: .valueChanged)
				uiSwitch.isOn = bool(for: updateSubscriptionProductListKey)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == tokenUpdateSettingsRow {
				cell.textLabel?.text = NSLocalizedString("update authorization token settings title", comment: "title of settings to auto-update the premium authorization token")
				let uiSwitch = makeSwitch()
				uiSwitch.addTarget(self, action: #selector(toggleUpdateAuthToken(_:)), for: .valueChanged)
				uiSwitch.isOn = bool(for: updateAuthorizationTokenKey)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == loadOptionsButtonRow {
				let title: String?
				switch updateStatus {
				case .none:
					title = NSLocalizedString("load snowhaze premium options settings default title", comment: "title of settings to manually load the list of snowhaze premium subscription options when nothing special happened recently")
				case .running:
					_ = makeActivity(for: cell)
					title = nil
				case .failed(_):
					title = NSLocalizedString("load snowhaze premium options settings load failed title", comment: "title of settings to manually load the list of snowhaze premium subscription options when a load recently failed")
				case .succeded(_):
					title = NSLocalizedString("load snowhaze premium options settings load succeeded title", comment: "title of settings to manually load the list of snowhaze premium subscription options when a load recently succeeded")
				}
				cell.textLabel?.text = title
				if let _ = title {
					cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "reload"))
				}
			} else if indexPath.row == restorePurchasesButtonRow {
				let title: String?
				switch restoreStatus {
				case .none:
					title = NSLocalizedString("restore snowhaze premium purchase settings default title", comment: "title of settings to restore a snowhaze premium purchase when nothing special happened recently")
				case .running:
					_ = makeActivity(for: cell)
					title = nil
				case .failed(_):
					title = NSLocalizedString("restore snowhaze premium purchase settings restore failed title", comment: "title of settings to restore a snowhaze premium purchase when a restore recently failed")
				case .succeded(_):
					title = NSLocalizedString("restore snowhaze premium purchase settings restore succeeded title", comment: "title of settings to restore a snowhaze premium purchase when a restore recently succeeded")
				}
				cell.textLabel?.text = title
				if let _ = title {
					cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "reload"))
				}
			} else {
				fatalError("invalid row")
			}
		} else if indexPath.section == miscSection {
			if indexPath.row == dashboardButtonRow {
				cell.textLabel?.text = NSLocalizedString("open zka2 dashboard setting title", comment: "title of setting to open the zka2 dashboard")
				cell.accessoryView = getExternalLinkAccessory()
			} else if indexPath.row == tutorialsButtonRow {
				cell.textLabel?.text = NSLocalizedString("open zka2 tutorials setting title", comment: "title of setting to open the zka2 tutorials")
				cell.accessoryView = getExternalLinkAccessory()
			} else if indexPath.row == manageSubscriptionsButtonRow {
				cell.textLabel?.text = NSLocalizedString("view all subscriptions settings title", comment: "title of settings to show the users subscriptions management settings in itunes")
				cell.accessoryView = getExternalLinkAccessory()
			} else if indexPath.row == tosButtonRow {
				cell.textLabel?.text = NSLocalizedString("show subscription terms of service button title", comment: "title of the button to show the snowhaze premium subscription terms of service")
				cell.accessoryView = getExternalLinkAccessory()
			} else if indexPath.row == privacyPolicyButtonRow {
				cell.textLabel?.text = NSLocalizedString("show subscription privacy policy button title", comment: "title of the button to show the snowhaze premium subscription privacy policy")
				cell.accessoryView = getExternalLinkAccessory()
			} else {
				fatalError("invalid row")
			}
		} else if indexPath.section == tokenSection {
			assert(indexPath.row == tokenRow)
			if let key = V3APIConnection.crcedMasterSecretHex {
				cell.textLabel?.text = NSLocalizedString("zka2 master secret settings title", comment: "title of the setting that displays the zka2 master secret")
				cell.detailTextLabel?.text = key.replace("[0-9a-fA-F]{2}(?!$)", template: "$0 ")
			} else {
				cell.textLabel?.text = NSLocalizedString("current token hash settings title", comment: "title of the setting that displays the hash of the current premium authorization token")
				if SubscriptionManager.status.possible {
					if let token = SubscriptionManager.shared.authorizationTokenHash, SubscriptionManager.status.confirmed {
						cell.detailTextLabel?.text = token.replace("[0-9a-fA-F]{2}(?!$)", template: "$0 ")
					} else {
						cell.detailTextLabel?.text = NSLocalizedString("tab to load new authorization token settings subtitle", comment: "subtitle of the setting to load a new authorization token")
					}
				} else {
					cell.detailTextLabel?.text = NSLocalizedString("subscribe to receive authorization token notice", comment: "text to indicate that an authorization token can only be received by subscribing to snowhaze premium")
				}
			}
			cell.accessoryType = (tokenOkDisappearDate?.timeIntervalSinceNow) ?? 0 > 0 ? .checkmark : .none
			if isLoadingAuthToken {
				let spinner: UIActivityIndicatorView
				if #available(iOS 13, *) {
					spinner = UIActivityIndicatorView(style: .medium)
					spinner.color = .white
				} else {
					spinner = UIActivityIndicatorView(style: .white)
				}
				spinner.startAnimating()
				cell.accessoryView = spinner
			}
		} else if indexPath.section == verificationSection {
			if indexPath.row == verificationScriptRow {
				cell.textLabel?.text = NSLocalizedString("zka verification script settings title", comment: "title of the setting that links to the zka verification script")
				cell.accessoryView = getExternalLinkAccessory()
			} else {
				assert(indexPath.row == verificationBlobRow)
				cell.accessoryType = (blobOkDisappearDate?.timeIntervalSinceNow) ?? 0 > 0 ? .checkmark : .none
				cell.textLabel?.text = NSLocalizedString("zka verification blob settings title", comment: "title of the setting that displays the zka verification blob")
				cell.detailTextLabel?.text = SubscriptionManager.shared.verificationBlobBase64
			}
		} else {
			fatalError("invalid section")
		}
		return cell
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == optionsSection {
			assert((0..<2).contains(indexPath.row))
		} else if indexPath.section == tokenSection {
			assert(indexPath.row == tokenRow)
			if let key = V3APIConnection.crcedMasterSecretHex {
				UIPasteboard.general.string = key
				let oldDate = tokenOkDisappearDate
				tokenOkDisappearDate = Date(timeIntervalSinceNow: 0.9)
				if oldDate?.timeIntervalSinceNow ?? -1 < 0 {
					tableView.reloadRows(at: [indexPath], with: .fade)
				}
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
					if self?.tokenOkDisappearDate?.timeIntervalSinceNow ?? 0 < 0 {
						tableView.reloadRows(at: [indexPath], with: .fade)
					}
				}
			} else if let token = SubscriptionManager.shared.authorizationTokenHash, SubscriptionManager.status.confirmed {
				UIPasteboard.general.string = token
				let oldDate = tokenOkDisappearDate
				tokenOkDisappearDate = Date(timeIntervalSinceNow: 0.9)
				if oldDate?.timeIntervalSinceNow ?? -1 < 0 {
					reloadZKA1Token()
				}
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
					if self?.tokenOkDisappearDate?.timeIntervalSinceNow ?? 0 < 0 {
						self?.reloadZKA1Token()
					}
				}
			} else {
				isLoadingAuthToken = true
				reloadZKA1Token()
				if PolicyManager.globalManager().autoUpdateAuthToken {
					SubscriptionManager.shared.updateAuthToken() { [weak self] _ in
						self?.isLoadingAuthToken = false
						self?.reloadZKA1Token()
					}
				}
			}
		} else if indexPath.section == settingsSection {
			if indexPath.row == optionsUpdateSettingsRow || indexPath.row == tokenUpdateSettingsRow {
				super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
			} else if indexPath.row == loadOptionsButtonRow {
				updateProductList()
			} else if indexPath.row == restorePurchasesButtonRow {
				restorePurchases()
			} else {
				fatalError("invalid row")
			}
		} else if indexPath.section == miscSection {
			if indexPath.row == dashboardButtonRow {
				let language = PolicyManager.globalManager().threeLanguageCode
				open("https://dashboard.snowhaze.com/\(language)")
			} else if indexPath.row == tutorialsButtonRow {
				let language = PolicyManager.globalManager().threeLanguageCode
				open("https://snowhaze.com/\(language)/support-tutorials.html")
			} else if indexPath.row == manageSubscriptionsButtonRow {
				showSupscriptionManagment()
			} else if indexPath.row == tosButtonRow {
				showTOS()
			} else if indexPath.row == privacyPolicyButtonRow {
				showPrivacyPolicy()
			} else {
				fatalError("invalid row")
			}
		} else if indexPath.section == verificationSection {
			if indexPath.row == verificationScriptRow {
				let language = PolicyManager.globalManager().threeLanguageCode
				open("https://blog.snowhaze.com/zero-knowledge-auth-\(language)")
			} else if let blob = SubscriptionManager.shared.verificationBlobBase64 {
				assert(indexPath.row == verificationBlobRow)
				UIPasteboard.general.string = blob
				let oldDate = blobOkDisappearDate
				blobOkDisappearDate = Date(timeIntervalSinceNow: 0.9)
				if oldDate?.timeIntervalSinceNow ?? -1 < 0 {
					tableView.reloadRows(at: [indexPath], with: .fade)
				}
				DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
					let okExpired = self?.blobOkDisappearDate?.timeIntervalSinceNow ?? 0 < 0
					if okExpired && SubscriptionManager.shared.hasVerificationBlob {
						tableView.reloadRows(at: [indexPath], with: .fade)
					}
				}
			}
		} else {
			fatalError("invalid section")
		}
	}

	private func getExternalLinkAccessory() -> UIView {
		let image = #imageLiteral(resourceName: "external-link").withRenderingMode(.alwaysTemplate)
		let result = UIImageView(image: image)
		result.tintColor = .title
		return result
	}

	@objc private func toggleUpdateProductList(_ sender: UISwitch) {
		set(sender.isOn, for: updateSubscriptionProductListKey)
		updateHeaderColor(animated: true)
		if sender.isOn {
			DownloadManager.shared.triggerProductListUpdate()
		}
	}

	@objc private func toggleUpdateAuthToken(_ sender: UISwitch) {
		set(sender.isOn, for: updateAuthorizationTokenKey)
		updateHeaderColor(animated: true)
		if sender.isOn {
			DownloadManager.shared.triggerAuthTokenUpdate()
		}
	}

	@objc private func loadOptionsButtonPressed(_ sender: UIButton) {
		updateProductList()
	}

	@objc private func yearlyOptionButtonPressed(_ sender: UIButton) {
		if let yearly = SubscriptionManager.shared.products!.yearly {
			SubscriptionManager.shared.purchase(yearly)
		}
	}

	@objc private func monthlyOptionButtonPressed(_ sender: UIButton) {
		if let monthly = SubscriptionManager.shared.products!.monthly {
			SubscriptionManager.shared.purchase(monthly)
		}
	}

	@objc private func logInOutButtonPressed(_ sender: UIButton) {
		if V3APIConnection.hasSecret {
			V3APIConnection.clearMasterSecret()
			reloadLoginRow()
		} else {
			parent?.switchToLogin()
		}
	}

	@objc private func useOnOtherDevicesButtonPressed(_ sender: UIButton) {
		parent?.switchToRegister()
	}

	private func updateProductList() {
		updateStatus = .running
		let indexPath = IndexPath(row: loadOptionsButtonRow, section: settingsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		DownloadManager.shared.updateProductList(force: true) { [weak self] success in
			guard let self = self else {
				return
			}
			let date = Date(timeIntervalSinceNow: 0.9)
			if success {
				self.updateStatus = .succeded(date)
			} else {
				self.updateStatus = .failed(date)
			}
			let indexPath = IndexPath(row: loadOptionsButtonRow, section: settingsSection)
			self.controller?.tableView?.reloadRows(at: [indexPath], with: .fade)
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
				guard let self = self else {
					return
				}
				switch self.updateStatus {
				case .failed(let date):
					if date > Date() {
						return
					}
				case .succeded(let date):
					if date > Date() {
						return
					}
				default:
					return
				}
				self.updateStatus = .none
				let indexPath = IndexPath(row: loadOptionsButtonRow, section: settingsSection)
				self.controller?.tableView?.reloadRows(at: [indexPath], with: .fade)
			}
		}
	}

	private func restorePurchases() {
		restoreStatus = .running
		let indexPath = IndexPath(row: restorePurchasesButtonRow, section: settingsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		SubscriptionManager.shared.restorePurchases()
	}

	private func showSupscriptionManagment() {
		UIApplication.shared.open(URL(string: "itmss://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")!)
	}

	private func showTOS() {
		let language = PolicyManager.globalManager().threeLanguageCode
		let site = "https://snowhaze.com/\(language)/terms-of-service.html"
		open(site)
	}

	private func showPrivacyPolicy() {
		let language = PolicyManager.globalManager().threeLanguageCode
		let site = "https://snowhaze.com/\(language)/privacy-policy.html"
		open(site)
	}

	private var subscriptionStatus: String? {
		let manager = SubscriptionManager.shared
		if let date = manager.expirationDate, manager.status.confirmed {
			let time = date.timeIntervalSinceNow
			let days = Int(time / (24 * 60 * 60))
			guard days >= 0 else {
				return nil
			}
			if manager.subscriptionRenews {
				switch days {
				case 0:
					return NSLocalizedString("subscription renews within 0 days notice", comment: "text to indicate that the subscription will renew within the next 0 days")
				case 1:
					return NSLocalizedString("subscription renews within 1 days notice", comment: "text to indicate that the subscription will renew within the next 1 days")
				default:
					let format = NSLocalizedString("subscription renews within n days notice format", comment: "format of text to indicate that the subscription will renew within the next n days for n > 1")
					return String(format: format, "\(days)")
				}
			} else {
				switch days {
				case 0:
					return NSLocalizedString("subscription expires in 0 days notice", comment: "text to indicate that the subscription will expire in 0 days")
				case 1:
					return NSLocalizedString("subscription expires in 1 days notice", comment: "text to indicate that the subscription will expire in 1 days")
				default:
					let format = NSLocalizedString("subscription expires in n days notice format", comment: "format of text to indicate that the subscription will expire in n days for n > 1")
					return String(format: format, "\(days)")
				}
			}
		}
		return NSLocalizedString("snowhaze premium subscription auto-renew notice", comment: "notice to warn users that snowhaze premium subscriptions auto-renew")
	}
}

extension DefaultSubscriptionSettingsManager: SubscriptionManagerDelegate {
	func productListDidChange() {
		reloadOptions()
	}

	func activeSubscriptionChanged(fromId: String?) {
		reloadOptions()
		updateHeaderColor(animated: true)
	}

	func purchaseFailed(besause reason: String?) {
		let alert = AlertType.purchaseFailed(reason: reason).build()
		controller.present(alert, animated: true, completion: nil)
	}

	func apiErrorOccured(_ error: V3APIConnection.Error) {
		SubscriptionSettingsManager.show(error: error, in: controller.splitMergeController!)
	}

	func hasPreexistingPayments(until expiration: Date, renews: Bool, purchasing product: SubscriptionManager.Product) {
		let alert = AlertType.preexistingSubscription(expiration: expiration, renews: renews, product: product)
		controller?.splitMergeController?.present(alert.build(), animated: true, completion: nil)
	}

	func restoreFinished(succesfully success: Bool) {
		guard parent?.isActive(self) ?? false else {
			return
		}
		let date = Date(timeIntervalSinceNow: 0.9)
		let oldRestore = restoreStatus
		if success {
			restoreStatus = .succeded(date)
		} else {
			restoreStatus = .failed(date)
		}
		let indexPath = IndexPath(row: restorePurchasesButtonRow, section: settingsSection)
		switch oldRestore {
			case .none, .running:	controller.tableView.reloadRows(at: [indexPath], with: .fade)
			default:				break
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
			guard let self = self else {
				return
			}
			switch self.restoreStatus {
			case .failed(let date):
				if date > Date() {
					return
				}
			case .succeded(let date):
				if date > Date() {
					return
				}
			default:
				return
			}
			self.restoreStatus = .none
			let indexPath = IndexPath(row: restorePurchasesButtonRow, section: settingsSection)
			self.controller?.tableView?.reloadRows(at: [indexPath], with: .fade)
		}
	}

	func verificationBlobChanged(from oldBlob: String?) {
		guard parent?.isActive(self) ?? false else {
			return
		}
		let newBlob = SubscriptionManager.shared.verificationBlobBase64
		guard newBlob != oldBlob else {
			return
		}
		let indexPath = IndexPath(row: verificationBlobRow, section: verificationSection)
		if newBlob == nil {
			controller.tableView.deleteRows(at: [indexPath], with: .fade)
		} else if oldBlob == nil {
			controller.tableView.insertRows(at: [indexPath], with: .fade)
		} else {
			controller.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}
}
