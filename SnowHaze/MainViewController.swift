//
//  ViewController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit
import WebKit
import AVFoundation

enum InputType {
	case plainInput
	case url
}

private let crashCountKey = "ch.illotros.snowhaze.crashCount"

class MainViewController: UIViewController {
	private(set) static var controller: MainViewController!

	@IBOutlet weak var pageContentView: UIView!
	@IBOutlet weak var urlBar: URLBar!
	@IBOutlet weak var tabToolBar: UIToolbar!
	@IBOutlet weak var navigationToolBarContainer: HeightChangingToolbarContainer!
	@IBOutlet weak var tabCollectionView: UICollectionView!
	@IBOutlet weak var moreButton: UIBarButtonItem? {
		didSet {
			moreButton?.accessibilityLabel = NSLocalizedString("more button accessibility label", comment: "accessibility label for more button (for tab settings)")
		}
	}

	private var textInputBar: TextInputBar?

	private var tabVC: TabViewController!
	private var suggestionVC: SuggestionViewController!
	private var suggestionContainer = UIView()

	private let animationDuration = 0.3
	private let tabControllerEdgeOffset: CGFloat = 5
	private let pageTapRecognizer = UITapGestureRecognizer()

	private let tabStore = TabStore.store
	private let dimmer = ScreenDimmer(dimming: 0.4, whiteStatusBar: true)
	private var windowMargin: CGFloat = 0
	private var showNavBarOnViewDisappear = false
	private var showToolbarPart: CGFloat = 1 {
		didSet {
			navigationToolBarContainer.scale = showToolbarPart
		}
	}
	private var showingSuggestionVC: Bool {
		return pageTapRecognizer.isEnabled
	}

	private enum OpenTask {
		case openTab(AnyObject)
		case loadInFreshTab(String, InputType)
	}

	private static var openTasks = [(OpenTask, (() -> Void)?)]()

	class func addEmptyTab(_ sender: AnyObject, completionHandler: (() -> Void)? = nil) {
		DispatchQueue.main.async {
			if let controller = controller {
				controller.addEmptyTab(sender)
				completionHandler?()
			} else {
				openTasks.append((.openTab(sender), completionHandler))
			}
		}
	}

	class func loadInFreshTab(input: String, type: InputType, completionHandler: (() -> Void)? = nil) {
		DispatchQueue.main.async {
			if let controller = controller {
				controller.loadInFreshTab(input: input, type: type)
				completionHandler?()
			} else {
				openTasks.append((.loadInFreshTab(input, type), completionHandler))
			}
		}
	}

