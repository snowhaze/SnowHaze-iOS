//
//  LoadBar.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

class LoadBar: UIView {
	var progress: CGFloat = 0.0
	var fillColor = UIColor.button
	var missingColor = UIColor.clear {
		didSet {
			backgroundColor = missingColor
		}
	}

	private func setup() {
		backgroundColor = .clear
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	override func draw(_ rect: CGRect) {
		if progress <= 0 || progress >= 1 {
			return
		}
		let context = UIGraphicsGetCurrentContext()
		var red: CGFloat = 0.0
		var green: CGFloat = 0.0
		var blue: CGFloat = 0.0
		var alpha: CGFloat = 0.0
		fillColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
		context!.setFillColor(red: red, green: green, blue: blue, alpha: alpha)
		let y = bounds.minY
		let height = bounds.height

		let x = bounds.minX
		let width = (bounds.maxX - x) * progress

		let rect = CGRect(x: x, y: y, width: width, height: height)

		context!.fill(rect)
	}
}
