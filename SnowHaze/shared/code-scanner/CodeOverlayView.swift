//
//  CodeOverlayView.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let animationDuration = 0.3
private let buttonHeight: CGFloat = 45
private let labelHeight: CGFloat = 60
private let backgroundDimming: CGFloat = 0.7
private let codeLineNumber = 2

protocol CodeOverlayViewDelegate: AnyObject {
	func codeOverlayView(_ overlay: CodeOverlayView, canPreviewCode code: String) -> Bool
	func codeOverlayView(_ overlay: CodeOverlayView, previewCode code: String)
	func codeOverlayView(_ overlay: CodeOverlayView, didSelectCode code: String?)
	func codeOverlayView(_ overlay: CodeOverlayView, canSelectCode code: String) -> Bool
}

class CodeOverlayView: UIView {
	weak var delegate: CodeOverlayViewDelegate?

	var cancelButtonTitle = "Cancel" {
		didSet {
			cancelButton.setTitle(cancelButtonTitle, for: [])
		}
	}

	var doneButtonTitle = "Done" {
		didSet {
			doneButton.setTitle(doneButtonTitle, for: [])
		}
	}

	var previewButtonTitle = "Preview" {
		didSet {
			previewButton.setTitle(previewButtonTitle, for: [])
		}
	}

	var fontName: String? {
		didSet {
			if let name = fontName {
				let codeSize = codeLabel.font.pointSize
				let codeFont = UIFont(name: name, size: codeSize)
				codeLabel.font = codeFont

				let buttonSize = cancelButton.titleLabel!.font.pointSize
				let buttonFont = UIFont(name: name, size: buttonSize)
				cancelButton.titleLabel?.font = buttonFont
				doneButton.titleLabel?.font = buttonFont
				previewButton.titleLabel?.font = buttonFont
			} else {
				let codeSize = codeLabel.font.pointSize
				let codeFont = UIFont.systemFont(ofSize: codeSize)
				codeLabel.font = codeFont

				let buttonSize = cancelButton.titleLabel!.font.pointSize
				let buttonFont = UIFont.systemFont(ofSize: buttonSize)
				cancelButton.titleLabel?.font = buttonFont
				doneButton.titleLabel?.font = buttonFont
				previewButton.titleLabel?.font = buttonFont
			}
		}
	}

	var codeBackgroundColor = UIColor.black {
		didSet {
			backgroundView.backgroundColor = codeBackgroundColor.withAlphaComponent(backgroundDimming)
			codeBackgroundView.backgroundColor = codeBackgroundColor.withAlphaComponent(backgroundDimming)
		}
	}

	var codeColor = UIColor.white {
		didSet {
			codeLabel.textColor = codeColor
		}
	}

	var buttonColor = UIColor.blue {
		didSet {
			cancelButton.setTitleColor(buttonColor, for: [])
			doneButton.setTitleColor(buttonColor, for: [])
			previewButton.setTitleColor(buttonColor, for: [])
		}
	}

	 var showScanResult = true {
		 didSet {
			codeBackgroundView.isHidden = !(showScanResult && code != nil)
		 }
	 }

	 var showControlButtons = true {
		didSet {
			backgroundView.isHidden = !showControlButtons
		}
	}

	var code: String? {
		didSet {
			codeLabel.text = code
			if let code = code, codeBackgroundView.alpha == 0 {
				if showScanResult {
					codeBackgroundView.isHidden = false
				}
				let hidePreviewButton = !(delegate?.codeOverlayView(self, canPreviewCode: code) ?? false)
				let hideDoneButton = !(delegate?.codeOverlayView(self, canSelectCode: code) ?? true)
				if !hidePreviewButton {
					previewButton.isHidden = false
				}
				if !hideDoneButton {
					doneButton.isHidden = false
				}
				UIView.animate(withDuration: animationDuration, animations: {
					self.codeBackgroundView.alpha = 1
					self.previewButton.alpha = hidePreviewButton ? 0 : 1
					self.doneButton.alpha = hideDoneButton ? 0 : 1
				}, completion: { (finished) -> () in
					if finished {
						self.previewButton.isHidden = hidePreviewButton
						self.doneButton.isHidden = hideDoneButton
					}
				})
			} else if codeBackgroundView.alpha != 0 && code == nil {
				UIView.animate(withDuration: animationDuration, animations: {
					self.codeBackgroundView.alpha = 0
					self.previewButton.alpha = 0
					self.doneButton.alpha = 0
				}, completion: { (finished) -> () in
					if finished {
						self.codeBackgroundView.isHidden = true
						self.previewButton.isHidden = true
						self.doneButton.isHidden = true
					}
				})
			}
		}
	}

