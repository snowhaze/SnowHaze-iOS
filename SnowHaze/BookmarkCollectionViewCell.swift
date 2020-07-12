//
//  BookmarkCollectionViewCell.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

protocol BookmarkCollectionViewCellDelegate: class {
	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestDeleteBookmark bookmark: Bookmark)
	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestRefreshBookmark bookmark: Bookmark)
	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestRenameBookmark bookmark: Bookmark)
}

class BookmarkCollectionViewCell: UICollectionViewCell {
	private let animationDuration = 0.3
	private let dimmedFaviconAlpha: CGFloat = 0.1
	var previewRegistered = false

	weak var delegate: BookmarkCollectionViewCellDelegate?

	var faviconView: UIImageView!
	var faviconBorderView: UIImageView!
	var titleLabel: UILabel!
	var deleteButton: UIButton!
	var refreshButton: UIButton!
	var renameButton: UIButton!
	var pressRecognizer: UILongPressGestureRecognizer!
	var tapRecognizer: UITapGestureRecognizer!
	var windowTapRecognizer: UITapGestureRecognizer!

	var inEditMode = false

	override func prepareForReuse() {
		deleteButton?.isHidden = true
		refreshButton?.isHidden = true
		renameButton?.isHidden = true
		faviconView?.alpha = 1
		faviconBorderView?.alpha = 1
		inEditMode = false
	}

