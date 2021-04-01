//
//  TabController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

private let alertCountLimit = 3
private let alertCountMonitoringLimit = 100

struct DownloadData {
	fileprivate let response: URLResponse
}

enum TabControllerError: Error {
	case valueAlreadySet
}

enum TabUIEventType {
	case alert(type: AlertType, domain: String?, fallbackHandler: () -> ())
	case tabCreation(request: URLRequest, inForeground: Bool)
}

protocol TabControllerUIDelegate: class {
	func tabController(_ controller: TabController, displayAlert alert: AlertType, forDomain domain: String?, fallbackHandler: @escaping () -> ()) -> Bool
	func tabController(_ controller: TabController, createTabForRequest request: URLRequest, inForeground: Bool)
}

protocol TabControllerNavigationDelegate: class {
	func tabController(_ controller: TabController, didLoadTitle title: String?)
	func tabController(_ controller: TabController, isLoading url: URL?)
	func tabController(_ controller: TabController, estimatedProgress: Double)
	func tabControllerWillStartLoading(_ controller: TabController)
	func tabController(_ controller: TabController, securityAssessmentDidUpdate assessment: PolicyAssessmentResult)

	func tabController(_ controller: TabController, serverTrustDidChange trust: SecTrust?)

	func tabControllerCanGoForwardBackwardUpdate(_ controller: TabController)
	func tabControllerTabHistoryUpdate(_ controller: TabController)

	func tabController(_ controller: TabController, didUpgradeLoadOf url: URL)
}

private extension WKWebView {
	private var snapshotBounds: CGRect {
		return bounds.inset(by: scrollView.contentInset)
	}

