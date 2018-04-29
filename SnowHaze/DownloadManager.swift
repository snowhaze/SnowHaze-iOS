//
//  DownloadManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let domainsDBLocation = "https://api.snowhaze.com/lists.db"
private let subscriptionDomainsDBLocation = "https://api.snowhaze.com/index.php"

class DownloadManager: PinningSessionDelegate {
	static let shared = DownloadManager()

	private lazy var mainSession: URLSession = {
		URLSession(configuration: self.sessionConfig(background: false), delegate: self, delegateQueue: nil)
	}()

	private lazy var backgroundSession: URLSession = {
		URLSession(configuration: self.sessionConfig(), delegate: self, delegateQueue: nil)
	}()

	private lazy var backgroundWifiSession: URLSession = {
		URLSession(configuration: self.sessionConfig(allowCellular: false), delegate: self, delegateQueue: nil)
	}()

	func sessionConfig(allowCellular: Bool = true, background: Bool = true) -> URLSessionConfiguration {
		var config: URLSessionConfiguration
		if background {
			config = URLSessionConfiguration.background(withIdentifier: "ch.illotros.snowhaze.backgrounddownload" + (allowCellular ? "" : ".wifi"))
		} else {
			config = URLSessionConfiguration()
		}

		config.allowsCellularAccess = allowCellular

		config.tlsMinimumSupportedProtocol = .tlsProtocol12

		config.httpCookieAcceptPolicy = .never
		config.httpCookieStorage = nil
		config.httpShouldSetCookies = false

		config.urlCache = nil
		config.requestCachePolicy = .reloadIgnoringLocalCacheData

		config.isDiscretionary = !allowCellular

		return config
	}

	private var timer: Timer?
	private var pendingCompletionHandler: (() -> Void)?

	var listUpdateDec: (() -> Void)?

	override private init() {
		super.init()
	}

	func stopSiteListsUpdate() {
		backgroundSession.getAllTasks { tasks in
			tasks.forEach { $0.cancel() }
		}
		backgroundWifiSession.getAllTasks { tasks in
			tasks.forEach { $0.cancel() }
		}
	}

	func triggerSiteListsUpdate() {
		let policy = PolicyManager.globalManager()
		guard listUpdateDec == nil && policy.updateSiteLists else {
			return
		}
		listUpdateDec = InUseCounter.network.inc()
		let session = appropriateListUpdateBackgroundSession(for: policy)
		var request: URLRequest
		let manager = SubscriptionManager.shared
		if manager.hasSubscription, manager.hasValidToken, let token = manager.authorizationToken {
			request = URLRequest(url: URL(string: subscriptionDomainsDBLocation)!)
			request.setFormEncoded(data: ["t": token, "v": "2", "action": "list"])
		} else {
			request = URLRequest(url: URL(string: domainsDBLocation)!)
		}
		let task = session.downloadTask(with: request)
		task.resume()
	}

	func triggerProductListUpdate() {
		guard PolicyManager.globalManager().updateProductList else {
			return
		}
		updateProductList()
	}

	func triggerAuthTokenUpdate() {
		guard PolicyManager.globalManager().autoUpdateAuthToken else {
			return
		}
		updateAuthToken()
	}

	func triggerVPNListUpdate() {
		guard PolicyManager.globalManager().autoUpdateVPNList else {
			return
		}
		updateVPNList()
	}

	func updateProductList(force: Bool = false, completionHandler: ((Bool) -> Void)? = nil) {
		let dec = InUseCounter.network.inc()
		SubscriptionManager.shared.updateProducts(force: force) { success in
			DispatchQueue.main.async {
				dec()
				completionHandler?(success)
			}
		}
	}

	func updateAuthToken(completionHandler: ((Bool) -> Void)? = nil) {
		SubscriptionManager.shared.updateAuthToken(completionHandler: completionHandler)
	}

	func updateVPNList(completionHandler: ((Bool) -> Void)? = nil) {
		VPNManager.shared.updateProfileList(withCompletionHandler: completionHandler)
	}

	func start() {
		timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(timerFired(_:)), userInfo: nil, repeats: true)
		trigger()
	}

	func trigger() {
		triggerSiteListsUpdate()
		triggerProductListUpdate()
		triggerAuthTokenUpdate()
		triggerVPNListUpdate()
	}

	@objc private func timerFired(_ timer: Timer) {
		trigger()
	}
}

