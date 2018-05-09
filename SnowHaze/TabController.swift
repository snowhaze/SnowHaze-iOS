//
//  TabController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let alertCountLimit = 3
private let alertCountMonitoringLimit = 100

enum TabControllerError: Error {
	case valueAlreadySet
}

enum TabUIEventType {
	case jsAlert(text: String, frameInfo: WKFrameInfo, completionHandler: () -> Void)
	case jsConfirm(question: String, frameInfo: WKFrameInfo, completionHandler: (Bool) -> Void)
	case jsPrompt(question: String, defaultText: String?, frameInfo: WKFrameInfo, completionHandler: (String?) -> Void)
	case alert(alert: UIAlertController, domain: String?, fallbackHandler: () -> Void)
	case tabCreation(request: URLRequest)
}

protocol TabControllerUIDelegate: class {
	func tabController(_ controller: TabController, displayJSAlert alert: String, withFrameInfo frameInfo: WKFrameInfo, completionHandler: @escaping () -> Void) -> Bool
	func tabController(_ controller: TabController, displayJSConfirmDialogWithQuestion question: String, frameInfo: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) -> Bool
	func tabController(_ controller: TabController, displayJSPromptWithQuestion question: String, defaultText: String?, frameInfo: WKFrameInfo, completionHandler: @escaping (String?) -> Void) -> Bool

	func tabController(_ controller: TabController, displayAlert alert: UIAlertController, forDomain domain: String?, fallbackHandler: @escaping () -> Void) -> Bool

	func tabController(_ controller: TabController, createTabForRequest request: URLRequest)
}

protocol TabControllerNavigationDelegate: class {
	func tabController(_ controller: TabController, didLoadTitle title: String?)
	func tabController(_ controller: TabController, didLoadURL url: URL?)
	func tabController(_ controller: TabController, estimatedProgress: Double)
	func tabControllerWillStartLoading(_ controller: TabController)
	func tabController(_ controller: TabController, securityAssessmentDidUpdate assessment: PolicyAssessmentResult)

	func tabController(_ controller: TabController, serverTrustDidChange trust: SecTrust?)

	func tabControllerCanGoForwardBackwardUpdate(_ controller: TabController)
}

private extension WKWebView {
	private var snapshotBounds: CGRect {
		return UIEdgeInsetsInsetRect(bounds, scrollView.contentInset)
	}

	func getSnapshot(callback: @escaping (UIImage?) -> Void) {
		if #available(iOS 11, *) {
			let config = WKSnapshotConfiguration()
			config.rect = snapshotBounds
			takeSnapshot(with: config) { image, error in
				if let error = error {
					print(error)
				}
				callback(image)
			}
		} else {
			DispatchQueue.main.async { [weak self] in
				callback(self?.snapshot)
			}
		}
	}

	private var snapshot: UIImage? {
		let snapshotBounds = self.snapshotBounds
		guard snapshotBounds.width > 0 && snapshotBounds.height > 0 else {
			return nil
		}
		let hasSuperview = superview != nil
		UIGraphicsBeginImageContextWithOptions(snapshotBounds.size, true, 0)
		var drawRect = CGRect(origin: CGPoint.zero, size: bounds.size)
		drawRect.origin.x = bounds.origin.x - scrollView.contentInset.left
		drawRect.origin.y = bounds.origin.y - scrollView.contentInset.top
		let result = drawHierarchy(in: drawRect, afterScreenUpdates: !hasSuperview)
		let snapshot = result ? UIGraphicsGetImageFromCurrentImageContext() : nil
		UIGraphicsEndImageContext()
		return snapshot
	}
}

class TabController: NSObject, WebViewManager {
	var lastUpgrade = HTTPSUpgradeState()
	var reloadedRequest: URLRequest?

	let tab: Tab
	let timeout: TimeInterval = 15
	private var sslValidationExeptions = [String: SecChallengeHandlerPolicy]()

	private var dec: (() -> Void)?

	private var internalUserAgent: String?
	private var internalDataStore: (WKWebsiteDataStore, WKProcessPool)?

	var userAgent: String {
		if let userAgent = internalUserAgent {
			return userAgent
		}
		internalUserAgent = PolicyManager.manager(for: tab).userAgent
		return internalUserAgent!
	}

	var dataStore: (WKWebsiteDataStore, WKProcessPool) {
		if let store = internalDataStore {
			return store
		}
		internalDataStore = (PolicyManager.manager(for: tab).dataStore, WKProcessPool())
		return internalDataStore!
	}

	func set(userAgent: String) throws {
		guard internalUserAgent == nil && !webViewLoaded else {
			throw TabControllerError.valueAlreadySet
		}
		internalUserAgent = userAgent
	}

	func set(dataStore: (WKWebsiteDataStore, WKProcessPool)) throws {
		guard internalDataStore == nil && !webViewLoaded else {
			throw TabControllerError.valueAlreadySet
		}
		internalDataStore = dataStore
	}

	private(set) var webViewLoaded = false

	private var waitingSnowHazeSearch: String?

	private var observer: NSObjectProtocol?

	weak var UIDelegate: TabControllerUIDelegate? {
		didSet {
			DispatchQueue.main.async { [weak self] in
				if let me = self, let _ = me.UIDelegate {
					let localEvents = me.queuedUIEvents
					me.queuedUIEvents.removeAll()
					localEvents.forEach { me.post(event: $0) }
				}
			}
		}
	}

	weak var navigationDelegate: TabControllerNavigationDelegate? {
		didSet {
			if let navigationDelegate = navigationDelegate {
				navigationDelegate.tabController(self, didLoadTitle: webView.title)
				navigationDelegate.tabController(self, didLoadURL: webView.url)
				navigationDelegate.tabController(self, estimatedProgress: progress)
				navigationDelegate.tabController(self, securityAssessmentDidUpdate: securityAssessment)
				navigationDelegate.tabControllerCanGoForwardBackwardUpdate(self)
			}
		}
	}

	private var actionTryList: [PolicyManager.Action] = []
	private var queuedUIEvents = [TabUIEventType]()
	private var blockedAlertDomains = Set<String>()
	private let historyStore = HistoryStore.store

