//
//  ScreenDimmer.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

class ScreenDimmer {
	init(dimming initDimm: CGFloat, whiteStatusBar: Bool = false) {
		dimming = initDimm
		statusBarStyle = whiteStatusBar ? .lightContent : .default

		let oldKeyWindow = UIApplication.shared.keyWindow
		overlayWindow = UIWindow(frame: UIScreen.main.bounds)
		overlayWindow.windowLevel = UIWindow.Level.statusBar
		overlayWindow.backgroundColor = .black
		overlayWindow.alpha = 0
		overlayWindow.isHidden = true
		overlayWindow.isOpaque = false
		overlayWindow.rootViewController = overlayVC
		overlayWindow.makeKeyAndVisible()
		overlayWindow.isUserInteractionEnabled = false
		oldKeyWindow?.makeKey()

		overlayVC.statusBarStyle = statusBarStyle
	}

	private let dimming: CGFloat

	private let statusBarStyle: UIStatusBarStyle

	private let overlayVC = DimmingViewController()

	private let overlayWindow: UIWindow

	func set(dimmed: Bool, animated: Bool = false) {
		if animated {
			if dimmed {
				overlayWindow.isHidden = false
				UIView.animate(withDuration: 0.3) {
					self.overlayWindow.alpha = self.dimming
				}
			} else {
				UIView.animate(withDuration: 0.3, animations: {
					self.overlayWindow.alpha = 0
				}, completion: { finished in
					if finished {
						self.overlayWindow.isHidden = true
					}
				})
			}
		} else {
			overlayWindow.isHidden = !dimmed
			overlayWindow.alpha = dimmed ? dimming : 0
		}
	}
}

private class DimmingViewController: UIViewController {
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return statusBarStyle
	}

	var statusBarStyle = UIStatusBarStyle.default

	private var topMainVC: UIViewController? {
		var top = (UIApplication.shared.delegate as? AppDelegate)?.window?.rootViewController
		while top?.presentedViewController != nil {
			top = top?.presentedViewController
		}
		return top
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return topMainVC?.supportedInterfaceOrientations ?? .all
	}

	init() {
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
}