	override var keyCommands: [UIKeyCommand]? {
		if isShowingTabsView {
			return []
		}
		let newTabTitle = NSLocalizedString("new tab key command title", comment: "discoverability title of key command to make a new tab")
		let newTab = UIKeyCommand(input: "N", modifierFlags: .command, action: #selector(makeNewTab(_:)), discoverabilityTitle: newTabTitle)
		if showingSuggestionVC {
			let cancelTitle = NSLocalizedString("cancel key command title", comment: "discoverability title of key command to cancel user input")
			let nextTitle = NSLocalizedString("next suggestion key command title", comment: "discoverability title of key command to select next suggestion")
			let previousTitle = NSLocalizedString("previous suggestion key command title", comment: "discoverability title of key command to select previous suggestion")
			let selectTitle = NSLocalizedString("open key command title", comment: "discoverability title of key command to open selected suggestion")
			let endInput = UIKeyCommand(input: UIKeyInputEscape, modifierFlags: UIKeyModifierFlags(rawValue: 0), action: #selector(endURLEntry(_:)), discoverabilityTitle: cancelTitle)
			let next = UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: .command, action: #selector(selectNextSuggestion(_:)), discoverabilityTitle: nextTitle)
			let previous = UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: .command, action: #selector(selectPreviousSuggestion(_:)), discoverabilityTitle: previousTitle)
			let select = UIKeyCommand(input: "O", modifierFlags: .command, action: #selector(selectSuggestion(_:)), discoverabilityTitle: selectTitle)
			var commands = [endInput]
			if suggestionVC.canSelectNext {
				commands.append(next)
			}
			if suggestionVC.canSelectPrevious {
				commands.append(previous)
			}
			if suggestionVC.hasSelection {
				commands.append(select)
			}
			commands.append(newTab)
			return commands
		}
		let searchTitle = NSLocalizedString("search key command title", comment: "discoverability title of key command to start search input")
		let startInput = UIKeyCommand(input: "F", modifierFlags: .command, action: #selector(startURLEntry(_:)), discoverabilityTitle: searchTitle)
		return [startInput, newTab]
	}

	override var canBecomeFirstResponder : Bool {
		return true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let crashCount: Int64
		if let oldCrashCount = DataStore.shared.getInt(for: crashCountKey) {
			crashCount = oldCrashCount + 1
		} else {
			crashCount = 0
		}
		DataStore.shared.set(crashCount, for: crashCountKey)

		let policy = PolicyManager.globalManager()
		policy.updateOpenedVersion()
		MainViewController.controller = self
		for wrapped in MainViewController.openTasks {
			let (task, completion) = wrapped
			DispatchQueue.main.async {
				switch task {
					case .openTab(let sender):					self.addEmptyTab(sender)
					case .loadInFreshTab(let input, let type):	self.loadInFreshTab(input: input, type: type)
				}
				completion?()
			}
		}
		tabCollectionView.register(TabCollectionViewCell.self, forCellWithReuseIdentifier: "TabCell")

		if #available(iOS 11.0, *) {
			tabCollectionView.contentInset = view.safeAreaInsets
		}

		navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.font: UIFont.snowHazeFont(size: 20)]

		let tab = crashCount != 2 ? currentTab : tabStore.addEmptyItem()!
		let tabPolicy = PolicyManager.manager(for: tab)
		dimmer.set(dimmed: tabPolicy.isInNightMode)
		setupSuggestionVC()
		set(tab: tab, animated: false)

		urlBar.tabTitleURLs = tabTitleURLs(masked: false)

		NotificationCenter.default.addObserver(self, selector: #selector(tabListDidChange(_:)), name: TAB_LIST_CHANGED_NOTIFICATION, object: tabStore)
		NotificationCenter.default.addObserver(self, selector: #selector(tabDidChange(_:)), name: TAB_CHANGED_NOTIFICATION, object: tabStore)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameDidChange(_:)), name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)

		urlBar.delegate = self

		// since the subviews aren't properly layed out yet, failing to to call view.layoutIfNeeded() can result in an oversized url field on iPad
		view.layoutIfNeeded()
		urlBar.constrainedWidth = traitCollection.horizontalSizeClass == .compact
		urlBar.constrainedHeight = traitCollection.verticalSizeClass == .compact

		navigationController?.navigationBar.tintColor = .button
		pageTapRecognizer.addTarget(self, action: #selector(backgroundTaped(_:)))
		pageTapRecognizer.isEnabled = false
		pageContentView.addGestureRecognizer(pageTapRecognizer)

		if policy.displayInstallTutorial {
			let tutorial = InstallTutorialViewController()
			present(tutorial, animated: true, completion: nil)
		}

		if policy.displayUpdateTutorial {
			let tutorial = UpdateTutorialViewController()
			present(tutorial, animated: true, completion: nil)
		}

		DownloadManager.shared.start()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		guard !LockController.isDisengagingUILock else {
			return
		}
		if let navigationController = navigationController {
			navigationController.setNavigationBarHidden(true, animated: animated)
			tabVC?.updateSecAssessment()
			for cell in tabCollectionView.visibleCells {
				let tabCell = cell as! TabCollectionViewCell
				tabCell.updateSecAssessment()
			}
		}
		let policy = PolicyManager.globalManager()
		if policy.showEOLWarning {
			let title = NSLocalizedString("old snowhaze version prompt title", comment: "title of prompt to warn user that their snowhaze version is old")
			let messageFormat = NSLocalizedString("old snowhaze version prompt message format", comment: "format string of message of prompt to warn user that their snowhaze version is old")
			let updateTitle = NSLocalizedString("old snowhaze version prompt update button title", comment: "title of button to lead users to the app store to update snowhaze")
			let cancelTitle = NSLocalizedString("old snowhaze version prompt ignore button title", comment: "title of button to ignore old snowhaze version warning")

			let message = String(format: messageFormat, versionDescription)
			let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
			let okAction = UIAlertAction(title: updateTitle, style: .default) { _ in
				if #available(iOS 10, *) {
					UIApplication.shared.open(URL(string: "https://itunes.apple.com/app/id1121026941")!)
				} else {
					UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/id1121026941")!)
				}
				policy.updateEOLWarningVersion()
			}
			alert.addAction(okAction)
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
				policy.updateEOLWarningVersion()
			}
			alert.addAction(cancelAction)
			present(alert, animated: true, completion: nil)
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if let navigationController = navigationController , showNavBarOnViewDisappear {
			navigationController.setNavigationBarHidden(false, animated: false)
			showNavBarOnViewDisappear = false
		}
	}

	override var preferredStatusBarStyle : UIStatusBarStyle {
		return .lightContent
	}

	@available(iOS 11, *)
	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		tabCollectionView.contentInset = view.safeAreaInsets
	}
}

// MARK: Internals
private extension MainViewController {
	var tabs: [Tab] {
		return tabStore.items
	}

	func close(_ tab: Tab) {
		let currentDeleted = tabVC.tab == tab

		let url = tab.controller?.url
		let policy = PolicyManager.manager(for: url, in: tab)
		tabStore.remove(tab, undoTime: policy.tabClosingUndoTimeLimit)

		if currentDeleted {
			tabVC.tab = nil
			set(tab: currentTab, animated: !isShowingTabsView)
		}
	}

	var isShowingTabsView: Bool {
		return !tabCollectionView.isHidden
	}

	func tabTitleURLs(masked: Bool) -> [(NSAttributedString, URL?)] {
		return tabs.map { tab in
			if masked && shouldMask(tab: tab) {
				let rawTitle = NSLocalizedString("masked tab title", comment: "displayed instead of title for masked tabs in app snapshots")
				let title = NSAttributedString(string: rawTitle)
				return (title, nil)
			} else {
				return (tab.formatedDisplayTitle, tab.displayURL)
			}
		}
	}

	var currentTab: Tab {
		for tab in tabs.reversed() where tab.isActive {
			return tab
		}
		return tabs.last ?? tabStore.addEmptyItem()!
	}

	@discardableResult func scroll(to tab: Tab, animated: Bool = true) -> IndexPath {
		let indexPath = IndexPath(item: tabs.index(of: tab)!, section: 0)
		tabCollectionView.scrollToItem(at: indexPath, at: [], animated: animated)
		return indexPath
	}

	func setupSuggestionVC() {
		view.addSubview(suggestionContainer)
		suggestionVC = SuggestionViewController()
		addChildViewController(suggestionVC)
		suggestionContainer.addSubview(suggestionVC.view)
		suggestionVC.didMove(toParentViewController: self)
		let width = min(view.bounds.width, 600)
		let y: CGFloat = urlBar.suggestionViewOrigin(in: view)
		suggestionContainer.frame = CGRect(x: (view.bounds.width - width) / 2, y: y, width: width, height: view.bounds.height - urlBar.bounds.maxY)
		suggestionVC.view.frame = suggestionContainer.bounds
		suggestionContainer.isHidden = true
		let flexibleSize: UIViewAutoresizing = [.flexibleWidth, .flexibleHeight]
		suggestionContainer.autoresizingMask = flexibleSize
		suggestionVC.view.autoresizingMask = flexibleSize
		suggestionVC.delegate = self
		suggestionVC.titleColor = .title
		suggestionVC.subtitleColor = .subtitle
		suggestionVC.backgroundColor = .bar
		suggestionVC.selectionColor = UIColor(white: 1, alpha: 0.2)
		suggestionVC.alwaysBounce = false
		suggestionContainer.layer.shadowOffset = CGSize(width: 1, height: 6)
		suggestionContainer.layer.shadowRadius = 2
		suggestionContainer.layer.shadowOpacity = 0.3
	}

	func updateSuggestionVCHeight() {
		suggestionContainer.frame.origin.y = urlBar?.suggestionViewOrigin(in: view) ?? 58
		let margins = suggestionContainer.frame.origin.y + windowMargin
		let height = view.bounds.height - margins
		suggestionContainer.frame.size.height = height
		suggestionContainer.isHidden = suggestionVC.sources.isEmpty
		let width = min(view.bounds.width, 500)
		suggestionContainer.frame.size.width = width
		suggestionContainer.frame.origin.x = (view.bounds.width - width) / 2
	}

	func set(tab: Tab, animated: Bool) {
		guard tabVC?.tab?.id != tab.id else {
			return
		}
		tabVC?.tab?.controller?.saveTabState()
		let oldTabVC = tabVC
		oldTabVC?.urlBar = nil
		guard let storyboard = storyboard else {
			return
		}
		tab.makeActive()
		tabVC = storyboard.instantiateViewController(withIdentifier: "TabViewController") as! TabViewController
		tabVC.delegate = self
		addChildViewController(tabVC)
		pageContentView.addSubview(tabVC.view)
		tabVC.didMove(toParentViewController: self)
		tabVC.urlBar = urlBar
		tabVC.tab = tab
		tabVC.view.frame = pageContentView.bounds
		tabVC.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		hideTextInputBar()
		updateNightMode()

		urlBar.selectedTab = tabs.index(of: tab) ?? -1

		if animated {
			tabVC.view.frame.origin.y += pageContentView.bounds.height
			UIView.animate(withDuration: animationDuration, animations: {
				self.tabVC.view.frame = self.pageContentView.bounds
			}, completion: { _ in
				oldTabVC?.tab = nil
				oldTabVC?.willMove(toParentViewController: nil)
				oldTabVC?.view.removeFromSuperview()
				oldTabVC?.removeFromParentViewController()
			})
		} else {
			oldTabVC?.tab = nil
			oldTabVC?.willMove(toParentViewController: nil)
			oldTabVC?.view.removeFromSuperview()
			oldTabVC?.removeFromParentViewController()
		}
	}

	func showActivityController(with extensionItem: NSExtensionItem?, webView: WKWebView?, tab: Tab?, sender: NSObject, initialHost opwHost: String?, policy: PolicyManager?) {
		var items = [AnyObject]()
		if let extensionItem = extensionItem, let _ = opwHost {
			items.append(extensionItem)
		}
		let dlHost: String?
		if let wv = webView, let h = wv.url?.host, let p = policy, p.allowPWManager, p.allowApplicationJS {
			if let extensionItem = DashlaneHelper.shared.extensionItem(for: wv) {
				items.append(extensionItem)
				dlHost = h
			} else {
				dlHost = nil
			}
		} else {
			dlHost = nil
		}
		if let webView = webView {
			if let title = webView.title {
				items.append(title as AnyObject)
			}
			if let url = webView.url {
				items.append(url as AnyObject)
			}
			items.append(PagePrintRenderer(webView: webView))
			items.append(webView)
			let info = UIPrintInfo(dictionary: nil)
			let untitledName = NSLocalizedString("untitled document name", comment: "name of document that has not been given a name")
			info.jobName = webView.title ?? webView.url?.absoluteString ?? untitledName
			info.outputType = .general
			items.append(info)
		}
		if let tab = tab {
			items.append(tab)
		}
		let scanActivity = ScanCodeActivity()
		scanActivity.source = sender
		scanActivity.delegate = self
		let readerActivity = StartReaderActivity() { [weak self] activity in
			guard let me = self, let tab = activity.tab, let url = tab.displayURL else {
				activity.activityDidFinish(false)
				return
			}
			guard let newtab = me.tabStore.addEmptyItem(with: URLRequest(url: url), copySettingsFromParent: tab) else {
				activity.activityDidFinish(false)
				return
			}
			let settings = Settings.settings(for: PolicyDomain(url: url), in: newtab)
			settings.set(.true, for: readerModeKey)
			me.set(tab: newtab, animated: true)
			activity.activityDidFinish(true)
		}
		let searchActivity = FindOnPageActivity() { activity in
			let bar = SearchBar()
			if self.set(inputBar: bar) {
				bar.search = Search(tab: activity.tab)
				bar.search.listener = self
				bar.searchBarDelegate = self
				bar.activity = activity
			} else {
				activity.activityDidFinish(false)
			}
		}
		var activities = [AddBookmarkActivity(), readerActivity, searchActivity]
		if scanActivity.available {
			activities.append(scanActivity)
		}
		let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
		controller.excludedActivityTypes = [UIActivityType.addToReadingList]
		// TODO: set an upper limit once bug is patched
		if #available(iOS 11, *) {
			// work arround a bug where iOS 11 tries to generate a file name from the title and fails if it is empty
			if let wv = webView, (wv.title ?? "").isEmpty {
				controller.excludedActivityTypes = (controller.excludedActivityTypes ?? []) + [UIActivityType.markupAsPDF]
			}
		}
		controller.completionWithItemsHandler = { [weak self] activityType, completed, returnedItems, error in
			self?.updateNightMode() // TODO: find way to display activity controller in night mode
			guard completed, let type = activityType, let p = policy, p.allowPWManager else {
				return
			}
			if let h = dlHost, webView?.url?.host == h {
				if DashlaneHelper.shared.isDashlaneResponce(type: type) {
					if let controller = tab?.controller {
						DashlaneHelper.shared.fill(controller, with: returnedItems, completion: nil)
					}
					return
				}
			}
			if let h = opwHost, webView?.url?.host == h {
				if OnePasswordExtension.shared().isOnePasswordExtensionActivityType(type.rawValue) || type.rawValue == "com.lastpass.ilastpass.LastPassExt" {
					if let webView = webView, let callback = tab?.controller?.enableJS() {
						OnePasswordExtension.shared().fillReturnedItems(returnedItems, intoWebView: webView) { _, _  in
							callback()
						}
					}
				}
			}
		}
		if sender.isKind(of: UIBarButtonItem.self) {
			controller.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
		} else if sender.isKind(of: UIView.self) {
			let view = sender as? UIView
			controller.popoverPresentationController?.sourceView = view?.superview;
			controller.popoverPresentationController?.sourceRect = view?.frame ?? CGRect.zero
		}
		dimmer.set(dimmed: false, animated: true) // TODO: find way to display activity controller in night mode
		present(controller, animated: true, completion: nil)
	}

	func showSettings() {
		performSegue(withIdentifier: "showSettings", sender: urlBar)
	}
}

// MARK: Public
extension MainViewController {
	func loadInFreshTab(input: String, type: InputType) {
		if !(tabVC.tab?.controller?.unused ?? false) {
			guard let tab = tabStore.addEmptyItem() else {
				return
			}
			set(tab: tab, animated: true)
		}
		hideTabsView(nil)
		switch type {
			case .url:			tabVC.tab?.controller?.load(url: URL(string: input))
			case .plainInput:	tabVC.tab?.controller?.load(userInput: input)
		}
	}

	func representingView(for tab: Tab?) -> UIView? {
		guard let tab = tab, let index = tabs.index(of: tab) else {
			return nil
		}
		return urlBar.representingViewForTab(at: index, isCurrent: true)
	}

	func popToVisible(animated: Bool) {
		_ = navigationController?.popToViewController(self, animated: animated)
	}

	func showSubscription() {
		let vcs = navigationController!.viewControllers
		let index = vcs.index(of: self)!
		let show: () -> Void = {
			self.showSettings()
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
				let top = self.navigationController?.topViewController
				if let splitMerge = top as? SplitMergeController, let settings = splitMerge.masterViewController as? SettingsViewController {
					settings.showSubscriptionSettings()
					return
				}
			}
		}
		if index + 1 < vcs.count {
			let next = vcs[index + 1]
			if let splitMerge = next as? SplitMergeController, let settings = splitMerge.masterViewController as? SettingsViewController {
				settings.showSubscriptionSettings()
				return
			}
			popToVisible(animated: true)
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3, execute: show)
			return
		}
		show()
	}
}