	private var alertCounts = [String: Int]()
	private var totalAlertCount = 0

	private var observations = Set<NSKeyValueObservation>()

	private var webViewIfLoaded: WKWebView? {
		return webViewLoaded ? webView : nil
	}

	private(set) lazy var webView: WKWebView = {
		let policy = PolicyManager.manager(for: self.tab)
		let config = policy.webViewConfiguration
		(config.websiteDataStore, config.processPool) = self.dataStore
		let ret = WKWebView(frame: CGRect.zero, configuration: config)
		ret.backgroundColor = .background
		ret.scrollView.backgroundColor = .background
		ret.customUserAgent = self.userAgent
		ret.navigationDelegate = self
		ret.uiDelegate = self

		if #available(iOS 10, *) {
			ret.allowsLinkPreview = true
		} else {
			ret.allowsLinkPreview = false
		}

		DispatchQueue.main.async {
			self.observations.insert(ret.observe(\.URL, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabController(me, didLoadURL: webView.url)
				}
				if let url = webView.url {
					self?.pushTabHistory(url)
				}
			}))

			self.observations.insert(ret.observe(\.title, options: .initial, changeHandler: { [weak self] webView, _ in
				if !webView.isLoading || !(webView.title?.isEmpty ?? true) {
					self?.tab.title = webView.title
				}
				if let me = self {
					me.navigationDelegate?.tabController(me, didLoadTitle: webView.title)
				}
			}))

			if #available(iOS 10, *) {
				self.observations.insert(ret.observe(\.serverTrust, options: .initial, changeHandler: { [weak self] webView, _ in
					if let me = self {
						me.navigationDelegate?.tabController(me, serverTrustDidChange: webView.serverTrust)
					}
				}))
			}

			self.observations.insert(ret.observe(\.loading, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabController(me, didLoadTitle: webView.title)
					me.navigationDelegate?.tabController(me, estimatedProgress: me.progress)
				}
				if webView.isLoading {
					self?.dec = InUseCounter.network.inc()
				} else {
					self?.dec?()
					self?.dec = nil
				}
			}))

			self.observations.insert(ret.observe(\.canGoBack, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabControllerCanGoForwardBackwardUpdate(me)
				}
			}))

			self.observations.insert(ret.observe(\.canGoForward, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabControllerCanGoForwardBackwardUpdate(me)
				}
			}))

			self.observations.insert(ret.observe(\.estimatedProgress, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabController(me, estimatedProgress: me.progress)
				}
			}))

			self.observations.insert(ret.observe(\.hasOnlySecureContent, options: .initial, changeHandler: { [weak self] webView, _ in
				if let me = self {
					me.navigationDelegate?.tabController(me, didLoadTitle: webView.title)
				}
			}))
		}

		self.observations.insert(ret.observe(\.URL, options: .initial, changeHandler: { [weak self] webView, _ in
			self?.updatePolicy(for: webView.url, webView: webView)
		}))

		if !self.tab.history.isEmpty {
			let url = self.tab.history.last! as URL
			let request = URLRequest(url: url)
			self.updatePolicy(for: url, webView: ret)
			ret.load(request)
		}
		self.webViewLoaded = true
		return ret
	}()

	init(tab: Tab) {
		self.tab = tab
	}

	private func post(event: TabUIEventType) {
		queuedUIEvents.append(event)
		notifyNextUIEvent()
	}

	func notifyNextUIEvent() {
		guard let UIDelegate = UIDelegate, let event = queuedUIEvents.first else {
			return
		}
		if let fallbackHandler = fallbackHandlerIfAbort(for: event) {
			queuedUIEvents.removeFirst()
			let sum = random(1001) + random(1000) + random(1000)		// approximate normal distribution
			let randOffset = Double(4 * sum * sum) / (3000.0 * 3000.0)	// bias towards smaller numbers
			let waitTime = TimeInterval(0.3 + randOffset)				// faster than 0.3s would seem unrealistic
			let next = DispatchTime.now() + waitTime
			DispatchQueue.main.asyncAfter(deadline: next) {
				self.notifyNextUIEvent()
				fallbackHandler()
			}
			return
		}
		let success: Bool
		switch event {
			case .jsAlert(let text, let frameInfo, let completionHandler):
				success = UIDelegate.tabController(self, displayJSAlert: text, withFrameInfo: frameInfo, completionHandler: completionHandler)
			case .jsConfirm(let question, let frameInfo, let completionHandler):
				success = UIDelegate.tabController(self, displayJSConfirmDialogWithQuestion: question, frameInfo: frameInfo, completionHandler: completionHandler)
			case .jsPrompt(let question, let defaultText, let frameInfo, let completionHandler):
				success = UIDelegate.tabController(self, displayJSPromptWithQuestion: question, defaultText: defaultText, frameInfo: frameInfo, completionHandler: completionHandler)
			case .alert(let alert, let domain, let fallbackHandler):
				success = UIDelegate.tabController(self, displayAlert: alert, forDomain: domain, fallbackHandler: fallbackHandler)
			case .tabCreation(request: let request):
				UIDelegate.tabController(self, createTabForRequest: request)
				success = true
		}
		if success {
			queuedUIEvents.removeFirst()
		}
	}

	deinit {
		if let observer = observer {
			NotificationCenter.default.removeObserver(observer)
		}
		if webViewLoaded {
			webView.stopLoading()
			webViewLoaded = false
			dec?()
		}

		for event in queuedUIEvents {
			switch event {
				case .jsAlert(_, _, let handler):					handler()
				case .jsConfirm(_, _, let handler):					handler(false)
				case .jsPrompt(_, _, _, let handler):				handler(nil)
				case .alert(_, _, let handler):						handler()
				case .tabCreation(_):								break
			}
		}
	}
}

// MARK: UI Delegate
extension TabController: WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		let isBlank = PolicyManager.isAboutBlank(navigationAction.request.url)
		guard policy.allowsPopover(for: navigationAction.navigationType) && !isBlank else {
			return nil
		}
		post(event: .tabCreation(request: navigationAction.request))
		return nil
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		post(event: .jsAlert(text: message, frameInfo: frame, completionHandler: completionHandler))
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		post(event: .jsConfirm(question: message, frameInfo: frame, completionHandler: completionHandler))
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		post(event: .jsPrompt(question: prompt, defaultText: defaultText, frameInfo: frame, completionHandler: completionHandler))
	}
}

