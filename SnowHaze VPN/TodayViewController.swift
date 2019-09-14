//
//  TodayViewController.swift
//  SnowHaze VPN
//

//  Copyright © 2018 Benjamin Andris Suter-Dörig. All rights reserved.
//

import UIKit
import NotificationCenter
import NetworkExtension

class TodayViewController: UIViewController, NCWidgetProviding {
	@IBOutlet weak var flagImageView: UIImageView!
	@IBOutlet weak var connectSwitch: UISwitch!
	@IBOutlet weak var connectionStatusLabel: UILabel!
	@IBOutlet weak var locationLabel: UILabel!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var switchButton: UIButton!
	@IBOutlet weak var rotateButton: UIButton!
	@IBOutlet weak var infoButton: UIButton!
	
	private var observer: NSObjectProtocol?
	private var vpnManagerLoaded = false
	private var performWithLoadedVPNManager: [() -> Void]?

	private var timer: Timer?

	override func viewDidLoad() {
		super.viewDidLoad()
		let name = NSNotification.Name.NEVPNStatusDidChange
		observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
			DispatchQueue.main.async {
				self?.updateStatus()
			}
		}
		if !vpnManagerLoaded {
			withLoadedManager { _ in }
		}
		let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(flagTapped(_:)))
		flagImageView.addGestureRecognizer(tapRecognizer)
		flagImageView.isUserInteractionEnabled = true
		updateStatus()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		view.bounds.origin = CGPoint.zero
		layout(for: view.bounds.size)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
		updateStatus()
		completionHandler(NCUpdateResult.newData)
	}

	@objc private func flagTapped(_ sender: UITapGestureRecognizer) {
		if !enabled {
			self.extensionContext?.open(URL(string: "shc://?open-setting=subscription")!, completionHandler: nil)
		}
	}

	@objc private func updateStatus() {
		connectSwitch.isOn = connected
		connectionStatusLabel.text = connectionStatus
		locationLabel.text = location
		connectSwitch.isEnabled = enabled
		connectSwitch.alpha = enabled ? 1 : 0.5
		flagImageView.image = flag
		let format = NSLocalizedString("flag accessibbility label format", comment: "format of the accessibbility label for the ipsec location flag")
		flagImageView.accessibilityLabel = String(format: format, location)
		flagImageView.isAccessibilityElement = true
		if fullyConnected && timer == nil {
			timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(TodayViewController.updateStatus), userInfo: nil, repeats: true)
		} else if !fullyConnected && timer != nil {
			timer?.invalidate()
			timer = nil
		}
		if isTemporayStatus {
			activityIndicator.startAnimating()
		} else {
			activityIndicator.stopAnimating()
		}
	}

	private var location: String {
		guard let config = NEVPNManager.shared().protocolConfiguration else {
			return NSLocalizedString("none ipsec location name", comment: "indication that no vpn location is selected")
		}
		switch config.serverAddress {
			case "au1.shvpn.ch":	return NSLocalizedString("australia ipsec location name", comment: "indication that australia is selected as ipsec vpn location")
			case "ca1.shvpn.ch":	return NSLocalizedString("canada ipsec location name", comment: "indication that canada is selected as ipsec vpn location")
			case "ch1.shvpn.ch":	return NSLocalizedString("switzerland ipsec location name", comment: "indication that switzerland is selected as ipsec vpn location")
			case "de1.shvpn.ch":	return NSLocalizedString("germany ipsec location name", comment: "indication that germany is selected as ipsec vpn location")
			case "fr1.shvpn.ch":	return NSLocalizedString("france ipsec location name", comment: "indication that france is selected as ipsec vpn location")
			case "pl1.shvpn.ch":	return NSLocalizedString("poland ipsec location name", comment: "indication that poland is selected as ipsec vpn location")
			case "sg1.shvpn.ch":	return NSLocalizedString("singapore ipsec location name", comment: "indication that singapore is selected as ipsec vpn location")
			case "uk1.shvpn.ch":	return NSLocalizedString("uk ipsec location name", comment: "indication that uk is selected as ipsec vpn location")
			case "us1.shvpn.ch":	return NSLocalizedString("us ipsec location name", comment: "indication that us is selected as ipsec vpn location")
			default:				return NSLocalizedString("unknown ipsec location name", comment: "indication that the selected ipsec vpn location is unknown")
		}
	}

	private var connectionStatus: String {
		switch NEVPNManager.shared().connection.status {
			case .connected:
				if let date = NEVPNManager.shared().connection.connectedDate {
					let calendar = Calendar(identifier: .gregorian)
					let components = calendar.dateComponents([.second, .minute, .hour, .day], from: date, to: Date())
					guard let timeString = DateComponentsFormatter.localizedString(from: components, unitsStyle: .positional) else {
						return NSLocalizedString("error ipsec status", comment: "label for the error ipsec status")
					}
					let format = NSLocalizedString("connected ipsec status format", comment: "format for the label for the connected ipsec status")
					return String(format: format, timeString)
				} else {
					return NSLocalizedString("error ipsec status", comment: "label for the error ipsec status")
				}
			case .connecting:		return NSLocalizedString("connecting ipsec status", comment: "label for the connecting ipsec status")
			case .disconnected:		return NSLocalizedString("disconnected ipsec status", comment: "label for the disconnected ipsec status")
			case .disconnecting:	return NSLocalizedString("disconnecting ipsec status", comment: "label for the disconnecting ipsec status")
			case .invalid:			return NSLocalizedString("invalid ipsec status", comment: "label for the invalid ipsec status")
			case .reasserting:		return NSLocalizedString("reasserting ipsec status", comment: "label for the reasserting ipsec status")
			@unknown default:		return NSLocalizedString("unknown ipsec status", comment: "label for when the ipsec vpn is in a state added to ios after the compilation of the extension")
		}
	}

	private var flag: UIImage {
		guard let config = NEVPNManager.shared().protocolConfiguration, !(config.serverAddress?.isEmpty ?? true) else {
			return #imageLiteral(resourceName: "invalid_flag")
		}
		switch config.serverAddress {
			case "au1.shvpn.ch":	return #imageLiteral(resourceName: "australia_flag")
			case "ca1.shvpn.ch":	return #imageLiteral(resourceName: "canadian_flag")
			case "ch1.shvpn.ch":	return #imageLiteral(resourceName: "swiss_flag")
			case "de1.shvpn.ch":	return #imageLiteral(resourceName: "german_flag")
			case "fr1.shvpn.ch":	return #imageLiteral(resourceName: "french_flag")
			case "pl1.shvpn.ch":	return #imageLiteral(resourceName: "poland_flag")
			case "sg1.shvpn.ch":	return #imageLiteral(resourceName: "singapore_flag")
			case "uk1.shvpn.ch":	return #imageLiteral(resourceName: "uk_flag")
			case "us1.shvpn.ch":	return #imageLiteral(resourceName: "usa_flag")
			default:				return #imageLiteral(resourceName: "unknown_location")
		}
	}

	private var enabled: Bool {
		let manager = NEVPNManager.shared()
		guard !(manager.protocolConfiguration?.serverAddress ?? "").isEmpty else {
			return false
		}
		switch manager.connection.status {
			case .invalid:	return false
			default:		return true
		}
	}

	private var fullyConnected: Bool {
		switch NEVPNManager.shared().connection.status {
			case .connected:	return true
			default:			return false
		}
	}

	private var connected: Bool {
		switch NEVPNManager.shared().connection.status {
			case .connected:		return true
			case .connecting:		return true
			case .disconnected:		return false
			case .disconnecting:	return false
			case .invalid:			return false
			case .reasserting:		return true
			@unknown default:		return false
		}
	}

	private var isTemporayStatus: Bool {
		switch NEVPNManager.shared().connection.status {
			case .connected:		return false
			case .connecting:		return true
			case .disconnected:		return false
			case .disconnecting:	return true
			case .invalid:			return true
			case .reasserting:		return true
			@unknown default:		return true
		}
	}

	private func disconnect() {
		withLoadedManager { [weak self] reload in
			let manager = NEVPNManager.shared()

			// don't create a profile just to disconnect
			guard !(manager.protocolConfiguration?.serverAddress ?? "").isEmpty else {
				return
			}

			manager.isOnDemandEnabled = false
			self?.saveManager(with: reload) {
				NEVPNManager.shared().connection.stopVPNTunnel()
			}
		}
	}

	private func connect() {
		withLoadedManager { [weak self] reload in
			let vpnManager = NEVPNManager.shared()

			let ike = NEVPNProtocolIKEv2()
			ike.deadPeerDetectionRate = .none
			ike.enablePFS = true

			ike.ikeSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
			ike.ikeSecurityAssociationParameters.integrityAlgorithm = .SHA512
			ike.ikeSecurityAssociationParameters.diffieHellmanGroup = .group16

			ike.childSecurityAssociationParameters.encryptionAlgorithm = .algorithmAES256GCM
			ike.childSecurityAssociationParameters.integrityAlgorithm = .SHA512
			ike.childSecurityAssociationParameters.diffieHellmanGroup = .group16

			if #available(iOS 11.0, *) {
				ike.minimumTLSVersion = .version1_2
			}

			ike.disconnectOnSleep = false
			ike.authenticationMethod = .sharedSecret

			let alwaysConnect = NEOnDemandRuleConnect()
			alwaysConnect.interfaceTypeMatch = .any

			vpnManager.onDemandRules = [alwaysConnect]
			vpnManager.protocolConfiguration = ike
			vpnManager.isEnabled = true
			vpnManager.isOnDemandEnabled = true
			self?.saveManager(with: reload)
		}
	}

	private func saveManager(with reload: @escaping () -> Void, success: (() -> Void)? = nil) {
		NEVPNManager.shared().saveToPreferences { [weak self] err in
			if let error = err {
				let code = (error as NSError).code
				if (error as NSError).domain == "NEVPNErrorDomain", let vpnError = NEVPNError.Code(rawValue: code) {
					switch vpnError {
						case .configurationInvalid:
							fatalError("config invalid")
						case .configurationDisabled:
							fatalError("was not trying to connect")
						case .connectionFailed:
							fatalError("was not trying to connect")
						case .configurationStale:
							reload()
						case .configurationReadWriteFailed:
							fatalError("failed to save config")
						case .configurationUnknown:
							fatalError("unexpected error")
						@unknown default:
							fatalError("unsupported vpn error")
					}
				} else {
					fatalError("unexpected error domain \((error as NSError).domain), code \(code)")
				}
			} else {
				self?.loadVPNManager(completion: nil)
				success?()
			}
		}
	}

	@IBAction func connectToggled(_ sender: UISwitch) {
		if connected {
			disconnect()
		} else {
			try? NEVPNManager.shared().connection.startVPNTunnel()
		}
		sender.isOn = connected
	}

	@IBAction func rotateCredentials(_ sender: UIButton) {
		self.extensionContext?.open(URL(string: "shc://?rotate-ipsec-credentials")!, completionHandler: nil)
	}

	@IBAction func switchLocation(_ sender: UIButton) {
		self.extensionContext?.open(URL(string: "shc://?open-setting=vpn")!, completionHandler: nil)
	}

	@IBAction func explainRotation(_ sender: UIButton) {
		self.extensionContext?.open(URL(string: "shc://?open-setting=vpn&unfold-explanation")!, completionHandler: nil)
	}

	private func withLoadedManager(perform block: @escaping (@escaping ()->Void) -> Void) {
		var retryCount = 0
		let reload: () -> Void = { [weak self] in
			guard retryCount < 3 else {
				return
			}
			retryCount += 1
			self?.loadVPNManager {
				self?.withLoadedManager(perform: block)
			}
		}
		guard vpnManagerLoaded else {
			reload()
			return
		}
		block(reload)
	}

	private func loadVPNManager(completion: (() -> Void)? = nil) {
		guard performWithLoadedVPNManager == nil else {
			if let block = completion {
				performWithLoadedVPNManager!.append(block)
			}
			return
		}
		if let completion = completion {
			performWithLoadedVPNManager = [completion]
		} else {
			performWithLoadedVPNManager = []
		}
		NEVPNManager.shared().loadFromPreferences { [weak self] error in
			DispatchQueue.main.async {
				if let error = error {
					let code = (error as NSError).code
					if (error as NSError).domain == "NEVPNErrorDomain", let vpnError = NEVPNError.Code(rawValue: code) {
						switch vpnError {
							case .configurationInvalid:
								fatalError("config invalid")
							case .configurationDisabled:
								fatalError("was not trying to connect")
							case .connectionFailed:
								fatalError("was not trying to connect")
							case .configurationStale:
								fatalError("was trying to load config already")
							case .configurationReadWriteFailed:
								print("failed to load config")
							case .configurationUnknown:
								fatalError("unexpected error")
							@unknown default:
								fatalError("unsupported vpn error")

						}
					} else {
						fatalError("unexpected error domain \((error as NSError).domain), code \(code)")
					}
					self?.performWithLoadedVPNManager = nil
				} else {
					self?.vpnManagerLoaded = true
					self?.performWithLoadedVPNManager!.forEach { $0() }
					self?.performWithLoadedVPNManager = nil
				}
			}
		}
	}

	deinit {
		if let o = observer {
			NotificationCenter.default.removeObserver(o)
		}
	}

	private func layout(for size: CGSize) {
		let compact = size.width < 500
		let oneIfWide = CGFloat(compact ? 0 : 1)
		let statusHeight = 0.6 * size.height
		let buttonHeight = 0.4 * size.height
		let flagWidth = statusHeight
		let margin = CGFloat(10.0)
		let totalStatusMargins = (4 + oneIfWide) * margin
		let switchWidth = CGFloat(50.0)
		let locationWidth = oneIfWide * min(200, 0.45 * (size.width - totalStatusMargins - switchWidth - flagWidth))
		let statusWidth = min(230, size.width - locationWidth - totalStatusMargins - switchWidth - flagWidth)
		let additionalMargin = (size.width - statusWidth - locationWidth - totalStatusMargins - switchWidth - flagWidth) / (8 + oneIfWide)
		var x = margin + 4 * additionalMargin

		flagImageView.frame = CGRect(x: x, y: 0, width: flagWidth, height: statusHeight)
		x += margin + additionalMargin + flagWidth
		locationLabel.frame = CGRect(x: x, y: 0, width: locationWidth, height: statusHeight)
		locationLabel.isHidden = compact
		x += oneIfWide * (locationWidth + margin + additionalMargin)
		connectionStatusLabel.frame = CGRect(x: x, y: 0, width: statusWidth, height: statusHeight)
		x += margin + additionalMargin + statusWidth
		connectSwitch.center = CGPoint(x: x + switchWidth / 2, y: statusHeight / 2)
		activityIndicator.center = CGPoint(x: x - margin - min(10, additionalMargin) - activityIndicator.bounds.width / 2, y: statusHeight / 2)

		let totalButtonMargins = 3 * margin
		let buttonWidth = min(100, (size.width - totalButtonMargins) / 2)
		let additionalButtonMargin = (size.width - totalButtonMargins - 2 * buttonWidth) / 15
		let infoButtonWidth = min(buttonHeight, 35 + additionalButtonMargin)
		let rotateButtonWidth = buttonWidth - max(0, 30 - additionalButtonMargin * 7)

		x = margin + 7 * additionalButtonMargin
		switchButton.frame = CGRect(x: x, y: statusHeight, width: buttonWidth, height: buttonHeight)
		x += buttonWidth + margin + additionalButtonMargin
		rotateButton.frame = CGRect(x: x, y: statusHeight, width: rotateButtonWidth, height: buttonHeight)
		x += rotateButtonWidth
		infoButton.frame = CGRect(x: size.width - infoButtonWidth, y: statusHeight, width: infoButtonWidth, height: buttonHeight)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		layout(for: size)
	}
}
