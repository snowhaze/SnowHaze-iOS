//
//  HeightChangingToolbarContainer.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class HeightChangingToolbarContainer: UIView {
	var scale: CGFloat = 1 {
		didSet {
			invalidateIntrinsicContentSize()
			setNeedsLayout()
			layoutIfNeeded()
			superview?.setNeedsLayout()
			superview?.layoutIfNeeded()
		}
	}

	override var intrinsicContentSize : CGSize {
		let masterSize = super.intrinsicContentSize
		let width = masterSize.width
		let fullHeight = (toolbar?.frame.height ?? 44) + safeAreaInsets.bottom
		let height = traitCollection.horizontalSizeClass == .compact ? fullHeight * scale : 0
		return CGSize(width: width, height: height)
	}

	override func safeAreaInsetsDidChange() {
		super.safeAreaInsetsDidChange()
		invalidateIntrinsicContentSize()
	}

	@IBOutlet weak var toolbar: UIToolbar?
}
