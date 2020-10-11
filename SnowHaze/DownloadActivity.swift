//
//  DownloadActivity.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

class DownloadActivity: UIActivity {
	private var tab: Tab?
	let data: DownloadData

	init(data: DownloadData) {
		self.data = data
	}

	override var activityType : UIActivity.ActivityType? {
		return UIActivity.ActivityType("Download Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("download page activity title", comment: "title of the activity to download the current page")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "download_page")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		tab = nil
		for object in activityItems {
			if let tab = object as? Tab {
				self.tab = tab
			}
		}
		return tab?.controller != nil
	}

	override class var activityCategory : UIActivity.Category {
		return .action
	}

	override func perform() {
		guard let controller = tab?.controller else {
			return
		}
		controller.download(data)
		activityDidFinish(true)
	}
}