// MARK: Actions
extension MainViewController {
	@IBAction func showAdditionalTabOptions(_ sender: AnyObject) {
		let wrapper = SettingsDefaultWrapper.wrapGlobalSettings()
		let controller = TabSettingsController(wrapper: wrapper)
		let contentView = LocalSettingsView(controller: controller)
		let popover = DetailPopover(contentView: contentView, arrowPosition: .bottom(offset: 20)) {
			if #available(iOS 11, *) {
				let insets = self.view.safeAreaInsets
				return CGPoint(x: 30 + insets.left, y: self.view.bounds.height - 33 - insets.bottom)
			} else {
				return CGPoint(x: 30, y: self.view.bounds.height - 33)
			}
		}
		controller.callback = { [weak popover] values, temporary in
			assert(!temporary)
			guard let tab = self.tabStore.addEmptyItem(withSettings: values) else {
				return
			}
			self.scroll(to: tab)
			self.set(tab: tab, animated: false)
			self.hideTabsView(sender)
			popover?.dismiss(animated: true)
		}
		popover.show(in: view, animated: true) { _ in
			contentView.flashScrollIndicator()
		}
	}

	@IBAction func showTabsView(_ sender: AnyObject) {
		tabVC.stopInput()
		tabToolBar.isHidden = false
		tabCollectionView.isHidden = false
		tabToolBar.alpha = 0
		tabCollectionView.alpha = 0
		tabVC.tab?.controller?.saveTabState()
		if let tab = tabVC.tab {
			let indexPath = scroll(to: tab, animated: false)
			if let attributes = tabCollectionView.layoutAttributesForItem(at: indexPath) {
				let tabVC = self.tabVC
				UIView.animate(withDuration: animationDuration, animations: {
					var frame = attributes.frame
					frame.size.height -= TabCollectionViewCell.barHeight
					frame.origin.y += TabCollectionViewCell.barHeight
					frame.size.width -= self.tabControllerEdgeOffset * 2
					frame.origin.x += self.tabControllerEdgeOffset
					let convertedFrame = self.pageContentView.convert(frame, from: self.tabCollectionView)
					tabVC?.view.frame = convertedFrame
					tabVC?.view.layer.transform = attributes.transform3D
				})
			}
		}
		hideTextInputBar()
		UIView.animate(withDuration: animationDuration, animations: {
			self.tabToolBar.alpha = 1
			self.tabCollectionView.alpha = 1
			self.urlBar.alpha = 0
		})
		UIView.animate(withDuration: animationDuration / 3, delay: 2 * animationDuration / 3, animations: {
			self.pageContentView.alpha = 0
		}, completion: { finished in
			if finished {
				self.pageContentView.isHidden = true
			}
		})
	}

	@IBAction func addEmptyTab(_ sender: AnyObject) {
		let tab = tabStore.addEmptyItem()!
		scroll(to: tab)
		set(tab: tab, animated: false) // hideTabsView will animate change
		hideTabsView(sender)
	}

	@IBAction func hideTabsView(_ sender: AnyObject?) {
		self.popToVisible(animated: false)
		guard isShowingTabsView else {
			return
		}
		let id = tabVC.tab?.id ?? 0
		var lastTab: Tab? = nil
		for tab in tabs {
			if (lastTab == nil && tab.id >= id) || (tab.isActive && (lastTab?.isActive != true)) {
				lastTab = tab
			}
		}
		if lastTab == nil {
			lastTab = tabs.last
		}
		if lastTab == nil {
			lastTab = tabStore.addEmptyItem()
		}
		set(tab: lastTab!, animated: false)
		let indexPath = IndexPath(item: tabs.index(of: lastTab!)!, section: 0)
		if let attributes = tabCollectionView.layoutAttributesForItem(at: indexPath) {
			let tabVC = self.tabVC
			var frame = attributes.frame
			frame.size.height -= TabCollectionViewCell.barHeight
			frame.origin.y += TabCollectionViewCell.barHeight
			frame.size.width -= tabControllerEdgeOffset * 2
			frame.origin.x += tabControllerEdgeOffset
			let convertedFrame = pageContentView.convert(frame, from: tabCollectionView)
			tabVC?.view.frame = convertedFrame
			tabVC?.view.layer.transform = attributes.transform3D
		}
		UIView.animate(withDuration: animationDuration, animations: {
			self.tabVC.view.frame = self.pageContentView.bounds
			self.tabVC.view.layer.transform = CATransform3DIdentity
		})
		pageContentView.isHidden = false
		UIView.animate(withDuration: animationDuration / 3, animations: { () -> Void in
			self.pageContentView.alpha = 1
		})
		UIView.animate(withDuration: animationDuration, animations: {
			self.tabToolBar.alpha = 0
			self.tabCollectionView.alpha = 0
			self.urlBar.alpha = 1
		}, completion: { _ in
			self.tabToolBar.isHidden = true
			self.tabCollectionView.isHidden = true
		})
	}

	@objc private func backgroundTaped(_ sender: UITapGestureRecognizer?) {
		tabVC.stopInput()
	}

	@objc private func endURLEntry(_ sender: UIKeyCommand) {
		tabVC.stopInput()
	}

	@objc private func startURLEntry(_ sender: UIKeyCommand) {
		tabVC?.showControls()
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
			self?.urlBar.startInput()
		}
	}

	@objc private func selectNextSuggestion(_ sender: UIKeyCommand) {
		suggestionVC.selectNext()
	}

	@objc private func selectPreviousSuggestion(_ sender: UIKeyCommand) {
		suggestionVC.selectPrevious()
	}

	@objc private func selectSuggestion(_ sender: UIKeyCommand) {
		suggestionVC.openSelection()
	}

	@objc private func makeNewTab(_ sender: UIKeyCommand) {
		set(tab: tabStore.addEmptyItem()!, animated: true)
	}

	func updateNightMode() {
		guard let tab = tabVC?.tab else {
			return
		}
		let policy = PolicyManager.manager(for: tab)
		dimmer.set(dimmed: policy.isInNightMode, animated: true)
	}
}

