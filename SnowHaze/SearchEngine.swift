//
//	SearchEngine.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum SearchEngineType: Int64 {
	case none
	case bing
	case google
	case yahoo
	case wikipedia
	case wolframAlpha
	case ecosia
	case startpage
	case swisscows
	case duckDuckGo
	case qwant			= 12
	case custom
	case mojeek
}

class SearchEngine {
	let type: SearchEngineType
	init(type: SearchEngineType) {
		self.type = type
	}

	static func add(suggestionEngine engine: SearchEngineType, to: [SearchEngineType]) -> [SearchEngineType] {
		var res = to
		if !res.contains(engine) {
			res.append(engine)
		}
		return res
	}

	static func remove(suggestionEngine engine: SearchEngineType, from: [SearchEngineType]) -> [SearchEngineType] {
		var res = from
		if let index = res.firstIndex(of: engine) {
			res.remove(at: index)
		}
		return res
	}

	static func updateSuggestionEngine(new newEngine: SearchEngineType, old oldEngine: SearchEngineType, inList: [SearchEngineType]) -> [SearchEngineType] {
		var res = inList
		if let index = res.firstIndex(of: oldEngine) {
			if res.contains(newEngine) {
				res.remove(at: index)
			} else {
				res[index] = newEngine
			}
		}
		return res
	}

	static func encode(_ list: [SearchEngineType]) -> String{
		let values = list.map { NSNumber(value: $0.rawValue as Int64) }
		let data = try! JSONSerialization.data(withJSONObject: values)
		return String(data: data, encoding: .utf8)!
	}

	static func decode(_ string: String) -> [SearchEngineType] {
		let data = string.data(using: .utf8)!
		let numbers = try! JSONSerialization.jsonObject(with: data) as! [NSNumber]
		return numbers.map { SearchEngineType(rawValue: $0.int64Value) ?? .none }
	}

	func url(for search: String, using policy: PolicyManager) -> URL? {
		let allowedChars = CharacterSet.urlQueryValueAllowed
		guard let escapedSearch = search.addingPercentEncoding(withAllowedCharacters: allowedChars) else {
			return nil
		}
		switch type {
			case .bing:			return URL(string: "https://www.bing.com/search?q=" + escapedSearch)
			case .google:		return URL(string: "https://www.google.com/search?q=" + escapedSearch)
			case .yahoo:		return URL(string: "https://search.yahoo.com/search?p=" + escapedSearch)
			case .wikipedia:	return URL(string: "https://\(NSLocalizedString("localized wikipedia domain", comment: "domain for wikipedia in the language used by the user"))/wiki/" + escapedSearch)
			case .wolframAlpha:	return URL(string: "https://m.wolframalpha.com/input/?i=" + escapedSearch)
			case .ecosia:		return URL(string: "https://www.ecosia.org/search?q=" + escapedSearch)
			case .startpage:	return URL(string: "https://www.startpage.com/do/dsearch?language=\(NSLocalizedString("localized startpage language", comment: "language for startpage in the language used by the user"))&query=" + escapedSearch)
			case .swisscows:	return URL(string: "https://swisscows.com/?query=" + escapedSearch)
			case .duckDuckGo:	return URL(string: "https://duckduckgo.com/?q=" + escapedSearch)
			case .qwant:		return URL(string: "https://www.qwant.com/?q=\(escapedSearch)")
			case .mojeek:		return URL(string: "https://www.mojeek.com/search?q=\(escapedSearch)")
			case .custom:		return syncToMainThread { policy.customSearchURL(for: search) }
			case .none:			return nil
		}
	}
}
