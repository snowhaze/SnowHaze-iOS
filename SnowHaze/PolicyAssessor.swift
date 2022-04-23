//
//	PolicyAssessor.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

enum PolicyCategory: Equatable {
	case application
	case javaScript
	case searchEngine
	case websiteData
	case history
	case mediaPlayback
	case userAgent
	case tracking
	case https
	case appearance
	case popover
	case externalBookmarks
	case warnings
	case hidden
	case subscription
	case vpn
	case passcode
	case contentTypeBlocker
	case tor
	case safebrowsing
	// also update '==' and 'allCategories' below
}

func ==(cat1: PolicyCategory, cat2: PolicyCategory) -> Bool {
	switch (cat1, cat2) {
		case (.application, .application):					return true
		case (.javaScript, .javaScript):					return true
		case (.searchEngine, .searchEngine):				return true
		case (.websiteData, .websiteData):					return true
		case (.history, .history):							return true
		case (.mediaPlayback, .mediaPlayback):				return true
		case (.userAgent, .userAgent):						return true
		case (.tracking, .tracking):						return true
		case (.https, .https):								return true
		case (.appearance, .appearance):					return true
		case (.popover, .popover):							return true
		case (.externalBookmarks, .externalBookmarks):		return true
		case (.warnings, .warnings):						return true
		case (.hidden, .hidden):							return true
		case (.subscription, .subscription):				return true
		case (.vpn, .vpn):									return true
		case (.passcode, .passcode):						return true
		case (.contentTypeBlocker, .contentTypeBlocker):	return true
		case (.tor, .tor):									return true
		case (.safebrowsing, .safebrowsing):				return true
		default:											return false
	}
}

class PolicyAssessor {
	static let allCategories: [PolicyCategory] = [.application, .javaScript, .searchEngine, .websiteData, .history, .mediaPlayback, .userAgent, .tracking, .https, .appearance, .popover, .externalBookmarks, .warnings, .hidden, .subscription, .vpn, .passcode, .contentTypeBlocker, .tor, .safebrowsing]
	let wrapper: SettingsDefaultWrapper

	init(wrapper: SettingsDefaultWrapper) {
		self.wrapper = wrapper
	}

	func weight(for category: PolicyCategory) -> Double {
		switch category {
			case .application:			return 3
			case .javaScript:			return 6
			case .searchEngine:			return 4
			case .websiteData:			return 6
			case .history:				return 1
			case .mediaPlayback:		return 3
			case .userAgent:			return 2
			case .tracking:				return 6
			case .https:				return 3
			case .appearance:			return 1
			case .popover:				return 2
			case .externalBookmarks:	return 1
			case .warnings:				return 3
			case .hidden:				return 1
			case .subscription:			return 2
			case .vpn:					return 6
			case .passcode:				return 1
			case .contentTypeBlocker:	return 2
			case .tor:					return 7
			case .safebrowsing:			return 3
		}
	}

	private func integer(for key: String) -> Int64 {
		return wrapper.value(for: key).integer!
	}

	private func bool(for key: String) -> Bool {
		return wrapper.value(for: key).boolValue
	}

	private func double(for key: String) -> Double {
		return wrapper.value(for: key).float!
	}

	private func assessAppSettings() -> Double {
		var res = 0.1
		res += bool(for: suggestPrivateSitesKey) ? 0.1 : 0.0
		res += bool(for: showLocalSiteSuggestionsKey) ? 0.0 : 0.05
		let multiplier = bool(for: allowTabClosingUndoForAllTabsKey) ? 0.1 : 0.05
		let undoPenalty = double(for: tabClosingUndoTimeLimitKey) / 60 * multiplier
		res += double(for: previewDelayKey) / 60 * 0.2

		let maskRating: Double
		let raw = integer(for: tabMaskingRuleKey)
		switch TabMaskingRule(rawValue: raw)! {
			case .always: maskRating = 0.1
			case .whenPrivate: maskRating = 0.05
			case .never: maskRating = 0
		}
		res += bool(for: updateSiteListsKey) ? 0.2 : 0
		res += bool(for: updateUsageStatsKey) ? 0 : 0.05
		res += wrapper.value(for: homepageURLKey).text == nil ? 0.2 : 0
		return res - undoPenalty + maskRating
	}

	private func assessJavaScript() -> Double {
		let applicationJS = bool(for: allowApplicationJavaScriptKey)
		let generalJS = bool(for: allowJavaScriptKey)
		let pwManager = bool(for: allowPasswordManagerIntegrationKey)
		let jsURLs = bool(for: allowJSURLsInURLBarKey)
		var result = applicationJS ? 0.35 : 0
		if !generalJS {
			result += 0.3
		}
		if pwManager {
			result += 0.15
		}
		if !jsURLs {
			result += 0.2
		}
		return result
	}

