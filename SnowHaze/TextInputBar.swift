//
//  TextInputBar.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

protocol TextInputBarDelegate: class {
	func textInputBar(_ bar: TextInputBar, willUpdateText newText: String)
	func textInputBarDidDismiss(_ bar: TextInputBar)
}

class TextInputBar: UIView, UITextFieldDelegate {
	let textField = UITextField()
	private let doneButton = UIButton()
	weak var delegate: SearchBarDelegate?

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .bar
		textField.textColor = .title
		textField.tintColor = .button
		textField.layer.cornerRadius = 5
		textField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
		textField.textAlignment = .center
		textField.delegate = self
		UIFont.setSnowHazeFont(on: textField)
		doneButton.frame = CGRect(x: frame.maxX - 80, y: frame.minY, width: 80, height: frame.height)
		textField.frame = CGRect(x: 80, y: frame.minY + 8, width: frame.width - 160, height: frame.height - 16)
		doneButton.autoresizingMask = .flexibleLeftMargin
		textField.autoresizingMask = .flexibleWidth

		let done = NSLocalizedString("text input bar dismiss button title", comment: "title of button to dismiss text input bar")
		doneButton.setTitleColor(.button, for: [])
		doneButton.setTitle(done, for: [])

		doneButton.addTarget(self, action: #selector(doneButtonPressed(_:)), for: .touchUpInside)

		addSubview(textField)
		addSubview(doneButton)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func doneButtonPressed(_ sender: UIButton) {
		delegate?.textInputBarDidDismiss(self)
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		let oldText = textField.text ?? ""
		let newText = (oldText as NSString).replacingCharacters(in: range, with: string)
		delegate?.textInputBar(self, willUpdateText: newText)
		return true
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let usableWidth: CGFloat
		let doneX: CGFloat
		if #available(iOS 11, *) {
			usableWidth = bounds.width - 2 * max(safeAreaInsets.left, safeAreaInsets.right)
			doneX = bounds.maxX - 80 - safeAreaInsets.right
		} else {
			usableWidth = bounds.width
			doneX = bounds.maxX - 80
		}
		let width = min(usableWidth / 2, usableWidth - 160)
		textField.frame.size.width = width
		textField.frame.origin.x = bounds.midX - width / 2

		doneButton.frame = CGRect(x: doneX, y: bounds.minY, width: 80, height: bounds.height)
	}
}
