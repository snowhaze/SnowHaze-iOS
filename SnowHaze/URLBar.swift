//
//  URLBar.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

private let tabSelectionMaxHeight: CGFloat = 45
private let tabSelectionShinkage: CGFloat = 8

protocol URLBarDelegate: class {
	func prevButtonPressed(for urlBar: URLBar)
	func nextButtonPressed(for urlBar: URLBar)
	func shareButtonPressed(for urlBar: URLBar, sender: NSObject)
	func plusButtonPressed(for urlBar: URLBar)
	func tabsButtonPressed(for urlBar: URLBar)
	func settingsButtonPressed(for urlBar: URLBar)
	func reloadButtonPressed(for urlBar: URLBar)
	func securityDetailButtonPressed(for urlBar: URLBar)
	func cancelLoad(for urlBar: URLBar)
	func inputStringUpdated(for urlBar: URLBar, input: String)
	func urlbar(_ urlBar: URLBar, selectedInput: String)
	func inputEnded(for urlBar: URLBar)
	func urlbar(_ urlBar: URLBar, selectedTab: Int)
	func urlbar(_ urlBar: URLBar, closedTab: Int)
	func urlbar(_ urlBar: URLBar, loadedURL: URL, atIndex: Int)
}

@IBDesignable
class URLBar: UIView {
	private let containerView = UIView()
	let urlField = UITextField()
	private let securityButton = UIButton()
	private let loadBar = LoadBar()
	private let prevButton = UIButton()
	private let nextButton = UIButton()
	private let shareButton = UIButton()
	private let plusButton = UIButton()
	private let tabsButton = UIButton()
	private let settingsButton = UIButton()
	private let reloadButton = UIButton()
	private let cancelButton = UIButton()

	private var startEditingRecognizer: UITapGestureRecognizer?
	private var rawDragInteraction: Any?

	@available(iOS 11, *)
	private var dragInteraction: UIDragInteraction? {
		get {
			return rawDragInteraction as? UIDragInteraction
		}
		set {
			rawDragInteraction = newValue
		}
	}

	private let tabSelectionView = TabSelectionView()

	var tabTitleURLs: [(NSAttributedString, URL?)] {
		set {
			tabSelectionView.titleURLs = newValue
		}
		get {
			return tabSelectionView.titleURLs
		}
	}

	var selectedTab: Int {
		set {
			tabSelectionView.selectedTab = newValue
		}
		get {
			return tabSelectionView.selectedTab
		}
	}

	var attributedTitle: NSAttributedString? {
		didSet {
			if !urlField.isFirstResponder {
				urlField.attributedText = attributedTitle
			}
		}
	}

	var url: URL? {
		didSet {
			if urlField.isFirstResponder {
				urlField.attributedText = NSAttributedString(string: url?.absoluteString ?? "")
			}
		}
	}

	var isEditing: Bool {
		return urlField.isFirstResponder
	}

	var title: String? {
		set {
			if let title = newValue {
				attributedTitle = NSAttributedString(string: title)
			} else {
				attributedTitle = nil
			}
		}
		get {
			return attributedTitle?.string
		}
	}

	@IBOutlet weak var externalPrevButton: UIBarButtonItem? {
		didSet {
			externalPrevButton?.accessibilityLabel = NSLocalizedString("previous page button accessibility label", comment: "accessibility label of button to load the previous page")
		}
	}

	@IBOutlet weak var externalNextButton: UIBarButtonItem? {
		didSet {
			externalNextButton?.accessibilityLabel = NSLocalizedString("next page button accessibility label", comment: "accessibility label of button to load the next page")
		}
	}

	@IBOutlet weak var externalShareButton: UIBarButtonItem? {
		didSet {
			externalShareButton?.accessibilityLabel = NSLocalizedString("share button accessibility label", comment: "accessibility label of button to show share dialog")
		}
	}

	@IBOutlet weak var externalTabsButton: UIBarButtonItem? {
		didSet {
			externalTabsButton?.accessibilityLabel = NSLocalizedString("show tab selection view button accessibility label", comment: "accessibility label of button to show tab selection view")
		}
	}

