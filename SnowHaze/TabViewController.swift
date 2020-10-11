//
//  TabViewController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit
import WebKit

protocol TabViewControllerDelegate: class {
	func tabViewController(_ controller: TabViewController, openTabForRequest request: URLRequest, inForeground: Bool)
	func showSuggestions(searchString: String)
	func stopShowingSuggestions()
	func showToolBar(degree: CGFloat)
	func stopShowingOverlays()
	func showRenameBar(fallback: String?, prefill: String?, callback: @escaping (String?) -> ())
	func boundingViews() -> (top: UIView?, bottom: UIView?)
	func showDownloads()
}

class TabViewController: UIViewController {
	@IBOutlet var bookmarkHistoryView: BookmarkHistoryView!
	private let historyStore = HistoryStore.store
	private let bookmarkStore = BookmarkStore.store
	private var lastScrollPosition: CGFloat?
	private var scrollDirectionStrength = 0

	private static var docController: UIDocumentInteractionController?
	private static var sendingFile = false

	weak var delegate: TabViewControllerDelegate?

	@IBOutlet weak var maskContent: UIView!
	@IBOutlet weak var maskImage: UIImageView!
	@IBOutlet weak var downloadProgress: DownloadProgressIndicator!

	private var contentScale: CGFloat = 0

	var tab: Tab? {
		willSet {
			webView = nil
			if let tab = tab {
				tab.controller?.navigationDelegate = nil
				tab.controller?.UIDelegate = nil
			}
		}
		didSet {
			guard let tab = tab else {
				return
			}
			guard let controller = tab.controller else {
				return
			}
			contentScale = PolicyManager.manager(for: tab).webContentScale

			webView = controller.webView
			scale = 1

			webView.transform = CGAffineTransform(scaleX: contentScale, y: contentScale)

			controller.UIDelegate = self
			controller.navigationDelegate = self

			bookmarkHistoryView.reloadHistory()
			bookmarkHistoryView.reloadBookmarks()
			if controller.unused {
				webView.isHidden = true
				webView.alpha = 0
				bookmarkHistoryView.isHidden = false
				view.insertSubview(bookmarkHistoryView, at: 1)
			} else {
				webView.isHidden = false
				webView.alpha = 1
				bookmarkHistoryView.isHidden = true
				self.bookmarkHistoryView.removeFromSuperview()
				if webView.url == nil && !webView.isLoading {
					controller.localReload()
				}
			}
		}
	}

	var urlBar: URLBar? {
		didSet {
			stopInput()
			delegate?.stopShowingSuggestions()
		}
	}

	var isMasked: Bool = false {
		didSet {
			guard let tab = tab, oldValue != isMasked else {
				return
			}
			if isMasked {
				webView.isHidden = true
				bookmarkHistoryView.isHidden = true
				maskContent.isHidden = false
				urlBar?.progress = 0
				urlBar?.title = NSLocalizedString("masked tab title", comment: "displayed instead of title for masked tabs in app snapshots")
				let policy = PolicyManager.globalManager()
				let wrapper = policy.settingsWrapper
				let assessment = PolicyAssessor(wrapper: wrapper).assess(PolicyAssessor.allCategories)
				updateSecAssessment(assessment)
				let allWindows = UIApplication.shared.windows
				if !allWindows.isEmpty {
					let windows = allWindows.suffix(from: 1)
					for window in windows {
						if let root = window.rootViewController {
							if root is LockPresenterController {
								continue
							}
						}
						window.isHidden = true
					}
				}
				if let alert = presentedViewController as? UIAlertController {
					alert.view.isHidden = true
				}
			} else {
				webView.isHidden = tab.controller?.unused ?? true
				maskContent.isHidden = true
				bookmarkHistoryView.isHidden = !webView.isHidden
				urlBar?.progress = CGFloat(webView.estimatedProgress)
				urlBar?.attributedTitle = tab.formatedDisplayTitle
				updateSecAssessment()
				let allWindows = UIApplication.shared.windows
				if !allWindows.isEmpty {
					let windows = allWindows.suffix(from: 1)
					for window in windows {
						if let root = window.rootViewController {
							if root is LockPresenterController {
								continue
							}
						}
						window.isHidden = false
					}
				}
				if let alert = presentedViewController as? UIAlertController {
					alert.view.isHidden = false
				}
			}
		}
	}

