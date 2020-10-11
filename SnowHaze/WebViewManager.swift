//
//  WebViewManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

enum InputType {
	case plainInput
	case url
}

struct HTTPSUpgradeState {
	private(set) var url: URL? = nil
	private var count: Int = 0

	mutating func set(_ url: URL) {
		self.url = url
		count = 3
	}

	mutating func dec() {
		count -= 1
		if count <= 0 {
			url = nil
			count = 0
		}
	}

	mutating func reset() {
		count = 0
		url = nil
	}
}

enum WebLoadType {
	case userInput(String)
	case url(URL)
}
protocol WebViewManager: WKScriptMessageHandler, TorSchemeHandlerDelegate, WKNavigationDelegate {
	var webView: WKWebView { get }
	var tab: Tab { get }
	var securityCookie: String { get }

	func load(_ type: WebLoadType)
	func load(input: String, type: InputType)
	func load(url: URL?)
	func load(userInput: String)
}

extension WebViewManager {
	func torSchemeHandler(_ handler: TorSchemeHandler, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		guard let _ = webView?(webView, didReceive: challenge, completionHandler: completionHandler) else {
			completionHandler(.performDefaultHandling, nil)
			return
		}
	}
}

extension WebViewManager {
	func load(input: String, type: InputType) {
		switch type {
			case .url:			load(url: URL(string: input))
			case .plainInput:	load(userInput: input)
		}
	}
}

// Public
extension WebViewManager {
	func enableJS() -> (() -> ())? {
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		guard policy.allowApplicationJS else {
			return nil
		}
		if #available(iOS 14, *) {
			// javascript is controlled by the webview's navigation delegate
		} else {
			webView.configuration.preferences.javaScriptEnabled = true
		}
		let blockGuard = BlockCallGuard()
		let ret: () -> () = {
			blockGuard.called()
			let policy = PolicyManager.manager(for: self.webView.url, in: self.tab)
			if #available(iOS 14, *) {
				// javascript is controlled by the webview's navigation delegate
			} else {
				self.webView.configuration.preferences.javaScriptEnabled = policy.allowJS
			}
		}
		return ret
	}

	@discardableResult func enableJS(for block: () -> ()) -> Bool {
		guard let disable = enableJS() else {
			return false
		}
		block()
		disable()
		return true
	}

	@discardableResult func evaluate(_ script: String?, completionHandler: ((Any?, Error?) -> ())? = nil) -> Bool {
		guard let script = script else {
			return false
		}
		let result = enableJS {
			webView.evaluateJavaScript(script, completionHandler: completionHandler)
		}
		return result
	}

	func load(_ type: WebLoadType) {
		switch type {
			case .url(let url):			load(url: url)
			case .userInput(let input):	load(userInput: input)
		}
	}
}

// Internals. Only intended for classes implementing WebViewManager
internal extension WebViewManager {
	func upgradeURL(for url: URL?, navigationAction: WKNavigationAction) -> URL? {
		guard let url = url, let frame = navigationAction.targetFrame , frame.isMainFrame else {
			return nil
		}
		guard navigationAction.request.isHTTPGet else {
			return nil
		}
		guard let domain = url.host , url.normalizedScheme == "http" else {
			return nil
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		let httpsSites = DomainList(type: policy.useHTTPSExclusivelyWhenPossible ? .httpsSites: .empty)
		guard httpsSites.contains(domain) || policy.trustedSiteUpdateRequired else {
			return nil
		}
		var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
		components.scheme = "https"
		return components.url
	}

	func update(policy: PolicyManager, webView: WKWebView) {
		if #available(iOS 14, *) {
			// javascript settings are applied in the call back in
			// webView(_:, decidePolicyFor: , preferences: , decisionHandler: )
		} else {
			webView.configuration.preferences.javaScriptEnabled = policy.allowJS
		}
		webView.configuration.userContentController.removeAllUserScripts()
		webView.configuration.preferences.minimumFontSize = policy.minFontSize
		webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = policy.allowAutomaticJSPopovers
		policy.userScripts(with: securityCookie, for: tab).forEach { webView.configuration.userContentController.addUserScript($0) }
		webView.configuration.userContentController.removeAllContentRuleLists()
		policy.withEnabledContentRuleLists(for: tab) { lists, replacements in
			lists.forEach { webView.configuration.userContentController.add($0) }
			replacements.forEach { webView.configuration.userContentController.addUserScript($0) }
		}
	}

	func rawLoad(_ request: URLRequest, in webView: WKWebView?) {
		guard let webView = webView else {
			return
		}
		let jsSchemePrefix = "javascript:"
		if request.url?.normalizedScheme == "javascript" && request.url?.absoluteString.lowercased().hasPrefix(jsSchemePrefix) ?? false {
			let policy = PolicyManager.manager(for: self.webView.url, in: self.tab)
			if policy.allowJSURLsInURLBar {
				let url = request.url!.absoluteString
				let substring = url[url.index(url.startIndex, offsetBy: jsSchemePrefix.count) ..< url.endIndex]
				let js = substring.removingPercentEncoding ?? String(substring)
				if #available(iOS 14, *) {
					// javascript is controlled by the webview's navigation delegate
					webView.evaluateJavaScript(js)
				} else {
					webView.configuration.preferences.javaScriptEnabled = true
					webView.evaluateJavaScript(js)
					webView.configuration.preferences.javaScriptEnabled = policy.allowJS
				}
			} else {
				webView.loadHTMLString(BrowserPageGenerator(type: .jsUrlBlocked).getHTML(), baseURL: nil)
			}
		} else {
			var request = request
			if tab.useTor {
				request.url = request.url?.torified
			}
			webView.load(request)
		}
	}

	func didReceive(scriptMessage message: WKScriptMessage, from userContentController: WKUserContentController) {
		print(message)
	}
}
