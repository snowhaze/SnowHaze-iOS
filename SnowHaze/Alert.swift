//
//  Alert.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

enum AlertType {
	case update
	case tabActions(close: (() -> ())?, closeAll: (() -> ())?, new: () -> ())
	case jsAlert(domain: String, alert: String, completion: () -> ())
	case jsConfirm(domain: String, question: String, completion: (Bool) -> ())
	case jsPrompt(domain: String, question: String, default: String?, completion: (String?) -> ())
	case download(url: URL, file: String?, download: () -> ())
	case subscriptionNetworkError
	case subscriptionNoSuchAccountError
	case subscriptionEmailInUseError
	case subscriptionLogout
	case purchaseFailed(reason: String?)
	case preexistingSubscription(expiration: Date, renews: Bool, product: SubscriptionManager.Product)
	case deleteAllWebsiteData(count: Int, delete: () -> ())
	case deleteCacheWebsiteData(count: Int, delete: () -> ())
	case deleteCookieWebsiteData(count: Int, delete: () -> ())
	case deleteTrackingCookieWebsiteData(count: Int, delete: () -> ())
	case deleteOtherWebsiteData(count: Int, delete: () -> ())
	case resetSettings(reset: () -> ())
	case resetPageSettings(reset: () -> ())
	case clearHistory(clear: () -> ())
	case installOpenVPNForOpening
	case installOpenVPNForOVPNInstall(showTutorial: (UIAlertAction) -> ())
	case profileExpiration(multiple: Bool, expired: Bool, showVPNSettings: () -> ())
	case call(facetime: Bool, recipient: String, url: URL)
	case openApp(name: String, url: URL)
	case resubmit(url: URL?, completion: (Bool) -> ())
	case blockXSS(host: String?, completion: (Bool) -> ())
	case crossFrameNavigation(src: WKFrameInfo, target: WKFrameInfo, url: URL?, action: URLRequest, completion: (Bool) -> ())
	case paramStrip(url: URL, changes: [(name: String, value: String?)], completion: (Bool?) -> ())
	case dangerWarning(url: URL?, dangers: Set<Safebrowsing.Danger>, completion: (Bool) -> ())
	case invalidTLSCert(domain: String, completion: (Bool) -> ())
	case tlsDomainMismatch(domain: String, certDomain: String?, completion: (Bool) -> ())
	case httpAuthentication(realm: String?, domain: String, failCount: Int, secure: Bool, suggestion: URLCredential?, completion: (Bool, UIAlertController) -> ())

	private var title: String? {
		switch self {
			case .update:
				return NSLocalizedString("old snowhaze version prompt title", comment: "title of prompt to warn user that their snowhaze version is old")
			case .jsAlert(let domain, _, _):
				return domain
			case .jsConfirm(let domain, _, _):
				return domain
			case .jsPrompt(let domain, _, _, _):
				return domain
			case .download(_, _, _):
				return NSLocalizedString("file download confirmation prompt title", comment: "title of alert to confirm a file download")
			case .subscriptionNetworkError:
				return NSLocalizedString("subscription network error alert title", comment: "title of the alert to indicate that a subscription operation could not complete due to a network error")
			case .subscriptionNoSuchAccountError:
				return NSLocalizedString("subscription invalid account error alert title", comment: "title of the alert to indicate that a subscription operation could not complete due to the specified account not existing")
			case .subscriptionEmailInUseError:
				return NSLocalizedString("subscription email in use error alert title", comment: "title of the alert to indicate that a subscription operation could not complete due to the specified email already being in use")
			case .subscriptionLogout:
				return NSLocalizedString("subscription logout error alert title", comment: "title of the alert to indicate that a user's zka credentials have been rejected")
			case .purchaseFailed(_):
				return NSLocalizedString("purchase failed error alert title", comment: "title of alert to inform users that a purchase has failed")
			case .preexistingSubscription(_, _, _):
				return NSLocalizedString("preexisting subscription warning alert title", comment: "title of the alert to warn users that they are about to purchase a subscription that overlaps with a previous one")
			case .deleteAllWebsiteData(_, _):
				return NSLocalizedString("delete all data confirm dialog title", comment: "title for dialog to confirm deletion of all website data records")
			case .deleteCacheWebsiteData(_, _):
				return NSLocalizedString("delete all caches confirm dialog title", comment: "title for dialog to confirm deletion of all website cache records")
			case .deleteCookieWebsiteData(_, _):
				return NSLocalizedString("delete all cookies confirm dialog title", comment: "title for dialog to confirm deletion of all cookies")
			case .deleteTrackingCookieWebsiteData(_, _):
				return NSLocalizedString("delete tracking cookies confirm dialog title", comment: "title for dialog to confirm deletion of tracking cookies")
			case .deleteOtherWebsiteData(_, _):
				return NSLocalizedString("delete all data stores confirm dialog title", comment: "title for dialog to confirm deletion of all website data stores")
			case .resetSettings(_):
				return NSLocalizedString("reset global settings confirm dialog title", comment: "title for dialog to confirm resetting of global settings")
			case .resetPageSettings(_):
				return NSLocalizedString("reset page settings confirm dialog title", comment: "title for dialog to confirm resetting of per page settings")
			case .clearHistory(_):
				return NSLocalizedString("clear history confirm dialog title", comment: "title for dialog to confirm clearing of history")
			case .installOpenVPNForOpening:
				return NSLocalizedString("opening openvpn connect requires installing alert title", comment: "title of alert to point out that opening openvpn connect requires it being installed")
			case .installOpenVPNForOVPNInstall(_):
				return NSLocalizedString("installing ovpn requires openvpn connect alert title", comment: "title of alert to point out that installing a ovpn configuration requires openvpn connect")
			case .profileExpiration(let multiple, let expired, _):
				switch (multiple, expired) {
					case (false, true):
						return NSLocalizedString("vpn profile expiration warning single profile expired alert title", comment: "title of alert to warn users that a single installed VPN profile has expired")
					case (false, false):
						return NSLocalizedString("vpn profile expiration warning single profile expiring alert title", comment: "title of alert to warn users that a single installed VPN profile is about to expire")
					case (true, true):
						return NSLocalizedString("vpn profile expiration warning multiple profiles expired alert title", comment: "title of alert to warn users that multiple installed VPN profiles have expired")
					case (true, false):
						return NSLocalizedString("vpn profile expiration warning multiple profiles expiring alert title", comment: "title of alert to warn users that multiple installed VPN profiles are about to expire")
				}
			case .call(let faceTime, _, _):
				let facetimeTitle = NSLocalizedString("confirm facetime call dialog title", comment: "title of dialog used to confirm the user wants to initiate a facetime call")
				let phoneTitle = NSLocalizedString("confirm phone call dialog title", comment: "title of dialog used to confirm the user wants to initiate a phone call")
				return faceTime ? facetimeTitle : phoneTitle
			case .openApp(_, _):
				return NSLocalizedString("open url in app prompt title", comment: "title of prompt to ask users if they want to open another app")
			case .resubmit(_, _):
				return NSLocalizedString("form resubmission confirmation prompt title", comment: "title of prompt to ask users if they want to resubmit a form")
			case .blockXSS(_, _):
				return NSLocalizedString("block xss prompt title", comment: "title of prompt to block xss")
			case .crossFrameNavigation(_, _, _, _, _):
				return NSLocalizedString("cross frame navigation warning title", comment: "title of the cross frame navigation warning alert")
			case .paramStrip(_, _, _):
				return NSLocalizedString("tracking parameter found alert title", comment: "title of alert to warn users of url parameters identified as tracking parameters")
			case .dangerWarning(_, _, _):
				return NSLocalizedString("dangerous site warning alert title", comment: "title of alert to warn users of dangerous sites")
			case .invalidTLSCert(_, _):
				return NSLocalizedString("invalid certificate alert title", comment: "title of the alert that is displayed when trying to connect to a server with an invalid certificate")
			case .tlsDomainMismatch(_, _, _):
				return NSLocalizedString("certificate domain name mismatch alert title", comment: "title of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name")
			case .httpAuthentication(_, _, _, _, _, _):
				return NSLocalizedString("http authentication prompt title", comment: "title of prompt for http authentication")
			default:
				return nil
		}
	}

