//
//  SettingsViewManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class SettingsViewManager: NSObject {
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
		let bold = UIFont(name: BoldSnowHazeFontName, size: header.size)!
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

	private class SettingsButton: UIButton { }
	func makeButton(for cell: UITableViewCell) -> UIButton {
		let button = SettingsButton(frame: cell.bounds)
		button.setTitleColor(.darkTitle, for: .disabled)
		cell.textLabel?.text = ""
		UIFont.setSnowHazeFont(on: button)
		button.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		cell.addSubview(button)
		return button
	}

	func makeActivity(for cell: UITableViewCell) -> UIActivityIndicatorView {
		let activity = UIActivityIndicatorView(style: .white)
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
				if subview is SettingsButton || subview is UIActivityIndicatorView {
					subview.removeFromSuperview()
				}
			}
			cell.accessoryType = .none
			cell.accessoryView = nil
			cell.textLabel?.text = ""
			cell.detailTextLabel?.text = ""
			cell.accessibilityLabel = nil
			cell.imageView?.image = nil
			return cell
		}
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
		cell.backgroundColor = .clear
		cell.textLabel?.textColor = .title
		cell.detailTextLabel?.textColor = .subtitle
		cell.selectionStyle = .none
		cell.tintColor = .title
		UIFont.setSnowHazeFont(on: cell.textLabel!)
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
		UIFont.setSnowHazeFont(on: label)
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
		UIFont.setSnowHazeFont(on: label)
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
