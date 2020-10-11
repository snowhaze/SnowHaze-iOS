//
//	DetailPopover.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

enum DetailPopoverArrowPosition {
	case top(offset: CGFloat)
	case bottom(offset: CGFloat)
}

private let borderWidth: CGFloat = 5
private let arrowLength: CGFloat = 10

class DetailPopover {
	fileprivate let containerView = UIView()

	private let contentView: UIView
	private let contentSize: CGSize
	private let arrowPosition: DetailPopoverArrowPosition
	private var isDisplayed = false
	private let arrowView: DetailPopoverArrowView
	private var dismissView: DetailPopoverDismissView? = nil
	private let arrowTipSource: (DetailPopover) -> CGPoint

	init(contentView: UIView, arrowPosition: DetailPopoverArrowPosition, arrowTip: @escaping (DetailPopover) -> CGPoint) {
		contentSize = contentView.bounds.size
		self.contentView = contentView
		contentView.frame.origin = CGPoint(x: borderWidth, y: borderWidth)
		self.arrowPosition = arrowPosition
		arrowView = DetailPopoverArrowView(arrowPosition: arrowPosition)
		self.arrowTipSource = arrowTip

		containerView.bounds = CGRect(origin: CGPoint.zero, size: CGSize(width: contentSize.width + 2 * borderWidth, height: contentSize.height + 2 * borderWidth))
	}

	func show(in view: UIView, animated: Bool, completion: @escaping (Bool) -> () = { _ in }) {
		guard !isDisplayed else {
			return
		}
		isDisplayed = true

		dismissView = DetailPopoverDismissView(view: view, popover: self)
		dismissView?.backgroundColor = .popoverDismiss

		containerView.backgroundColor = .popover
		containerView.clipsToBounds = true
		containerView.layer.cornerRadius = 2 * borderWidth

		contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

		containerView.addSubview(contentView)
		dismissView?.addSubview(arrowView)
		dismissView?.addSubview(containerView)

		layout()

		if animated {
			dismissView?.alpha = 0
			UIView.animate(withDuration: 0.2, animations: {
				self.dismissView?.alpha = 1
			}, completion: completion)
		} else {
			completion(false)
		}
	}

	fileprivate func layout() {
		guard isDisplayed else {
			return
		}
		let arrowTip = arrowTipSource(self)
		let dist: CGFloat
		switch arrowPosition {
			case .top(_):		dist = arrowTip.y
			case .bottom(_):	dist = dismissView!.bounds.height - arrowTip.y
		}
		let width = min(contentSize.width, dismissView!.bounds.width - 4 * borderWidth)
		let height = min(contentSize.height, dismissView!.bounds.height - 4 * borderWidth - dist - arrowLength)
		let size = CGSize(width: width + 2 * borderWidth, height: height + 2 * borderWidth)
		let origin: CGPoint
		switch arrowPosition {
			case .top(let offset):
				origin = CGPoint(x: arrowTip.x - offset, y: arrowTip.y + arrowLength)
				arrowView.frame.origin = CGPoint(x: arrowTip.x - arrowLength, y: arrowTip.y)
			case .bottom(let offset):
				origin = CGPoint(x: arrowTip.x - offset, y: arrowTip.y - arrowLength - contentView.frame.height - 2 * borderWidth)
				arrowView.frame.origin = CGPoint(x: arrowTip.x - arrowLength, y: arrowTip.y - arrowLength)
		}
		containerView.frame = CGRect(origin: origin, size: size)
	}

	func dismiss(animated: Bool) {
		guard isDisplayed else {
			return
		}
		isDisplayed = false

		if animated {
			UIView.animate(withDuration: 0.2, animations: {
				self.dismissView?.alpha = 0
			}, completion: { (finished) -> () in
				self.dismissView?.removeFromSuperview()
				self.dismissView = nil
			})
		} else {
			dismissView?.removeFromSuperview()
			dismissView = nil
		}
	}
}

private class DetailPopoverArrowView: UIView {
	let arrowPosition: DetailPopoverArrowPosition

	init(arrowPosition: DetailPopoverArrowPosition) {
		self.arrowPosition = arrowPosition
		super.init(frame: CGRect(x: 0, y: 0, width: 2 * arrowLength, height: arrowLength))
		backgroundColor = .clear
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func draw(_ rect: CGRect) {
		let context = UIGraphicsGetCurrentContext()
		let bgColor = UIColor.popover.cgColor
		context!.setFillColor(bgColor)
		let arrowPointY: CGFloat
		let arrowBaseY: CGFloat
		switch arrowPosition {
			case .top(offset: _):
				arrowBaseY = bounds.maxY
				arrowPointY = bounds.minY
			case .bottom(offset: _):
				arrowBaseY = bounds.minY
				arrowPointY = bounds.maxY
		}
		context!.move(to: CGPoint(x: bounds.minX, y: arrowBaseY))
		context!.addLine(to: CGPoint(x: bounds.midX, y: arrowPointY))
		context!.addLine(to: CGPoint(x: bounds.maxX, y: arrowBaseY))
		context!.fillPath()
	}

}

class DetailPopoverDismissView: UIView, UIGestureRecognizerDelegate {
	var popover: DetailPopover!
	init(view: UIView, popover: DetailPopover) {
		self.popover = popover
		super.init(frame: view.bounds)
		backgroundColor = .clear
		autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.addSubview(self)
		let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap(_:)))
		recognizer.delegate = self
		addGestureRecognizer(recognizer)
	}

	override func layoutSubviews() {
		popover.layout()
	}

	@objc private func didTap(_ sender: UITapGestureRecognizer) {
		popover.dismiss(animated: true)
	}

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		let location = touch.location(in: popover.containerView)
		return !popover.containerView.bounds.contains(location)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