// MARK: webview accessing
extension TabController {
	var progress: Double {
		guard webViewLoaded else {
			return 0
		}
		return webView.isLoading ? webView.estimatedProgress : 0
	}

	var title: String? {
		return webViewIfLoaded?.title
	}

	var url: URL? {
		return webViewIfLoaded?.url
	}

	var hasOnlySecureContent: Bool? {
		return webViewIfLoaded?.hasOnlySecureContent
	}

	var isLoading: Bool? {
		return webViewIfLoaded?.isLoading
	}

	var evOrganization: String? {
		if #available(iOS 10, *) {
			guard let trust = webViewIfLoaded?.serverTrust else {
				return nil
			}
			guard let result = SecTrustCopyResult(trust) as NSDictionary? else {
				return nil
			}
			if result[kSecTrustExtendedValidation] as? Bool == true {
				return result[kSecTrustOrganizationName] as? String
			}
			return nil
		} else {
			return nil
		}
	}
}

// MARK: peek & pop
@available(iOS 10, *)
extension TabController {
	func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
		return elementInfo.linkURL != nil
	}

	func webView(_ webView: WKWebView, previewingViewControllerForElement elementInfo: WKPreviewElementInfo, defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
		let pageVC = PagePreviewController(url: elementInfo.linkURL!, tab: tab)
		let openAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierOpen }
		let copyAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierCopy }
		let shareAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierShare }

		pageVC.previewActionItems = []
		if let action = openAction {
			pageVC.previewActionItems.append(action)
		}

		if let url = elementInfo.linkURL {
			let title = NSLocalizedString("open in new tab preview action title", comment: "title of preview action to open a link in a new tab")
			let openInNewTabAction = UIPreviewAction(title: title, style: .default) { _, _ in
				let request = URLRequest(url: url)
				self.post(event: .tabCreation(request: request))
			}
			pageVC.previewActionItems.append(openInNewTabAction)
		}

		if let action = copyAction {
			pageVC.previewActionItems.append(action)
		}
		if let action = shareAction {
			pageVC.previewActionItems.append(action)
		}
		return pageVC
	}

	func webView(_ webView: WKWebView, commitPreviewingViewController previewingViewController: UIViewController) {
		if let pageVC = previewingViewController as? PagePreviewController {
			if let url = pageVC.manager.webView.url {
				load(request: URLRequest(url: url))
			}
		}
	}
}

