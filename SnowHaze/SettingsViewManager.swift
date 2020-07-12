//
//  SettingsViewManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewManager: NSObject {
	class OneWaySwitch: UIView {
		private let uiSwitch: UISwitch
		init(manager: SettingsViewManager, action: Selector) {
			let imageSize: CGFloat = 25
			let flexible: UIView.AutoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
			uiSwitch = manager.makeSwitch()
			uiSwitch.isOn = true
			uiSwitch.addTarget(manager, action: action, for: .valueChanged)
			uiSwitch.autoresizingMask = flexible
			let blocked = UIImageView(image: #imageLiteral(resourceName: "blocked"))
			blocked.frame = CGRect(x: 0, y: 0, width: imageSize, height: imageSize)
			blocked.autoresizingMask = flexible
			uiSwitch.center = CGPoint(x: 0, y: imageSize / 2)
			uiSwitch.frame.origin.x = imageSize + 10
			super.init(frame: CGRect(x: 0, y: 0, width: uiSwitch.frame.width + imageSize + 10, height: imageSize))
			addSubview(uiSwitch)
			addSubview(blocked)
		}

		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		func trigger() {
			uiSwitch.setOn(false, animated: true)
			uiSwitch.sendActions(for: UIControl.Event.valueChanged)
		}
	}

	let settings = SettingsDefaultWrapper.wrapGlobalSettings()

	weak var controller: SettingsDetailViewController!

	func viewWillAppear(_ animated: Bool) { }

	func html() -> String {
		fatalError("SettingsViewManager is an abstract superclass")
	}

	func setup() { }

	private(set) lazy var header: SettingsDetailTableViewHeader = {
		let header = SettingsDetailTableViewHeader(reuseIdentifier: "header")
		let color = UIColor.title.hex
		let bold = UIFont.boldSystemFont(ofSize: header.size)
		header.sectionDescription = HTMLParser(html: self.html(), boldFont: bold).attributedString
		return header
	}()

	func updateHeaderColor(animated: Bool) {
		if animated {
			UIView.animate(withDuration: 0.2, animations: {
				self.header.color = self.assessmentResultColor
			})
		} else {
			header.color = assessmentResultColor
		}
	}

	var rightBarButtonItem: UIBarButtonItem? {
		get {
			return controller?.rightBarButtonItem
		}
		set {
			controller?.rightBarButtonItem = newValue
		}
	}

	var assessmentResultColor: UIColor {
		return PolicyAssessmentResult.color(for: .veryBad)
	}

	func bool(for key: String) -> Bool {
		return settings.value(for: key).boolValue
	}

	func set(_ value: Bool, for key: String) {
		settings.set(.bool(value), for: key)
	}

	func makeSwitch() -> UISwitch {
		let uiSwitch = UISwitch()
		uiSwitch.tintColor = .switchOff
		uiSwitch.backgroundColor = .switchOff
		uiSwitch.onTintColor = .switchOn
		uiSwitch.thumbTintColor = .title
		uiSwitch.layer.cornerRadius = uiSwitch.bounds.height / 2
		return uiSwitch
	}

	func makeProgressView(for cell: UITableViewCell) -> UIProgressView {
		let progress = UIProgressView(frame: cell.bounds)
		progress.frame.size.width -= 40
		progress.center = CGPoint(x: cell.bounds.midX, y: cell.bounds.midY)
		progress.progressTintColor = .button
		progress.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
		cell.addSubview(progress)
		return progress
	}

	func makeButton(for cell: UITableViewCell) -> UIButton {
		let button = SettingsButton(frame: cell.bounds)
		button.setTitleColor(.darkTitle, for: .disabled)
		cell.textLabel?.text = ""
		button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		cell.addSubview(button)
		return button
	}

	private class SettingsButton: UIButton { }
	func makeTextField(for cell: UITableViewCell) -> UITextField {
		let frame = CGRect(x: cell.bounds.minX + 20, y: cell.bounds.midY - 20, width: cell.bounds.maxX - 40, height: 40)
		let textField = UITextField(frame: frame)
		textField.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin, .flexibleTopMargin]
		textField.layer.cornerRadius = 20
		textField.clipsToBounds = true
		textField.backgroundColor = .white
		textField.layer.borderColor = UIColor.black.cgColor
		textField.layer.borderWidth = 2
		textField.textAlignment = .center
		textField.tintColor = .button
		cell.addSubview(textField)
		return textField
	}

	private class ContainerView: UIView { }
	func containerView(with frame: CGRect) -> UIView {
		return ContainerView(frame: frame)
	}

	func open(_ site: String) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		mainVC?.loadInFreshTab(input: site, type: .url)
	}

	func makeActivity(for cell: UITableViewCell) -> UIActivityIndicatorView {
		let activity: UIActivityIndicatorView
		if #available(iOS 13, *) {
			activity = UIActivityIndicatorView(style: .medium)
			activity.color = .white
		} else {
			activity = UIActivityIndicatorView(style: .white)
		}
		activity.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
		activity.center = CGPoint(x: cell.bounds.midX, y: cell.bounds.midY)
		activity.startAnimating()
		cell.addSubview(activity)
		return activity
	}

	func getCell(for tableView: UITableView) -> UITableViewCell {
		let id = "cell"
		if let cell = tableView.dequeueReusableCell(withIdentifier: id) {
			for subview in cell.subviews {
				if subview is UILabel && subview != cell.textLabel && subview != cell.detailTextLabel {
					subview.removeFromSuperview()
				} else if subview is SettingsButton || subview is UIActivityIndicatorView {
					subview.removeFromSuperview()
				} else if subview is UISegmentedControl || subview is UITextField {
					subview.removeFromSuperview()
				} else if subview is UIProgressView {
					subview.removeFromSuperview()
				} else if subview is ContainerView {
					subview.removeFromSuperview()
				} else if subview is UISwitch {
					subview.removeFromSuperview()
				}
			}
			cell.accessoryType = .none
			cell.accessoryView = nil
			cell.textLabel?.text = ""
			cell.detailTextLabel?.text = ""
			cell.accessibilityLabel = nil
			cell.imageView?.image = nil

			// UIKit sometimes resets the labels, making them loose their color
			cell.textLabel?.textColor = .title
			cell.detailTextLabel?.textColor = .subtitle

			return cell
		}
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
		cell.backgroundColor = UIColor(white: 1, alpha: 0.1)
		cell.textLabel?.textColor = .title
		cell.detailTextLabel?.textColor = .subtitle
		cell.selectionStyle = .none
		cell.tintColor = .title
		return cell
	}

	func numberOfRows(inSection section: Int) -> Int {
		return 0
	}

	func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		return 55
	}

	func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		return cell
	}

	var numberOfSections: Int {
		return 1
	}

	func viewForHeader(inSection section: Int) -> UIView? {
		if section == 0 {
			return header
		}
		guard let title = titleForHeader(inSection: section) else {
			return nil
		}
		let label = UILabel()
		label.text = title
		label.textColor = .title
		let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
		label.frame = view.bounds
		label.frame.origin.x = controller?.tableView.separatorInset.left ?? 0
		label.frame.size.width -= controller?.tableView.separatorInset.left ?? 0
		view.addSubview(label)
		label.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleRightMargin]
		return view
	}

	func viewForFooter(inSection section: Int) -> UIView? {
		guard let title = titleForFooter(inSection: section) else {
			return nil
		}
		let label = UILabel()
		label.text = title
		label.textColor = .title
		let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
		label.numberOfLines = 0
		view.addSubview(label)

		label.translatesAutoresizingMaskIntoConstraints = false
		let inset = controller?.tableView.separatorInset.left ?? 0
		let views = ["label": label]
		let metrics = ["inset": inset]
		var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-inset-[label]-inset-|", metrics: metrics, views:views)
		constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[label]-0-|", metrics: nil, views: views)
		NSLayoutConstraint.activate(constraints)

		return view
	}

	func heightForHeader(inSection section: Int) -> CGFloat {
		return section == 0 ? header.bestHeight : 0
	}

	func heightForFooter(inSection section: Int) -> CGFloat {
		return 30
	}

	func titleForHeader(inSection section: Int) -> String? {
		return nil
	}

	func titleForFooter(inSection section: Int) -> String? {
		return nil
	}

	func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		guard let cell = tableView.cellForRow(at: indexPath) else {
			return
		}
		if let uiSwitch = cell.accessoryView as? OneWaySwitch {
			uiSwitch.trigger()
			return
		}
		guard let uiSwitch = cell.accessoryView as? UISwitch else {
			return
		}
		guard uiSwitch.isEnabled else {
			return
		}
		uiSwitch.setOn(!uiSwitch.isOn, animated: true)
		uiSwitch.sendActions(for: UIControl.Event.valueChanged)
	}

	var contentWidth: CGFloat {
		guard let tableView = controller?.tableView else {
			return 0
		}
		let fullWidth = tableView.bounds.width
		let insets = tableView.separatorInset.left
		return fullWidth - 2 * insets
	}
}
