//
//  SettingsDetailViewController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

protocol SettingsDetailViewControllerDelegate: AnyObject {
	func settingsDetailViewControllerShowSubscriptionSettings(_ settingsDetailVC: SettingsDetailViewController)
}

private extension UIView {
	var firstResponder: UIView? {
		if isFirstResponder {
			return self
		}
		for view in subviews {
			if let responder = view.firstResponder {
				return responder
			}
		}
		return nil
	}
}

class SettingsDetailViewController: UIViewController {
	@IBOutlet weak var tableView: UITableView!
	var manager: SettingsViewManager!

	private var observers = [NSObjectProtocol]()

	weak var delegate: SettingsDetailViewControllerDelegate?

	var rightBarButtonItem: UIBarButtonItem? {
		get {
			if navigationController?.viewControllers.contains(self) ?? false {
				return navigationItem.rightBarButtonItem
			} else {
				return splitMergeController?.detailRightBarButtonItem
			}
		}
		set {
			splitMergeController?.detailRightBarButtonItem = newValue
			navigationItem.setRightBarButton(newValue, animated: true)
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.backgroundView = nil
		tableView.backgroundColor = .clear
		tableView.alwaysBounceVertical = false

		manager.header.delegate = self
		manager.updateHeaderColor(animated: false)
		manager.setup()

		let keyboardObserver = NotificationCenter.default.addObserver(forName: UIWindow.keyboardWillChangeFrameNotification, object: nil, queue: nil) { [weak self] notification in
			self?.keyboadFrameWillChange(notification)
		}
		observers.append(keyboardObserver)

		let textObserver = NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] notification in
			self?.manager?.header.rescaleFont()
		}
		observers.append(textObserver)
	}

	deinit {
		for observer in observers {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	func expand() {
		manager.header.expand()
	}

	func switchToSubscriptionSettings() {
		delegate?.settingsDetailViewControllerShowSubscriptionSettings(self)
	}

	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		tableView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		manager.viewWillAppear(animated)
	}

	private func keyboadFrameWillChange(_ notification: Notification) {
		guard let info = notification.userInfo else {
			return
		}
		guard (info[UIWindow.keyboardIsLocalUserInfoKey] as! NSNumber).boolValue else {
			return
		}
		func inset(for rect: NSValue) -> CGFloat {
			let frame = UIScreen.main.coordinateSpace.convert(rect.cgRectValue, to: view)
			if frame.maxY < view.bounds.maxY {
				return 0
			} else {
				return max(0, view.bounds.maxY - frame.minY)
			}
		}
		let rawCurve = info[UIWindow.keyboardAnimationCurveUserInfoKey] as! NSNumber
		let curve = UIView.AnimationOptions(rawValue: UInt(rawCurve.intValue))
		let duration = (info[UIView.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
		let newInset = inset(for: info[UIView.keyboardFrameEndUserInfoKey] as! NSValue)
		let oldInset = inset(for: info[UIView.keyboardFrameBeginUserInfoKey] as! NSValue)
		let diff = newInset - oldInset
		UIView.animate(withDuration: duration, delay: 0, options: curve, animations: {
			self.tableView.horizontalScrollIndicatorInsets.bottom += diff
			self.tableView.verticalScrollIndicatorInsets.bottom += diff
			self.tableView.contentInset.bottom += diff
		})
		guard let textField = tableView?.firstResponder as? UITextField else {
			return
		}
		guard let cell = textField.superview as? UITableViewCell else {
			return
		}
		guard let indexPath = tableView.indexPath(for: cell) else {
			return
		}
		tableView.scrollToRow(at: indexPath, at: .none, animated: true)
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
