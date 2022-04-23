//
//  TabCollectionViewCell.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

protocol TabCollectionViewCellDelegate: AnyObject {
	func closeTab(for tab: TabCollectionViewCell)
}

private let animationDuration = 0.3

class TabCollectionViewCell: UICollectionViewCell {
	static let barHeight: CGFloat = 35
	private let barHeight: CGFloat = TabCollectionViewCell.barHeight
	private var closeButton: UIButton!
	private var imageView: UIImageView!
	private var homeImageView: UIImageView!
	private var titleLabel: UILabel!
	private var registeredForNotifications = false
	private var secIconImageView: UIImageView!

	private var translation: CGFloat = 0
	private var closeGestureRecognizer: UIPanGestureRecognizer!

	private var dragDropRegistered = false

	weak var delegate: TabCollectionViewCellDelegate?

	private lazy var gradientLayer: CAGradientLayer = {
		let gradientLayer = CAGradientLayer()
		gradientLayer.colors = [UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor]
		gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
		gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.95)
		gradientLayer.contentsGravity = CALayerContentsGravity.resize
		gradientLayer.frame = self.contentView.layer.bounds
		return gradientLayer
	}()

	weak var tab: Tab? {
		didSet {
			refreshView()
		}
	}

	var isMasked = false {
		didSet {
			guard let tab = tab, oldValue != isMasked else {
				return
			}
			if isMasked {
				titleLabel.text = NSLocalizedString("masked tab title", comment: "displayed instead of title for masked tabs in app snapshots").localizedUppercase
				imageView.image = #imageLiteral(resourceName: "Background")
				homeImageView.image = #imageLiteral(resourceName: "masked").withRenderingMode(.alwaysTemplate)
				homeImageView.tintColor = .white
				homeImageView.isHidden = false
				layoutImageView()

				let policy = PolicyManager.globalManager()
				let wrapper = policy.settingsWrapper
				let assessment = PolicyAssessor(wrapper: wrapper).assess(PolicyAssessor.allCategories)
				let image = assessment.image.withRenderingMode(.alwaysTemplate)
				secIconImageView.image = image
				secIconImageView.tintColor = assessment.color
			} else {
				homeImageView.image = #imageLiteral(resourceName: "home")
				titleLabel.attributedText = tab.uppercaseFormatedDisplayTitle
				imageView.image = tab.snapshot ?? #imageLiteral(resourceName: "Background")
				if let _ = tab.snapshot {
					homeImageView.isHidden = true
				} else {
					homeImageView.isHidden = false
				}
				layoutImageView()
				updateSecAssessment()
			}
		}
	}

	func updateSecAssessment() {
		guard let assessment = tab?.controller?.securityAssessment else {
			return
		}
		let image = assessment.image.withRenderingMode(.alwaysTemplate)
		secIconImageView.image = image
		secIconImageView.tintColor = assessment.color
	}

	private func refreshView() {
		guard let tab = tab else {
			return
		}
		contentView.clipsToBounds = true
		contentView.layer.cornerRadius = 10
		contentView.alpha = 1
		contentView.frame.origin = CGPoint(x: 0, y: 0)
		translation = 0
		contentView.backgroundColor = .background
		let background = #imageLiteral(resourceName: "Background")
		let image = tab.snapshot ?? background
		if imageView == nil {
			imageView = UIImageView(image: image)
			imageView.contentMode = .scaleToFill
			contentView.addSubview(imageView)
		}
		if homeImageView == nil {
			homeImageView = UIImageView(image: #imageLiteral(resourceName: "home"))
			homeImageView.contentMode = .scaleAspectFit
			contentView.addSubview(homeImageView)
		}
		if secIconImageView == nil {
			secIconImageView = UIImageView()
			let width = contentView.bounds.width
			secIconImageView.frame = CGRect(x: width - barHeight * 0.8, y: barHeight * 0.2, width: barHeight * 0.6, height: barHeight * 0.6)
			secIconImageView.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
			secIconImageView.contentMode = .scaleAspectFit
			contentView.addSubview(secIconImageView)
		}
		if closeButton == nil {
			closeButton = UIButton()
			closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
			closeButton.setTitleColor(.button, for: [])
			let originalClose = #imageLiteral(resourceName: "close")
			let close = originalClose.withRenderingMode(.alwaysTemplate)
			closeButton.setImage(close, for: [])
			closeButton.tintColor = .button
			let insets = barHeight * 0.3
			closeButton.contentEdgeInsets = UIEdgeInsets(top: insets, left: insets, bottom: insets, right: insets)
			closeButton.frame = CGRect(x: 0, y: 0, width: barHeight, height: barHeight)
			closeButton.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
			closeButton.accessibilityLabel = NSLocalizedString("close tab button accessibility label", comment: "accessibility label for button to close a tab")
			contentView.addSubview(closeButton)
		}
		if titleLabel == nil {
			titleLabel = UILabel()
			let width = contentView.bounds.width
			titleLabel.frame = CGRect(x: barHeight, y: 0, width: width - 2 * barHeight, height: barHeight)
			titleLabel.textColor = .button
			titleLabel.textAlignment = .center
			titleLabel.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
			contentView.addSubview(titleLabel)
		}
		if closeGestureRecognizer == nil {
			closeGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panClosing(_:)))
			closeGestureRecognizer.delegate = self
			addGestureRecognizer(closeGestureRecognizer)
		}
		if contentView.layer.mask == nil {
			contentView.layer.mask = gradientLayer
		}
		if !dragDropRegistered {
			dragDropRegistered = true

			let dragInteraction = UIDragInteraction(delegate: self)
			dragInteraction.isEnabled = true
			addInteraction(dragInteraction)

			let dropInteraction = UIDropInteraction(delegate: self)
			dropInteraction.allowsSimultaneousDropSessions = false
			addInteraction(dropInteraction)
		}
		if !registeredForNotifications {
			registeredForNotifications = true
			NotificationCenter.default.addObserver(self, selector: #selector(tabDidChange(_:)), name: TAB_CHANGED_NOTIFICATION, object: TabStore.store)
		}
		titleLabel.attributedText = tab.uppercaseFormatedDisplayTitle
		imageView.image = image
		updateSecAssessment()
		if let _ = tab.snapshot {
			homeImageView.isHidden = true
		} else {
			homeImageView.isHidden = false
		}
		layoutImageView()
	}

	@objc private func close(_ sender: AnyObject) {
		delegate?.closeTab(for: self)
	}

	func swipeClose(_ sender: AnyObject) {
		UIView.animate(withDuration: animationDuration, animations: {
			self.contentView.center.x -= self.contentView.frame.width
		})
		delegate?.closeTab(for: self)
	}

	@objc private func panClosing(_ sender: UIPanGestureRecognizer) {
		let viewTranslation = sender.translation(in: self)
		translation -= viewTranslation.x / bounds.width
		translation = max(translation, 0)
		translation = min(translation, 1)
		contentView.frame.origin.x = -translation * bounds.width
		contentView.alpha = 1 - translation
		sender.setTranslation(CGPoint.zero, in: self)
		let xVelocity = sender.velocity(in: self).x
		switch sender.state {
			case .cancelled, .failed, .ended:
				var delete = false
				if translation > 0.8 {
					delete = true
				}
				if translation > 0.6 && xVelocity <=
					0 {
					delete = true
				}
				if translation > 0.3 && xVelocity < -5 {
					delete = true
				}
				if delete {
					UIView.animate(withDuration: animationDuration, animations: {
						self.contentView.frame.origin.x = -self.bounds.width
						self.contentView.alpha = 0
					})
					delegate?.closeTab(for: self)
				} else {
					translation = 0
					UIView.animate(withDuration: animationDuration, animations: {
						self.contentView.frame.origin.x = 0
						self.contentView.alpha = 1
					})
				}
			default:
				break
		}
	}

	private func layoutImageView() {
		guard let imageSize = imageView.image?.size else {
			return
		}
		let imageRatio = imageSize.height / imageSize.width
		let ratio = (bounds.height - barHeight) / bounds.width
		let width: CGFloat
		let height: CGFloat
		if ratio < imageRatio {
			width = bounds.width
			height = width * imageRatio
		} else if imageRatio.isNaN {
			height = (bounds.height - barHeight)
			width = 0
		} else {
			height = (bounds.height - barHeight)
			width = height / imageRatio
		}
		imageView.frame = CGRect(x: bounds.minX + (bounds.width - width) / 2, y: barHeight, width: width, height: height)
		let margin: CGFloat = 0.2
		homeImageView.frame = bounds
		homeImageView.frame.origin.y += barHeight + homeImageView.frame.size.height * margin
		homeImageView.frame.size.height -= barHeight + homeImageView.frame.size.height * margin * 2
		homeImageView.frame.origin.x += homeImageView.frame.size.width * margin
		homeImageView.frame.size.width -= homeImageView.frame.size.width * margin * 2
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		gradientLayer.frame = contentView.layer.bounds
		contentView.frame.origin.x = -translation * bounds.width
		layoutImageView()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

extension TabCollectionViewCell: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
}

//Notifications
extension TabCollectionViewCell {
	@objc private func tabDidChange(_ notification: Notification) {
		if let tab = tab , notification.userInfo?[TAB_KEY] as? Tab == tab {
			imageView.image = tab.snapshot ?? #imageLiteral(resourceName: "Background")
			if let _ = tab.snapshot {
				homeImageView.isHidden = true
			} else {
				homeImageView.isHidden = false
			}
			layoutImageView()
			titleLabel.attributedText = tab.uppercaseFormatedDisplayTitle
			updateSecAssessment()
		}
	}
}

extension TabCollectionViewCell: UIDragInteractionDelegate {
	func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
		if let url = tab?.displayURL {
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			let plainTitle = tab?.title
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

extension TabCollectionViewCell: UIDropInteractionDelegate{
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
				let tab = self?.tab
				DispatchQueue.main.async { [weak tab] in
					tab?.controller?.load(url: urls[0])
				}
			}
		}
	}
}
