//
//  HomeSuggestionSource.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

class HomeSuggestionSource: SuggestionSource {
	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> ()) {
		if let url = PolicyManager.globalManager().homepageURL {
			let list = NSLocalizedString("home suggestion source search terms", comment: "a comma separated list of terms the user can search for to get the home page suggestion")
			let terms = list.components(separatedBy: ",")
			var score = 0.0
			for term in terms {
				if term.localizedLowercase.hasPrefix(base.localizedLowercase) {
					score = max(score, 30 + 25 * pow(Double(base.count), 1.7))
				}
			}
			if score > 0 {
				let title = NSLocalizedString("home suggestion title", comment: "title of the home page suggestion")
				let icon = #imageLiteral(resourceName: "home")
				let suggestion = Suggestion(title: title, subtitle: url.absoluteString, url: url, image: icon, priority: score)
				callback([suggestion], "home")
			}
		}
	}
}
