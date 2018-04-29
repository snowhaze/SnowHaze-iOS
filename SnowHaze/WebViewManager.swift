//
//  WebViewManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

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

protocol WebViewManager: class {
	var webView: WKWebView { get }
	var tab: Tab { get }
}

private class BlockCallGuard {
	var called = false
	deinit {
		guard called else {
			fatalError("Block Was not Called")
		}
	}
}

// Public
extension WebViewManager {
	func enableJS() -> (() -> Void)? {
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		guard policy.allowApplicationJS else {
			return nil
		}
		webView.configuration.preferences.javaScriptEnabled = true
		let blockGuard = BlockCallGuard()
		let ret: () -> Void = {
			blockGuard.called = true
			let policy = PolicyManager.manager(for: self.webView.url, in: self.tab)
			self.webView.configuration.preferences.javaScriptEnabled = policy.allowJS
		}
		return ret
	}

	@discardableResult func enableJS(for block: () -> Void) -> Bool {
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		guard policy.allowApplicationJS else {
			return false
		}
		webView.configuration.preferences.javaScriptEnabled = true
		block()
		webView.configuration.preferences.javaScriptEnabled = policy.allowJS
		return true
	}

	@discardableResult func evaluate(_ script: String?, completionHandler: ((Any?, Error?) -> Void)?) -> Bool {
		guard let script = script else {
			return false
		}
		let result = enableJS {
			webView.evaluateJavaScript(script, completionHandler: completionHandler)
		}
		return result
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
		guard let domain = url.host , url.scheme?.lowercased() == "http" else {
			return nil
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		guard policy.useHTTPSExclusivelyWhenPossible && DomainList(type: .httpsSites).contains(domain) else {
			return nil
		}
		var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		components.scheme = "https"
		return components.url
	}

	func update(policy: PolicyManager, webView: WKWebView) {
		webView.configuration.preferences.javaScriptEnabled = policy.allowJS
		webView.configuration.userContentController.removeAllUserScripts()
		webView.configuration.preferences.minimumFontSize = policy.minFontSize
		webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = policy.allowAutomaticJSPopovers
		policy.userScripts.forEach { webView.configuration.userContentController.addUserScript($0) }
		if #available(iOS 11, *) {
			webView.configuration.userContentController.removeAllContentRuleLists()
			policy.withEnabledContentRuleLists { lists, replacements in
				lists.forEach { webView.configuration.userContentController.add($0) }
				replacements.forEach { webView.configuration.userContentController.addUserScript($0) }
			}
		}
	}
}
