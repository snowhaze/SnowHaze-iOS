//
//  FixedNavigationController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class FixedNavigationController: UINavigationController {
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		if #available(iOS 11, *) {
			// fix weird iOS 11 issues
			if let mask = delegate?.navigationControllerSupportedInterfaceOrientations?(self) {
				return mask
			} else if UI_USER_INTERFACE_IDIOM() == .pad {
				return .all
			} else {
				return .portrait
			}
		} else {
			// already works on older OS versions
			return super.supportedInterfaceOrientations
		}
	}
}
