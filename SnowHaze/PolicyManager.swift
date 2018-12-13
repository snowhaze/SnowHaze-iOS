//
//  PolicyManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

let WebViewURLSchemes = ["http", "https", "data"]

public let aboutBlankURL = "about:blank" // is also used in DB migration
private let dataURIPseudoDomain = "data:uri"
public let missingHostPseudoDomain = "missing:host" // is also used in DB migration
private let aboutBlankURLS = [aboutBlankURL, aboutBlankURL + "%23", aboutBlankURL + "%23moreInformation"]

let allowPermanentDataStorageKey			= "ch.illotros.snowhaze.allowPermanentStorage"
let allowJavaScriptKey						= "ch.illotros.snowhaze.allowJavaScript"
let allowApplicationJavaScriptKey			= "ch.illotros.snowhaze.allowApplicationJavaScript"
let allowPasswordManagerIntegrationKey		= "ch.illotros.snowhaze.allowPasswordManagerIntegration"
let saveHistoryKey							= "ch.illotros.snowhaze.saveHistory"
let userAgentsKey							= "ch.illotros.snowhaze.userAgents"
let searchEngineKey							= "ch.illotros.snowhaze.searchEngine"
let searchSuggestionEnginesKey				= "ch.illotros.snowhaze.searchSuggestionEngines"
let requiresUserActionForMediaPlaybackKey	= "ch.illotros.snowhaze.requiresUserActionForMediaPlayback"
let allowsInlineMediaPlaybackKey			= "ch.illotros.snowhaze.allowsInlineMediaPlayback"
let blockHTTPReferrersKey					= "ch.illotros.snowhaze.blockHTTPReferrers"
let tryHTTPSfirstKey						= "ch.illotros.snowhaze.tryHTTPSfirst"
let nightModeKey							= "ch.illotros.snowhaze.nightMode"
let minFontSizeKey							= "ch.illotros.snowhaze.minFontSize"
let ignoresViewportScaleLimitsKey			= "ch.illotros.snowhaze.ignoresViewportScaleLimits"
let blockTrackingScriptsKey					= "ch.illotros.snowhaze.blockTrackingScripts"
let blockSocialMediaWidgetsKey				= "ch.illotros.snowhaze.blockSocialMediaWidgets"
let applyHideOnlyBlockRulesKey				= "ch.illotros.snowhaze.applyHideOnlyBlockRules"
let useHTTPSExclusivelyWhenPossibleKey		= "ch.illotros.snowhaze.useHTTPSExclusivelyWhenPossible"
let blockMixedContentKey					= "ch.illotros.snowhaze.blockMixedContent"
let forgetPrivateSitesKey					= "ch.illotros.snowhaze.forgetPrivateSites"
let blockCanvasDataAccessKey				= "ch.illotros.snowhaze.blockCanvasDataAccess"
let blockFingerprintingKey					= "ch.illotros.snowhaze.blockFingerprinting"
let popoverBlockingPolicyKey				= "ch.illotros.snowhaze.popoverBlockingPolicy"
let indexBookmarksInSpotlightKey			= "ch.illotros.snowhaze.indexBookmarksInSpotlight"
let addBookmarkApplicationShortcutsKey		= "ch.illotros.snowhaze.addBookmarkApplicationShortcuts"
let suggestPrivateSitesKey					= "ch.illotros.snowhaze.suggestPrivateSites"
let showLocalSiteSuggestionsKey				= "ch.illotros.snowhaze.showLocalSiteSuggestions"
let blockAdsKey								= "ch.illotros.snowhaze.blockAds"
let showDangerousSitesWarningsKey			= "ch.illotros.snowhaze.showDangerousSitesWarnings"
let showTLSCertificateWarningsKey			= "ch.illotros.snowhaze.showTLSCertificateWarnings"
let tabClosingUndoTimeLimitKey				= "ch.illotros.snowhaze.tabClosingUndoTimeLimit"
let allowTabClosingUndoForAllTabsKey		= "ch.illotros.snowhaze.allowTabClosingUndoForAllTabs"
let tabMaskingRuleKey						= "ch.illotros.snowhaze.tabMaskingRule"
let updateSiteListsKey						= "ch.illotros.snowhaze.updateSiteLists"
let useCellularForSiteListsUpdateKey		= "ch.illotros.snowhaze.useCellularForSiteListsUpdate"
let updateVPNListKey						= "ch.illotros.snowhaze.updateVPNList"
let passcodeLockAfterDurationKey			= "ch.illotros.snowhaze.passcodeLockAfterDuration"
let showVPNServerPingStatsKey				= "ch.illotros.snowhaze.showVPNServerPingStats"
let cookieBlockingPolicyKey					= "ch.illotros.snowhaze.cookieBlockingPolicy"
let contentTypeBlockerBlockedTypesKey		= "ch.illotros.snowhaze.contentTypeBlockerBlockedTypes"
let stripTrackingURLParametersKey			= "ch.illotros.snowhaze.stripTrackingURLParameters"
let preventXSSKey							= "ch.illotros.snowhaze.preventXSS"
let skipRedirectsKey						= "ch.illotros.snowhaze.skipRedirects"
let useFrontCameraForCodeScannerKey			= "ch.illotros.snowhaze.useFrontCameraForCodeScanner"
let autorotateIPSecCredentialsKey			= "ch.illotros.snowhaze.autorotateIPSecCredentials"
let updateUsageStatsKey						= "ch.illotros.snowhaze.updateUsageStatsKey"