	private func rate(searchEngine engine: SearchEngineType) -> Double {
		switch engine {
			case .bing:			return 0.3
			case .google:		return 0.2
			case .yahoo:		return 0.1
			case .wikipedia:	return 0.8
			case .wolframAlpha:	return 0.65
			case .ecosia:		return 0.35
			case .startpage:	return 0.8
			case .swisscows:	return 0.55
			case .duckDuckGo:	return 0.85
			case .qwant:		return 0.85
			case .custom:		return 0.25
			case .mojeek:		return 0.55
			case .none:			return 1
		}
	}

	private func assessSearchEngine() -> Double {
		let engineVal = integer(for: searchEngineKey)
		let engine = SearchEngineType(rawValue: engineVal) ?? .none
		var result = rate(searchEngine: engine)

		let encoded = wrapper.value(for: searchSuggestionEnginesKey).text!
		let suggestions = SearchEngine.decode(encoded)

		for suggestion in suggestions {
			result *= rate(searchEngine: suggestion)
		}
		return result.squareRoot()
	}

	private func assessWebsiteData() -> Double {
		var result = bool(for: allowPermanentDataStorageKey) ? 0 : 0.8
		let rawPolicy = integer(for: cookieBlockingPolicyKey)
		switch CookieBlockingPolicy(rawValue: rawPolicy)! {
			case .none:			result += 0
			case .thirdParty:	result += 0.1
			case .all:			result += 0.2
		}
		return result
	}

	private func assessUserAgent() -> Double {
		var result = 0.9
		let agents = UserAgent.decode(wrapper.value(for: userAgentsKey).text!)
		for agent in agents {
			switch agent {
				case .safariiPhone:		result *= 0.4
				case .chromeiPhone:		result *= 0.8
				case .firefoxiPhone:	result *= 0.7
				case .operaiPhone:		result *= 0.8

				case .safariiPad:		result *= 0.4
				case .chromeiPad:		result *= 0.8
				case .firefoxiPad:		result *= 0.7
				case .operaiPad:		result *= 0.8

				case .defaultAndroid:	result *= 0.9
				case .chromeAndroid:	result *= 0.9
				case .firefoxAndroid:	result *= 0.9
				case .operaAndroid:		result *= 0.95

				case .safariMac:		result *= 0.6
				case .chromeWindows:	result *= 0.8
				case .firefoxLinux:		result *= 0.8
			}
		}
		let isIPad = UIDevice.current.userInterfaceIdiom == .pad
		if bool(for: renderAsDesktopSiteKey) != isIPad {
			result += 0.1
		}
		return 1 - result
	}

	private func assessHistory() -> Double {
		let history = bool(for: saveHistoryKey)
		let privateSites = bool(for: forgetPrivateSitesKey)
		var result = history ? 0 : 0.6
		if privateSites {
			result += 0.4
		}
		return result
	}

	private func assessMediaPlayback() -> Double {
		let userInteraction = bool(for: requiresUserActionForMediaPlaybackKey)
		let inline = bool(for: allowsInlineMediaPlaybackKey)
		var result: Double = 0
		if userInteraction {
			result += 0.9
		}
		if inline {
			result += 0.1
		}
		return result
	}

	private func assessTracking() -> Double {
		let referer = bool(for: blockHTTPReferrersKey)
		let trackers = bool(for: blockTrackingScriptsKey)
		let adds = bool(for: blockAdsKey)
		let canvas = bool(for: blockCanvasDataAccessKey)
		let fingerprinting = bool(for: blockFingerprintingKey)
		let socialMedia = bool(for: blockSocialMediaWidgetsKey)
		let hiders = bool(for: applyHideOnlyBlockRulesKey)
		let redirects = bool(for: skipRedirectsKey)
		var result: Double = 0
		if referer {
			result += 0.1
		}
		if canvas {
			result += 0.15
		}
		if trackers {
			result += 0.2
		}
		if adds {
			result += 0.2
		}
		if fingerprinting {
			result += 0.15
		}
		if socialMedia {
			result += 0.1
		}
		if !hiders {
			result += 0.05
		}
		if !redirects {
			result += 0.05
		}
		return result
	}

	private func assessHTTPS() -> Double {
		let httpsFirst = bool(for: tryHTTPSfirstKey)
		let extendedHstsPreload = bool(for: useHTTPSExclusivelyWhenPossibleKey)
		let httpsOnly = bool(for: upgradeAllHTTPKey)
		let httpsOnTrusted = bool(for: requireHTTPSForTrustedSitesKey)
		let blockMixedContent = bool(for: blockMixedContentKey)
		let blockDeprecatedTLS = bool(for: blockDeprecatedTLSKey)
		var result = httpsFirst ? 0.25 : 0
		if extendedHstsPreload {
			result += 0.25
		}
		if httpsOnTrusted {
			result += 0.1
		}
		if blockMixedContent {
			result += 0.1
		}
		if httpsOnly {
			result += 0.2
		}
		if blockDeprecatedTLS {
			result += 0.1
		}
		return result
	}

