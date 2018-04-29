//
//  ExternalBookmarksSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CoreSpotlight

class ExternalBookmarksSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("external bookmark settings explanation", comment: "explanations of the external bookmark settings")

	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.externalBookmarks]).color
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let uiSwitch = makeSwitch()
		if indexPath.row == 0 {
			cell.textLabel?.text = NSLocalizedString("index bookmarks in spotlight setting title", comment: "title of setting to index bookmarks in spotlight");
			uiSwitch.addTarget(self, action: #selector(indexInSpotlightToggled(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: indexBookmarksInSpotlightKey)
		} else {
			cell.textLabel?.text = NSLocalizedString("bookmark application shortcuts setting title", comment: "title of setting to add application shortcuts for bookmarks");
			uiSwitch.addTarget(self, action: #selector(homeScreenShortcuts(_:)), for: .valueChanged)
			uiSwitch.isOn = bool(for: addBookmarkApplicationShortcutsKey)
		}
		cell.accessoryView = uiSwitch
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return 2
	}

	private func indexBookmarks() {
		let bookmarks = BookmarkStore.store.items
		let searchableItems = bookmarks.map { bookmark -> CSSearchableItem in
			let attributes = CSSearchableItemAttributeSet(itemContentType: bookmarkUTID)
			attributes.displayName = bookmark.displayName
			attributes.title = bookmark.title
			attributes.path = bookmark.URL.absoluteString
			let icon = bookmark.displayIcon
			attributes.thumbnailData = UIImagePNGRepresentation(icon)
			let id = "bookmark-\(bookmark.id)-\(bookmark.URL.absoluteString)"
			return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: bookmarkSearchDomainID, attributeSet: attributes)
		}
		CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: nil)
	}

	private func unindexBookmarks() {
		CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [bookmarkSearchDomainID], completionHandler: nil)
	}

	@objc private func indexInSpotlightToggled(_ sender: UISwitch) {
		set(sender.isOn, for: indexBookmarksInSpotlightKey)
		if sender.isOn {
			indexBookmarks()
		} else {
			unindexBookmarks()
		}
		updateHeaderColor(animated: true)
	}

	@objc private func homeScreenShortcuts(_ sender: UISwitch) {
		set(sender.isOn, for: addBookmarkApplicationShortcutsKey)
		let policy = PolicyManager.globalManager()
		UIApplication.shared.shortcutItems = policy.applicationShortcutItems
		updateHeaderColor(animated: true)
	}
}