	private var message: String? {
		switch self {
			case .update:
				let fmt = NSLocalizedString("old snowhaze version prompt message format", comment: "format string of message of prompt to warn user that their snowhaze version is old")
				return String(format: fmt, versionDescription)
			case .jsAlert(_, let alert, _):
				return alert
			case .jsConfirm(_, let question, _):
				return question
			case .jsPrompt(_, let question, _, _):
				return question
			case .download(let url, let file, _):
				let fmt = NSLocalizedString("file download confirmation prompt message format", comment: "format of message of alert to confirm a file download")
				return String(format: fmt, file ?? url.lastPathComponent, url.absoluteString)
			case .subscriptionNetworkError:
				return NSLocalizedString("subscription network error alert message", comment: "message of the alert to indicate that a subscription operation could not complete due to a network error")
			case .subscriptionNoSuchAccountError:
				return NSLocalizedString("subscription invalid account error alert message", comment: "message of the alert to indicate that a subscription operation could not complete due to the specified account not existing")
			case .subscriptionEmailInUseError:
				return NSLocalizedString("subscription email in use error alert message", comment: "message of the alert to indicate that a subscription operation could not complete due to the specified email already being in use")
			case .subscriptionLogout:
				return NSLocalizedString("subscription logout error alert message", comment: "message of the alert to indicate that a user's zka credentials have been rejected")
			case .purchaseFailed(let reason):
				return reason ?? NSLocalizedString("purchase failed error alert unknown error message", comment: "displayed instead of the error message in the alert to inform users that a purchase has failed when the reason for the failure is unknown")
			case .preexistingSubscription(let expiration, let renews, let product):
				let renewFmt = NSLocalizedString("preexisting subscription warning alert renewing message format", comment: "format of message of the alert to warn users that they are about to purchase a subscription that overlaps with a previous one when the later renews")
				let expireFmt = NSLocalizedString("preexisting subscription warning alert expiring message format", comment: "format of message of the alert to warn users that they are about to purchase a subscription that overlaps with a previous one when the later expires")
				let formatter = DateFormatter()
				formatter.dateStyle = .long
				formatter.timeStyle = .short
				let date = formatter.string(from: expiration)
				return String(format: renews ? renewFmt : expireFmt, product.description, date)
			case .deleteAllWebsiteData(let count, _):
				let fmt = NSLocalizedString("delete all data message format", comment: "message format for dialog to confirm deletion of all website data records")
				return String(format: fmt, NumberFormatter().string(from: NSNumber(value: count))!)
			case .deleteCacheWebsiteData(let count, _):
				let fmt = NSLocalizedString("delete all caches message format", comment: "message format for dialog to confirm deletion of all website cache records")
				return String(format: fmt, NumberFormatter().string(from: NSNumber(value: count))!)
			case .deleteCookieWebsiteData(let count, _):
				let fmt = NSLocalizedString("delete all cookies message format", comment: "message format for dialog to confirm deletion of all cookies")
				return String(format: fmt, NumberFormatter().string(from: NSNumber(value: count))!)
			case .deleteTrackingCookieWebsiteData(let count, _):
				let fmt = NSLocalizedString("delete tracking cookies message format", comment: "message format for dialog to confirm deletion of tracking cookies")
				return String(format: fmt, NumberFormatter().string(from: NSNumber(value: count))!)
			case .deleteOtherWebsiteData(let count, _):
				let fmt = NSLocalizedString("delete all data stores message format", comment: "message format for dialog to confirm deletion of all website data stores")
				return String(format: fmt, NumberFormatter().string(from: NSNumber(value: count))!)
			case .resetSettings(_):
				return NSLocalizedString("reset global settings confirm dialog message", comment: "message for dialog to confirm resetting of global settings")
			case .resetPageSettings(_):
				return NSLocalizedString("reset page settings confirm dialog message", comment: "message for dialog to confirm resetting of per page settings")
			case .clearHistory(_):
				return NSLocalizedString("clear history confirm dialog message", comment: "message for dialog to confirm clearing of history")
			case .installOpenVPNForOpening:
				return NSLocalizedString("opening openvpn connect requires installing alert message", comment: "message of alert to point out that opening openvpn connect requires it being installed")
			case .installOpenVPNForOVPNInstall(_):
				return NSLocalizedString("installing ovpn requires openvpn connect alert message", comment: "message of alert to point out that installing a ovpn configuration requires openvpn connect")
			case .profileExpiration(let multiple, let expired, _):
				switch (multiple, expired) {
					case (false, true):
						return NSLocalizedString("vpn profile expiration warning single profile expired alert message", comment: "message of alert to warn users that a single installed VPN profile has expired")
					case (false, false):
						return NSLocalizedString("vpn profile expiration warning single profile expiring alert message", comment: "message of alert to warn users that a single installed VPN profile is about to expire")
					case (true, true):
						return NSLocalizedString("vpn profile expiration warning multiple profiles expired alert message", comment: "message of alert to warn users that multiple installed VPN profiles have expired")
					case (true, false):
						return NSLocalizedString("vpn profile expiration warning multiple profiles expiring alert message", comment: "message of alert to warn users that multiple installed VPN profiles are about to expire")
				}
			case .call(let facetime, let recipient, _):
				let facetimeFmt = NSLocalizedString("confirm facetime call dialog message format", comment: "format for message of dialog used to confirm the user wants to initiate a facetime call")
				let phoneFmt = NSLocalizedString("confirm phone call dialog message format", comment: "format for message of dialog used to confirm the user wants to initiate a phone call")
				return facetime ? String(format: facetimeFmt, recipient) : String(format: phoneFmt, recipient)
			case .openApp(let name, _):
				let fmt = NSLocalizedString("open url in app prompt format", comment: "format string used to ask users if they want to open another app")
				return String(format: fmt, name)
			case .resubmit(let url, _):
				if let url = url {
					let fmt = NSLocalizedString("form resubmission confirmation prompt format", comment: "format string of message of prompt to ask users if they want to resubmit a form")
					return String(format: fmt, url.absoluteString)
				} else {
					return NSLocalizedString("form resubmission confirmation prompt unknown url message", comment: "message of prompt to ask users if they want to resubmit a form when the destination is unknown")
				}
			case .blockXSS(let host, _):
				if let host = host {
					let fmt =  NSLocalizedString("block xss known host prompt format", comment: "format string of message of prompt to block xss on a known host")
					return String(format: fmt, host)
				} else {
					return NSLocalizedString("block xss unknown host prompt message", comment: "message of prompt to block xss on an unknown host")
				}
			case .crossFrameNavigation(let src, let target, let url, let action, _):
				func fmt(_ frame: WKFrameInfo, source: Bool) -> String {
					let fmt: String
					switch (frame.isMainFrame, source) {
						case (true, true):		fmt = NSLocalizedString("cross frame navigation warning main frame source format", comment: "format of descripiton of a main frame in the cross frame navigation warning alert when it is the source of the navigation")
						case (true, false):		fmt = NSLocalizedString("cross frame navigation warning main frame target format", comment: "format of descripiton of a main frame in the cross frame navigation warning alert when it is the target of the navigation")
						case (false, true):		fmt = NSLocalizedString("cross frame navigation warning frame source format", comment: "format of descripiton of a non-main frame in the cross frame navigation warning alert when it is the source of the navigation")
						case (false, false):	fmt = NSLocalizedString("cross frame navigation warning frame target format", comment: "format of descripiton of a non-main frame in the cross frame navigation warning alert when it is the target of the navigation")
					}
					let origin: String
					let secOrigin = frame.securityOrigin
					if secOrigin.port == 0 {
						origin = "\(secOrigin.protocol)://\(secOrigin.host)"
					} else {
						origin = "\(secOrigin.protocol)://\(secOrigin.host):\(secOrigin.port)"
					}
					return String(format: fmt, origin)
				}
				let format = NSLocalizedString("cross frame navigation warning message format", comment: "format of message of the cross frame navigation warning alert")
				let noURLPlaceholder = NSLocalizedString("cross frame navigation warning no url palcehoder", comment: "placeholder for missing urls in the cross frame navigation warning alert")
				let noTargetPlaceholder = NSLocalizedString("cross frame navigation warning no navigation destination palcehoder", comment: "placeholder for missing navigation destination in the cross frame navigation warning alert")
				let dst = action.url?.absoluteString ?? noTargetPlaceholder
				let srcURL = src.realRequest?.url?.absoluteString ?? noURLPlaceholder
				let targetURL = target.realRequest?.url?.absoluteString ?? noURLPlaceholder
				let pageURL = url?.absoluteString ?? noURLPlaceholder
				return String(format: format, fmt(src, source: true), fmt(target, source: false), dst, srcURL, targetURL, pageURL)
			case .paramStrip(let url, let changes, _):
				if let host = url.host, changes.count == 1 {
					let fmt = NSLocalizedString("tracking parameter found one parameter on known host alert format", comment: "format of message of alert to warn users of a single url parameter on a known host identified as a tracking parameter")
					return String(format: fmt, changes.first!.name, host)
				} else if changes.count == 1 {
					let fmt = NSLocalizedString("tracking parameter found one parameter on unknown host alert format", comment: "format of message of alert to warn users of a single url parameter on an unknown host identified as a tracking parameter")
					return String(format: fmt, changes.first!.name)
				} else {
					let separator = NSLocalizedString("tracking parameter found alert multiple parameters separator", comment: "separator used to separate multiple parameters in alert to warn users of url parameters identified as tracking parameters when three ore more where found")
					let last = changes.last!.name
					let rest = changes[0 ..< changes.count - 1].map( { $0.name } ).joined(separator: separator)
					if let host = url.host {
						let fmt = NSLocalizedString("tracking parameter found multiple parameters on known host alert format", comment: "format of message of alert to warn users of multiple url parameters on a known host identified as tracking parameters")
						return String(format: fmt, rest, last, host)
					} else {
						let fmt = NSLocalizedString("tracking parameter found multiple parameters on unknown host alert format", comment: "format of message of alert to warn users of multiple url parameters on an unknown host identified as tracking parameters")
						return String(format: fmt, rest, last)
					}
				}
			case .dangerWarning(let url, let dangerSet, _):
				let dangers = Array(dangerSet).sorted(by: { $0.rawValue < $1.rawValue })
				let safebrowsing = dangers.contains { $0.hasSafebrowsingSource }
				let warnings = dangers.sorted(by: { $0.order < $1.order }).map { danger -> String in
					switch danger {
						case .fingerprinting:
							return NSLocalizedString("fingerprinting site warning reason", comment: "explanation that the site is likely targeted by google safebrowsing fingerprinting")
						case .unspecified:
							return NSLocalizedString("unspecified site warning reason", comment: "explanation that the site might have unspecified dangerous content")
						case .malicious:
							return NSLocalizedString("malicious site warning reason", comment: "explanation that the site might have malicious content")
						case .phish:
							return NSLocalizedString("phishing site warning reason", comment: "explanation that the site might be a phishing site")
						case .phishGoogle:
							return NSLocalizedString("phishing site warning reason", comment: "explanation that the site might be a phishing site")
						case .malware:
							return NSLocalizedString("malware site warning reason", comment: "explanation that the site might contain malware")
						case .harmfulApplication:
							return NSLocalizedString("harmful application site warning reason", comment: "explanation that the site might contain harmful applications")
						case .unwantedSoftware:
							return NSLocalizedString("unwanted software site warning reason", comment: "explanation that the site might contain unwanted software")
						case .networkIssue:
							return NSLocalizedString("network issue site warning reason", comment: "explanation that the site was not checked against the current safebrosing list due to a network issue")
						case .offlineOnly:
							return NSLocalizedString("offline only site warning reason", comment: "explanation that the site was not checked against the current safebrosing list because other issues were already discovered")
						case .noSubscription:
							return NSLocalizedString("no subscription site warning reason", comment: "explanation that the site was not checked against the current safebrosing list due to the user not having a current subscription")

					}
				}
				let mainSeparator = NSLocalizedString("dangerous site warning reason list main separator", comment: "the separator used to separator most items in a (long) list of reasons a site might be dangerous. e.g. ', ' in 'a, b, c and d'")
				let finalSeparator = NSLocalizedString("dangerous site warning reason list final separator", comment: "the separator used to separator the last 2 items in a list of reasons a site might be dangerous. e.g. ' and ' in 'a, b, c and d'")
				let domain = url?.host ?? NSLocalizedString("dangerous site warning unknown domain name replacement", comment: "used instead of the domain name in the dangerous site warning if the domain is unknown")
				let format: String
				if !safebrowsing {
					format = NSLocalizedString("dangerous site warning alert message format", comment: "format string for the message of the dangerous site warning alert")
				} else if dangerSet.contains(.offlineOnly) {
					format = NSLocalizedString("offline safebrowsing dangerous site warning alert message format", comment: "format string for the message of the dangerous site warning alert when at least part of the warnings was generated by local google safebrowsing data")
				} else {
					format = NSLocalizedString("online safebrowsing dangerous site warning alert message format", comment: "format string for the message of the dangerous site warning alert when at least part of the warnings was generated by online google safebrowsing data")
				}
				let reasonList = warnings.sentenceJoined(mainSeparator: mainSeparator, finalSeparator: finalSeparator)
				return String(format: format, reasonList, domain)
			case .invalidTLSCert(let domain, _):
				let fmt = NSLocalizedString("invalid certificate alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with an invalid certificate")
				return String(format: fmt, domain)
			case .tlsDomainMismatch(let domain, let certDomain, _):
				if let certDomain = certDomain {
					let displayOriginalDomain: String
					if certDomain.hasPrefix("*.") {
						displayOriginalDomain = String(certDomain[certDomain.index(certDomain.startIndex, offsetBy: 2)...])
					} else {
						displayOriginalDomain = certDomain
					}
					let fmt = NSLocalizedString("certificate domain name mismatch known cert domain alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name and the domain the certificate was issued for is known")
					return String(format: fmt, domain, displayOriginalDomain)
				} else {
					let fmt = NSLocalizedString("certificate domain name mismatch unknown cert domain alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name and the domain the certificate was issued for is not available")
					return String(format: fmt, domain)
				}
			case .httpAuthentication(let realm, let domain, let failCount, let secure, _, _):
				let error = NSLocalizedString("http authentication prompt incorrect credentials notice", comment: "notice displayed in http authentication prompt when the specified credentials where incorrect")
				let errormsg = failCount == 0 ?  "" : (error + "\n\n")

				let prompt: String
				if let realm = realm {
					let format = NSLocalizedString("http authentication prompt existing realm prompt", comment: "prompt displayed in http authentication prompt when a realm is specified")
					prompt = String(format: format, realm, domain)
				} else {
					let format = NSLocalizedString("http authentication prompt missing realm prompt", comment: "prompt displayed in http authentication prompt when no realm is specified")
					prompt = String(format: format, domain)
				}

				let warn = NSLocalizedString("http authentication prompt insecure transmission warning", comment: "warning displayed when credentials entered in http authentication prompt will be transmitted insecurely")
				let warning = secure ? "" : ("\n\n" + warn)
				return errormsg + prompt + warning
			default:
				return nil
		}
	}

