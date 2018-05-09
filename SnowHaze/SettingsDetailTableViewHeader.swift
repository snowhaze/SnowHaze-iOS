//
//  SettingsDetailTableViewHeader.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let defaultLength: CGFloat = 250
private let borderMargin: CGFloat = 8

protocol SettingsDetailTableViewHeaderDelegate: class {
	func showDetails(for header: SettingsDetailTableViewHeader)
}

class SettingsDetailTableViewHeader: UITableViewHeaderFooterView {
	private static let defaultHeight: CGFloat = 350
	private let colorView = UIView()
	private let iconImageView = UIImageView(image: nil)
	private let descriptionLabel = UILabel(frame: CGRect(x: borderMargin, y: defaultLength, width: defaultLength - 2 * borderMargin, height: SettingsDetailTableViewHeader.defaultHeight - defaultLength))

	weak var delegate: SettingsDetailTableViewHeaderDelegate?

	var size: CGFloat {
		return descriptionLabel.font.pointSize
	}

	var icon: UIImage? {
		set {
			iconImageView.image = newValue
		}
		get {
			return iconImageView.image
		}
	}

	var sectionDescription: NSAttributedString? {
		set {
			descriptionLabel.attributedText = newValue
		}
		get {
			return descriptionLabel.attributedText
		}
	}

	var color: UIColor {
		set {
			colorView.backgroundColor = newValue
		}
		get {
			return colorView.backgroundColor!
		}
	}

	override init(reuseIdentifier: String?) {
		super.init(reuseIdentifier: reuseIdentifier)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	private func setup() {
		bounds = CGRect(x: 0, y: 0, width: defaultLength, height: SettingsDetailTableViewHeader.defaultHeight)
		addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showDetails)))

		descriptionLabel.textColor = .title
		descriptionLabel.numberOfLines = 4
		descriptionLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		UIFont.setSnowHazeFont(on: descriptionLabel)

		colorView.frame = CGRect(x: 0, y: 0, width: defaultLength, height: 250)
		colorView.backgroundColor = .red
		colorView.addSubview(iconImageView)
		colorView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		colorView.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
		addSubview(colorView)

		iconImageView.frame = CGRect(x: (defaultLength - 200) / 2, y: (defaultLength - 200) / 2, width: 200, height: 200)
		iconImageView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
		iconImageView.tintColor = .white
		addSubview(descriptionLabel)

		color = PolicyAssessmentResult.color(for: .veryBad)
	}

	private var labelFrame: CGRect {
		let size = bounds.size
		let leftMargin: CGFloat
		let rightMargin: CGFloat
		if #available(iOS 11, *) {
			leftMargin = borderMargin + safeAreaInsets.left
			rightMargin = borderMargin + safeAreaInsets.right
		} else {
			leftMargin = borderMargin
			rightMargin = borderMargin
		}
		return CGRect(x: leftMargin, y: defaultLength, width: size.width - leftMargin - rightMargin, height: size.height - defaultLength)
	}

	var bestHeight: CGFloat {
		let defaultHeight = SettingsDetailTableViewHeader.defaultHeight
		let size = CGSize(width: labelFrame.width, height: 0)
		let labelHeight = descriptionLabel.sizeThatFits(size).height + 15
		return max(defaultHeight, defaultLength + labelHeight)
	}

	override func layoutSubviews() {
		descriptionLabel.frame = labelFrame
		super.layoutSubviews()
	}

	func expand() {
		descriptionLabel.numberOfLines = 0
	}

	@objc private func showDetails() {
		delegate?.showDetails(for: self)
	}
}