	private func assessAppearance() -> Double {
		let nightMode = bool(for: nightModeKey)
		let minFontSize = double(for: minFontSizeKey)
		let ignoresViewportScaleLimits = bool(for: ignoresViewportScaleLimitsKey)
		let webContentScale = integer(for: webContentScaleKey)
		var result = nightMode ? 0 : 0.45
		result += 0.20 / (minFontSize * 0.1 + 1)
		var minReaderFontsize = double(for: minReaderFontSizeKey)
		if minReaderFontsize < 0 {
			minReaderFontsize = minFontSize
		}
		result += 0.5 / (minReaderFontsize * 0.1 + 1)
		result += ignoresViewportScaleLimits ? 0.0 : 0.1
		result += webContentScale == 1 * scaleStorageFactor ? 0.15 : 0
		return result
	}

	private func assessPopover() -> Double {
		let value = integer(for: popoverBlockingPolicyKey)
		let type = PopoverBlockingPolicyType(rawValue: value)!
		switch type {
			case .allwaysBlock:		return 1
			case .blockScripted:	return 0.8
			case .allwaysAllow:		return 0
		}
	}

	private func assessExternalBookmarks() -> Double {
		var result = 1.0
		if bool(for: indexBookmarksInSpotlightKey) {
			result -= 0.5
		}
		if bool(for: addBookmarkApplicationShortcutsKey) {
			result -= 0.5
		}
		return result
	}

	private func assessWarnings() -> Double {
		var result = 0.0
		if bool(for: showDangerousSitesWarningsKey) {
			result += 0.35
		}
		if bool(for: showTLSCertificateWarningsKey) {
			result += 0.1
		}
		if bool(for: stripTrackingURLParametersKey) {
			result += 0.25
		}
		if bool(for: preventXSSKey) {
			result += 0.2
		}
		if bool(for: warnCrossFrameNavigationKey) {
			result += 0.1
		}
		return result
	}

	private func assessHidden() -> Double {
		var result = bool(for: trustedSiteKey) ? 0.5 : 0
		result += bool(for: readerModeKey) ? 0 : 0.5
		return result
	}

	private func assessSubscription() -> Double {
		var result = bool(for: updateSubscriptionProductListKey) ? 0 : 0.1
		switch SubscriptionManager.status {
			case .confimed:	result += 0.7
			case .likely:	result += 0.4
			case .none:		break
		}
		result += bool(for: updateAuthorizationTokenKey) ? 0.2: 0
		return result
	}

	private func assessVPN() -> Double {
		let listUpdate = bool(for: updateVPNListKey) ? 0.3 : 0
		let hasIPSec = VPNManager.shared.ipsecConnected
		let hasOpenVPN = VPNManager.shared.currentOVPNInstalled
		let hasVPN = hasIPSec || hasOpenVPN
		let vpnResult = hasVPN ? 0.5 : 0
		let credsResult = bool(for: autorotateIPSecCredentialsKey) ? 0.2 : 0
		return listUpdate + vpnResult + credsResult
	}

	private func assessPasscode() -> Double {
		var result = 0.2 / sqrt(1 + double(for: passcodeLockAfterDurationKey) / 60)
		switch PasscodeManager.shared.mode {
			case .off:				result += 0
			case .pinOrBiometrics:	result += 0.4
			case .pinOnly:			result += 0.5
		}
		switch PasscodeManager.shared.type {
			case .digit6:		result += 0
			case .longDigit:	result += 0.1
			case .alphanumeric:	result += 0.2
		}
		return result
	}

	private func assessContentBlocker() -> Double {
		assert(ContentTypes.allTypes == [.document, .image, .styleSheet, .script, .font, .raw, .svgDocument, .media, .popup, .thirdPartyScripts])
		var result = 0.0
		let rawTypes = integer(for: contentTypeBlockerBlockedTypesKey)
		let types = ContentTypes(rawValue: rawTypes)
		result += types.contains(.image) ? 0.1 : 0
		result += types.contains(.styleSheet) ? 0.05 : 0
		result += types.contains(.script) ? 0.3 : 0
		result += types.contains(.font) ? 0.1 : 0
		result += types.contains(.raw) ? 0.15 : 0
		result += types.contains(.svgDocument) ? 0.05 : 0
		result += types.contains(.media) ? 0.1 : 0
		result += !types.contains(.script) && types.contains(.thirdPartyScripts) ? 0.15 : 0
		result += bool(for: blockDOHServersKey) ? 0.15 : 0
		return result
	}