// MARK: Navigation Delegate
extension TabController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		actionTryList.removeAll()
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if navigationResponse.isForMainFrame && !navigationResponse.canShowMIMEType {
			decisionHandler(.cancel)
			let errorpagegen = ErrorPageGenerator(type: .pageError)
			let title = NSLocalizedString("unknown file type errorpage title", comment: "title of the unknown file type errorpage")
			errorpagegen.title = title
			errorpagegen.message = NSLocalizedString("unknown file type errorpage message", comment: "errormessage of the unknown file type errorpage")
			if let url = navigationResponse.response.url {
				pushTabHistory(url)
				pushHistory(withTitle: title, url: url)
				errorpagegen.url = url
			}
			errorpagegen.file = navigationResponse.response.suggestedFilename
			errorpagegen.mimeType = navigationResponse.response.mimeType
			let html = errorpagegen.getHTML()
			webView.loadHTMLString(html, baseURL: nil)
			return
		}
		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		let error = error as NSError
		// don't continue with try list when cancelled by callback, since other code might already be loading an alternate URL
		if error.domain == "WebKitErrorDomain" && error.code == 102 {
			return
		}
		if error.code == NSURLErrorCancelled || tryNextAction() {
			return
		}
		let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
		if let url = url {
			pushTabHistory(url)
		}
		let errorpagegen = ErrorPageGenerator(type: .pageError)
		errorpagegen.errorCode = error.code
		errorpagegen.errorDomain = error.domain
		errorpagegen.errorReason = error.localizedFailureReason
		errorpagegen.description = error.localizedDescription
		errorpagegen.title = NSLocalizedString("network error errorpage title", comment: "title of the network error errorpage")
		errorpagegen.url = url
		errorpagegen.message = NSLocalizedString("network error errormessage format", comment: "errormessage format of the network error errorpage")
		let html = errorpagegen.getHTML()
		webView.loadHTMLString(html, baseURL: nil)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		let error = error as NSError
		if error.code == NSURLErrorCancelled {
			return
		}
		if error.code == 204 {
			return
		}
		let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
		if let url = url {
			pushTabHistory(url)
		}
		let errorpagegen = ErrorPageGenerator(type: .pageError)
		errorpagegen.errorCode = error.code
		errorpagegen.errorDomain = error.domain
		errorpagegen.errorReason = error.localizedFailureReason
		errorpagegen.description = error.localizedDescription
		errorpagegen.title = NSLocalizedString("website error errorpage title", comment: "title of the website error errorpage")
		errorpagegen.url = url
		errorpagegen.message = NSLocalizedString("website error errormessage format", comment: "errormessage format of the website error errorpage")
		let html = errorpagegen.getHTML()
		webView.loadHTMLString(html, baseURL: nil)
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if let title = webView.title, let url = webView.url {
			pushHistory(withTitle: title, url: url)
		}
		if let _ = webView.url {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
				self.saveTabState()
			}
		}
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		// When decisionHandler(.cancel) is called asynchronously for redirects, the page is loaded anyway.
		// If possible cancel those request immediately and then load them again in order to prevent this from happening.
		// Since navigationAction.sourceFrame is mostly uninitiallized in many cases where this function is called,
		// navigationAction.sourceFrame.webView seems to be the only safe way of detecting if the request is a redirect.
		if #available(iOS 11, *) {
			if case .other = navigationAction.navigationType, let _ = navigationAction.sourceFrame.webView, navigationAction.request.isHTTPGet && navigationAction.targetFrame?.isMainFrame ?? false {
				// WKWebView has quirk where it can unexpected undo redirects with huge timeout intervals. Try not to force it to do otherwise.
				if navigationAction.request != reloadedRequest && navigationAction.request.timeoutInterval <= 120 {
					reloadedRequest = navigationAction.request
					decisionHandler(.cancel)
					load(request: navigationAction.request)
					return
				}
			}
		}
		reloadedRequest = nil
		let finalDecision: (Bool) -> Void = { decision in
			if !decision {
				decisionHandler(.cancel)
			} else if #available(iOS 11, *) {
				ContentBlockerManager.shared.load { decisionHandler(.allow) }
			} else {
				decisionHandler(.allow)
			}
		}

		lastUpgrade.dec()
		let actionURL = navigationAction.request.url
		let requestingDomain = navigationAction.sourceFrame.securityOrigin.host

		if actionURL != lastUpgrade.url, let url = upgradeURL(for: actionURL, navigationAction: navigationAction) {
			finalDecision(false)
			load(request: navigationAction.request.with(url: url))
			if let actionURL = actionURL {
				lastUpgrade.set(actionURL)
			}
			return
		}

		let formHandler: () -> Void = { [weak self] in
			if navigationAction.navigationType != .formResubmitted {
				finalDecision(true)
			} else if let me = self {
				me.promptResubmitOK(url: actionURL, decisionHandler: finalDecision)
			} else {
				finalDecision(false)
			}
		}

		let externalHandler: (Bool) -> Void = { [weak self] cont in
			guard cont else {
				finalDecision(false)
				return
			}
			if let postCancel = self?.afterCancel(for: actionURL, for: requestingDomain) {
				finalDecision(false)
				postCancel()
				return
			}
			formHandler()
		}

		let paramHandler: (Bool) -> Void = { [weak self] cont in
			if cont, let me = self {
				me.promptForParamStripAndRedirect(for: navigationAction) { cont, url in
					externalHandler(cont)
					guard let url = url, let me = self else {
						return
					}
					assert(!cont)
					me.load(request: navigationAction.request.with(url: url))
				}
			} else {
				finalDecision(false)
			}
		}

		let xssHandler: (Bool) -> Void = { [weak self] cont in
			guard let me = self else {
				finalDecision(false)
				return
			}
			let policy = PolicyManager.manager(for: webView.url, in: me.tab)
			if policy.preventXSS, actionURL?.potentialXSS ?? false {
				me.xssPrompt(host: actionURL?.host, completion: paramHandler)
			} else {
				paramHandler(true)
			}
		}

		let policy = PolicyManager.manager(for: webView.url, in: tab)
		if policy.shouldBlockLoad(of: actionURL) {
			finalDecision(false)
		} else if !promptForDangers(on: actionURL, conformingTo: policy, decisionHandler: xssHandler) {
			xssHandler(true)
		}
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		let domain = challenge.protectionSpace.host
		let method = challenge.protectionSpace.authenticationMethod
		let secure = challenge.protectionSpace.receivesCredentialSecurely
		let realm = challenge.protectionSpace.realm
		let failCount = challenge.previousFailureCount
		switch method {
			case NSURLAuthenticationMethodServerTrust:
				handleSSLChallenge(with: challenge.protectionSpace.serverTrust!, for: domain, completionHandler: completionHandler)
			case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
				handleLoginPrompt(suggestion: challenge.proposedCredential, failCount: failCount, secure: secure, forDomain: domain, realm: realm, completionHandler: completionHandler)
			default:
				completionHandler(.performDefaultHandling, nil)
				print("unhandled authentication method \(method)")
		}
	}
}

// MARK: Tab Handling
extension TabController {
	var securityAssessment: PolicyAssessmentResult {
		let url = webViewIfLoaded?.url ?? tab.history.last
		let policy = PolicyManager.manager(for: url, in: tab)
		let wrapper = policy.settingsWrapper
		let assessor = PolicyAssessor(wrapper: wrapper)
		let categories = PolicyAssessor.allCategories
		return assessor.assess(categories)
	}

	var unused: Bool {
		return tab.history.isEmpty && (!webViewLoaded || (!webView.isLoading && webView.url?.absoluteString == nil))
	}

	var canGoForward: Bool {
		return webViewIfLoaded?.canGoForward ?? false
	}

	var canGoBack: Bool {
		return webViewIfLoaded?.canGoBack ?? false
	}

	func saveTabState() {
		if !unused || webViewIfLoaded?.isLoading ?? false {
			webViewIfLoaded?.getSnapshot() { [weak self] snapshot in
				if let snapshot = snapshot {
					self?.tab.snapshot = snapshot
				}
			}
		}
	}
}

