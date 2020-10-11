//
//  InstallTutorialViewController.swift
//  SnowHaze
//
//
//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private class FlipBook: UIImageView {
	private let images: [UIImage]
	private let delay: TimeInterval
	private var state: State = .paused
	private var index: Int
	private static let transition = 0.2

	private enum State {
		case paused
		case pausing
		case flipping
	}

	init(images: [UIImage], delay: TimeInterval) {
		precondition(!images.isEmpty)
		precondition(delay > FlipBook.transition)
		self.images = images
		self.delay = delay
		self.index = images.count - 1
		super.init(image: images.last)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func flip() {
		index = (index + 1) % images.count
		let img = images[index]
		UIView.transition(with: self, duration: FlipBook.transition, options: .transitionCrossDissolve, animations: { [weak self] in
			self?.image = img
		})
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
			guard let self = self else {
				return
			}
			if case .pausing = self.state {
				self.state = .paused
				self.index = self.images.count - 1
			}
			if case .flipping = self.state {
				self.flip()
			}
		}
	}

	override func willMove(toWindow newWindow: UIWindow?) {
		super.willMove(toWindow: newWindow)
		if let _ = newWindow {
			let oldState = state
			state = .flipping
			if case .paused = oldState {
				flip()
			}
		} else {
			if case .flipping = state {
				state = .pausing
			}
		}
	}
}

class InstallTutorialViewController : TutorialViewController {
	private lazy var storedViews: [(UIView, UIView, CGFloat)] = {
		let buttonHeight: CGFloat = 45
		let margin: CGFloat = 10

		var res = [(UIView, UIView, CGFloat)]()
		for i in 0 ..< 5 {
			let main = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
			let sec = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 300))
			var secHeightMultiplier: CGFloat = 1.0
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
				let format = "<span style='font-size:\(label.font.pointSize)px;color:#\(color.hex);text-align:center;font-family: -apple-system'>\(welcomeFormat)</span>"
				let data = format.data(using: .utf8)!
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
				let label = UILabel(frame: CGRect(x: 10, y: 10, width: 80, height: 180))
				label.numberOfLines = 0
				label.textAlignment = .center
				label.autoresizingMask = [.flexibleHeight, .flexibleBottomMargin, .flexibleWidth]
				label.textColor = .title
				label.text = NSLocalizedString("tutorial \(i + 1). page content", comment: "content of \(i + 1). tutorial page")
				sec.addSubview(label)

				sec.backgroundColor = .tutorialTextBG

				let separator = UIView(frame: CGRect(x: 0, y: 0, width: sec.bounds.width, height: 2))
				separator.backgroundColor = .tutorialTextBGSeparator
				separator.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				sec.addSubview(separator)

				if i == 5 - 1 {
					let buttonwidth: CGFloat = 250
					let buttonContainer = UIView(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: 2 * buttonHeight + 10))
					buttonContainer.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					buttonContainer.center = CGPoint(x: sec.bounds.midX, y: sec.bounds.midY)
					sec.addSubview(buttonContainer)

