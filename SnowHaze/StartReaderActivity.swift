//
//  StartReaderActivity.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class StartReaderActivity: UIActivity {
	private let callback: (StartReaderActivity) -> Void

	private(set) var tab: Tab!

	init(callback: @escaping (StartReaderActivity) -> Void) {
		self.callback = callback
	}

	override var activityType : UIActivity.ActivityType? {
		return UIActivity.ActivityType("Start Reader Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("reader mode activity title", comment: "title of the activity to enter reader mode")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "reader")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		for object in activityItems {
			if let tab = object as? Tab, let url = tab.displayURL {
				if !PolicyManager.manager(for: url, in: tab).isInReaderMode {
					self.tab = tab
					return true
				}
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
