//
//  TabSelectionView.swift
//  SnowHaze
//
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

private class TabView: UICollectionViewCell {
	weak var delegate: TabViewDelegate?
	private var index = 0
	private var title = NSAttributedString()
	private var url: URL?
	private let closeButton = UIButton(type: .system)
	private let titleButton = UIButton()
	private let separator = UIView()

	var tabSelected: Bool {
		set {
			let color: UIColor = newValue ? .white : .dimmedTitle
			closeButton.tintColor = color
			titleButton.titleLabel?.textColor = color
			titleButton.setTitleColor(color, for: [])
		}
		get {
			return closeButton.tintColor == .white
		}
	}

	func setup(title: NSAttributedString, url: URL?, index: Int) {
		self.index = index
		self.title = title
		self.url = url

		closeButton.tintColor = .dimmedTitle

		titleButton.setAttributedTitle(title, for: [])
		titleButton.titleLabel?.textColor = .dimmedTitle
		titleButton.setTitleColor(.dimmedTitle, for: [])

		separator.isHidden = index == 0
	}

	override func layoutSubviews() {
		separator.frame = CGRect(x: bounds.minX, y: bounds.minY + 5, width: 1, height: bounds.height - 10)
		closeButton.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.height, height: bounds.height)
		let insets = (bounds.height - 15) / 2
		closeButton.imageEdgeInsets = UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)
		titleButton.frame = CGRect(x: bounds.minX + bounds.height - 10, y: bounds.minY, width: bounds.width - bounds.height, height: bounds.height)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		separator.backgroundColor = .dimmedTitle
		backgroundColor = .bar
		separator.clipsToBounds = true
		separator.layer.cornerRadius = 0.5

		closeButton.setImage(#imageLiteral(resourceName: "close_tab").withRenderingMode(.alwaysTemplate), for: .normal)
		let format = NSLocalizedString("close tab from tab selection bar accessibility label format", comment: "format of the accessibility label for the close tab button of the tab switcher bar")
		closeButton.accessibilityLabel = String(format: format, title)

		titleButton.titleLabel?.lineBreakMode = .byTruncatingTail

		let dragInteraction = UIDragInteraction(delegate: self)
		dragInteraction.isEnabled = true
		addInteraction(dragInteraction)

		let dropInteraction = UIDropInteraction(delegate: self)
		dropInteraction.allowsSimultaneousDropSessions = false
		addInteraction(dropInteraction)

		titleButton.addTarget(self, action: #selector(titleButtonPressed(_:)), for: .touchUpInside)
		closeButton.addTarget(self, action: #selector(closeButtonPressed(_:)), for: .touchUpInside)

		addSubview(closeButton)
		addSubview(titleButton)
		addSubview(separator)
	}

	@objc private func titleButtonPressed(_ sender: UIButton) {
		delegate?.tabViewDidSelectTitle(self, atIndex: index)
	}

	@objc private func closeButtonPressed(_ sender: UIButton) {
		delegate?.tabViewDidClose(self, atIndex: index)
	}
}

extension TabView: UIDragInteractionDelegate {
	func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
		if let url = url {
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			let plainTitle = title.string
			dragItem.localObject = (url, plainTitle)
			dragItem.previewProvider = { UIDragPreview(for: url, title: plainTitle) }
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

extension TabView: UIDropInteractionDelegate {
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
			_ = session.loadObjects(ofClass: URL.self) { [weak self]  urls in
				assert(urls.count == 1)
				DispatchQueue.main.async {
					if let self = self, let delegate = self.delegate {
						delegate.tabView(self, loadUrl: urls[0], atIndex: self.index)
					}
				}
			}
		}
	}
}

class TabSelectionView: UICollectionView, TabViewDelegate {
	private var lastSize = CGSize.zero

	var titleURLs = [(NSAttributedString, URL?)]() {
		didSet {
			reloadData()
		}
	}

	var tabDelegate: TabSelectionViewDelegate?

	var selectedTab: Int = 0 {
		didSet {
			guard selectedTab != oldValue else {
				return
			}
			(representingViewForTab(at: oldValue) as? TabView)?.tabSelected = false
			(representingViewForTab(at: selectedTab) as? TabView)?.tabSelected = true
			DispatchQueue.main.async { [weak self] in
				guard let self = self else {
					return
				}
				let tabWidth = TabSelectionViewLayout.tabWidth(for: self)
				let x = CGFloat(self.selectedTab) * tabWidth - 200
				self.scrollRectToVisible(CGRect(x: x, y: 0, width: tabWidth + 400, height: self.bounds.height), animated: true)
			}
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		if lastSize != bounds.size {
			let tabWidth = TabSelectionViewLayout.tabWidth(for: self)
			let x = CGFloat(selectedTab) * tabWidth - 200
			scrollRectToVisible(CGRect(x: x, y: 0, width: tabWidth + 400, height: bounds.height), animated: true)
			lastSize = bounds.size
		}
	}

	init(frame: CGRect) {
		super.init(frame: frame, collectionViewLayout: TabSelectionViewLayout())
		register(TabView.self, forCellWithReuseIdentifier: "tabCell")
		backgroundColor = .bar
		dataSource = self
		showsHorizontalScrollIndicator = false
		reloadData()
	}

	func representingViewForTab(at index: Int) -> UIView? {
		return cellForItem(at: IndexPath(row: index, section: 0))
	}

	fileprivate func tabViewDidSelectTitle(_: TabView, atIndex index: Int) {
		tabDelegate?.tabSelectionView(self, didSelectTab: index)
	}

	fileprivate func tabViewDidClose(_: TabView, atIndex index: Int) {
		tabDelegate?.tabSelectionView(self, didCloseTab: index)
	}

	fileprivate func tabView(_: TabView, loadUrl url: URL, atIndex index: Int) {
		tabDelegate?.tabSelectionView(self, didLoadURL: url, atIndex: index)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init with coder not supported")
	}
}

extension TabSelectionView: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return titleURLs.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let tv = dequeueReusableCell(withReuseIdentifier: "tabCell", for: indexPath) as! TabView
		tv.setup(title: titleURLs[indexPath.row].0, url: titleURLs[indexPath.row].1, index: indexPath.row)
		tv.tabSelected = indexPath.row == selectedTab
		tv.delegate = self
		return tv
	}
}

