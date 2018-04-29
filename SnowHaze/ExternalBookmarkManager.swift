//
//  ExternalBookmarkManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CoreSpotlight

let bookmarkSearchDomainID = "ch.illotros.snowhaze.core-spotlight.domain.bookmark"
let bookmarkUTID = "ch.illotros.snowhaze.bookmark"
let bookmarkApplicationShortcutType = "ch.illotros.snowhaze.application-shortcut.type.bookmark"
let newTabApplicationShortcutType = "ch.illotros.snowhaze.application-shortcut.type.new-tab" // Is also used in info.plist

class ExternalBookmarkManager: NSObject {
	init(store: BookmarkStore) {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(bookmarksChanged(_:)), name: BOOKMARK_LIST_CHANGED_NOTIFICATION, object: store)
		NotificationCenter.default.addObserver(self, selector: #selector(bookmarksChanged(_:)), name: BOOKMARK_CHANGED_NOTIFICATION, object: store)
	}

	private func searchableItem(for bookmark: Bookmark) -> CSSearchableItem {
		let attributes = CSSearchableItemAttributeSet(itemContentType: bookmarkUTID)
		attributes.displayName = bookmark.displayName
		attributes.title = bookmark.title
		attributes.path = bookmark.URL.absoluteString
		let icon = bookmark.displayIcon
		attributes.thumbnailData = UIImagePNGRepresentation(icon)
		let id = "bookmark-\(bookmark.id)-\(bookmark.URL.absoluteString)"
		return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: bookmarkSearchDomainID, attributeSet: attributes)
	}

	private func updateSpotlight(_ store: BookmarkStore) {
		let searchIndex = CSSearchableIndex.default()
		searchIndex.deleteSearchableItems(withDomainIdentifiers: [bookmarkSearchDomainID], completionHandler: { _ in
			DispatchQueue.main.async {
				guard PolicyManager.globalManager().indexBookmarks else {
					return
				}
				let bookmarks = store.items
				let searchableItems = bookmarks.map { self.searchableItem(for: $0) }
				CSSearchableIndex.default().indexSearchableItems(searchableItems, completionHandler: nil)
			}
		})
	}

	@objc private func bookmarksChanged(_ notification: Notification) {
		let store = notification.object as! BookmarkStore
		let policy = PolicyManager.globalManager()
		UIApplication.shared.shortcutItems = policy.applicationShortcutItems
		updateSpotlight(store)
	}
}
