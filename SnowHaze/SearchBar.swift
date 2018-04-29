//
//	SearchBar.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

protocol SearchBarDelegate: TextInputBarDelegate {
	func searchBarSelectNext(_ bar: SearchBar)
	func searchBarSelectPrevious(_ bar: SearchBar)
}

class SearchBar: TextInputBar {
	override var intrinsicContentSize : CGSize {
		return CGSize(width: UIViewNoIntrinsicMetric, height: 45)
	}

	var search: Search!

	weak var searchBarDelegate: SearchBarDelegate?

	private let nextButton = UIButton()
	private let prevButton = UIButton()
	private let offsetLabel = UILabel()

	var activity: UIActivity?

	var offsetText: String {
		set {
			offsetLabel.text = newValue
		}
		get {
			return offsetLabel.text ?? ""
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		prevButton.frame = CGRect(x: frame.minX		, y: frame.minY, width: 40, height: frame.height)
		nextButton.frame = CGRect(x: frame.minX + 40, y: frame.minY, width: 40, height: frame.height)
		offsetLabel.frame = CGRect(x: 0				, y: frame.minY, width: 40, height: frame.height)
		offsetLabel.font = UIFont.snowHazeFont(size: 15)
		offsetLabel.textAlignment = .center
		prevButton.autoresizingMask = .flexibleRightMargin
		nextButton.autoresizingMask = .flexibleRightMargin
		prevButton.setImage(#imageLiteral(resourceName: "previous"), for: [])
		nextButton.setImage(#imageLiteral(resourceName: "next"), for: [])

		offsetLabel.textColor = .subtitle
		offsetLabel.numberOfLines = 2

		nextButton.addTarget(self, action: #selector(selectNext(_:)), for: .touchUpInside)
		prevButton.addTarget(self, action: #selector(selectPrevious(_:)), for: .touchUpInside)

		addSubview(prevButton)
		addSubview(nextButton)
		addSubview(offsetLabel)
	}

	convenience init() {
		self.init(frame: CGRect(x: 0, y: 0, width: 300, height: 45))
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let usableWidth: CGFloat
		let prevX: CGFloat
		if #available(iOS 11, *) {
			usableWidth = bounds.width - 2 * max(safeAreaInsets.left, safeAreaInsets.right)
			prevX = bounds.minX + safeAreaInsets.left
		} else {
			usableWidth = bounds.width
			prevX = bounds.minX
		}
		let width = min(usableWidth / 2, usableWidth - 160)
		let labelFraction: CGFloat = min(0.2, 100 / width)
		textField.frame.size.width = width * (1 - labelFraction)
		textField.frame.origin.x = bounds.midX - width / 2

		offsetLabel.frame.size.width = width * labelFraction
		offsetLabel.frame.origin.x = bounds.midX + width * (1 - labelFraction - 0.5)

		prevButton.frame = CGRect(x: prevX	   , y: bounds.minY, width: 40, height: bounds.height)
		nextButton.frame = CGRect(x: prevX + 40, y: bounds.minY, width: 40, height: bounds.height)
	}

	@objc private func selectNext(_ sender: UIButton) {
		delegate?.searchBarSelectNext(self)
	}

	@objc private func selectPrevious(_ sender: UIButton) {
		delegate?.searchBarSelectPrevious(self)
	}
}
