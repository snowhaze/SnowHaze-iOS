//
//  PopularSitesSuggestionSource.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let maxCount = 3

class PopularSitesSuggestionSource: SuggestionSource {
	let includesPrivate: Bool
	private(set) weak var tab: Tab?
	private var popularSites: DomainList {
		return DomainList(type: includesPrivate ? .popularSites : .nonPrivatePopularSites)
	}

	init(includePrivate: Bool, tab: Tab) {
		includesPrivate = includePrivate
		self.tab = tab
	}

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			guard let tab = self.tab else {
				return callback([], "popular_sites")
			}
			let sites = self.popularSites.search(top: Int64(maxCount), matching: base)
			let data = syncToMainThread {
				return sites.map { (index, site) -> (Int64, Bool, String) in
					let preliminaryURL = URL(string: "https://" + site)!
					let policy = PolicyManager.manager(for: preliminaryURL, in: tab)
					let httpsSites = DomainList(type: policy.useHTTPSExclusivelyWhenPossible ? .httpsSites: .empty)
					let upgrade = httpsSites.contains(site) || policy.trustedSiteUpdateRequired
					return (index, upgrade, site)
				}
			}
			let suggestions = data.map { (index, upgrade, site) -> Suggestion in
				let title: String
				if site.hasPrefix("www.") {
					title = String(site[site.index(site.startIndex, offsetBy: 4)...])
				} else {
					title = site
				}
				let urlString = (upgrade ? "https://" : "http://") + site
				let url = URL(string:  urlString)!
				let image = #imageLiteral(resourceName: "popular_sites")
				let priority = 5000 / (Double(index) + 100) * Double(1 + base.count) * Double(1 + base.count)
				let suggestion =  Suggestion(title: title, subtitle: urlString, url: url, image: image, priority: priority)
				let tab = self.tab
				suggestion.selectionCallback = { [weak tab] in
					if upgrade, let tab = tab {
						Stats.shared.upgradedLoad(of: url, in: tab)
					}
				}
				return suggestion
			}
			DispatchQueue.main.sync {
				callback(suggestions, "popular_sites")
			}
		}
	}
}
