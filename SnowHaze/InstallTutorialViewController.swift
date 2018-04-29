//
//  InstallTutorialViewController.swift
//  SnowHaze
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

class InstallTutorialViewController : TutorialViewController {
	private lazy var storedViews: [(UIView, UIView)] = {
		let buttonHeight: CGFloat = 45
		let margin: CGFloat = 10

		var res = [(UIView, UIView)]()
		for i in 0 ..< 9 {
			let main = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
			let sec = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
			if i == 0 {
				let buttonwidth: CGFloat = 200
				let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: 2 * buttonHeight + 10))
				buttonContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				buttonContainer.center = CGPoint(x: sec.bounds.midX, y: sec.bounds.midY)
				sec.addSubview(buttonContainer)

				let startButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: buttonHeight))
				let startButtonTitle = NSLocalizedString("tutorial start tutorial button title", comment: "title of button to move from first to second tutorial page")
				startButton.setTitle(startButtonTitle, for: [])
				startButton.addTarget(self, action: #selector(selectNext), for: .touchUpInside)
				startButton.setTitleColor(.title, for: [])
				startButton.backgroundColor = .tutorialTextBGSeparator
				startButton.layer.cornerRadius = buttonHeight / 2
				UIFont.setSnowHazeFont(on: startButton)
				buttonContainer.addSubview(startButton)

				let skipButton = UIButton(frame: CGRect(x: 0, y: buttonContainer.bounds.maxY - buttonHeight, width: buttonwidth, height: buttonHeight))
				let skipButtonTitle = NSLocalizedString("tutorial skip tutorial button title", comment: "title of button to leave tutorial from first page")
				skipButton.setTitle(skipButtonTitle, for: [])
				skipButton.addTarget(self, action: #selector(skip), for: .touchUpInside)
				skipButton.setTitleColor(.title, for: [])
				skipButton.backgroundColor = .tutorialSecondaryButton
				skipButton.layer.borderWidth = 1
				skipButton.layer.borderColor = UIColor.tutorialButtonBorder.cgColor
				skipButton.layer.cornerRadius = buttonHeight / 2
				UIFont.setSnowHazeFont(on: skipButton)
				buttonContainer.addSubview(skipButton)

				let contentHeight: CGFloat = 300
				let contentWidth: CGFloat = 300
				let imageSize: CGFloat = 100
				let contentContainer = UIView(frame: CGRect(x: main.bounds.midX - contentWidth / 2, y: main.bounds.midY - contentHeight / 2, width: contentWidth, height: contentHeight))
				contentContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				contentContainer.center = CGPoint(x: main.bounds.midX, y: main.bounds.midY)
				main.addSubview(contentContainer)

				let label = UILabel(frame: CGRect(x: 0, y: imageSize, width: contentWidth, height: contentHeight - imageSize))
				let color = UIColor.title
				label.textAlignment = .center
				label.numberOfLines = 0
				let welcomeFormat = NSLocalizedString("tutorial welcome html", comment: "html of first tutorial page content")
				let format = "<shfont style='font-size:\(label.font.pointSize)px;color:#\(color.hex);font-family:\(SnowHazeFontName);text-align:center'>\(welcomeFormat)</shfont>"
				let data = format.data(using: String.Encoding.utf8)!
				let options: [NSAttributedString.DocumentReadingOptionKey : Any] = [NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.documentType.rawValue): NSAttributedString.DocumentType.html, NSAttributedString.DocumentReadingOptionKey(rawValue: NSAttributedString.DocumentAttributeKey.characterEncoding.rawValue): String.Encoding.utf8.rawValue]
				label.attributedText = try? NSAttributedString(data: data, options: options, documentAttributes: nil)
				contentContainer.addSubview(label)

				let imageView = UIImageView(frame: CGRect(x: contentContainer.bounds.midX - imageSize / 2, y: 0, width: imageSize, height: imageSize))
				imageView.image = #imageLiteral(resourceName: "icon_round")
				imageView.layer.cornerRadius = imageSize / 2
				imageView.layer.borderColor = UIColor.tutorialIconBorder.cgColor
				imageView.layer.borderWidth = 1
				contentContainer.addSubview(imageView)
			} else {
				if i < 7 - 1 {
					let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 180))
					UIFont.setSnowHazeFont(on: label)
					label.numberOfLines = 0
					label.textAlignment = .center
					label.autoresizingMask = [.flexibleHeight, .flexibleBottomMargin, .flexibleWidth]
					label.textColor = .title
					label.text = NSLocalizedString("tutorial \(i + 1). page content", comment: "content of \(i + 1). tutorial page")
					sec.addSubview(label)
				}

				if i == 7 - 1 || i == 8 - 1 || i == 9 - 1 {
					let buttonwidth: CGFloat = 200
					let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: 2 * buttonHeight + 10))
					buttonContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					buttonContainer.center = CGPoint(x: sec.bounds.midX, y: sec.bounds.midY)
					sec.addSubview(buttonContainer)

					if i > 7 - 1 {
						let upperButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: buttonHeight))
						if i == 9 - 1 {
							let startButtonTitle = NSLocalizedString("visit online tutorial button title", comment: "title of the tutorial button to visit the online tutorial")
							upperButton.setTitle(startButtonTitle, for: [])
							upperButton.frame.size.width = 250
							buttonContainer.frame.size.width = 250
							buttonContainer.center = CGPoint(x: sec.bounds.midX, y: sec.bounds.midY)
							upperButton.addTarget(self, action: #selector(showTutorial), for: .touchUpInside)
						} else {
							let subscribeButtonTitle = NSLocalizedString("subscribe now tutorial button title", comment: "title of the tutorial button to subscribe to snowhaze premium")
							upperButton.setTitle(subscribeButtonTitle, for: [])
							upperButton.addTarget(self, action: #selector(showSubscription), for: .touchUpInside)
						}
						upperButton.setTitleColor(.title, for: [])
						upperButton.backgroundColor = .tutorialSecondaryButton
						upperButton.layer.borderWidth = 1
						upperButton.layer.borderColor = UIColor.tutorialButtonBorder.cgColor
						upperButton.layer.cornerRadius = buttonHeight / 2
						UIFont.setSnowHazeFont(on: upperButton)
						buttonContainer.addSubview(upperButton)
					}

					let lowerButton = UIButton(frame: CGRect(x: 0, y: buttonContainer.bounds.maxY - buttonHeight, width: buttonwidth, height: buttonHeight))
					if i == 9 - 1 {
						let endButtonTitle = NSLocalizedString("tutorial end tutorial button title", comment: "title of button to leave tutorial from last page")
						lowerButton.setTitle(endButtonTitle, for: [])
						lowerButton.frame.size.width = 250
						lowerButton.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)
					} else if i == 8 - 1 {
						let startButtonTitle = NSLocalizedString("tutorial continue button title", comment: "title of button to switch to next tutorial page")
						lowerButton.setTitle(startButtonTitle, for: [])
						lowerButton.addTarget(self, action: #selector(selectNext), for: .touchUpInside)
					} else {
						let continueButtonTitle = NSLocalizedString("tutorial continue button title", comment: "title of button to switch to next tutorial page")
						lowerButton.setTitle(continueButtonTitle, for: [])
						lowerButton.addTarget(self, action: #selector(selectNext), for: .touchUpInside)
					}

					lowerButton.setTitleColor(.title, for: [])
					lowerButton.backgroundColor = .tutorialTextBGSeparator
					lowerButton.layer.cornerRadius = buttonHeight / 2
					UIFont.setSnowHazeFont(on: lowerButton)
					buttonContainer.addSubview(lowerButton)

					if i == 8 - 1 {
						regularPromoButtonContainer = buttonContainer
						let skip = skipPromoButtonContainer
						skip.frame = buttonContainer.frame
						skip.frame.size.width += 50
						skip.frame.origin.x -= 25
						skip.autoresizingMask = buttonContainer.autoresizingMask
						buttonContainer.superview!.addSubview(skip)
					}
				} else {
					sec.backgroundColor = .tutorialTextBG

					let separator = UIView(frame: CGRect(x: 0, y: 0, width: sec.bounds.width, height: 2))
					separator.backgroundColor = .tutorialTextBGSeparator
					separator.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
					sec.addSubview(separator)

					let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: buttonHeight))
					button.layer.cornerRadius = buttonHeight / 2
					let continueButtonTitle = NSLocalizedString("tutorial continue button title", comment: "title of button to switch to next tutorial page")
					button.setTitle(continueButtonTitle, for: [])
					button.addTarget(self, action: #selector(selectNext), for: .touchUpInside)

					button.center = CGPoint(x: sec.frame.midX, y: sec.frame.minY + 0.8 * sec.frame.height)
					UIFont.setSnowHazeFont(on: button)
					button.setTitleColor(.title, for: [])
					button.backgroundColor = .tutorialTextBGSeparator
					button.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					sec.addSubview(button)
				}

				if i == 6 - 1 {
					let uiSwitch = UISwitch()
					let wrapper = UIView(frame: uiSwitch.bounds)
					uiSwitch.frame.origin.x = 0
					uiSwitch.frame.origin.y = 0
					wrapper.addSubview(uiSwitch)
					uiSwitch.isOn = SettingsDefaultWrapper.wrapGlobalSettings().value(for: doNotResetAutoUpdateKey).boolValue
					wrapper.transform = CGAffineTransform(scaleX: 2, y: 2)
					uiSwitch.tintColor = .switchOff
					uiSwitch.backgroundColor = .switchOff
					uiSwitch.onTintColor = .switchOn
					uiSwitch.thumbTintColor = .title
					uiSwitch.layer.cornerRadius = uiSwitch.bounds.height / 2
					uiSwitch.addTarget(self, action: #selector(updateSwitchToggled(_:)), for: .valueChanged)
					main.addSubview(wrapper)
					wrapper.center = CGPoint(x: main.bounds.midX, y: main.bounds.midY - 40)
					wrapper.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				} else {
					let locale = NSLocalizedString("localization code", comment: "code used to identify the current locale")
					let image = UIImage(named: "tutorial_page_\(i + 1)_image_\(locale)")
					let imageView = UIImageView(image: image)
					imageView.contentMode = .scaleAspectFit
					let bounds = main.bounds
					let rate: CGFloat = 0.8
					imageView.frame = CGRect (x: bounds.origin.x + bounds.width * (1 - rate) / 2, y: bounds.origin.y + bounds.height * (1 - rate) / 2, width: rate * bounds.width, height: rate * bounds.height)
					imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					main.addSubview(imageView)
				}
			}
			res.append((main, sec))
		}
		return res
	}()

	@objc private func updateSwitchToggled(_ sender: UISwitch) {
		let settings = SettingsDefaultWrapper.wrapGlobalSettings()
		if sender.isOn {
			settings.set(.true, for: updateVPNListKey)
			settings.set(.true, for: updateSubscriptionProductListKey)
			settings.set(.true, for: updateSiteListsKey)
			settings.set(.true, for: updateAuthorizationTokenKey)
			settings.set(.true, for: doNotResetAutoUpdateKey)
		} else {
			settings.unsetValue(for: updateVPNListKey)
			settings.unsetValue(for: updateSubscriptionProductListKey)
			settings.unsetValue(for: updateSiteListsKey)
			settings.set(.false, for: updateAuthorizationTokenKey)
			settings.unsetValue(for: doNotResetAutoUpdateKey)
		}
	}

	private var regularPromoButtonContainer: UIView!

	private lazy var skipPromoButtonContainer: UIView = {
		let buttonHeight: CGFloat = 45
		let margin: CGFloat = 10

		let buttonwidth: CGFloat = 250
		let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: 2 * buttonHeight + 10))

		let upperButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: buttonHeight))
		let subscribeButtonTitle = NSLocalizedString("subscribe now tutorial button title", comment: "title of the tutorial button to subscribe to snowhaze premium")
		upperButton.setTitle(subscribeButtonTitle, for: [])
		upperButton.addTarget(self, action: #selector(showSubscription), for: .touchUpInside)

		upperButton.setTitleColor(.title, for: [])
		upperButton.backgroundColor = .tutorialSecondaryButton
		upperButton.layer.borderWidth = 1
		upperButton.layer.borderColor = UIColor.tutorialButtonBorder.cgColor
		upperButton.layer.cornerRadius = buttonHeight / 2
		UIFont.setSnowHazeFont(on: upperButton)
		buttonContainer.addSubview(upperButton)

		let lowerButton = UIButton(frame: CGRect(x: 0, y: buttonContainer.bounds.maxY - buttonHeight, width: buttonwidth, height: buttonHeight))
		let endButtonTitle = NSLocalizedString("tutorial end tutorial button title", comment: "title of button to leave tutorial from last page")
		lowerButton.setTitle(endButtonTitle, for: [])
		lowerButton.frame.size.width = 250
		lowerButton.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)

		lowerButton.setTitleColor(.title, for: [])
		lowerButton.backgroundColor = .tutorialTextBGSeparator
		lowerButton.layer.cornerRadius = buttonHeight / 2
		UIFont.setSnowHazeFont(on: lowerButton)
		buttonContainer.addSubview(lowerButton)
		return buttonContainer
	}()

	override var views: [(UIView, UIView)] {
		return storedViews
	}

	private var skipping: Bool {
		set {
			if let regular = regularPromoButtonContainer {
				skipPromoButtonContainer.isHidden = !newValue
				regular.isHidden = newValue
			}
		}
		get {
			return !skipPromoButtonContainer.isHidden
		}
	}

	@objc func skip() {
		skipping = true
		forward(to: 8 - 1)
	}

	@objc private func showSubscription() {
		close {
			MainViewController.controller.showSubscription()
		}
	}

	@objc private func showTutorial() {
		close {
			let mainVC = MainViewController.controller!
			mainVC.popToVisible(animated: true)
			let lang = PolicyManager.globalManager().threeLanguageCode
			mainVC.loadInFreshTab(input: "https://snowhaze.com/\(lang)/app.html#tut-slider", type: .url)
		}
	}

	override func didAnimate(from oldIndex: Int, to newIndex: Int) {
		super.didAnimate(from: oldIndex, to: newIndex)
		if newIndex != 8 - 1 || newIndex < oldIndex {
			self.skipping = false
		}
	}
}