	private var numberOfActions: Int {
		switch self {
			case .tabActions(_, _, _):						return 4
			case .jsAlert(_, _, _):							return 1
			case .subscriptionNetworkError:					return 1
			case .subscriptionNoSuchAccountError:			return 1
			case .subscriptionEmailInUseError:				return 1
			case .subscriptionLogout:						return 1
			case .purchaseFailed(_):						return 1
			case .installOpenVPNForOVPNInstall(_):			return 3
			case .paramStrip(_, _, _):						return 3
			default:										return 2
		}
	}

	private var style: UIAlertController.Style {
		switch self {
			case .tabActions(_, _, _):						return .actionSheet
			case .download(_, _, _):						return .actionSheet
			case .deleteAllWebsiteData(_, _):				return .actionSheet
			case .deleteCacheWebsiteData(_, _):				return .actionSheet
			case .deleteCookieWebsiteData(_, _):			return .actionSheet
			case .deleteTrackingCookieWebsiteData(_, _):	return .actionSheet
			case .deleteOtherWebsiteData(_, _):				return .actionSheet
			case .resetSettings(_):							return .actionSheet
			case .resetPageSettings(_):						return .actionSheet
			case .clearHistory(_):							return .actionSheet
			default:										return .alert
		}
	}

	private func actionEnabled(at index: Int) -> Bool {
		switch (self, index) {
			case (.tabActions(let close, _, _), 0):			return close != nil
			case (.tabActions(_, let closeAll, _), 1):		return closeAll != nil

			default:										return true
		}
	}

