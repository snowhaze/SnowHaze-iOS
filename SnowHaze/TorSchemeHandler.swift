//
//  TorSchemeHandler.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

private let allowedParamCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ:/?._-#%=")

private func error(for url: URL?, code: Int, subscription: Bool = true) -> NSError {
	var info = [String: Any]()
	if !subscription {
		info[NSLocalizedDescriptionKey] = NSLocalizedString("tor missing subscription error message", comment: "error message to indicate that the user should purchase a subscription to use tor")
	}
	if let url = url {
		info[NSURLErrorFailingURLErrorKey] = url
	}
	return NSError(domain: "TorErrorDomain", code: code, userInfo: info)
}

protocol TorSchemeHandlerDelegate: class {
	func torSchemeHandler(_ handler: TorSchemeHandler, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ())
}

class TorSchemeHandler: NSObject, WKURLSchemeHandler, URLSessionDataDelegate {
	private var session: URLSession?

	let sendDNT: Bool
	let blockDeprecatedTLS: Bool

	let user = String.secureRandom()
	let password = String.secureRandom()

	weak var delegate: TorSchemeHandlerDelegate?

	init(dnt: Bool, blockDeprecatedTLS: Bool) {
		sendDNT = dnt
		self.blockDeprecatedTLS = blockDeprecatedTLS
		super.init()
	}

	private var map = [URLSessionDataTask: WKURLSchemeTask]()
	private var waiting = [WKURLSchemeTask]()

	private func setupSession(callback: @escaping (URLSession?, Bool) -> ()) {
		guard session == nil  else {
			return callback(session, true)
		}
		TorServer.shared.start { [weak self] error in
			guard error == nil else {
				if case .noSubscription = error {
					return callback(nil, false)
				} else {
					return callback(nil, true)
				}
			}
			guard self?.session == nil  else {
				return callback(self?.session, true)
			}
			TorServer.shared.getURLSessionProxyConfig { proxyConfig in
				guard var proxyConfig = proxyConfig else {
					return callback(nil, true)
				}
				guard let me = self, me.session == nil else {
					return callback(self?.session, true)
				}
				proxyConfig[kCFStreamPropertySOCKSUser] = me.user
				proxyConfig[kCFStreamPropertySOCKSPassword] = me.password
				let config: URLSessionConfiguration = .ephemeral
				config.connectionProxyDictionary = proxyConfig

				if me.blockDeprecatedTLS {
					if #available(iOS 13, *) {
						config.tlsMinimumSupportedProtocolVersion = .TLSv12
					} else {
						config.tlsMinimumSupportedProtocol = .tlsProtocol12
					}
				}

				me.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
				callback(me.session, true)
			}
		}
	}

	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		assert(Thread.isMainThread)
		waiting.append(urlSchemeTask)
		setupSession { [weak self] session, hasSubscription in
			DispatchQueue.main.async {
				var request = urlSchemeTask.request
				guard hasSubscription else {
					urlSchemeTask.didFailWithError(error(for: request.url, code: -1, subscription: false))
					return
				}
				guard let session = session, let originalURL = request.url else {
					urlSchemeTask.didFailWithError(error(for: request.url, code: -2))
					return
				}
				guard originalURL.isTorURL, let detorifiedURL = originalURL.detorified else {
					urlSchemeTask.didFailWithError(error(for: originalURL, code: -3))
					return
				}
				guard let self = self, self.waiting.contains(where: { $0 === urlSchemeTask }) else {
					return
				}
				self.waiting = self.waiting.filter { $0 !== urlSchemeTask }
				request.url = detorifiedURL
				if self.sendDNT {
					request.setValue("1", forHTTPHeaderField: "DNT")
				}
				let task = session.dataTask(with: request)
				self.map[task] = urlSchemeTask
				task.resume()
			}
		}
	}

	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		assert(Thread.isMainThread)
		var task: URLSessionDataTask? = nil
		for (key, value) in map {
			if value === urlSchemeTask {
				task = key
				break
			}
		}
		if let task = task {
			map[task] = nil
			task.cancel()
		} else {
			waiting = waiting.filter { $0 !== urlSchemeTask }
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				return
			}
			guard let dataTask = task as? URLSessionDataTask, let schemeTask = self.map[dataTask] else {
				task.cancel()
				return
			}
			self.map[dataTask] = nil
			if let error = error {
				schemeTask.didFailWithError(error)
			} else {
				schemeTask.didFinish()
			}
		}
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> ()) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				return
			}
			guard let schemeTask = self.map[dataTask] else {
				dataTask.cancel()
				return completionHandler(.cancel)
			}
			if let headers = (response as? HTTPURLResponse)?.allHeaderFields as? [String: String] {
				if let url = dataTask.originalRequest?.url?.detorified, var location = headers["Location"] {
					self.map[dataTask] = nil
					location = URL(string: location)?.torified?.absoluteString ?? location
					func escape(_ string: String) -> String {
						return Array(string.unicodeScalars).map({ scalar -> String in
							if allowedParamCharacters.contains(scalar) {
								return String(scalar)
							}
							return "&#\(scalar.value);"
						}).reduce("") { $0 + $1 }
					}
					var html = "<html><head><meta charset='UTF-8'>"
					html += "<meta http-equiv='refresh' content='0;url=\(escape(location))'>"
					if let cookie = headers["Set-Cookie"] {
						html += "<meta http-equiv='set-cookie' content='\(escape(cookie))'>"
					}
					html += "</head><body></body></html>"
					let data = html.data(using: .utf8)!
					let response = URLResponse(url: url, mimeType: "text/html", expectedContentLength: data.count, textEncodingName: "UTF-8")
					schemeTask.didReceive(response)
					schemeTask.didReceive(data)
					schemeTask.didFinish()
					completionHandler(.cancel)
					return
				}
			}
			schemeTask.didReceive(response)
			completionHandler(.allow)
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> ()) {
		completionHandler(nil)
	}

	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				return
			}
			guard let schemeTask = self.map[dataTask] else {
				dataTask.cancel()
				return
			}
			schemeTask.didReceive(data)
		}
	}

	func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> ()) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else {
				completionHandler(.cancelAuthenticationChallenge, nil)
				return
			}
			guard let delegate = self.delegate else {
				completionHandler(.performDefaultHandling, nil)
				return
			}
			delegate.torSchemeHandler(self, didReceive: challenge, completionHandler: completionHandler)
		}
	}

	func cleanup() {
		self.session = nil
	}
}
