//
//	PagePreviewController.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let errorHtmlFormat = "<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1, user-scalable=0'><style>@font-face { font-family: snowhaze-font; src: url('data:font/otf;base64,%@') format('opentype');}body { color: #FFFFFF; background-color: #312B35; font-size: 1.8em; text-align: center; font-family: 'snowhaze-font'; margin: 0; position: absolute; display: table; height: 100%%; width: 100%%;}div {display: table-cell; vertical-align: middle;}div svg { height: 5em; position: relative; vertical-align: bottom; margin-right: 0.2em;}</style>%@</head><body><div><svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 50 50' enable-background='new 0 0 50 50' fill='#f7a730'><path d='M 25 3 C 12.86158 3 3 12.86158 3 25 C 3 37.13842 12.86158 47 25 47 C 37.13842 47 47 37.13842 47 25 C 47 12.86158 37.13842 3 25 3 z M 25 5 C 36.05754 5 45 13.94246 45 25 C 45 36.05754 36.05754 45 25 45 C 13.94246 45 5 36.05754 5 25 C 5 13.94246 13.94246 5 25 5 z M 23.8125 14.3125 C 23.5125 14.3125 23.40625 14.4875 23.40625 14.6875 L 23.40625 28.1875 C 23.40625 28.4875 23.6125 28.59375 23.8125 28.59375 L 26.09375 28.59375 C 26.39375 28.59375 26.5 28.3875 26.5 28.1875 L 26.5 14.6875 C 26.5 14.3875 26.29375 14.3125 26.09375 14.3125 L 23.8125 14.3125 z M 23.8125 32.3125 C 23.5125 32.3125 23.40625 32.4875 23.40625 32.6875 L 23.40625 35.3125 C 23.40625 35.6125 23.6125 35.6875 23.8125 35.6875 L 26.1875 35.6875 C 26.4875 35.6875 26.59375 35.5125 26.59375 35.3125 L 26.59375 32.6875 C 26.59375 32.3875 26.3875 32.3125 26.1875 32.3125 L 23.8125 32.3125 z' fill='#f7a730'/></svg><br/><br/>%@</div></body></html>"

class PagePreviewController: UIViewController, WorkerWebViewManagerDelegate {
	let manager: WorkerWebViewManager
	let loadBar = LoadBar()

	private var _previewActionItems = [UIPreviewActionItem]()

	override var previewActionItems: [UIPreviewActionItem] {
		get {
			return _previewActionItems
		}
		set {
			_previewActionItems = newValue
		}
	}

	private let loadBarHeight: CGFloat = 2.5

	override var prefersStatusBarHidden: Bool {
		return true
	}

	private func setup() {
		let webView = manager.webView
		manager.delegate = self
		webView.frame = view.bounds
		webView.scrollView.backgroundColor = .background
		view.addSubview(webView)
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]


		loadBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: loadBarHeight)
		loadBar.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
		view.addSubview(loadBar)
	}

	init(input: String, tab: Tab) {
		manager = WorkerWebViewManager(tab: tab)
		super.init(nibName: nil, bundle: nil)
		manager.load(userInput: input)
		setup()
	}

	init(url: URL, tab: Tab) {
		manager = WorkerWebViewManager(tab: tab)
		super.init(nibName: nil, bundle: nil)
		manager.load(url: url)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func webViewManagerDidFailLoad(_ manager: WorkerWebViewManager) {
		let title = NSLocalizedString("failed to load page preview error page title html", comment: "html of the title of the error page displayed if a page preview could not be loaded")
		let content = NSLocalizedString("failed to load page preview error page content html", comment: "html of the content of the error page displayed if a page preview could not be loaded")
		let font = try! Data(contentsOf: Bundle.main.url(forResource: SnowHazeFontName, withExtension: "otf")!).base64EncodedString()
		let html = String(format: errorHtmlFormat, font, title, content)
		manager.webView.loadHTMLString(html, baseURL: nil)
	}

	func webViewManagerDidFinishLoad(_ manager: WorkerWebViewManager) { }

	func webViewManager(_ manager: WorkerWebViewManager, didMakeProgress progress: Double) {
		if progress > 0 && progress < 1 {
			loadBar.progress = CGFloat(progress)
		} else {
			loadBar.progress = 0
		}
		loadBar.setNeedsDisplay()
	}

	func webViewManaget(_ manager: WorkerWebViewManager, didUpgradeLoadOf url: URL) {
		Stats.shared.upgradedLoad(of: url, in: manager.tab)
	}

	func webViewManaget(_ manager: WorkerWebViewManager, isLoading url: URL?) {
		Stats.shared.loading(url, in: manager.tab)
	}

	@available(iOS 11.0, *)
	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		loadBar.frame = CGRect(x: 0, y: view.safeAreaInsets.top, width: view.bounds.width, height: loadBarHeight)
	}
}