					let upperButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonwidth, height: buttonHeight))
					let subscribeButtonTitle = NSLocalizedString("subscribe now tutorial button title", comment: "title of the tutorial button to subscribe to snowhaze premium")
					upperButton.setTitle(subscribeButtonTitle, for: [])
					upperButton.addTarget(self, action: #selector(showSubscription), for: .touchUpInside)

					upperButton.setTitleColor(.title, for: [])
					upperButton.backgroundColor = .tutorialSecondaryButton
					upperButton.layer.borderWidth = 1
					upperButton.layer.borderColor = UIColor.tutorialButtonBorder.cgColor
					upperButton.layer.cornerRadius = buttonHeight / 2
					buttonContainer.addSubview(upperButton)

					let lowerButton = UIButton(frame: CGRect(x: 0, y: buttonContainer.bounds.maxY - buttonHeight, width: buttonwidth, height: buttonHeight))
					let endButtonTitle = NSLocalizedString("tutorial end tutorial button title", comment: "title of button to leave tutorial from last page")
					lowerButton.setTitle(endButtonTitle, for: [])
					lowerButton.frame.size.width = 250
					lowerButton.addTarget(self, action: #selector(closeTutorial), for: .touchUpInside)

					lowerButton.setTitleColor(.title, for: [])
					lowerButton.backgroundColor = .tutorialTextBGSeparator
					lowerButton.layer.cornerRadius = buttonHeight / 2
					buttonContainer.addSubview(lowerButton)

					secHeightMultiplier = 1.3
					let offset: CGFloat = 50
					label.frame.size.height -= offset
					buttonContainer.frame.origin.y += offset
				} else {
					let button = UIButton(frame: CGRect(x: 0, y: 0, width: 200, height: buttonHeight))
					button.layer.cornerRadius = buttonHeight / 2
					let continueButtonTitle = NSLocalizedString("tutorial continue button title", comment: "title of button to switch to next tutorial page")
					button.setTitle(continueButtonTitle, for: [])
					button.addTarget(self, action: #selector(selectNext), for: .touchUpInside)

					button.center = CGPoint(x: sec.frame.midX, y: sec.frame.minY + 0.8 * sec.frame.height)
					button.setTitleColor(.title, for: [])
					button.backgroundColor = .tutorialTextBGSeparator
					button.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					sec.addSubview(button)
				}

				if i == 4 - 1 {
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
					wrapper.center = CGPoint(x: main.bounds.midX, y: main.bounds.midY - 30)
					wrapper.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
				} else {
					let names: [String]
					let locale = NSLocalizedString("localization code", comment: "code used to identify the current locale")
					switch i {
						case 2 - 1:
							names = [
								"tutorial_page_2_frame1_image_\(locale)",
								"tutorial_page_2_frame2_image_\(locale)"
							]
						case 3 - 1:
							names = [
								"tutorial_page_3_frame1_image_\(locale)",
								"tutorial_page_3_frame2_image_\(locale)"
							]
						case 5 - 1:
							names = ["tutorial_page_5_image"]
						default:	fatalError("Unexpected Image Index")
					}
					var images = names.map { UIImage(named: $0)! }
					let imageView = FlipBook(images: images, delay: 2)
					imageView.contentMode = .scaleAspectFit
					let bounds = main.bounds
					let rate: CGFloat = 0.8
					imageView.frame = CGRect (x: bounds.origin.x + bounds.width * (1 - rate) / 2, y: bounds.origin.y + bounds.height * (1 - rate) / 2, width: rate * bounds.width, height: rate * bounds.height)
					imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
					main.addSubview(imageView)
				}

				if i >= 4 - 1 {
					let label = UILabel()
					label.numberOfLines = 0
					label.text = NSLocalizedString("tutorial \(i + 1). page title", comment: "title of \(i + 1). tutorial page")
					label.font = UIFont.systemFont(ofSize: UIFont.systemFontSize * 2)
					label.textColor = .title
					label.frame = CGRect(x: 0, y: 0, width: main.bounds.width - 60, height: 100)
					label.textAlignment = .center
					main.addSubview(label)
					label.center = CGPoint(x: main.bounds.midX, y: main.bounds.midY - 80)
					label.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleWidth]
				}
			}
			res.append((main, sec, secHeightMultiplier))
		}
		return res
	}()

	@objc private func updateSwitchToggled(_ sender: UISwitch) {
		let settings = SettingsDefaultWrapper.wrapGlobalSettings()
		if sender.isOn {
			settings.set(.true, for: updateVPNListKey)
			settings.set(.true, for: updateSubscriptionProductListKey)
			settings.set(.true, for: updateAuthorizationTokenKey)
			settings.set(.true, for: doNotResetAutoUpdateKey)
		} else {
			settings.unsetValue(for: updateVPNListKey)
			settings.unsetValue(for: updateSubscriptionProductListKey)
			settings.set(.false, for: updateAuthorizationTokenKey)
			settings.unsetValue(for: doNotResetAutoUpdateKey)
		}
		DomainList.set(updating: sender.isOn)
	}

	override var views: [(UIView, UIView, CGFloat)] {
		return storedViews
	}

	@objc func skip() {
		forward(to: 5 - 1)
	}

	@objc private func showSubscription() {
		close {
			MainViewController.controller.openSettings(.subscription)
		}
	}
}
