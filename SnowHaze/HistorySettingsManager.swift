//
//  HistorySettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class HistorySettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("history settings explanation", comment: "explanations of the history settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.history]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 0 {
			let uiSwitch = makeSwitch()
			if indexPath.row == 0 {
				cell.textLabel?.text = NSLocalizedString("save history setting title", comment: "title of save history setting")
				uiSwitch.isOn = bool(for: saveHistoryKey)
				uiSwitch.addTarget(self, action: #selector(toggleSaveHistory(_:)), for: .valueChanged)
			} else {
				cell.textLabel?.text = NSLocalizedString("forget private sites setting title", comment: "title of forget private sites setting")
				uiSwitch.isOn = bool(for: forgetPrivateSitesKey)
				uiSwitch.addTarget(self, action: #selector(toggleForgetPrivateSites(_:)), for: .valueChanged)
			}
			cell.accessoryView = uiSwitch
		} else {
			let button = makeButton(for: cell)
			button.addTarget(self, action: #selector(confirmClearHistory(_:)), for: .touchUpInside)
			let title = NSLocalizedString("clear history button title", comment: "title of button that deletes all history items")
			button.setTitle(title, for: [])
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return section == 0 ? 2 : 1
	}

	override var numberOfSections: Int {
		return 2
	}

	@objc private func toggleSaveHistory(_ sender: UISwitch) {
		set(sender.isOn, for: saveHistoryKey)
		updateHeaderColor(animated: true)
	}

	@objc private func toggleForgetPrivateSites(_ sender: UISwitch) {
		set(sender.isOn, for: forgetPrivateSitesKey)
		updateHeaderColor(animated: true)
	}

	@objc private func confirmClearHistory(_ sender: UIButton) {
		let title = NSLocalizedString("clear history confirm dialog title", comment: "title for dialog to confirm clearing of history")
		let message = NSLocalizedString("clear history confirm dialog message", comment: "message for dialog to confirm clearing of history")
		let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)

		let reset = NSLocalizedString("clear history confirm dialog confirm option title", comment: "title for confirm option of dialog to confirm clearing of history")
		let confirmAction = UIAlertAction(title: reset, style: .destructive) { _ in
			let store = HistoryStore.store
			guard let count = store.itemsByDate?.count , count > 0 else {
				return
			}
			let indexes = 0 ... count - 1
			indexes.reversed().forEach { store.removeSection(at: $0) }
		}
		alert.addAction(confirmAction)

		let cancel = NSLocalizedString("clear history confirm dialog cancel option title", comment: "title for cancel option of dialog to confirm clearing of history")
		let cancelAction = UIAlertAction(title: cancel, style: .cancel, handler: nil)
		alert.addAction(cancelAction)
		alert.popoverPresentationController?.sourceView = sender
		alert.popoverPresentationController?.sourceRect = sender.bounds
		controller.present(alert, animated: true, completion: nil)
	}
}
