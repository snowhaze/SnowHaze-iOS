//
//  PageInformationOverview.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private class IconView: UIView {
	var indicate: Bool = false {
		didSet {
			icon.layer.borderWidth = indicate ? 2 : 0
		}
	}

	private let icon: UIButton

	override var intrinsicContentSize: CGSize {
		return CGSize(width: 40, height: 40)
	}

	func addTarget(_ target: Any, action: Selector) {
		icon.addTarget(target, action: action, for: .touchUpInside)
	}

	init(image: UIImage) {
		icon = UIButton(type: .system)
		super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
		icon.layer.borderWidth = 0
		icon.frame = bounds
		let noTemplate = image.withRenderingMode(.alwaysOriginal)
		icon.setImage(noTemplate, for: [])
		icon.layer.cornerRadius = 5
		icon.layer.borderColor = UIColor.button.cgColor
		icon.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
		addSubview(icon)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PageInformationOverview: UIView {
	private var parrent: PageInformationView? {
		return superview as? PageInformationView
	}

	private enum IconType: Equatable {
		case trusted
		case tor
		case https
		case http
		case mixed
		case ev(String)

		var icon: UIImage {
			switch self {
				case .trusted:	return #imageLiteral(resourceName: "pageinfo_trusted")
				case .tor:		return #imageLiteral(resourceName: "pageinfo_tor")
				case .https:	return #imageLiteral(resourceName: "pageinfo_https")
				case .http:		return #imageLiteral(resourceName: "pageinfo_http")
				case .mixed:	return #imageLiteral(resourceName: "pageinfo_mixed_content")
				case .ev:		return #imageLiteral(resourceName: "pageinfo_ev")
			}
		}

		var explanation: String {
			switch self {
				case .trusted:		return NSLocalizedString("page information trusted site explanation", comment: "explanation displayed when the user tabs the trusted site icon in the page information")
				case .tor:			return NSLocalizedString("page information tor explanation", comment: "explanation displayed when the user tabs the tor icon in the page information")
				case .https:		return NSLocalizedString("page information https explanation", comment: "explanation displayed when the user tabs the https icon in the page information")
				case .http:			return NSLocalizedString("page information http explanation", comment: "explanation displayed when the user tabs the http icon in the page information")
				case .mixed:		return NSLocalizedString("page information mixed content explanation", comment: "explanation displayed when the user tabs the mixed content icon in the page information")
				case .ev(let org):	let format = NSLocalizedString("page information extended validation https explanation format", comment: "format for the explanation displayed when the user tabs the extended validation https icon in the page information")
									return String(format: format, org)
			}
		}

		func detailsAvailable(for tab: Tab) -> Bool {
			switch self {
				case .trusted:	return false
				case .tor:		return tab.torProxyCredentials != nil
				case .https:	return tab.controller?.serverTrust != nil
				case .http:		return false
				case .mixed:	return tab.controller?.serverTrust != nil
				case .ev:		return tab.controller?.serverTrust != nil
			}
		}

		static func ==(_ lhs: IconType, rhs: IconType) -> Bool {
			switch (lhs, rhs) {
				case (.trusted, .trusted):				return true
				case (.tor, .tor):						return true
				case (.https, .https):					return true
				case (.http, .http):					return true
				case (.mixed, .mixed):					return true
				case (.ev(let org1), .ev(let org2)):	return org1 == org2
				default:								return false
			}
		}

		func details(for tab: Tab, host: String?) -> UIView? {
			if case .tor = self {
				guard let creds = tab.torProxyCredentials else {
					return nil
				}
				let service: String?
				if let host = host, host.lowercased().hasSuffix(".onion") {
					service = String(host[..<host.index(host.endIndex, offsetBy: -".onion".count)])
				} else {
					service = nil
				}
				return TorInfoView(user: creds.0, password: creds.1, service: service)
			}
			if let trust = tab.controller?.serverTrust {
				return TLSInfoView(sec: trust)
			}
			return nil
		}
	}

	private let scrollView = UIScrollView()
	private let url: URL
	private let tab: Tab

	private var views = [(UIView, CGFloat)]()

	private let settingsController: FastPageSettingsController

	private let icons = UIStackView(arrangedSubviews: [])
	private let detailsButton = UIButton(type: .system)
	private let explainLabel = UILabel()
	private var iconTypes = [IconType]()
	private var selectedIcon: IconType?

	override func layoutSubviews() {
		super.layoutSubviews()
		layout()
	}

	private func layout() {
		views.forEach { $0.0.removeFromSuperview() }
		var offset: CGFloat = 0
		for (view, height) in views {
			view.frame = CGRect(x: 0, y: offset, width: bounds.width, height: height)
			offset += height
			scrollView.addSubview(view)
		}
		scrollView.contentSize = CGSize(width: bounds.width, height: offset)
	}

	init(url: URL, tab: Tab) {
		self.url = url
		self.tab = tab
		let policyDomain = PolicyDomain(url: url)
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: policyDomain, inTab: tab)
		self.settingsController = FastPageSettingsController(wrapper: wrapper)
		super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 300))

		let domain = UILabel()
		domain.textAlignment = .center
		domain.text = host
		domain.lineBreakMode = .byTruncatingHead
		domain.textColor = .darkTitle
		views.append((domain, 30))

		icons.distribution = .fillEqually
		views.append((icons, 40))

		explainLabel.textAlignment = .center
		explainLabel.textColor = .darkTitle
		views.append((explainLabel, 30))

		let detailsTitle = NSLocalizedString("page information view details button title", comment: "title of details button in page information view")
		detailsButton.setTitle(detailsTitle, for: [])
		detailsButton.titleLabel?.textAlignment = .center
		detailsButton.tintColor = .button
		detailsButton.addTarget(self, action: #selector(showDetails(_:)), for: .touchUpInside)
		views.append((detailsButton, 30))

		let moreTitle = NSLocalizedString("page information view more settings button title", comment: "title of more settings button in page information view")
		let more = UIButton(type: .system)
		more.setTitle(moreTitle, for: [])
		more.addTarget(self, action: #selector(showFullSettings(_:)), for: .touchUpInside)
		more.titleLabel?.textAlignment = .center
		more.setTitleColor(.button, for: [])
		views.append((more, 40))

		settingsController.callback = { [weak self] settings, temporary in
			self?.parrent?.complete(settings: settings, temporary: temporary)
		}
		let settings = LocalSettingsView(controller: settingsController)
		views.append((settings, 130))

		scrollView.frame = bounds
		addSubview(scrollView)
		scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

		layout()
		reloadIcons()
	}

	private func reloadIcons() {
		for view in icons.arrangedSubviews {
			icons.removeArrangedSubview(view)
			view.removeFromSuperview()
		}
		iconTypes = []
		let policy = PolicyManager.manager(for: url, in: tab)
		if policy.trust {
			iconTypes.append(.trusted)
		}
		if tab.useTor {
			iconTypes.append(.tor)
		}
		switch tab.tlsStatus {
			case .http: 		iconTypes.append(.http)
			case .mixed:		iconTypes.append(.mixed)
			case .other:		break
			case .secure:		iconTypes.append(.https)
			case .ev(let org):	iconTypes.append(.ev(org))
		}
		explainLabel.text = NSLocalizedString("page settings tap icon title", comment: "title of the request to tap icon for more information")
		detailsButton.isEnabled = false
		for type in iconTypes {
			let icon = IconView(image: type.icon)
			icon.addTarget(self, action: #selector(iconTaped(_:)))
			icons.addArrangedSubview(icon)
		}
		if let selected = selectedIcon {
			setSelectedIcon(iconTypes.firstIndex(of: selected))
		} else {
			setSelectedIcon(nil)
		}
	}

	private var host: String {
		if PolicyDomain.isAboutBlank(url) {
			return NSLocalizedString("page settings blank page description", comment: "displayed instead of domain name if the current page is an about:blank in page settings")
		} else if PolicyDomain.isNormalDataURI(url) {
			return NSLocalizedString("page settings data uris description", comment: "displayed instead of domain name if the current page is a data URI in page settings")
		}
		let thisPage = NSLocalizedString("page settings domain name placeholder", comment: "displayed instead of domain name if url.host is nil in page settings")
		return url.host?.localizedLowercase ?? thisPage
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setSelectedIcon(_ index: Int?) {
		for icon in icons.arrangedSubviews {
			(icon as? IconView)?.indicate = false
		}
		guard let index = index else {
			selectedIcon = nil
			explainLabel.text = NSLocalizedString("page settings tap icon title", comment: "title of the request to tap icon for more information")
			detailsButton.isEnabled = false
			return
		}
		let type = iconTypes[index]
		explainLabel.text = type.explanation
		detailsButton.isEnabled = type.detailsAvailable(for: tab)
		selectedIcon = type
		(icons.arrangedSubviews[index] as? IconView)?.indicate = true
	}

	@objc private func iconTaped(_ sender: UIButton) {
		if let superview = sender.superview {
			setSelectedIcon(icons.arrangedSubviews.firstIndex(of: superview))
		}
	}

	@objc private func showDetails(_ sender: UIButton) {
		if let details = selectedIcon?.details(for: tab, host: url.host) {
			parrent?.push(details)
		} else {
			reloadIcons()
		}
	}

	@objc private func showFullSettings(_ sender: UIButton) {
		let policyDomain = PolicyDomain(url: url)
		let wrapper = SettingsDefaultWrapper.wrapSettings(for: policyDomain, inTab: tab)
		let override = OverrideSettingsDefaultWrapper(wrapper: wrapper, prioritySettings: settingsController.settings)
		let controller = PageSettingsController(wrapper: override)
		controller.url = url
		controller.callback = { [weak self] settings, temp in
			guard let self = self else {
				return
			}
			var merged = self.settingsController.settings
			for (key, value) in settings {
				merged[key] = value
			}
			self.parrent?.complete(settings: merged, temporary: temp)
		}
		let view = LocalSettingsView(controller: controller)
		parrent?.push(view)
	}
}
