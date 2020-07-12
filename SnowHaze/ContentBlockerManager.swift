//
//  ContentBlockerManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

private let compiledContentBlockerVersionKeyPrefix = "ch.illotros.snowhaze.contenblockermanager.contentblocker.compiled.version."

class BlockerID {
	fileprivate static let deprecatedAdBlocker = "ad-blocker"
	fileprivate static let deprecatedHstsPreloadUpgrader = "hsts-preload-upgrader"

	static let adBlocker1 = "ad-blocker-1-2"
	static let adBlocker2 = "ad-blocker-2-2"
	static let adHider = "ad-hider"
	static let trackingScriptsBlocker = "tracking-scripts-blocker"
	static let socialMediaWidgetsBlocker = "social-media-widgets-blocker"
	static let socialMediaWidgetsHider = "social-media-widgets-hider"

	static let allCookiesBlocker = "all-cookies-blocker"
	static let thirdPartiesCookiesBlocker = "third-party-cookies-blocker"

	static let mixedContentBlocker = "mixed-content-blocker"
	static let httpsOnlyContentBlocker = "upgrade-all-http-blocker"
	static let nonTorURLsBlocker = "non-tor-urls-blocker"
	static let dohServerBlocker = "doh-server-blocker"

	static let hstsPreloadUpgrader1 = "hsts-preload-upgrader-1-4"
	static let hstsPreloadUpgrader2 = "hsts-preload-upgrader-2-4"
	static let hstsPreloadUpgrader3 = "hsts-preload-upgrader-3-4"
	static let hstsPreloadUpgrader4 = "hsts-preload-upgrader-4-4"

	static let documentContentTypeBlocker = "document-content-type-blocker"
	static let imageContentTypeBlocker = "image-content-type-blocker"
	static let styleSheetContentTypeBlocker = "style-sheet-content-type-blocker"
	static let scriptContentTypeBlocker = "script-content-type-blocker"
	static let fontContentTypeBlocker = "font-content-type-blocker"
	static let rawContentTypeBlocker = "raw-content-type-blocker"
	static let svgDocumentContentTypeBlocker = "svg-document-content-type-blocker"
	static let mediaContentTypeBlocker = "media-content-type-blocker"
	static let popupContentTypeBlocker = "popup-content-type-blocker"
	static let thirdPartyScriptsContentTypeBlocker = "third-party-script-content-type-blocker"

	static let allIDs = [
		adBlocker1,
		adBlocker2,
		adHider,
		trackingScriptsBlocker,
		socialMediaWidgetsBlocker,
		socialMediaWidgetsHider,

		allCookiesBlocker,
		thirdPartiesCookiesBlocker,
		nonTorURLsBlocker,
		dohServerBlocker,

		httpsOnlyContentBlocker,
		mixedContentBlocker,
		hstsPreloadUpgrader1,
		hstsPreloadUpgrader2,
		hstsPreloadUpgrader3,
		hstsPreloadUpgrader4,

		documentContentTypeBlocker,
		imageContentTypeBlocker,
		styleSheetContentTypeBlocker,
		scriptContentTypeBlocker,
		fontContentTypeBlocker,
		rawContentTypeBlocker,
		svgDocumentContentTypeBlocker,
		mediaContentTypeBlocker,
		popupContentTypeBlocker,
		thirdPartyScriptsContentTypeBlocker,
	]

	static let checkBlockers = [
		adBlocker1,
		hstsPreloadUpgrader1,
		nonTorURLsBlocker,
		httpsOnlyContentBlocker,
	]

	fileprivate static let optionalContentBlockers = [
		hstsPreloadUpgrader2,
		hstsPreloadUpgrader3,
		hstsPreloadUpgrader4,
	]

	fileprivate static let deprecatedContentBlockers = [
		deprecatedAdBlocker,
		deprecatedHstsPreloadUpgrader,
	]
}

class ContentBlockerManager {
	private init() {
		observer = NotificationCenter.default.addObserver(forName: DomainList.dbFileChangedNotification, object: nil, queue: nil) { _ in
			// Ensure, that DomainList's db is already updated
			DispatchQueue.main.async {
				let me = ContentBlockerManager.shared
				// and that me.blockers is set
				me.load {
					for id in BlockerID.allIDs {
						if me.has(with: id) && me.compiledVersion(for: id) != me.currentVersion(for: id) {
							let (version, source) = me.code(for: id)
							WKContentRuleListStore.default().compileContentRuleList(forIdentifier: id, encodedContentRuleList: source) { list, error in
								if let error = error {
									print("rule list recompilation error for \(id): \(error)")
								}
								if let list = list {
									syncToMainThread {
										me.blockers[id] = list
										DataStore.shared.set(version, for: compiledContentBlockerVersionKeyPrefix + id)
									}
								}
							}
						}
					}
				}
			}
		}
	}
	private let observer: NSObjectProtocol

