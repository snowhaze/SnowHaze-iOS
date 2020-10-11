//
//	LocalSettingsView.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class TabSettingsController: LocalSettingsController {
	override var numberOfSettings: Int {
		return SubscriptionManager.status.possible ? 8 : 7
	}

	override var title: String {
		return NSLocalizedString("tab settings title", comment: "title of tab settings popover")
	}

	override var buttonTitle: String {
		return NSLocalizedString("tab settings create tab button title", comment: "title of button to create tab in tab settings popover")
	}

	override func nameForSetting(at index: Int) -> String {
		switch index {
			case 0:		return NSLocalizedString("save website data setting title", comment: "title of save website data records setting")
			case 1:		return NSLocalizedString("save history setting title", comment: "title of save history setting")
			case 2:		return NSLocalizedString("night mode setting title", comment: "title of night mode setting")
			case 3:		return NSLocalizedString("show search suggestions tab settings title", comment: "title of settings in tab settings to enable / disable search suggestions")
			case 4:		return NSLocalizedString("allow javascript setting title", comment: "title of allow javascript setting")
			case 5:		return NSLocalizedString("desktop user agent tab setting title", comment: "title of tab setting to use desktop user agents")
			case 6:		return NSLocalizedString("ignore scale limits setting title", comment: "title of ignore scale limits setting")
			case 7:		return NSLocalizedString("use tor setting title", comment: "title of use tor setting")
			default:	fatalError("Invalid Index")
		}
	}

	override func keyForSetting(at index: Int) -> String {
		switch index {
			case 0:		return allowPermanentDataStorageKey
			case 1:		return saveHistoryKey
			case 2:		return nightModeKey
			case 3:		return searchSuggestionEnginesKey
			case 4:		return allowJavaScriptKey
			case 5:		return userAgentsKey
			case 6:		return ignoresViewportScaleLimitsKey
			case 7:		return useTorNetworkKey
			default:	fatalError("Invalid Index")
		}
	}

	override func mapToData(_ bool: Bool, for key: String) -> SQLite.Data {
		if key == searchSuggestionEnginesKey {
			let encoded = wrapper.value(for: searchSuggestionEnginesKey).text!
			let currentEngines = SearchEngine.decode(encoded)
			let engines: [SearchEngineType]
			if bool != currentEngines.isEmpty {
				engines = currentEngines
			} else if bool {
				let defaultEngineID = wrapper.value(for: searchEngineKey).integer!
				let mainEngine = SearchEngineType(rawValue: defaultEngineID) ?? .none
				if mainEngine == .none {
					engines = [.wikipedia, .wolframAlpha, .startpage]
				} else {
					engines = [mainEngine]
				}
			} else {
				engines = []
			}
			return .text(SearchEngine.encode(engines))
		} else if key == userAgentsKey {
			if bool {
				return .text(UserAgent.encode(UserAgent.desktopAgents))
			} else {
				return .text(UserAgent.encode(UserAgent.defaultUserAgentTypes))
			}
		} else {
			return super.mapToData(bool, for: key)
		}
	}

	override func mapToBool(_ data: SQLite.Data, for key: String) -> Bool {
		if key == searchSuggestionEnginesKey {
			let encoded = wrapper.value(for: searchSuggestionEnginesKey).text!
			return !SearchEngine.decode(encoded).isEmpty
		} else if key == userAgentsKey {
			return UserAgent.decode(data.text!).contains { $0.isDesktop }
		} else {
			return super.mapToBool(data, for: key)
		}
	}
}

class PageSettingsController: LocalSettingsController {
	override var numberOfSettings: Int {
		return 11
	}

	var url: URL?

	private var host: String {
		if PolicyDomain.isAboutBlank(url) {
			return NSLocalizedString("page settings blank page description", comment: "displayed instead of domain name if the current page is an about:blank in page settings")
		} else if PolicyDomain.isNormalDataURI(url) {
			return NSLocalizedString("page settings data uris description", comment: "displayed instead of domain name if the current page is a data URI in page settings")
		}
		let thisPage = NSLocalizedString("page settings domain name placeholder", comment: "displayed instead of domain name if url.host is nil in page settings")
		return url?.host?.localizedLowercase ?? thisPage
	}