private let compressFactor: CGFloat = 3
private let compressWidth: CGFloat = 150
private class TabSelectionViewLayout: UICollectionViewLayout {
	override var collectionViewContentSize : CGSize {
		return CGSize(width: width, height: tsv.bounds.height)
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}

	private var width: CGFloat {
		return CGFloat(tsv.titleURLs.count) * tabWidth
	}

	static func tabWidth(for tsv: TabSelectionView) -> CGFloat {
		return max(200 + tsv.bounds.width / 25, tsv.bounds.width / CGFloat(tsv.titleURLs.count))
	}

	private var tabWidth: CGFloat {
		return TabSelectionViewLayout.tabWidth(for: tsv)
	}

	private var tsv: TabSelectionView {
		return collectionView as! TabSelectionView
	}

	override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		guard !tsv.titleURLs.isEmpty else {
			return []
		}
		let minI = max(0, Int(rect.minX) / Int(tabWidth) - 1)
		let maxI = max(0, min(tsv.titleURLs.count - 1, Int(rect.maxX + tabWidth) / Int(tabWidth) + 1))
		guard maxI > minI else {
			return []
		}
		return (minI ... maxI).map { layoutAttributesForItem(at: IndexPath(row: $0, section: 0))! }
	}

	override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let row = CGFloat(indexPath.row)
		let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
		var x = row * tabWidth

		func comp(_ d: CGFloat) -> CGFloat {
			let w = compressFactor * compressWidth
			return pow(max(0, min(w, d)) / w, 1) * (w - compressWidth)
		}
		x += comp(tsv.bounds.minX - x)
		x -= comp(x + tabWidth - compressWidth - tsv.bounds.maxX)

		let frame = CGRect(x: x, y: 0, width: tabWidth, height: tsv.bounds.height)
		attributes.frame = frame
		attributes.zIndex = indexPath.row
		return attributes
	}
}
