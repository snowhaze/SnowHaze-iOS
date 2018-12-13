//
//  ReviewPrompt.swift
//  SnowHaze
//

//  Copyright © 2018 Benjamin Andris Suter-Dörig. All rights reserved.
//

import Foundation
import StoreKit

class ReviewPrompt {
	private static var prompted = false
	private static var closedTabs = 0

	static func settingsReset() {
		prompt()
	}

	static func tabClosed() {
		closedTabs += 1
		if closedTabs >= 3 {
			prompt()
		}
	}

	static func tabCloseReset() {
		closedTabs = 0
	}

	private static func prompt() {
		guard !prompted else {
			return
		}
		if #available(iOS 10.3, *) {
			SKStoreReviewController.requestReview()
		}
		prompted = true
	}
}