	@IBOutlet weak var externalSettingsButton: UIBarButtonItem? {
		didSet {
			externalSettingsButton?.accessibilityLabel = NSLocalizedString("show settings controller button accessibility label", comment: "accessibility label of button to show settings controller")
		}
	}

	private let reloadCounter = RepeatCounter(repetitions: 3)

	private let loadBarHeight: CGFloat = 2.5

	weak var delegate: URLBarDelegate?

	var canGoForward: Bool {
		get {
			return nextButton.isEnabled
		}
		set {
			nextButton.isEnabled = newValue
			externalNextButton?.isEnabled = newValue
		}
	}

	var canGoBack: Bool {
		get {
			return prevButton.isEnabled
		}
		set {
			prevButton.isEnabled = newValue
			externalPrevButton?.isEnabled = newValue
		}
	}

	private(set) var showsCancelButton: Bool = false {
		willSet {
			guard newValue != showsCancelButton else {
				return
			}
			if newValue {
				cancelButton.alpha = 0
				cancelButton.isHidden = false
				UIView.animate(withDuration: 0.3, animations: { () -> Void in
					self.cancelButton.alpha = 1
					self.reloadButton.alpha = 0
				}, completion: { (finished) -> Void in
					if finished {
						self.reloadButton.isHidden = true
					}
				})
			} else if !newValue {
				reloadButton.alpha = 0
				reloadButton.isHidden = false
				UIView.animate(withDuration: 0.3, animations: { () -> Void in
					self.reloadButton.alpha = 1
					self.cancelButton.alpha = 0
				}, completion: { (finished) -> Void in
					if finished {
						self.cancelButton.isHidden = true
					}
				})
			}
		}
	}

	func startInput() {
		showsCancelButton = true
		urlField.becomeFirstResponder()
	}

	func stopInput() {
		if progress <= 0 || progress >= 1 {
			showsCancelButton = false
		}
		urlField.resignFirstResponder()
	}

	var constrainedWidth: Bool = false {
		didSet {
			prevButton.isHidden = constrainedWidth
			nextButton.isHidden = constrainedWidth
			shareButton.isHidden = constrainedWidth
			plusButton.isHidden = constrainedWidth
			tabsButton.isHidden = constrainedWidth
			settingsButton.isHidden = constrainedWidth
			layoutContentView()
			updateTabSelectionView()
			invalidateIntrinsicContentSize()
		}
	}

	var constrainedHeight: Bool = false {
		didSet {
			updateTabSelectionView()
			invalidateIntrinsicContentSize()
		}
	}

	private var showTabSelection: Bool {
		return !constrainedHeight && !constrainedWidth
	}

	private var tabSelectionHeight: CGFloat {
		return showTabSelection ? tabSelectionMaxHeight : 0
	}

	override var intrinsicContentSize : CGSize {
		return CGSize(width: UIView.noIntrinsicMetric, height: height(for: scale))
	}

	@available(iOS 11, *)
	override func safeAreaInsetsDidChange() {
		super.safeAreaInsetsDidChange()
		layoutContentView()
	}

	var securityIcon: UIImage? {
		set {
			let icon = newValue?.withRenderingMode(.alwaysTemplate)
			securityButton.setImage(icon, for: [])
		}
		get {
			return securityButton.image(for: [])
		}
	}

	var securityName: String? {
		set {
			securityButton.accessibilityLabel = newValue
		}
		get {
			return securityButton.accessibilityLabel
		}
	}

	var securityIconColor: UIColor {
		set {
			securityButton.tintColor = newValue
		}
		get {
			return securityButton.tintColor
		}
	}

	var scale: CGFloat = 1 {
		didSet {
			let contentAlpha = max(scale * 1.3 - 0.3, 0)
			containerView.alpha = contentAlpha
			prevButton.alpha = contentAlpha
			nextButton.alpha = contentAlpha
			shareButton.alpha = contentAlpha
			plusButton.alpha = contentAlpha
			tabsButton.alpha = contentAlpha
			settingsButton.alpha = contentAlpha
			invalidateIntrinsicContentSize()
			setNeedsLayout()
			layoutIfNeeded()
			superview?.setNeedsLayout()
			superview?.layoutIfNeeded()
		}
	}

