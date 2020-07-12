//
//  FixedNavigationController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class FixedNavigationController: UINavigationController {
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		// work around iOS issues
		if let presented = presentedViewController ?? topViewController?.presentedViewController {
			return presented.supportedInterfaceOrientations
		} else if let mask = delegate?.navigationControllerSupportedInterfaceOrientations?(self) {
			return mask
		} else if UIDevice.current.userInterfaceIdiom == .pad {
			return .all
		} else {
			return .portrait
		}
	}
}
