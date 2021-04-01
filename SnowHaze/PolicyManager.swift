//
//  PolicyManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit

let WebViewURLSchemes = ["http", "https", "data", "javascript"]

let scaleStorageFactor: Int64 = 1_000_000

let allowPermanentDataStorageKey			= "ch.illotros.snowhaze.allowPermanentStorage"
let allowJavaScriptKey						= "ch.illotros.snowhaze.allowJavaScript"
let allowApplicationJavaScriptKey			= "ch.illotros.snowhaze.allowApplicationJavaScript"
let allowPasswordManagerIntegrationKey		= "ch.illotros.snowhaze.allowPasswordManagerIntegration"
let saveHistoryKey							= "ch.illotros.snowhaze.saveHistory"
let userAgentsKey							= "ch.illotros.snowhaze.userAgents"
let renderAsDesktopSiteKey					= "ch.illotros.snowhaze.renderAsDesktopSite"
let searchEngineKey							= "ch.illotros.snowhaze.searchEngine"
let searchSuggestionEnginesKey				= "ch.illotros.snowhaze.searchSuggestionEngines"
let customSearchURLKey						= "ch.illotros.snowhaze.customSearchURL"
let customSearchSuggestionsURLKey			= "ch.illotros.snowhaze.customSearchSuggestionsURL"
let customSearchSuggestionsJSONPathKey		= "ch.illotros.snowhaze.customSearchSuggestionsJSONPath"
let requiresUserActionForMediaPlaybackKey	= "ch.illotros.snowhaze.requiresUserActionForMediaPlayback"
let allowsInlineMediaPlaybackKey			= "ch.illotros.snowhaze.allowsInlineMediaPlayback"
let blockHTTPReferrersKey					= "ch.illotros.snowhaze.blockHTTPReferrers"
let tryHTTPSfirstKey						= "ch.illotros.snowhaze.tryHTTPSfirst"
let nightModeKey							= "ch.illotros.snowhaze.nightMode"
let minFontSizeKey							= "ch.illotros.snowhaze.minFontSize"
let webContentScaleKey						= "ch.illotros.snowhaze.webContentScale"
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
let allowCloseAllTabsKey					= "ch.illotros.snowhaze.allowCloseAllTabs"
let autorotateIPSecCredentialsKey			= "ch.illotros.snowhaze.autorotateIPSecCredentials"
let updateUsageStatsKey						= "ch.illotros.snowhaze.updateUsageStatsKey"
let allowJSURLsInURLBarKey					= "ch.illotros.snowhaze.allowJSURLsInURLBar"
let homepageURLKey							= "ch.illotros.snowhaze.homepageURL"
let previewDelayKey							= "ch.illotros.snowhaze.previewDelay"
let safebrowsingEnabledKey					= "ch.illotros.snowhaze.safebrowsing.enabled"
let safebrowsingProxyKey					= "ch.illotros.snowhaze.safebrowsing.proxy"
let safebrowsingHardFailKey					= "ch.illotros.snowhaze.safebrowsing.hardFail"
let safebrowsingCacheSharingKey				= "ch.illotros.snowhaze.safebrowsing.cacheSharing"
let requireHTTPSForTrustedSitesKey			= "ch.illotros.snowhaze.trustedSite.requireHTTPS"
let upgradeAllHTTPKey						= "ch.illotros.snowhaze.trustedSite.upgradeAllHTTP"
let blockDOHServersKey						= "ch.illotros.snowhaze.blockDOHServers"
let warnCrossFrameNavigationKey				= "ch.illotros.snowhaze.warnCrossFrameNavigation"
let blockDeprecatedTLSKey					= "ch.illotros.snowhaze.blockDeprecatedTLS"

let lastOpenedVersionKey					= "ch.illotros.snowhaze.lastOpenedVersion"
let lastTutorialVersionKey					= "ch.illotros.snowhaze.lastTutorialVersion"
let lastEOLWarningVersionKey				= "ch.illotros.snowhaze.lastEOLWarningVersion"

