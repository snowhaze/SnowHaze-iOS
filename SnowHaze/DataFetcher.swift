//
//  DataFetcher.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class DataFetcher: NSObject, URLSessionDelegate {
	private lazy var session = setupSession()
	private let tab: Tab

	init(tab: Tab) {
		self.tab = tab
		super.init()
	}

	private func upgrade(_ url: URL) -> URL {
		guard let domain = url.host , url.scheme!.lowercased() == "http" else {
			return url
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		guard policy.useHTTPSExclusivelyWhenPossible && DomainList(type: .httpsSites).contains(domain) else {
			return url
		}
		var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		components.scheme = "https"
		return components.url!
	}

	func fetch(_ originalUrl: URL, callback: @escaping (Data?) -> Void) {
		let dec = InUseCounter.network.inc()
		let url = upgrade(originalUrl)
		let task = session.dataTask(with: url, completionHandler: { (data, _, error) -> Void in
			dec()
			guard error == nil else {
				callback(nil)
				return
			}
			callback(data)
		})
		task.resume()
	}

	private func setupSession() -> URLSession {
		let tabPolicy = PolicyManager.manager(for: tab)
		let config = tabPolicy.urlSessionConfiguration
		config.httpAdditionalHeaders = ["User-Agent": tab.controller?.userAgent ?? tabPolicy.userAgent]
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}

	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
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
