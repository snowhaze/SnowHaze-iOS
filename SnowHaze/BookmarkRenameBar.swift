//
//  BookmarkRenameBar.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class BookmarkRenameBar: TextInputBar {
	private let cancelButton = UIButton()
	private(set) var wasCanceled = false

	var callback: ((String?) -> Void)?

	override init(frame: CGRect) {
		super.init(frame: frame)
		cancelButton.frame = CGRect(x: 0, y: frame.minY, width: 80, height: frame.height)
		cancelButton.autoresizingMask = .flexibleRightMargin

		let cancel = NSLocalizedString("bookmark rename bar cancel button title", comment: "title of button to cancel renaming of bookmark")
		cancelButton.setTitleColor(.button, for: [])
		cancelButton.setTitle(cancel, for: [])
		cancelButton.titleLabel?.adjustsFontSizeToFitWidth = true

		cancelButton.addTarget(self, action: #selector(cancelButtonPressed(_:)), for: .touchUpInside)

		addSubview(cancelButton)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func cancelButtonPressed(_ sender: UIButton) {
		wasCanceled = true
		delegate?.textInputBarDidDismiss(self)
	}

	override func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let res = super.textFieldShouldReturn(textField)
		if res {
			delegate?.textInputBarDidDismiss(self)
		}
		return res
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let cancelX: CGFloat
		if #available(iOS 11, *) {
			cancelX = safeAreaInsets.left
		} else {
			cancelX = 0
		}
		cancelButton.frame = CGRect(x: cancelX, y: bounds.minY, width: 80, height: bounds.height)
	}

	convenience init() {
		self.init(frame: CGRect(x: 0, y: 0, width: 300, height: 45))
	}
}
