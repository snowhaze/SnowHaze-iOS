//
//  SettingsDetailViewController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

protocol SettingsDetailViewControllerDelegate: AnyObject {
	func settingsDetailViewControllerShowSubscriptionSettings(_ settingsDetailVC: SettingsDetailViewController)
}

class SettingsDetailViewController: UIViewController {
	@IBOutlet weak var tableView: UITableView!
	var manager: SettingsViewManager!

	weak var delegate: SettingsDetailViewControllerDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.backgroundView = nil
		tableView.backgroundColor = .clear
		tableView.alwaysBounceVertical = false

		manager.header.delegate = self
		manager.updateHeaderColor(animated: false)
		manager.setup()
	}

	func expand() {
		manager.header.expand()
	}

	func switchToSubscriptionSettings() {
		delegate?.settingsDetailViewControllerShowSubscriptionSettings(self)
	}

	@available (iOS 11, *)
	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		tableView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		manager.viewWillAppear(animated)
	}
}

extension SettingsDetailViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return manager.heightForHeader(inSection: section)
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return manager.heightForRow(atIndexPath: indexPath)
	}

	func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return manager.heightForFooter(inSection: section)
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return manager.viewForHeader(inSection: section)
	}

	func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return manager.viewForFooter(inSection: section)
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return manager.titleForHeader(inSection: section)
	}

	func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return manager.titleForFooter(inSection: section)
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		manager.didSelectRow(atIndexPath: indexPath, tableView: tableView)
	}
}

extension SettingsDetailViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return manager.numberOfRows(inSection: section)
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return manager.cellForRow(atIndexPath: indexPath, tableView: tableView)
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return manager.numberOfSections
	}
}

extension SettingsDetailViewController: SettingsDetailTableViewHeaderDelegate {
	func showDetails(for header: SettingsDetailTableViewHeader) {
		header.expand()
		tableView.reloadSections(IndexSet(integer: 0), with: .none)
	}
}
