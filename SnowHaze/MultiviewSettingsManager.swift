//
//  MultiviewSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2021 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

protocol MultiviewSettingsManagerMode: Hashable {
	static func defaultValue() -> Self
}

internal class MultiviewSettingsManager<Mode: MultiviewSettingsManagerMode> : SettingsViewManager {
	private(set) var mode: Mode = Mode.defaultValue()

	private var shouldSetup = false

	private var managers = [Mode: SettingsViewManager]()
	private var setupComplete = Set<Mode>()

	func createManager(for mode: Mode) -> SettingsViewManager {
		fatalError("MultiviewSettingsManager is an abstract superclass.")
	}

	func barButton(for mode: Mode) -> UIBarButtonItem? {
		fatalError("MultiviewSettingsManager is an abstract superclass.")
	}

	private func ensureManagerIsSetup() {
		guard !setupComplete.contains(mode) else {
			return
		}
		manager.setup()
		setupComplete.insert(mode)
	}

	override func html() -> String {
		return manager.html()
	}

	private func manager(for mode: Mode) -> SettingsViewManager {
		if let manager = managers[mode] {
			return manager
		}
		let manager = createManager(for: mode)
		managers[mode] = manager
		return manager
	}

	override var header: SettingsDetailTableViewHeader {
		if let manager = managers[mode], setupComplete.contains(mode) {
			ensureManagerIsSetup()
			return manager.header
		}
		return super.header
	}

	var manager: SettingsViewManager {
		return manager(for: mode)
	}

	override func setup() {
		guard case Mode.defaultValue() = mode else {
			fatalError("Invalid State")
		}
		super.setup()
		shouldSetup = true
		ensureManagerIsSetup()
	}

	func isActive(_ query: SettingsViewManager) -> Bool {
		return manager == query
	}

	override func updateHeaderColor(animated: Bool) {
		manager.updateHeaderColor(animated: animated)
	}

	override var numberOfSections: Int {
		return manager.numberOfSections
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		return manager.heightForRow(atIndexPath: indexPath)
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return manager.numberOfRows(inSection: section)
	}

	override func titleForHeader(inSection section: Int) -> String? {
		return manager.titleForHeader(inSection: section)
	}

	override func titleForFooter(inSection section: Int) -> String? {
		return manager.titleForFooter(inSection: section)
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		return manager.heightForFooter(inSection: section)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		return manager.cellForRow(atIndexPath: indexPath, tableView: tableView)
	}

	override func viewForHeader(inSection section: Int) -> UIView? {
		return manager.viewForHeader(inSection: section)
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		return manager.didSelectRow(atIndexPath: indexPath, tableView: tableView)
	}

	private func reloadData(with animation: UITableView.RowAnimation, change: () -> ()) {
		guard let tableView = self.controller?.tableView else {
			return
		}
		let oldSectionCount = manager.numberOfSections
		change()
		let newSectionCount = manager.numberOfSections
		let reloadSectionCount = min(newSectionCount, oldSectionCount)
		let reloadSections = IndexSet(integersIn: 0 ..< reloadSectionCount)
		let maxSectionCount = max(newSectionCount, oldSectionCount)
		let otherSections = IndexSet(integersIn: reloadSectionCount ..< maxSectionCount)
		tableView.beginUpdates()
		if newSectionCount > oldSectionCount {
			tableView.insertSections(otherSections, with: animation)
		} else if oldSectionCount > newSectionCount {
			tableView.deleteSections(otherSections, with: animation)
		}
		tableView.reloadSections(reloadSections, with: animation)
		tableView.endUpdates()
	}

	func switchTo(_ mode: Mode) {
		guard mode != self.mode else {
			return
		}
		reloadData(with: .fade) {
			self.mode = mode
			ensureManagerIsSetup()
			(manager as? ChildSettingsManager<Self>)?.resetIfNeeded()
			let newButton = barButton(for: mode)
			if newButton != rightBarButtonItem {
				rightBarButtonItem = newButton
			}
		}
	}
}
