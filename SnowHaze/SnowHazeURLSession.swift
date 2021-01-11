//
//  SnowHazeURLSession.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

public class SnowHazeURLSession {
	private let delegate: URLSessionDelegate
	private let config: URLSessionConfiguration
	private let torConfig: URLSessionConfiguration?

	public enum Error: Swift.Error {
		case torSetupError
	}

	private lazy var nonTorSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
	private var torSession: URLSession?
	private var torSessionCallbacks = [(URLSession?) -> ()]()

	private var user = String.secureRandom()
	private var password = String.secureRandom()

	public func rotateTorCredentials() {
		syncToMainThread {
			guard let config = torSession?.configuration else {
				return
			}
			user = String.secureRandom()
			password = String.secureRandom()
			config.connectionProxyDictionary?[kCFStreamPropertySOCKSUser] = user
			config.connectionProxyDictionary?[kCFStreamPropertySOCKSPassword] = password
			torSession = URLSession(configuration: config)
		}
	}

	private func completeSessionLoad(with session: URLSession?) {
		syncToMainThread {
			let oldCallbacks = torSessionCallbacks
			torSessionCallbacks = []
			for callback in oldCallbacks {
				callback(session)
			}
		}
	}

	private func withTorSession(callback: @escaping (URLSession?) -> ()) {
		syncToMainThread {
			if let session = torSession {
				callback(session)
			} else {
				torSessionCallbacks.append(callback)
				if torSessionCallbacks.count == 1 {
					TorServer.shared.start { error in
						guard error == nil else {
							return self.completeSessionLoad(with: nil)
						}
						TorServer.shared.getURLSessionProxyConfig { proxyConfig in
							guard var proxyConfig = proxyConfig else {
								return self.completeSessionLoad(with: nil)
							}
							syncToMainThread {
								proxyConfig[kCFStreamPropertySOCKSUser] = self.user
								proxyConfig[kCFStreamPropertySOCKSPassword] = self.password
							}
							let config = self.torConfig ?? self.config
							config.connectionProxyDictionary = proxyConfig
							self.torSession = URLSession(configuration: config, delegate: self.delegate, delegateQueue: nil)
							return self.completeSessionLoad(with: self.torSession)
						}
					}
				}
			}
		}
	}

	private func withProperSession(callback: @escaping (URLSession?) -> ()) {
		if PolicyManager.globalManager().useTorForAPICalls {
			withTorSession(callback: callback)
		} else {
			callback(nonTorSession)
		}
	}

	public init(configuration: URLSessionConfiguration = .ephemeral, torConfig: URLSessionConfiguration? = nil, delegate: URLSessionDelegate = PinningSessionDelegate()) {
		// identifiers must be unique, background and regular sessions schould not be mixed
		assert((configuration.identifier == nil) == (torConfig?.identifier == nil))
		assert((configuration.identifier == nil) || (torConfig?.identifier != configuration.identifier))

		configuration.httpAdditionalHeaders = configuration.httpAdditionalHeaders ?? [:]
		configuration.httpAdditionalHeaders!["User-Agent"] = "SnowHaze/1"

		torConfig?.httpAdditionalHeaders = torConfig?.httpAdditionalHeaders ?? [:]
		torConfig?.httpAdditionalHeaders!["User-Agent"] = "SnowHaze/1"

		if #available(iOS 13, *) {
			configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
			torConfig?.tlsMinimumSupportedProtocolVersion = .TLSv13
		} else {
			configuration.tlsMinimumSupportedProtocol = .tlsProtocol13
			torConfig?.tlsMinimumSupportedProtocol = .tlsProtocol13
		}

		self.delegate = delegate
		self.torConfig = torConfig
		config = configuration
	}

	public func performDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Swift.Error?) -> ()) {
		withProperSession { session in
			guard let session = session else {
				completionHandler(nil, nil, Error.torSetupError)
				return
			}
			session.dataTask(with: request, completionHandler: completionHandler).resume()
		}
	}

	public func performDataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Swift.Error?) -> ()) {
		performDataTask(with: URLRequest(url: url), completionHandler: completionHandler)
	}

	public func performDownloadTask(with request: URLRequest, torFailure: @escaping () -> ()) {
		withProperSession { session in
			guard let session = session else {
				return torFailure()
			}
			session.downloadTask(with: request).resume()
		}
	}

	public func cancelAllTasks() {
		syncToMainThread {
			withTorSession { session in
				session?.getAllTasks { tasks in
					tasks.forEach { $0.cancel() }
				}
			}
			nonTorSession.getAllTasks { tasks in
				tasks.forEach { $0.cancel() }
			}
		}
	}

	public func cancelAndInvalidate() {
		syncToMainThread {
			withTorSession { session in
				session?.invalidateAndCancel()
			}
			nonTorSession.invalidateAndCancel()
		}
	}

	public func loadSessions(includingTor: Bool, failure: @escaping () -> ()) {
		_ = nonTorSession
		if includingTor {
			withTorSession { session in
				if session == nil {
					failure()
				}
			}
		}
	}
}
