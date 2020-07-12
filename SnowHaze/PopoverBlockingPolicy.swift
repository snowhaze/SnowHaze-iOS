//
//  PopoverBlockingPolicy.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

enum PopoverBlockingPolicyType: Int64 {
	case allwaysBlock
	case blockScripted
	case allwaysAllow
}

class PopoverBlockingPolicy {
	let type: PopoverBlockingPolicyType

	init(type: PopoverBlockingPolicyType) {
		self.type = type
	}

	var displayName: String {
		switch type {
			case .allwaysBlock:		return NSLocalizedString("allways block popover blocking policy name", comment: "name of popover blocking policy which blocks all popovers")
			case .blockScripted:	return NSLocalizedString("block scripted popover blocking policy name", comment: "name of popover blocking policy which only blocks js-triggered popovers")
			case .allwaysAllow:		return NSLocalizedString("allways allow popover blocking policy name", comment: "name of popover blocking policy which allows all popovers")
		}
	}

	var allowAutomaticJSPopovers: Bool {
		switch type {
			case .allwaysAllow:	return true
			default:			return false
		}
	}

	func allow(for navigationType: WKNavigationType) -> Bool {
		switch type {
			case .allwaysBlock:	return false
			default:			return true
		}
	}
}
