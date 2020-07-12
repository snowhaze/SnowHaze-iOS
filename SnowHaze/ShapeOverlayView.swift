//
//	ShapeOverlayView.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class ShapeOverlayView: UIView {
	var corners: [CGPoint]?

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .clear
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func draw(_ rect: CGRect) {
		guard let corners = corners , !corners.isEmpty else {
			return
		}
		let context = UIGraphicsGetCurrentContext()
		let point = corners[0]
		context!.move(to: CGPoint(x: point.x, y: point.y))
		for point in corners {
			context!.addLine(to: CGPoint(x: point.x, y: point.y))
		}
		context!.closePath()
		context!.setLineWidth(3)
		context!.setLineJoin(.round)
		context!.setFillColor(UIColor.button.withAlphaComponent(0.4).cgColor)
		context!.setStrokeColor(UIColor.button.cgColor)
		context!.drawPath(using: .fillStroke)
	}
}
