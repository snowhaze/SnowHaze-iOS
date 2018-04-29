//
//  CookieBlockingPolicy.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum CookieBlockingPolicy: Int64 {
	case none = 0
	case thirdParty = 1
	case all = 2

	@available(iOS 11, *)
	var contentBlocker: WKContentRuleList? {
		switch self {
			case .none:			return nil
			case .thirdParty:	return ContentBlockerManager.shared.blockers[BlockerID.thirdPartiesCookiesBlocker]!
			case .all:			return ContentBlockerManager.shared.blockers[BlockerID.allCookiesBlocker]!
		}
	}
}
