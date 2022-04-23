//
//  DownloadProgressIndicator.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private class ProgressDrawer: UIView {
	var progress = 0.0 {
		didSet {
			setNeedsDisplay()
		}
	}

	override func draw(_ rect: CGRect) {
		UIColor.button.setStroke()
		let path1 = UIBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
		path1.stroke()
		guard progress >= 0 && progress <= 1 else {
			return
		}
		let path2 = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY), radius: bounds.height / 2 - 3, startAngle: CGFloat(0 - Double.pi / 2), endAngle: CGFloat((progress * 2 - 0.5) * Double.pi), clockwise: true)
		path2.lineWidth = 3
		path2.stroke()
	}
}

@objc protocol DownloadProgressIndicatorDelegate: AnyObject {
	func downloadProgressIndicatorTapped(_ indicator: DownloadProgressIndicator)
}

class DownloadProgressIndicator: UIView {
	private let drawer = ProgressDrawer()

	@IBOutlet weak var delegate: DownloadProgressIndicatorDelegate?

	var progress = 0.0 {
		didSet {
			isHidden = !(progress >= 0 && progress <= 1)
			drawer.progress = progress
		}
	}

	init() {
		super.init(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setup()
	}

	private func setup() {
		isHidden = true
		bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
		clipsToBounds = true
		isOpaque = true
		layer.borderColor = UIColor.bar.cgColor
		layer.borderWidth = 1
		layer.cornerRadius = 8
		drawer.frame = CGRect(x: 5, y: 5, width: 20, height: 20)
		drawer.backgroundColor = .clear
		addSubview(drawer)
		let gesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
		addGestureRecognizer(gesture)
	}

	@objc private func tapped(_ sender: UIGestureRecognizer) {
		if case .recognized = sender.state {
			delegate?.downloadProgressIndicatorTapped(self)
		}
	}
}