	private var webView: WKWebView! {
		willSet {
			webView?.scrollView.delegate = nil
			webView?.removeFromSuperview()
		}
		didSet {
			if let webView = webView {
				webView.scrollView.delegate = self
				webView.scrollView.contentInsetAdjustmentBehavior = .never
				webView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
				webView.frame = view.bounds
				webView.allowsBackForwardNavigationGestures = true
				view.insertSubview(webView, belowSubview: downloadProgress)
				adjustWebviewSize(isIntemediate: isIntermediate(scale: scale))
			}
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		bookmarkHistoryView.showDownloads(!FileDownload.downloads.isEmpty, animated: false)
		bookmarkHistoryView.reloadDownloads()
		FileDownload.delegate = self
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .background
		view.clipsToBounds = true

		let mask = #imageLiteral(resourceName: "masked").withRenderingMode(.alwaysTemplate)
		maskImage.image = mask
		maskImage.tintColor = .title

		NotificationCenter.default.addObserver(self, selector: #selector(bookmarkListDidChange(_:)), name: BOOKMARK_LIST_CHANGED_NOTIFICATION, object: bookmarkStore)
		NotificationCenter.default.addObserver(self, selector: #selector(addedHistoryItem(_:)), name: INSERT_HISTORY_NOTIFICATION, object: historyStore)
		NotificationCenter.default.addObserver(self, selector: #selector(deletedHistoryItem(_:)), name: DELETE_HISTORY_NOTIFICATION, object: historyStore)

		NotificationCenter.default.addObserver(self, selector: #selector(reloadStatsView(_:)), name: statsResetNotificationName, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(reloadStatsView(_:)), name: SubscriptionManager.statusUpdatedNotification, object: nil)

		bookmarkHistoryView.delegate = self
		bookmarkHistoryView.constrainedWidth = traitCollection.horizontalSizeClass == .compact
		bookmarkHistoryView.constrainedHeight = traitCollection.verticalSizeClass == .compact
		bookmarkHistoryView.hideStats = !PolicyManager.globalManager().keepStats
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		adjustWebviewSize(isIntemediate: isIntermediate(scale: scale))
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
		tab?.controller?.UIDelegate = nil
	}
}

// MARK: Internals
private extension TabViewController {
	func isIntermediate(scale: CGFloat) -> Bool {
		return !(scale == 1 || scale == 0)
	}

	var scale: CGFloat {
		set {
			if newValue != scale {
				urlBar?.scale = newValue
				delegate?.showToolBar(degree: newValue)
				if newValue < 1 {
					stopInput()
				}
				adjustWebviewSize(isIntemediate: isIntermediate(scale: newValue))
			}
		}
		get {
			return urlBar?.scale ?? 1
		}
	}

	private func adjustWebviewSize(isIntemediate: Bool) {
		let bounds = delegate?.boundingViews()
		let topOffset: CGFloat
		if let top = bounds?.top {
			let topRect = top.convert(top.bounds, to: view)
			topOffset = max(topRect.maxY, 0)
		} else {
			topOffset = 0
		}
		let bottomOffset: CGFloat
		if let bottom = bounds?.bottom {
			let bottomRect = bottom.convert(bottom.bounds, to: view)
			bottomOffset = max(view.bounds.maxY - bottomRect.minY, 0)
		} else {
			bottomOffset = 0
		}
		let insets = UIEdgeInsets(top: topOffset, left: 0, bottom: bottomOffset, right: 0)

		if let wv = webView, wv.superview == view {
			let oldYOffset = wv.scrollView.bounds.minY + wv.scrollView.contentInset.top
			var tbInsets = UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
			let reducedHeight = max(0, urlBar?.minLowerBound(in: view) ?? 0)
			tbInsets.top -= reducedHeight
			var newFrame = view.bounds
			newFrame.origin.y += reducedHeight
			newFrame.size.height -= reducedHeight
			wv.frame = newFrame
			wv.frame.size.width -= insets.left + insets.right
			wv.frame.origin.x += insets.left
			if isIntemediate {
				wv.scrollView.contentInset = tbInsets
				wv.scrollView.horizontalScrollIndicatorInsets = tbInsets
				wv.scrollView.verticalScrollIndicatorInsets = tbInsets
			} else {
				wv.scrollView.contentInset = .zero
				wv.scrollView.horizontalScrollIndicatorInsets = .zero
				wv.scrollView.verticalScrollIndicatorInsets = .zero
				wv.frame.size.height -= tbInsets.top + tbInsets.bottom
				wv.frame.origin.y += tbInsets.top
			}
			let topCorrection = view.safeAreaInsets.top - wv.frame.minY
			if topCorrection > 0 {
				wv.scrollView.contentInset.top += topCorrection
				wv.scrollView.horizontalScrollIndicatorInsets.top += topCorrection
				wv.scrollView.verticalScrollIndicatorInsets.top += topCorrection
			}
			let bottomCorrection = view.safeAreaInsets.bottom - view.bounds.maxY + wv.frame.maxY
			if bottomCorrection > 0 {
				wv.scrollView.contentInset.bottom += bottomCorrection
				wv.scrollView.horizontalScrollIndicatorInsets.bottom += bottomCorrection
				wv.scrollView.verticalScrollIndicatorInsets.bottom += bottomCorrection
			}
			wv.scrollView.contentInset.scale(1 / contentScale)
			wv.scrollView.horizontalScrollIndicatorInsets.scale(1 / contentScale)
			wv.scrollView.verticalScrollIndicatorInsets.scale(1 / contentScale)
			wv.scrollView.bounds.origin.y = oldYOffset - wv.scrollView.contentInset.top
			wv.scrollView.adjustedContentInsetDidChange()
		}
		bookmarkHistoryView?.frame = view.bounds
		bookmarkHistoryView?.frame.size.height -= insets.top + insets.bottom
		bookmarkHistoryView?.frame.origin.y += insets.top

		downloadProgress.frame.origin.x = view.bounds.maxX - downloadProgress.frame.width - 8 - insets.right
		downloadProgress.frame.origin.y = view.bounds.maxY - downloadProgress.frame.height - 8 - insets.bottom
	}
}

// MARK: Control
extension TabViewController {
	func load(_ input: String) {
		tab?.controller?.load(userInput: input)
	}

	func webViewForShareAction() -> WKWebView? {
		return tab?.controller?.unused ?? true ? nil : webView
	}

	func stopInput() {
		urlBar?.stopInput()
	}

	func showHistory(animated: Bool) {
		bookmarkHistoryView.showHistory(true, animated: animated)
	}

	func showControls() {
		scale = 1
	}

	func updateSecAssessment(_ assessment: PolicyAssessmentResult? = nil) {
		guard let assessment = assessment ?? tab?.controller?.securityAssessment else {
			return
		}
		urlBar?.securityIconColor = assessment.color
		urlBar?.securityIcon = assessment.image
		urlBar?.securityName = assessment.name + NSLocalizedString("privacy assessment privacy suffix", comment: "privacy term to be appended to privacy assessment name")
	}

	func updateContentScale() {
		guard let tab = tab else {
			return
		}
		let newScale = PolicyManager.manager(for: tab).webContentScale
		if newScale != contentScale {
			contentScale = newScale
			webView.transform = CGAffineTransform(scaleX: contentScale, y: contentScale)
			adjustWebviewSize(isIntemediate: isIntermediate(scale: scale))
		}
	}
}

// MARK: Tab Controller UI Delegate
extension TabViewController: TabControllerUIDelegate {
	func tabController(_ controller: TabController, createTabForRequest request: URLRequest, inForeground: Bool) {
		delegate?.tabViewController(self, openTabForRequest: request, inForeground: inForeground)
	}

	func tabController(_ controller: TabController, displayAlert type: AlertType, forDomain domain: String?, fallbackHandler: @escaping () -> ()) -> Bool {
		guard !TabAlertTransitioningDelegate.shared.isBusy, presentedViewController == nil else {
			if let controller = tab?.controller {
				if TabAlertTransitioningDelegate.shared.isBusy {
					TabAlertTransitioningDelegate.shared.notify(controller: controller)
				} else {
					TabAlertTransitioningDelegate.shared.additionalNotify(controller: controller)
				}
			} else {
				fallbackHandler()
			}
			return false
		}
		let alert: UIAlertController
		if let domain = domain, !domain.isEmpty, tab?.controller?.shouldAllowIgnoreForIncedAlertCount(for: domain) ?? false {
			let ignoreTitle = NSLocalizedString("ignore alerts from this site alert button title", comment: "title of button to ignore further alerts by this site")
			let ignoreAction = UIAlertAction(title: ignoreTitle, style: .default) { [weak self] _ in
				self?.tab?.controller?.blockAlerts(from: domain)
				fallbackHandler()
			}
			alert = type.build(with: ignoreAction, at: -2)
		} else {
			alert = type.build()
		}
		if let urlBar = urlBar {
			alert.popoverPresentationController?.sourceView = urlBar
			alert.popoverPresentationController?.sourceRect = urlBar.shareButtonFrame(in: urlBar) ?? urlBar.bounds
		}

		TabAlertTransitioningDelegate.shared.setup(delegate: alert.transitioningDelegate)
		alert.transitioningDelegate = TabAlertTransitioningDelegate.shared
		present(alert, animated: true, completion: nil)
		return true
	}
}

// MARK: Tab Controller Navigation Delegate
extension TabViewController: TabControllerNavigationDelegate {
	func tabController(_ controller: TabController, didLoadTitle title: String?) {
		urlBar?.attributedTitle = tab?.formatedDisplayTitle
	}

	func tabController(_ controller: TabController, isLoading url: URL?) {
		urlBar?.url = controller.tab.displayURL
		Stats.shared.loading(url, in: controller.tab)
	}

	func tabController(_ controller: TabController, didUpgradeLoadOf url: URL) {
		Stats.shared.upgradedLoad(of: url, in: controller.tab)
	}

	func tabController(_ controller: TabController, estimatedProgress: Double) {
		if estimatedProgress > 0 && urlBar?.progress == 0 {
			stopInput()
			delegate?.stopShowingOverlays()
		}
		urlBar?.progress = CGFloat(estimatedProgress)
	}

	func tabControllerWillStartLoading(_ controller: TabController) {
		stopInput()
		urlBar?.stopInput()
		if webView.isHidden {
			webView.alpha = 0
			webView.isHidden = false
			UIView.animate(withDuration: 0.3, animations: {
				self.webView.alpha = 1
			}, completion: { _ in
				self.bookmarkHistoryView.isHidden = true
				self.bookmarkHistoryView.removeFromSuperview()
			})
		}
	}

	func tabController(_ controller: TabController, securityAssessmentDidUpdate assessment: PolicyAssessmentResult) {
		updateSecAssessment(assessment)
	}

	func tabControllerCanGoForwardBackwardUpdate(_ controller: TabController) {
		urlBar?.canGoBack = controller.canGoBack
		urlBar?.canGoForward = controller.canGoForward
	}

	func tabController(_ controller: TabController, serverTrustDidChange trust: SecTrust?) {
		urlBar?.attributedTitle = tab?.formatedDisplayTitle
	}
}

// MARK: Bookmark History Delegate
extension TabViewController: BookmarkHistoryDelegate {
	var viewControllerForSharing: UIViewController {
		return self
	}

	var viewControllerForPreviewing: UIViewController {
		return self
	}

	func previewController(for url: URL) -> PagePreviewController? {
		guard let tab = self.tab else {
			return nil
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		return PagePreviewController(url: url, tab: tab, delay: policy.previewDelay)
	}

	func load(_ type: WebLoadType) {
		tab?.controller?.load(type)
	}

	var historyItems: [[HistoryItem]]? {
		return historyStore.itemsByDate
	}

	func removeHistoryItem(at indexPath: IndexPath) {
		historyStore.removeItem(at: indexPath)
	}

	func removeSection(atIndex index: Int) {
		historyStore.removeSection(at: index)
	}

	func didSelect(historyItem item: HistoryItem) {
		tab?.controller?.load(url: item.url)
	}

	var bookmarks: [Bookmark] {
		return bookmarkStore.items
	}

	func didSelect(bookmark: Bookmark) {
		tab?.controller?.load(url: bookmark.URL)
		bookmark.wasSelected()
	}

	func remove(bookmark: Bookmark) {
		bookmarkStore.remove(item: bookmark)
	}

	func refresh(bookmark: Bookmark) {
		if let tab = tab {
			bookmark.reload(in: tab)
		}
	}

	func rename(bookmark: Bookmark) {
		delegate?.showRenameBar(fallback: bookmark.title, prefill: bookmark.name) { newName in
			bookmark.name = newName?.isEmpty == true ? nil : newName
		}
	}

	func makeBookmark(for url: URL) {
		if let tab = tab {
			bookmarkStore.addItem(for: url, loadWith: tab)
		}
	}

	func numerOfStats(in statsView: StatsView) -> Int {
		return 4
	}

	func titleOfStat(_ index: Int, in statsView: StatsView) -> String {
		switch index {
			case 0:		return NSLocalizedString("https upgrades usage stats name", comment: "name of the https upgrades usage stat")
			case 1:		return NSLocalizedString("blocked trackers usage stats name", comment: "name of the blocked trackers usage stat")
			case 2:		return NSLocalizedString("ephemeral cookies usage stats name", comment: "name of the ephemeral cookies usage stat")
			case 3:		return NSLocalizedString("vpn protected loads usage stats name", comment: "name of the vpn protected loads usage stat")
			default:	fatalError("unexpected index")
		}
	}

	func accessibilityFormatOfStat(_ index: Int, in statsView: StatsView) -> String {
		switch index {
			case 0:		return NSLocalizedString("https upgrades usage stats accessibility format", comment: "format of the accessibility label of the https upgrades usage stat")
			case 1:		return NSLocalizedString("blocked trackers usage stats accessibility format", comment: "format of the accessibility label of the blocked trackers usage stat")
			case 2:		return NSLocalizedString("ephemeral cookies usage stats accessibility format", comment: "format of the accessibility label of the ephemeral cookies usage stat")
			case 3:		return NSLocalizedString("vpn protected loads usage stats accessibility format", comment: "format of the accessibility label of the vpn protected loads usage stat")
			default:	fatalError("unexpected index")
		}
	}

	func countForStat(_ index: Int, in statsView: StatsView) -> Int {
		let stats = Stats.shared
		let count: UInt
		switch index {
			case 0:		count = stats.upgradedLoads
			case 1:		count = stats.blockedTrackers
			case 2:		count = stats.killedCookies
			case 3:		count = stats.protectedSiteLoads
			default:	fatalError("unexpected index")
		}
		return Int(count)
	}

	func colorForStat(_ index: Int, in statsView: StatsView) -> UIColor {
		switch index {
			case 0:		return .httpsStats
			case 1:		return .trackerStats
			case 2:		return .cookieStats
			case 3:		return .vpnStats
			default:	fatalError("unexpected index")
		}
	}

	func dimmStat(_ index: Int, in statsView: StatsView) -> Bool {
		return index == 3 && !SubscriptionManager.status.possible
	}

	func statTapped(at index: Int, in statsView: StatsView) {
		if index == 3 && !SubscriptionManager.status.possible {
			MainViewController.openSettings(type: .subscription)
		}
	}

	var downloads: [FileDownload] {
		return FileDownload.downloads
	}

	func delete(_ download: FileDownload, at index: Int) {
		FileDownload.delete(at: index)
	}

	func share(_ download: FileDownload, from sender: UIView) {
		guard let url = download.url, let superview = sender.superview else {
			return
		}
		let docController = UIDocumentInteractionController(url: url)
		docController.delegate = self
		docController.presentOpenInMenu(from: sender.frame, in: superview, animated: true)
		TabViewController.docController = docController
	}

	func retry(_ download: FileDownload) {
		download.start()
	}

	func cancel(_ download: FileDownload) {
		download.stop()
	}
}

// MARK: Notifications
extension TabViewController {
	@objc private func bookmarkListDidChange(_ notification: Notification) {
		let new = notification.userInfo?[NEW_BOOKMARKS_INDEX_USER_INFO_KEY] as? [Int]
		let deleted = notification.userInfo?[DELETED_BOOKMARKS_INDEX_USER_INFO_KEY] as? [Int]
		let from = notification.userInfo?[MOVED_BOOKMARKS_FROM_INDEX_USER_INFO_KEY] as? [Int]
		let to = notification.userInfo?[MOVED_BOOKMARKS_TO_INDEX_USER_INFO_KEY] as? [Int]
		bookmarkHistoryView.reloadBookmarks(new: new, deleted: deleted, movedFrom: from, movedTo: to)
	}

	@objc private func addedHistoryItem(_ notification: Notification) {
		guard let info = notification.userInfo else {
			return
		}
		guard let section = info[HISTORY_SECTION_INDEX] as? Int else {
			return
		}
		let index = info[HISTORY_ITEM_INDEX] as? Int
		bookmarkHistoryView.insertHistoryItem(section: section, index: index)
	}

	@objc private func deletedHistoryItem(_ notification: Notification) {
		guard let info = notification.userInfo else {
			return
		}
		guard let section = info[HISTORY_SECTION_INDEX] as? Int else {
			return
		}
		let index = info[HISTORY_ITEM_INDEX] as? Int
		bookmarkHistoryView.deleteHistoryItems(section: section, index: index)
	}

	@objc private func reloadStatsView(_ notification: Notification) {
		bookmarkHistoryView.hideStats = !PolicyManager.globalManager().keepStats
		bookmarkHistoryView.reloadStats()
	}
}

// MARK: UIContentContainer methods
extension TabViewController {
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		super.willTransition(to: newCollection, with: coordinator)
		bookmarkHistoryView.constrainedWidth = newCollection.horizontalSizeClass == .compact
		bookmarkHistoryView.constrainedHeight = newCollection.verticalSizeClass == .compact
	}
}

extension TabViewController: UIScrollViewDelegate {
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let hideLength: CGFloat = 150
		let originalScale = scale
		var finalScale = originalScale
		let yOffset = scrollView.bounds.origin.y + scrollView.contentInset.top
		let tooLow = yOffset < 0
		let tooHigh = scrollView.bounds.maxY > scrollView.contentSize.height - scrollView.contentInset.bottom
		let y: CGFloat? = tooLow || tooHigh ? nil : yOffset
		let useNewY = scrollView.isDragging && !scrollView.isZooming
		let newScrollPosition: CGFloat? = useNewY ? y : nil
		if let newPosition = newScrollPosition, let oldPosition = lastScrollPosition {
			let delta = oldPosition - newPosition
			let scrollUp = delta < 0
			if (scrollUp && scrollDirectionStrength > 0) || (!scrollUp && scrollDirectionStrength < 0) {
				let allowScaling = scrollView.contentSize.height - scrollView.bounds.height > 2.5 * hideLength || scale < 1
				if allowScaling && abs(delta) < hideLength {
					let diff = delta / hideLength
					finalScale = min(1,max(0,scale + diff))
					finalScale = min(1,max(finalScale, 3 - (yOffset) / 50))
				}
				scrollDirectionStrength = scrollUp ? 8 : -8
			} else {
				scrollDirectionStrength += scrollUp ? 1 : -1
			}
		}
		finalScale = min(1,max(finalScale, 1 - yOffset / 50))
		if !(originalScale == 1 && scrollView.isDecelerating && urlBar?.isEditing ?? false) {
			scale = finalScale
		}
		lastScrollPosition = newScrollPosition
	}

	private func collapse() {
		guard isIntermediate(scale: scale) else {
			return
		}
		webView?.scrollView.showsHorizontalScrollIndicator = false
		webView?.scrollView.showsVerticalScrollIndicator = false
		if scale < 0.67 {
			UIView.animate(withDuration: 0.2, animations: {
				self.scale = 0
			}) { [weak self] _ in
				self?.webView?.scrollView.showsHorizontalScrollIndicator = true
				self?.webView?.scrollView.showsVerticalScrollIndicator = true
			}
		} else {
			UIView.animate(withDuration: 0.2, animations: {
				self.scale = 1
			}) { [weak self] _ in
				self?.webView?.scrollView.showsHorizontalScrollIndicator = true
				self?.webView?.scrollView.showsVerticalScrollIndicator = true
			}
		}
	}

	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		collapse()
	}

	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if !decelerate {
			collapse()
		}
	}

	func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		UIView.animate(withDuration: 0.2) {
			self.scale = 1
		}
	}
}

private class TabAlertTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
	static let shared = TabAlertTransitioningDelegate()