	override var title: String {
		let format = NSLocalizedString("page settings title format", comment: "title format of page settings popover (format specifier for domain name)")
		return String(format: format, host)
	}

	override var buttonTitle: String {
		return NSLocalizedString("page settings apply button title", comment: "button of apply button of page settings")
	}

	override var tempButtonTitle: String? {
		return NSLocalizedString("temporary page settings button title", comment: "title of button to temporarily set a page setting")
	}

	override func nameForSetting(at index: Int) -> String {
		switch index {
			case 0:		return NSLocalizedString("allow javascript setting title", comment: "title of allow javascript setting")
			case 1:		return NSLocalizedString("block canvas data access setting title", comment: "title of block canvas data access setting")
			case 2:		return NSLocalizedString("block fingerprinting setting title", comment: "title of block fingerprinting setting")
			case 3:		return NSLocalizedString("save history setting title", comment: "title of save history setting")
			case 4:		return NSLocalizedString("block referer setting title", comment: "title of block referer setting")
			case 5:		return NSLocalizedString("block tracking scripts setting title", comment: "title of block tracking scripts setting")
			case 6:		return NSLocalizedString("allow popovers page setting title", comment: "title of page setting to allow popovers")
			case 7:		return NSLocalizedString("block ads setting title", comment: "title of block ads setting")
			case 8:		return NSLocalizedString("mark as trusted setting title", comment: "title of mark as trusted setting")
			case 9:		return NSLocalizedString("block social media widgets setting title", comment: "title of block social media widgets setting")
			case 10:	return NSLocalizedString("block cookies page setting title", comment: "title of page setting to block cookies")
			default:	fatalError("Invalid Index")
		}
	}

	override func keyForSetting(at index: Int) -> String {
		switch index {
			case 0:		return allowJavaScriptKey
			case 1:		return blockCanvasDataAccessKey
			case 2:		return blockFingerprintingKey
			case 3:		return saveHistoryKey
			case 4:		return blockHTTPReferrersKey
			case 5:		return blockTrackingScriptsKey
			case 6:		return popoverBlockingPolicyKey
			case 7:		return blockAdsKey
			case 8:		return trustedSiteKey
			case 9:		return blockSocialMediaWidgetsKey
			case 10:	return cookieBlockingPolicyKey
			default:	fatalError("Invalid Index")
		}
	}

	override func mapToData(_ bool: Bool, for key: String) -> SQLite.Data {
		if key == popoverBlockingPolicyKey {
			let policy = bool ? PopoverBlockingPolicyType.allwaysAllow : PopoverBlockingPolicyType.allwaysBlock
			let id = policy.rawValue
			return .integer(id)
		} else if key == cookieBlockingPolicyKey {
			let policy = bool ? CookieBlockingPolicy.all : CookieBlockingPolicy.none
			let id = policy.rawValue
			return .integer(id)
		} else {
			return super.mapToData(bool, for: key)
		}
	}

	override func mapToBool(_ data: SQLite.Data, for key: String) -> Bool {
		if key == popoverBlockingPolicyKey {
			let policy = PopoverBlockingPolicyType(rawValue: data.integer!)!
			return policy == PopoverBlockingPolicyType.allwaysAllow
		} else if key == cookieBlockingPolicyKey {
			let policy = CookieBlockingPolicy(rawValue: data.integer!)!
			if case .none = policy {
				return false
			} else {
				return true
			}
		} else {
			return super.mapToBool(data, for: key)
		}
	}
}

class FastPageSettingsController: LocalSettingsController {
	private let showJS: Bool

	override init(wrapper: SettingsDefaultWrapper) {
		showJS = !(wrapper.value(for: allowJavaScriptKey).bool ?? false)
		super.init(wrapper: wrapper)
	}

	override var title: String? {
		return nil
	}

	override var buttonTitle: String {
		return NSLocalizedString("page settings apply button title", comment: "button of apply button of page settings")
	}

