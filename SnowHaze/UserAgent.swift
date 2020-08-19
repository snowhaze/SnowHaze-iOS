//
//	UserAgent.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

enum UserAgentType: Int {
	case safariiPhone
	case chromeiPhone
	case firefoxiPhone
	case operaiPhone

	case safariiPad
	case chromeiPad
	case firefoxiPad
	case operaiPad

	case defaultAndroid
	case chromeAndroid
	case firefoxAndroid
	case operaAndroid

	case safariMac
	case chromeWindows
	case firefoxLinux

	var isDesktop: Bool {
		switch self {
			case .safariiPhone, .chromeiPhone, .firefoxiPhone, .operaiPhone,
				 .safariiPad, .chromeiPad, .firefoxiPad, .operaiPad,
				 .defaultAndroid, .chromeAndroid, .firefoxAndroid, .operaAndroid:
				return false
			case .safariMac, .chromeWindows, .firefoxLinux:
				return true
		}
	}
}

class UserAgent {
	let type: UserAgentType

	init(type: UserAgentType) {
		self.type = type
	}

	static let mobileAgents = [
		UserAgentType.safariiPhone, .chromeiPhone, .firefoxiPhone, .operaiPhone,
		.safariiPad, .chromeiPad, .firefoxiPad, .operaiPad,
		.defaultAndroid, .chromeAndroid, .firefoxAndroid, .operaAndroid
	]

	static let desktopAgents = [UserAgentType.safariMac, .chromeWindows, .firefoxLinux]

	static var defaultUserAgentTypes: [UserAgentType] {
		if UIDevice.current.userInterfaceIdiom == .pad {
			return [.safariiPad, .chromeiPad, .firefoxiPad, .operaiPad]
		} else {
			return [.safariiPhone, .chromeiPhone, .firefoxiPhone, .operaiPhone]
		}
	}

	static func encode(_ types: [UserAgentType]) -> String {
		let numbers = types.map { NSNumber(value: $0.rawValue as Int) }
		let data = try! JSONSerialization.data(withJSONObject: numbers)
		return String(data: data, encoding: .utf8)!
	}

	static func decode(_ string: String) -> [UserAgentType] {
		let data = string.data(using: String.Encoding.utf8)!
		let numbers = try! JSONSerialization.jsonObject(with: data) as! [NSNumber]
		return numbers.map { UserAgentType(rawValue: $0.intValue)! }
	}

	static func remove(_ type: UserAgentType, from: [UserAgentType]) -> [UserAgentType] {
		guard let index = from.firstIndex(of: type) else {
			return from
		}
		var mutableFrom = from
		mutableFrom.remove(at: index)
		return mutableFrom
	}

	static func add(_ type: UserAgentType, to: [UserAgentType]) -> [UserAgentType] {
		guard !to.contains(type) else {
			return to
		}
		var mutableTo = to
		mutableTo.append(type)
		return mutableTo
	}

	var string: String {
		switch type {
			case .safariiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 13_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Mobile/15E148 Safari/604.1"
			case .chromeiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 13_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/84.0.4147.122 Mobile/15E148 Safari/604.1"
			case .firefoxiPhone:	return "Mozilla/5.0 (iPhone; CPU OS 13_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/28.0 Mobile/15E148 Safari/605.1.15"
			case .operaiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 13_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPT/2.4.4 Mobile/15E148"

			case .safariiPad:		return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Safari/605.1.15"
			case .chromeiPad:		return "Mozilla/5.0 (iPad; CPU OS 13_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/84.0.4147.122 Mobile/15E148 Safari/604.1"
			case .firefoxiPad:		return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1 Safari/605.1.15"
			case .operaiPad:		return "Mozilla/5.0 (iPad; CPU OS 13_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPT/2.4.4 Mobile/15E148"

			case .defaultAndroid:	return "Mozilla/5.0 (Linux; Android 8.0.0; SAMSUNG SM-G935F/G935FXXS7ETA8) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/12.1 Chrome/79.0.3945.136 Mobile Safari/537.36"
			case .chromeAndroid:	return "Mozilla/5.0 (Linux; Android 8.0.0; SM-G935F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Mobile Safari/537.36"
			case .firefoxAndroid:	return "Mozilla/5.0 (Android 8.0.0; Mobile; rv:79.0) Gecko/79.0 Firefox/79.0"
			case .operaAndroid:		return "Mozilla/5.0 (Linux; Android 8.0.0; SM-G935F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36 OPR/59.1.2926.54067"

			case .safariMac:		return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Safari/605.1.15"
			case .chromeWindows:	return "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.135 Safari/537.36"
			case .firefoxLinux:		return "Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0"
		}
	}

	var displayName: String {
		switch type {
			case .safariiPhone:		return NSLocalizedString("iphone safari user agent display name", comment: "string displayed to user to identify iphone safari user agent")
			case .chromeiPhone:		return NSLocalizedString("iphone chrome user agent display name", comment: "string displayed to user to identify iphone chrome user agent")
			case .firefoxiPhone:	return NSLocalizedString("iphone firefox user agent display name", comment: "string displayed to user to identify iphone firefox user agent")
			case .operaiPhone:		return NSLocalizedString("iphone opera user agent display name", comment: "string displayed to user to identify iphone opera user agent")

			case .safariiPad:		return NSLocalizedString("ipad safari user agent display name", comment: "string displayed to user to identify ipad safari user agent")
			case .chromeiPad:		return NSLocalizedString("ipad chrome user agent display name", comment: "string displayed to user to identify ipad chrome user agent")
			case .firefoxiPad:		return NSLocalizedString("ipad firefox user agent display name", comment: "string displayed to user to identify ipad firefox user agent")
			case .operaiPad:		return NSLocalizedString("ipad opera user agent display name", comment: "string displayed to user to identify ipad opera user agent")

			case .defaultAndroid:	return NSLocalizedString("android default browser user agent display name", comment: "string displayed to user to identify android default browser user agent")
			case .chromeAndroid:	return NSLocalizedString("android chrome user agent display name", comment: "string displayed to user to identify android chrome user agent")
			case .firefoxAndroid:	return NSLocalizedString("android firefox user agent display name", comment: "string displayed to user to identify android firefox user agent")
			case .operaAndroid:		return NSLocalizedString("android opera user agent display name", comment: "string displayed to user to identify android opera user agent")

			case .safariMac:		return NSLocalizedString("safari macos user agent display name", comment: "string displayed to user to identify macos safari user agent")
			case .chromeWindows:	return NSLocalizedString("chrome windows user agent display name", comment: "string displayed to user to identify windows chrome user agent")
			case .firefoxLinux:		return NSLocalizedString("firefox linux user agent display name", comment: "string displayed to user to identify linux firefox user agent")
		}
	}
}