	deinit {
		NotificationCenter.default.removeObserver(observer)
	}

	static let shared = ContentBlockerManager()
	private let store = WKContentRuleListStore.default()

	private(set) var blockers = [String: WKContentRuleList]()
	private var compilationCnt = 0
	private var blockerCallbacks = [() -> Void]()
	private var isLoading = false

	func load(completionHandler: (() -> Void)?) {
		assert(Thread.isMainThread)
		if canLoadPages {
			completionHandler?()
			return
		}
		if let completion = completionHandler {
			blockerCallbacks.append(completion)
		}
		if isLoading {
			return
		}
		isLoading = true
		let optional = BlockerID.optionalContentBlockers
		let nonOptional = BlockerID.allIDs.filter { !optional.contains($0) }
		nonOptional.forEach { load(rules: $0) }
		optional.forEach { load(rules: $0) }
		BlockerID.deprecatedContentBlockers.forEach { clear(for: $0) }
	}

	private func clear(for id: String) {
		if let _ = compiledVersion(for: id) {
			WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: id) { rules, error in
				print(error as Any)
				if let _ = rules {
					WKContentRuleListStore.default().removeContentRuleList(forIdentifier: id) { erron in
						guard error == nil else {
							return
						}
						DispatchQueue.main.async {
							DataStore.shared.delete(compiledContentBlockerVersionKeyPrefix + id)
						}
					}
				} else if let error = error as NSError?, error.code == 7, error.domain == "WKErrorDomain" {
					DispatchQueue.main.async {
						DataStore.shared.delete(compiledContentBlockerVersionKeyPrefix + id)
					}
				}
			}
		}
	}

	private func load(rules id: String) {
		guard has(with: id) else {
			completeLoad(of: id, with: nil)
			return
		}
		if compiledVersion(for: id) == currentVersion(for: id) {
			WKContentRuleListStore.default().lookUpContentRuleList(forIdentifier: id) { list, error in
				if let error = error {
					print("rule list load error for \(id): \(error)")
				}
				if let list = list {
					self.completeLoad(of: id, with: list)
				} else {
					syncToMainThread {
						DataStore.shared.delete(compiledContentBlockerVersionKeyPrefix + id)
					}
					self.load(rules: id)
				}
			}
		} else {
			let (version, source) = code(for: id)
			WKContentRuleListStore.default().compileContentRuleList(forIdentifier: id, encodedContentRuleList: source) { list, error in
				if let error = error {
					print("rule list compilation error for \(id): \(error)")
				}
				if let _ = list {
					syncToMainThread {
						DataStore.shared.set(version, for: compiledContentBlockerVersionKeyPrefix + id)
					}
				}
				self.completeLoad(of: id, with: list)
			}
		}
	}

	private func completeLoad(of id: String, with rules: WKContentRuleList?) {
		syncToMainThread {
			assert(compilationCnt < BlockerID.allIDs.count)
			blockers[id] = rules
			compilationCnt += 1
			if canLoadPages {
				isLoading = false
				blockerCallbacks.forEach { $0() }
				blockerCallbacks = []
			}
		}
	}

	private func compiledVersion(for id: String) -> Int64? {
		return syncToMainThread {
			return DataStore.shared.getInt(for: compiledContentBlockerVersionKeyPrefix + id)
		}
	}

	private func currentVersion(for id: String) -> Int64 {
		return DomainList.contentBlockerVersion(for: id)
	}

	private func has(with id: String) -> Bool {
		return DomainList.hasContentBlocker(with: id)
	}

	private func code(for id: String) -> (Int64, String) {
		return DomainList.contentBlockerSource(for: id)
	}

	private var canLoadPages: Bool {
		let outstandingOptionals = BlockerID.optionalContentBlockers.filter({ blockers[$0] == nil })
		let requiredCount = BlockerID.allIDs.count - outstandingOptionals.count
		assert(compilationCnt <= requiredCount)
		return compilationCnt == requiredCount
	}
}
