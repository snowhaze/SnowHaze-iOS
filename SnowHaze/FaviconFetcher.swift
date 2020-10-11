//
//	FaviconFetcher.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class FaviconFetcher: DataFetcher {
	private let manager: WebViewManager
	private let jsgenerator = JSGenerator.named("FaviconFetcher")!

	init(manager: WebViewManager) {
		self.manager = manager
		super.init(tab: manager.tab)
	}

	/**
	 *	Downloads the favicon for the website currently loaded in webView
	 *	- parameter callback: is called on main queue with the image data
	 */
	func fetch(_ callback: @escaping (Data?) -> ()) {
		let script = jsgenerator.generate()!
		manager.evaluate(script) { result, error in
			guard let path = result as? String,  let url = URL(string: path) else {
				return
			}
			self.fetch(url, callback: callback)
		}
	}
}
