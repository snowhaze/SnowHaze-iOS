//
//  HistoryTableViewCell.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class HistoryTableViewCell: UITableViewCell {
	private let timeFormatter: DateFormatter = DateFormatter()
	var previewRegistered = false
	private var dragRegistered = false

	var historyItem: HistoryItem? {
		didSet {
			guard let historyItem = historyItem else {
				return
			}
			textLabel?.text = historyItem.title
			detailTextLabel?.text = historyItem.url.absoluteString
			let time = timeFormatter.string(from: historyItem.timestamp as Date)
			imageView?.image = image(from: time)
			if #available(iOS 11, *) {
				if !dragRegistered {
					dragRegistered = true

					let dragInteraction = UIDragInteraction(delegate: self)
					dragInteraction.isEnabled = true
					addInteraction(dragInteraction)
				}
			}
		}
	}

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
		timeFormatter.dateStyle = .none
		timeFormatter.timeStyle = .short
		backgroundColor = UIColor(white: 1, alpha: 0.05)
		textLabel?.textColor = .title
		detailTextLabel?.textColor = .subtitle
		UIFont.setSnowHazeFont(on: textLabel!)
		UIFont.setSnowHazeFont(on: detailTextLabel!)
		separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		selectedBackgroundView = UIView()
		selectedBackgroundView?.backgroundColor = UIColor(white: 1, alpha: 0.2)
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	private func image(from string: String) -> UIImage {
		let attributes = [NSAttributedString.Key.foregroundColor: UIColor.title, NSAttributedString.Key.font: UIFont.snowHazeFont(size: 12)]
		let size = string.size(withAttributes: attributes)
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		string.draw(at: CGPoint.zero, withAttributes: attributes)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image!
	}
}

@available(iOS 11, *)
extension HistoryTableViewCell: UIDragInteractionDelegate {
	func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
		if let url = historyItem?.url {
			let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
			let sanitizedTitle = Tab.sanitize(title: historyItem?.title)
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
