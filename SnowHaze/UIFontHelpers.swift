//
//  UIFontHelpers.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

let SnowHazeFontName = "texgyreadventor-regular"
let BoldSnowHazeFontName = "texgyreadventor-bold"

extension UIFont {
	static func setSnowHazeFont(on textField: UITextField) {
		let size = textField.font!.pointSize
		textField.font = snowHazeFont(size: size)
	}

	static func setSnowHazeFont(on textView: UITextView) {
		let size = textView.font?.pointSize ?? 12
		textView.font = snowHazeFont(size: size)
	}

	static func setSnowHazeFont(on label: UILabel) {
		let size = label.font!.pointSize
		label.font = snowHazeFont(size: size)
	}

	static func setSnowHazeFont(on button: UIButton) {
		setSnowHazeFont(on: button.titleLabel!)
	}

	static func snowHazeFont(size: CGFloat) -> UIFont {
		return UIFont(name: SnowHazeFontName, size: size)!
	}
}
