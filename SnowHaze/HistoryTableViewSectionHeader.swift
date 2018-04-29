//
//	HistoryTableViewSectionHeader.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

protocol HistoryTableViewSectionHeaderDelegate: class {
	func historySectionHeader(_ header: HistoryTableViewSectionHeader, commitDeletionOfSection section: Int)
}

class HistoryTableViewSectionHeader: UIView {
	private let deleteButton = UIButton()
	private var tapRecognizer: UITapGestureRecognizer!
	private let titleLabel = UILabel()
	private let animationDuration = 0.3
	private var confirmMode = false

	weak var delegate: HistoryTableViewSectionHeaderDelegate?
	var section = -1

	var title: String? {
		get {
			return titleLabel.text
		}
		set {
			titleLabel.text = newValue
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		let flexibleSize: UIViewAutoresizing = [.flexibleHeight, .flexibleWidth]

		tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(deleteButtonMissed(_:)))
		tapRecognizer.delegate = self

		let backgroudView = UIView()
		backgroudView.frame = bounds
		backgroudView.backgroundColor = .bar
		backgroudView.autoresizingMask = flexibleSize
		addSubview(backgroudView)

		titleLabel.frame = bounds
		let startOffset: CGFloat = 61
		titleLabel.frame.size.width -= 100 + startOffset
		titleLabel.frame.origin.x += startOffset
		titleLabel.autoresizingMask = flexibleSize
		titleLabel.textColor = .title
		UIFont.setSnowHazeFont(on: titleLabel)
		addSubview(titleLabel)

		deleteButton.addTarget(self, action: #selector(deleteButtonTaped(_:)), for: .touchUpInside)
		deleteButton.backgroundColor = UIColor(white: 1, alpha: 0.3)
		deleteButton.setTitleColor(.title, for: [])
		let inset: CGFloat = 5
		deleteButton.contentEdgeInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
		UIFont.setSnowHazeFont(on: deleteButton)
		deleteButton.tintColor = .title
		deleteButton.clipsToBounds = true
		deleteButton.layer.cornerRadius = 10
		let originalClose = #imageLiteral(resourceName: "close")
		let close = originalClose.withRenderingMode(.alwaysTemplate)
		deleteButton.setImage(close, for: [])
		deleteButton.accessibilityLabel = NSLocalizedString("delete history day button accessibility label", comment: "accessibility label of button to delete a day from history when in regular mode")
		deleteButton.frame = frameForDeleteButton(false)
		deleteButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
		addSubview(deleteButton)
	}

	private func frameForDeleteButton(_ confirmMode: Bool) -> CGRect {
		let title = NSLocalizedString("delete history section button title", comment: "title of button to delete all history section of a day")
		let font = deleteButton.titleLabel!.font!
		let size = title.size(withAttributes: [NSAttributedStringKey.font: font])

		let width: CGFloat = confirmMode ? size.width + 15 : 20
		return CGRect(x: bounds.width - 10 - width, y: 5, width: width, height: 20)
	}

	private func enterConfirmMode() {
		let title = NSLocalizedString("delete history section button title", comment: "title of button to delete all history section of a day")
		window?.addGestureRecognizer(tapRecognizer)
		UIView.animate(withDuration: animationDuration, animations: {
			self.deleteButton.frame = self.frameForDeleteButton(true)
			self.deleteButton.setImage(nil, for: [])
			self.deleteButton.setTitle(title, for: [])
			self.deleteButton.accessibilityLabel = NSLocalizedString("delete history day button confirm accessibility label", comment: "accessibility label of button to delete a day from history when in confirm mode")
			self.confirmMode = true
		})
	}

	private func exitConfirmMode() {
		window?.removeGestureRecognizer(tapRecognizer)
		UIView.animate(withDuration: animationDuration, animations: {
			self.deleteButton.frame = self.frameForDeleteButton(false)
			let originalClose = #imageLiteral(resourceName: "close")
			let close = originalClose.withRenderingMode(.alwaysTemplate)
			self.deleteButton.setImage(close, for: [])
			self.deleteButton.accessibilityLabel = NSLocalizedString("delete history day button accessibility label", comment: "accessibility label of button to delete a day from history when in regular mode")
			self.deleteButton.setTitle("", for: [])
			self.confirmMode = false
		})
	}

	@objc private func deleteButtonTaped(_ sender: UIButton) {
		if confirmMode {
			window?.removeGestureRecognizer(tapRecognizer)
			delegate?.historySectionHeader(self, commitDeletionOfSection: section)
		} else {
			enterConfirmMode()
		}
	}

	@objc private func deleteButtonMissed(_ sender: AnyObject) {
		if confirmMode {
			exitConfirmMode()
		}
	}

	convenience init(title: String?, section: Int, delegate: HistoryTableViewSectionHeaderDelegate) {
		self.init(frame: CGRect(x: 0, y: 0, width: 300, height: 30))
		self.title = title
		self.section = section
		self.delegate = delegate
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		window?.removeGestureRecognizer(tapRecognizer)
	}
}

extension HistoryTableViewSectionHeader: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		return !deleteButton.frame.contains(touch.location(in: self))
	}
}