// MARK: Collection View
extension MainViewController: UICollectionViewDataSource, UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return tabs.count
	}

	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TabCell", for: indexPath) as! TabCollectionViewCell
		cell.tab = tabs[indexPath.row]
		cell.delegate = self
		return cell
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		let tab = tabs[indexPath.row]
		set(tab: tab, animated: false)
		hideTabsView(collectionView.cellForItem(at: indexPath)!)
	}

	func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		let tabCell = cell as! TabCollectionViewCell
		tabCell.updateSecAssessment()
	}
}

// MARK: Tab Collection View Cell Delegate
extension MainViewController: TabCollectionViewCellDelegate {
	func closeTab(for tabCell: TabCollectionViewCell) {
		close(tabCell.tab!)
	}

	override func motionBegan(_ motion: UIEventSubtype, with event: UIEvent?) {
		if motion == .motionShake && isShowingTabsView {
			if let tab = tabStore.undoDeletion() {
				scroll(to: tab)
			}
		}
		super.motionBegan(motion, with: event)
	}
}

// MARK: URL Bar Delegate
extension MainViewController: URLBarDelegate {
	func prevButtonPressed(for urlBar: URLBar) {
		tabVC.tab?.controller?.goBack()
	}

	func nextButtonPressed(for urlBar: URLBar) {
		tabVC.tab?.controller?.goForward()
	}