	@IBInspectable var progress: CGFloat {
		set {
			loadBar.progress = newValue
			loadBar.setNeedsDisplay()
			showsCancelButton = (newValue > 0 && newValue < 1) || urlField.isFirstResponder
		}
		get {
			return loadBar.progress
		}
	}

	func securityButtonFrame(in view: UIView) -> CGRect {
		return containerView.convert(securityButton.frame, to: view)
	}

	private func setupAccessibility() {
		prevButton.accessibilityLabel = NSLocalizedString("previous page button accessibility label", comment: "accessibility label of button to load the previous page")
		nextButton.accessibilityLabel = NSLocalizedString("next page button accessibility label", comment: "accessibility label of button to load the next page")
		shareButton.accessibilityLabel = NSLocalizedString("share button accessibility label", comment: "accessibility label of button to show share dialog")
		tabsButton.accessibilityLabel = NSLocalizedString("show tab selection view button accessibility label", comment: "accessibility label of button to show tab selection view")
		settingsButton.accessibilityLabel = NSLocalizedString("show settings controller button accessibility label", comment: "accessibility label of button to show settings controller")

		reloadButton.accessibilityLabel = NSLocalizedString("reload page button accessibility label", comment: "accessibility label of button to reload the current page")
		plusButton.accessibilityLabel = NSLocalizedString("new tab button accessibility label", comment: "accessibility label of button to create a new tab")
	}