// MARK: internals
private extension TabController {
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
		navigationDelegate?.tabControllerWillStartLoading(self)
		webView.loadHTMLString(errorPage, baseURL: nil)
	}

	func loadFromInput(forTabPolicy list: (PolicyManager) -> [PolicyManager.Action]) {
		lastUpgrade.reset()
		let policy = PolicyManager.manager(for: tab)
		policy.stopSuppressingHistory()
		load(list(policy))

		// if the new url is the same as the old one, history suppresion won't be setup again
		policy.setupHistorySuppresion(for: webViewIfLoaded?.url)
	}

	func updatePolicy(for url: URL?) {
		updatePolicy(for: url, webView: webView)
	}

	func updatePolicy(for url: URL?, webView: WKWebView) {
		let policy = PolicyManager.manager(for: url, in: tab)
		let tabPolicy = PolicyManager.manager(for: tab)
		tabPolicy.setupHistorySuppresion(for: url)
		navigationDelegate?.tabController(self, securityAssessmentDidUpdate: securityAssessment)
		update(policy: policy, webView: webView)
	}

	func pushTabHistory(_ url: URL) {
		if url != tab.history.last && WebViewURLSchemes.contains(url.scheme!.lowercased()) {
			tab.history.append(url)
		}
	}

	func pushHistory(withTitle title: String, url: URL) {
		let time: Int64 = 60 * 30
		let hasRecent = historyStore.hasRecent(with: url, seconds: time)
		let saveHistory = PolicyManager.manager(for: url, in: tab).shouldAddToHistory
		if !hasRecent && saveHistory && WebViewURLSchemes.contains(url.scheme!.lowercased()) {
			historyStore.addItem(title: title, atURL: url)
		}
	}

	func tryNextAction() -> Bool {
		guard !actionTryList.isEmpty else {
			return false
		}
		let nextAction = actionTryList.removeFirst()
		switch nextAction {
			case .load(let nextURL):
				let request = URLRequest(url: nextURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
				load(request: request)
			case .getTokenForSearch(let search):
				assert(actionTryList.isEmpty)
				waitForToken(with: search)
		}
		return true
	}

	func fallbackHandlerIfAbort(for event: TabUIEventType) -> (() -> Void)? {
		let data: (domain: String?, handler: () -> Void)
		switch event {
			case .jsAlert(_, let frameInfo, let completionHandler):
				data = (frameInfo.securityOrigin.host, completionHandler)
			case .jsConfirm(_, let frameInfo, let completionHandler):
				data = (frameInfo.securityOrigin.host, { completionHandler(false) })
			case .jsPrompt(_, _, let frameInfo, let completionHandler):
				data = (frameInfo.securityOrigin.host, { completionHandler(nil) })
			case .alert(_, let domain, let fallbackHandler):
				data = (domain, fallbackHandler)
			case .tabCreation(request: _):
				return nil
		}
		if let domain = data.domain, blockedAlertDomains.contains(domain) {
			return data.handler
		} else {
			return nil
		}
	}
}

// MARK: scheme handling
private extension TabController {
	func afterCancel(for url: URL?, for domain: String) -> (() -> Void)? {
		class Callguard {
			var called = false
			init() {
				DispatchQueue.main.async {
					self.check()
				}
			}
			func check() {
				if !called {
					fatalError("after cancel calling was deffered for too long")
				}
			}
		}
		let scheme = SchemeType(url)
		switch scheme {
			case .unknown:
				return nil
			case .http:
				return nil
			case .call(let recipient):
				if let recipient = recipient {
					promptFor(call: url!, to: recipient, by: domain)
				}
				return { }
			case .intent(let fallback):
				if let fallback = fallback {
					let callguard = Callguard()
					return {
						callguard.called = true
						self.load([.load(fallback)])
					}
				}
				return { }
			default:
				let uiApp = UIApplication.shared
				if let app = scheme.appName, !scheme.needsCheck || uiApp.canOpenURL(url!) {
					promptFor(app: app, toOpen: url!, by: domain)
				}
				return { }
		}
	}
}

// MARK: prompts
private extension TabController {
	func promptFor(call: URL, to recipient: String, by domain: String) {
		let title = NSLocalizedString("confirm call dialog title", comment: "title of dialog used to confirm the user wants to initiate a call")
		let format = NSLocalizedString("confirm call dialog message format", comment: "format for message of dialog used to confirm the user wants to initiate a call")
		let confirmTitle = NSLocalizedString("confirm call dialog confirm button title", comment: "title of confirm button of dialog used to confirm the user wants to initiate a call")
		let cancelTitle = NSLocalizedString("cancel call dialog confirm button title", comment: "title of cancel button of dialog used to confirm the user wants to initiate a call")
		let message = String(format: format, recipient)
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let confirm = UIAlertAction(title: confirmTitle, style: .default) { _ in
			if #available(iOS 10, *) {
				UIApplication.shared.open(call)
			} else {
				UIApplication.shared.openURL(call)
			}
		}
		alert.addAction(confirm)

		let decline = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
		alert.addAction(decline)