	func shareButtonPressed(for urlBar: URLBar, sender: NSObject) {
		let webView = tabVC.webViewForShareAction()
		if let url = webView?.url, let tab = tabVC.tab, let host = url.host {
			let policy = PolicyManager.manager(for: url, in: tab)
			if policy.allowPWManager {
				let onePwExtension = OnePasswordExtension.shared()
				let opwAvailable = onePwExtension.isAppExtensionAvailable()
				if opwAvailable, let callback = tab.controller?.enableJS() {
					onePwExtension.createExtensionItem(forWebView: webView!) { (extentionItem, error) -> Void in
						callback()
						self.showActivityController(with: extentionItem, webView: webView, tab: tab, sender: sender, initialHost: host, policy: policy)
					}
					return
				}
			}
		}
		showActivityController(with: nil, webView: webView, tab: tabVC.tab, sender: sender, initialHost: nil, policy: nil)
	}

	func plusButtonPressed(for urlBar: URLBar) {
		set(tab: tabStore.addEmptyItem()!, animated: true)
	}

	func tabsButtonPressed(for urlBar: URLBar) {
		showTabsView(urlBar)
	}

	func settingsButtonPressed(for urlBar: URLBar) {
		showSettings()
	}

	func reloadButtonPressed(for urlBar: URLBar) {
		tabVC.tab?.controller?.reload()
	}

