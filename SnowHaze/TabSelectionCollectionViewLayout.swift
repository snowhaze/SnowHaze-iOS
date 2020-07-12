//
//  TabSelectionCollectionViewLayout.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

class TabSelectionCollectionViewLayout: UICollectionViewLayout {
	private let rotationAngle: CGFloat = -0.3
	private let absCellSpacing: CGFloat = 80
	private let relCellSpacing: CGFloat = -0.5
	private let absTopMargin: CGFloat = 20
	private let relTopMargin: CGFloat = 0.05
	private let absBottomMargin: CGFloat = 0
	private let relBottomMargin: CGFloat = 0.15
	private let heightWidthRatio: CGFloat = 2.0 / 3.0

	private var colCount: Int {
		return Int(width) / 550 + 1
	}

	private var rowCount: Int {
		return (itemCount + colCount - 1) / colCount
	}

	private var itemCount: Int {
		return collectionView!.numberOfItems(inSection: 0)
	}

	private var width: CGFloat {
		return insetBounds.size.width
	}

	private var colWidth: CGFloat {
		return width / CGFloat(colCount)
	}

	private var insetBounds: CGRect {
		var rect = collectionView!.bounds
		rect.origin.x += collectionView!.contentInset.left
		rect.size.width -= collectionView!.contentInset.left
		rect.size.width -= collectionView!.contentInset.right

		rect.origin.y += collectionView!.contentInset.top
		rect.size.height -= collectionView!.contentInset.top
		rect.size.height -= collectionView!.contentInset.bottom

		return rect
	}

	override var collectionViewContentSize : CGSize {
		let elementWidth = (colWidth - 320) * 0.75 + 300
		let elementHeight = heightWidthRatio * elementWidth
		let cellSpacing = relCellSpacing * elementHeight + absCellSpacing
		let topMargin = relTopMargin * elementHeight + absTopMargin
		let bottomMargin = relBottomMargin * elementHeight + absBottomMargin
		let minHeight = topMargin + CGFloat(rowCount) * (elementHeight + cellSpacing) + bottomMargin
		let height = max(minHeight, insetBounds.size.height)
		return CGSize(width: width, height: height)
	}

	override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
		return true
	}

	override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
		var allAttributes = [UICollectionViewLayoutAttributes]()
		for i in 0 ..< collectionView!.numberOfItems(inSection: 0) {
			let indexPath = IndexPath(row: i, section: 0)
			let attributes = layoutAttributesForItem(at: indexPath)!
			allAttributes.append(attributes)
		}
		return allAttributes
	}

	override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
		let row = indexPath.row
		let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
		let height = insetBounds.size.height
		let elementWidth = (colWidth - 320) * 0.75 + 300
		let elementHeight = heightWidthRatio * elementWidth
		let topMargin = relTopMargin * elementHeight + absTopMargin
		let cellSpacing = relCellSpacing * elementHeight + absCellSpacing
		let bottomMargin = relBottomMargin * elementHeight + absBottomMargin
		let requiredHeight = topMargin + CGFloat(rowCount) * (elementHeight + cellSpacing) + bottomMargin
		let xOffset = itemCount < colCount ? CGFloat(colCount - itemCount) * colWidth / 2 : 0
		let yOffset = height <= requiredHeight ? 0 : (height - requiredHeight) / 2
		let x = (colWidth - elementWidth) / 2 + CGFloat(row % colCount) * colWidth + xOffset
		let y = yOffset + (elementHeight + cellSpacing) * CGFloat(row / colCount) + topMargin
		let frame = CGRect(x: x, y: y, width: elementWidth, height: elementHeight)
		attributes.frame = frame
		var rotation = CATransform3DIdentity
		rotation.m34 = 1.0 / -850.0
		rotation = CATransform3DRotate(rotation, rotationAngle, 1, 0, 0)
		attributes.transform3D = rotation;
		attributes.isHidden = false
		attributes.zIndex = row
		return attributes
	}
}