	private func assessTor() -> Double {
		let use = bool(for: useTorNetworkKey) ? 0.75 : 0
		let launch = bool(for: startTorOnAppLaunchKey) ? 0 : 0.1
		let dnt = bool(for: sendDNTHeaderOverTorKey) ? 0 : 0.05
		let api = bool(for: useTorForAPICallsKey) ? 0.05 : 0
		let rotate = bool(for: rotateCircuitForNewTokensKey) ? 0.05 : 0
		return use + launch + dnt + api + rotate
	}

	private func assessSafebrowsing() -> Double {
		let cacheType = integer(for: safebrowsingCacheSharingKey)
		let cache: Double
		switch SafebrowsingCacheSharing(rawValue: cacheType)! {
			case .all:		cache = 0
			case .prefix:	cache = 0.2
			case .none:		cache = 0.3
		}
		let enabled = bool(for: safebrowsingEnabledKey) ? 0 : 0.1
		let proxy = bool(for: safebrowsingProxyKey) ? 0.4: 0
		let fail = bool(for: safebrowsingHardFailKey) ? 0.2: 0
		return enabled + cache + proxy + fail
	}

	private func assess(_ category: PolicyCategory) -> Double {
		switch category {
			case .application:			return assessAppSettings()
			case .javaScript:			return assessJavaScript()
			case .searchEngine:			return assessSearchEngine()
			case .websiteData:			return assessWebsiteData()
			case .history:				return assessHistory()
			case .mediaPlayback:		return assessMediaPlayback()
			case .userAgent:			return assessUserAgent()
			case .tracking:				return assessTracking()
			case .https:				return assessHTTPS()
			case .appearance:			return assessAppearance()
			case .popover:				return assessPopover()
			case .externalBookmarks:	return assessExternalBookmarks()
			case .warnings:				return assessWarnings()
			case .hidden:				return assessHidden()
			case .subscription:			return assessSubscription()
			case .vpn:					return assessVPN()
			case .passcode:				return assessPasscode()
			case .contentTypeBlocker:	return assessContentBlocker()
			case .tor:					return assessTor()
			case .safebrowsing:			return assessSafebrowsing()
		}
	}

	func assess(_ categories: [PolicyCategory]) -> PolicyAssessmentResult {
		var totalWeight: Double = 0
		var totalResult: Double = 0
		for category in categories {
			let weight = self.weight(for: category)
			let result = assess(category)
			totalWeight += weight
			totalResult += result * weight
		}
		let result = totalResult / totalWeight
		return PolicyAssessmentResult(result: result)
	}
}

enum PolicyAssessmentResultType {
	case veryGood
	case good
	case ok
	case passable
	case bad
	case veryBad
}

class PolicyAssessmentResult {
	let result: Double
	var type: PolicyAssessmentResultType {
		if result < 0.15 {
			return .veryBad
		} else if result < 0.35 {
			return .bad
		} else if result < 0.45 {
			return .passable
		} else if result < 0.55 {
			return .ok
		} else if result < 0.75 {
			return .good
		} else {
			return .veryGood
		}
	}

	var color: UIColor {
		return PolicyAssessmentResult.color(for: type)
	}

	var image: UIImage {
		return PolicyAssessmentResult.image(for: type)
	}

	var name: String {
		switch type {
			case .veryGood:	return NSLocalizedString("very good privacy assessment name", comment: "name of 'very good' privacy assessment")
			case .good:		return NSLocalizedString("good privacy assessment name", comment: "name of 'good' privacy assessment")
			case .ok:		return NSLocalizedString("ok privacy assessment name", comment: "name of 'ok' privacy assessment")
			case .passable:	return NSLocalizedString("passable privacy assessment name", comment: "name of 'passable' privacy assessment")
			case .bad:		return NSLocalizedString("bad privacy assessment name", comment: "name of 'bad' privacy assessment")
			case .veryBad:	return NSLocalizedString("very bad privacy assessment name", comment: "name of 'very bad' privacy assessment")
		}
	}

	static func color(for type: PolicyAssessmentResultType) -> UIColor {
		switch type {
			case .veryGood:	return .veryGoodPrivacy
			case .good:		return .goodPrivacy
			case .ok:		return .okPrivacy
			case .passable:	return .passablePrivacy
			case .bad:		return .badPrivacy
			case .veryBad:	return .veryBadPrivacy
		}
	}

	static func image(for type: PolicyAssessmentResultType) -> UIImage {
		switch type {
			case .veryGood, .good, .ok, .passable:	return #imageLiteral(resourceName: "good_sec_icon")
			case .bad, .veryBad:					return #imageLiteral(resourceName: "bad_sec_icon")
		}
	}

	fileprivate init(result: Double) {
		self.result = result
	}
}