	private func setupButtons() {
		prevButton.tintColor = .button
		nextButton.tintColor = .button
		shareButton.tintColor = .button
		settingsButton.tintColor = .button
		plusButton.tintColor = .button

		prevButton.setImage(#imageLiteral(resourceName: "previous"), for: [])
		nextButton.setImage(#imageLiteral(resourceName: "next"), for: [])
		shareButton.setImage(#imageLiteral(resourceName: "share"), for: [])
		plusButton.setImage(#imageLiteral(resourceName: "plus"), for: [])
		tabsButton.setImage(#imageLiteral(resourceName: "tabs"), for: [])
		settingsButton.setImage(#imageLiteral(resourceName: "settings"), for: [])

		reloadButton.setImage(#imageLiteral(resourceName: "reload"), for: [])
		let originalClose = #imageLiteral(resourceName: "close")
		let close = originalClose.withRenderingMode(.alwaysTemplate)
		cancelButton.setImage(close, for: [])
		cancelButton.tintColor = .title
		cancelButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

		let flexibleTopRight: UIView.AutoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
		let flexibleTopLeft: UIView.AutoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]

		prevButton.frame.origin.x = 12
		prevButton.frame.origin.y = containerView.frame.origin.y - 5
		prevButton.frame.size.height = 45
		prevButton.frame.size.width = 45
		prevButton.autoresizingMask = flexibleTopRight

		nextButton.frame.origin.x = 67
		nextButton.frame.origin.y = containerView.frame.origin.y - 5
		nextButton.frame.size.height = 45
		nextButton.frame.size.width = 45
		nextButton.autoresizingMask = flexibleTopRight

		shareButton.frame.origin.x = 122
		shareButton.frame.origin.y = containerView.frame.origin.y - 5
		shareButton.frame.size.height = 45
		shareButton.frame.size.width = 45
		shareButton.autoresizingMask = flexibleTopRight

		plusButton.frame.origin.x = bounds.width - 167
		plusButton.frame.origin.y = containerView.frame.origin.y - 5
		plusButton.frame.size.height = 45
		plusButton.frame.size.width = 45
		plusButton.autoresizingMask = flexibleTopLeft

		tabsButton.frame.origin.x = bounds.width - 112
		tabsButton.frame.origin.y = containerView.frame.origin.y - 5
		tabsButton.frame.size.height = 45
		tabsButton.frame.size.width = 45
		tabsButton.autoresizingMask = flexibleTopLeft

		settingsButton.frame.origin.x = bounds.width - 57
		settingsButton.frame.origin.y = containerView.frame.origin.y - 5
		settingsButton.frame.size.height = 45
		settingsButton.frame.size.width = 45
		settingsButton.autoresizingMask = flexibleTopLeft

		reloadButton.frame = CGRect(x: containerView.bounds.maxX - 35, y: containerView.bounds.minY, width: 35, height: 35)
		reloadButton.autoresizingMask = .flexibleLeftMargin

		cancelButton.frame = reloadButton.frame
		cancelButton.autoresizingMask = reloadButton.autoresizingMask
		cancelButton.isHidden = true

		addSubview(prevButton)
		addSubview(nextButton)
		addSubview(shareButton)
		addSubview(plusButton)
		addSubview(tabsButton)
		addSubview(settingsButton)

		containerView.addSubview(reloadButton)
		containerView.addSubview(cancelButton)

		prevButton.addTarget(self, action: #selector(prevButtonPressed(_:)), for: .touchUpInside)
		nextButton.addTarget(self, action: #selector(nextButtonPressed(_:)), for: .touchUpInside)
		shareButton.addTarget(self, action: #selector(shareButtonPressed(_:)), for: .touchUpInside)
		plusButton.addTarget(self, action: #selector(plusButtonPressed(_:)), for: .touchUpInside)
		tabsButton.addTarget(self, action: #selector(tabsButtonPressed(_:)), for: .touchUpInside)
		settingsButton.addTarget(self, action: #selector(settingsButtonPressed(_:)), for: .touchUpInside)
		securityButton.addTarget(self, action: #selector(securityDetailButtonPressed(_:)), for: .touchUpInside)

		reloadButton.addTarget(self, action: #selector(reloadButtonPressed(_:)), for: .touchUpInside)
		cancelButton.addTarget(self, action: #selector(cancelButtonPressed(_:)), for: .touchUpInside)
	}

	private func setup() {
		backgroundColor = .bar
		layer.shadowOpacity = 0.15
		layer.shadowOffset = CGSize(width: 0, height: 1)
		layer.shadowRadius = 2
		if #available(iOS 11, *) {
			containerView.layer.cornerRadius = 10
		} else {
			containerView.layer.cornerRadius = 4
		}
		containerView.clipsToBounds = true
		containerView.frame = CGRect(x: 12, y: 27, width: 105, height: 35)
		containerView.autoresizingMask = .flexibleWidth
		containerView.backgroundColor = UIColor(white: 1, alpha: 0.05)

		securityButton.backgroundColor = UIColor(white: 1, alpha: 0.1)
		securityButton.frame = CGRect(x: 0, y: 0, width: 35, height: 35)
		securityButton.imageView?.contentMode = .scaleAspectFit
		let inset: CGFloat = 6
		securityButton.contentEdgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
		containerView.addSubview(securityButton)

		urlField.frame = CGRect(x: 35, y: 0, width: 35, height: 35)
		urlField.autoresizingMask = .flexibleWidth
		urlField.textAlignment = .center
		urlField.textColor = .title
		urlField.keyboardType = .webSearch
		urlField.autocapitalizationType = .none
		urlField.keyboardAppearance = .dark
		urlField.autocorrectionType = .no
		urlField.tintColor = .button
		urlField.delegate = self
		if #available(iOS 10, *) {
			urlField.textContentType = .URL
		}
		UIFont.setSnowHazeFont(on: urlField)

		clipsToBounds = true

		if #available(iOS 11, *) {
			for interaction in urlField.interactions {
				if interaction is UIDragInteraction || interaction is UIDropInteraction {
					urlField.removeInteraction(interaction)
				}
			}

			dragInteraction = UIDragInteraction(delegate: self)
			dragInteraction!.isEnabled = true
			urlField.addInteraction(dragInteraction!)

			startEditingRecognizer = UITapGestureRecognizer()
			startEditingRecognizer?.addTarget(self, action: #selector(startEditing(_:)))
			startEditingRecognizer?.isEnabled = true
			urlField.addGestureRecognizer(startEditingRecognizer!)

			let dropInteraction = UIDropInteraction(delegate: self)
			dropInteraction.allowsSimultaneousDropSessions = false
			urlField.addInteraction(dropInteraction)
		}

		let flexibleTopWidth: UIView.AutoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		containerView.autoresizingMask = flexibleTopWidth
		containerView.addSubview(urlField)
		containerView.frame.origin.y = bounds.height - 45 - tabSelectionHeight + (showTabSelection ? tabSelectionShinkage : 0)
		containerView.frame.size.width = bounds.width - 24
		addSubview(containerView)
		loadBar.frame = CGRect(x: bounds.minX, y: bounds.maxY - loadBarHeight, width: bounds.width, height: loadBarHeight)
		loadBar.autoresizingMask = flexibleTopWidth
		tabSelectionView.frame = CGRect(x: bounds.minX, y: bounds.maxY - tabSelectionHeight, width: bounds.width, height: tabSelectionMaxHeight)
		tabSelectionView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		tabSelectionView.delegate = self
		addSubview(tabSelectionView)
		addSubview(loadBar)
		setupButtons()
		setupAccessibility()
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	@IBAction func prevButtonPressed(_ sender: AnyObject) {
		delegate?.prevButtonPressed(for: self)
	}

	@IBAction func nextButtonPressed(_ sender: AnyObject) {
		delegate?.nextButtonPressed(for: self)
	}

	@IBAction func shareButtonPressed(_ sender: NSObject) {
		delegate?.shareButtonPressed(for: self, sender: sender)
	}

	@objc private func plusButtonPressed(_ sender: AnyObject) {
		delegate?.plusButtonPressed(for: self)
	}

	@objc private func tabsButtonPressed(_ sender: AnyObject) {
		delegate?.tabsButtonPressed(for: self)
	}

	@objc private func settingsButtonPressed(_ sender: AnyObject) {
		delegate?.settingsButtonPressed(for: self)
	}

	@objc private func securityDetailButtonPressed(_ sender: AnyObject) {
		delegate?.securityDetailButtonPressed(for: self)
	}

	@objc private func reloadButtonPressed(_ sender: AnyObject) {
		delegate?.reloadButtonPressed(for: self)
		
		if reloadCounter.inc() {
			reloadCounter.reset()
			UIView.animate(withDuration: .pi / 16, delay: 0, options: .curveEaseIn, animations: {
				self.reloadButton.transform = CGAffineTransform(rotationAngle: CGFloat(2.0 * .pi / 3.0))
			}, completion: { (finished) -> Void in
				if finished {
					UIView.animate(withDuration: .pi / 16, delay: 0, options: .curveLinear, animations: {
						self.reloadButton.transform = CGAffineTransform(rotationAngle: CGFloat(2.0 * 2.0 * .pi / 3.0))
					}, completion: { (finished) -> Void in
						if finished {
							UIView.animate(withDuration: .pi / 16, delay: 0, options: .curveEaseOut, animations: {
								self.reloadButton.transform = CGAffineTransform(rotationAngle: 0)
							}, completion: nil)
						} else {
							self.reloadButton.transform = CGAffineTransform(rotationAngle: 0)
						}
					})
				} else {
					self.reloadButton.transform = CGAffineTransform(rotationAngle: 0)
				}
			})
		}
	}

	@objc private func cancelButtonPressed(_ sender: AnyObject) {
		if urlField.isFirstResponder {
			urlField.resignFirstResponder()
			stopInput()
		} else {
			delegate?.cancelLoad(for: self)
		}
	}

	@objc private func startEditing(_ sender: UITapGestureRecognizer) {
		urlField.becomeFirstResponder()
	}

	private func updateTabSelectionView() {
		containerView.frame.origin.y = bounds.height - 45 - tabSelectionHeight + (showTabSelection ? tabSelectionShinkage : 0)
		tabSelectionView.frame.origin.y = bounds.maxY - tabSelectionHeight

		prevButton.frame.origin.y = containerView.frame.origin.y - 5
		nextButton.frame.origin.y = containerView.frame.origin.y - 5
		shareButton.frame.origin.y = containerView.frame.origin.y - 5
		plusButton.frame.origin.y = containerView.frame.origin.y - 5
		tabsButton.frame.origin.y = containerView.frame.origin.y - 5
		settingsButton.frame.origin.y = containerView.frame.origin.y - 5
	}
}


// MARK: public
extension URLBar {
	func representingViewForTab(at index: Int, isCurrent: Bool) -> UIView? {
		if showTabSelection, let view = tabSelectionView.representingViewForTab(at: index) {
			return view
		}
		if isCurrent {
			return urlField
		}
		return nil
	}

	func suggestionViewOrigin(in view: UIView) -> CGFloat {
		let x = urlField.frame.maxX
		let y = urlField.frame.maxY
		let targetHeight = intrinsicContentSize.height
		let finalY = y + targetHeight - bounds.height
		return view.convert(CGPoint(x: x, y: finalY), from: urlField.superview).y
	}

	func minLowerBound(in view: UIView) -> CGFloat {
		var rect = bounds
		let adjust = bounds.size.height - height(for: 0)
		rect.size.height -= adjust
		return convert(rect, to: view).maxY
	}
}

// MARK: Text Field Delegate
extension URLBar: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let result = textField.text ?? ""
		stopInput()
		delegate?.urlbar(self, selectedInput: result)
		return true
	}

	func textFieldDidBeginEditing(_ textField: UITextField) {
		textField.attributedText = NSAttributedString(string: url?.absoluteString ?? "")
		if #available(iOS 11, *) {
			dragInteraction?.isEnabled = false
		}
		textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
		if #available(iOS 13, *) {
			UIMenuController.shared.showMenu(from: self, rect: textField.convert(textField.bounds, to: self))
		} else {
			UIMenuController.shared.setMenuVisible(true, animated: true)
		}
		delegate?.inputStringUpdated(for: self, input: textField.text ?? "")
		startInput()
	}

	func textFieldDidEndEditing(_ textField: UITextField) {
		textField.attributedText = attributedTitle
		if #available(iOS 11, *) {
			dragInteraction?.isEnabled = true
		}
		delegate?.inputEnded(for: self)
		stopInput()
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let oldText = textField.text ?? ""
		let newString = (oldText as NSString).replacingCharacters(in: range, with: string)
		delegate?.inputStringUpdated(for: self, input: newString)
		return true
	}
}

extension URLBar: TabSelectionViewDelegate {
	func tabSelectionView(_: TabSelectionView, didSelectTab tab: Int) {
		delegate?.urlbar(self, selectedTab: tab)
	}

	func tabSelectionView(_: TabSelectionView, didCloseTab tab: Int) {
		delegate?.urlbar(self, closedTab: tab)
	}

	func tabSelectionView(_: TabSelectionView, didLoadURL url: URL, atIndex tab: Int) {
		delegate?.urlbar(self, loadedURL: url, atIndex: tab)
	}
}

@available(iOS 11, *)
extension URLBar: UIDragInteractionDelegate {
	func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
		if let url = url {
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			let sanitizedTitle = Tab.sanitize(title: attributedTitle?.string)
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

// internals
private extension URLBar {
	func layoutContentView() {
		let margin: CGFloat
		if #available(iOS 11, *) {
			margin = max(safeAreaInsets.left, safeAreaInsets.right) + (constrainedWidth ? 12 : 180)
		} else {
			margin = constrainedWidth ? 12 : 180
		}
		containerView.frame.origin.x = margin
		containerView.frame.size.width = bounds.width - 2 * margin
	}

	func height(for scale: CGFloat) -> CGFloat {
		let height: CGFloat
		let scalableHeight: CGFloat = (constrainedHeight ? 56 : 68 - 20) - loadBarHeight
		let scaledHeight = scalableHeight * scale
		if #available(iOS 11, *) {
			height = scaledHeight + loadBarHeight
		} else {
			height = (constrainedHeight ? scaledHeight : scaledHeight + 20) + loadBarHeight
		}
		return height + 45 + tabSelectionHeight - (showTabSelection ? tabSelectionShinkage : 0)
	}
}

@available(iOS 11, *)
extension URLBar: UIDropInteractionDelegate {
	func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
		return 	(session.canLoadObjects(ofClass: String.self) || session.canLoadObjects(ofClass: URL.self))
				&& session.items.count == 1
	}

	func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
		let location = session.location(in: urlField)
		if urlField.bounds.contains(location) {
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
					self?.didDrop(urls[0].absoluteString)
				}
			}
		} else if session.canLoadObjects(ofClass: String.self) {
			let _ = session.loadObjects(ofClass: String.self) { [weak self] strings in
				assert(strings.count == 1)
				DispatchQueue.main.async {
					self?.didDrop(strings[0])
				}
			}
		}
	}

	private func didDrop(_ text: String) {
		stopInput()
		delegate?.urlbar(self, selectedInput: text)
	}
}