let trustedSiteKey							= "ch.illotros.snowhaze.trustedSite"
let readerModeKey							= "ch.illotros.snowhaze.readerMode"
let doNotResetAutoUpdateKey					= "ch.illotros.snowhaze.doNotResetAutoUpdate"
let strictTabGroupSeparationKey				= "ch.illotros.snowhaze.strictTabGroupSeparation"

let useTorNetworkKey						= "ch.illotros.snowhaze.useTorNetwork"
let startTorOnAppLaunchKey					= "ch.illotros.snowhaze.startTorOnAppLaunch"
let useTorForAPICallsKey					= "ch.illotros.snowhaze.useTorForAPICalls"
let rotateCircuitForNewTokensKey			= "ch.illotros.snowhaze.rotateTorCircuitForNewTokens"
let sendDNTHeaderOverTorKey					= "ch.illotros.snowhaze.sendDNTHeaderOverTor"

let updateSubscriptionProductListKey		= "ch.illotros.snowhaze.updateSubscriptionProductList"
let updateAuthorizationTokenKey				= "ch.illotros.snowhaze.updateAuthorizationToken"

private let suppressHistoryKey				= "ch.illotros.snowhaze.suppressHistory"

private let defaults: [String: SQLite.Data] = [
	// App Data
	lastOpenedVersionKey:					.integer(0),
	lastTutorialVersionKey:					.integer(0),
	lastEOLWarningVersionKey:				.integer(0),

	// Warnings:
	showDangerousSitesWarningsKey:			.true,
	showTLSCertificateWarningsKey:			.true,
	stripTrackingURLParametersKey:			.false,
	preventXSSKey:							.false,
	warnCrossFrameNavigationKey:			.false,

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
	allowJSURLsInURLBarKey:					.false,

	// User Agent
	userAgentsKey:							.text(UserAgent.encode(UserAgent.defaultUserAgentTypes)),
	renderAsDesktopSiteKey:					SQLite.Data(UIDevice.current.userInterfaceIdiom == .pad),

	// Search Engine
	searchEngineKey:						.integer(SearchEngineType.startpage.rawValue),
	searchSuggestionEnginesKey:				.text(SearchEngine.encode([SearchEngineType.startpage, SearchEngineType.wikipedia])),
	customSearchURLKey:						.text(""),
	customSearchSuggestionsURLKey:			.text(""),
	customSearchSuggestionsJSONPathKey:		.text(""),

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
	skipRedirectsKey:						.false,

	// HTTPS
	tryHTTPSfirstKey:						.true,
	useHTTPSExclusivelyWhenPossibleKey:		.true,
	blockMixedContentKey:					.true,
	requireHTTPSForTrustedSitesKey:			.false,
	upgradeAllHTTPKey:						.false,
	blockDeprecatedTLSKey:					.true,

	// Appearence
	nightModeKey:							.false,
	minFontSizeKey:							.float(0),
	ignoresViewportScaleLimitsKey:			.false,
	webContentScaleKey:						.integer(scaleStorageFactor),

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
	homepageURLKey:							.null,

	tabClosingUndoTimeLimitKey:				.float(10),
	allowTabClosingUndoForAllTabsKey:		.false,
	tabMaskingRuleKey:						.integer(TabMaskingRule.whenPrivate.rawValue),

	// Passcode
	passcodeLockAfterDurationKey:			.float(2 * 60),

	// Hidden
	trustedSiteKey:							.false,
	readerModeKey:							.false,
	doNotResetAutoUpdateKey:				.false,
	suppressHistoryKey:						.false,
	useFrontCameraForCodeScannerKey:		.false, // intended for debug use only
	allowCloseAllTabsKey:					.true, // intended for debug use only
	strictTabGroupSeparationKey:			.true,
	previewDelayKey:						.float(5),

	// Subscription
	updateSubscriptionProductListKey:		.false,
	updateAuthorizationTokenKey:			.true,

	// VPN
	updateVPNListKey:						.false,
	showVPNServerPingStatsKey:				.true,
	autorotateIPSecCredentialsKey:			.true,

	// Content Blocer
	contentTypeBlockerBlockedTypesKey:		.integer(ContentTypes.none.rawValue),
	blockDOHServersKey:						.true,

	// Safebrowsing
	safebrowsingEnabledKey:					.false,
	safebrowsingProxyKey:					.true,
	safebrowsingHardFailKey:				.true,
	safebrowsingCacheSharingKey:			.integer(SafebrowsingCacheSharing.prefix.rawValue),

	// Tor
	useTorNetworkKey:						.false,
	startTorOnAppLaunchKey:					.false,
	sendDNTHeaderOverTorKey:				.false,
	useTorForAPICallsKey:					.false,
	rotateCircuitForNewTokensKey:			.false,
]

