//
//  SubscriptionSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let updateRestoreButtonProductsSection = 2
private let updateButtonRow = 0
private let restoreButtonRow = 1

private let optionsSection = 1

private let tokenSection = 0
private let tokenRow = 2

class SubscriptionSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("subscription settings explanation", comment: "explanations of the subscription settings tab")
	}

	private enum ActionStatus {
		case none
		case running
		case failed(Date)
		case succeded(Date)
	}

	private var updateStatus: ActionStatus = .none
	private var restoreStatus: ActionStatus = .none

	private var okDisappearDate: Date?
	private var isLoadingAuthToken = false

	private var loadingProducts = Set<String>()
	private var productLoadFailedMessages = [String: String]()

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.subscription]).color
	}

	override var numberOfSections: Int {
		return 3
	}

	override func setup() {
		super.setup()
		SubscriptionManager.shared.delegate = self
	}

	override func numberOfRows(inSection section: Int) -> Int {
		assert(tokenSection == 0)
		assert(optionsSection == 1)
		assert(updateRestoreButtonProductsSection == 2)
		switch section {
			case 0:		return 3
			case 1:		return SubscriptionManager.shared.products.count
			case 2:		return 5
			default:	fatalError("incorrect section")
		}
	}

	override func titleForFooter(inSection section: Int) -> String? {
		if section == optionsSection {
			let manager = SubscriptionManager.shared
			if let date = manager.expirationDate , manager.hasSubscription {
				let time = date.timeIntervalSinceNow
				if time < 0 {
					return nil
				}
				let days = Int(time / (24 * 60 * 60))
				if manager.subscriptionRenews {
					switch days {
						case 0:
							return NSLocalizedString("subscription renews within 0 days notice", comment: "text to indicate that the subscription will renew within the next 0 days")
						case 1:
							return NSLocalizedString("subscription renews within 1 days notice", comment: "text to indicate that the subscription will renew within the next 1 days")
						default:
							let format = NSLocalizedString("subscription renews within n days notice format", comment: "text to indicate that the subscription will renew within the next n days for n > 1")
							return String(format: format, "\(days)")
					}
				} else {
					switch days {
						case 0:
							return NSLocalizedString("subscription expire in 0 days notice", comment: "text to indicate that the subscription will expire in 0 days")
						case 1:
							return NSLocalizedString("subscription expire in 1 days notice", comment: "text to indicate that the subscription will expire in 1 days")
						default:
							let format = NSLocalizedString("subscription expire in n days notice", comment: "text to indicate that the subscription will expire in n days for n > 1")
							return String(format: format, "\(days)")
					}
				}
			}
			if !SubscriptionManager.shared.products.isEmpty {
				return NSLocalizedString("snowhaze premium subscription auto-renew notice", comment: "notice to warn users that snowhaze premium subscriptions auto-renew")
			}
		} else if section == updateRestoreButtonProductsSection {
			return NSLocalizedString("premium subscription conditions", comment: "conditions for the snowhaze premium autorenewing subscription")
		}
		return nil
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		assert(updateRestoreButtonProductsSection == optionsSection + 1)
		if section == updateRestoreButtonProductsSection && SubscriptionManager.shared.products.isEmpty {
			return 0
		}
		return super.heightForHeader(inSection: section) + (section == optionsSection ? 20 : 0)
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		if section == optionsSection && SubscriptionManager.shared.products.isEmpty {
			return 0
		} else if section == updateRestoreButtonProductsSection {
			let size = CGSize(width: contentWidth, height: 0)
			let text = titleForFooter(inSection: section)!
			let label = UILabel()
			label.text = text
			UIFont.setSnowHazeFont(on: label)
			label.numberOfLines = 0
			return label.sizeThatFits(size).height + 25
		}
		return super.heightForFooter(inSection: section) + (section == optionsSection ? 20 : 0)
	}

	override func titleForHeader(inSection section: Int) -> String? {
		if section == optionsSection && !SubscriptionManager.shared.products.isEmpty {
			return NSLocalizedString("snowhaze premium settings title", comment: "title of settings to subscribe to snowhaze premium")
		}
		return super.titleForHeader(inSection: section)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == tokenSection {
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("update snowhaze premium subscription options settings title", comment: "title of settings to auto-update the list of snowhaze premium subscription options")
				let uiSwitch = makeSwitch()
				uiSwitch.addTarget(self, action: #selector(toggleUpdateProductList(_:)), for: .valueChanged)
				uiSwitch.isOn = bool(for: updateSubscriptionProductListKey)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == 1 {
				cell.textLabel?.text = NSLocalizedString("update authorization token settings title", comment: "title of settings to auto-update the premium authorization token")
				let uiSwitch = makeSwitch()
				uiSwitch.addTarget(self, action: #selector(toggleUpdateAuthToken(_:)), for: .valueChanged)
				uiSwitch.isOn = bool(for: updateAuthorizationTokenKey)
				cell.accessoryView = uiSwitch
			} else if indexPath.row == tokenRow {
				cell.textLabel?.text = NSLocalizedString("current token hash settings title", comment: "title of the setting that displays the hash of the current premium authorization token")
				if SubscriptionManager.shared.hasSubscription {
					if let token = SubscriptionManager.shared.authorizationTokenHash {
						cell.detailTextLabel?.text = token.replace("[0-9a-fA-F]{2}(?!$)", template: "$0 ")
					} else {
						cell.detailTextLabel?.text = NSLocalizedString("tab to load new authorization token settings subtitle", comment: "subtitle of the setting to load a new authorization token")
					}
					cell.accessoryType = (okDisappearDate?.timeIntervalSinceNow) ?? 0 > 0 ? .checkmark : .none
					if isLoadingAuthToken {
						let spinner = UIActivityIndicatorView(style: .white)
						spinner.startAnimating()
						cell.accessoryView = spinner
					}
				} else {
					cell.detailTextLabel?.text = NSLocalizedString("subscribe to receive authorization token notice", comment: "text to indicate that an authorization token can only be received by subscribing to snowhaze premium")
				}
			} else {
				fatalError("unexpected IndexPath")
			}
		} else if indexPath.section == optionsSection {
			let manager = SubscriptionManager.shared
			let product = manager.products[indexPath.row]
			let id = product.id
			cell.textLabel?.text = "\(product.description) (\(product.priceString))"
			cell.accessoryType = manager.activeSubscription == id ? .checkmark : .none
			cell.detailTextLabel?.text = productLoadFailedMessages[id]
			if loadingProducts.contains(id) {
				let spinner = UIActivityIndicatorView(style: .white)
				spinner.startAnimating()
				cell.accessoryView = spinner
			}
		} else {
			if indexPath.row == updateButtonRow {
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
				if let title = title {
					let button = makeButton(for: cell)
					button.addTarget(self, action: #selector(updateProductList(_:)), for: .touchUpInside)
					button.setTitle(title, for: [])
				}
			} else if indexPath.row == restoreButtonRow {
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
				if let title = title {
					let button = makeButton(for: cell)
					button.addTarget(self, action: #selector(restorePurchases(_:)), for: .touchUpInside)
					button.setTitle(title, for: [])
				}
			} else if indexPath.row == 2 {
				let button = makeButton(for: cell)
				button.addTarget(self, action: #selector(showSupscriptionManagment(_:)), for: .touchUpInside)
				let title = NSLocalizedString("view all subscriptions settings title", comment: "title of settings to show the users subscriptions management settings in itunes")
				button.setTitle(title, for: [])
			} else if indexPath.row == 3 {
				let button = makeButton(for: cell)
				button.addTarget(self, action: #selector(showTOS(_:)), for: .touchUpInside)
				let title = NSLocalizedString("show subscription terms of service button title", comment: "title of the button to show the snowhaze premium subscription terms of service")
				button.setTitle(title, for: [])
			} else if indexPath.row == 4 {
				let button = makeButton(for: cell)
				button.addTarget(self, action: #selector(showPrivacyPolicy(_:)), for: .touchUpInside)
				let title = NSLocalizedString("show subscription privacy policy button title", comment: "title of the button to show the snowhaze premium subscription privacy policy")
				button.setTitle(title, for: [])
			}
		}
		return cell
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == tokenSection {
			if indexPath.row == tokenRow && SubscriptionManager.shared.hasSubscription {
				if let token = SubscriptionManager.shared.authorizationTokenHash {
					UIPasteboard.general.string = token
					let oldDate = okDisappearDate
					okDisappearDate = Date(timeIntervalSinceNow: 0.9)
					if oldDate?.timeIntervalSinceNow ?? -1 < 0 {
						tableView.reloadRows(at: [indexPath], with: .fade)
					}
					DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
						if self?.okDisappearDate?.timeIntervalSinceNow ?? 0 < 0 {
							tableView.reloadRows(at: [indexPath], with: .fade)
						}
					}
				} else {
					isLoadingAuthToken = true
					let indexPath = IndexPath(row: tokenRow, section: tokenSection)
					controller?.tableView.reloadRows(at: [indexPath], with: .fade)
					if PolicyManager.globalManager().autoUpdateAuthToken {
						SubscriptionManager.shared.updateAuthToken() { [weak self] _ in
							self?.isLoadingAuthToken = false
							let indexPath = IndexPath(row: tokenRow, section: tokenSection)
							self?.controller?.tableView.reloadRows(at: [indexPath], with: .fade)
						}
					}
				}
			} else {
				super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
			}
		} else if indexPath.section == optionsSection {
			let wrappedProduct = SubscriptionManager.shared.products[indexPath.row]
			let id = wrappedProduct.id
			if !loadingProducts.contains(id) {
				if let product = wrappedProduct.product {
					SubscriptionManager.shared.purchase(product)
					if productLoadFailedMessages[id] != nil {
						productLoadFailedMessages[id] = nil
						tableView.reloadRows(at: [indexPath], with: .fade)
					}
				} else {
					let manager = SubscriptionManager.shared
					loadingProducts.insert(id)
					tableView.reloadRows(at: [indexPath], with: .fade)
					manager.load(product: id) { [weak self] product, error in
						let section = optionsSection
						guard let row = manager.products.index(where: { $0.id == id }), let me = self else {
							return
						}
						me.loadingProducts.remove(id)
						if let product = product {
							manager.purchase(product)
							me.productLoadFailedMessages[id] = nil
						} else {
							me.productLoadFailedMessages[id] = error!.localizedDescription
							DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
								guard self?.productLoadFailedMessages[id] == error!.localizedDescription else {
									return
								}
								self?.productLoadFailedMessages[id] = nil
								if let index = SubscriptionManager.shared.products.index(where: { $0.id == id }) {
									let indexPath = IndexPath(row: index, section: section)
									tableView.reloadRows(at: [indexPath], with: .fade)
								}
							}
						}
						tableView.reloadRows(at: [IndexPath(row: row, section: section)], with: .fade)
					}
				}
			}
		} else {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		}
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

	@objc private func updateProductList(_ sender: UIButton) {
		updateStatus = .running
		let indexPath = IndexPath(row: updateButtonRow, section: updateRestoreButtonProductsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		DownloadManager.shared.updateProductList(force: true) { [weak self] success in
			guard let me = self else {
				return
			}
			let date = Date(timeIntervalSinceNow: 0.9)
			if success {
				me.updateStatus = .succeded(date)
			} else {
				me.updateStatus = .failed(date)
			}
			let indexPath = IndexPath(row: updateButtonRow, section: updateRestoreButtonProductsSection)
			me.controller.tableView.reloadRows(at: [indexPath], with: .fade)
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
				guard let me = self else {
					return
				}
				switch me.updateStatus {
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
				me.updateStatus = .none
				let indexPath = IndexPath(row: updateButtonRow, section: updateRestoreButtonProductsSection)
				me.controller.tableView.reloadRows(at: [indexPath], with: .fade)
			}
		}
	}

	@objc private func restorePurchases(_ sender: UIButton) {
		restoreStatus = .running
		let indexPath = IndexPath(row: restoreButtonRow, section: updateRestoreButtonProductsSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		SubscriptionManager.shared.restorePurchases()
	}

	@objc private func showSupscriptionManagment(_ sender: UIButton) {
		if #available(iOS 10, *) {
			UIApplication.shared.open(URL(string: "itmss://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")!)
		} else {
			UIApplication.shared.openURL(URL(string: "itmss://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")!)
		}
	}

	@objc private func showTOS(_ sender: UIButton) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		let language = PolicyManager.globalManager().threeLanguageCode
		let site = "https://snowhaze.com/\(language)/terms-of-service.html"
		mainVC?.loadInFreshTab(input: site, type: .url)
	}

	@objc private func showPrivacyPolicy(_ sender: UIButton) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		let language = PolicyManager.globalManager().threeLanguageCode
		let site = "https://snowhaze.com/\(language)/privacy-policy.html"
		mainVC?.loadInFreshTab(input: site, type: .url)
	}
}

extension SubscriptionSettingsManager: SubscriptionManagerDelegate {
	func productListDidChange() {
		controller.tableView.reloadSections(IndexSet(integer: 1), with: .none)
	}

	func activeAubscriptionStatusChanged(fromId: String?) {
		controller?.tableView.reloadSections(IndexSet(integer: 1), with: .none)
		let indexPath = IndexPath(row: tokenRow, section: tokenSection)
		controller?.tableView.reloadRows(at: [indexPath], with: .none)
		updateHeaderColor(animated: true)
	}

	func purchaseFailed(besause description: String?) {
		let title = NSLocalizedString("purchase failed error alert title", comment: "title of alert to inform users that a purchase has failed")
		let error = NSLocalizedString("purchase failed error alert unknown error message", comment: "displayed instead of the error message in the alert to inform users that a purchase has failed when the reason for the failure is unknown")
		let ok = NSLocalizedString("purchase failed error alert ok button title", comment: "title of the ok button of the alert to inform users that a purchase has failed")
		let alert = UIAlertController(title: title, message: description ?? error, preferredStyle: .alert)
		let cancel = UIAlertAction(title: ok, style: .default, handler: nil)
		alert.addAction(cancel)
		controller.present(alert, animated: true, completion: nil)
	}

	func restoreFinished(succesfully success: Bool) {
		let date = Date(timeIntervalSinceNow: 0.9)
		let oldRestore = restoreStatus
		if success {
			restoreStatus = .succeded(date)
		} else {
			restoreStatus = .failed(date)
		}
		let indexPath = IndexPath(row: restoreButtonRow, section: updateRestoreButtonProductsSection)
		switch oldRestore {
			case .none, .running:	controller.tableView.reloadRows(at: [indexPath], with: .fade)
			default:				break
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
			guard let me = self else {
				return
			}
			switch me.restoreStatus {
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
			me.restoreStatus = .none
			let indexPath = IndexPath(row: restoreButtonRow, section: updateRestoreButtonProductsSection)
			me.controller.tableView.reloadRows(at: [indexPath], with: .fade)
		}
	}
}