	func getSnapshot(callback: @escaping (UIImage?) -> ()) {
		let config = WKSnapshotConfiguration()
		config.rect = snapshotBounds
		takeSnapshot(with: config) { image, error in
			if let error = error {
				print(error)
			}
			callback(image)
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
	private var lastUpgrade = HTTPSUpgradeState()
	private var reloadedRequest: URLRequest?

	let tab: Tab
	private(set) var downloadData: DownloadData?

	private let timeout: TimeInterval = 15
	private var sslValidationExeptions = [String: SecChallengeHandlerPolicy]()

	private var dec: (() -> ())?

	private var internalUserAgent: String?
	private var internalDataStore: (WKWebsiteDataStore, WKProcessPool)?
	private var internalSafebrowsingStorage: SafebrowsingStorage?

	var userAgent: String {
		if let userAgent = internalUserAgent {
			return userAgent
		}
		internalUserAgent = PolicyManager.manager(for: tab).userAgent
		return internalUserAgent!
	}

	var safebrowsingStorage: SafebrowsingStorage {
		if let safebrowsingStorage = internalSafebrowsingStorage {
			return safebrowsingStorage
		}
		internalSafebrowsingStorage = PolicyManager.manager(for: tab).safebrowsingStorage
		return internalSafebrowsingStorage!
	}

	var dataStore: (WKWebsiteDataStore, WKProcessPool) {
		if let store = internalDataStore {
			return store
		}
		let store = PolicyManager.manager(for: tab).dataStore
		internalDataStore = (store.store, store.pool ?? WKProcessPool())
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

	func set(safebrowsingStorage: SafebrowsingStorage) throws {
		guard internalSafebrowsingStorage == nil && !webViewLoaded else {
			throw TabControllerError.valueAlreadySet
		}
		internalSafebrowsingStorage = safebrowsingStorage
	}

	private(set) var webViewLoaded = false

	private var observer: NSObjectProtocol?

	weak var UIDelegate: TabControllerUIDelegate? {
		didSet {
			DispatchQueue.main.async { [weak self] in
				if let self = self, let _ = self.UIDelegate {
					let localEvents = self.queuedUIEvents
					self.queuedUIEvents.removeAll()
					localEvents.forEach { self.post(event: $0) }
				}
			}
		}
	}

	weak var navigationDelegate: TabControllerNavigationDelegate? {
		didSet {
			if let navigationDelegate = navigationDelegate {
				navigationDelegate.tabController(self, didLoadTitle: webView.title)
				navigationDelegate.tabController(self, isLoading: webView.url)
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

	let securityCookie: String = String.secureRandom()

	private(set) lazy var webView: WKWebView = {
		let policy = PolicyManager.manager(for: self.tab)
		let config = policy.webViewConfiguration(for: self)
		(config.websiteDataStore, config.processPool) = self.dataStore
		let ret = WKWebView(frame: .zero, configuration: config)
		ret.backgroundColor = .background
		ret.scrollView.backgroundColor = .background
		ret.customUserAgent = self.userAgent
		ret.navigationDelegate = self
		ret.uiDelegate = self
		ret.allowsLinkPreview = true

		DispatchQueue.main.async {
			self.observations.insert(ret.observe(\.title, options: .initial, changeHandler: { [weak self] webView, _ in
				if !webView.isLoading || !(webView.title?.isEmpty ?? true) {
					self?.tab.title = webView.title
				}
				if let self = self {
					self.navigationDelegate?.tabController(self, didLoadTitle: webView.title)
				}
			}))

			self.observations.insert(ret.observe(\.serverTrust, options: .initial, changeHandler: { [weak self] webView, _ in
				if let self = self {
					self.navigationDelegate?.tabController(self, serverTrustDidChange: webView.serverTrust)
				}
			}))

			self.observations.insert(ret.observe(\.isLoading, options: .initial, changeHandler: { [weak self] webView, _ in
				if !webView.isLoading {
					self?.tab.title = webView.title
				}
				if let self = self {
					self.navigationDelegate?.tabController(self, didLoadTitle: webView.title)
					self.navigationDelegate?.tabController(self, estimatedProgress: self.progress)
					self.navigationDelegate?.tabControllerTabHistoryUpdate(self)
				}
				if webView.isLoading {
					self?.dec = InUseCounter.network.inc()
				} else {
					self?.dec?()
					self?.dec = nil
				}
			}))

			self.observations.insert(ret.observe(\.canGoBack, options: .initial, changeHandler: { [weak self] _, _ in
				if let self = self {
					self.navigationDelegate?.tabControllerCanGoForwardBackwardUpdate(self)
				}
			}))

			self.observations.insert(ret.observe(\.canGoForward, options: .initial, changeHandler: { [weak self] _, _ in
				if let self = self {
					self.navigationDelegate?.tabControllerCanGoForwardBackwardUpdate(self)
				}
			}))

			self.observations.insert(ret.observe(\.estimatedProgress, options: .initial, changeHandler: { [weak self] _, _ in
				if let self = self {
					self.navigationDelegate?.tabController(self, estimatedProgress: self.progress)
				}
			}))

			self.observations.insert(ret.observe(\.hasOnlySecureContent, options: .initial, changeHandler: { [weak self] webView, _ in
				if let self = self {
					self.navigationDelegate?.tabController(self, didLoadTitle: webView.title)
				}
			}))
		}

		self.observations.insert(ret.observe(\.url, options: [.initial, .new, .old], changeHandler: { [weak self] webView, change in
			guard change.oldValue != change.newValue else {
				return
			}
			guard !(self?.tab.deleted ?? false) else {
				self?.stopLoading()
				return
			}
			assert(change.newValue == webView.url)
			self?.updatePolicy(for: webView.url, webView: webView)
			if let self = self {
				self.navigationDelegate?.tabController(self, isLoading: webView.url)
			}
			if let url = webView.url {
				self?.pushTabHistory(url)
			}
		}))

		if !self.tab.history.isEmpty {
			let url = self.tab.history.last! as URL
			let request = URLRequest(url: url)
			self.updatePolicy(for: url, webView: ret)
			rawLoad(request, in: ret)
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
			case .alert(let alert, let domain, let fallbackHandler):
				success = UIDelegate.tabController(self, displayAlert: alert, forDomain: domain, fallbackHandler: fallbackHandler)
			case .tabCreation(request: let request, inForeground: let foreground):
				UIDelegate.tabController(self, createTabForRequest: request, inForeground: foreground)
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
				case .alert(_, _, let handler):						handler()
				case .tabCreation(_, _):							break
			}
		}
	}
}

// MARK: UI Delegate
extension TabController: WKUIDelegate {
	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		createTab(for: navigationAction, originatingWebView: webView)
		return nil
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> ()) {
		let type = AlertType.jsAlert(domain: frame.securityOrigin.host, alert: message, completion: completionHandler)
		post(event: .alert(type: type, domain: frame.securityOrigin.normalizedHost, fallbackHandler: completionHandler))
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> ()) {
		let type = AlertType.jsConfirm(domain: frame.securityOrigin.host, question: message, completion: completionHandler)
		post(event: .alert(type: type, domain: frame.securityOrigin.normalizedHost, fallbackHandler: { completionHandler(false) }))
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> ()) {
		let type = AlertType.jsPrompt(domain: frame.securityOrigin.host, question: prompt, default: defaultText, completion: completionHandler)
		post(event: .alert(type: type, domain: frame.securityOrigin.normalizedHost, fallbackHandler: { completionHandler(nil) }))
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
		return webViewIfLoaded?.url?.detorified
	}

	var backList: [WKBackForwardListItem]? {
		return webViewIfLoaded?.backForwardList.backList
	}

	var forwardList: [WKBackForwardListItem]? {
		return webViewIfLoaded?.backForwardList.forwardList
	}

	var hasOnlySecureContent: Bool? {
		return webViewIfLoaded?.hasOnlySecureContent
	}

	var isLoading: Bool? {
		return webViewIfLoaded?.isLoading
	}

	var webbsiteDataStore: WKWebsiteDataStore? {
		return webViewIfLoaded?.configuration.websiteDataStore
	}

	var certCount: Int? {
		guard let trust = webViewIfLoaded?.serverTrust else {
			return nil
		}
		return SecTrustGetCertificateCount(trust)
	}

	var serverTrust: ServerTrust? {
		guard let trust =  webViewIfLoaded?.serverTrust else {
			return nil
		}
		return ServerTrust(trust: trust)
	}

	var torProxyCredentials: (String, String)? {
		guard let handler = webViewIfLoaded?.configuration.urlSchemeHandler(forURLScheme: "tor") else {
			return nil
		}
		guard let torHandler = handler as? TorSchemeHandler else {
			return nil
		}
		return (torHandler.user, torHandler.password)
	}
}

// MARK: context menu
@available(iOS 13.0, *)
extension TabController {
	func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> ()) {
		guard let url = elementInfo.linkURL else {
			completionHandler(nil)
			return
		}
		let previewProvider: UIContextMenuContentPreviewProvider = { [weak self] in
			guard let tab = self?.tab, !tab.deleted else {
				return nil
			}
			let openingPolicy = PolicyManager.manager(for: elementInfo.linkURL, in: tab)
			return PagePreviewController(url: url, tab: tab, delay: openingPolicy.previewDelay)
		}
		let actionProvider: UIContextMenuActionProvider = { [weak self] suggestedActions -> UIMenu in
			guard let tab = self?.tab, !tab.deleted else {
				return UIMenu()
			}
			let openAction = suggestedActions.first { ($0 as? UIAction)?.identifier.rawValue == "WKElementActionTypeOpen" }
			let copyAction = suggestedActions.first { ($0 as? UIAction)?.identifier.rawValue == "WKElementActionTypeCopy" }
			let shareAction = suggestedActions.first { ($0 as? UIAction)?.identifier.rawValue == "WKElementActionTypeShare" }
			let saveImageAction = suggestedActions.first { ($0 as? UIAction)?.identifier.rawValue == "WKElementActionTypeSaveImage" }

			var actions = [UIMenuElement]()
			if let action = openAction {
				actions.append(action)
			}

			let foregroundTitle = NSLocalizedString("open in new tab preview action title", comment: "title of preview action to open a link in a new tab")
			actions.append(UIAction(title: foregroundTitle, image: #imageLiteral(resourceName: "newtab-context").withRenderingMode(.alwaysTemplate)) { _ in
				let request = URLRequest(url: url)
				self?.post(event: .tabCreation(request: request, inForeground: true))
			})

			let backgroundTitle = NSLocalizedString("open in new tab in background preview action title", comment: "title of preview action to open a link in a new tab in the background")
			actions.append(UIAction(title: backgroundTitle, image: #imageLiteral(resourceName: "new-background-tab-context").withRenderingMode(.alwaysTemplate)) { _ in
				let request = URLRequest(url: url)
				self?.post(event: .tabCreation(request: request, inForeground: false))
			})

			if let action = copyAction {
				actions.append(action)
			}
			if let action = shareAction {
				actions.append(action)
			}
			if let action = saveImageAction {
				actions.append(action)
			}
			return UIMenu(title: url.absoluteString, image: nil, identifier: nil, options: [], children: actions)
		}
		let config = UIContextMenuConfiguration(identifier: nil, previewProvider: previewProvider, actionProvider: actionProvider)
		completionHandler(config)
	}

	func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo, willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
		if let pageVC = animator.previewViewController as? PagePreviewController {
			load(pageVC.commitLoad)
		}
	}
}

// MARK: peek & pop
extension TabController {
	func webView(_ webView: WKWebView, shouldPreviewElement elementInfo: WKPreviewElementInfo) -> Bool {
		return elementInfo.linkURL != nil
	}

	func webView(_ webView: WKWebView, previewingViewControllerForElement elementInfo: WKPreviewElementInfo, defaultActions previewActions: [WKPreviewActionItem]) -> UIViewController? {
		let openingPolicy = PolicyManager.manager(for: elementInfo.linkURL, in: tab)
		let pageVC = PagePreviewController(url: elementInfo.linkURL!, tab: tab, delay: openingPolicy.previewDelay)
		let openAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierOpen }
		let copyAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierCopy }
		let shareAction = previewActions.first { $0.identifier == WKPreviewActionItemIdentifierShare }

		pageVC.previewActionItems = []
		if let action = openAction {
			pageVC.previewActionItems.append(action)
		}

		if let url = elementInfo.linkURL {
			let foregoundTitle = NSLocalizedString("open in new tab preview action title", comment: "title of preview action to open a link in a new tab")
			let openInNewForegroundTabAction = UIPreviewAction(title: foregoundTitle, style: .default) { [weak self] _, _ in
				let request = URLRequest(url: url)
				self?.post(event: .tabCreation(request: request, inForeground: true))
			}
			pageVC.previewActionItems.append(openInNewForegroundTabAction)

			let backgroundTitle = NSLocalizedString("open in new tab in background preview action title", comment: "title of preview action to open a link in a new tab in the background")
			let openInNewBackgroundTabAction = UIPreviewAction(title: backgroundTitle, style: .default) { [weak self] _, _ in
				let request = URLRequest(url: url)
				self?.post(event: .tabCreation(request: request, inForeground: false))
			}
			pageVC.previewActionItems.append(openInNewBackgroundTabAction)
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
			load(pageVC.commitLoad)
		}
	}
}

