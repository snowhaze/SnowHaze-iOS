//
//  ContactSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import MessageUI

class ContactSettingsManager: SettingsViewManager, MFMailComposeViewControllerDelegate {
	override func html() -> String {
		return NSLocalizedString("contact settings explanation", comment: "explanations of the contact settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessmentResult.color(for: .veryGood)
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let button = makeButton(for: cell)
		let title: String
		if indexPath.row == 0 && MFMailComposeViewController.canSendMail() {
			title = NSLocalizedString("email support button title", comment: "title of button to email support")
			button.addTarget(self, action: #selector(mailSupport(_:)), for: .touchUpInside)
		} else if indexPath.row == (MFMailComposeViewController.canSendMail() ? 1 : 0) {
			title = NSLocalizedString("visit website button title", comment: "title of button to visit snowhaze website")
			button.addTarget(self, action: #selector(visitWebsite(_:)), for: .touchUpInside)
		} else if indexPath.row == (MFMailComposeViewController.canSendMail() ? 2 : 1) {
			title = NSLocalizedString("share snowhaze button title", comment: "title of button to share snowhaze")
			button.addTarget(self, action: #selector(shareSnowHaze(_:)), for: .touchUpInside)
		} else if indexPath.row == (MFMailComposeViewController.canSendMail() ? 3 : 2)  {
			title = NSLocalizedString("rate snowhaze button title", comment: "title of button to rate snowhaze on the app store")
			button.addTarget(self, action: #selector(rateSnowHaze(_:)), for: .touchUpInside)
		} else {
			title = NSLocalizedString("show snowhaze source button title", comment: "title of button to show the snowhaze source")
			button.addTarget(self, action: #selector(showSource(_:)), for: .touchUpInside)
		}
		button.setTitle(title, for: [])
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return MFMailComposeViewController.canSendMail() ? 5 : 4
	}

	@objc private func mailSupport(_ sender: UIButton) {
		let emailTitle = NSLocalizedString("support email title", comment: "title of email to be sent to support")
		let device = UIDevice.current
		var u: utsname = utsname()
		uname(&u)
		let model = String(cString: uname_model(&u), encoding: String.defaultCStringEncoding) ?? "???"
		let deviceDesc = "\(model); \(device.systemName) \(device.systemVersion)"

		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "en_US")
		dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'UTC'"
		let date = dateFormatter.string(from: compilationDate)

		let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
		let buildNr = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
		let versionDesc = "\(version) (\(buildNr)@\(date))"
		let messageFormat =  NSLocalizedString("support email message format", comment: "format of message of email to be sent to support")
		let messageBody = String(format: messageFormat, deviceDesc, versionDesc, Locale.current.identifier)
		let toRecipents = ["support@snowhaze.com"]
		let mc: MFMailComposeViewController = MFMailComposeViewController()
		mc.navigationBar.barTintColor = .bar
		mc.mailComposeDelegate = self
		mc.setSubject(emailTitle)
		mc.setMessageBody(messageBody, isHTML: false)
		mc.setToRecipients(toRecipents)
		controller.present(mc, animated: true, completion: nil)
	}

	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		controller.dismiss(animated: true, completion: nil)
	}

	@objc private func visitWebsite(_ sender: UIButton) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		let site = "https://snowhaze.com/"
		mainVC?.loadInFreshTab(input: site, type: .url)
	}

	@objc private func showSource(_ sender: UIButton) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		let site = "https://snowhaze.com/opensource"
		mainVC?.loadInFreshTab(input: site, type: .url)
	}

	@objc private func shareSnowHaze(_ sender: UIButton) {
		let message = NSLocalizedString("snowhaze share text", comment: "text use to prefill 'share' messagers")
		let activityController = UIActivityViewController(activityItems: [message], applicationActivities: nil)
		activityController.popoverPresentationController?.sourceView = sender
		controller.present(activityController, animated: true, completion: nil)
	}

	@objc private func rateSnowHaze(_ sender: UIButton) {
		if #available(iOS 10, *) {
			UIApplication.shared.open(URL(string: "https://itunes.apple.com/app/id1121026941?action=write-review")!)
		} else {
			UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/id1121026941?action=write-review")!)
		}
	}
}