class PolicyManager {
	private static var globalSetupPerformed = false

	class var dataAvailable: Bool {
		return SettingsDefaultWrapper.dataAvailable
	}

	let settingsWrapper: SettingsDefaultWrapper

	static func globalManager() -> PolicyManager {
		setup()
		let wrapper = SettingsDefaultWrapper.wrapGlobalSettings()
		return PolicyManager(wrapper: wrapper)
	}

	static func manager(for tab: Tab) -> PolicyManager {
		precondition(!tab.deleted)
		setup()
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: tab)
		return PolicyManager(wrapper: wrapper)
	}

	static func manager(for url: URL?, in tab: Tab) -> PolicyManager {
		return manager(for: PolicyDomain(url: url), in: tab)
	}

	static func manager(for domain: PolicyDomain, in tab: Tab) -> PolicyManager {
		precondition(!tab.deleted)
		setup()
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: domain, inTab: tab)
		return PolicyManager(wrapper: wrapper)
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

	func webViewConfiguration(for manager: WebViewManager) -> WKWebViewConfiguration {
		let config = WKWebViewConfiguration()
		let userActionForMedia = bool(for: requiresUserActionForMediaPlaybackKey)
		config.allowsInlineMediaPlayback = bool(for: allowsInlineMediaPlaybackKey)
		config.ignoresViewportScaleLimits = bool(for: ignoresViewportScaleLimitsKey)
		config.mediaTypesRequiringUserActionForPlayback = userActionForMedia ? .all : []
		if manager.tab.useTor {
			let setDNT = bool(for: sendDNTHeaderOverTorKey)
			let blockDeprecatedTLS = bool(for: blockDeprecatedTLSKey)
			let handler = TorSchemeHandler(dnt: setDNT, blockDeprecatedTLS: blockDeprecatedTLS)
			handler.delegate = manager
			config.setURLSchemeHandler(handler, forURLScheme: "tor")
			config.setURLSchemeHandler(handler, forURLScheme: "tors")
		}
		return config
	}

	func urlSessionConfiguration(tabController: TabController?) -> URLSessionConfiguration? {
		let config = allowPermanentDataStorage ? URLSessionConfiguration.default : URLSessionConfiguration.ephemeral
		if tabController?.tab.useTor ?? useTor {
			guard let proxy = TorServer.shared.connectionProxyDictionary else {
				TorServer.shared.getURLSessionProxyConfig { _ in }
				return nil
			}
			config.connectionProxyDictionary = proxy
		}
		config.httpAdditionalHeaders = ["User-Agent": tabController?.userAgent ?? userAgent]
		return config
	}

	func awaitTorIfNecessary(for tab: Tab?, callback: @escaping (Bool) -> ()) {
		guard tab?.useTor ?? useTor else {
			callback(true)
			return
		}
		TorServer.shared.start { error in
			guard error == nil else {
				callback(false)
				return
			}
			TorServer.shared.getURLSessionProxyConfig { config in
				callback(config != nil)
			}
		}
	}

	func torifyIfNecessary(for tab: Tab, url: URL?) -> URL? {
		if let url = url, tab.useTor, url.canTorify {
			return url.torified
		} else {
			return nil
		}
	}

	var dataStore: (store: WKWebsiteDataStore, pool: WKProcessPool?) {
		struct LocaData {
			static let pool = WKProcessPool()
		}
		let store = allowPermanentDataStorage ? WKWebsiteDataStore.default() : WKWebsiteDataStore.nonPersistent()
		let pool = allowPermanentDataStorage && shareGlobalProcessPool ? LocaData.pool : nil
		return (store, pool)
	}

	var useTor: Bool {
		return bool(for: useTorNetworkKey)
	}

	var useTorForAPICalls: Bool {
		return bool(for: useTorForAPICallsKey)
	}

	var rotateCircuitForNewTokens: Bool {
		return bool(for: rotateCircuitForNewTokensKey)
	}

	var shareGlobalProcessPool: Bool {
		return !bool(for: strictTabGroupSeparationKey)
	}

	var allowJS: Bool {
		return bool(for: allowJavaScriptKey)
	}

	var allowJSURLsInURLBar: Bool {
		return bool(for: allowJSURLsInURLBarKey)
	}

	var allowPWManager: Bool {
		return bool(for: allowPasswordManagerIntegrationKey)
	}

	var trust: Bool {
		return bool(for: trustedSiteKey)
	}

	var trustedSiteUpdateRequired: Bool {
		return trust && bool(for: requireHTTPSForTrustedSitesKey)
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
		return !deleteSiteLists && ((lastUpdate < compilationDate) || (SubscriptionManager.status.confirmed && lastUpdate.timeIntervalSinceNow < -7 * 24 * 60 * 60))
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

	var homepageURL: URL? {
		guard let text = settingsWrapper.value(for: homepageURLKey).text else {
			return nil
		}
		return URL(string: text)
	}

	var hasHomePage: Bool {
		return settingsWrapper.value(for: homepageURLKey).text != nil
	}

	var minFontSize: CGFloat {
		let data = settingsWrapper.value(for: minFontSizeKey)
		let value = data.floatValue!
		return CGFloat(value)
	}

	var webContentScale: CGFloat {
		let data = settingsWrapper.value(for: webContentScaleKey)
		let value = data.integer!
		return CGFloat(value) / CGFloat(scaleStorageFactor)
	}

	var previewDelay: TimeInterval {
		return settingsWrapper.value(for: previewDelayKey).float!
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

	var allowCloseAllTabs: Bool {
		return bool(for: allowCloseAllTabsKey)
	}

	/**
	 *	Is not guarantied to return the same user agent even on multiple calls to same PolicyManager object
	 */
	var userAgent: String {
		let agentTypes = UserAgent.decode(settingsWrapper.value(for: userAgentsKey).text!)
		return UserAgent(type: agentTypes.randomElement).string
	}

	var safebrowsing: Bool {
		return bool(for: safebrowsingEnabledKey)
	}

	var safebrowsingStorage: SafebrowsingStorage {
		guard safebrowsing else {
			return DummySafebrowsingStorage()
		}
		let id = settingsWrapper.value(for: safebrowsingCacheSharingKey).integer!
		switch SafebrowsingCacheSharing(rawValue: id)! {
			case .all:		return CachingSafebrowsingStorage()
			case .prefix:	return PrefixCachingSafebrowsingStorage()
			case .none:		return EphemeralSafebrowsingStorage()
		}
	}

	private struct Scripts {
		static let referrerBlocker = WKUserScript(source: JSGenerator.named("BlockReferrers")!.generate()!, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		static let nightMode = WKUserScript(source: JSGenerator.named("NightMode")!.generate()!, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		static let canvasProtection = WKUserScript(source: JSGenerator.named("CanvasProtection")!.generate()!, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		static let fingerprintingProtection = WKUserScript(source: JSGenerator.named("FingerprintingProtection")!.generate()!, injectionTime: .atDocumentStart, forMainFrameOnly: false)
		static let readerMode = WKUserScript(source: JSGenerator.named("ReaderMode")!.generate()!, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
	}
	func userScripts(with securityCookie: String, for tab: Tab) -> [WKUserScript] {
		guard allowApplicationJS else {
			return []
		}
		var ret = [WKUserScript]()
		if bool(for: blockHTTPReferrersKey) {
			ret.append(Scripts.referrerBlocker)
		}
		if isInNightMode {
			ret.append(Scripts.nightMode)
		}
		if bool(for: blockCanvasDataAccessKey) {
			ret.append(Scripts.canvasProtection)
		}
		if bool(for: blockFingerprintingKey) {
			ret.append(Scripts.fingerprintingProtection)
		}
		if isInReaderMode {
			ret.append(Scripts.readerMode)
		}
		if tab.useTor {
			let js = JSGenerator.named("TorifyURLs")!.generate()!
			ret.append(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
		}
		return ret
	}

	func withEnabledContentRuleLists(for tab: Tab, do work: @escaping ([WKContentRuleList], [WKUserScript]) -> ()) {
		assert(ContentTypes.allTypes == [.document, .image, .styleSheet, .script, .font, .raw, .svgDocument, .media, .popup, .thirdPartyScripts])
		let blockAds = self.blockAds
		let blockTrackingScripts = self.blockTrackingScripts
		let blockSocialMediaWidgets = bool(for: blockSocialMediaWidgetsKey)
		let applyHideOnly = bool(for: applyHideOnlyBlockRulesKey)
		let rawType = settingsWrapper.value(for: contentTypeBlockerBlockedTypesKey).integer!
		let blockedTypes = ContentTypes(rawValue: rawType)
		let blockMixedContent = self.blockMixedContent
		let extendedHstsPreload = self.useHTTPSExclusivelyWhenPossible
		let httpsOnly = bool(for: upgradeAllHTTPKey)
		let cookieBlockingPolicy = CookieBlockingPolicy(rawValue: settingsWrapper.value(for: cookieBlockingPolicyKey).integer!)!
		let applicationJS = allowApplicationJS
		let tor = tab.useTor
		let blockDOH = bool(for: blockDOHServersKey)

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
			if extendedHstsPreload {
				if let blocker = allBlockers[BlockerID.hstsPreloadUpgrader1] {
					blockers.append(blocker)
				} else {
					print("hsts preload upgrader 1 not available")
				}
				if let blocker = allBlockers[BlockerID.hstsPreloadUpgrader2] {
					blockers.append(blocker)
				} else {
					print("hsts preload upgrader 2 not available")
				}
				if let blocker = allBlockers[BlockerID.hstsPreloadUpgrader3] {
					blockers.append(blocker)
				} else {
					print("hsts preload upgrader 3 not available")
				}
				if let blocker = allBlockers[BlockerID.hstsPreloadUpgrader4] {
					blockers.append(blocker)
				} else {
					print("hsts preload upgrader 4 not available")
				}
			}
			if httpsOnly {
				if let blocker = allBlockers[BlockerID.httpsOnlyContentBlocker] {
					blockers.append(blocker)
				} else {
					print("all http upgrader not available")
				}
			}
			if blockDOH {
				if let blocker = allBlockers[BlockerID.dohServerBlocker] {
					blockers.append(blocker)
				} else {
					print("doh blocker not available")
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

			if tor {
				// TODO: consider leaving in place instead of removing & readding this particularly important one
				// in this case, crash rather than continue if something went wrong
				blockers.append(allBlockers[BlockerID.nonTorURLsBlocker]!)
			}

			work(blockers, applicationJS ? replacementScripts : [])
		}
	}

	var blockDeprecatedTLS: Bool {
		return bool(for: blockDeprecatedTLSKey)
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

	var warnCrossFrameNavigation: Bool {
		return bool(for: warnCrossFrameNavigationKey)
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

	var renderAsDesktopSite: Bool {
		return bool(for: renderAsDesktopSiteKey)
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
		guard bool(for: forgetPrivateSitesKey), !isSuppressingHistory else {
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

	func performLaunchOperations() {
		struct LocalData {
			static var performed = false
		}
		assert(Thread.isMainThread && !LocalData.performed)
		LocalData.performed = true
		if bool(for: startTorOnAppLaunchKey) {
			TorServer.shared.start { _ in }
		}
	}

	func updateEOLWarningVersion() {
		settingsWrapper.set(.integer(currentVersion), for: lastEOLWarningVersionKey)
	}

	func suggestionSources(for tab: Tab) -> [SuggestionSource] {
		let localSources: [SuggestionSource] = [
			HistorySuggestionSource(),
			BookmarkSuggestionSource(),
			PopularSitesSuggestionSource(includePrivate: bool(for: suggestPrivateSitesKey), tab: tab),
			HomeSuggestionSource()
		]
		let encoded = settingsWrapper.value(for: searchSuggestionEnginesKey).text!
		let engines = SearchEngine.decode(encoded)
		let engineSources: [SuggestionSource] = engines.map {
			SearchEngineSuggestionSource(engine: SearchEngine(type: $0), tab: tab)
		}
		return (bool(for: showLocalSiteSuggestionsKey) ? localSources : []) + engineSources
	}

	static func customSearchTemplate(for query: String) -> Templating? {
		guard let escaped = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
			return nil
		}
		var template = Templating()
		template.add("@@") { _ in return "@" }
		template.add("@query@") { _ in return escaped }
		return template
	}

	func customSearchURL(for query: String) -> URL? {
		guard let template = PolicyManager.customSearchTemplate(for: query) else {
			return nil
		}
		let text = settingsWrapper.value(for: customSearchURLKey).text!
		return try? URL(string: template.apply(to: text))
	}

	func customSearchSuggestionParams(for query: String) -> (URL, JSONPath)? {
		guard let template = PolicyManager.customSearchTemplate(for: query) else {
			return nil
		}
		let text = settingsWrapper.value(for: customSearchURLKey).text!
		guard let url = try? URL(string: template.apply(to: text)) else {
			return nil
		}
		guard let path = try? JSONPath(settingsWrapper.value(for: customSearchSuggestionsJSONPathKey).text!) else {
			return nil
		}
		return (url, path)
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
		case load(URL, upgraded: Bool)
	}
	func actionList(for userInput: String, in tab: Tab) -> [Action] {
		let httpsSites = DomainList(type: useHTTPSExclusivelyWhenPossible ? .httpsSites : .empty)
		func enfoceHTTPS(for url: URL) -> Bool {
			if httpsSites.contains(url.host!) {
				return true
			}
			let policy = PolicyManager.manager(for: url, in: tab)
			return policy.trustedSiteUpdateRequired
		}
		var ret = [Action]()
		if let url = userInput.punycodeURL {
			if url.normalizedScheme! == "http" && enfoceHTTPS(for: url) {
				var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
				components.scheme = "https"
				return [.load(components.url!, upgraded: true)]
			} else {
				return [.load(url, upgraded: false)]
			}
		}

		if let encoded = userInput.punycodeExtension {
			var httpsFirst = bool(for: tryHTTPSfirstKey)
			var https = [Action]()

			if let url = encoded.extendToURL(https: true, www: false) {
				httpsFirst = httpsFirst && !url.isOnion
				let upgraded = httpsFirst || enfoceHTTPS(for: url)
				https.append(.load(url, upgraded: upgraded))
			}
			if let url = encoded.extendToURL(https: true, www: true), !encoded.hasWPrefix {
				let upgraded = httpsFirst || enfoceHTTPS(for: url)
				if !url.isOnion {
					https.append(.load(url, upgraded: https.isEmpty && upgraded))
				}
			}
			var http = [Action]()
			if let url = encoded.extendToURL(https: false, www: false) {
				if !enfoceHTTPS(for: url) {
					http.append(.load(url, upgraded: false))
				}
			}
			if let url = encoded.extendToURL(https: false, www: true), !encoded.hasWPrefix {
				if !enfoceHTTPS(for: url) && !url.isOnion {
					http.append(.load(url, upgraded: false))
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
		if let url = engine.url(for: userInput, using: self) {
			ret.append(.load(url, upgraded: false))
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

	func dangerReasons(for url: URL?, in tabController: TabController, callback: @escaping (Set<Safebrowsing.Danger>) -> ()) {
		guard bool(for: showDangerousSitesWarningsKey), let url = url else {
			callback([])
			return
		}
		let hardFail = bool(for: safebrowsingHardFailKey)
		let networking: SafebrowsingNetworking
		if !safebrowsing {
			networking = DummySafebrowsingNetworking()
		} else if let config = urlSessionConfiguration(tabController: tabController) {
			if bool(for: safebrowsingProxyKey) {
				networking = ProxySafebrowsingNetworking(configuration: config, rotateCredentials: rotateCircuitForNewTokens)
			} else {
				networking = GoogleSafebrowsingNetworking(configuration: config, tab: tabController.tab)
			}
		} else {
			callback(hardFail ? [.networkIssue] : [])
			return
		}
		let hasSubscription = SubscriptionManager.status.confirmed
		let sb = Safebrowsing(network: networking, storage: tabController.safebrowsingStorage, local: true, softFail: !hardFail, hasSubscription: hasSubscription)
		sb.types(for: url, callback: callback)
	}

	var updateSafebrowsing: Safebrowsing? {
		guard let config = urlSessionConfiguration(tabController: nil), SubscriptionManager.status.confirmed else {
			return nil
		}
		let networking: SafebrowsingNetworking
		if bool(for: safebrowsingProxyKey) {
			networking = ProxySafebrowsingNetworking(configuration: config, rotateCredentials: rotateCircuitForNewTokens)
		} else {
			networking = GoogleSafebrowsingNetworking(configuration: config, tab: nil)
		}
		let storage = CachingSafebrowsingStorage()
		return Safebrowsing(network: networking, storage: storage, local: false, softFail: false, hasSubscription: true)
	}
}

struct PolicyDomain {
	public static let aboutBlankURL = "about:blank" // is also used in DB migration
	private static let dataURIPseudoDomain = "data:uri"
	public static let missingHostPseudoDomain = "missing:host" // is also used in DB migration
	private static let aboutBlankURLS = [aboutBlankURL, aboutBlankURL + "%23", aboutBlankURL + "%23moreInformation"]

	let domain: String

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
		return url.normalizedScheme == "data" && url.host == nil
	}

	init(url: URL?) {
		if PolicyDomain.isAboutBlank(url) {
			domain = PolicyDomain.aboutBlankURL
		} else if PolicyDomain.isNormalDataURI(url) {
			domain = PolicyDomain.dataURIPseudoDomain
		} else if let host = url?.host {
			domain = host.replacingOccurrences(of: ":", with: "::")
		} else {
			domain = PolicyDomain.missingHostPseudoDomain
		}
	}

	init(host: String?) {
		if let host = host?.lowercased() {
			domain = host.replacingOccurrences(of: ":", with: "::")
		} else {
			domain = PolicyDomain.missingHostPseudoDomain
		}
	}

	var isAboutBlank: Bool {
		return domain == PolicyDomain.aboutBlankURL
	}

	var isNormalDataURI: Bool {
		return domain == PolicyDomain.dataURIPseudoDomain
	}
}

// internals
extension PolicyManager {
	private static func setup() {
		if !globalSetupPerformed {
			SettingsDefaultWrapper.standardDefaults = defaults
			globalSetupPerformed = true
		}
	}

	private func bool(for key: String) -> Bool {
		return settingsWrapper.value(for: key).boolValue
	}
}