extension DownloadManager: URLSessionDownloadDelegate {
	func handleBackgroundTaskEvent(completionHandler: @escaping () -> Void) {
		assert(pendingCompletionHandler == nil)
		pendingCompletionHandler = completionHandler
		_ = backgroundSession
		_ = backgroundWifiSession
	}

	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		DispatchQueue.main.async {
			let handler = self.pendingCompletionHandler
			self.pendingCompletionHandler = nil
			handler?()
		}
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		let url = downloadTask.currentRequest?.url?.absoluteString
		if url == domainsDBLocation || url == subscriptionDomainsDBLocation {
			guard let db = SQLCipher(url: location, key: DomainList.dbKey, flags: .readonly) else {
				return
			}
			guard let integrityCheck = try? db.execute("PRAGMA quick_check") else {
				print("DB corrupted")
				return
			}
			guard integrityCheck.count == 1, integrityCheck[0].text == "ok" else {
				print("DB corrupted")
				return
			}
			guard (try? db.execute("PRAGMA foreign_key_check").isEmpty) ?? false else {
				print("DB corrupted")
				return
			}
			for table in ["tracking", "ad", "https", "private", "popular", "blogspot", "danger"] {
				guard let _ = try? db.execute("SELECT domain FROM \(table.sqliteEscapedIdentifier) LIMIT 0") else {
					print("table \(table) does not have a domain column or does not exist")
					return
				}
			}
			guard let _ = try? db.execute("SELECT rank FROM popular LIMIT 0") else {
				print("table popular does not have a rank column")
				return
			}
			guard let _ = try? db.execute("SELECT type FROM danger LIMIT 0") else {
				print("table danger does not have a type column")
				return
			}
			guard let _ = try? db.execute("SELECT hash, type FROM danger_hash LIMIT 0") else {
				print("table danger_hash is missing a hash or type column or does not exist")
				return
			}
			guard let _ = try? db.execute("SELECT id, version, source FROM content_blocker LIMIT 0") else {
				print("table content_blocker is missing a column or does not exist")
				return
			}
			guard let _ = try? db.execute("SELECT host, name, value FROM parameter_stripping LIMIT 0") else {
				print("table parameter_stripping is missing a column or does not exist")
				return
			}

			let blockerIds = BlockerID.allIDs.map { SQLite.Data.text($0) }
			let values = [String](repeating: "(?)", count: blockerIds.count).joined(separator: ", ")
			let blockerQuery = "SELECT count(*) FROM content_blocker WHERE id IN (VALUES \(values)) AND json_valid(source) AND json_type(source) = 'array'"
			guard let blockerCount = try? db.execute(blockerQuery, with: blockerIds), blockerCount[0].integer == Int64(blockerIds.count) else {
				print("table content_blocker has invalid source or is missing a row")
				return
			}

			let headers = (downloadTask.response as? HTTPURLResponse)?.allHeaderFields
			let date = read(httpDate: headers?["Last-Modified"] as? String ?? "") ?? Date()
			syncToMainThread {
				installSitesDB(from: location, modified: date)
			}
		} else {
			print("weird download success location")
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		let url = task.currentRequest?.url?.absoluteString
		if url == domainsDBLocation || url == subscriptionDomainsDBLocation {
			syncToMainThread {
				if let dec = listUpdateDec {
					dec()
					listUpdateDec = nil
				}
			}
		} else {
			print("weird fail location")
		}
	}
}

/// Helpers
private extension DownloadManager {
	private func syncToMainThread<T>(_ work: () -> T) -> T {
		return Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
	}

	func installSitesDB(from location: URL, modified: Date) {
		assert(Thread.isMainThread)
		// If DB isn't available, assume updates are enabled. File will be cleared on unlock otherwise.
		guard !PolicyManager.dataAvailable || PolicyManager.globalManager().updateSiteLists else {
			return
		}
		let fm = FileManager.default
		try! fm.replaceItem(at: URL(fileURLWithPath: DomainList.dbLocation), withItemAt: location, backupItemName: nil, options: [], resultingItemURL: nil)
		try? fm.setAttributes([.creationDate: modified], ofItemAtPath: DomainList.dbLocation)
		NotificationCenter.default.post(name: DomainList.dbFileChangedNotification, object: nil)
	}

	func appropriateListUpdateBackgroundSession(for policy: PolicyManager) -> URLSession {
		if policy.useCellularForSiteListsUpdate {
			return backgroundSession
		} else {
			return backgroundWifiSession
		}
	}

	func read(httpDate dateString: String) -> Date? {
		struct Local {
			static let rfc1123: DateFormatter = {
				var formater = DateFormatter()
				formater.locale = Locale(identifier: "en_US")
				formater.dateFormat = "E, dd MMM yyyy HH:mm:ss zzz"
				return formater
			}()

			static let rfc850: DateFormatter = {
				var formater = DateFormatter()
				formater.locale = Locale(identifier: "en_US")
				formater.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
				return formater
			}()

			static let asctime: DateFormatter = {
				var formater = DateFormatter()
				formater.locale = Locale(identifier: "en_US")
				formater.dateFormat = "E MM d HH:mm:ss yyyy"
				return formater
			}()
		}
		return Local.rfc1123.date(from: dateString) ?? Local.rfc850.date(from: dateString) ?? Local.asctime.date(from: dateString)
	}
}
