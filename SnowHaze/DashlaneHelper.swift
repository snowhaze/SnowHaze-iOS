//
//  DashlaneHelper.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let appNameKey = "dashlaneExtensionRequestAppName"
private let loginQueryKey = "com.dashlane.extension.request-login"
private let signupQueryKey = "com.dashlane.extension.request-signup"
private let signupDataKey = "dashlaneExtensionSignupRequestedData"
private let signupCredentialsKey = "dashlaneExtensionSignupRequestCredentials"
private let passwordReplyKey = "dashlaneExtensionRequestReplyPassword"
private let serviceKey = "dashlaneExtensionSignupSetviceURL"

struct DashlaneHelper {
	static let shared = DashlaneHelper()

	private init() { }

	var dashlaneInstalled: Bool {
		return UIApplication.shared.canOpenURL(URL(string: "dashlane-ext://")!)
	}

	private func extensionItem(for service: String) -> NSExtensionItem {
		let ret = NSExtensionItem()
		ret.userInfo = [appNameKey: "SnowHaze"]
		let nsservice = service as NSString
		ret.attachments = [NSItemProvider(item: nsservice, typeIdentifier: loginQueryKey)]
		return ret
	}

	func extensionItem(for webView: WKWebView) -> NSExtensionItem? {
		guard let url = webView.url?.absoluteString else {
			return nil
		}
		return extensionItem(for: url)
	}

	func isDashlaneResponse(type: UIActivity.ActivityType?) -> Bool {
		return type?.rawValue == "com.dashlane.dashlanephonefinal.SafariExtension"
	}

	func fill(_ manager: WebViewManager, with response: [Any]?, completion: (() -> Void)?) {
		let extensionItem = response!.first as! NSExtensionItem
		let provider = extensionItem.attachments!.first! 
		provider.loadItem(forTypeIdentifier: "com.apple.property-list") { [weak manager] nsdict, _ in
			guard let data = nsdict as? [String: String] else {
				if let completion = completion {
					DispatchQueue.main.async {
						completion()
					}
				}
				return
			}
			let pw = data["password"]
			let user = data["username"]
			let script = JSGenerator(scriptName: "LoginFill")!.generate(with: ["pw": pw as AnyObject, "user": user as AnyObject])
			DispatchQueue.main.async {
				manager?.evaluate(script) { _, _ in
					if let completion = completion {
						DispatchQueue.main.async {
							completion()
						}
					}
				}
			}
		}
	}

	func promptForPasscode(for service: String, new: Bool, sourceView: UIView, in controller: UIViewController, completion: @escaping (String?) -> Void) {
		let items: [AnyObject]
		if new {
			let item = NSExtensionItem()
			item.userInfo = [appNameKey: "SnowHaze"]
			let request = [signupDataKey: [signupCredentialsKey], serviceKey: service] as NSDictionary
			item.attachments = [NSItemProvider(item: request, typeIdentifier: signupQueryKey)]
			items = [item]
		} else {
			items = [extensionItem(for: service), URL(string: service)! as NSURL]
		}
		let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
		activity.popoverPresentationController?.sourceRect = sourceView.bounds
		activity.popoverPresentationController?.sourceView = sourceView

		activity.completionWithItemsHandler = { type, _ , returnedItems, _ in
			guard self.isDashlaneResponse(type: type) else {
				completion(nil)
				return
			}
			guard let extensionItem = returnedItems?.first as? NSExtensionItem else {
				completion(nil)
				return
			}
			if new, let data = extensionItem.attachments!.first! as Any as? [String: String] {
				completion(data[passwordReplyKey])
			} else if !new {
				let provider = extensionItem.attachments!.first! 
				provider.loadItem(forTypeIdentifier: "com.apple.property-list") { nsdict, _ in
					guard let data = nsdict as? [String: String] else {
						completion(nil)
						return
					}
					DispatchQueue.main.async {
						completion(data["password"])
					}
				}
			}
		}
		controller.present(activity, animated: true, completion: nil)
	}
}
