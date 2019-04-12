//
//  StatsView.swift
//  SnowHaze
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

protocol StatsViewDelegate: class {
	func numerOfStats(in statsView: StatsView) -> Int
	func titleOfStat(_ index: Int, in statsView: StatsView) -> String
	func countForStat(_ index: Int, in statsView: StatsView) -> Int
	func colorForStat(_ index: Int, in statsView: StatsView) -> UIColor
	func dimmStat(_ index: Int, in statsView: StatsView) -> Bool
	func statTapped(at index: Int, in statsView: StatsView)
}

class StatsView: UICollectionReusableView {
	private let stackView = UIStackView()

	weak var delegate: StatsViewDelegate? {
		didSet {
			reload()
		}
	}

	private func setup() {
		stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		stackView.frame = bounds
		stackView.axis = .horizontal
		stackView.spacing = 5
		stackView.distribution = .fillEqually
		addSubview(stackView)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	private func fmt(_ i: Int) -> String {
		if i >= 100_000_000 {
			return "\(i / 1_000_000_000).\((i % 1_000_000_000) / 100_000_000)G"
		} else if i >= 10_000_000 {
			return "\(i / 1_000_000)M"
		} else if i >= 100_000 {
			return "\(i / 1_000_000).\((i % 1_000_000) / 100_000)M"
		} else if i >= 10_000 {
			return "\(i / 1_000)k"
		} else if i >= 1_000 {
			return "\(i / 1_000).\((i % 1_000) / 100)k"
		} else {
			return "\(i)"
		}
	}

	func reload() {
		for view in stackView.arrangedSubviews {
			stackView.removeArrangedSubview(view)
		}
		guard let delegate = delegate else {
			return
		}
		let statsCount = delegate.numerOfStats(in: self)
		assert(statsCount >= 0)
		for i in 0 ..< statsCount {
			let dimmed = delegate.dimmStat(i, in: self)
			let container = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 85))
			let number = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 55))
			let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(statsViewTapped(_:)))
			container.addGestureRecognizer(tapRecognizer)

			number.textAlignment = .center
			number.autoresizingMask = .flexibleWidth
			number.textColor = dimmed ? .darkTitle : delegate.colorForStat(i, in: self)
			number.adjustsFontSizeToFitWidth = true
			UIFont.setSnowHazeFont(on: number, scale: 2)
			number.text = fmt(delegate.countForStat(i, in: self))

			let category = UILabel(frame: CGRect(x: 0, y: 55, width: 100, height: 30))
			category.textAlignment = .center
			category.autoresizingMask = .flexibleWidth
			category.numberOfLines = 2
			UIFont.setSnowHazeFont(on: category, scale: 0.6)
			category.textColor = dimmed ? .darkTitle : .title
			category.text = delegate.titleOfStat(i, in: self)

			container.addSubview(number)
			container.addSubview(category)
			stackView.addArrangedSubview(container)
		}
	}

	@objc private func statsViewTapped(_ sender: UITapGestureRecognizer) {
		guard let view = sender.view, let index = stackView.arrangedSubviews.firstIndex(of: view) else {
			return
		}
		delegate?.statTapped(at: index, in: self)
	}
}
