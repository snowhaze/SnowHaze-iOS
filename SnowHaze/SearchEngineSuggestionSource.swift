//
//  SearchEngineSuggestionSource.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private enum SearchEngineSuggestionError: Error {
	case contentError
}

private let maxCount = 3

class SearchEngineSuggestionSource: SuggestionSource {
	var engine: SearchEngine
	var tab: Tab

	private var snowhazeSearchID = 0

	init(engine: SearchEngine, tab: Tab) {
		self.engine = engine
		self.tab = tab
	}

	init(tab: Tab) {
		engine = SearchEngine(type: .none)
		self.tab = tab
	}

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> Void) {
		DispatchQueue.main.async { () -> Void in
			let callback: ([Suggestion], String) -> Void = { suggestions, id in
				DispatchQueue.main.async { () -> Void in
					callback(suggestions, "search_engine." + id)
				}
			}
			switch self.engine.type {
				case .bing:			self.bingSuggestion(for: base, callback: callback)
				case .google:		self.googleSuggestion(for: base, callback: callback)
				case .yahoo:		self.yahooSuggestion(for: base, callback: callback)
				case .wikipedia:	self.wikipediaSuggestion(for: base, callback: callback)
				case .wolframAlpha:	self.wolframAlphaSuggestion(for: base, callback: callback)
				case .ecosia:		self.ecosiaSuggestion(for: base, callback: callback)
				case .startpage:	self.startpageSuggestion(for: base, callback: callback)
				case .hulbee:		self.hulbeeSuggestion(for: base, callback: callback)
				case .duckDuckGo:	self.duckDuckGoSuggestion(for: base, callback: callback)
				case .snowhaze:		self.snowhazeSuggestion(for: base, callback: callback)
				case .none:			return
			}
		}
	}

	func priority(for index: Int) -> Double {
		return 55 - 5 * Double(index)
	}

	func bingSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		guard let queryString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else {
			return
		}
		guard let url = URL(string: "https://api.bing.com/osjson.aspx?query=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [AnyObject] else {
				return
			}
			guard let array = result.last as? [String] else {
				return
			}
			let phrases = array.prefix(maxCount)
			var suggestions = [Suggestion]()
			for (index, title) in phrases.enumerated() {
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("bing search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from bing")
				let image = #imageLiteral(resourceName: "bing")
				let count = index + 1
				let suggestion = Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: count))
				suggestions.append(suggestion)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "bing")
			}
		}
	}

	func googleSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		guard let url = URL(string: "https://suggestqueries.google.com/complete/search?output=firefox&q=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [AnyObject] else {
				return
			}
			guard let array = result.last as? [String] else {
				return
			}
			let phrases = array.prefix(maxCount)
			var suggestions = [Suggestion]()
			for (index, title) in phrases.enumerated() {
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("google search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from google")
				let image = #imageLiteral(resourceName: "google")
				let count = index + 1
				let suggestion = Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: count))
				suggestions.append(suggestion)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "google")
			}
		}
	}

	func yahooSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		guard let url = URL(string: "https://sugg.search.yahoo.net/sg/?output=json&nresults=\(maxCount)&command=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [String: AnyObject] else {
				return
			}
			guard let array = result["gossip"] as? [String: AnyObject] else {
				return
			}
			guard let results = array["results"] as? [AnyObject] else {
				return
			}
			var suggestions = [Suggestion]()
			for (index, entry) in results.enumerated() {
				guard let res = entry as? [String: AnyObject] else {
					return
				}
				guard let title = res["key"] as? String else {
					return
				}
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("yahoo search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from yahoo")
				let image = #imageLiteral(resourceName: "yahoo")
				let count = index + 1
				let suggestion = Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: count))
				suggestions.append(suggestion)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "yahoo")
			}
		}
	}

	func wikipediaSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		let wikipediaDomain = NSLocalizedString("localized wikipedia domain", comment: "domain for wikipedia in the language used by the user")
		guard let url = URL(string: "https://\(wikipediaDomain)/w/api.php?action=opensearch&limit=\(maxCount)&search=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [AnyObject] , result.count == 4 else {
				return
			}
			guard let phrases = result[1] as? [String] else {
				return
			}
			guard let urls = result.last as? [String] else {
				return
			}
			guard urls.count >= phrases.count else {
				return
			}
			var suggestions = [Suggestion]()
			for (index, title) in phrases.enumerated() {
				guard let url = URL(string: urls[index]) else {
					return
				}
				let subtitle = NSLocalizedString("wikipedia search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from wikipedia")
				let image = #imageLiteral(resourceName: "wikipedia")
				let count = index + 1
				let suggestion = Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: count))
				suggestions.append(suggestion)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "wikipedia")
			}
		}
	}

	func wolframAlphaSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		guard let url = URL(string: "https://www.wolframalpha.com/input/autocomplete.jsp?i=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [String: AnyObject] else {
				return
			}
			guard let results = result["results"] as? [[String: AnyObject]] else {
				return
			}
			let array = results.prefix(maxCount)
			let suggestions = array.compactMap { sug -> Suggestion? in
				guard let title = sug["input"] as? String else {
					return nil
				}
				guard let url = self.engine.url(for: title) else {
					return nil
				}
				let subtitle = NSLocalizedString("wolframalpha search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from wolframalpha")
				let image = #imageLiteral(resourceName: "wolframalpha")
				let description = sug["description"] as? String ?? subtitle
				let freq = sug["absoluteFrequency"] as? Double ?? 0
				return Suggestion(title: title, subtitle: description, url: url, image: image, priority: pow(freq, 1 / 3) * 1000)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "wolfram_alpha")
			}
		}
	}

	func ecosiaSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		guard let url = URL(string: "https://ac.ecosia.org/autocomplete?q=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [String: AnyObject] else {
				return
			}
			guard let results = result["suggestions"] as? [String] else {
				return
			}
			let array = results.prefix(maxCount)
			var suggestions = [Suggestion]()
			suggestions.reserveCapacity(array.count)
			for (index, title) in array.enumerated() {
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("ecosia search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from ecosia")
				let image = #imageLiteral(resourceName: "ecosia")
				suggestions.append(Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: index + 1)))
			}
			if !suggestions.isEmpty {
				callback(suggestions, "ecosia")
			}
		}
	}

	func startpageSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		let language = NSLocalizedString("localized startpage language", comment: "language for startpage in the language used by the user")
		guard let url = URL(string: "https://www.startpage.com/do/suggest?limit=\(maxCount)&lang=\(language)&format=json&query=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [AnyObject], result.count == 2 else {
				return
			}
			guard let results = result[1] as? [String] else {
				return
			}
			var suggestions = [Suggestion]()
			suggestions.reserveCapacity(results.count)
			for (index, title) in results.enumerated() {
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("startpage search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from startpage")
				let image = #imageLiteral(resourceName: "startpage")
				suggestions.append(Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: index + 1)))
			}
			if !suggestions.isEmpty {
				callback(suggestions, "startpage")
			}
		}
	}

	func hulbeeSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		let convertedString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
		guard let queryString = convertedString, !queryString.isEmpty else {
			return
		}
		guard let url = URL(string: "https://suggest.hulbee.com/suggest?count=\(maxCount)&culture=browser&bucket=Web&query=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let result = json as? [String] else {
				return
			}
			var suggestions = [Suggestion]()
			suggestions.reserveCapacity(result.count)
			for (index, title) in result.enumerated() {
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("hulbee search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from hulbee")
				let image = #imageLiteral(resourceName: "hulbee")
				suggestions.append(Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: self.priority(for: index + 1)))
			}
			if !suggestions.isEmpty {
				callback(suggestions, "hulbee")
			}
		}
	}

	func duckDuckGoSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		guard let queryString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else {
			return
		}
		guard let url = URL(string: "https://ac.duckduckgo.com/ac/?q=" + queryString) else {
			return
		}
		JSONFetcher(tab: tab).fetchJSON(from: url) { (json) -> Void in
			guard let array = json as? [[String: String]] else {
				return
			}
			let phrases = array.prefix(maxCount)
			var suggestions = [Suggestion]()
			for (index, phrase) in phrases.enumerated() {
				guard let title = phrase["phrase"] else {
					return
				}
				guard let url = self.engine.url(for: title) else {
					return
				}
				let subtitle = NSLocalizedString("duckduckgo search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from duckduckgo")
				let image = #imageLiteral(resourceName: "duckduckgo")
				let priority = self.priority(for: index + 1)
				let suggestion = Suggestion(title: title, subtitle: subtitle, url: url, image: image, priority: priority)
				suggestions.append(suggestion)
			}
			if !suggestions.isEmpty {
				callback(suggestions, "duckduckgo")
			}
		}
	}

	func snowhazeSuggestion(for search: String, callback: @escaping ([Suggestion], String) -> Void) {
		guard let queryString = search.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) else {
			return
		}
		let manager = SubscriptionManager.shared
		guard manager.hasSubscription, manager.hasValidToken, let originalToken = manager.authorizationToken else {
			if PolicyManager.globalManager().autoUpdateAuthToken {
				SubscriptionManager.shared.updateAuthToken { success in
					if success {
						self.snowhazeSuggestion(for: search, callback: callback)
					}
				}
			}
			return
		}
		let token = originalToken.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)!
		let lang = NSLocalizedString("localization code", comment: "code used to identify the current locale")
		guard let url = URL(string: "https://search.snowhaze.com/suggestion.php?v=1&l=\(lang)&t=\(token)&q=\(queryString)") else {
			return
		}
		let id = snowhazeSearchID + 1
		snowhazeSearchID = id
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) { [weak self] in
			guard let me = self, me.snowhazeSearchID == id else {
				return
			}
			JSONFetcher(tab: me.tab).fetchJSON(from: url) { (json) -> Void in
				guard let me = self, let array = json as? [String] else {
					return
				}
				let phrases = array.prefix(maxCount)
				var suggestions = [Suggestion]()
				for (index, phrase) in phrases.enumerated() {
					guard let url = me.engine.url(for: phrase) else {
						return
					}
					let subtitle = NSLocalizedString("snowhaze search search suggestion subtitle", comment: "subtitle for autocomplete search suggestions from snowhaze search")
					let image = #imageLiteral(resourceName: "snowflake")
					let priority = me.priority(for: index + 1)
					let suggestion = Suggestion(title: phrase, subtitle: subtitle, url: url, image: image, priority: priority)
					suggestions.append(suggestion)
				}
				if !suggestions.isEmpty {
					callback(suggestions, "snowhaze")
				}
			}
		}
	}

	func cancelSuggestions() {
		snowhazeSearchID += 1
	}
}