		post(event: .alert(alert: alert, domain: domain, fallbackHandler: { }))
	}

	func promptFor(app: String, toOpen url: URL, by domain: String) {
		let promptFormat = NSLocalizedString("open url in app prompt format", comment: "format string used to ask users if they want to open another app")
		let prompt = String(format: promptFormat, app)
		let title = NSLocalizedString("open url in app prompt title", comment: "title of prompt to ask users if they want to open another app")
		let confirmTitle = NSLocalizedString("open url in app prompt confirm button title", comment: "title of confirm button of prompt to ask users if they want to open another app")
		let cancelTitle = NSLocalizedString("open url in app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to open another app")
		let alert = UIAlertController(title: title, message: prompt, preferredStyle: .alert)
		let confirm = UIAlertAction(title: confirmTitle, style: .default) { _ in
			if #available(iOS 10, *) {
				UIApplication.shared.open(url)
			} else {
				UIApplication.shared.openURL(url)
			}
		}
		alert.addAction(confirm)

		let decline = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
		alert.addAction(decline)

		post(event: .alert(alert: alert, domain: domain, fallbackHandler: { }))
	}

	func promptResubmitOK(url: URL?, decisionHandler: @escaping (Bool) -> Void) {
		let title = NSLocalizedString("form resubmission confirmation prompt title", comment: "title of prompt to ask users if they want to resubmit a form")
		let prompt: String
		if let url = url {
			let format = NSLocalizedString("form resubmission confirmation prompt format", comment: "format string of message of prompt to ask users if they want to resubmit a form")
			prompt = String(format: format, url.absoluteString)
		} else {
			prompt = NSLocalizedString("form resubmission confirmation prompt unknown url message", comment: "message of prompt to ask users if they want to resubmit a form when the destination is unknown")
		}
		let confirmTitle = NSLocalizedString("form resubmission confirmation prompt confirm button title", comment: "title of confirm button of prompt to ask users if they want to resubmit a form")
		let cancelTitle = NSLocalizedString("form resubmission confirmation prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to resubmit a form")
		let alert = UIAlertController(title: title, message: prompt, preferredStyle: .alert)
		let confirm = UIAlertAction(title: confirmTitle, style: .default) { _ in decisionHandler(true) }
		alert.addAction(confirm)

		let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in decisionHandler(false) })
		alert.addAction(cancel)

		post(event: .alert(alert: alert, domain: nil, fallbackHandler: { decisionHandler(false) }))
	}

	func xssPrompt(host: String?, completion: @escaping (Bool) -> Void) {
		let title = NSLocalizedString("block xss prompt title", comment: "title of prompt to block xss")
		let msg: String
		if let host = host {
			let format =  NSLocalizedString("block xss known host prompt format", comment: "format string of message of prompt to block xss on a known host")
			msg = String(format: format, host)
		} else {
			msg = NSLocalizedString("block xss unknown host prompt message", comment: "message of prompt to block xss on an unknown host")
		}
		let blockTitle = NSLocalizedString("block xss unknown host prompt block action title", comment: "title of block action of prompt to block xss on an unknown host")
		let loadTitle = NSLocalizedString("block xss unknown host prompt load action title", comment: "title of load action of prompt to block xss on an unknown host")
		let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)
		let blockAction = UIAlertAction(title: blockTitle, style: .default) { _ in completion(false) }
		let loadAction = UIAlertAction(title: loadTitle, style: .cancel) { _ in completion(true) }
		alert.addAction(blockAction)
		alert.addAction(loadAction)
		post(event: .alert(alert: alert, domain: nil, fallbackHandler: { completion(false) }))
	}

	func promptForParamStripAndRedirect(for navigationAction: WKNavigationAction, completion: @escaping (Bool, URL?) -> Void) {
		guard let url = navigationAction.request.url, navigationAction.targetFrame?.isMainFrame ?? false else {
			completion(true, nil)
			return
		}
		guard navigationAction.request.isHTTPGet else {
			completion(true, nil)
			return
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		let redirect: (URL) -> URL? = { [weak self] original in
			if let me = self {
				let policy = PolicyManager.manager(for: original, in: me.tab)
				return policy.skipRedirects ? Redirector.shared.redirect(original) : nil
			} else {
				return nil
			}
		}
		guard policy.stripTrackingURLParameters else {
			let redirected = redirect(url)
			completion(redirected == nil, redirected)
			return
		}
		let (newUrl, changes) = URLParamStripRule.changedURL(for: url, from: DomainList.dbManager, table: "parameter_stripping")
		guard !changes.isEmpty else {
			let redirected = redirect(url)
			completion(redirected == nil, redirected)
			return
		}

		let title = NSLocalizedString("tracking parameter found alert title", comment: "title of alert to warn users of url parameters identified as tracking parameters")
		let msg: String
		if let host = url.host, changes.count == 1 {
			let format = NSLocalizedString("tracking parameter found one parameter on known host alert format", comment: "format of message of alert to warn users of a single url parameter on a known host identified as a tracking parameter")
			msg = String(format: format, changes.first!.name, host)
		} else if changes.count == 1 {
			let format = NSLocalizedString("tracking parameter found one parameter on unknown host alert format", comment: "format of message of alert to warn users of a single url parameter on an unknown host identified as a tracking parameter")
			msg = String(format: format, changes.first!.name)
		} else {
			let separator = NSLocalizedString("tracking parameter found alert multiple parameters separator", comment: "separator used to separate multiple parameters in alert to warn users of url parameters identified as tracking parameters when three ore more where found")
			let last = changes.last!.name
			let rest = changes[0 ..< changes.count - 1].map( { $0.name } ).joined(separator: separator)
			if let host = url.host {
				let format = NSLocalizedString("tracking parameter found multiple parameters on known host alert format", comment: "format of message of alert to warn users of multiple url parameters on a known host identified as tracking parameters")
				msg = String(format: format, rest, last, host)
			} else {
				let format = NSLocalizedString("tracking parameter found multiple parameters on unknown host alert format", comment: "format of message of alert to warn users of multiple url parameters on an unknown host identified as tracking parameters")
				msg = String(format: format, rest, last)
			}
		}

		let alert = UIAlertController(title: title, message: msg, preferredStyle: .alert)

		let ignoreTitle = NSLocalizedString("tracking parameter found alert ignore option title", comment: "title of ignore action of alert to warn users of url parameters identified as tracking parameters")
		let cancelTitle = NSLocalizedString("tracking parameter found alert cancel option title", comment: "title of cancel action of alert to warn users of url parameters identified as tracking parameters")
		let stripTitle = NSLocalizedString("tracking parameter found alert strip option title", comment: "title of strip action of alert to warn users of url parameters identified as tracking parameters")

		let ignore = UIAlertAction(title: ignoreTitle, style: .default) { _ in
			let redirected = redirect(url)
			completion(redirected == nil, redirected)
		}
		let cancel = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
			completion(false, nil)
		}
		let strip = UIAlertAction(title: stripTitle, style: .default) { _ in
			completion(false, redirect(newUrl) ?? newUrl)
		}

		alert.addAction(ignore)
		alert.addAction(cancel)
		alert.addAction(strip)

		post(event: .alert(alert: alert, domain: nil, fallbackHandler: { completion(false, nil) }))
	}

	func promptForDangers(on url: URL?, conformingTo policy: PolicyManager, decisionHandler: @escaping (Bool) -> Void) -> Bool {
		var dangerSet = policy.dangerReasons(for: url)
		guard !dangerSet.isEmpty else {
			return false
		}
		if dangerSet.contains(.phishGoogle) {
			dangerSet.remove(.phish)
		}
		let dangers = Array(dangerSet).sorted(by: { $0.rawValue < $1.rawValue })
		let title = NSLocalizedString("dangerous site warning alert title", comment: "title of alert to warn users of dangerous sites")
		var safebrowsing = false
		let warnings = dangers.map { danger -> String in
			switch danger {
				case .malicious:
					return NSLocalizedString("malicious site warning reason", comment: "explanation that the site might have malicious content")
				case .phish:
					return NSLocalizedString("phishing site warning reason", comment: "explanation that the site might be a phishing site")
				case .phishGoogle:
					safebrowsing = true
					return NSLocalizedString("phishing site warning reason", comment: "explanation that the site might be a phishing site")
				case .malware:
					safebrowsing = true
					return NSLocalizedString("malware site warning reason", comment: "explanation that the site might contain malware")
				case .harmfulApplication:
					safebrowsing = true
					return NSLocalizedString("harmful application site warning reason", comment: "explanation that the site might contain harmful applications")
				case .unwantedSoftware:
					safebrowsing = true
					return NSLocalizedString("unwanted software site warning reason", comment: "explanation that the site might contain unwanted software")
			}
		}
		let mainSeparator = NSLocalizedString("dangerous site warning reason list main separator", comment: "the separator used to separator most items in a (long) list of reasons a site might be dangerous. e.g. ', ' in 'a, b, c and d'")
		let finalSeparator = NSLocalizedString("dangerous site warning reason list final separator", comment: "the separator used to separator the last 2 items in a list of reasons a site might be dangerous. e.g. ' and ' in 'a, b, c and d'")
		let domain = url?.host ?? NSLocalizedString("dangerous site warning unknown domain name replacement", comment: "used instead of the domain name in the dangerous site warning if the domain is unknown")
		let format = safebrowsing ? NSLocalizedString("safebrowsing dangerous site warning alert message format", comment: "format string for the message of the dangerous site warning alert when at least part of the warnings was generated by google safebrowsing data") : NSLocalizedString("dangerous site warning alert message format", comment: "format string for the message of the dangerous site warning alert")
		let reasonList = warnings.sentenceJoined(mainSeparator: mainSeparator, finalSeparator: finalSeparator)
		let prompt = String(format: format, reasonList, domain)
		let confirmTitle = NSLocalizedString("dangerous site warning alert continue button title", comment: "title of the continue button of the alert to warn users of dangerous sites")
		let cancelTitle = NSLocalizedString("dangerous site warning alert cancel button title", comment: "title of the cancel button of the alert to warn users of dangerous sites")
		let alert = UIAlertController(title: title, message: prompt, preferredStyle: .alert)
		let confirm = UIAlertAction(title: confirmTitle, style: .default) { _ in
			decisionHandler(true)
		}
		alert.addAction(confirm)

		let decline = UIAlertAction(title: cancelTitle, style: .cancel, handler: { _ in decisionHandler(false) })
		alert.addAction(decline)

		post(event: .alert(alert: alert, domain: nil, fallbackHandler: { decisionHandler(false) }))
		return true
	}
}