	func cancelLoad(for urlBar: URLBar) {
		tabVC.tab?.controller?.stopLoading()
	}

	func securityDetailButtonPressed(for urlBar: URLBar) {
		guard let tab = tabVC.tab, let url = tab.controller?.url else {
			let contentView = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 100))
			contentView.text = NSLocalizedString("local page settings unavailable notice", comment: "is displayed when the user presses the page security icon without having loaded a page first")
			contentView.numberOfLines = 3
			contentView.textAlignment = .center
			contentView.textColor = .localSettingsTitle
			UIFont.setSnowHazeFont(on: contentView)
			let popover = DetailPopover(contentView: contentView, arrowPosition: .top(offset: 20)) {
				let buttonFrame = urlBar.securityButtonFrame(in: self.view)
				let x = buttonFrame.midX
				let y = buttonFrame.maxY - 2
				return CGPoint(x: x, y: y)
			}
			popover.show(in: view, animated: true)
			return
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		let controller = PageSettingsController(wrapper: policy.settingsWrapper)
		controller.url = url
		let domain = PolicyDomain(url: url)
		let contentView = LocalSettingsView(controller: controller)
		let popover = DetailPopover(contentView: contentView, arrowPosition: .top(offset: 20)) {
			let buttonFrame = urlBar.securityButtonFrame(in: self.view)
			let x = buttonFrame.midX
			let y = buttonFrame.maxY - 2
			return CGPoint(x: x, y: y)
		}
		controller.callback = { [weak popover] values, temporary in
			Settings.atomically {
				let tmpSettings = Settings.settings(for: domain, in: tab)
				for (key, _) in values {
					tmpSettings.unsetValue(for: key)
				}
				let settings = temporary ? tmpSettings : Settings.settings(for: domain)
				let oldSaveHistory = settings.value(for: saveHistoryKey)
				let newSaveHistory = values[saveHistoryKey]
				if newSaveHistory?.boolValue == false && oldSaveHistory?.boolValue == true {
					let maxAge: TimeInterval? = temporary ? 5 * 60 : nil
					HistoryStore.store.removeItems(with: url.host, maxAge: maxAge)
				}
				for (key, value) in values {
					settings.set(value, for: key)
				}
			}
			popover?.dismiss(animated: true)
			if !values.isEmpty {
				tab.controller?.reload()
			}
		}
		popover.show(in: view, animated: true) { _ in
			contentView.flashScrollIndicator()
		}
	}

	func inputStringUpdated(for urlBar: URLBar, input: String) {
		tabVC?.showControls()
		showSuggestions(searchString: input)
	}

	func urlbar(_ urlBar: URLBar, selectedInput: String) {
		tabVC?.load(selectedInput)
	}

	func inputEnded(for urlBar: URLBar) {
		stopShowingSuggestions()
	}

	func urlbar(_ urlBar: URLBar, selectedTab tab: Int) {
		let selectedTab = tabs[tab]
		if selectedTab == tabVC?.tab && urlBar.scale < 0.5 {
			tabVC?.showControls()
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) { [weak self] in
				self?.urlBar.startInput()
			}
		} else {
			set(tab: selectedTab, animated: false)
		}
	}

	func urlbar(_ urlBar: URLBar, closedTab index: Int) {
		close(tabs[index])
	}

	func urlbar(_ urlBar: URLBar, loadedURL url: URL, atIndex index: Int) {
		tabs[index].controller?.load(url: url)
	}
}