	private func actionTitle(at index: Int) -> String {
		switch (self, index) {
			case (.update, 0):
				return NSLocalizedString("old snowhaze version prompt update button title", comment: "title of button to lead users to the app store to update snowhaze")
			case (.update, 1):
				return NSLocalizedString("old snowhaze version prompt ignore button title", comment: "title of button to ignore old snowhaze version warning")

			case (.tabActions(_, _, _), 0):
				return NSLocalizedString("close tab tab menu option title", comment: "title of option in the tab menu to close the current tab")
			case (.tabActions(_, _, _), 1):
				return NSLocalizedString("close all tabs tab menu option title", comment: "title of option in the tab menu to close all tabs")
			case (.tabActions(_, _, _), 2):
				return NSLocalizedString("new tab tab menu option title", comment: "title of option in the tab menu to create a new tab")
			case (.tabActions(_, _, _), 3):
				return NSLocalizedString("cancel tab menu option title", comment: "title of option in the tab menu to close the menu")

			case (.jsAlert(_, _, _), 0):
				return NSLocalizedString("js alert panel confirmation button title", comment: "title of button to confirm a js alert")

			case (.jsConfirm(_, _, _), 0):
				return NSLocalizedString("js confirm panel confirm button title", comment: "title of button to confirm a js confirmation dialog")
			case (.jsConfirm(_, _, _), 1):
			   return NSLocalizedString("js confirm panel cancel button title", comment: "title of button to cancel a js confirmation dialog")

			case (.jsPrompt(_, _, _, _), 0):
				return NSLocalizedString("js text prompt confirm button title", comment: "title of button to confirm a js text prompt")
			case (.jsPrompt(_, _, _, _), 1):
				return NSLocalizedString("js text prompt cancel button title", comment: "title of button to cancel a js text prompt")

			case (.download(_, _, _), 0):
				return NSLocalizedString("file download confirmation prompt download button title", comment: "title of download button of alert to confirm a file download")
			case (.download(_, _, _), 1):
				return NSLocalizedString("file download confirmation prompt cancel button title", comment: "title of cancel button of alert to confirm a file download")

			case (.subscriptionNetworkError, 0):
				return NSLocalizedString("subscription network error alert ok button title", comment: "title of the ok button of the alert to indicate that a subscription operation could not complete due to a network error")
			case (.subscriptionNoSuchAccountError, 0):
				return NSLocalizedString("subscription invalid account error alert ok button title", comment: "title of the ok button of the alert to indicate that a subscription operation could not complete due to the specified account not existing")
			case (.subscriptionEmailInUseError, 0):
				return NSLocalizedString("subscription email in use error alert ok button title", comment: "title of the ok button of the alert to indicate that a subscription operation could not complete due to the specified email already being in use")
			case (.subscriptionLogout, 0):
				return NSLocalizedString("subscription logout error alert ok button title", comment: "title of the ok button of the alert to indicate that a user's zka credentials have been rejected")

			case (.purchaseFailed(_), 0):
				return NSLocalizedString("purchase failed error alert ok button title", comment: "title of the ok button of the alert to inform users that a purchase has failed")

			case (.preexistingSubscription(_, _, _), 0):
				return NSLocalizedString("preexisting subscription warning alert confirm button title", comment: "title of the button to confirm purchase on the alert to warn users that they are about to purchase a subscription that overlaps with a previous one")
			case (.preexistingSubscription(_, _, _), 1):
				return NSLocalizedString("preexisting subscription warning alert cancel button title", comment: "title of the button to cancel purchase on the alert to warn users that they are about to purchase a subscription that overlaps with a previous one")

			case (.deleteAllWebsiteData(_, _), 0):
				return NSLocalizedString("delete all data confirm option title", comment: "title for confirm option of dialog to confirm deletion of all website data records")
			case (.deleteAllWebsiteData(_, _), 1):
				return NSLocalizedString("delete all data cancel option title", comment: "title for confirm option of dialog to cancel deletion of all website data records")

			case (.deleteCacheWebsiteData(_, _), 0):
				return NSLocalizedString("delete all caches confirm option title", comment: "title for confirm option of dialog to confirm deletion of all website cache records")
			case (.deleteCacheWebsiteData(_, _), 1):
				return NSLocalizedString("delete all caches cancel option title", comment: "title for confirm option of dialog to cancel deletion of all website cache records")

			case (.deleteCookieWebsiteData(_, _), 0):
				return NSLocalizedString("delete all cookies confirm option title", comment: "title for confirm option of dialog to confirm deletion of all cookies")
			case (.deleteCookieWebsiteData(_, _), 1):
				return NSLocalizedString("delete all cookies cancel option title", comment: "title for confirm option of dialog to cancel deletion of all cookies")

			case (.deleteTrackingCookieWebsiteData(_, _), 0):
				return NSLocalizedString("delete tracking cookies confirm option title", comment: "title for confirm option of dialog to confirm deletion of tracking cookies")
			case (.deleteTrackingCookieWebsiteData(_, _), 1):
				return NSLocalizedString("delete tracking cookies cancel option title", comment: "title for confirm option of dialog to cancel deletion of tracking cookies")

			case (.deleteOtherWebsiteData(_, _), 0):
				return NSLocalizedString("delete all data stores confirm option title", comment: "title for confirm option of dialog to confirm deletion of all website data stores")
			case (.deleteOtherWebsiteData(_, _), 1):
				return NSLocalizedString("delete all data stores cancel option title", comment: "title for confirm option of dialog to cancel deletion of all website data stores")

			case (.resetSettings(_), 0):
				return NSLocalizedString("reset global settings confirm dialog confirm option title", comment: "title for confirm option of dialog to confirm resetting of global settings")
			case (.resetSettings(_), 1):
				return NSLocalizedString("reset global settings confirm dialog cancel option title", comment: "title for cancel option of dialog to confirm resetting of global settings")

			case (.resetPageSettings(_), 0):
				return NSLocalizedString("reset page settings confirm dialog confirm option title", comment: "title for confirm option of dialog to confirm resetting of per page settings")
			case (.resetPageSettings(_), 1):
				return NSLocalizedString("reset page settings confirm dialog cancel option title", comment: "title for cancel option of dialog to confirm resetting of per page settings")

			case (.clearHistory(_), 0):
				return NSLocalizedString("clear history confirm dialog confirm option title", comment: "title for confirm option of dialog to confirm clearing of history")
			case (.clearHistory(_), 1):
				return NSLocalizedString("clear history confirm dialog cancel option title", comment: "title for cancel option of dialog to confirm clearing of history")

			case (.installOpenVPNForOpening, 0):
				return NSLocalizedString("install openvpn connect app prompt ok button title", comment: "title of ok button of prompt to ask users if they want to install the openvpn connect app")
			case (.installOpenVPNForOpening, 1):
				return NSLocalizedString("install openvpn connect app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to install the openvpn connect app")

			case (.installOpenVPNForOVPNInstall(_), 0):
				return NSLocalizedString("install openvpn connect app prompt ok button title", comment: "title of ok button of prompt to ask users if they want to install the openvpn connect app")
			case (.installOpenVPNForOVPNInstall(_), 1):
				return NSLocalizedString("install openvpn show tutorial button title", comment: "title of the show tutorial button of prompt to ask users if they want to install the openvpn connect app")
			case (.installOpenVPNForOVPNInstall(_), 2):
				return NSLocalizedString("install openvpn connect app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to install the openvpn connect app")

			case (.profileExpiration(_, _, _), 0):
				return NSLocalizedString("vpn profile expiration warning alert vpn settings button title", comment: "title of vpn settings button of alert to warn users of VPN profile expiration")
			case (.profileExpiration(_, _, _), 1):
				return NSLocalizedString("vpn profile expiration warning alert ignore button title", comment: "title of ignore button of alert to warn users of VPN profile expiration")

			case (.call(_, _, _), 0):
				return NSLocalizedString("confirm call dialog confirm button title", comment: "title of confirm button of dialog used to confirm the user wants to initiate a call")
			case (.call(_, _, _), 1):
				return NSLocalizedString("cancel call dialog confirm button title", comment: "title of cancel button of dialog used to confirm the user wants to initiate a call")

			case (.openApp(_, _), 0):
				return NSLocalizedString("open url in app prompt confirm button title", comment: "title of confirm button of prompt to ask users if they want to open another app")
			case (.openApp(_, _), 1):
				return NSLocalizedString("open url in app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to open another app")

			case (.resubmit(_, _), 0):
				return NSLocalizedString("form resubmission confirmation prompt confirm button title", comment: "title of confirm button of prompt to ask users if they want to resubmit a form")
			case (.resubmit(_, _), 1):
				return NSLocalizedString("form resubmission confirmation prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to resubmit a form")

			case (.blockXSS(_, _), 0):
				return NSLocalizedString("block xss unknown host prompt load action title", comment: "title of load action of prompt to block xss on an unknown host")
			case (.blockXSS(_, _), 1):
				return NSLocalizedString("block xss unknown host prompt block action title", comment: "title of block action of prompt to block xss on an unknown host")

			case (.crossFrameNavigation(_, _, _, _, _), 0):
				return NSLocalizedString("cross frame navigation warning allow button title", comment: "title of the allow button in the cross frame navigation warning alert")
			case (.crossFrameNavigation(_, _, _, _, _), 1):
				return NSLocalizedString("cross frame navigation warning block button title", comment: "title of the block button in the cross frame navigation warning alert")

			case (.paramStrip(_, _, _), 0):
				return NSLocalizedString("tracking parameter found alert ignore option title", comment: "title of ignore action of alert to warn users of url parameters identified as tracking parameters")
			case (.paramStrip(_, _, _), 1):
				return NSLocalizedString("tracking parameter found alert strip option title", comment: "title of strip action of alert to warn users of url parameters identified as tracking parameters")
			case (.paramStrip(_, _, _), 2):
				return NSLocalizedString("tracking parameter found alert cancel option title", comment: "title of cancel action of alert to warn users of url parameters identified as tracking parameters")

			case (.dangerWarning(_, _, _), 0):
				return NSLocalizedString("dangerous site warning alert continue button title", comment: "title of the continue button of the alert to warn users of dangerous sites")
			case (.dangerWarning(_, _, _), 1):
				return NSLocalizedString("dangerous site warning alert cancel button title", comment: "title of the cancel button of the alert to warn users of dangerous sites")

			case (.invalidTLSCert(_, _), 0):
				return NSLocalizedString("invalid certificate alert continue button title", comment: "title of continue button of the alert that is displayed when trying to connect to a server with an invalid certificate")
			case (.invalidTLSCert(_, _), 1):
				return NSLocalizedString("invalid certificate alert cancel button title", comment: "title of cancel button of the alert that is displayed when trying to connect to a server with an invalid certificate")

			case (.tlsDomainMismatch(_, _, _), 0):
				return NSLocalizedString("certificate domain name mismatch alert continue button title", comment: "title of continue button of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name")
			case (.tlsDomainMismatch(_, _, _), 1):
				return NSLocalizedString("invalid certificate alert cancel button title", comment: "title of cancel button of the alert that is displayed when trying to connect to a server with an invalid certificate")

			case (.httpAuthentication(_, _, _, _, _, _), 0):
				return NSLocalizedString("http authentication prompt continue button title", comment: "title of continue button of http authentication prompt")
			case (.httpAuthentication(_, _, _, _, _, _), 1):
				return NSLocalizedString("http authentication prompt cancel button title", comment: "title of cancel button of http authentication prompt")

			default:	fatalError()
		}
	}

