//
//  WorkerWebViewManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

protocol WorkerWebViewManagerDelegate: class {
	func webViewManagerDidFailLoad(_ manager: WorkerWebViewManager)
	func webViewManagerDidFinishLoad(_ manager: WorkerWebViewManager)
	func webViewManager(_ manager: WorkerWebViewManager, didMakeProgress progress: Double)
}

extension WorkerWebViewManagerDelegate {
	func webViewManagerDidFailLoad(_ manager: WorkerWebViewManager) { }
	func webViewManagerDidFinishLoad(_ manager: WorkerWebViewManager) { }
}

class WorkerWebViewManager: NSObject, WebViewManager {
	let timeout: TimeInterval = 15
	let tab: Tab
	weak var delegate: WorkerWebViewManagerDelegate?

	private var dec: (() -> Void)?
	private var waitingSnowHazeSearch: String?
	private var observer: NSObjectProtocol?

	var lastUpgrade = HTTPSUpgradeState()

	private var actionTryList: [PolicyManager.Action] = []

	init(tab: Tab) {
		self.tab = tab
	}

	private var observations = Set<NSKeyValueObservation>()

	private(set) lazy var webView: WKWebView = {
		let policy = PolicyManager.manager(for: self.tab)
		let config = policy.webViewConfiguration
		let store = self.tab.controller?.dataStore ?? (PolicyManager.manager(for: self.tab).dataStore, WKProcessPool())
		(config.websiteDataStore, config.processPool) = store
		let ret = WKWebView(frame: CGRect.zero, configuration: config)
		ret.allowsLinkPreview = false
		ret.customUserAgent = self.tab.controller?.userAgent ?? policy.userAgent
		ret.navigationDelegate = self
		ret.backgroundColor = .background

		DispatchQueue.main.async {
			self.observations.insert(ret.observe(\.estimatedProgress, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.delegate?.webViewManager(me, didMakeProgress: webView.estimatedProgress)
				}
			}))

			self.observations.insert(ret.observe(\.loading, options: .initial, changeHandler: { [weak self] webView, _ in
				if webView.isLoading {
					self?.dec = InUseCounter.network.inc()
				} else {
					self?.dec?()
					self?.dec = nil
				}
			}))
		}
		self.observations.insert(ret.observe(\.URL, options: .initial, changeHandler: { [weak self] webView, _ in
			self?.update(for: webView.url, webView: webView)
		}))
		return ret
	}()

	func load(userInput input: String) {
		let policy = PolicyManager.manager(for: tab)
		load(policy.actionList(for: input))
	}

	func load(url: URL?) {
		if let url = url {
			load([.load(url)])
		}
	}

	func load(request: URLRequest) {
		waitingSnowHazeSearch = nil
		update(for: request.url, webView: webView)
		webView.load(request)
	}

	private func load(_ list: [PolicyManager.Action]) {
		lastUpgrade.reset()
		actionTryList.removeAll()
		webView.stopLoading()
		actionTryList = list
		if actionTryList.isEmpty {
			return
		}
		let action = actionTryList.removeFirst()
		switch action {
			case .load(let url):
				let request = actionTryList.isEmpty ? URLRequest(url: url) : URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
				load(request: request)
			case .getTokenForSearch(let search):
				assert(actionTryList.isEmpty)
				waitForToken(with: search)
		}
	}

	deinit {
		if let observer = observer {
			NotificationCenter.default.removeObserver(observer)
		}
		webView.stopLoading()
		dec?()
	}
}

extension WorkerWebViewManager: WKNavigationDelegate {
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		delegate?.webViewManagerDidFinishLoad(self)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		delegate?.webViewManagerDidFailLoad(self)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		if !actionTryList.isEmpty {
			let action = actionTryList.removeLast()
			switch action {
				case .load(let url):
					let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
					load(request: request)
				case .getTokenForSearch(let search):
					assert(actionTryList.isEmpty)
					waitForToken(with: search)
			}
		} else {
			delegate?.webViewManagerDidFailLoad(self)
		}
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		lastUpgrade.dec()
		let actionURL = navigationAction.request.url
		let isHTTPGet = navigationAction.request.isHTTPGet
		if actionURL != lastUpgrade.url, let url = upgradeURL(for: actionURL, navigationAction: navigationAction) {
			decisionHandler(.cancel)
			var newRequest = navigationAction.request
			newRequest.url = url
			load(request: newRequest)
			lastUpgrade.set(url)
			return
		}
		if let url = strippedURL(for: navigationAction) {
			decisionHandler(.cancel)
			var newRequest = navigationAction.request
			newRequest.url = url
			load(request: newRequest)
			return
		}
		let policy = PolicyManager.manager(for: actionURL, in: tab)
		if policy.shouldBlockLoad(of: actionURL) || (policy.preventXSS && actionURL?.potentialXSS ?? false) {
			decisionHandler(.cancel)
			delegate?.webViewManagerDidFailLoad(self)
			return
		}
		if policy.stripTrackingURLParameters && isHTTPGet, let original = actionURL {
			let db = DomainList.dbManager
			let table = "parameter_stripping"
			let result = URLParamStripRule.changedURL(for: original, from: db, table: table)
			if !result.stripped.isEmpty {
				decisionHandler(.cancel)
				load(url: result.url)
				return
			}
		}
		if policy.skipRedirects && isHTTPGet, let original = actionURL, let url = Redirector.shared.redirect(original) {
			decisionHandler(.cancel)
			load(url: url)
			return
		}
		if let url = actionURL, !policy.dangerReasons(for: url).isEmpty {
			decisionHandler(.cancel)
			delegate?.webViewManagerDidFailLoad(self)
			return
		}
		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		let space = challenge.protectionSpace
		guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
			completionHandler(.performDefaultHandling, nil)
			return
		}
		guard tab.controller?.accept(space.serverTrust!, for: space.host) ?? false else {
			completionHandler(.cancelAuthenticationChallenge, nil)
			return
		}
		completionHandler(.performDefaultHandling, nil)
	}
}

/// internals
private extension WorkerWebViewManager {
	func waitForToken(with search: String) {
		if observer == nil {
			observer = NotificationCenter.default.addObserver(forName: SubscriptionManager.tokenUpdatedNotificationName, object: nil, queue: nil) { [weak self] _ in
				if let search = self?.waitingSnowHazeSearch {
					if PolicyManager.isAboutBlank(self?.webView.url) {
						let url = SearchEngine(type: .snowhaze).url(for: search)
						self?.load(url: url)
					}
				}
			}
		}
		waitingSnowHazeSearch = search
		let errorPage = ErrorPageGenerator(type: .authError).getHTML()
		webView.loadHTMLString(errorPage, baseURL: nil)
	}

	func strippedURL(for navigationAction: WKNavigationAction) -> URL? {
		guard let url = navigationAction.request.url, navigationAction.targetFrame?.isMainFrame ?? false else {
			return nil
		}
		guard navigationAction.request.isHTTPGet else {
			return nil
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		guard policy.stripTrackingURLParameters else {
			return nil
		}
		let (newUrl, changes) = URLParamStripRule.changedURL(for: url, from: DomainList.dbManager, table: "parameter_stripping")
		return changes.isEmpty ? nil : newUrl
	}

	func update(for url: URL?, webView: WKWebView) {
		let policy = PolicyManager.manager(for: url, in: tab)
		update(policy: policy, webView: webView)
	}
}
