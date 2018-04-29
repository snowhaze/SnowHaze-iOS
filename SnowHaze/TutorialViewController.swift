//
//  TutorialViewController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class TutorialViewController: UIViewController {
	private lazy var pageControl: UIPageControl = {
		let ret = UIPageControl()
		ret.addTarget(self, action: #selector(pageControlTapped(_:)), for: .touchUpInside)
		return ret
	}()

	private var overlap: CGFloat {
		return overlapRel + overlapConst / view.bounds.height
	}

	private let overlapConst: CGFloat = 100
	private let overlapRel: CGFloat = 0.125
	private let animationDuration = 0.4

	private var index = 0

	var views: [(UIView, UIView)] {
		fatalError("TutorialViewController is intended as an abstract superclass")
	}

	override var prefersStatusBarHidden : Bool {
		return true
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let image = #imageLiteral(resourceName: "tutorial_background")
		let backgroundImageView = UIImageView(image: image)
		backgroundImageView.contentMode = .scaleAspectFill
		backgroundImageView.frame = view.bounds
		backgroundImageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.addSubview(backgroundImageView)

		pageControl.numberOfPages = views.count
		pageControl.currentPage = index
		pageControl.frame = CGRect(x: 0, y: 10, width: view.bounds.width, height: 40)
		pageControl.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
		view.addSubview(pageControl)
		pageControl.pageIndicatorTintColor = .deselectedTutorialPage
		pageControl.currentPageIndicatorTintColor = .selectedTutorialPage

		let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(selectNext))
		leftSwipe.direction = .left
		view.addGestureRecognizer(leftSwipe)
		let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(selectPrev))
		rightSwipe.direction = .right
		view.addGestureRecognizer(rightSwipe)
	}

	@available(iOS 11.0, *)
	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		pageControl.frame = CGRect(x: view.bounds.minX, y: view.bounds.minY + view.safeAreaInsets.top, width: view.bounds.width, height: 20)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		let mainView = views[index].0
		mainView.frame = view.bounds
		mainView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.insertSubview(mainView, belowSubview: pageControl)

		let secondaryView = views[index].1
		secondaryView.frame = view.bounds
		secondaryView.frame.origin.y += secondaryView.frame.height * (1-overlap)
		secondaryView.frame.size.height = secondaryView.frame.height * overlap
		secondaryView.autoresizingMask = [.flexibleHeight, .flexibleWidth, .flexibleTopMargin]
		view.insertSubview(secondaryView, belowSubview: pageControl)
	}

	@objc func selectNext() {
		guard index < views.count - 1 else {
			return
		}
		forward(to: index + 1)
	}

	func forward(to: Int) {
		guard index < views.count else {
			return
		}
		let oldIndex = index
		let oldMainView = views[index].0
		let oldSecView = views[index].1
		index = to
		pageControl.currentPage = index
		let newMainView = views[index].0
		let newSecView = views[index].1

		newMainView.frame = view.bounds
		newMainView.frame.origin.x += view.bounds.width
		newMainView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.insertSubview(newMainView, belowSubview: oldMainView)

		newSecView.frame = view.bounds
		newSecView.frame.size.height = view.bounds.height * overlap
		newSecView.frame.origin.y += view.bounds.height
		newSecView.autoresizingMask = [.flexibleHeight, .flexibleWidth, .flexibleTopMargin]

		UIView.animate(withDuration: animationDuration, animations: {
			oldMainView.frame.origin.x -= self.view.bounds.width
			newMainView.frame.origin.x -= self.view.bounds.width
		}, completion:  { [weak self] _ in
			oldMainView.removeFromSuperview()
			self?.didAnimate(from: oldIndex, to: to)
		})

		UIView.animate(withDuration: animationDuration / 2, animations: {
			oldSecView.frame.origin.y += oldSecView.frame.size.height
		}, completion: { _ in
			oldSecView.removeFromSuperview()
			self.view.insertSubview(newSecView, belowSubview: self.pageControl)
			UIView.animate(withDuration: self.animationDuration / 2, animations: {
				newSecView.frame.origin.y -= newSecView.frame.size.height
			})
		})
	}

	@objc private func pageControlTapped(_ sender: UIPageControl) {
		switch sender.currentPage {
			case index + 1:	forward(to: index + 1)
			case index - 1:	selectPrev()
			default: 		assert(sender.currentPage == index)
		}
	}

	@objc func selectPrev() {
		guard index > 0 else {
			return
		}
		let oldIndex = index
		let newIndex = oldIndex - 1
		let oldMainView = views[index].0
		let oldSecView = views[index].1
		index = newIndex
		pageControl.currentPage = index
		let newMainView = views[index].0
		let newSecView = views[index].1

		newMainView.frame = view.bounds
		newMainView.frame.origin.x -= view.bounds.width
		newMainView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.insertSubview(newMainView, belowSubview: oldMainView)

		newSecView.frame = view.bounds
		newSecView.frame.size.height = view.bounds.height * overlap
		newSecView.frame.origin.y += view.bounds.height
		newSecView.autoresizingMask = [.flexibleHeight, .flexibleWidth, .flexibleTopMargin]

		UIView.animate(withDuration: animationDuration, animations: {
			oldMainView.frame.origin.x += self.view.bounds.width
			newMainView.frame.origin.x += self.view.bounds.width
		}, completion:  { [weak self] _ in
			oldMainView.removeFromSuperview()
			self?.didAnimate(from: oldIndex, to: newIndex)
		})

		UIView.animate(withDuration: animationDuration / 2, animations: {
			oldSecView.frame.origin.y += oldSecView.frame.size.height
		}, completion: { _ in
			oldSecView.removeFromSuperview()
			self.view.insertSubview(newSecView, belowSubview: self.pageControl)
			UIView.animate(withDuration: self.animationDuration / 2, animations: {
				newSecView.frame.origin.y -= newSecView.frame.size.height
			})
		})
	}

	override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
		return UI_USER_INTERFACE_IDIOM() == .pad ? .all : .portrait
	}

	override var preferredStatusBarStyle : UIStatusBarStyle {
		return .lightContent
	}

	@objc func closeTutorial() {
		close(completion: nil)
	}

	func close(completion: (() -> Void)?) {
		dismiss(animated: true, completion: completion)
		let policy = PolicyManager.globalManager()
		policy.updateTutorialVersion()
	}

	func didAnimate(from oldIndex: Int, to newIndex: Int) { }
}
