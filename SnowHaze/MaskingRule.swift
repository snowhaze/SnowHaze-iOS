//
//  MaskingRule.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum TabMaskingRule: Int64 {
	case never			= 0
	case whenPrivate	= 1
	case always			= 2

	func shouldMask(isPrivate: Bool) -> Bool {
		switch self {
			case .never:		return false
			case .whenPrivate:	return isPrivate
			case .always:		return true
		}
	}

	var name: String {
		switch self {
			case .never:		return NSLocalizedString("never tab masking rule name", comment: "name of the never tab masking rule")
			case .whenPrivate:	return NSLocalizedString("when private tab masking rule name", comment: "name of the when private tab masking rule")
			case .always:		return NSLocalizedString("always tab masking rule name", comment: "name of the always tab masking rule")
		}
	}
}