	private(set) var proxiedDelegate: UIViewControllerTransitioningDelegate?
	private(set) var waitingControllers = [TabController]()
	private var additionalNotifyScheduled = false

	private func notify() {
		let oldWaiting = waitingControllers
		waitingControllers = []
		for controller in oldWaiting {
			controller.notifyNextUIEvent()
		}
	}

	func notify(controller: TabController) {
		precondition(isBusy)
		precondition(Thread.isMainThread)
		waitingControllers.append(controller)
	}

	// TODO: find clean solution
	func additionalNotify(controller: TabController) {
		precondition(!isBusy)
		precondition(Thread.isMainThread)
		waitingControllers.append(controller)
		guard !additionalNotifyScheduled else {
			return
		}
		additionalNotifyScheduled = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.additionalNotifyScheduled = false
			self.notify()
		}
	}

	func setup(delegate: UIViewControllerTransitioningDelegate?) {
		precondition(Thread.isMainThread)
		proxiedDelegate = delegate
	}

	private(set) var isBusy = false

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		isBusy = true
		return proxiedDelegate?.animationController?(forPresented: presented, presenting: presenting, source: source)
	}

	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		DispatchQueue.main.async {
			self.isBusy = false
			self.notify()
		}
		return proxiedDelegate?.animationController?(forDismissed: dismissed)
	}
}