// MARK: Tab View Controller Delegate
extension MainViewController: TabViewControllerDelegate {
	func tabViewController(_ controller: TabViewController, openTabForRequest request: URLRequest) {
		guard let tab = tabStore.addEmptyItem(with: request, copySettingsFromParent: controller.tab!) else {
			return
		}
		set(tab: tab, animated: true)
	}

	func showSuggestions(searchString: String) {
		guard let tab = tabVC.tab else {
			return
		}
		let policy = PolicyManager.manager(for: tab)
		suggestionVC.sources = policy.searchSuggestionSources(for: tab)

		suggestionVC.baseString = searchString
		suggestionContainer.isHidden = suggestionVC.sources.isEmpty
		pageTapRecognizer.isEnabled = true
		UIView.animate(withDuration: 0.3, animations: {
			self.suggestionContainer.alpha = self.suggestionVC.sources.isEmpty ? 0 : 1
		})
	}

	func stopShowingSuggestions() {
		suggestionVC.cancelSuggestions()
		UIView.animate(withDuration: 0.3, animations: {
			self.suggestionContainer.alpha = 0
		}, completion: { _ in
			self.suggestionContainer.isHidden = true
			self.pageTapRecognizer.isEnabled = false
		})
	}

	func showToolBar(degree: CGFloat) {
		showToolbarPart = degree
	}

	func stopShowingOverlays() {
		hideTextInputBar()
		stopShowingSuggestions()
	}

	func showRenameBar(fallback: String?, prefill: String?, callback: @escaping (String?) -> Void) {
		let bar = BookmarkRenameBar()
		bar.callback = callback
		bar.textField.text = prefill
		bar.textField.placeholder = fallback
		set(inputBar: bar)
	}

	func boundingViews() -> (top: UIView?, bottom: UIView?) {
		return (urlBar, navigationToolBarContainer)
	}
}

// MARK: Code Scanner Delegate
extension MainViewController: ScanCodeActivityDelegate {
	func activity(_ activity: ScanCodeActivity, didScanCode code: String) {
		loadInFreshTab(input: code, type: .plainInput)
	}
}

// MARK: Suggestion View Controller Delegate
extension MainViewController: SuggestionViewControllerDelegate {
	func suggestionController(_ controller: SuggestionViewController, didSelectURL url: URL) {
		tabVC.tab?.controller?.load(url: url)
		controller.baseString = nil
	}
}

// MARK: UIContentContainer methods
extension MainViewController {
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		super.willTransition(to: newCollection, with: coordinator)
		urlBar?.constrainedWidth = newCollection.horizontalSizeClass == .compact
		let constrainedHeight = newCollection.verticalSizeClass == .compact
		urlBar?.constrainedHeight = constrainedHeight
		updateSuggestionVCHeight()
		navigationToolBarContainer.invalidateIntrinsicContentSize()
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		DispatchQueue.main.async {
			self.updateSuggestionVCHeight()
		}
	}
}

// MARK: Notifications
extension MainViewController {
	@objc private func tabListDidChange(_ notification: Notification) {
		let newIndexes = notification.userInfo?[NEW_TABS_INDEX_KEY] as? [Int] ?? []
		let deletedIndexes = notification.userInfo?[DELETED_TABS_INDEX_KEY] as? [Int] ?? []
		let fromIndexes = notification.userInfo?[MOVED_TABS_FROM_INDEX_KEY] as? [Int] ?? []
		let toIndexes = notification.userInfo?[MOVED_TABS_TO_INDEX_KEY] as? [Int] ?? []
		let newPaths = newIndexes.map { IndexPath(item: $0, section: 0) }
		let deletedPaths = deletedIndexes.map { IndexPath(item: $0, section: 0) }
		let fromPaths = fromIndexes.map { IndexPath(item: $0, section: 0) }
		let toPaths = toIndexes.map { IndexPath(item: $0, section: 0) }
		tabCollectionView.performBatchUpdates({
			self.tabCollectionView.insertItems(at: newPaths)
			self.tabCollectionView.deleteItems(at: deletedPaths)
			for (index, fromPath) in fromPaths.enumerated() {
				let toPath = toPaths[index]
				self.tabCollectionView.moveItem(at: fromPath, to: toPath)
			}
		}, completion: nil);
		urlBar.tabTitleURLs = tabTitleURLs(masked: false)

		if let tab = tabVC?.tab {
			urlBar.selectedTab = tabs.index(of: tab) ?? -1
		}
	}

	@objc private func tabDidChange(_ notification: Notification) {
		urlBar.tabTitleURLs = tabTitleURLs(masked: false)
	}