let lastOpenedVersionKey					= "ch.illotros.snowhaze.lastOpenedVersion"
let lastTutorialVersionKey					= "ch.illotros.snowhaze.lastTutorialVersion"
let lastEOLWarningVersionKey				= "ch.illotros.snowhaze.lastEOLWarningVersion"

let trustedSiteKey							= "ch.illotros.snowhaze.trustedSite"
let readerModeKey							= "ch.illotros.snowhaze.readerMode"
let doNotResetAutoUpdateKey					= "ch.illotros.snowhaze.doNotResetAutoUpdate"

let updateSubscriptionProductListKey		= "ch.illotros.snowhaze.updateSubscriptionProductList"
let updateAuthorizationTokenKey				= "ch.illotros.snowhaze.updateAuthorizationToken"

private let suppressHistoryKey				= "ch.illotros.snowhaze.suppressHistory"

private let defaults: [String: SQLite.Data] = [
	// App Data
	lastOpenedVersionKey:					.integer(0),
	lastTutorialVersionKey:					.integer(0),
	lastEOLWarningVersionKey:				.integer(0),

	// Warnings:
	showDangerousSitesWarningsKey:			.false,
	showTLSCertificateWarningsKey:			.true,
	stripTrackingURLParametersKey:			.false,
	preventXSSKey:							.false,

	// Website Data
	allowPermanentDataStorageKey:			.false,
	cookieBlockingPolicyKey:				.integer(CookieBlockingPolicy.thirdParty.rawValue),

	// History
	saveHistoryKey:							.true,
	forgetPrivateSitesKey:					.true,

	// JavaScript
	allowJavaScriptKey:						.true,
	allowApplicationJavaScriptKey:			.true,
	allowPasswordManagerIntegrationKey:		.true,

	// User Agent
	userAgentsKey:							.text(UserAgent.encode(UserAgent.defaultUserAgentTypes)),

	// Search Engine
	searchEngineKey:						.integer(SearchEngineType.startpage.rawValue),
	searchSuggestionEnginesKey:				.text(SearchEngine.encode([SearchEngineType.startpage, SearchEngineType.wikipedia])),

	// Media Playback
	requiresUserActionForMediaPlaybackKey:	.false,
	allowsInlineMediaPlaybackKey:			.true,

	// Tracking Protection
	blockHTTPReferrersKey:					.true,
	blockTrackingScriptsKey:				.true,
	blockAdsKey:							.true,
	blockCanvasDataAccessKey:				.true,
	blockFingerprintingKey:					.true,
	blockSocialMediaWidgetsKey:				.true,
	applyHideOnlyBlockRulesKey:				.false,

	// HTTPS
	tryHTTPSfirstKey:						.true,
	useHTTPSExclusivelyWhenPossibleKey:		.true,
	blockMixedContentKey:					.true,

	// Appearence
	nightModeKey:							.false,
	minFontSizeKey:							.float(0),
	ignoresViewportScaleLimitsKey:			.false,

	// Popover
	popoverBlockingPolicyKey:				.integer(PopoverBlockingPolicyType.blockScripted.rawValue),

	// External Bookmarks
	indexBookmarksInSpotlightKey:			.true,
	addBookmarkApplicationShortcutsKey:		.true,

	// App Settings
	showLocalSiteSuggestionsKey:			.true,
	suggestPrivateSitesKey:					.false,
	updateSiteListsKey:						.false,
	useCellularForSiteListsUpdateKey:		.false,
	updateUsageStatsKey:					.true,

	tabClosingUndoTimeLimitKey:				.float(10),
	allowTabClosingUndoForAllTabsKey:		.false,
	tabMaskingRuleKey:						.integer(TabMaskingRule.whenPrivate.rawValue),

	// Passcode
	passcodeLockAfterDurationKey:			.float(2 * 60),

	// Hidden
	trustedSiteKey:							.false,
	readerModeKey:							.false,
	doNotResetAutoUpdateKey:				.false,
	skipRedirectsKey:						.false, // not reliable yet; planed for v3
	suppressHistoryKey:						.false,
	useFrontCameraForCodeScannerKey:		.false, // Requires iOS 10; intended for debug use only

	// Subscription
	updateSubscriptionProductListKey:		.false,
	updateAuthorizationTokenKey:			.true,

	// VPN
	updateVPNListKey:						.false,
	showVPNServerPingStatsKey:				.true,
	autorotateIPSecCredentialsKey:			.true,

	// Content Type Blocer
	contentTypeBlockerBlockedTypesKey:		.integer(ContentTypes.none.rawValue),
]

