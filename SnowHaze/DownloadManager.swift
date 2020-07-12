//
//  DownloadManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let domainsDBLocation = "https://api.snowhaze.com/lists.db"
private let subscriptionDomainsDBLocation = "https://api.snowhaze.com/index.php"

class DownloadManager: PinningSessionDelegate {
	static let shared = DownloadManager()

	private lazy var backgroundSession: SnowHazeURLSession = {
		SnowHazeURLSession(configuration: self.sessionConfig(), torConfig: self.sessionConfig(tor: true), delegate: self)
	}()

	private lazy var backgroundWifiSession: SnowHazeURLSession = {
		SnowHazeURLSession(configuration: self.sessionConfig(allowCellular: false), torConfig: self.sessionConfig(allowCellular: false, tor: true), delegate: self)
	}()

	private func sessionConfig(allowCellular: Bool = true, tor: Bool = false) -> URLSessionConfiguration {
		var config: URLSessionConfiguration
		config = URLSessionConfiguration.background(withIdentifier: "ch.illotros.snowhaze.backgrounddownload" + (allowCellular ? "" : ".wifi") + (tor ? "" : ".tor"))

		config.allowsCellularAccess = allowCellular

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
		backgroundSession.cancelAllTasks()
		backgroundWifiSession.cancelAllTasks()
	}

	func triggerSiteListsUpdate() {
		let policy = PolicyManager.globalManager()
		guard listUpdateDec == nil && policy.updateSiteLists else {
			return
		}
		listUpdateDec = InUseCounter.network.inc()
		let session = appropriateListUpdateBackgroundSession(for: policy)
		let manager = SubscriptionManager.shared
		manager.tryWithTokens { token, _ in
			let policy = PolicyManager.globalManager()
			if policy.rotateCircuitForNewTokens {
				session.rotateTorCredentials()
			}
			var request: URLRequest
			if let token = token {
				request = URLRequest(url: URL(string: subscriptionDomainsDBLocation)!)
				request.setFormEncoded(data: ["t": token, "v": "3", "action": "list"])
			} else if !manager.hasValidToken {
				request = URLRequest(url: URL(string: domainsDBLocation)!)
			} else {
				self.listUpdateDec?()
				self.listUpdateDec = nil
				return
			}
			session.performDownloadTask(with: request) {
				self.listUpdateDec?()
				self.listUpdateDec = nil
			}
		}
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
	func performPendingCompletionHandler() {
		DispatchQueue.main.async {
			let handler = self.pendingCompletionHandler
			self.pendingCompletionHandler = nil
			handler?()
		}
	}

	func handleBackgroundTaskEvent(completionHandler: @escaping () -> Void) {
		assert(pendingCompletionHandler == nil)
		pendingCompletionHandler = completionHandler
		backgroundSession.loadSessions(failure: self.performPendingCompletionHandler)
		backgroundWifiSession.loadSessions(failure: self.performPendingCompletionHandler)
	}

	func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
		performPendingCompletionHandler()
	}

	private func authorizer(action: SQLite.AuthorizerAction, db: String?, cause: String?) -> SQLite.AuthorizerResponse {
		switch (action, db, cause) {
			case (.pragma("cipher_integrity_check", nil), nil, nil):	return .ok
			case (.pragma("foreign_key_check", nil), nil, nil):			return .ok
			case (.pragma("quick_check", nil), nil, nil):				return .ok

			case (.select, nil, nil):									return .ok
			case (.function("count"), nil, nil):						return .ok
			case (.function("json_valid"), nil, nil):					return .ok
			case (.function("json_type"), nil, nil):					return .ok

			case (.read("ad", "domain"), "main", nil):					return .ok
			case (.read("blogspot", "domain"), "main", nil):			return .ok
			case (.read("content_blocker", "id"), "main", nil):			return .ok
			case (.read("content_blocker", "source"), "main", nil):		return .ok
			case (.read("content_blocker", "version"), "main", nil):	return .ok
			case (.read("danger", "domain"), "main", nil):				return .ok
			case (.read("danger", "type"), "main", nil):				return .ok
			case (.read("danger_hash", "hash"), "main", nil):			return .ok
			case (.read("danger_hash", "type"), "main", nil):			return .ok
			case (.read("https", "domain"), "main", nil):				return .ok
			case (.read("parameter_stripping", "host"), "main", nil):	return .ok
			case (.read("parameter_stripping", "name"), "main", nil):	return .ok
			case (.read("parameter_stripping", "value"), "main", nil):	return .ok
			case (.read("popular", "domain"), "main", nil):				return .ok
			case (.read("popular", "rank"), "main", nil):				return .ok
			case (.read("popular", "trackers"), "main", nil):			return .ok
			case (.read("private", "domain"), "main", nil):				return .ok
			case (.read("tracking", "domain"), "main", nil):			return .ok
			default:													return .deny
		}
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		let url = downloadTask.currentRequest?.url?.absoluteString
		if url == domainsDBLocation || url == subscriptionDomainsDBLocation {
			_ = initSQLite
			let setupOptions = SQLite.SetupOptions.secure.subtracting([.limitVariableNumber, .limitLength])
			guard let db = SQLCipher(url: location, key: DomainList.dbKey, flags: .readonly, cipherOptions: .compatibility(3), setupOptions: setupOptions) else {
				return
			}
			guard let _ = try? db.set(authorizer: authorizer) else {
				return
			}
			guard let _ = try? db.dropModules() else {
				return
			}
			guard (try? db.execute("PRAGMA cipher_integrity_check").isEmpty) ?? false else {
				print("DB corrupted")
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
			guard let _ = try? db.execute("SELECT rank, trackers FROM popular LIMIT 0") else {
				print("table popular does not have a rank or trackers column")
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
		if let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first {
			let downloadCaches = cachePath + "/com.apple.nsurlsessiond"
			try? fm.removeItem(atPath: downloadCaches)
		}
	}

	func appropriateListUpdateBackgroundSession(for policy: PolicyManager) -> SnowHazeURLSession {
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
