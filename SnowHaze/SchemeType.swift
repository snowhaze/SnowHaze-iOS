//
//  SchemeType.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum SchemeType {
	private static let calleeRx = Regex(pattern: "^(?:[a-z-]+):(?://)?(.*)$", options: .caseInsensitive)

	case unknown
	case http
	case call(String?)
	case store
	case itunes
	case mail
	case sms
	case maps
	case whatsapp
	case intent(URL?)
	case workflow

	init(_ url: URL?) {
		guard let target = url, let scheme = target.scheme?.lowercased() else {
			self = .unknown
			return
		}
		let urlString = target.absoluteString
		switch scheme {
			case nil:
				self = .unknown
			case "http", "https":
				if let host = target.host?.lowercased() {
					if host == "itunes.apple.com" {
						self = .itunes
						return
					}
					if host == "maps.apple.com" && target.query != nil {
						self = .maps
						return
					}
				}
				self = .http
			case "tel", "facetime", "facetime-audio":
				if let match = SchemeType.calleeRx.firstMatch(in: urlString) {
					self = .call(String(match.match(at: 1)))
				} else {
					self = .call(nil)
				}
			case "itms-appss", "itms-apps":
				self = .store
			case "itmss":
				self = .itunes
			case "mailto":
				self = .mail
			case "sms":
				self = .sms
			case "whatsapp":
				self = .whatsapp
			case "workflow":
				self = .workflow
			case "intent":
				let components = url!.absoluteString.components(separatedBy: ";").filter { $0.hasPrefix("S.browser_fallback_url=") }
				let args = components.first?.components(separatedBy: "=").dropFirst()
				let arg = args?.joined(separator: "=")
				if let arg = arg?.removingPercentEncoding, let fallback = URL(string: arg) {
					self = .intent(fallback)
				} else {
					self = .intent(nil)
				}
			default:
				self = .unknown
		}
	}

	var appName: String? {
		switch self {
			case .store:	return NSLocalizedString("open url in app app store app name", comment: "name of the app store app used to confirm opening of url in other app")
			case .itunes:	return NSLocalizedString("open url in app itunes app name", comment: "name of the itunes app used to confirm opening of url in other app")
			case .mail:		return NSLocalizedString("open url in app mail app name", comment: "name of the mail app used to confirm opening of url in other app")
			case .sms:		return NSLocalizedString("open url in app messages app name", comment: "name of the messages app used to confirm opening of url in other app")
			case .maps:		return NSLocalizedString("open url in app maps app name", comment: "name of the maps app used to confirm opening of url in other app")
			case .whatsapp:	return NSLocalizedString("open url in app whatsapp app name", comment: "name of the whatsapp app used to confirm opening of url in other app")
			case .workflow: return NSLocalizedString("open url in app workflow app name", comment: "name of the workflow app used to confirm opening of url in other app")
			default:		return nil
		}
	}

	var needsCheck: Bool {
		switch self {
			case .whatsapp:	return true
			default:		return false
		}
	}
}