// MARK: Web View Controlls
extension TabController {
	func goForward() {
		webView.goForward()
	}

	func goBack() {
		webView.goBack()
	}

	func localReload() {
		webView.reload()
	}

	func reload() {
		updatePolicy(for: webView.url)
		if let search = waitingSnowHazeSearch, PolicyManager.isAboutBlank(webView.url) {
			let url = SearchEngine(type: .snowhaze).url(for: search)
			load(url: url)
		} else if PolicyManager.isAboutBlank(webView.url) || webView.url == nil {
			if let url = tab.history.last {
				load(request: URLRequest(url: url as URL))
			}
		} else {
			webView.reloadFromOrigin()
		}
	}

	func stopLoading() {
		webView.stopLoading()
	}

	func load(userInput input: String) {
		loadFromInput { $0.actionList(for: input) }
	}

	func load(request: URLRequest) {
		waitingSnowHazeSearch = nil
		navigationDelegate?.tabControllerWillStartLoading(self)
		updatePolicy(for: request.url)
		webView.load(request)
	}

	func load(url: URL?) {
		if let url = url {
			loadFromInput { _ in return [.load(url)] }
		}
	}

	func clearMediaInfo() {
		waitingSnowHazeSearch = nil
		_ = webViewIfLoaded?.load(URLRequest(url: URL(string: "about:clear")!))
	}

	func blockAlerts(from domain: String) {
		blockedAlertDomains.insert(domain)
		alertCounts[domain] = nil
	}

	func shouldAllowIgnoreForIncedAlertCount(for domain: String) -> Bool {
		let cnt = (alertCounts[domain] ?? 0) + 1
		alertCounts[domain] = cnt
		totalAlertCount += 1
		if totalAlertCount > alertCountMonitoringLimit {
			let remove = random(totalAlertCount)
			var total = 0
			for (domain, count) in alertCounts {
				total += count
				if total > remove {
					let newCount = alertCounts[domain]! - 1
					alertCounts[domain] = newCount > 0 ? newCount : nil
					break
				}
			}
		}
		return cnt >= alertCountLimit
	}