	private func actionStyle(at index: Int) -> UIAlertAction.Style {
		switch (self, index) {
			case (.update, 1):	return .cancel

			case (.tabActions(_, _, _), 0):						return .destructive
			case (.tabActions(_, _, _), 1):						return .destructive
			case (.tabActions(_, _, _), 3):						return .cancel

			case (.jsConfirm(_, _, _), 1):						return .cancel

			case (.jsPrompt(_, _, _, _), 1):					return .cancel

			case (.download(_, _, _), 1):						return .cancel

			case (.preexistingSubscription(_, _, _), 1):		return .cancel

			case (.deleteAllWebsiteData(_, _), 0):				return .destructive
			case (.deleteAllWebsiteData(_, _), 1):				return .cancel

			case (.deleteCacheWebsiteData(_, _), 0):			return .destructive
			case (.deleteCacheWebsiteData(_, _), 1):			return .cancel

			case (.deleteCookieWebsiteData(_, _), 0):			return .destructive
			case (.deleteCookieWebsiteData(_, _), 1):			return .cancel

			case (.deleteTrackingCookieWebsiteData(_, _), 0):	return .destructive
			case (.deleteTrackingCookieWebsiteData(_, _), 1):	return .cancel

			case (.deleteOtherWebsiteData(_, _), 0):			return .destructive
			case (.deleteOtherWebsiteData(_, _), 1):			return .cancel

			case (.resetSettings(_), 0):						return .destructive
			case (.resetSettings(_), 1):						return .cancel

			case (.resetPageSettings(_), 0):					return .destructive
			case (.resetPageSettings(_), 1):					return .cancel

			case (.clearHistory(_), 0):							return .destructive
			case (.clearHistory(_), 1):							return .cancel

			case (.installOpenVPNForOpening, 1):				return .cancel

			case (.installOpenVPNForOVPNInstall(_), 2):			return .cancel

			case (.profileExpiration(_, _, _), 1):				return .cancel

			case (.call(_, _, _), 1):							return .cancel

			case (.openApp(_, _), 1):							return .cancel

			case (.resubmit(_, _), 1):							return .cancel

			case (.blockXSS(_, _), 1):							return .cancel

			case (.crossFrameNavigation(_, _, _, _, _), 1):		return .cancel

			case (.paramStrip(_, _, _), 2):						return .cancel

			case (.dangerWarning(_, _, _), 1):					return .cancel

			case (.invalidTLSCert(_, _), 1):					return .cancel

			case (.httpAuthentication(_, _, _, _, _, _), 1):	return .cancel

			default:											return .default
		}
	}