	override var tempButtonTitle: String? {
		return NSLocalizedString("temporary page settings button title", comment: "title of button to temporarily set a page setting")
	}

	override var numberOfSettings: Int {
		return 2
	}

	override func keyForSetting(at index: Int) -> String {
		let index = index + (showJS ? 0 : 1)
		switch index {
			case 0:		return allowJavaScriptKey
			case 1:		return blockAdsKey
			case 2:		return trustedSiteKey
			default:	fatalError()
		}
	}

	override func nameForSetting(at index: Int) -> String {
		let index = index + (showJS ? 0 : 1)
		switch index {
			case 0:		return NSLocalizedString("allow javascript setting title", comment: "title of allow javascript setting")
			case 1:		return NSLocalizedString("block ads setting title", comment: "title of block ads setting")
			case 2:		return NSLocalizedString("mark as trusted setting title", comment: "title of mark as trusted setting")
			default:	fatalError()
		}
	}
}

class LocalSettingsController {
	let wrapper: SettingsDefaultWrapper

	init(wrapper: SettingsDefaultWrapper) {
		self.wrapper = wrapper
	}

	private(set) var settings: [String: SQLite.Data] = [:]

	var callback: (([String: SQLite.Data], Bool) -> ())?

	var numberOfSettings: Int {
		fatalError("LocalSettingsViewController is an abstract superclass")
	}

	var title: String? {
		fatalError("LocalSettingsViewController is an abstract superclass")
	}

	var buttonTitle: String {
		fatalError("LocalSettingsViewController is an abstract superclass")
	}

	var tempButtonTitle: String? {
		return nil
	}

	func nameForSetting(at index: Int) -> String {
		fatalError("LocalSettingsViewController is an abstract superclass")
	}

	func keyForSetting(at index: Int) -> String {
		fatalError("LocalSettingsViewController is an abstract superclass")
	}

	func mapToData(_ bool: Bool, for key: String) -> SQLite.Data {
		return .bool(bool)
	}

	func mapToBool(_ data: SQLite.Data, for key: String) -> Bool {
		return data.boolValue
	}

	fileprivate func didSet(value: Bool, atIndex index: Int) {
		let key = keyForSetting(at: index)
		let dataType: SQLite.Data = mapToData(value, for: key)
		settings[key] = dataType
	}

	fileprivate func value(at index: Int) -> Bool {
		let key = keyForSetting(at: index)
		if let value = settings[key] {
			return mapToBool(value, for: key)
		}
		return mapToBool(wrapper.value(for: key), for: key)
	}

	fileprivate func didFinishSetup(forTempSettings temporary: Bool) {
		callback?(settings, temporary)
	}

	fileprivate func policyAssessment() -> PolicyAssessmentResult {
		let tmpDefaults = OverrideSettingsDefaultWrapper(wrapper: wrapper, prioritySettings: settings)
		let assessor = PolicyAssessor(wrapper: tmpDefaults)
		let categories = PolicyAssessor.allCategories
		return assessor.assess(categories)
	}
}

class LocalSettingsView: UIView, UITableViewDelegate, UITableViewDataSource {
	let controller: LocalSettingsController

