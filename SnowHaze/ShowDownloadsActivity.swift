//
//  ShowDownloadsActivity.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class ShowDownloadsActivity: UIActivity {
	override var activityType : UIActivity.ActivityType? {
		return UIActivity.ActivityType("Show Downloads Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("show downloads activity title", comment: "title of the activity to show downloads")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "view_downloads")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		return true
	}

	override class var activityCategory : UIActivity.Category {
		return .action
	}

	override func perform() {
		MainViewController.controller?.showDownloads()
		activityDidFinish(MainViewController.controller != nil)
	}
}
