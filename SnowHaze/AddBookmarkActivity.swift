//
//  AddBookmarkActivity.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class AddBookmarkActivity: UIActivity {
	private var tab: Tab?

	override var activityType : UIActivityType? {
		return UIActivityType("Add Bookmark Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("add bookmark activity title", comment: "title of the activity to create a new bookmark")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "add_bookmark")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		self.tab = nil
		for object in activityItems {
			if let tab = object as? Tab, let _ = tab.controller?.url {
				self.tab = tab
			}
		}
		return self.tab != nil
	}

	override class var activityCategory : UIActivityCategory {
		return .action
	}

	override func perform() {
		guard let tab = tab else {
			return
		}
		BookmarkStore.store.addItem(forTab: tab)
		activityDidFinish(true)
	}
}