	private let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 30))
	private let tableView = UITableView(frame: CGRect(x: 0, y: 30, width: 300, height: 160), style: .plain)
	private let imageView = UIImageView(frame: CGRect(x: 270, y: 200, width: 20, height: 20))
	private let dissmissButton = UIButton(frame: CGRect(x: 20, y: 190, width: 240, height: 40))
	private let tempDissmissButton = UIButton(frame: CGRect(x: 140, y: 190, width: 120, height: 40))

	init(controller: LocalSettingsController) {
		self.controller = controller
		super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 230))

		label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		label.textColor = .localSettingsTitle
		label.text = controller.title
		label.textAlignment = .center
		label.lineBreakMode = .byTruncatingHead
		addSubview(label)

		tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.rowHeight = 44
		tableView.alwaysBounceVertical = false
		addSubview(tableView)

		if controller.title == nil {
			tableView.frame.origin.y -= 30
			tableView.frame.size.height += 30
		}

		dissmissButton.setTitle(controller.buttonTitle, for: [])
		dissmissButton.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
		dissmissButton.setTitleColor(.button, for: [])
		dissmissButton.addTarget(self, action: #selector(finishSetup(_:)), for: .touchUpInside)
		addSubview(dissmissButton)

		if let tempTitle = controller.tempButtonTitle {
			dissmissButton.frame.size.width = 120
			dissmissButton.autoresizingMask = [.flexibleTopMargin, .flexibleWidth, .flexibleRightMargin]

			tempDissmissButton.setTitle(tempTitle, for: [])
			tempDissmissButton.autoresizingMask = [.flexibleTopMargin, .flexibleWidth, .flexibleLeftMargin]
			tempDissmissButton.setTitleColor(.button, for: [])
			tempDissmissButton.addTarget(self, action: #selector(finishSetup(_:)), for: .touchUpInside)
			addSubview(tempDissmissButton)

			let separator = UIView(frame: CGRect(x: 139.5, y: 200, width: 1, height: 30))
			separator.layer.cornerRadius = 1
			separator.clipsToBounds = true
			separator.backgroundColor = .separator
			separator.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleRightMargin]
			addSubview(separator)
		}

		imageView.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin]
		imageView.contentMode = .scaleAspectFit
		addSubview(imageView)
		updateAssessment()

		bounds.size.height = tableView.rowHeight * CGFloat(controller.numberOfSettings) + bounds.size.height - tableView.frame.height
		bounds.size.width = 350
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return controller.numberOfSettings
	}

	func getCell(for tableView: UITableView) -> UITableViewCell {
		let id = "cell"
		if let cell = tableView.dequeueReusableCell(withIdentifier: id) {
			return cell
		}
		let cell = UITableViewCell(style: .default, reuseIdentifier: id)
		let uiSwitch = UISwitch()
		uiSwitch.tintColor = .switchOff
		uiSwitch.backgroundColor = .switchOff
		uiSwitch.onTintColor = .switchOn
		uiSwitch.thumbTintColor = .title
		uiSwitch.layer.cornerRadius = uiSwitch.bounds.height / 2
		uiSwitch.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
		cell.accessoryView = uiSwitch
		cell.backgroundColor = .clear
		cell.selectionStyle = .none
		return cell
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = getCell(for: tableView)
		let on = controller.value(at: indexPath.row)
		let uiSwitch = cell.accessoryView as? UISwitch
		uiSwitch?.tag = indexPath.row
		uiSwitch?.isOn = on
		cell.textLabel?.text = controller.nameForSetting(at: indexPath.row)
		cell.textLabel?.textColor = on ? .localSettingsOnSubtitle : .localSettingsOffSubtitle
		cell.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: false)
		guard let cell = tableView.cellForRow(at: indexPath) else {
			return
		}
		guard let uiSwitch = cell.accessoryView as? UISwitch else {
			return
		}
		uiSwitch.setOn(!uiSwitch.isOn, animated: true)
		switchValueChanged(uiSwitch)
	}

	@objc private func switchValueChanged(_ uiSwitch: UISwitch) {
		controller.didSet(value: uiSwitch.isOn, atIndex: uiSwitch.tag)
		let indexPath = IndexPath(row: uiSwitch.tag, section: 0)
		let cell = tableView.cellForRow(at: indexPath)
		let color = uiSwitch.isOn ? UIColor.localSettingsOnSubtitle : UIColor.localSettingsOffSubtitle
		UIView.animate(withDuration: 0.2, animations: {
			cell?.textLabel?.textColor = color
		})
		updateAssessment()
	}

	func flashScrollIndicator() {
		tableView.flashScrollIndicators()
	}

	@objc private func finishSetup(_ sender: UIButton) {
		controller.didFinishSetup(forTempSettings: sender == tempDissmissButton)
	}

	private func updateAssessment() {
		let result = controller.policyAssessment()
		let color = result.color
		let image = result.image.withRenderingMode(.alwaysTemplate)
		imageView.tintColor = color
		imageView.image = image
	}
}
