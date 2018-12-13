//
//  TabSelectionView.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

protocol TabSelectionViewDelegate: class {
	func tabSelectionView(_: TabSelectionView, didSelectTab: Int)
	func tabSelectionView(_: TabSelectionView, didCloseTab: Int)
	func tabSelectionView(_: TabSelectionView, didLoadURL: URL, atIndex: Int)
}

private protocol TabViewDelegate: class {
	func tabViewDidSelectTitle(_: TabView, atIndex: Int)
	func tabViewDidClose(_: TabView, atIndex: Int)
	func tabView(_: TabView, loadUrl: URL, atIndex: Int)
}

private class TabView: UIView {
	weak var delegate: TabViewDelegate?
	private let index: Int
	private let title: NSAttributedString
	private let url: URL?
	private let closeButton: UIButton
	private let titleButton: UIButton
	private let separator: UIView

	var selected: Bool {
		set {
			let color: UIColor = newValue ? .white : .darkTitle
			closeButton.tintColor = color
			titleButton.titleLabel?.textColor = color
			titleButton.setTitleColor(color, for: [])
		}
		get {
			return closeButton.tintColor == .white
		}
	}

	init(title: NSAttributedString, url: URL?, index: Int) {
		self.index = index
		self.title = title
		self.url = url

		closeButton = UIButton(type: .system)
		closeButton.tintColor = .darkTitle
		closeButton.setImage(#imageLiteral(resourceName: "close_tab").withRenderingMode(.alwaysTemplate), for: .normal)
		let format = NSLocalizedString("close tab from tab selection bar accessibility label format", comment: "format of the accessibility label for the close tab button of the tab switcher bar")
		closeButton.accessibilityLabel = String(format: format, title)

		titleButton = UIButton()
		titleButton.setAttributedTitle(title, for: [])
		UIFont.setSnowHazeFont(on: titleButton)
		titleButton.titleLabel?.textColor = .darkTitle
		titleButton.setTitleColor(.darkTitle, for: [])
		titleButton.titleLabel?.lineBreakMode = .byTruncatingTail

		separator = UIView()
		separator.backgroundColor = .darkTitle
		separator.clipsToBounds = true
		separator.layer.cornerRadius = 0.5
		separator.isHidden = index == 0

		super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 45))

		if #available(iOS 11, *) {
			let dragInteraction = UIDragInteraction(delegate: self)
			dragInteraction.isEnabled = true
			addInteraction(dragInteraction)

			let dropInteraction = UIDropInteraction(delegate: self)
			dropInteraction.allowsSimultaneousDropSessions = false
			addInteraction(dropInteraction)
		}

		titleButton.addTarget(self, action: #selector(titleButtonPressed(_:)), for: .touchUpInside)
		closeButton.addTarget(self, action: #selector(closeButtonPressed(_:)), for: .touchUpInside)

		addSubview(closeButton)
		addSubview(titleButton)
		addSubview(separator)
	}

	override func layoutSubviews() {
		separator.frame = CGRect(x: bounds.maxX, y: bounds.minY + 5, width: 1, height: bounds.height - 10)
		closeButton.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.height, height: bounds.height)
		let insets = (bounds.height - 15) / 2
		closeButton.imageEdgeInsets = UIEdgeInsets.init(top: insets, left: insets, bottom: insets, right: insets)
		titleButton.frame = CGRect(x: bounds.minX + bounds.height - 10, y: bounds.minY, width: bounds.width - bounds.height, height: bounds.height)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func titleButtonPressed(_ sender: UIButton) {
		delegate?.tabViewDidSelectTitle(self, atIndex: index)
	}

	@objc private func closeButtonPressed(_ sender: UIButton) {
		delegate?.tabViewDidClose(self, atIndex: index)
	}
}

