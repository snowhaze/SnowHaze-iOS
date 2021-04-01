//
//  BookmarkSuggestionSource.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let maxCount = 3

class BookmarkSuggestionSource: SuggestionSource {
	private let bookmarkStore = BookmarkStore.store

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> ()) {
		let bookmarks = bookmarkStore.bookmarks(forSearch: base, limit: UInt(maxCount))
		let suggestions = bookmarks.map { (bookmark) -> Suggestion in
			let name = bookmark.bookmark.displayName
			let urlString = bookmark.bookmark.URL.absoluteString
			let url = bookmark.bookmark.URL
			let priority = -4 * bookmark.bookmark.weight / bookmark.rank
			let icon = bookmark.bookmark.displayIcon
			let suggestion = Suggestion(title: name, subtitle: urlString, url: url, image: icon, priority: priority)
			suggestion.selectionCallback = bookmark.bookmark.wasSelected
			return suggestion
		}
		callback(suggestions, "bookmark")
	}
}
