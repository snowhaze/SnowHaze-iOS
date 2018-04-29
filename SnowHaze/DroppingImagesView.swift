//
//  DroppingImagesView.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import CoreMotion

class DroppingImagesView: UIView {
	private lazy var animator: UIDynamicAnimator = {
		return UIDynamicAnimator(referenceView: self)
	}()

	private var collision = UICollisionBehavior(items: [])
	private var gravity = UIGravityBehavior(items: [])
	private var itemBehavior = UIDynamicItemBehavior(items: [])

	private var lastLayoutBounds = CGRect.zero

	private let motionManager = CMMotionManager()

	private var animationCnt: UInt64 = 0

	var paths: [UIBezierPath?]?

	var imageSize: CGSize = CGSize(width: 50, height: 50)

	var images: [UIImage] = [] {
		didSet {
			restartAnimation(init: true)
		}
	}

	var showBounds = false

	var imageColor = UIColor.black

	override init(frame: CGRect) {
		super.init(frame: frame)
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	private func addImages(isInit: Bool, remainingCnt: Int, forAnimation animation: UInt64) {
		guard remainingCnt > 0, animation == animationCnt else {
			return
		}
		let index = images.randomIndex
		let image = images[index].withRenderingMode(.alwaysTemplate)
		let imageView = BoundedImageView(image: image)
		imageView.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
		imageView.tintColor = imageColor
		addSubview(imageView)
		let imageX = CGFloat(random(Int(bounds.width) + 1)) + bounds.origin.x
		let offset = isInit ? 0 : 2 * bounds.height / 3
		let imageY = CGFloat(random(Int(bounds.height) / 3 + 1)) + bounds.origin.y + offset
		imageView.bounds.size = imageSize
		imageView.center = CGPoint(x: imageX, y: imageY)
		var displayPath: UIBezierPath? = nil
		if let path = paths?[index] {
			imageView.boundsType = .path
			imageView.boundsPath = path
			if showBounds {
				displayPath = path
			}
		} else if showBounds {
			displayPath = UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: imageSize))
		}
		if let path = displayPath {
			let pathView = PathOverlayView()
			pathView.boundsPath = path
			pathView.frame.size = imageSize
			imageView.addSubview(pathView)
		}
		gravity.addItem(imageView)
		collision.addItem(imageView)
		itemBehavior.addItem(imageView)

		if remainingCnt > 1 {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.01) { [weak self] in
				self?.addImages(isInit: isInit, remainingCnt: remainingCnt - 1, forAnimation: animation)
			}
		}
	}

	private func restartAnimation(init isInit: Bool) {
		subviews.forEach { $0.removeFromSuperview() }
		if !images.isEmpty {
			lastLayoutBounds = bounds

			if isInit && motionManager.isAccelerometerAvailable {
				motionManager.accelerometerUpdateInterval = 0.2
				motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] (data, error) -> Void in
					guard let acceleration = data?.acceleration, error == nil else {
						return
					}
					let gravity: CGVector


					switch UIApplication.shared.statusBarOrientation {
						case .landscapeLeft:		gravity = CGVector(dx: acceleration.y, dy: acceleration.x)
						case .landscapeRight:		gravity = CGVector(dx: -acceleration.y, dy: -acceleration.x)
						case .portrait:				gravity = CGVector(dx: acceleration.x, dy: -acceleration.y)
						case .portraitUpsideDown:	gravity = CGVector(dx: -acceleration.x, dy: acceleration.y)
						default:					gravity = CGVector(dx: 0, dy: 0.1)
					}
					self?.gravity.gravityDirection = gravity
				}
			}

			animator.removeAllBehaviors()
			gravity = UIGravityBehavior(items: [])
			animator.addBehavior(gravity)
			collision = UICollisionBehavior(items: [])
			collision.translatesReferenceBoundsIntoBoundary = true
			animator.addBehavior(collision)
			itemBehavior = UIDynamicItemBehavior(items: [])
			itemBehavior.elasticity = 0.995
			animator.addBehavior(itemBehavior)

			animationCnt += 1
			let imageCount = Int(bounds.width / imageSize.width) * Int(bounds.height / imageSize.height) / 2
			addImages(isInit: isInit, remainingCnt: imageCount, forAnimation: animationCnt)
		} else if isInit {
			motionManager.stopAccelerometerUpdates()
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		if lastLayoutBounds != bounds {
			restartAnimation(init: false)
		}
	}

	deinit {
		motionManager.stopAccelerometerUpdates()
	}
}

private class BoundedImageView: UIImageView {
	var boundsType: UIDynamicItemCollisionBoundsType = .rectangle
	var boundsPath: UIBezierPath = UIBezierPath()

	override var collisionBoundingPath: UIBezierPath {
		return boundsPath
	}

	override var collisionBoundsType: UIDynamicItemCollisionBoundsType {
		return boundsType
	}
}

private class PathOverlayView: UIView {
	var boundsPath: UIBezierPath = UIBezierPath()

	override func draw(_ rect: CGRect) {
		let context = UIGraphicsGetCurrentContext()!
		context.saveGState()
		context.translateBy(x: bounds.size.width / 2, y: bounds.size.height / 2)
		UIColor.yellow.setStroke()
		boundsPath.stroke()
		context.restoreGState()
	}

	private func setup() {
		isOpaque = false
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	init() {
		super.init(frame: CGRect.zero)
		setup()
	}
}
