//
//  SublayerResizingView.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class SublayerResizingView: UIView {
	var layersToResize = [CALayer]()

	override func layoutSubviews() {
		super.layoutSubviews()
		layersToResize.forEach { $0.frame = self.layer.bounds }
	}
}
