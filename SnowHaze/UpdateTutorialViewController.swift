//
//  UpdateTutorialViewController.swift
//  SnowHaze
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

class UpdateTutorialViewController : TutorialViewController {
	private let textView = UITextView()

	private lazy var storedViews: [(UIView, UIView)] = {
		let buttonHeight: CGFloat = 45
		let margin: CGFloat = 10
		var res = [(UIView, UIView)]()

		let language = NSLocalizedString("localization code", comment: "code used to identify the current locale")
		let supportedLanguages = ["en", "de", "fr", "en-GB", "gsw"]
		let showDevMessage = supportedLanguages.contains(language)
		for i in 0 ..< (showDevMessage ? 4 : 3) {
			let main = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
			let sec = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))

			if i == 0 {
				let buttonwidth: CGFloat = 200
				let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: 2 * buttonHeight + 10))
				buttonContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				buttonContainer.center = CGPoint(x: sec.bounds.midX, y: sec.bounds.midY)
				sec.addSubview(buttonContainer)

				// Create Start Button of Tutorial on first page
				let startButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: buttonHeight))
				let startButtonTitle = NSLocalizedString("update tutorial start tutorial button title", comment: "title of button to move from first to second update tutorial page")
				startButton.setTitle(startButtonTitle, for: [])
				startButton.addTarget(self, action: #selector(selectNext), for: .touchUpInside)
				startButton.setTitleColor(.title, for: [])
				startButton.backgroundColor = .tutorialTextBGSeparator
				startButton.layer.cornerRadius = buttonHeight / 2
				UIFont.setSnowHazeFont(on: startButton)
				buttonContainer.addSubview(startButton)

				// Create Skip Button of Tutorial on first page
				let skipButton = UIButton(frame: CGRect(x: 0, y: buttonContainer.bounds.maxY - buttonHeight, width: buttonwidth, height: buttonHeight))
				let skipButtonTitle = NSLocalizedString("update tutorial skip tutorial button title", comment: "title of button to leave update tutorial from first page")
				skipButton.setTitle(skipButtonTitle, for: [])
				skipButton.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)
				skipButton.setTitleColor(.title, for: [])
				skipButton.backgroundColor = .tutorialSecondaryButton
				skipButton.layer.borderWidth = 1
				skipButton.layer.borderColor = UIColor.tutorialButtonBorder.cgColor
				skipButton.layer.cornerRadius = buttonHeight / 2
				UIFont.setSnowHazeFont(on: skipButton)
				buttonContainer.addSubview(skipButton)

				// Content container
				let contentHeight: CGFloat = 300
				let contentWidth: CGFloat = 300
				let imageSize: CGFloat = 100
				let contentContainer = UIView(frame: CGRect(x: main.bounds.midX - contentWidth / 2, y: main.bounds.midY - contentHeight / 2, width: contentWidth, height: contentHeight))
				contentContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				contentContainer.center = CGPoint(x: main.bounds.midX, y: main.bounds.midY)
				main.addSubview(contentContainer)

				// Content on first tutorial page
				let label = UILabel(frame: CGRect(x: 0, y: imageSize, width: contentWidth, height: contentHeight - imageSize))
				let color = UIColor.title
				label.textAlignment = .center
				label.numberOfLines = 0
				let welcomeFormat = NSLocalizedString("update tutorial welcome html", comment: "html of first update tutorial page content")
				let format = "<shfont style='font-size:\(label.font.pointSize)px;color:#\(color.hex);font-family:\(SnowHazeFontName);text-align:center'>\(welcomeFormat)</shfont>"
				let data = format.data(using: String.Encoding.utf8)!
				let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.documentType.rawValue): NSAttributedString.DocumentType.html, NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.characterEncoding.rawValue): String.Encoding.utf8.rawValue]
				label.attributedText = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
				contentContainer.addSubview(label)

				// SnowHaze logo on first tutorial page
				let imageView = UIImageView(frame: CGRect(x: contentContainer.bounds.midX - imageSize / 2, y: 0, width: imageSize, height: imageSize))
				imageView.image = #imageLiteral(resourceName: "icon_round")
				imageView.layer.cornerRadius = imageSize / 2
				imageView.layer.borderColor = UIColor.tutorialIconBorder.cgColor
				imageView.layer.borderWidth = 1
				contentContainer.addSubview(imageView)
			}

			if i == 2 - 1 || i == 3 - 1 {
				// Content in separator
				let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 180))
				UIFont.setSnowHazeFont(on: label)
				label.numberOfLines = 0
				label.textAlignment = .center
				label.autoresizingMask = [.flexibleHeight, .flexibleBottomMargin, .flexibleWidth]
				label.textColor = .title
				let tutorialText = NSLocalizedString("update tutorial \(i + 1). page content", comment: "content of \(i + 1). update tutorial page")
				sec.addSubview(label)

				// Change color of warning symbol
				let unsafeCharacter = "\u{F105}"
				let attributedString = NSMutableAttributedString(string: tutorialText)
				let warningRange = (tutorialText as NSString).range(of: unsafeCharacter)
				if warningRange.location != NSNotFound {
					attributedString.addAttribute(NSAttributedStringKey.foregroundColor, value: UIColor.httpWarning, range: warningRange)
				}
				label.attributedText = attributedString

				// Separator for pages 2 and 3
				sec.backgroundColor = .tutorialTextBG
				let separator = UIView(frame: CGRect(x: 0, y: 0, width: sec.bounds.width, height: 2))
				separator.backgroundColor = .tutorialTextBGSeparator
				separator.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				sec.addSubview(separator)

				// Button
				let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: buttonHeight))
				button.layer.cornerRadius = buttonHeight / 2
				if !showDevMessage && i == 3-1 {
					let endButtonTitle = NSLocalizedString("update tutorial end tutorial button title", comment: "title of button to leave the update tutorial from last page")
					button.setTitle(endButtonTitle, for: [])
					button.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)
				} else {
					let continueButtonTitle = NSLocalizedString("tutorial continue button title", comment: "title of button to switch to next tutorial page")
					button.setTitle(continueButtonTitle, for: [])
					button.addTarget(self, action: #selector(selectNext), for: .touchUpInside)
				}

				button.center = CGPoint(x: sec.frame.midX, y: sec.frame.minY + 0.82 * sec.frame.height)
				UIFont.setSnowHazeFont(on: button)
				button.setTitleColor(.title, for: [])
				button.backgroundColor = .tutorialTextBGSeparator
				button.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				sec.addSubview(button)

				// Here the images for page 2 and 3 are inserted
				let image = UIImage(named: "update_tutorial_page_\(i + 1)_image")
				let imageView = UIImageView(image: image)
				imageView.contentMode = .scaleAspectFit
				let bounds = main.bounds
				let rate: CGFloat = 0.8
				imageView.frame = CGRect (x: bounds.origin.x + bounds.width * (1 - rate) / 2, y: bounds.origin.y + bounds.height * (1 - rate) / 2, width: rate * bounds.width, height: rate * bounds.height)
				imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				main.addSubview(imageView)
			}

			// The following is for the page with dev message, 4th and final page
			if i == 4 - 1 {
				// The end tutorial button is created
				let endButton = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: buttonHeight))
				endButton.center = CGPoint(x: sec.frame.midX, y: sec.frame.minY + 0.82 * sec.frame.height)
				endButton.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]

				let endButtonTitle = NSLocalizedString("update tutorial end tutorial button title", comment: "title of button to leave the update tutorial from last page")
				endButton.setTitle(endButtonTitle, for: [])
				endButton.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)

				endButton.setTitleColor(.title, for: [])
				endButton.backgroundColor = .tutorialTextBGSeparator
				endButton.layer.cornerRadius = buttonHeight / 2
				UIFont.setSnowHazeFont(on: endButton)
				sec.addSubview(endButton)

				// Create the title of the page
				let labelMessageFromDev = NSLocalizedString("update tutorial message from developers header", comment: "header for the message from the developers in en, fr, de")
				let label = UILabel(frame: CGRect(x: 10, y: -20, width: 80, height: 80))
				UIFont.setSnowHazeFont(on: label)
				label.numberOfLines = 1
				label.textAlignment = .center
				label.autoresizingMask = [.flexibleHeight, .flexibleBottomMargin, .flexibleWidth]
				label.textColor = .title
				label.text = labelMessageFromDev
				main.addSubview(label)

				// Create the message
				let messageFromDev = NSLocalizedString("update tutorial message from developers content", comment: "message from the developers in en, fr, de")
				let fontsize: CGFloat = 16.0
				let bounds = main.bounds
				let rate: CGFloat = 0.8

				textView.frame = CGRect(x: bounds.origin.x + bounds.width * (1 - rate) / 2, y: bounds.origin.y + bounds.height * (1.1 - rate) / 2, width: rate * bounds.width, height: rate * rate * bounds.height)
				textView.text = messageFromDev
				textView.backgroundColor = nil
				textView.textColor = .white
				UIFont.setSnowHazeFont(on: textView)
				textView.font = UIFont.snowHazeFont(size: fontsize)
				textView.contentMode = .scaleToFill
				textView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				textView.isEditable = false
				textView.isSelectable = false

				main.addSubview(textView)
			}
			res.append((main, sec))
		}
		return res
	}()

	override var views: [(UIView, UIView)] {
		return storedViews
	}

	override func didAnimate(from oldIndex: Int, to newIndex: Int) {
		super.didAnimate(from: oldIndex, to: newIndex)
		if newIndex == 4 - 1 {
			textView.flashScrollIndicators()
		}
	}
}
