//
//  FindOnPageActivity.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class FindOnPageActivity: UIActivity {
	private let callback: (FindOnPageActivity) -> Void

	private(set) var tab: Tab!

	init(callback: @escaping (FindOnPageActivity) -> Void) {
		self.callback = callback
	}

	override var activityType : UIActivity.ActivityType? {
		return UIActivity.ActivityType("Find on Page Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("find on page activity title", comment: "title of the activity to find some text on page")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "find_on_page")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		var webView: WKWebView? = nil
		var tab: Tab? = nil
		for object in activityItems {
			webView = object as? WKWebView ?? webView
			tab = object as? Tab ?? tab
			if let tab = tab, let _ = webView {
				self.tab = tab
				return true
			}
		}
		return false
	}

	override class var activityCategory : UIActivity.Category {
		return .action
	}

	override func perform() {
		callback(self)
	}
}