	private var codeLabel = UILabel()
	private var backgroundView = UIView()
	private var codeBackgroundView = UIView()
	private var cancelButton = UIButton()
	private var doneButton = UIButton()
	private var previewButton = UIButton()

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
		backgroundView.frame = CGRect(x: bounds.minX, y: bounds.maxY - buttonHeight, width: bounds.width, height: buttonHeight)
		backgroundView.backgroundColor = codeBackgroundColor.withAlphaComponent(backgroundDimming)
		addSubview(backgroundView)

		codeBackgroundView.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
		codeBackgroundView.frame = CGRect(x: bounds.minX, y: bounds.midY - labelHeight / 2, width: bounds.width, height: labelHeight)
		codeBackgroundView.backgroundColor = codeBackgroundColor.withAlphaComponent(backgroundDimming)
		codeBackgroundView.alpha = 0
		codeBackgroundView.isHidden = true
		addSubview(codeBackgroundView)

		codeLabel.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
		codeLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: labelHeight)
		codeLabel.textColor = codeColor
		codeLabel.textAlignment = .center
		codeLabel.numberOfLines = codeLineNumber
		codeBackgroundView.addSubview(codeLabel)

		cancelButton.setTitleColor(buttonColor, for: [])
		doneButton.setTitleColor(buttonColor, for: [])
		previewButton.setTitleColor(buttonColor, for: [])

		cancelButton.setTitle(cancelButtonTitle, for: [])
		doneButton.setTitle(doneButtonTitle, for: [])
		previewButton.setTitle(previewButtonTitle, for: [])

		cancelButton.autoresizingMask = [.flexibleHeight, .flexibleRightMargin, .flexibleWidth]
		cancelButton.frame = CGRect(x: bounds.minX, y: 0, width: bounds.width / 3, height: buttonHeight)
		cancelButton.addTarget(self, action: #selector(cancelButtonPressed(_:)), for: .touchUpInside)
		backgroundView.addSubview(cancelButton)

		previewButton.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin, .flexibleRightMargin, .flexibleWidth]
		previewButton.frame = CGRect(x: bounds.minX + bounds.width / 3, y: 0, width: bounds.width / 3, height: buttonHeight)
		previewButton.alpha = 0
		previewButton.isHidden = true
		previewButton.addTarget(self, action: #selector(previewButtonPressed(_:)), for: .touchUpInside)
		backgroundView.addSubview(previewButton)

		doneButton.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin, .flexibleWidth]
		doneButton.frame = CGRect(x: bounds.maxX - bounds.width / 3, y: 0, width: bounds.width / 3, height: buttonHeight)
		doneButton.alpha = 0
		doneButton.isHidden = true
		doneButton.addTarget(self, action: #selector(doneButtonPressed(_:)), for: .touchUpInside)
		backgroundView.addSubview(doneButton)
	}

	override func layoutSubviews() {
		let leftMargin = safeAreaInsets.left
		let rightMargin = safeAreaInsets.right
		let bottomMargin = safeAreaInsets.bottom

		codeBackgroundView.frame = CGRect(x: bounds.minX, y: bounds.midY - labelHeight / 2 - bottomMargin, width: bounds.width, height: labelHeight)
		codeLabel.frame = CGRect(x: max(leftMargin, 8), y: 0, width: bounds.width - max(leftMargin + rightMargin, 2 * 8), height: labelHeight)

		backgroundView.frame = CGRect(x: bounds.minX, y: bounds.maxY - buttonHeight - bottomMargin, width: bounds.width, height: buttonHeight + bottomMargin)
		cancelButton.frame = CGRect(x: bounds.minX + leftMargin, y: backgroundView.bounds.minY, width: (bounds.width - leftMargin - rightMargin) / 3, height: buttonHeight)
		previewButton.frame = CGRect(x: bounds.minX + leftMargin + (bounds.width - leftMargin - rightMargin) / 3, y: backgroundView.bounds.minY, width: (bounds.width - leftMargin - rightMargin) / 3, height: buttonHeight)
		doneButton.frame = CGRect(x: bounds.maxX - rightMargin - (bounds.width - leftMargin - rightMargin) / 3, y: backgroundView.bounds.minY, width: (bounds.width - leftMargin - rightMargin) / 3, height: buttonHeight)
	}

	convenience init(view: UIView) {
		self.init(frame: view.bounds)
		autoresizingMask = [.flexibleHeight, .flexibleWidth]
		view.addSubview(self)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	@objc private func cancelButtonPressed(_ sender: UIButton) {
		delegate?.codeOverlayView(self, didSelectCode: nil)
	}

	@objc private func previewButtonPressed(_ sender: UIButton) {
		delegate?.codeOverlayView(self, previewCode: code!)
	}

	@objc private func doneButtonPressed(_ sender: UIButton) {
		delegate?.codeOverlayView(self, didSelectCode: code!)
	}
}