// MARK: Navigation Delegate
extension TabController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		actionTryList.removeAll()
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> ()) {
		precondition(Thread.isMainThread)
		downloadData = nil
		if navigationResponse.isForMainFrame && !navigationResponse.canShowMIMEType {
			decisionHandler(.cancel)
			if let _ = navigationResponse.response.url {
				download(DownloadData(response: navigationResponse.response), confirm: true)
			} else {
				let errorpagegen = BrowserPageGenerator(type: .pageError)
				let title = NSLocalizedString("unknown file type errorpage title", comment: "title of the unknown file type errorpage")
				errorpagegen.title = title
				errorpagegen.message = NSLocalizedString("unknown file type errorpage message", comment: "errormessage of the unknown file type errorpage")
				if let url = navigationResponse.response.url {
					pushTabHistory(url)
					pushHistory(withTitle: title, url: url)
					errorpagegen.url = url.detorified
				}
				errorpagegen.file = navigationResponse.response.suggestedFilename
				errorpagegen.mimeType = navigationResponse.response.mimeType
				let html = errorpagegen.getHTML()
				webView.loadHTMLString(html, baseURL: nil)
			}
			return
		} else if navigationResponse.isForMainFrame, let url = navigationResponse.response.url?.detorified, ["http", "https", "data"].contains(url.normalizedScheme) {
			downloadData = DownloadData(response: navigationResponse.response)
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
		let errorpagegen = BrowserPageGenerator(type: .pageError)
		errorpagegen.errorCode = error.code
		errorpagegen.errorDomain = error.domain
		errorpagegen.errorReason = error.localizedFailureReason
		errorpagegen.description = error.localizedDescription
		errorpagegen.title = NSLocalizedString("network error errorpage title", comment: "title of the network error errorpage")
		errorpagegen.url = url?.detorified
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
		let errorpagegen = BrowserPageGenerator(type: .pageError)
		errorpagegen.errorCode = error.code
		errorpagegen.errorDomain = error.domain
		errorpagegen.errorReason = error.localizedFailureReason
		errorpagegen.description = error.localizedDescription
		errorpagegen.title = NSLocalizedString("website error errorpage title", comment: "title of the website error errorpage")
		errorpagegen.url = url?.detorified
		errorpagegen.message = NSLocalizedString("website error errormessage format", comment: "errormessage format of the website error errorpage")
		let html = errorpagegen.getHTML()
		webView.loadHTMLString(html, baseURL: nil)
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard !tab.deleted else {
			return
		}
		if let title = webView.title, let url = webView.url {
			pushHistory(withTitle: title, url: url)
		}
		if let _ = webView.url {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
				self.saveTabState()
			}
		}
	}

	@available(iOS 13, *)
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> ()) {
		self.webView(webView, decidePolicyFor: navigationAction) { [weak self] decision in
			guard let self = self, !self.tab.deleted else {
				if #available(iOS 14, *) {
					preferences.allowsContentJavaScript = false
				}
				preferences.preferredContentMode = .recommended
				decisionHandler(.cancel, preferences)
				return
			}
			let policyURL = navigationAction.loadedMainURL ?? webView.url
			let policy = PolicyManager.manager(for: policyURL, in: self.tab)
			if #available(iOS 14, *) {
				preferences.allowsContentJavaScript = policy.allowJS
			}
			preferences.preferredContentMode = policy.renderAsDesktopSite ? .desktop : .mobile
			decisionHandler(decision, preferences)
		}
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> ()) {
		guard !tab.deleted else {
			decisionHandler(.cancel)
			return
		}
		// When decisionHandler(.cancel) is called asynchronously for redirects, the page is loaded anyway.
		// If possible cancel those request immediately and then load them again in order to prevent this from happening.
		if case .other = navigationAction.navigationType, let _ = navigationAction.realSourceFrame, navigationAction.targetFrame?.isMainFrame ?? false {
			if navigationAction.request.url?.normalizedScheme == "about" {
				decisionHandler(.cancel)
				return
			}
			// WKWebView has a quirk where it can unexpectedly undo redirects with huge timeout intervals. Try not to force it to do otherwise.
			if navigationAction.request.isHTTPGet && navigationAction.request != reloadedRequest && navigationAction.request.timeoutInterval <= 120 {
				reloadedRequest = navigationAction.request
				decisionHandler(.cancel)
				load(request: navigationAction.request)
				return
			}
		}
		// 'activated' links can cause universal links to be opened in other apps. To prevent this massive privacy violation, we cancel them and load the request directly.
		// In such cases the targetFrame also tends to be nil.
		if [.linkActivated, .formSubmitted].contains(navigationAction.navigationType), navigationAction.request.isHTTPGet && navigationAction.targetFrame?.isMainFrame ?? true {
			decisionHandler(.cancel)
			if let _ = navigationAction.targetFrame {
				load(request: navigationAction.request)
			} else {
				createTab(for: navigationAction, originatingWebView: webView)
			}
			return
		}
		reloadedRequest = nil

		let actionURL = navigationAction.request.url?.detorified ?? navigationAction.request.url
		let requestingDomain = navigationAction.realSourceFrame?.securityOrigin.normalizedHost

		let policyURL = navigationAction.loadedMainURL ?? webView.url
		let policy = PolicyManager.manager(for: policyURL, in: tab)
		if navigationAction.request.isHTTPGet && navigationAction.targetFrame?.isMainFrame ?? true, let url = policy.torifyIfNecessary(for: tab, url: navigationAction.request.url) {
			decisionHandler(.cancel)
			load(url: url)
			return
		}

		let finalDecision: (Bool) -> () = { [weak self] decision in
			if !decision {
				decisionHandler(.cancel)
			} else {
				ContentBlockerManager.shared.load {
					guard let self = self, !self.tab.deleted else {
						decisionHandler(.cancel)
						return
					}
					if navigationAction.targetFrame?.isMainFrame ?? false {
						self.updatePolicy(for: policyURL)
					}
					decisionHandler(.allow)
				}
			}
		}

		lastUpgrade.dec()

		if actionURL != lastUpgrade.url, let url = upgradeURL(for: actionURL, navigationAction: navigationAction) {
			navigationDelegate?.tabController(self, didUpgradeLoadOf: url)
			finalDecision(false)
			load(request: navigationAction.request.with(url: url))
			if let actionURL = actionURL {
				lastUpgrade.set(actionURL)
			}
			return
		}

		let formHandler: () -> () = { [weak self] in
			guard let self = self, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			if navigationAction.navigationType != .formResubmitted {
				finalDecision(true)
			} else {
				self.promptResubmitOK(url: actionURL, decisionHandler: finalDecision)
			}
		}

		let externalHandler: (Bool) -> () = { [weak self] cont in
			guard let self = self, cont, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			if let postCancel = self.afterCancel(for: actionURL, for: requestingDomain) {
				finalDecision(false)
				postCancel()
				return
			}
			formHandler()
		}

		let paramHandler: (Bool) -> () = { [weak self] cont in
			guard let self = self, cont, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			self.promptForParamStripAndRedirect(for: navigationAction, in: webView) { [weak self] cont, url in
				externalHandler(cont)
				guard let url = url, let self = self else {
					return
				}
				assert(!cont)
				self.load(request: navigationAction.request.with(url: url))
			}
		}

		let xssHandler: (Bool) -> () = { [weak self] cont in
			guard let self = self, cont, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			let policy = PolicyManager.manager(for: policyURL, in: self.tab)
			if policy.preventXSS, actionURL?.potentialXSS ?? false {
				self.xssPrompt(host: actionURL?.host, completion: paramHandler)
			} else {
				paramHandler(true)
			}
		}

		let frameHandler: (Bool) -> () = { [weak self] cont in
			guard let self = self, cont, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			guard let target = navigationAction.targetFrame, let source = navigationAction.realSourceFrame else {
				xssHandler(true)
				return
			}
			let policy = PolicyManager.manager(for: policyURL, in: self.tab)
			if policy.warnCrossFrameNavigation, source != target, navigationAction.navigationType != .other {
				self.crossFrameNavigationPrompt(src: source, target: target, url: policyURL, action: navigationAction.request, completion: xssHandler)
			} else {
				xssHandler(true)
			}
		}

		let onionHandler: (Bool) -> () = { [weak self] cont in
			guard let self = self, cont, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			guard navigationAction.targetFrame?.isMainFrame ?? false, let loadUrl = actionURL else {
				frameHandler(true)
				return
			}
			let policy = PolicyManager.manager(for: policyURL, in: self.tab)
			guard actionURL?.isOnion ?? false, let host = loadUrl.normalizedHost, !policy.useTor else {
				frameHandler(true)
				return
			}
			let alert = AlertType.switchToTor(host: host, load: loadUrl, completion: frameHandler)
			let url = navigationAction.realSourceFrame?.request.url ?? webView.url
			let blockHost = url?.normalizedHost ?? host
			self.post(event: .alert(type: alert, domain: blockHost, fallbackHandler: { finalDecision(false) }))
		}

		policy.awaitTorIfNecessary(for: tab) { [weak self] _ in
			guard let self = self, !self.tab.deleted else {
				finalDecision(false)
				return
			}
			let policy = PolicyManager.manager(for: policyURL, in: self.tab)
			if policy.shouldBlockLoad(of: actionURL) {
				finalDecision(false)
			} else {
				self.promptForDangers(on: actionURL, conformingTo: policy, decisionHandler: onionHandler)
			}
		}
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		let domain = challenge.protectionSpace.normalizedHost
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

	func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge, shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> ()) {
		guard !tab.deleted else {
			decisionHandler(false)
			return
		}
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		decisionHandler(!policy.blockDeprecatedTLS)
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
	func loadFromInput(forTabPolicy list: (PolicyManager) -> [PolicyManager.Action]) {
		lastUpgrade.reset()
		let policy = PolicyManager.manager(for: tab)
		policy.stopSuppressingHistory()
		load(list(policy))
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
		guard let url = url.detorified else {
			return
		}
		if url != tab.history.last && WebViewURLSchemes.contains(url.normalizedScheme ?? ":arbitrary-non-webview-scheme:") {
			tab.history.append(url)
		}
	}

	func pushHistory(withTitle title: String, url: URL) {
		guard let url = url.detorified else {
			return
		}
		let time: Int64 = 60 * 30
		let hasRecent = historyStore.hasRecent(with: url, seconds: time)
		let saveHistory = PolicyManager.manager(for: url, in: tab).shouldAddToHistory
		if !hasRecent && saveHistory && WebViewURLSchemes.contains(url.normalizedScheme!) {
			historyStore.addItem(title: title, atURL: url)
		}
	}

	func tryNextAction() -> Bool {
		guard !actionTryList.isEmpty else {
			return false
		}
		let nextAction = actionTryList.removeFirst()
		switch nextAction {
			case .load(let nextURL, let upgraded):
				let request = URLRequest(url: nextURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
				if upgraded {
					navigationDelegate?.tabController(self, didUpgradeLoadOf: nextURL)
				}
				load(request: request)
		}
		return true
	}

	func fallbackHandlerIfAbort(for event: TabUIEventType) -> (() -> ())? {
		let data: (domain: String?, handler: () -> ())
		switch event {
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

	func createTab(for navigationAction: WKNavigationAction, originatingWebView webView: WKWebView) {
		let policy = PolicyManager.manager(for: webView.url, in: tab)
		let isBlank = PolicyDomain.isAboutBlank(navigationAction.request.url)
		if policy.allowsPopover(for: navigationAction.navigationType) && !isBlank {
			post(event: .tabCreation(request: navigationAction.request, inForeground: true))
		}
	}
}

// MARK: scheme handling
private extension TabController {
	func afterCancel(for url: URL?, for domain: String?) -> (() -> ())? {
		let scheme = SchemeType(url)
		switch scheme {
			case .unknown:
				return nil
			case .http:
				return nil
			case .call(let recipient, let facetime) where recipient != nil:
				assert(scheme.needsCheck)
				if UIApplication.shared.canOpenURL(url!) {
					promptFor(call: url!, to: recipient!, facetime: facetime, by: domain)
				}
				return { }
			case .intent(let fallback):
				if let fallback = fallback {
					let callguard = SyncBlockCallGuard()
					return {
						callguard.called()
						self.load([.load(fallback, upgraded: false)])
					}
				}
				return { }
			default:
				let canOpen = !scheme.needsCheck || UIApplication.shared.canOpenURL(url!)
				if let app = scheme.appName, canOpen {
					promptFor(app: app, toOpen: url!, by: domain)
				}
				return { }
		}
	}
}

// MARK: prompts
private extension TabController {
	func promptFor(call url: URL, to recipient: String, facetime: Bool, by domain: String?) {
		let alert = AlertType.call(facetime: facetime, recipient: recipient, url: url)
		post(event: .alert(type: alert, domain: domain, fallbackHandler: { }))
	}

	func promptFor(app: String, toOpen url: URL, by domain: String?) {
		let alert = AlertType.openApp(name: app, url: url)
		post(event: .alert(type: alert, domain: domain, fallbackHandler: { }))
	}

	func promptResubmitOK(url: URL?, decisionHandler: @escaping (Bool) -> ()) {
		let alert = AlertType.resubmit(url: url, completion: decisionHandler)
		post(event: .alert(type: alert, domain: nil, fallbackHandler: { decisionHandler(false) }))
	}

	func xssPrompt(host: String?, completion: @escaping (Bool) -> ()) {
		let alert = AlertType.blockXSS(host: host, completion: completion)
		post(event: .alert(type: alert, domain: nil, fallbackHandler: { completion(false) }))
	}

	func crossFrameNavigationPrompt(src: WKFrameInfo, target: WKFrameInfo, url: URL?, action: URLRequest, completion: @escaping (Bool) -> ()) {
		let alert = AlertType.crossFrameNavigation(src: src, target: target, url: url, action: action, completion: completion)
		post(event: .alert(type: alert, domain: url?.normalizedHost, fallbackHandler: { completion(false) }))
	}

	func promptForParamStripAndRedirect(for navigationAction: WKNavigationAction, in webView: WKWebView, completion: @escaping (Bool, URL?) -> ()) {
		let rawURL = navigationAction.request.url
		guard let url = rawURL?.detorified ?? rawURL, navigationAction.targetFrame?.isMainFrame ?? false else {
			completion(true, nil)
			return
		}
		let policyURL = navigationAction.loadedMainURL ?? webView.url
		guard navigationAction.request.isHTTPGet else {
			completion(true, nil)
			return
		}
		let policy = PolicyManager.manager(for: policyURL, in: tab)
		let redirect: (URL) -> URL? = { [weak self] original in
			if let self = self {
				let policy = PolicyManager.manager(for: policyURL, in: self.tab)
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

		let completionHandler = { (result: Bool?) -> () in
			if result == true {
				let redirected = redirect(url)
				completion(redirected == nil, redirected)
			} else if result == false {
				completion(false, nil)
			} else {
				completion(false, redirect(newUrl) ?? newUrl)
			}
		}
		let alert = AlertType.paramStrip(url: url, changes: changes, completion: completionHandler)
		post(event: .alert(type: alert, domain: navigationAction.realSourceFrame?.request.url?.normalizedHost, fallbackHandler: { completion(false, nil) }))
	}

	func promptForDangers(on url: URL?, conformingTo policy: PolicyManager, decisionHandler: @escaping (Bool) -> ()) {
		policy.dangerReasons(for: url, in: self) { [weak self] dangerSet in
			var dangerSet = dangerSet
			guard !dangerSet.isEmpty, let self = self else {
				decisionHandler(dangerSet.isEmpty)
				return
			}
			if dangerSet.contains(.phishGoogle) {
				dangerSet.remove(.phish)
			}
			let alert = AlertType.dangerWarning(url: url, dangers: dangerSet, completion: decisionHandler)
			self.post(event: .alert(type: alert, domain: nil, fallbackHandler: { decisionHandler(false) }))
		}
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

	func go(to item: WKBackForwardListItem) {
		webView.go(to: item)
	}

	func localReload() {
		webView.reload()
	}

	func reload() {
		updatePolicy(for: webView.url)
		if PolicyDomain.isAboutBlank(webView.url) || webView.url == nil {
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
		loadFromInput { $0.actionList(for: input, in: tab) }
	}

	func load(request: URLRequest) {
		navigationDelegate?.tabControllerWillStartLoading(self)
		updatePolicy(for: request.url)
		rawLoad(request, in: webView)
	}

	func load(url: URL?) {
		if let url = url {
			loadFromInput { _ in return [.load(url, upgraded: false)] }
		}
	}

	func cleanup() {
		rawLoad(URLRequest(url: URL(string: "about:clear")!), in: webViewIfLoaded)
		let insecureHandler = webViewIfLoaded?.configuration.urlSchemeHandler(forURLScheme: "tor") as? TorSchemeHandler
		insecureHandler?.cleanup()
		let secureHandler = webViewIfLoaded?.configuration.urlSchemeHandler(forURLScheme: "tors") as? TorSchemeHandler
		secureHandler?.cleanup()
	}

	func blockAlerts(from domain: String) {
		blockedAlertDomains.insert(domain)
		alertCounts[domain] = nil
	}

	func shouldAllowIgnoreForIncedAlertCount(for domain: String) -> Bool {
		let cnt = (alertCounts[domain] ?? 0) + 1
		alertCounts[domain] = cnt
		totalAlertCount += 1
		while totalAlertCount > alertCountMonitoringLimit {
			let remove = random(UInt32(totalAlertCount))
			totalAlertCount -= 1
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
			case .load(let url, let upgraded):
				let request = actionTryList.isEmpty ? URLRequest(url: url) : URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: timeout)
				if upgraded {
					navigationDelegate?.tabController(self, didUpgradeLoadOf: url)
				}
				load(request: request)
		}
	}

	func download(_ downloadData: DownloadData, confirm: Bool = false) {
		guard let url = downloadData.response.url else {
			return
		}
		webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
			if confirm {
				let type = AlertType.download(url: url, file: downloadData.response.suggestedFilename) { [weak self] in
					if let tab = self?.tab, !tab.deleted {
						 FileDownload.start(for: url, cookies: cookies, tab: tab)
					}
				}
				self?.post(event: .alert(type: type, domain: downloadData.response.url?.normalizedHost, fallbackHandler: { }))
			} else if let tab = self?.tab {
				FileDownload.start(for: url, cookies: cookies, tab: tab)
			}
		}
	}
}

// MARK: Authentication
extension TabController {
	private func handleSSLChallenge(with trust: SecTrust, for domain: String, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		let policyEvaluator = SecPolicyEvaluator(domain: domain, trust: trust)
		let url = self.url
		weak var tab = self.tab
		policyEvaluator.evaluate(sslValidationExeptions[domain] ?? .strict) { [weak self] _ in
			guard let self = self else {
				completionHandler(.cancelAuthenticationChallenge, nil)
				return
			}
			var alertType: AlertType? = nil
			let retest = { [weak self] (exeption: SecChallengeHandlerPolicy) in
				guard let self = self else {
					completionHandler(.cancelAuthenticationChallenge, nil)
					return
				}
				self.sslValidationExeptions[domain] = exeption
				self.accept(trust, for: domain) { result in
					if result {
						completionHandler(.useCredential, URLCredential(trust: trust))
					} else {
						completionHandler(.cancelAuthenticationChallenge, nil)
					}
				}
			}
			switch policyEvaluator.issue {
				case .none:
					self.accept(trust, for: domain) { result in
						if result {
							completionHandler(.useCredential, URLCredential(trust: trust))
						} else {
							completionHandler(.cancelAuthenticationChallenge, nil)
						}
					}
				case .invalidCert:
					alertType = .invalidTLSCert(domain: domain) { retry in
						if retry {
							retest(.allowInvalidCerts)
						} else {
							completionHandler(.cancelAuthenticationChallenge, nil)
						}
					}
				case .domainMismatch(let certDomain):
					alertType = .tlsDomainMismatch(domain: domain, certDomain: certDomain) { retry in
						if retry {
							retest(.allowDomainMismatch)
						} else {
							completionHandler(.cancelAuthenticationChallenge, nil)
						}
					}
				case .unrecoverable:
					completionHandler(.cancelAuthenticationChallenge, nil)
				case .notEvaluated:
					fatalError("This should not happen")
			}
			if let alertType = alertType {
				if let tab = tab, PolicyManager.manager(for: url, in: tab).showTLSCertWarnings {
					self.post(event: .alert(type: alertType, domain: url?.normalizedHost ?? domain, fallbackHandler: { completionHandler(.cancelAuthenticationChallenge, nil) }))
				} else {
					completionHandler(.cancelAuthenticationChallenge, nil)
				}
			}
		}
	}

	private func handleLoginPrompt(suggestion: URLCredential?, failCount: Int, secure: Bool, forDomain domain: String, realm: String?, canUsePWManager: Bool = true, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		if let credentials = suggestion, credentials.hasPassword && failCount == 0 {
			completionHandler(.performDefaultHandling, credentials)
			return
		}
		let type = AlertType.httpAuthentication(realm: realm, domain: domain, failCount: failCount, secure: secure, suggestion: suggestion) { authenticate, alert in
			if authenticate {
				if let user = alert.textFields![0].text, let password = alert.textFields![1].text {
					completionHandler(.useCredential, URLCredential(user: user, password: password, persistence: .forSession))
				} else {
					completionHandler(.cancelAuthenticationChallenge, nil)
				}
			} else {
				completionHandler(.cancelAuthenticationChallenge, nil)
			}
		}
		post(event: .alert(type: type, domain: domain, fallbackHandler: { completionHandler(.cancelAuthenticationChallenge, nil) }))
	}

	func accept(_ trust: SecTrust, for host: String, completionHandler: @escaping (Bool) -> ()) {
		let policyEvaluator = SecPolicyEvaluator(domain: host, trust: trust)
		policyEvaluator.evaluate(sslValidationExeptions[host] ?? .strict) { result in
			completionHandler(result && (!PinningSessionDelegate.pinnedHosts.contains(host) || policyEvaluator.pin(with: .certs(PinningSessionDelegate.pinnedCerts))))
		}
	}
}

extension TabController {
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		didReceive(scriptMessage: message, from: userContentController)
	}
}
