//
//	PolicyAssessor.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

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
		default:											return false
	}
}

class PolicyAssessor {
	static let allCategories: [PolicyCategory] = [.application, .javaScript, .searchEngine, .websiteData, .history, .mediaPlayback, .userAgent, .tracking, .https, .appearance, .popover, .externalBookmarks, .warnings, .hidden, .subscription, .vpn, .passcode, .contentTypeBlocker]
	let wrapper: SettingsDefaultWrapper

	init(wrapper: SettingsDefaultWrapper) {
		self.wrapper = wrapper
	}

	func weight(for category: PolicyCategory) -> Double {
		switch category {
			case .application:			return 3
			case .javaScript:			return 5
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
		var res = 0.2
		res += bool(for: suggestPrivateSitesKey) ? 0.1 : 0.0
		res += bool(for: showLocalSiteSuggestionsKey) ? 0.0 : 0.05
		let multiplier = bool(for: allowTabClosingUndoForAllTabsKey) ? 0.2 : 0.1
		let undoPenalty = double(for: tabClosingUndoTimeLimitKey) / 60 * multiplier

		let maskRating: Double
		let raw = integer(for: tabMaskingRuleKey)
		switch TabMaskingRule(rawValue: raw)! {
			case .always: maskRating = 0.15
			case .whenPrivate: maskRating = 0.1
			case .never: maskRating = 0
		}
		res += bool(for: updateSiteListsKey) ? 0.5 : 0
		return res - undoPenalty + maskRating
	}

	private func assessJavaScript() -> Double {
		let applicationJS = bool(for: allowApplicationJavaScriptKey)
		let generalJS = bool(for: allowJavaScriptKey)
		let pwManager = bool(for: allowPasswordManagerIntegrationKey)
		var result = applicationJS ? 0.45 : 0
		if !generalJS {
			result += 0.35
		}
		if pwManager {
			result += 0.2
		}
		return result
	}

	private func rate(searchEngine engine: SearchEngineType) -> Double {
		switch engine {
			case .bing:			return 0.3
			case .google:		return 0.2
			case .yahoo:		return 0.1
			case .wikipedia:	return 0.7
			case .wolframAlpha:	return 0.6
			case .ecosia:		return 0.3
			case .startpage:	return 0.8
			case .hulbee:		return 0.7
			case .duckDuckGo:	return 0.75
			case .snowhaze:		return 0.95
			case .none:			return 1
		}
	}

	private func assessSearchEngine() -> Double {
		let engineVal = integer(for: searchEngineKey)
		let engine = SearchEngineType(rawValue: engineVal)!
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
			}
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
		var result: Double = 0
		if referer {
			result += 0.1
		}
		if canvas {
			result += 0.15
		}
		if trackers {
			result += 0.25
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
		return result
	}

	private func assessHTTPS() -> Double {
		let httpsFirst = bool(for: tryHTTPSfirstKey)
		let httpsOnly = bool(for: useHTTPSExclusivelyWhenPossibleKey)
		let blockMixedContent = bool(for: blockMixedContentKey)
		var result = httpsFirst ? 0.3 : 0
		if httpsOnly {
			result += 0.6
		}
		if blockMixedContent {
			result += 0.1
		}
		return result
	}

	private func assessAppearance() -> Double {
		let nightMode = bool(for: nightModeKey)
		let minFontSize = double(for: minFontSizeKey)
		let ignoresViewportScaleLimits = bool(for: ignoresViewportScaleLimitsKey)
		var result = nightMode ? 0 : 0.6
		result += 0.3 / (minFontSize * 0.1 + 1)
		result += ignoresViewportScaleLimits ? 0.0 : 0.1
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
			result += 0.3
		}
		if bool(for: preventXSSKey) {
			result += 0.25
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
		result += SubscriptionManager.shared.hasSubscription ? 0.7 : 0
		result += bool(for: updateAuthorizationTokenKey) ? 0.2: 0
		return result
	}

	private func assessVPN() -> Double {
		let listUpdate = bool(for: updateVPNListKey) ? 0.3 : 0
		let hasIPSec = VPNManager.shared.ipsecConnected
		let hasOpenVPN = VPNManager.shared.currentOVPNInstalled
		let hasVPN = hasIPSec || hasOpenVPN
		return listUpdate + (hasVPN ? 0.7 : 0)
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

	private func assessContentTypeBlocker() -> Double {
		assert(ContentTypes.allTypes == [.document, .image, .styleSheet, .script, .font, .raw, .svgDocument, .media, .popup, .thirdPartyScripts])
		var result = 0.0
		let rawTypes = integer(for: contentTypeBlockerBlockedTypesKey)
		let types = ContentTypes(rawValue: rawTypes)
		result += types.contains(.image) ? 0.1 : 0
		result += types.contains(.styleSheet) ? 0.05 : 0
		result += types.contains(.script) ? 0.3 : 0
		result += types.contains(.font) ? 0.15 : 0
		result += types.contains(.raw) ? 0.2 : 0
		result += types.contains(.svgDocument) ? 0.05 : 0
		result += types.contains(.media) ? 0.15 : 0
		result += !types.contains(.script) && types.contains(.thirdPartyScripts) ? 0.15 : 0
		return result
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
			case .contentTypeBlocker:	return assessContentTypeBlocker()
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
		if result < 0.17 {
			return .veryBad
		} else if result < 0.33 {
			return .bad
		} else if result < 0.50 {
			return .passable
		} else if result < 0.67 {
			return .ok
		} else if result < 0.83 {
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