	private func actionHandler(at index: Int) -> ((UIAlertAction, UIAlertController) -> ())? {
		switch (self, index) {
			case (.update, 0):
				return { _, _ in
					UIApplication.shared.open(URL(string: "https://itunes.apple.com/app/id1121026941")!)
					PolicyManager.globalManager().updateEOLWarningVersion()
				}
			case (.update, 1):
				return { _, _ in PolicyManager.globalManager().updateEOLWarningVersion() }

			case (.tabActions(let close, _, _), 0):
				return { _, _ in close!() }
			case (.tabActions(_, let closeAll, _), 1):
				return { _, _ in closeAll!() }
			case (.tabActions(_, _, let new), 2):
				return { _, _ in new() }

			case (.jsAlert(_, _, let completion), 0):
				return { _, _ in completion() }

			case (.jsConfirm(_, _, let completion), 0):
				return { _, _ in completion(true) }
			case (.jsConfirm(_, _, let completion), 1):
				return { _, _ in completion(false) }

			case (.jsPrompt(_, _, _, let completion), 0):
				return { _, alert in completion(alert.textFields![0].text) }
			case (.jsPrompt(_, _, _, let completion), 1):
				return { _, _ in completion(nil) }

			case (.download(_, _, let download), 0):
				return { _, _ in download() }

			case (.preexistingSubscription(_, _, let product), 0):
				return { _, _ in SubscriptionManager.shared.purchase(product, force: true) }

			case (.deleteAllWebsiteData(_, let delete), 0):
				return { _, _ in delete() }

			case (.deleteCacheWebsiteData(_, let delete), 0):
				return { _, _ in delete() }

			case (.deleteCookieWebsiteData(_, let delete), 0):
				return { _, _ in delete() }

			case (.deleteTrackingCookieWebsiteData(_, let delete), 0):
				return { _, _ in delete() }

			case (.deleteOtherWebsiteData(_, let delete), 0):
				return { _, _ in delete() }

			case (.resetSettings(let reset), 0):
				return { _, _ in reset() }

			case (.resetPageSettings(let reset), 0):
				return { _, _ in reset() }

			case (.clearHistory(let clear), 0):
				return { _, _ in clear() }

			case (.installOpenVPNForOpening, 0):
				return { _, _ in UIApplication.shared.open(URL(string: "https://itunes.apple.com/app/id590379981")!) }

			case (.installOpenVPNForOVPNInstall(_), 0):
				return { _, _ in UIApplication.shared.open(URL(string: "https://itunes.apple.com/app/id590379981")!) }
			case (.installOpenVPNForOVPNInstall(let showTutorial), 1):
				return { action, _ in showTutorial(action) }

			case (.profileExpiration(_, _, let showVPNSetting), 0):
				return { _, _ in showVPNSetting() }

			case (.call(_, _, let url), 0):
				return { _, _ in UIApplication.shared.open(url) }

			case (.openApp(_, let url), 0):
				return { _, _ in UIApplication.shared.open(url) }

			case (.resubmit(_, let completion), 0):
				return { _, _ in completion(true) }
			case (.resubmit(_, let completion), 1):
				return { _, _ in completion(false) }

			case (.blockXSS(_, let completion), 0):
				return { _, _ in completion(true) }
			case (.blockXSS(_, let completion), 1):
				return { _, _ in completion(false) }

			case (.crossFrameNavigation(_, _, _, _, let completion), 0):
				return { _, _ in completion(true) }
			case (.crossFrameNavigation(_, _, _, _, let completion), 1):
				return { _, _ in completion(false) }

			case (.paramStrip(_, _, let completion), 0):
				return { _, _ in completion(true) }
			case (.paramStrip(_, _, let completion), 1):
				return { _, _ in completion(nil) }
			case (.paramStrip(_, _, let completion), 2):
				return { _, _ in completion(false) }

			case (.dangerWarning(_, _, let completion), 0):
				return { _, _ in completion(true) }
			case (.dangerWarning(_, _, let completion), 1):
				return { _, _ in completion(false) }

			case (.invalidTLSCert(_, let completion), 0):
				return { _, _ in completion(true) }
			case (.invalidTLSCert(_, let completion), 1):
				return { _, _ in completion(false) }

			case (.tlsDomainMismatch(_, _, let completion), 0):
				return { _, _ in completion(true) }
			case (.tlsDomainMismatch(_, _, let completion), 1):
				return { _, _ in completion(false) }

			case (.httpAuthentication(_, _, _, _, _, let completion), 0):
				return { _, alert in completion(true, alert) }
			case (.httpAuthentication(_, _, _, _, _, let completion), 1):
				return { _, alert in completion(false, alert) }

			default:			return nil
		}
	}