@available(iOS 11, *)
extension TabView: UIDragInteractionDelegate {
	func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
		if let url = url {
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			let sanitizedTitle = Tab.sanitize(title: title.string)
			dragItem.localObject = (url, sanitizedTitle)
			dragItem.previewProvider = { UIDragPreview(for: url, title: sanitizedTitle) }
			return [dragItem]
		} else {
			return []
		}
	}

	func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
		guard let (url, title) = item.localObject as? (URL, String?) else {
			return nil
		}
		guard let window = window else {
			return nil
		}
		let target = UIDragPreviewTarget(container: window, center: session.location(in: window))
		return UITargetedDragPreview(for: url, title: title, target: target)
	}
}

@available(iOS 11, *)
extension TabView: UIDropInteractionDelegate{
	func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
		return session.canLoadObjects(ofClass: URL.self) && session.items.count == 1
	}

	func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
		let location = session.location(in: self)
		if bounds.contains(location) {
			return UIDropProposal(operation: .copy)
		} else {
			return UIDropProposal(operation: .cancel)
		}
	}

	func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
		if session.canLoadObjects(ofClass: URL.self) {
			let _ = session.loadObjects(ofClass: URL.self) { [weak self]  urls in
				assert(urls.count == 1)
				DispatchQueue.main.async {
					if let me = self, let delegate = me.delegate {
						delegate.tabView(me, loadUrl: urls[0], atIndex: me.index)
					}
				}
			}
		}
	}
}

class TabSelectionView: UIView, TabViewDelegate {
	var titleURLs = [(NSAttributedString, URL?)]() {
		didSet {
			refresh()
		}
	}

	var delegate: TabSelectionViewDelegate?

	private func map(index: Int) -> Int? {
		let revesed = titleURLs.count - 1 - index
		if revesed >= 0 && revesed < tabViews.count {
			return revesed
		} else {
			return nil
		}
	}

	private func unmap(index: Int) -> Int {
		return titleURLs.count - 1 - index
	}

	var selectedTab: Int = 0 {
		didSet {
			if let old = map(index: oldValue) {
				tabViews[old].selected = false
			}
			if let new = map(index: selectedTab) {
				tabViews[new].selected = true
			}
		}
	}

	private var displayCnt = 0 {
		didSet {
			refresh()
		}
	}

	private var tabsPostfix: [(NSAttributedString, URL?)] {
		return [(NSAttributedString, URL?)](titleURLs.reversed().prefix(displayCnt))
	}

	private var tabViews = [TabView]()

	func refresh() {
		tabViews.forEach { $0.removeFromSuperview() }
		tabViews = []
		for (i, (title, url)) in tabsPostfix.enumerated() {
			let tabView = TabView(title: title, url: url, index: i)
			tabView.delegate = self
			tabViews.append(tabView)
		}
		guard !tabViews.isEmpty else {
			return
		}
		if let selected = map(index: selectedTab) {
			tabViews[selected].selected = true
		}
		tabViews.forEach { addSubview($0) }
		layoutSubviews()
	}

	func representingViewForTab(at index: Int) -> UIView? {
		guard let index = map(index: index) else {
			return nil
		}
		return tabViews[index]
	}

	override func layoutSubviews() {
		let newCnt = Int(bounds.width / 250)
		if newCnt != displayCnt {
			displayCnt = newCnt
		} else {
			let width = bounds.width / CGFloat(tabViews.count)
			for (i, tabView) in tabViews.reversed().enumerated() {
				tabView.frame = CGRect(x: CGFloat(i) * width, y: bounds.minY, width: width, height: bounds.height)
			}
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		refresh()
	}

	fileprivate func tabViewDidSelectTitle(_: TabView, atIndex index: Int) {
		delegate?.tabSelectionView(self, didSelectTab: unmap(index: index))
	}

	fileprivate func tabViewDidClose(_: TabView, atIndex index: Int) {
		delegate?.tabSelectionView(self, didCloseTab: unmap(index: index))
	}

	fileprivate func tabView(_: TabView, loadUrl url: URL, atIndex index: Int) {
		delegate?.tabSelectionView(self, didLoadURL: url, atIndex: unmap(index: index))
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init with coder not supported")
	}
}