	var bookmark: Bookmark! {
		willSet {
			if let _ = bookmark {
				NotificationCenter.default.removeObserver(self)
			}
		}
		didSet {
			guard let _ = bookmark else {
				return
			}
			NotificationCenter.default.addObserver(self, selector: #selector(bookmarkDidChange(_:)), name: BOOKMARK_CHANGED_NOTIFICATION, object: BookmarkStore.store)
			refreshView()
		}
	}

	private func border(with size: CGSize) -> UIImage {
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		let lineWidth: CGFloat = 2
		let lineOffset: CGFloat = 0.5
		let context = UIGraphicsGetCurrentContext()!
		context.setLineDash(phase: 0, lengths: [0, 8])
		context.setLineCap(CGLineCap.round)
		context.setStrokeColor(UIColor.title.cgColor)
		context.setLineWidth(lineWidth)
		let outerRect = CGRect(origin: CGPoint.zero, size: size)
		let rect = outerRect.insetBy(dx: lineWidth / 2 + lineOffset, dy: lineWidth / 2 + lineOffset)
		context.strokeEllipse(in: rect)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image!
	}

	private func refreshView() {
		if faviconBorderView == nil {
			let size = CGSize(width: 100, height: 100)
			let border = self.border(with: size)
			faviconBorderView = UIImageView(image: border)
			faviconBorderView.frame = CGRect(origin: CGPoint.zero, size: size)
			contentView.addSubview(faviconBorderView)
		}
		if faviconView == nil {
			faviconView = UIImageView(image: nil)
			faviconView.frame = faviconBorderView.frame
			faviconView.clipsToBounds = true
			faviconView.layer.cornerRadius = 50
			contentView.addSubview(faviconView)
		}
		if titleLabel == nil {
			titleLabel = UILabel(frame: CGRect(x: 0, y: 110, width: 100, height: 50))
			titleLabel.textColor = .title
			titleLabel.numberOfLines = 2
			titleLabel.textAlignment = .center
			contentView.addSubview(titleLabel)
		}
		if deleteButton == nil {
			deleteButton = UIButton()
			let deleteButtonTitle = NSLocalizedString("delete bookmark button title", comment: "title of button to delete bookmark in bookmark view")
			deleteButton.setTitle(deleteButtonTitle, for: [])
			deleteButton.frame = CGRect(x: 0, y: 0, width: 100, height: 33)
			deleteButton.addTarget(self, action: #selector(deleteBookmark(_:)), for: .touchUpInside)
			deleteButton.isHidden = true
			contentView.addSubview(deleteButton)
		}
		if refreshButton == nil {
			refreshButton = UIButton()
			let refreshButtonTitle = NSLocalizedString("refresh bookmark button title", comment: "title of button to refresh bookmark in bookmark view")
			refreshButton.setTitle(refreshButtonTitle, for: [])
			refreshButton.frame = CGRect(x: 0, y: 33, width: 100, height: 33)
			refreshButton.addTarget(self, action: #selector(refreshBookmark(_:)), for: .touchUpInside)
			refreshButton.isHidden = true
			contentView.addSubview(refreshButton)
		}
		if renameButton == nil {
			renameButton = UIButton()
			let cancelButtonTitle = NSLocalizedString("rename bookmark button title", comment: "title of button to rename bookmark in bookmark view")
			renameButton.setTitle(cancelButtonTitle, for: [])
			renameButton.frame = CGRect(x: 0, y: 66, width: 100, height: 34)
			renameButton.addTarget(self, action: #selector(renameBookmark(_:)), for: .touchUpInside)
			renameButton.isHidden = true
			renameButton.titleLabel?.adjustsFontSizeToFitWidth = true
			contentView.addSubview(renameButton)
		}
		if pressRecognizer == nil {
			pressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(toggleEditMode(_:)))
			addGestureRecognizer(pressRecognizer)
		}
		if tapRecognizer == nil {
			tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleEditMode(_:)))
			tapRecognizer.isEnabled = false
			addGestureRecognizer(tapRecognizer)
		}
		if windowTapRecognizer == nil {
			windowTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleEditMode(_:)))
			windowTapRecognizer.isEnabled = false
			windowTapRecognizer.delegate = self
		}
		faviconView.image = bookmark.displayIcon
		titleLabel.text = bookmark.displayName
	}

	func enterEditMode() {
		inEditMode = true
		tapRecognizer.isEnabled = true
		deleteButton.alpha = 0
		refreshButton.alpha = 0
		renameButton.alpha = 0
		deleteButton.isHidden = false
		refreshButton.isHidden = false
		renameButton.isHidden = false
		window?.addGestureRecognizer(windowTapRecognizer)
		windowTapRecognizer.isEnabled = true
		UIView.animate(withDuration: animationDuration, animations: {
			self.deleteButton.alpha = 1
			self.refreshButton.alpha = 1
			self.renameButton.alpha = 1
			self.faviconView.alpha = self.dimmedFaviconAlpha
			self.faviconBorderView.alpha = self.dimmedFaviconAlpha
		})
	}

	func exitEditMode() {
		inEditMode = false
		tapRecognizer.isEnabled = false
		deleteButton.isHidden = false
		refreshButton.isHidden = false
		renameButton.isHidden = false
		window?.removeGestureRecognizer(windowTapRecognizer)
		windowTapRecognizer.isEnabled = false
		UIView.animate(withDuration: animationDuration, animations: {
			self.deleteButton.alpha = 0
			self.refreshButton.alpha = 0
			self.renameButton.alpha = 0
			self.faviconView.alpha = 1
			self.faviconBorderView.alpha = 1
		}, completion: { _ in
			self.deleteButton.isHidden = true
			self.refreshButton.isHidden = true
			self.renameButton.isHidden = true
		})
	}

	@objc private func toggleEditMode(_ sender: UIGestureRecognizer) {
		if sender == pressRecognizer && sender.state != .began {
			return
		}
		if inEditMode {
			exitEditMode()
		} else {
			enterEditMode()
		}
	}

	@objc private func deleteBookmark(_ sender: UIButton) {
		if let bookmark = bookmark {
			delegate?.bookmarkCell(self, didRequestDeleteBookmark: bookmark)
		}
	}

	@objc private func renameBookmark(_ sender: UIButton) {
		if let bookmark = bookmark {
			delegate?.bookmarkCell(self, didRequestRenameBookmark: bookmark)
		}
		exitEditMode()
	}

	@objc private func refreshBookmark(_ sender: UIButton) {
		if let bookmark = bookmark {
			delegate?.bookmarkCell(self, didRequestRefreshBookmark: bookmark)
		}
		exitEditMode()
	}

	@objc private func bookmarkDidChange(_ notification: Notification) {
		let item = notification.userInfo?[BOOKMARK_KEY] as? Bookmark
		if item?.id != bookmark.id {
			return
		}
		faviconView.image = bookmark.displayIcon
		titleLabel.text = bookmark.displayName
	}

	deinit {
		window?.removeGestureRecognizer(tapRecognizer)
	}
}

extension BookmarkCollectionViewCell: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		let inBounds = bounds.contains(touch.location(in: self))
		if !inBounds && inEditMode {
			exitEditMode()
		}
		return false
	}
}