	private func load(_ list: [PolicyManager.Action]) {
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
}

// MARK: Authentication
extension TabController {
	private func handleSSLChallenge(with trust: SecTrust, for domain: String, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		let policyEvaluator = SecPolicyEvaluator(domain: domain, trust: trust)
		policyEvaluator.evaluate(sslValidationExeptions[domain] ?? .strict)
		var optDialog: UIAlertController? = nil
		let retest = { (exeption: SecChallengeHandlerPolicy) in
			self.sslValidationExeptions[domain] = exeption
			if self.accept(trust, for: domain) {
				completionHandler(.useCredential, URLCredential(trust: trust))
			} else {
				completionHandler(.cancelAuthenticationChallenge, nil)
			}
		}
		switch policyEvaluator.issue {
			case .none:
				if accept(trust, for: domain) {
					completionHandler(.useCredential, URLCredential(trust: trust))
				} else {
					completionHandler(.cancelAuthenticationChallenge, nil)
				}
			case .invalidCert:
				let invalidCertTitle = NSLocalizedString("invalid certificate alert title", comment: "title of the alert that is displayed when trying to connect to a server with an invalid certificate")
				let invalidCertFormat = NSLocalizedString("invalid certificate alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with an invalid certificate")
				let invalidCertMessage = String(format: invalidCertFormat, domain)
				optDialog = UIAlertController(title: invalidCertTitle, message: invalidCertMessage, preferredStyle: .alert)
				let continueTitle = NSLocalizedString("invalid certificate alert continue button title", comment: "title of continue button of the alert that is displayed when trying to connect to a server with an invalid certificate")
				let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in retest(.allowInvalidCerts) }
				optDialog!.addAction(continueAction)
			case .domainMismatch(let certDomain):
				let domainMismatchTitle = NSLocalizedString("certificate domain name mismatch alert title", comment: "title of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name")
				let domainMismatchMessage: String
				if let certDomain = certDomain {
					let displayOriginalDomain: String
					if certDomain.hasPrefix("*.") {
						displayOriginalDomain = String(certDomain[certDomain.index(certDomain.startIndex, offsetBy: 2)...])
					} else {
						displayOriginalDomain = certDomain
					}
					let domainMismatchFormat = NSLocalizedString("certificate domain name mismatch known cert domain alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name and the domain the certificate was issued for is known")
					domainMismatchMessage = String(format: domainMismatchFormat, domain, displayOriginalDomain)
				} else {
					let domainMismatchFormat = NSLocalizedString("certificate domain name mismatch unknown cert domain alert message format", comment: "format of message of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name and the domain the certificate was issued for is not available")
					domainMismatchMessage = String(format: domainMismatchFormat, domain)

				}
				optDialog = UIAlertController(title: domainMismatchTitle, message: domainMismatchMessage, preferredStyle: .alert)
				let continueTitle = NSLocalizedString("certificate domain name mismatch alert continue button title", comment: "title of continue button of the alert that is displayed when trying to connect to a server with a certificate with an incorrect domain name")
				let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in retest(.allowDomainMismatch) }
				optDialog!.addAction(continueAction)
			case .unrecoverable:
				completionHandler(.cancelAuthenticationChallenge, nil)
			case .notEvaluated:
				fatalError("This should not happen")
		}
		if let dialog = optDialog {
			if PolicyManager.manager(for: url, in: tab).showTLSCertWarnings {
				let cancelTitle = NSLocalizedString("invalid certificate alert cancel button title", comment: "title of cancel button of the alert that is displayed when trying to connect to a server with an invalid certificate")
				let fallbackHandler = { completionHandler(.cancelAuthenticationChallenge, nil) }
				let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in fallbackHandler() }
				dialog.addAction(cancelAction)
				post(event: .alert(alert: dialog, domain: domain, fallbackHandler: fallbackHandler))
			} else {
				completionHandler(.cancelAuthenticationChallenge, nil)
			}
		}
	}

	private func handleLoginPrompt(suggestion: URLCredential?, failCount: Int, secure: Bool, forDomain domain: String, realm: String?, canUsePWManager: Bool = true, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
		if let credentials = suggestion , credentials.hasPassword && failCount == 0 {
			completionHandler(.performDefaultHandling, credentials)
			return
		}
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

		let title = NSLocalizedString("http authentication prompt title", comment: "title of prompt for http authentication")
		let dialog = UIAlertController(title: title, message: errormsg + prompt + warning, preferredStyle: .alert)

		dialog.addTextField { textField in
			let username = NSLocalizedString("http authentication prompt username placeholder", comment: "placeholder for username in prompt for http authentication")
			textField.placeholder = username
			textField.text = suggestion?.user
		}

		dialog.addTextField { textField in
			let password = NSLocalizedString("http authentication prompt password placeholder", comment: "placeholder for password in prompt for http authentication")
			textField.placeholder = password
			textField.isSecureTextEntry = true
			textField.text = suggestion?.password
		}

		let continueTitle = NSLocalizedString("http authentication prompt continue button title", comment: "title of continue button of http authentication prompt")
		let continueAction = UIAlertAction(title: continueTitle, style: .default) { _ in
			if let textFields = dialog.textFields, let user = textFields[0].text, let password = textFields[1].text {
				completionHandler(.useCredential, URLCredential(user: user, password: password, persistence: .forSession))
			} else {
				completionHandler(.cancelAuthenticationChallenge, nil)
			}
		}
		dialog.addAction(continueAction)

		if canUsePWManager, OnePasswordExtension.shared().isAppExtensionAvailable() {
			let onePWTitle = NSLocalizedString("http authentication 1password button title", comment: "title of button of http authentication prompt to retrieve credentials from 1password")
			let onePWAction = UIAlertAction(title: onePWTitle, style: .default) { [weak self] _ in
				let urlString = (secure ? "https://" : "http://") + domain
				guard let sender = MainViewController.controller.representingView(for: self?.tab) else {
					self?.handleLoginPrompt(suggestion: suggestion, failCount: failCount, secure: secure, forDomain: domain, realm: realm, canUsePWManager: false, completionHandler: completionHandler)
					return
				}
 				OnePasswordExtension.shared().findLogin(forURLString: urlString, for: MainViewController.controller, sender: sender) { loginDict, error in
					guard let loginDict = loginDict else {
						self?.handleLoginPrompt(suggestion: suggestion, failCount: failCount, secure: secure, forDomain: domain, realm: realm, completionHandler: completionHandler)
						return
					}
					let user = loginDict[AppExtensionUsernameKey] as? String ?? ""
					let password = loginDict[AppExtensionPasswordKey] as? String ?? ""
					let credentials = URLCredential(user: user, password: password, persistence: .forSession)
					if user.isEmpty && password.isEmpty {
						self?.handleLoginPrompt(suggestion: suggestion, failCount: failCount, secure: secure, forDomain: domain, realm: realm, completionHandler: completionHandler)
					} else if user.isEmpty || password.isEmpty {
						self?.handleLoginPrompt(suggestion: credentials, failCount: failCount + 1, secure: secure, forDomain: domain, realm: realm, completionHandler: completionHandler)
					} else {
						completionHandler(.useCredential, credentials)
					}
				}
			}
			dialog.addAction(onePWAction)
		}

		let cancelTitle = NSLocalizedString("http authentication prompt cancel button title", comment: "title of cancel button of http authentication prompt")
		let fallbackHandler = { completionHandler(.cancelAuthenticationChallenge, nil) }
		let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in fallbackHandler() }
		dialog.addAction(cancelAction)
		post(event: .alert(alert: dialog, domain: domain, fallbackHandler: fallbackHandler))
	}

	func accept(_ trust: SecTrust, for host: String) -> Bool {
		let policyEvaluator = SecPolicyEvaluator(domain: host, trust: trust)
		return 	policyEvaluator.evaluate(sslValidationExeptions[host] ?? .strict) &&
				(!PinningSessionDelegate.pinnedHosts.contains(host) ||
				policyEvaluator.pin(with: .certs(PinningSessionDelegate.pinnedCerts)))
	}
}
