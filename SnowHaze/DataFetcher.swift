//
//  DataFetcher.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class DataFetcher: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
	private lazy var session = setupSession()
	private weak var tab: Tab!
	private let cookies: [HTTPCookie]

	init(tab: Tab, cookies: [HTTPCookie] = []) {
		self.tab = tab
		self.cookies = cookies
		super.init()
	}

	var usable: Bool {
		precondition(Thread.isMainThread)
		return !(tab?.deleted ?? true)
	}

	private func upgrade(_ url: URL) -> URL {
		guard let domain = url.host , url.normalizedScheme! == "http" else {
			return url
		}
		let policy = PolicyManager.manager(for: url, in: tab)
		let httpsSites = DomainList(type: policy.useHTTPSExclusivelyWhenPossible ? .httpsSites: .empty)
		guard httpsSites.contains(domain) || policy.trustedSiteUpdateRequired else {
			return url
		}
		var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
		components.scheme = "https"
		return components.url!
	}

	func fetch(_ originalUrl: URL, callback: @escaping (Data?) -> ()) {
		guard let session = session else {
			callback(nil)
			return
		}
		let dec = InUseCounter.network.inc()
		let url = upgrade(originalUrl.detorified ?? originalUrl)
		let task = session.dataTask(with: url, completionHandler: { [weak self] (data, _, error) -> () in
			dec()
			guard error == nil else {
				callback(nil)
				return
			}
			callback(data)
			self?.cancel()
		})
		task.resume()
	}

	enum DownloadEvent {
		case progressUnknown
		case progress(Int64, Int64)
		case complete(url: URL, file: String?, mime: String?)
		case error(Error)
	}
	enum DownloadError: Error {
		case sessionInitializationError
		case missingURL
		case contextReleased
	}
	private var downloadCallbacks = [URLSessionDownloadTask: (DownloadEvent) -> ()]()
	func download(_ request: URLRequest, callback: @escaping (DownloadEvent) -> ()) {
		assert(Thread.isMainThread)
		guard usable else {
			callback(.error(DownloadError.contextReleased))
			return
		}
		var request = request
		guard let url = request.url else {
			callback(.error(DownloadError.missingURL))
			return
		}
		request.url = upgrade(url)
		guard let session = session else {
			callback(.error(DownloadError.sessionInitializationError))
			return
		}
		let task = session.downloadTask(with: request)
		let dec = InUseCounter.network.inc()
		downloadCallbacks[task] = { event in
			switch event {
				case .error, .complete:	dec()
				default:				break
			}
			callback(event)
		}
		callback(.progressUnknown)
		task.resume()
	}

	private func setupSession() -> URLSession? {
		guard let controller = tab.controller else {
			return nil
		}
		let tabPolicy = PolicyManager.manager(for: tab)
		guard let config = tabPolicy.urlSessionConfiguration(tabController: controller) else {
			return nil
		}
		cookies.forEach { config.httpCookieStorage?.setCookie($0) }
		return URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}

	func cancel() {
		session?.invalidateAndCancel()
	}

	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		let space = challenge.protectionSpace
		guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
			completionHandler(.performDefaultHandling, nil)
			return
		}
		guard let controller = tab.controller else {
			completionHandler(.cancelAuthenticationChallenge, nil)
			return
		}
		controller.accept(space.serverTrust!, for: space.host) { result in
			if result {
				completionHandler(.useCredential, URLCredential(trust: space.serverTrust!))
			} else {
				completionHandler(.cancelAuthenticationChallenge, nil)
			}
		}
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		syncToMainThread {
			let callback = downloadCallbacks[downloadTask]!
			downloadCallbacks[downloadTask] = nil
			let fileName = downloadTask.response?.suggestedFilename
			let mime = downloadTask.response?.mimeType
			callback(.complete(url: location, file: fileName, mime: mime))
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error, let downloadTask = task as? URLSessionDownloadTask {
			syncToMainThread {
				let callback = downloadCallbacks[downloadTask]!
				downloadCallbacks[downloadTask] = nil
				callback(.error(error))
			}
		}
		cancel()
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		syncToMainThread {
			let callback = downloadCallbacks[downloadTask]!
			if totalBytesWritten > totalBytesExpectedToWrite {
				callback(.progressUnknown)
			} else {
				callback(.progress(totalBytesWritten, totalBytesExpectedToWrite))
			}
		}
	}
}