class PolicyManager {
	private static var settingsDefaultsSetup = false

	class var dataAvailable: Bool {
		return SettingsDefaultWrapper.dataAvailable
	}

	let settingsWrapper: SettingsDefaultWrapper

	static func globalManager() -> PolicyManager {
		setupSettingsWrapper()
		let wrapper = SettingsDefaultWrapper.wrapGlobalSettings()
		return PolicyManager(wrapper: wrapper)
	}

	static func manager(for tab: Tab) -> PolicyManager {
		setupSettingsWrapper()
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: tab)
		return PolicyManager(wrapper: wrapper)
	}

	static func manager(for url: URL?, in tab: Tab) -> PolicyManager {
		setupSettingsWrapper()
		let domain = PolicyDomain(url: url)
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: domain, inTab: tab)
		return PolicyManager(wrapper: wrapper)
	}

	static func isAboutBlank(_ url: URL?) -> Bool {
		guard let url = url else {
			return false
		}
		return aboutBlankURLS.contains(url.absoluteString)
	}

	static func isNormalDataURI(_ url: URL?) -> Bool {
		guard let url = url else {
			return false
		}
		return url.scheme?.lowercased() == "data" && url.host == nil
	}

	init(wrapper: SettingsDefaultWrapper) {
		settingsWrapper = wrapper
	}

	var allowPermanentDataStorage: Bool {
		return bool(for: allowPermanentDataStorageKey)
	}

	var displayInstallTutorial: Bool {
		return settingsWrapper.value(for: lastTutorialVersionKey).integer! < version_2_0_0__028
	}

	var showEOLWarning: Bool {
		return buildExpiration < Date() && settingsWrapper.value(for: lastEOLWarningVersionKey).integer! < currentVersion
	}

	var webViewConfiguration: WKWebViewConfiguration {
		let config = WKWebViewConfiguration()
		let userActionForMedia = bool(for: requiresUserActionForMediaPlaybackKey)
		config.allowsInlineMediaPlayback = bool(for: allowsInlineMediaPlaybackKey)
		if #available(iOS 10, *) {
			config.ignoresViewportScaleLimits = bool(for: ignoresViewportScaleLimitsKey)
			config.mediaTypesRequiringUserActionForPlayback = userActionForMedia ? .all : []
		} else {
			config.requiresUserActionForMediaPlayback = userActionForMedia
		}
		return config
	}

	var urlSessionConfiguration: URLSessionConfiguration {
		return allowPermanentDataStorage ? URLSessionConfiguration.default : URLSessionConfiguration.ephemeral
	}

	var dataStore: WKWebsiteDataStore {
		return allowPermanentDataStorage ? WKWebsiteDataStore.default() : WKWebsiteDataStore.nonPersistent()
	}

	var allowJS: Bool {
		return bool(for: allowJavaScriptKey)
	}

	var allowPWManager: Bool {
		return bool(for: allowPasswordManagerIntegrationKey)
	}

	var trust: Bool {
		return bool(for: trustedSiteKey)
	}

	var updateProductList: Bool {
		return bool(for: updateSubscriptionProductListKey)
	}

	var autoUpdateAuthToken: Bool {
		return bool(for: updateAuthorizationTokenKey)
	}

	var autoUpdateVPNList: Bool {
		return bool(for: updateVPNListKey)
	}

	var autorotateIPSecCredentials: Bool {
		return bool(for: autorotateIPSecCredentialsKey)
	}

	var updateSiteLists: Bool {
		let lastUpdate = (lastSiteListUpdate ?? .distantPast)
		return !deleteSiteLists && ((lastUpdate < compilationDate) || (SubscriptionManager.shared.hasSubscription && lastUpdate.timeIntervalSinceNow < -7 * 24 * 60 * 60))
	}

	var deleteSiteLists: Bool {
		return !bool(for: updateSiteListsKey)
	}

	var useCellularForSiteListsUpdate: Bool {
		return bool(for: useCellularForSiteListsUpdateKey)
	}

	var lastSiteListUpdate: Date? {
		let fm = FileManager.default
		guard let attributes = try? fm.attributesOfItem(atPath: DomainList.dbLocation) else {
			return nil
		}
		return (attributes as NSDictionary).fileCreationDate()
	}

	var minFontSize: CGFloat {
		let data = settingsWrapper.value(for: minFontSizeKey)
		let value = data.floatValue!
		return CGFloat(value)
	}

	var allowApplicationJS: Bool {
		return bool(for: allowApplicationJavaScriptKey)
	}

	var searchEngine: SearchEngine {
		let value = settingsWrapper.value(for: searchEngineKey).integer
		let type = SearchEngineType(rawValue: value!) ?? .none
		return SearchEngine(type: type)
	}

	var indexBookmarks: Bool {
		return bool(for: indexBookmarksInSpotlightKey)
	}

	var applicationShortcutItems: [UIApplicationShortcutItem] {
		guard bool(for: addBookmarkApplicationShortcutsKey) else {
			return []
		}
		let bookmarks = BookmarkStore.store.items
		return bookmarks.map { bookmark -> UIApplicationShortcutItem in
			let title = bookmark.displayName ?? ""
			let type = bookmarkApplicationShortcutType
			let userInfo = ["id": NSNumber(value: bookmark.id as Int64), "url": bookmark.URL.absoluteString] as! [String : NSSecureCoding]
			let icon = UIApplicationShortcutIcon(templateImageName: "bookmark")
			return UIApplicationShortcutItem(type: type, localizedTitle: title, localizedSubtitle: bookmark.URL.absoluteString, icon: icon, userInfo: userInfo)
		}
	}

	var keepStats: Bool {
		return bool(for: updateUsageStatsKey)
	}

	var isSuppressingHistory: Bool {
		return bool(for: suppressHistoryKey)
	}

	var isInNightMode: Bool {
		return bool(for: nightModeKey)
	}

	var isInReaderMode: Bool {
		return bool(for: readerModeKey)
	}

	var useFrontCamera: Bool {
		return bool(for: useFrontCameraForCodeScannerKey)
	}

	/**
	 *	Is not guarantied to return the same user agent even on multiple calls to same PolicyManager object
	 */
	var userAgent: String {
		let agentTypes = UserAgent.decode(settingsWrapper.value(for: userAgentsKey).text!)
		return UserAgent(type: agentTypes.randomElement).string
	}

	var userScripts: [WKUserScript] {
		guard allowApplicationJS else {
			return []
		}
		var ret = [WKUserScript]()
		if bool(for: blockHTTPReferrersKey) {
			let js = JSGenerator.named("BlockReferrers")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
		}
		if isInNightMode {
			let js = JSGenerator.named("NightMode")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
		}
		if #available(iOS 11, *) {
			// tracking scripts are blocked with WKContentRuleLists
		} else {
			if blockTrackingScripts {
				let blacklist = DomainList(type: .trackingScripts).domains
				let js = JSGenerator.named("ScriptBlackListing")!.generate(with: ["blacklist": blacklist as AnyObject])!
				ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
			}
		}
		if #available(iOS 11, *) {
			// ads are blocked with WKContentRuleLists
		} else {
			if blockAds {
				let blacklist = DomainList(type: .ads).domains
				let js = JSGenerator.named("BlockAds")!.generate(with: ["blacklist": blacklist as AnyObject])!
				ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
			}
		}
		if bool(for: blockCanvasDataAccessKey) {
			let js = JSGenerator.named("CanvasProtection")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
		}
		if bool(for: blockFingerprintingKey) {
			let js = JSGenerator.named("FingerprintingProtection")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
		}
		if isInReaderMode {
			let js = JSGenerator.named("ReaderMode")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
		}
		return ret
	}

	@available(iOS 11, *)
	func withEnabledContentRuleLists(do work: @escaping ([WKContentRuleList], [WKUserScript]) -> Void) {
		assert(ContentTypes.allTypes == [.document, .image, .styleSheet, .script, .font, .raw, .svgDocument, .media, .popup, .thirdPartyScripts])
		let blockAds = self.blockAds
		let blockTrackingScripts = self.blockTrackingScripts
		let blockSocialMediaWidgets = bool(for: blockSocialMediaWidgetsKey)
		let applyHideOnly = bool(for: applyHideOnlyBlockRulesKey)
		let rawType = settingsWrapper.value(for: contentTypeBlockerBlockedTypesKey).integer!
		let blockedTypes = ContentTypes(rawValue: rawType)
		let blockMixedContent = self.blockMixedContent
		let httpsOnly = self.useHTTPSExclusivelyWhenPossible
		let cookieBlockingPolicy = CookieBlockingPolicy(rawValue: settingsWrapper.value(for: cookieBlockingPolicyKey).integer!)!
		let applicationJS = allowApplicationJS

		let typeBlockers: [(ContentTypes, String, String)] = [
			(.document, BlockerID.documentContentTypeBlocker, "document"),
			(.image, BlockerID.imageContentTypeBlocker, "image"),
			(.styleSheet, BlockerID.styleSheetContentTypeBlocker, "style sheet"),
			(.script, BlockerID.scriptContentTypeBlocker, "script"),
			(.font, BlockerID.fontContentTypeBlocker, "font"),
			(.raw, BlockerID.rawContentTypeBlocker, "raw"),
			(.svgDocument, BlockerID.svgDocumentContentTypeBlocker, "svg document"),
			(.media, BlockerID.mediaContentTypeBlocker, "media"),
			(.popup, BlockerID.popupContentTypeBlocker, "popup"),
			(.thirdPartyScripts, BlockerID.thirdPartyScriptsContentTypeBlocker, "third party scripts"),
		]

		ContentBlockerManager.shared.load {
			var blockers = [WKContentRuleList]()
			var replacementScripts = [WKUserScript]()
			let allBlockers = ContentBlockerManager.shared.blockers
			if blockSocialMediaWidgets {
				if applyHideOnly, let blocker = allBlockers[BlockerID.socialMediaWidgetsHider] {
					blockers.append(blocker)
				} else if applyHideOnly {
					print("social media widget hider not available")
				}
				if let blocker = allBlockers[BlockerID.socialMediaWidgetsBlocker] {
					blockers.append(blocker)
				} else {
					print("social media widget blocker not available")
				}
			}
			if blockAds {
				if applyHideOnly, let blocker = allBlockers[BlockerID.adHider] {
					blockers.append(blocker)
				} else if applyHideOnly {
					print("ad hider not available")
				}
				if let blocker1 = allBlockers[BlockerID.adBlocker1], let blocker2 = allBlockers[BlockerID.adBlocker2] {
					blockers.append(blocker1)
					blockers.append(blocker2)
				} else {
					let blacklist = DomainList(type: .ads).domains
					let js = JSGenerator.named("BlockAds")!.generate(with: ["blacklist": blacklist as AnyObject])!
					replacementScripts.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
					print("ad blocker not available")
				}
			}
			if blockTrackingScripts {
				if let blocker = allBlockers[BlockerID.trackingScriptsBlocker] {
					blockers.append(blocker)
				} else {
					let blacklist = DomainList(type: .trackingScripts).domains
					let js = JSGenerator.named("ScriptBlackListing")!.generate(with: ["blacklist": blacklist as AnyObject])!
					replacementScripts.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
					print("tracking scripts blocker not available")
				}
			}

			if let blocker = cookieBlockingPolicy.contentBlocker {
				blockers.append(blocker)
			} else if case .none = cookieBlockingPolicy {
				// everything ok
			} else {
				print("cookie blocker not available")
			}

			if blockMixedContent {
				if let blocker = allBlockers[BlockerID.mixedContentBlocker] {
					blockers.append(blocker)
				} else {
					print("mixed content blocker not available")
				}
			}
			if httpsOnly {
				if let blocker = allBlockers[BlockerID.hstsPreloadUpgrader] {
					blockers.append(blocker)
				} else {
					print("hsts preload upgrader not available")
				}
			}

			for (type, blockerID, name) in typeBlockers {
				if blockedTypes.contains(type) {
					if let blocker = allBlockers[blockerID] {
						blockers.append(blocker)
					} else {
						print("content type \(name) blocker content blocker not available")
					}
				}
			}

			work(blockers, applicationJS ? replacementScripts : [])
		}
	}

	var blockAds: Bool {
		return bool(for: blockAdsKey)
	}

	var blockTrackingScripts: Bool {
		return bool(for: blockTrackingScriptsKey)
	}

	var blockMixedContent: Bool {
		return bool(for: blockMixedContentKey)
	}

	var useHTTPSExclusivelyWhenPossible: Bool {
		return bool(for: useHTTPSExclusivelyWhenPossibleKey)
	}

	var preventXSS: Bool {
		return bool(for: preventXSSKey)
	}

	var stripTrackingURLParameters: Bool {
		return bool(for: stripTrackingURLParametersKey)
	}

	var skipRedirects: Bool {
		return bool(for: skipRedirectsKey)
	}

	var allowAutomaticJSPopovers: Bool {
		let policyInt = settingsWrapper.value(for: popoverBlockingPolicyKey).integer!
		let type = PopoverBlockingPolicyType(rawValue: policyInt)!
		let policy = PopoverBlockingPolicy(type: type)
		return policy.allowAutomaticJSPopovers
	}

	var needsScreenLockPreparation: Bool {
		if case .off = PasscodeManager.shared.mode {
			return false
		} else {
			return settingsWrapper.value(for: passcodeLockAfterDurationKey).float! < Double.infinity
		}
	}

	var threeLanguageCode: String {
		let fullLang = NSLocalizedString("localization code", comment: "code used to identify the current locale")
		if ["en", "en-GB"].contains(fullLang) {
			return "en"
		}
		if ["de", "gsw"].contains(fullLang) {
			return "de"
		}
		if ["fr"].contains(fullLang) {
			return "fr"
		}
		return "en"
	}

	func lockAfter(duration: TimeInterval) -> Bool{
		if case .off = PasscodeManager.shared.mode {
			return false
		} else {
			return duration >= settingsWrapper.value(for: passcodeLockAfterDurationKey).float!
		}
	}

	func stopSuppressingHistory() {
		settingsWrapper.unsetValue(for: suppressHistoryKey)
	}

	func setupHistorySuppresion(for url: URL?) {
		guard bool(for: forgetPrivateSitesKey) else {
			return
		}
		struct Local {
			static let blogspot = DomainList(type: .blogspot).domains.map { "." + $0 }
		}
		guard let host = url?.host else {
			return
		}
		let offset = host.hasPrefix("www.") ? 4 : 0
		var query = String(host[host.index(host.startIndex, offsetBy: offset)...])
		if let blogspot = Local.blogspot.first(where: { query.hasSuffix($0) }) {
			let index = query.index(query.endIndex, offsetBy: -blogspot.count)
			query = String(query[..<index]) + ".blogspot.com"
		}
		let privateSites = DomainList(type: .privateSites)
		if privateSites.contains(query) {
			settingsWrapper.set(.true, for: suppressHistoryKey)
		}
	}

	func updateTutorialVersion() {
		settingsWrapper.set(.integer(currentVersion), for: lastTutorialVersionKey)
	}

	func updateOpenedVersion() {
		settingsWrapper.set(.integer(currentVersion), for: lastOpenedVersionKey)
	}

	var displayUpdateTutorial: Bool {
		guard let lastVersion = settingsWrapper.value(for: lastTutorialVersionKey).integer else {
			return false
		}
		return !displayInstallTutorial && lastVersion < version_2_5_0__055
	}

	func updateEOLWarningVersion() {
		settingsWrapper.set(.integer(currentVersion), for: lastEOLWarningVersionKey)
	}

	func searchSuggestionSources(for tab: Tab) -> [SuggestionSource] {
		let localSources: [SuggestionSource] = [HistorySuggestionSource(), BookmarkSuggestionSource(), PopularSitesSuggestionSource(includePrivate: bool(for: suggestPrivateSitesKey), upgrade: useHTTPSExclusivelyWhenPossible, tab: tab)]
		let encoded = settingsWrapper.value(for: searchSuggestionEnginesKey).text!
		let engines = SearchEngine.decode(encoded)
		let engineSources: [SuggestionSource] = engines.map {
			SearchEngineSuggestionSource(engine: SearchEngine(type: $0), tab: tab)
		}
		return (bool(for: showLocalSiteSuggestionsKey) ? localSources : []) + engineSources
	}

	var showTLSCertWarnings: Bool {
		return bool(for: showTLSCertificateWarningsKey)
	}

	var shouldAddToHistory: Bool {
		return bool(for: saveHistoryKey) && !isSuppressingHistory
	}

	var shouldMask: Bool {
		let value = settingsWrapper.value(for: tabMaskingRuleKey)
		let rule = TabMaskingRule(rawValue: value.integer!)!
		return rule.shouldMask(isPrivate: !shouldAddToHistory) && !needsScreenLockPreparation
	}

	var tabClosingUndoTimeLimit: TimeInterval {
		if shouldAddToHistory || bool(for: allowTabClosingUndoForAllTabsKey) {
			let data = settingsWrapper.value(for: tabClosingUndoTimeLimitKey)
			let value = data.floatValue!
			return TimeInterval(value)
		} else {
			return 0
		}
	}

	enum Action {
		case load(URL, Bool)
	}
	func actionList(for userInput: String) -> [Action] {
		let httpsSites = DomainList(type: useHTTPSExclusivelyWhenPossible ? .httpsSites : .empty)
		var ret = [Action]()
		if let url = userInput.punycodeURL {
			if url.scheme!.lowercased() == "http" && httpsSites.contains(url.host!) {
				var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
				components.scheme = "https"
				return [.load(components.url!, true)]
			} else {
				return [.load(url, false)]
			}
		}

		if let encoded = userInput.punycodeExtension {
			let httpsFirst = bool(for: tryHTTPSfirstKey)
			var https = [Action]()

			if let url = encoded.extendToURL(https: true, www: false) {
				let upgraded = httpsFirst || httpsSites.contains(url.host!)
				https.append(.load(url, upgraded))
			}
			if let url = encoded.extendToURL(https: true, www: true), !encoded.hasWPrefix {
				let upgraded = httpsFirst || httpsSites.contains(url.host!)
				https.append(.load(url, https.isEmpty && upgraded))
			}
			var http = [Action]()
			if let url = encoded.extendToURL(https: false, www: false) {
				if !httpsSites.contains(url.host!) {
					http.append(.load(url, false))
				}
			}
			if let url = encoded.extendToURL(https: false, www: true), !encoded.hasWPrefix {
				if !httpsSites.contains(url.host!) {
					http.append(.load(url, false))
				}
			}
			if httpsFirst {
				ret += https + http
			} else {
				ret += http + https
			}
			if !ret.isEmpty && !encoded.isLocalhostExtendable {
				return ret
			}
		}
		let engine = searchEngine
		if let url = engine.url(for: userInput) {
			ret.append(.load(url, false))
		}
		return ret
	}

	func allowsPopover(for navigationType: WKNavigationType) -> Bool {
		let policyInt = settingsWrapper.value(for: popoverBlockingPolicyKey).integer!
		let type = PopoverBlockingPolicyType(rawValue: policyInt)!
		let policy = PopoverBlockingPolicy(type: type)
		return policy.allow(for: navigationType)
	}

	func shouldBlockLoad(of url: URL?) -> Bool {
		guard let host = url?.host else {
			return false
		}
		return blockAds && DomainList(type: .ads).contains(host)
	}

	enum Danger: Int64 {
		case malicious			= 1
		case phish				= 2
		case phishGoogle		= 3
		case malware			= 4
		case harmfulApplication	= 5
		case unwantedSoftware	= 6
	}
	func dangerReasons(for url: URL?) -> Set<Danger> {
		guard bool(for: showDangerousSitesWarningsKey) else {
			return []
		}
		var types = Set<Int64>()
		if let host = url?.host {
			types = types.union(DomainList(type: .danger).types(forDomain: host))
		}
		if let url = url {
			types = types.union(DomainList(type: .dangerHash).types(forURL: url))
		}
		return Set(types.compactMap({ Danger(rawValue: $0) }))
	}
}

struct PolicyDomain {
	let domain: String
	init(url: URL?) {
		if PolicyManager.isAboutBlank(url) {
			domain = aboutBlankURL
		} else if PolicyManager.isNormalDataURI(url) {
			domain = dataURIPseudoDomain
		} else {
			domain = url?.host?.replacingOccurrences(of: ":", with: "::") ?? missingHostPseudoDomain
		}
	}
}

// internals
extension PolicyManager {
	private static func setupSettingsWrapper() {
		if !settingsDefaultsSetup {
			SettingsDefaultWrapper.standardDefaults = defaults
			settingsDefaultsSetup = true
		}
	}

	private func bool(for key: String) -> Bool {
		return settingsWrapper.value(for: key).boolValue
	}
}