	private var numberOfTextFields: Int {
		switch self {
			case .jsPrompt(_, _, _, _):					return 1
			case .httpAuthentication(_, _, _, _, _, _):	return 2
			default:									return 0
		}
	}

	private func configure(_ textField: UITextField, at index: Int) {
		switch (self, index) {
			case (.jsPrompt(_, _, let defaultText, _), 0):
				textField.placeholder = defaultText
				textField.autocapitalizationType = .words
				textField.autocorrectionType = .yes

			case (.httpAuthentication(_, _, _, _, let suggestion, _), 0):
				let username = NSLocalizedString("http authentication prompt username placeholder", comment: "placeholder for username in prompt for http authentication")
				textField.placeholder = username
				textField.text = suggestion?.user
			case (.httpAuthentication(_, _, _, _, let suggestion, _), 1):
				let password = NSLocalizedString("http authentication prompt password placeholder", comment: "placeholder for password in prompt for http authentication")
				textField.placeholder = password
				textField.isSecureTextEntry = true
				textField.text = suggestion?.password

			default:	fatalError()
		}
	}

	func build(with additionalAction: UIAlertAction? = nil, at insertIndex: Int = 0) -> UIAlertController {
		let alert = UIAlertController(title: title, message: message, preferredStyle: style)
		for i in 0 ..< numberOfTextFields {
			alert.addTextField { textField in
				configure(textField, at: i)
			}
		}
		if let action = additionalAction, insertIndex == -1 - numberOfActions {
			alert.addAction(action)
		}
		for i in 0 ..< numberOfActions where actionEnabled(at: i) {
			if let action = additionalAction, insertIndex == i {
				alert.addAction(action)
			}
			let handler = actionHandler(at: i)
			let action = UIAlertAction(title: actionTitle(at: i), style: actionStyle(at: i)) { [weak alert] action in handler?(action, alert!) }
			alert.addAction(action)
			if let action = additionalAction, i == numberOfActions + insertIndex {
				alert.addAction(action)
			}
		}
		return alert
	}
}
