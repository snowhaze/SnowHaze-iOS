//
//  PageInfoDetailsList.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

class PageInfoDetailsList: UIView {
	enum Entry {
		case data(String, String)
		case title(String)
	}

	private let scrollView = UIScrollView()
	private let activity = UIActivityIndicatorView()
	private let error = UILabel()

	private static let formatter = ISO8601DateFormatter()

	private var plain = true

	private func code(plain: String) -> String {
		guard !self.plain else {
			return plain
		}
		func replace(_ char: Character) -> [String] {
			switch char {
				case "A":	return ["4", "@"]
				case "B":	return ["8"]
				case "C":	return ["¢", "©"]
				case "D":	return ["D", "d", "|)", "c|"]
				case "E":	return ["3", "€"]
				case "F":	return ["ƒ"]
				case "G":	return ["G", "g", "6"]
				case "H":	return ["|-|", "H", "h", "]-["]
				case "I":	return ["!", "1", "¡"]
				case "J":	return [";", "j"]
				case "K":	return ["|<"]
				case "L":	return ["I_", "£"]
				case "M":	return ["nn", "|V|"]
				case "N":	return ["И", "ท"]
				case "O":	return ["0", "Ø"]
				case "P":	return ["|º", "P"]
				case "Q":	return ["Q", "q"]
				case "R":	return ["®", "Я"]
				case "S":	return ["$", "5", "§"]
				case "T":	return ["7", "†", "+"]
				case "U":	return ["µ", "บ"]
				case "V":	return ["v", "\\/"]
				case "W":	return ["Ш", "Щ", "พ"]
				case "X":	return ["×", "?"]
				case "Y":	return ["¥", "Ч"]
				case "Z":	return ["2", "%"]
				default:	return [String(char)]
			}
		}
		return plain.uppercased().map({ replace($0).randomElement }).joined()
	}

	func format(_ date: Date) -> String {
		return PageInfoDetailsList.formatter.string(from: date)
	}

	enum State {
		case loading
		case error(String)
		case data([Entry])
	}
	private(set) var state = State.loading

	func set(state: State, animated: Bool) {
		precondition(Thread.isMainThread)
		func change(_ change: @escaping () -> (), completion: @escaping () -> ()) {
			if animated {
				UIView.animate(withDuration: 0.2, animations: change) { _ in completion() }
			} else {
				change()
				completion()
			}
		}
		let oldState = self.state
		self.state = state
		switch (oldState, state) {
			case (.loading, .loading):
				break
			case (.error(_), .error(let error)):
				self.error.text = error
			case (.data(_), .data(_)):
				layout()
			case (_, .loading):
				self.activity.isHidden = false
				self.activity.alpha = 0
				change({
					self.activity.alpha = 1
					self.error.alpha = 0
					self.scrollView.alpha = 0
				}) {
					self.error.isHidden = true
					self.scrollView.isHidden = true
				}
			case (_, .error(let error)):
				self.error.isHidden = false
				self.error.alpha = 0
				self.error.text = error
				change({
					self.error.alpha = 1
					self.activity.alpha = 0
					self.scrollView.alpha = 0
				}) {
					self.activity.isHidden = true
					self.scrollView.isHidden = true
				}
			case (_, .data(_)):
				layout()
				self.scrollView.isHidden = false
				self.scrollView.alpha = 0
				change({
					self.scrollView.alpha = 1
					self.activity.alpha = 0
					self.error.alpha = 0
				}) {
					self.activity.isHidden = true
					self.error.isHidden = true
				}

		}
	}

	private class Cell: UIView {
		init(title: String, data: String?, width: CGFloat) {
			super.init(frame: CGRect(x: 0, y: 0, width: width, height: 10000))
			var height: CGFloat = 5
			let titleLabel = UILabel()
			titleLabel.textColor = .darkTitle
			titleLabel.numberOfLines = 0
			titleLabel.font = UIFont.boldSystemFont(ofSize: 3 * titleLabel.font!.pointSize / 4)
			titleLabel.text = title
			var boundingSize = bounds.size
			boundingSize.width -= 20
			let labelSize = titleLabel.sizeThatFits(boundingSize)
			titleLabel.frame.size.height = labelSize.height
			titleLabel.frame.size.width = boundingSize.width
			titleLabel.frame.origin.y = height
			titleLabel.frame.origin.x = 10
			addSubview(titleLabel)
			height += labelSize.height
			if let data = data {
				let dataLabel = UILabel()
				dataLabel.textColor = .darkTitle
				dataLabel.numberOfLines = 0
				dataLabel.text = data
				let labelSize = dataLabel.sizeThatFits(boundingSize)
				dataLabel.frame.size.height = labelSize.height
				dataLabel.frame.size.width = boundingSize.width
				dataLabel.frame.origin.y = height
				dataLabel.frame.origin.x = 10
				dataLabel.textAlignment = .right
				addSubview(dataLabel)
				height += labelSize.height
			} else {
				titleLabel.textAlignment = .center
			}
			height += 5
			frame.size.height = height
		}

		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}

	func layout() {
		guard case .data(let entries) = state else {
			return
		}
		scrollView.isHidden = false
		activity.isHidden = true
		for view in scrollView.subviews {
			view.removeFromSuperview()
		}
		var offset = CGFloat()
		var even = true
		for entry in entries {
			let title: String
			let data: String?
			let background: UIColor
			switch entry {
				case .data(let t, let d):
					title = code(plain: t)
					data = d
					background = even ? .pageInfoEvenCellBG : .pageInfoOddCellBG
					even = !even
				case .title(let t):
					title = code(plain: t)
					data = nil
					background = .pageInfoTitleBG
			}
			let cell = Cell(title: title, data: data, width: scrollView.bounds.width)
			cell.backgroundColor = background
			cell.frame.origin.y = offset
			offset += cell.frame.height
			scrollView.addSubview(cell)
		}
		scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: offset)
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		scrollView.frame = bounds
		scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		scrollView.isHidden = true
		addSubview(scrollView)
		activity.center = CGPoint(x: bounds.midX, y: bounds.midY)
		activity.startAnimating()
		scrollView.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin, .flexibleBottomMargin]
		addSubview(activity)
		error.frame = bounds
		error.textAlignment = .center
		error.numberOfLines = 0
		error.isHidden = true
		error.textColor = .darkTitle
		addSubview(error)
		let recognizer = UITapGestureRecognizer(target: self, action: #selector(trigger(_:)))
		recognizer.numberOfTapsRequired = 5
		addGestureRecognizer(recognizer)
	}

	override func layoutSubviews() {
		activity.center = CGPoint(x: bounds.midX, y: bounds.midY)
		scrollView.frame = bounds
		error.frame = bounds
		layout()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func trigger(_ sender: UITapGestureRecognizer) {
		plain = false
		if case .data(_) = state {
			layout()
		}
	}
}