	@objc private func keyboardFrameDidChange(_ notification: Notification) {
		guard let info = notification.userInfo else {
			return
		}
		let duration = info[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber ?? NSNumber(value: 0.3 as Double)
		let curveValue = info[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber ?? NSNumber(value: 0 as Int32)
		let curve = UIViewAnimationOptions(rawValue: curveValue.uintValue)
		let endValue = info[UIKeyboardFrameEndUserInfoKey] as? NSValue
		let endRect = endValue?.cgRectValue ?? CGRect.zero
		let viewRect = view.convert(endRect, from: view.window)
		windowMargin = viewRect.size.height
		var searchBarY: CGFloat
		let searchBarHeight = textInputBar?.bounds.height ?? 0
		if viewRect.maxY < view.bounds.maxY - 100 {
			searchBarY = view.bounds.maxY - searchBarHeight
		} else {
			searchBarY = viewRect.minY - searchBarHeight
		}
		if #available(iOS 11, *) {
			searchBarY = min(view.bounds.maxY - searchBarHeight - view.safeAreaInsets.bottom, searchBarY)
		}
		UIView.animate(withDuration: duration.doubleValue, delay: 0, options: curve, animations: {
			self.updateSuggestionVCHeight()
			self.textInputBar?.frame.origin.y = searchBarY
		}, completion: nil)
	}

	private func shouldMask(tab: Tab?) -> Bool {
		guard let tab = tab else {
			return false
		}
		let url = tab.controller?.url
		let policy = PolicyManager.manager(for: url, in: tab)
		return policy.shouldMask && !(tab.controller?.unused ?? false)
	}

	@objc private func didEnterBackground(_ notification: Notification) {
		DataStore.shared.delete(crashCountKey)

		tabVC.isMasked = shouldMask(tab: tabVC.tab)
		urlBar.tabTitleURLs = tabTitleURLs(masked: true)
		for cell in tabCollectionView.visibleCells {
			let tabCell = cell as! TabCollectionViewCell
			tabCell.isMasked = shouldMask(tab: tabCell.tab)
		}
	}

	@objc private func willEnterForeground(_ notification: Notification) {
		tabVC.isMasked = false
		urlBar.tabTitleURLs = tabTitleURLs(masked: false)
		for cell in tabCollectionView.visibleCells {
			let tabCell = cell as! TabCollectionViewCell
			tabCell.isMasked = false
		}
	}
}

// MARK: Transitions
extension MainViewController {
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "showSettings" {
			let settingVC = storyboard!.instantiateViewController(withIdentifier: "settingsViewController")
			let splitVC = segue.destination as! SplitMergeController
			splitVC.masterViewController = settingVC
			showNavBarOnViewDisappear = true
		}
	}
}

// MARK: In Page Search
extension MainViewController: SearchBarDelegate, SearchListener {
	@discardableResult private func set(inputBar bar: TextInputBar) -> Bool {
		guard textInputBar == nil else {
			return false
		}
		self.textInputBar = bar
		bar.textField.keyboardAppearance = .dark
		bar.delegate = self
		bar.frame.size.width = self.view.bounds.width
		bar.frame.origin.y = self.view.bounds.maxY + 10
		bar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		self.view.addSubview(bar)
		UIView.animate(withDuration: self.animationDuration, animations: {
			if #available(iOS 11, *) {
				bar.frame.origin.y = self.view.bounds.maxY - bar.frame.height - self.view.safeAreaInsets.bottom
			} else {
				bar.frame.origin.y = self.view.bounds.maxY - bar.frame.height
			}
		})
		bar.textField.becomeFirstResponder()
		return true
	}

	private func hideTextInputBar() {
		if let searchBar = textInputBar as? SearchBar {
			searchBar.search.searchPattern = ""
		}
		if let textInputBar = self.textInputBar {
			textInputBar.textField.resignFirstResponder()
			self.textInputBar = nil
			UIView.animate(withDuration: 0.12, delay: 0, options: UIViewAnimationOptions(rawValue: UInt(UIViewAnimationCurve.easeOut.rawValue)), animations: {
				textInputBar.frame.origin.y = self.view.bounds.maxY + 10
			}, completion: { (_) -> Void in
				textInputBar.removeFromSuperview()
			})
		}
	}

	func textInputBar(_ bar: TextInputBar, willUpdateText newText: String) {
		if let searchBar = bar as? SearchBar {
			searchBar.offsetText = ""
			searchBar.search.searchPattern = newText
		}
	}

	func textInputBarDidDismiss(_ bar: TextInputBar) {
		if let searchBar = bar as? SearchBar {
			searchBar.activity?.activityDidFinish(true)
		}
		if let bookmarkBar = bar as? BookmarkRenameBar , !bookmarkBar.wasCanceled {
			bookmarkBar.callback?(bookmarkBar.textField.text)
		}
		hideTextInputBar()
	}

	func searchBarSelectNext(_ bar: SearchBar) {
		bar.search.highlightNext()
	}

	func searchBarSelectPrevious(_ bar: SearchBar) {
		bar.search.highlightPrev()
	}

	func search(_ search: Search, indexDidUpdateTo index: UInt, of count: UInt) {
		if index > 0 {
			(textInputBar as? SearchBar)?.offsetText = count > 0 ? "\(index) / \(count)" : "0"
		} else {
			(textInputBar as? SearchBar)?.offsetText = ""
		}
	}
}
