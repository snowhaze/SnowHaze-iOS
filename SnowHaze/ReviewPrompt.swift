//
//  ReviewPrompt.swift
//  SnowHaze
//
//
//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation
import StoreKit

class ReviewPrompt {
	private static var prompted = false
	private static var closedTabs = 0

	static func settingsReset() {
		prompt()
	}

	static func allTabsClosed() {
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
		if #available(iOS 14, *) {
			guard let scene = MainViewController.controller?.viewIfLoaded?.window?.windowScene else {
				return
			}
			SKStoreReviewController.requestReview(in: scene)
		} else {
			SKStoreReviewController.requestReview()
		}
		prompted = true
	}
}
