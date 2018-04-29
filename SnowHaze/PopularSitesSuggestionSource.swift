//
//  PopularSitesSuggestionSource.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let maxCount = 3

class PopularSitesSuggestionSource: SuggestionSource {
	let includesPrivate: Bool
	let upgradeHTTP: Bool
	private var popularSites: DomainList {
		return DomainList(type: includesPrivate ? .popularSites : .nonPrivatePopularSites)
	}

	init(includePrivate: Bool, upgrade: Bool) {
		includesPrivate = includePrivate
		upgradeHTTP = upgrade
	}

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> Void) {
		DispatchQueue.global(qos: .userInitiated).async {
			let sites = self.popularSites.search(top: Int64(maxCount), matching: base)
			let httpsSites = DomainList(type: self.upgradeHTTP ? .httpsSites : .empty)
			let suggestions = sites.map { (index, site) -> Suggestion in
				let title: String
				if site.hasPrefix("www.") {
					title = String(site[site.index(site.startIndex, offsetBy: 4)...])
				} else {
					title = site
				}
				let upgrage = httpsSites.contains(site)
				let urlString = (upgrage ? "https://" : "http://") + site
				let url = URL(string:  urlString)!
				let image = #imageLiteral(resourceName: "popular_sites")
				let priority = 5000 / (Double(index) + 100) * Double(1 + base.count) * Double(1 + base.count)
				return Suggestion(title: title, subtitle: urlString, url: url, image: image, priority: priority)
			}
			DispatchQueue.main.sync {
				callback(suggestions, "popular_sites")
			}
		}
	}
}
