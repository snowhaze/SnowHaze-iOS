//
//  SplitMergeController.swift
//  iostest
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
/**
 *	The SplitMergeController currently presentling self.
 *	Only works reliably in masterViewController.
 */
	var splitMergeController: SplitMergeController? {
		return parent as? SplitMergeController
	}
}

/**
 *	UIViewController that handles a master-detail relationship in both constrained and regular width scenario.
 *	Has to be the topViewController on a UINavigationController to perform as intended.
 */
class SplitMergeController: UIViewController {
/**
 *	Equivalent to the UISplitViewController.viewControllers().first()!
 *	Has to be set before view is loaded
 */
	var masterViewController: UIViewController! {
		willSet {
			masterViewController?.willMove(toParentViewController: nil)
			masterViewController?.view.removeFromSuperview()
			masterViewController?.removeFromParentViewController()
		}
		didSet {
			addChildViewController(masterViewController)
			viewIfLoaded?.addSubview(masterViewController.view)
			masterViewController.didMove(toParentViewController: self)
			navigationItem.title = masterViewController.navigationItem.title
			if let _ = viewIfLoaded {
				layout()
			}
		}
	}

/**
 *	Equivalent to the UISplitViewController.viewControllers()[1]
 *	Setting it automaticaly pushes is on the navigationController if in constrained width mode.
 */
	var detailViewController: UIViewController? {
		willSet {
			detailFocus = false
			use(masterViewController.navigationItem)
			if constrainedWidth {
				if let _ = viewIfLoaded , navigationController!.topViewController == detailViewController {
					navigationController!.popToViewController(self, animated: true)
				}
			} else {
				detailViewController?.willMove(toParentViewController: nil)
				detailViewController?.view.removeFromSuperview()
				detailViewController?.removeFromParentViewController()
			}
		}
		didSet {
			if let detailViewController = detailViewController {
				if constrainedWidth {
					if let _ = viewIfLoaded {
						navigationController!.pushViewController(detailViewController, animated: true)
					}
				} else {
					use(detailViewController.navigationItem)
					addChildViewController(detailViewController)
					viewIfLoaded?.addSubview(detailViewController.view)
					detailViewController.didMove(toParentViewController: self)
					if let _ = viewIfLoaded {
						layout()
					}
				}
				detailFocus = true
			}
		}
	}

	private let backgroundImageView = UIImageView(image: nil)
	private var constrainedWidth = false
	private var detailFocus = false

/**
 *	Image displayed behind detailViewController.
 *	Therefore also serves as a placeholder image if detailViewController is not set.
 */
	var backgroundImage: UIImage? {
		set {
			backgroundImageView.image = newValue
			backgroundImageView.contentMode = .scaleAspectFill
		}
		get {
			return backgroundImageView.image
		}
	}

/**
 *	maps directly to view.backgroundColor
 *	cannot be accessed before view is loaded
 */
	var backgroundColor: UIColor? {
		set {
			viewIfLoaded?.backgroundColor = newValue
			navigationController?.view?.backgroundColor = newValue
		}
		get {
			return viewIfLoaded?.backgroundColor
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.addSubview(backgroundImageView)
		constrainedWidth = traitCollection.horizontalSizeClass == .compact
		view.addSubview(masterViewController.view)
		detailFocus = false
		if let detailViewController = detailViewController , !constrainedWidth {
			view.addSubview(detailViewController.view)
		}
		layout()
		use(masterViewController.navigationItem)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		DispatchQueue.main.async {
			self.layout()
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if constrainedWidth {
			detailFocus = false
		}
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	private func layout() {
		let size = view.bounds.size
		if self.constrainedWidth {
			masterViewController.view.frame = CGRect(origin: CGPoint.zero, size: size)
		} else {
			let masterWidth = (size.width - 200) * 0.3 + 200
			let detailWidth = size.width - masterWidth
			let masterFrame = CGRect(x: 0, y: 0, width: masterWidth, height: size.height)
			let detailFrame = CGRect(x: masterWidth, y: 0, width: detailWidth, height: size.height)
			masterViewController.view.frame = masterFrame
			backgroundImageView.frame = detailFrame
			detailViewController?.view.frame = detailFrame
		}
	}

	private func use(_ navItem: UINavigationItem) {
		navigationItem.title = navItem.title
		navigationItem.titleView = navItem.titleView
		navigationItem.prompt = navItem.prompt
	}
}

//UIContentContainer methods
extension SplitMergeController {
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		super.willTransition(to: newCollection, with: coordinator)
		let oldConstrainedWidth = constrainedWidth
		constrainedWidth = newCollection.horizontalSizeClass == .compact
		if !oldConstrainedWidth && constrainedWidth {
			use(masterViewController.navigationItem)
			if let detailViewController = detailViewController {
				detailViewController.willMove(toParentViewController: nil)
				detailViewController.view.removeFromSuperview()
				detailViewController.removeFromParentViewController()
				if detailFocus {
					navigationController!.pushViewController(detailViewController, animated: false)
				}
			}
		} else if !constrainedWidth && oldConstrainedWidth {
			if let detailViewController = detailViewController {
				use(detailViewController.navigationItem)
				if navigationController!.topViewController == detailViewController {
					navigationController!.popToViewController(self, animated: false)
				}
				addChildViewController(detailViewController)
				viewIfLoaded?.addSubview(detailViewController.view)
				detailViewController.didMove(toParentViewController: self)
			}
		}
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		//Wait for view.bounds to be adjusted to the new size
		DispatchQueue.main.async {
			self.layout()
		}
	}
}
