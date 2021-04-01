//
//  ViewController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit
import WebKit
import AVFoundation

private let crashCountKey = "ch.illotros.snowhaze.crashCount"

private let animationDuration = 0.3
private let tabControllerEdgeOffset: CGFloat = 5

private extension UIKeyCommand {
	convenience init(input: String, modifierFlags: UIKeyModifierFlags, action: Selector, title: String) {
		self.init(input: input, modifierFlags: modifierFlags, action: action)
		self.discoverabilityTitle = title
	}
}

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

	private enum LaunchTask {
		case openTab(AnyObject)
		case openSettings(SettingsViewController.SettingsType, Bool)
		case loadInFreshTab(String, InputType)
		case rotateIPSecCreds
	}

	private static var openTasks = [(LaunchTask, (() -> ())?)]()

	private class func perform(_ action: LaunchTask, completionHandler: (() -> ())?) {
		DispatchQueue.main.async {
			if let controller = controller {
				switch action {
					case .openTab(let sender):					controller.addEmptyTab(sender)
					case .openSettings(let type, let unfold):	controller.openSettings(type, unfold: unfold)
					case .loadInFreshTab(let input, let type):	controller.loadInFreshTab(input: input, type: type)
					case .rotateIPSecCreds:						VPNManager.shared.swapIPSecCreds(runningLongerThan: 60, force: true)
				}
				completionHandler?()
			} else {
				openTasks.append((action, completionHandler))
			}
		}
	}

	class func addEmptyTab(_ sender: AnyObject, completionHandler: (() -> ())? = nil) {
		MainViewController.perform(.openTab(sender), completionHandler: completionHandler)
	}

	class func openSettings(type: SettingsViewController.SettingsType, unfold: Bool = false, completionHandler: (() -> ())? = nil) {
		MainViewController.perform(.openSettings(type, unfold), completionHandler: completionHandler)
	}

	class func rotateIPSecCreds(completionHandler: (() -> ())? = nil) {
		MainViewController.perform(.rotateIPSecCreds, completionHandler: completionHandler)
	}

	class func loadInFreshTab(input: String, type: InputType, completionHandler: (() -> ())? = nil) {
		MainViewController.perform(.loadInFreshTab(input, type), completionHandler: completionHandler)
	}

	override var keyCommands: [UIKeyCommand]? {
		if isShowingTabsView {
			return []
		}
		let newTabTitle = NSLocalizedString("new tab key command title", comment: "discoverability title of key command to make a new tab")
		let newTab = UIKeyCommand(input: "T", modifierFlags: .command, action: #selector(makeNewTab(_:)), title: newTabTitle)
		var commands = [newTab]
		if showingSuggestionVC {
			let cancelTitle = NSLocalizedString("cancel key command title", comment: "discoverability title of key command to cancel user input")
			let nextTitle = NSLocalizedString("next suggestion key command title", comment: "discoverability title of key command to select next suggestion")
			let previousTitle = NSLocalizedString("previous suggestion key command title", comment: "discoverability title of key command to select previous suggestion")
			let selectTitle = NSLocalizedString("open key command title", comment: "discoverability title of key command to open selected suggestion")
			let endInput = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: UIKeyModifierFlags(rawValue: 0), action: #selector(endURLEntry(_:)), title: cancelTitle)
			let next = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: .command, action: #selector(selectNextSuggestion(_:)), title: nextTitle)
			let previous = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: .command, action: #selector(selectPreviousSuggestion(_:)), title: previousTitle)
			let select = UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(selectSuggestion(_:)), title: selectTitle)
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
			return commands
		} else if let _ = textInputBar {
			let endTitle = NSLocalizedString("end text input key command title", comment: "discoverability title of key command to cancel text input in text bar")
			let endInput = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: UIKeyModifierFlags(rawValue: 0), action: #selector(endTextEntry(_:)), title: endTitle)
			commands.append(endInput)
		}
		if !isShowingTabsView {
			let searchTitle = NSLocalizedString("search key command title", comment: "discoverability title of key command to start search input")
			let startInput = UIKeyCommand(input: "L", modifierFlags: .command, action: #selector(startURLEntry(_:)), title: searchTitle)

			let closeTitle = NSLocalizedString("close tab key command title", comment: "discoverability title of key command to close a tab")
			let close = UIKeyCommand(input: "W", modifierFlags: .command, action: #selector(closeTab(_:)), title: closeTitle)
			commands += [startInput, close]
			if tabVC?.tab?.controller?.canGoBack ?? false {
				let backTitle = NSLocalizedString("go back in history key command title", comment: "discoverability title of key command to go back in history")
				let back1 = UIKeyCommand(input: "[", modifierFlags: .command, action: #selector(historyBack(_:)), title: backTitle)
				let back2 = UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: .command, action: #selector(historyBack(_:)), title: backTitle)
				commands += [back1, back2]
			}
			if tabVC?.tab?.controller?.canGoForward ?? false {
				let forwardTitle = NSLocalizedString("go forward in history key command title", comment: "discoverability title of key command to go forward in history")
				let forward1 = UIKeyCommand(input: "]", modifierFlags: .command, action: #selector(historyForward(_:)), title: forwardTitle)
				let forward2 = UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: .command, action: #selector(historyForward(_:)), title: forwardTitle)
				commands += [forward1, forward2]
			}
			if tabVC?.tab?.controller?.webViewLoaded ?? false, let _ = tabVC?.tab?.controller?.url {
				let searchTitle = NSLocalizedString("search on page key command title", comment: "discoverability title of key command to search for text on a page")
				let search = UIKeyCommand(input: "F", modifierFlags: .command, action: #selector(searchOnPage(_:)), title: searchTitle)
				commands.append(search)

				let reloadTitle = NSLocalizedString("reload page key command title", comment: "discoverability title of key command to reload a page")
				let reload = UIKeyCommand(input: "R", modifierFlags: .command, action: #selector(reloadPage(_:)), title: reloadTitle)
				commands.append(reload)
				if tabVC?.tab?.controller?.isLoading ?? false {
					let stopTitle = NSLocalizedString("stop page load key command title", comment: "discoverability title of key command to stop the loading of a page")
					let stop = UIKeyCommand(input: ",", modifierFlags: .command, action: #selector(stopLoadingPage(_:)), title: stopTitle)
					commands.append(stop)
				}
			}
			if tabs.count > 1 {
				let previousTitle = NSLocalizedString("previous tab key command title", comment: "discoverability title of key command to switch to previous tab")
				let previous = UIKeyCommand(input: "[", modifierFlags: [.command, .shift], action: #selector(previousTab(_:)), title: previousTitle)

				let nextTitle = NSLocalizedString("next tab key command title", comment: "discoverability title of key command to switch to next tab")
				let next = UIKeyCommand(input: "]", modifierFlags: [.command, .shift], action: #selector(nextTab(_:)), title: nextTitle)
				commands.append(previous)
				commands.append(next)
			}
			return commands
		} else {
			return commands
		}
	}

	override var canBecomeFirstResponder : Bool {
		return true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("main view controller navigation title", comment: "title of the main view controller for back buttons in settings")

		let crashCount: Int64
		if let oldCrashCount = DataStore.shared.getInt(for: crashCountKey) {
			crashCount = oldCrashCount + 1
		} else {
			crashCount = 0
		}
		DataStore.shared.set(crashCount, for: crashCountKey)

		let policy = PolicyManager.globalManager()
		policy.updateOpenedVersion()
		policy.performLaunchOperations()
		MainViewController.controller = self
		let tasks = MainViewController.openTasks
		MainViewController.openTasks = []
		for wrapped in tasks {
			let (task, completion) = wrapped
			MainViewController.perform(task, completionHandler: completion)
		}
		tabCollectionView.register(TabCollectionViewCell.self, forCellWithReuseIdentifier: "TabCell")
		tabCollectionView.contentInset = view.safeAreaInsets

		let tab: Tab
		if crashCount != 2 {
			tab = policy.hasHomePage ? tabStore.add()! : currentTab
		} else {
			tab = tabStore.add(loadHomepage: false)!
		}
		let tabPolicy = PolicyManager.manager(for: tab)
		dimmer.set(dimmed: tabPolicy.isInNightMode)
		setupSuggestionVC()

		urlBar.tabTitleURLs = tabTitleURLs(masked: false)
		set(tab: tab, animated: false)

		NotificationCenter.default.addObserver(self, selector: #selector(tabListDidChange(_:)), name: TAB_LIST_CHANGED_NOTIFICATION, object: tabStore)
		NotificationCenter.default.addObserver(self, selector: #selector(tabDidChange(_:)), name: TAB_CHANGED_NOTIFICATION, object: tabStore)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardFrameDidChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		urlBar.delegate = self

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

		DownloadManager.shared.start()

		// start compiling, since this might take a while
		ContentBlockerManager.shared.load(completionHandler: nil)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		guard !LockController.isDisengagingUILock else {
			return
		}
		if let navigationController = navigationController {
			navigationController.setNavigationBarHidden(true, animated: animated)
			tabVC?.updateSecAssessment()
			tabVC?.updateContentScale()
			for cell in tabCollectionView.visibleCells {
				let tabCell = cell as! TabCollectionViewCell
				tabCell.updateSecAssessment()
			}
		}
		let policy = PolicyManager.globalManager()
		if policy.showEOLWarning {
			present(AlertType.update.build(), animated: true, completion: nil)
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

		Stats.shared.updateCookieCount(for: tab)

		let url = tab.controller?.url
		let policy = PolicyManager.manager(for: url, in: tab)
		tabStore.remove(tab, undoTime: policy.tabClosingUndoTimeLimit)

		ReviewPrompt.tabClosed()

		if currentDeleted {
			tabVC.tab = nil
			if !isShowingTabsView {
				set(tab: currentTab, animated: true)
			}
		}
	}

	func closeAllTabs() {
		tabStore.remove(tabs.map({ tab -> (Tab, TimeInterval) in
			Stats.shared.updateCookieCount(for: tab)
			let url = tab.controller?.url
			let policy = PolicyManager.manager(for: url, in: tab)
			return (tab, policy.tabClosingUndoTimeLimit)
		}))

		ReviewPrompt.allTabsClosed()

		tabVC.tab = nil
		if !isShowingTabsView {
			set(tab: self.tabStore.add()!, animated: true)
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
		return tabs.last ?? tabStore.add()!
	}

	@discardableResult func scroll(to tab: Tab, animated: Bool = true) -> IndexPath? {
		guard let index = tabs.firstIndex(of: tab) else {
			return nil
		}
		let indexPath = IndexPath(item: index, section: 0)
		tabCollectionView.scrollToItem(at: indexPath, at: [], animated: animated)
		return indexPath
	}

	func setupSuggestionVC() {
		view.addSubview(suggestionContainer)
		suggestionVC = SuggestionViewController()
		addChild(suggestionVC)
		suggestionContainer.addSubview(suggestionVC.view)
		suggestionVC.didMove(toParent: self)
		let width = min(view.bounds.width, 600)
		let y: CGFloat = urlBar.suggestionViewOrigin(in: view)
		suggestionContainer.frame = CGRect(x: (view.bounds.width - width) / 2, y: y, width: width, height: view.bounds.height - urlBar.bounds.maxY)
		suggestionVC.view.frame = suggestionContainer.bounds
		suggestionContainer.isHidden = true
		let flexibleSize: UIView.AutoresizingMask = [.flexibleWidth, .flexibleHeight]
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

	func startSearch(tab: Tab, activity: UIActivity?) {
		let bar = SearchBar()
		if self.set(inputBar: bar) {
			bar.search = Search(tab: tab)
			bar.search.listener = self
			bar.searchBarDelegate = self
			bar.activity = activity
		} else {
			activity?.activityDidFinish(false)
		}
	}

	func set(tab: Tab, animated: Bool) {
		guard tabVC?.tab?.id != tab.id else {
			return
		}
		tabVC?.tab?.controller?.saveTabState()
		let oldTabVC = tabVC
		oldTabVC?.urlBar = nil
		if let tab = oldTabVC?.tab {
			Stats.shared.updateCookieCount(for: tab)
		}
		guard let storyboard = storyboard else {
			return
		}
		tab.makeActive()
		tabVC = (storyboard.instantiateViewController(withIdentifier: "TabViewController") as! TabViewController)
		tabVC.delegate = self
		addChild(tabVC)
		pageContentView.addSubview(tabVC.view)
		tabVC.didMove(toParent: self)
		tabVC.urlBar = urlBar
		tabVC.tab = tab
		tabVC.view.frame = pageContentView.bounds
		tabVC.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		hideTextInputBar()
		updateNightMode()

		urlBar.selectedTab = tabs.firstIndex(of: tab) ?? -1

		if animated {
			tabVC.view.frame.origin.y += pageContentView.bounds.height
			UIView.animate(withDuration: animationDuration, animations: {
				self.tabVC.view.frame = self.pageContentView.bounds
			}, completion: { _ in
				oldTabVC?.tab = nil
				oldTabVC?.willMove(toParent: nil)
				oldTabVC?.view.removeFromSuperview()
				oldTabVC?.removeFromParent()
			})
		} else {
			oldTabVC?.tab = nil
			oldTabVC?.willMove(toParent: nil)
			oldTabVC?.view.removeFromSuperview()
			oldTabVC?.removeFromParent()
		}
	}

	func showSettings() {
		performSegue(withIdentifier: "showSettings", sender: urlBar)
	}
}

// MARK: Public
extension MainViewController {
	func loadInFreshTab(input: String, type: InputType) {
		if !(tabVC.tab?.controller?.unused ?? false) {
			guard let tab = tabStore.add(loadHomepage: false) else {
				return
			}
			set(tab: tab, animated: true)
		}
		hideTabsView(nil)
		tabVC.tab?.controller?.load(input: input, type: type)
	}

	func loadInFreshTorTab(input: String, type: InputType) {
		if let tab = tabVC.tab, tab.controller?.unused ?? false, PolicyManager.manager(for: tab).useTor {
			// use the existing tab
		} else {
			guard let tab = tabStore.add(withSettings: [useTorNetworkKey: .true], loadHomepage: false) else {
				return
			}
			set(tab: tab, animated: true)
		}
		hideTabsView(nil)
		tabVC.tab?.controller?.load(input: input, type: type)
	}

	func representingView(for tab: Tab?) -> UIView? {
		guard let tab = tab, let index = tabs.firstIndex(of: tab) else {
			return nil
		}
		return urlBar.representingViewForTab(at: index, isCurrent: true)
	}

	func popToVisible(animated: Bool) {
		_ = navigationController?.popToViewController(self, animated: animated)
	}

	func openSettings(_ type: SettingsViewController.SettingsType? = nil, unfold: Bool = false) {
		let vcs = navigationController!.viewControllers
		let index = vcs.firstIndex(of: self)!
		let show: () -> () = {
			SettingsViewController.requestedType = (type, unfold)
			self.showSettings()
		}
		if index + 1 < vcs.count {
			let next = vcs[index + 1]
			if let splitMerge = next as? SplitMergeController, let settings = splitMerge.masterViewController as? SettingsViewController {
				settings.showSettings(type, unfold: unfold)
				return
			}
			popToVisible(animated: true)
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + animationDuration + 0.1, execute: show)
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
		let popover = DetailPopover(contentView: contentView, arrowPosition: .bottom(offset: 20)) { _ in
			let insets = self.view.safeAreaInsets
			return CGPoint(x: 30 + insets.left, y: self.view.bounds.height - 33 - insets.bottom)
		}
		controller.callback = { [weak popover] values, temporary in
			assert(!temporary)
			guard let tab = self.tabStore.add(withSettings: values) else {
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

	private func showTabsView() {
		tabVC.stopInput()
		tabToolBar.isHidden = false
		tabCollectionView.isHidden = false
		tabToolBar.alpha = 0
		tabCollectionView.alpha = 0
		tabVC.tab?.controller?.saveTabState()
		if let tab = tabVC.tab {
			if let indexPath = scroll(to: tab, animated: false) {
				if let attributes = tabCollectionView.layoutAttributesForItem(at: indexPath) {
					let tabVC = self.tabVC
					UIView.animate(withDuration: animationDuration, animations: {
						var frame = attributes.frame
						frame.size.height -= TabCollectionViewCell.barHeight
						frame.origin.y += TabCollectionViewCell.barHeight
						frame.size.width -= tabControllerEdgeOffset * 2
						frame.origin.x += tabControllerEdgeOffset
						let convertedFrame = self.pageContentView.convert(frame, from: self.tabCollectionView)
						tabVC?.view.frame = convertedFrame
						tabVC?.view.layer.transform = attributes.transform3D
					})
				}
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
		let tab = tabStore.add()!
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
			lastTab = tabStore.add()
		}
		set(tab: lastTab!, animated: false)

		ReviewPrompt.tabCloseReset()

		let indexPath = IndexPath(item: tabs.firstIndex(of: lastTab!)!, section: 0)
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
		UIView.animate(withDuration: animationDuration / 3, animations: { () -> () in
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

	@objc private func endTextEntry(_ sender: UIKeyCommand) {
		textInputBar?.cancel()
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
		set(tab: tabStore.add()!, animated: true)
	}

	@objc private func closeTab(_ sender: UIKeyCommand) {
		guard let tab = tabVC?.tab else {
			return
		}
		close(tab)
	}

	@objc private func historyBack(_ sender: UIKeyCommand) {
		tabVC?.tab?.controller?.goBack()
	}

	@objc private func historyForward(_ sender: UIKeyCommand) {
		tabVC?.tab?.controller?.goForward()
	}

	@objc private func searchOnPage(_: UIKeyCommand) {
		if let tab = tabVC?.tab, tab.controller?.webViewLoaded ?? false, let _ = tab.controller?.url {
			startSearch(tab: tab, activity: nil)
		}
	}

	@objc private func reloadPage(_: UIKeyCommand) {
		tabVC?.tab?.controller?.reload()
	}

	@objc private func stopLoadingPage(_: UIKeyCommand) {
		tabVC?.tab?.controller?.stopLoading()
	}

	@objc private func previousTab(_: UIKeyCommand) {
		guard let tab = tabVC?.tab, let index = tabs.firstIndex(of: tab) else {
			return
		}
		let newIndex = (index + tabs.count - 1) % tabs.count
		let newTab = tabs[newIndex]
		set(tab: newTab, animated: true)
	}

	@objc private func nextTab(_: UIKeyCommand) {
		guard let tab = tabVC?.tab, let index = tabs.firstIndex(of: tab) else {
			return
		}
		let newIndex = (index + 1) % tabs.count
		let newTab = tabs[newIndex]
		set(tab: newTab, animated: true)
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

	override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
		if motion == .motionShake && isShowingTabsView {
			if let tab = tabStore.undoDeletion().last {
				scroll(to: tab)
			}
		}
		super.motionBegan(motion, with: event)
	}
}

// MARK: Tab History
private extension MainViewController {
	enum TabHistoryViewType {
		case forward
		case backward

		func list(from controller: TabController) -> [WKBackForwardListItem]? {
			switch self {
				case .forward:	return controller.forwardList
				case .backward:	return controller.backList?.reversed()
			}
		}

		var title: String {
			switch self {
				case .forward:	return NSLocalizedString("forward tab history title", comment: "title of popover to go forward in tab history")
				case .backward:	return NSLocalizedString("back tab history title", comment: "title of popover to go back in tab history")
			}
		}
	}

	@available (iOS 14, *)
	private func menuForTabHistory(ofType type: TabHistoryViewType) -> UIMenu? {
		guard let controller = tabVC.tab?.controller, let history = type.list(from: controller) else {
			return nil
		}
		var children = [UIMenuElement]()
		for item in history {
			let url = item.url.absoluteString
			let action = UIAction(title: item.title ?? url, image: nil, identifier: nil, discoverabilityTitle: url, attributes: [], state: .off) { [weak controller, weak item] _ in
				guard let controller = controller, let item = item else {
					return
				}
				controller.go(to: item)
			}
			children.append(action)
		}
		return UIMenu(title: type.title, image: nil, identifier: nil, options: [], children: children)
	}
}

// MARK: URL Bar Delegate
extension MainViewController: URLBarDelegate {
	func prevButtonTapped(for urlBar: URLBar) {
		tabVC.tab?.controller?.goBack()
	}

	func nextButtonTapped(for urlBar: URLBar) {
		tabVC.tab?.controller?.goForward()
	}

	@available (iOS 14, *)
	var forwardHistoryMenu: UIMenu? {
		return menuForTabHistory(ofType: .forward)
	}

	@available (iOS 14, *)
	var backHistoryMenu: UIMenu? {
		return menuForTabHistory(ofType: .backward)
	}

	func shareButtonPressed(for urlBar: URLBar, sender: NSObject) {
		let webView = tabVC.webViewForShareAction()
		var items = [AnyObject]()
		if let webView = webView {
			if let title = webView.title {
				items.append((title + " ") as AnyObject)
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
		if let tab = tabVC.tab {
			items.append(tab)
		}
		let scanActivity = ScanCodeActivity()
		scanActivity.source = sender
		scanActivity.delegate = self
		let readerActivity = StartReaderActivity() { [weak self] activity in
			guard let self = self, let tab = activity.tab, let url = tab.displayURL else {
				activity.activityDidFinish(false)
				return
			}
			let customization: (Tab) -> () = { newtab in
				let settings = Settings.settings(for: PolicyDomain(url: url), in: newtab)
				settings.set(.true, for: readerModeKey)
			}
			guard let newtab = self.tabStore.add(with: URLRequest(url: url), copySettingsFromParent: tab, customization: customization) else {
				activity.activityDidFinish(false)
				return
			}
			self.set(tab: newtab, animated: true)
			activity.activityDidFinish(true)
		}
		let searchActivity = FindOnPageActivity() { [weak self] activity in
			if let tab = activity.tab {
				self?.startSearch(tab: tab, activity: activity)
			}
		}
		var activities = [AddBookmarkActivity(), ShowDownloadsActivity(), readerActivity, searchActivity]
		if scanActivity.available {
			activities.append(scanActivity)
		}
		if let downloadData = tabVC?.tab?.controller?.downloadData {
			activities.append(DownloadActivity(data: downloadData))
		}
		let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
		controller.excludedActivityTypes = [UIActivity.ActivityType.addToReadingList]
		// TODO: remove once bug is patched
		// work arround a bug where iOS 11 tries to generate a file name from the title and fails if it is empty
		if let wv = webView, (wv.title ?? "").isEmpty {
			controller.excludedActivityTypes = (controller.excludedActivityTypes ?? []) + [UIActivity.ActivityType.markupAsPDF]
		}
		// TODO: find way to display activity controller in night mode
		controller.completionWithItemsHandler = { [weak self] _, _, _, _ in self?.updateNightMode() }
		if sender.isKind(of: UIBarButtonItem.self) {
			controller.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem
		} else if sender.isKind(of: UIView.self) {
			let view = sender as? UIView
			controller.popoverPresentationController?.sourceView = view?.superview;
			controller.popoverPresentationController?.sourceRect = view?.frame ?? .zero
		}
		dimmer.set(dimmed: false, animated: true) // TODO: find way to display activity controller in night mode
		present(controller, animated: true, completion: nil)
	}

	func plusButtonPressed(for urlBar: URLBar) {
		set(tab: tabStore.add()!, animated: true)
	}

	func tabsButtonPressed(for urlBar: URLBar) {
		showTabsView()
	}

	@available (iOS 14, *)
	var tabsActionsMenu: UIMenu? {
		let closeTitle = NSLocalizedString("close tab tab menu option title", comment: "title of option in the tab menu to close the current tab")
		let closeAllTitle = NSLocalizedString("close all tabs tab menu option title", comment: "title of option in the tab menu to close all tabs")
		let newTitle = NSLocalizedString("new tab tab menu option title", comment: "title of option in the tab menu to create a new tab")

		let close = UIAction(title: closeTitle, image: nil, identifier: nil, discoverabilityTitle: nil, attributes: .destructive, state: .off) { [weak self] _ in
			if let tab = self?.tabVC.tab {
				self?.close(tab)
			}
		}

		let closeAll = UIAction(title: closeAllTitle, image: nil, identifier: nil, discoverabilityTitle: nil, attributes: .destructive, state: .off) { [weak self] _ in
			self?.closeAllTabs()
		}

		let new = UIAction(title: newTitle, image: nil, identifier: nil, discoverabilityTitle: nil, attributes: [], state: .off) { [weak self] _ in
			guard let self = self, PolicyManager.globalManager().allowCloseAllTabs else {
				return
			}
			self.set(tab: self.tabStore.add()!, animated: true)
		}

		let allowCloseAll = tabs.count > 1 && PolicyManager.globalManager().allowCloseAllTabs

		let children = [close, allowCloseAll ? closeAll : nil, new]
		let title = NSLocalizedString("tab menu title", comment: "title of the tab actions menu")
		return UIMenu(title: title, image: nil, identifier: nil, options: [], children: children.compactMap { $0 })
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
		guard let tab = tabVC.tab, let url = tab.displayURL else {
			let contentView = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 100))
			contentView.text = NSLocalizedString("local page settings unavailable notice", comment: "is displayed when the user presses the page security icon without having loaded a page first")
			contentView.numberOfLines = 3
			contentView.textAlignment = .center
			contentView.textColor = .localSettingsTitle
			let popover = DetailPopover(contentView: contentView, arrowPosition: .top(offset: 20)) { _ in
				let buttonFrame = urlBar.securityButtonFrame(in: self.view)
				let x = buttonFrame.midX
				let y = buttonFrame.maxY - 2
				return CGPoint(x: x, y: y)
			}
			popover.show(in: view, animated: true)
			return
		}
		let pageInfo = PageInformationView(url: url, tab: tab)
		let popover = DetailPopover(contentView: pageInfo, arrowPosition: .top(offset: 20)) { _ in
			let buttonFrame = urlBar.securityButtonFrame(in: self.view)
			let x = buttonFrame.midX
			let y = buttonFrame.maxY - 2
			return CGPoint(x: x, y: y)
		}
		let domain = PolicyDomain(url: url)
		pageInfo.callback = { [weak popover] values, temporary in
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
		popover.show(in: view, animated: true)
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
	func tabViewController(_ controller: TabViewController, openTabForRequest request: URLRequest, inForeground: Bool) {
		guard let tab = tabStore.add(with: request, copySettingsFromParent: controller.tab!) else {
			return
		}
		if inForeground {
			set(tab: tab, animated: true)
		}
	}

	func showSuggestions(searchString: String) {
		guard let tab = tabVC.tab else {
			return
		}
		let policy = PolicyManager.manager(for: tab)
		suggestionVC.sources = policy.suggestionSources(for: tab)

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

	func showRenameBar(fallback: String?, prefill: String?, callback: @escaping (String?) -> ()) {
		let bar = BookmarkRenameBar()
		bar.callback = callback
		bar.textField.text = prefill
		if let fallback = fallback {
			let attributes = [NSAttributedString.Key.foregroundColor : UIColor.dimmedTitle]
			bar.textField.attributedPlaceholder = NSAttributedString(string: fallback, attributes: attributes)
		} else {
			bar.textField.attributedPlaceholder = nil
		}
		set(inputBar: bar)
	}

	func boundingViews() -> (top: UIView?, bottom: UIView?) {
		return (urlBar, navigationToolBarContainer)
	}

	func showDownloads() {
		if !(tabVC?.tab?.controller?.unused ?? false) {
			set(tab: tabStore.add(loadHomepage: false)!, animated: true)
			tabVC.showHistory(animated: false)
		} else {
			tabVC.showHistory(animated: true)
		}
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
		coordinator.animate(alongsideTransition: nil) { _ in
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
			urlBar.selectedTab = tabs.firstIndex(of: tab) ?? -1
		}
		DispatchQueue.main.async { [weak self] in
			self?.urlBar.reloadTabActions()
		}
	}

	@objc private func tabDidChange(_ notification: Notification) {
		urlBar.tabTitleURLs = tabTitleURLs(masked: false)
	}

	@objc private func keyboardFrameDidChange(_ notification: Notification) {
		guard let info = notification.userInfo else {
			return
		}
		let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber ?? NSNumber(value: 0.3 as Double)
		let curveValue = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber ?? NSNumber(value: 0 as Int32)
		let curve = UIView.AnimationOptions(rawValue: curveValue.uintValue)
		let endValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
		let endRect = endValue?.cgRectValue ?? .zero
		let viewRect = view.convert(endRect, from: view.window)
		windowMargin = viewRect.size.height
		var searchBarY: CGFloat
		let searchBarHeight = textInputBar?.bounds.height ?? 0
		if viewRect.maxY < view.bounds.maxY - 100 {
			searchBarY = view.bounds.maxY - searchBarHeight
		} else {
			searchBarY = viewRect.minY - searchBarHeight
		}
		searchBarY = min(view.bounds.maxY - searchBarHeight - view.safeAreaInsets.bottom, searchBarY)
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
		for tab in tabs {
			Stats.shared.updateCookieCount(for: tab)
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
		UIView.animate(withDuration: animationDuration, animations: {
			bar.frame.origin.y = self.view.bounds.maxY - bar.frame.height - self.view.safeAreaInsets.bottom
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
			UIView.animate(withDuration: 0.12, delay: 0, options: UIView.AnimationOptions(rawValue: UInt(UIView.AnimationCurve.easeOut.rawValue)), animations: {
				textInputBar.frame.origin.y = self.view.bounds.maxY + 10
			}, completion: { (_) -> () in
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