extension TabViewController: FileDownloadDelegate {
	func downloadDeleted(_ download: FileDownload, index: Int) {
		bookmarkHistoryView.delete(download: index)
		if FileDownload.downloads.isEmpty {
			bookmarkHistoryView.showDownloads(false, animated: true)
		}
	}

	func newDownloadStarted(_ download: FileDownload) {
		bookmarkHistoryView.addDownload()
	}

	func downloadStatusChanged(_ download: FileDownload, index: Int) {
		bookmarkHistoryView.showDownloads(true, animated: true)
		bookmarkHistoryView.reload(download: index)
		downloadProgress.progress = FileDownload.progress
	}
}

extension TabViewController: DownloadProgressIndicatorDelegate {
	func downloadProgressIndicatorTapped(_ indicator: DownloadProgressIndicator) {
		if webView.isHidden {
			bookmarkHistoryView.showHistory(true, animated: true)
		} else {
			delegate?.showDownloads()
		}
	}
}

private extension UIEdgeInsets {
	mutating func scale(_ scale: CGFloat) {
		top *= scale
		bottom *= scale
		left *= scale
		right *= scale
	}
}

extension TabViewController: UIDocumentInteractionControllerDelegate {
	func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
		TabViewController.sendingFile = true
	}

	func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
		TabViewController.sendingFile = false
		TabViewController.docController = nil
	}

	func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
		if !TabViewController.sendingFile {
			TabViewController.docController = nil
		}
	}
}
