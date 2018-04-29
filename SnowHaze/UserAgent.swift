//
//	UserAgent.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

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
}

class UserAgent {
	let type: UserAgentType

	init(type: UserAgentType) {
		self.type = type
	}

	static var agentCount: Int {
		return 12
	}

	static var defaultUserAgentTypes: [UserAgentType] {
		if UI_USER_INTERFACE_IDIOM() == .pad {
			return [.safariiPad, .chromeiPad, .firefoxiPad]
		} else {
			return [.safariiPhone, .chromeiPhone, .firefoxiPhone]
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
		guard let index = from.index(of: type) else {
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
			case .safariiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1"
			case .chromeiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 11_3 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) CriOS/65.0.3325.152 Mobile/15E216 Safari/604.1"
			case .firefoxiPhone:	return "Mozilla/5.0 (iPhone; CPU iPhone OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/11.0b9935 Mobile/15E216 Safari/605.1.15"
			case .operaiPhone:		return "Mozilla/5.0 (iPhone; CPU iPhone OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPiOS/16.0.8.121059 Mobile/15E216 Safari/9537.53"

			case .safariiPad:		return "Mozilla/5.0 (iPad; CPU OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1"
			case .chromeiPad:		return "Mozilla/5.0 (iPad; CPU OS 11_3 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) CriOS/65.0.3325.152 Mobile/15E216 Safari/604.1"
			case .firefoxiPad:		return "Mozilla/5.0 (iPad; CPU OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/11.0b9935 Mobile/15E216 Safari/605.1.15"
			case .operaiPad:		return "Mozilla/5.0 (iPad; CPU OS 11_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPiOS/16.0.8.121059 Mobile/15E216 Safari/9537.53"

			case .defaultAndroid:	return "Mozilla/5.0 (Linux; Android 7.0; SAMSUNG SM-G935F/G935FXXU2DRB6 Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/6.4 Chrome/56.0.2924.87 Mobile Safari/537.36"
			case .chromeAndroid:	return "Mozilla/5.0 (Linux; Android 7.0; SM-G935F Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.109 Mobile Safari/537.36"
			case .firefoxAndroid:	return "Mozilla/5.0 (Android 7.0; Mobile; rv:59.0) Gecko/59.0 Firefox/59.0"
			case .operaAndroid:		return "Mozilla/5.0 (Linux; Android 7.0; SM-G935F Build/NRD90M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.141 Mobile Safari/537.36 OPR/45.1.2246.125351"
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
		}
	}
}
