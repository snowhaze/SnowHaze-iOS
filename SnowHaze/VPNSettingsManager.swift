//
//  VPNSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import NetworkExtension

private let listSection = 1

private let profileURL: URL = {
	let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("client.ovpn")
	return URL(fileURLWithPath: path)
}()

class VPNSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("vpn settings explanation", comment: "explanations of the vpn settings tab")
	}

	private var showList: Bool {
		return !VPNManager.shared.ovpnProfiles.isEmpty || !VPNManager.shared.ipsecProfiles.isEmpty
	}

	private var controlSection: Int {
		return showList ? 2 : 1
	}

	private var isIPSec = true

	private var downloading = Set<String>()
	private var downloadErrors = Set<String>()

	private static var docController: UIDocumentInteractionController?
	private static var sendingFile = false

	private static let dateFormatter: DateFormatter = {
		var formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		formatter.doesRelativeDateFormatting = true
		return formatter
	}()

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.vpn]).color
	}

	private var observer: NSObjectProtocol?

	override func setup() {
		super.setup()
		VPNManager.shared.delegate = self
		VPNManager.shared.ovpnProfiles.forEach { setupPinger(for: $0) }
		VPNManager.shared.ipsecProfiles.forEach { setupPinger(for: $0) }

		let name = NSNotification.Name.NEVPNStatusDidChange
		observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
			DispatchQueue.main.async {
				guard let me = self else {
					return
				}
				if me.isIPSec && me.showList {
					let indexPath = IndexPath(row: 0, section: listSection)
					me.controller.tableView.reloadRows(at: [indexPath], with: .none)
				}
			}
		}
		if !VPNManager.shared.ipsecManagerLoaded {
			VPNManager.shared.withLoadedManager { _ in }
		}
	}

	private var selectedProfileIndex: Int? {
		return VPNManager.shared.ipsecProfiles.index { $0.id == selectedProfile }
	}

	private var selectedProfile: String? {
		return VPNManager.shared.selectedProfileID
	}

	private static func listIndex(for profile: VPNProfile) -> Int? {
		if let profile = profile as? IPSecProfile {
			return VPNManager.shared.ipsecProfiles.index(where: { $0 == profile })
		} else if let profile = profile as? OVPNProfile {
			return VPNManager.shared.ovpnProfiles.index(where: { $0 == profile })
		} else {
			fatalError("A VPNProfile should be eigther a OVPNProfile or a IPSec profile")
		}
	}

	private func setupPinger(for profile: VPNProfile) {
		let hosts = profile.hosts
		let id = profile.id

		guard pingers[id] == nil && bool(for: showVPNServerPingStatsKey) && !hosts.isEmpty else {
			return
		}
		let pinger = Pinger(host: hosts.randomElement) { [weak self] pinger, _, _ in
			guard let me = self else {
				pinger.stop()
				return
			}
			guard let time = pinger.averagePing, let rate = pinger.averageDropRate else {
				return
			}
			me.pingStats[id] = (time, rate)
			if me.isIPSec {
				if let index = VPNManager.shared.ipsecProfiles.index(where: { $0.id == id }) {
					let indexPath = IndexPath(row: index + 1, section: listSection)
					me.controller?.tableView.reloadRows(at: [indexPath], with: .none)
				}
			} else {
				if let index = VPNManager.shared.ovpnProfiles.index(where: { $0.id == id }) {
					let indexPath = IndexPath(row: index + 1, section: listSection)
					me.controller?.tableView.reloadRows(at: [indexPath], with: .none)
				}
			}
		}
		pingers[id] = pinger
		pinger.start()
	}

	private var pingStats = [String: (Double, Double)]()
	private var pingers = [String: Pinger]()

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == controlSection {
			if indexPath.row == 0 {
				let uiSwitch = makeSwitch()
				uiSwitch.isOn = bool(for: updateVPNListKey)
				uiSwitch.addTarget(self, action: #selector(toggleUpdateVPNList(_:)), for: .valueChanged)
				cell.accessoryView = uiSwitch
				cell.textLabel?.text = NSLocalizedString("update vpn list settings title", comment: "title of settings to auto-update the list of available vpn servers")
			} else if indexPath.row == 1 {
				let uiSwitch = makeSwitch()
				uiSwitch.addTarget(self, action: #selector(toggleShowPingStats(_:)), for: .valueChanged)
				uiSwitch.isOn = bool(for: showVPNServerPingStatsKey)
				cell.accessoryView = uiSwitch
				cell.textLabel?.text = NSLocalizedString("show vpn server ping status settings title", comment: "title of setting to display the ping status of the vpn servers")
			} else if indexPath.row == 2 {
				let button = makeButton(for: cell)
				let title = NSLocalizedString("show subscription status button title", comment: "title of button to switch from vpn settings to subscription settings")
				button.addTarget(self, action: #selector(showSubscriptionStatus(_:)), for: .touchUpInside)
				button.setTitle(title, for: [])
			} else {
				let button = makeButton(for: cell)
				let title = NSLocalizedString("show vpn tutorial button title", comment: "title of button to show the vpn tutorial")
				button.addTarget(self, action: #selector(showVPNTutorial(_:)), for: .touchUpInside)
				button.setTitle(title, for: [])
			}
		} else if indexPath.section == listSection && indexPath.row == 0 {
			if isIPSec {
				if SubscriptionManager.shared.hasSubscription {
					if let _ = VPNManager.shared.ipsecProfiles.first(where: { $0.id == selectedProfile && $0.hasProfile }) {
						switch NEVPNManager.shared().connection.status {
							case .connected:
								let onoff = makeSwitch()
								cell.textLabel?.text = NSLocalizedString("connected ipsec vpn state title", comment: "indication that the ipsec vpn is connected")
								onoff.isOn = true
								onoff.addTarget(self, action: #selector(toggleOnOff(_:)), for: .valueChanged)
								cell.accessoryView = onoff
							case .connecting:
								cell.textLabel?.text = NSLocalizedString("connecting ipsec vpn state title", comment: "indication that the ipsec vpn is connecting")
								let spinner = UIActivityIndicatorView(activityIndicatorStyle: .white)
								spinner.startAnimating()
								cell.accessoryView = spinner
							case .disconnected:
								let onoff = makeSwitch()
								cell.textLabel?.text = NSLocalizedString("disconnected ipsec vpn state title", comment: "indication that the ipsec vpn is disconnected")
								onoff.isOn = false
								onoff.addTarget(self, action: #selector(toggleOnOff(_:)), for: .valueChanged)
								cell.accessoryView = onoff
							case .disconnecting:
								cell.textLabel?.text = NSLocalizedString("disconnecting ipsec vpn state title", comment: "indication that the ipsec vpn is disconnecting")
								let spinner = UIActivityIndicatorView(activityIndicatorStyle: .white)
								spinner.startAnimating()
								cell.accessoryView = spinner
							case .invalid:
								cell.textLabel?.text = NSLocalizedString("invalid ipsec vpn state title", comment: "indication that the ipsec vpn profile is currently invalid")
								let spinner = UIActivityIndicatorView(activityIndicatorStyle: .white)
								spinner.startAnimating()
								cell.accessoryView = spinner
								if VPNManager.shared.ipsecManagerLoaded {
									VPNManager.shared.withLoadedManager { $0() }
								}
							case .reasserting:
								cell.textLabel?.text = NSLocalizedString("reasserting ipsec vpn state title", comment: "indication that the ipsec vpn is reasserting")
								let spinner = UIActivityIndicatorView(activityIndicatorStyle: .white)
								spinner.startAnimating()
								cell.accessoryView = spinner
						}
					} else {
						let onoff = makeSwitch()
						cell.textLabel?.text = NSLocalizedString("select ipsec vpn profile prompt", comment: "prompt for user to select the ipsec vpn profile")
						cell.accessoryView = onoff
						onoff.isEnabled = false
						onoff.isUserInteractionEnabled = false
					}
				} else {
					cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "blocked"))
					cell.textLabel?.text = NSLocalizedString("select ipsec vpn profile prompt", comment: "prompt for user to select the ipsec vpn profile")
					cell.accessibilityLabel = NSLocalizedString("select ipsec vpn profile prompt missing subscription accessibility label", comment: "accessibility label of prompt for user to select the ipsec vpn profile when user is not subscribed to snowhaze premium")
				}
			} else {
				let button = makeButton(for: cell)
				let title = NSLocalizedString("open openvpn connect button title", comment: "title of button to open openvpn connect")
				button.setTitle(title, for: [])
				button.addTarget(self, action: #selector(openOpenVPN(_:)), for: .touchUpInside)
			}
		} else if indexPath.section == listSection {
			let index = indexPath.row - 1
			let profile: VPNProfile
			if isIPSec {
				profile = VPNManager.shared.ipsecProfiles[index]
			} else {
				profile = VPNManager.shared.ovpnProfiles[index]
			}
			let loc = NSLocalizedString("localization code", comment: "code used to identify the current locale")
			let profileName = profile.names[loc] ?? profile.names["en"] ?? profile.hosts.randomElement
			cell.textLabel?.text = profileName
			cell.imageView?.image = profile.flag
			if downloadErrors.contains(profile.id) {
				cell.detailTextLabel?.text = NSLocalizedString("vpn profile download failed error message", comment: "error message flashed when a vpn profile download the user explicitly requested fails")
			} else {
				let profileState: String
				if let date = (profile as? OVPNProfile)?.installedExpiration {
					if date > Date() {
						let time = VPNSettingsManager.dateFormatter.string(from: date)
						let format = NSLocalizedString("vpn profile expiration notice format", comment: "format of the notice used to indicate when the vpn profile will expire")
						profileState = String(format: format, time)
					} else {
						profileState = NSLocalizedString("vpn profile expired notice", comment: "format of the notice used to indicate that a vpn profile has expired")
					}
				} else {
					// profileState will be ignored for IPSec profiles anyway
					profileState = NSLocalizedString("vpn profile not installed notice", comment: "format of the notice used to indicate that a vpn profile has not yet been installed")
				}
				if let (time, rate) = pingStats[profile.id] {
					let text: String
					if profile is IPSecProfile {
						let format = NSLocalizedString("vpn ping stats format", comment: "format used to display the vpn ping stats")
						text = String(format: format, "\(Int(time * 1000 + 0.5))", "\(Int(100 - 100 * rate + 0.5))")
					} else {
						let format = NSLocalizedString("vpn profile status und ping stats combined format", comment: "format used to combine the vpn profile status and ping stats")
						text = String(format: format, profileState, "\(Int(time * 1000 + 0.5))", "\(Int(100 - 100 * rate + 0.5))")
					}
					cell.detailTextLabel?.text = text
				} else if !isIPSec {
					cell.detailTextLabel?.text = profileState
				}
			}
			if !SubscriptionManager.shared.hasSubscription {
				cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "blocked"))
				let format = NSLocalizedString("vpn profile missing subscription accessibility label format", comment: "format of the accessibility label of the vpn profile cell when user is not subscribed to snowhaze premium")
				cell.accessibilityLabel = String(format: format, profileName)
			} else if downloading.contains(profile.id) {
				let activity = UIActivityIndicatorView(activityIndicatorStyle: .white)
				cell.accessoryView = activity
				activity.startAnimating()
				let format = NSLocalizedString("vpn profile downloading accessibility label format", comment: "format of the accessibility label of the vpn profile cell when the profile is being downloaded")
				cell.accessibilityLabel = String(format: format, profileName)
			} else if !profile.hasProfile {
				cell.accessoryView = UIImageView(image: #imageLiteral(resourceName: "download"))
				let format = NSLocalizedString("vpn profile download required accessibility label format", comment: "format of the accessibility label of the vpn profile cell when the profile credentials are not yet downloaded")
				cell.accessibilityLabel = String(format: format, profileName)
			} else if isIPSec && selectedProfileIndex == indexPath.row - 1 {
				cell.accessoryType = .checkmark
			}
		} else {
			fatalError("unexpected section")
		}
		return cell
	}

	override func viewForHeader(inSection section: Int) -> UIView? {
		if section == listSection && section != controlSection {
			let ipsecApp = NSLocalizedString("ipsec vpn app name", comment: "name of app to provide IPSec VPN")
			let openVPNApp = NSLocalizedString("openvpn vpn app name", comment: "name of app to provide OpenVPN VPN")
			let selector = UISegmentedControl(items: [ipsecApp, openVPNApp])
			selector.tintColor = .button
			selector.selectedSegmentIndex = isIPSec ? 0 : 1
			selector.translatesAutoresizingMaskIntoConstraints = false
			selector.addTarget(self, action: #selector(toggleVPNProtocol(_:)), for: .valueChanged)
			let container = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 45))
			container.addSubview(selector)

			let views = ["selector": selector]
			var constraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-20-[selector]-20-|", metrics: nil, views:views)
			constraints += NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[selector]-10-|", metrics: nil, views: views)
			NSLayoutConstraint.activate(constraints)
			selector.layoutIfNeeded()
			return container
		}
		return super.viewForHeader(inSection: section)
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		if section == listSection && section != controlSection {
			return 45
		}
		return super.heightForHeader(inSection: section)
	}

	override var numberOfSections: Int {
		return showList ? 3 : 2
	}

	override func numberOfRows(inSection section: Int) -> Int {
		if section == 0 {
			return 0
		} else if section == controlSection {
			return 4
		} else {
			assert(section == listSection)
			return (isIPSec ? VPNManager.shared.ipsecProfiles.count : VPNManager.shared.ovpnProfiles.count) + 1
		}
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if showList && indexPath.section == listSection && indexPath.row == 0 && isIPSec {
			toggleOnOff(tableView.cellForRow(at: indexPath))
		} else if indexPath.section == controlSection || indexPath.row == 0 {
			super.didSelectRow(atIndexPath: indexPath, tableView: tableView)
		} else {
			assert(indexPath.section == listSection)
			guard let cell = tableView.cellForRow(at: indexPath) else {
				return
			}
			let index = indexPath.row - 1
			if SubscriptionManager.shared.hasSubscription {
				let profile: VPNProfile
				if isIPSec {
					profile = VPNManager.shared.ipsecProfiles[index]
				} else {
					profile = VPNManager.shared.ovpnProfiles[index]
				}
				if profile.hasProfile {
					if let profile = profile as? IPSecProfile {
						var reload = [indexPath]
						if let oldSelectedIndex = selectedProfileIndex {
							reload.append(IndexPath(row: oldSelectedIndex + 1, section: listSection))
						} else {
							reload.append(IndexPath(row: 0, section: listSection))
						}
						if VPNManager.shared.ipsecConnected {
							VPNManager.shared.connect(with: profile)
						} else {
							VPNManager.shared.save(profile)
						}
						controller.tableView.reloadRows(at: reload, with: .none)
					} else if let profile = profile as? OVPNProfile {
						install(profile, for: cell)
					}
				} else {
					downloading.insert(profile.id)
					tableView.reloadRows(at: [indexPath], with: .none)
					VPNManager.shared.updateProfileList { [weak self] success in
						self?.downloading.remove(profile.id)
						guard let index = VPNSettingsManager.listIndex(for: profile) else {
							return
						}
						let indexPath = IndexPath(row: index, section: listSection)
						let correctProfiles: [VPNProfile]
						if profile is IPSecProfile {
							correctProfiles = VPNManager.shared.ipsecProfiles
						} else if profile is OVPNProfile {
							correctProfiles = VPNManager.shared.ovpnProfiles
						} else {
							fatalError("A VPNProfile should be eigther a OVPNProfile or a IPSec profile")
						}
						if success && correctProfiles[index].hasProfile {
							if let profile = profile as? IPSecProfile, let me = self {
								var reload = [indexPath]
								if let oldSelectedIndex = me.selectedProfileIndex {
									reload.append(IndexPath(row: oldSelectedIndex + 1, section: listSection))
								} else {
									reload.append(IndexPath(row: 0, section: listSection))
								}
								if VPNManager.shared.ipsecConnected {
									VPNManager.shared.connect(with: profile)
								} else {
									VPNManager.shared.save(profile)
								}
								me.controller.tableView.reloadRows(at: reload, with: .none)
							} else if let profile = profile as? OVPNProfile {
								self?.install(profile, for: cell)
							}
						} else {
							self?.downloadErrors.insert(profile.id)
							DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) { [weak self] in
								self?.downloadErrors.remove(profile.id)
								guard let index = VPNSettingsManager.listIndex(for: profile) else {
									return
								}
								let indexPath = IndexPath(row: index, section: listSection)
								tableView.reloadRows(at: [indexPath], with: .none)
							}
						}
						tableView.reloadRows(at: [indexPath], with: .none)
					}
				}
			} else {
				controller.switchToSubscriptionSettings()
			}
		}
	}

	@objc private func openOpenVPN(_ sender: UIButton) {
		if UIApplication.shared.canOpenURL(URL(string: "openvpn://")!) {
			UIApplication.shared.openURL(URL(string: "openvpn://")!)
		} else {
			let title = NSLocalizedString("opening openvpn connect requires installing alert title", comment: "title of alert to point out that opening openvpn connect requires it being installed")
			let message = NSLocalizedString("opening openvpn connect requires installing alert message", comment: "message of alert to point out that opening openvpn connect requires it being installed")
			let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
			let okTitle = NSLocalizedString("install openvpn connect app prompt ok button title", comment: "title of ok button of prompt to ask users if they want to install the openvpn connect app")
			let okAction = UIAlertAction(title: okTitle, style: .default) { _ in UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/id590379981")!) }
			alert.addAction(okAction)

			let cancelTitle = NSLocalizedString("install openvpn connect app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to install the openvpn connect app")
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
			alert.addAction(cancelAction)
			controller.present(alert, animated: true, completion: nil)
		}
	}

	@objc private func showSubscriptionStatus(_ sender: UIButton) {
		controller.switchToSubscriptionSettings()
	}

	@objc private func showVPNTutorial(_ sender: NSObject) {
		let mainVC = MainViewController.controller
		mainVC?.popToVisible(animated: true)
		let language = PolicyManager.globalManager().threeLanguageCode
		let site = "https://snowhaze.com/\(language)/vpn.html#tutorial"
		mainVC?.loadInFreshTab(input: site, type: .url)
	}

	@objc private func toggleUpdateVPNList(_ sender: UISwitch) {
		set(sender.isOn, for: updateVPNListKey)
		updateHeaderColor(animated: true)
		if sender.isOn {
			DownloadManager.shared.triggerVPNListUpdate()
		}
	}

	@objc private func toggleOnOff(_ sender: UIView?) {
		if VPNManager.shared.ipsecConnected {
			VPNManager.shared.disconnect()
		} else if let selectedProfileIndex = selectedProfileIndex {
			let profile = VPNManager.shared.ipsecProfiles[selectedProfileIndex]
			VPNManager.shared.connect(with: profile)
		} else {
			(sender as? UISwitch)?.setOn(false, animated: true)
		}
	}

	@objc private func toggleShowPingStats(_ sender: UISwitch) {
		set(sender.isOn, for: showVPNServerPingStatsKey)
		updateHeaderColor(animated: true)
		if sender.isOn {
			VPNManager.shared.ovpnProfiles.forEach { setupPinger(for: $0) }
			VPNManager.shared.ipsecProfiles.forEach { setupPinger(for: $0) }
		} else {
			for (_, pinger) in pingers {
				pinger.stop()
			}
			pingers = [:]
			pingStats = [:]
			if (!VPNManager.shared.ovpnProfiles.isEmpty && !isIPSec) || (!VPNManager.shared.ipsecProfiles.isEmpty && isIPSec) {
				let index = IndexSet(integer: listSection)
				controller?.tableView.reloadSections(index, with: .none)
			}
		}
	}

	@objc private func toggleVPNProtocol(_ sender: UISegmentedControl) {
		isIPSec = sender.selectedSegmentIndex == 0
		controller.tableView.reloadData()
	}

	private func install(_ profile: OVPNProfile, for sender: UIView) {
		guard let superview = sender.superview else {
			return
		}
		if UIApplication.shared.canOpenURL(URL(string: "openvpn://")!) {
			guard VPNSettingsManager.docController == nil else {
				return
			}
			let loc = NSLocalizedString("localization code", comment: "code used to identify the current locale")
			let name = profile.names[loc] ?? profile.names["en"] ?? profile.hosts.first ?? "?"
			let forebidden = CharacterSet.profileForebidden
			let sanitized = name.components(separatedBy: forebidden).joined()
			let profileString = profile.profile! + "\nsetenv FRIENDLY_NAME \"\(sanitized)\""
			let data = profileString.data(using: .utf8)!
			try! data.write(to: profileURL, options: .atomic)
			VPNSettingsManager.docController = UIDocumentInteractionController(url: profileURL)
			VPNSettingsManager.docController!.delegate = self
			VPNSettingsManager.docController!.annotation = ["id": profile.id] as NSDictionary
			VPNSettingsManager.docController!.presentOpenInMenu(from: sender.frame, in: superview, animated: true)
		} else {
			let title = NSLocalizedString("installing ovpn requires openvpn connect alert title", comment: "title of alert to point out that installing a ovpn configuration requires openvpn connect")
			let message = NSLocalizedString("installing ovpn requires openvpn connect alert message", comment: "message of alert to point out that installing a ovpn configuration requires openvpn connect")
			let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
			let okTitle = NSLocalizedString("install openvpn connect app prompt ok button title", comment: "title of ok button of prompt to ask users if they want to install the openvpn connect app")
			let okAction = UIAlertAction(title: okTitle, style: .default) { _ in UIApplication.shared.openURL(URL(string: "https://itunes.apple.com/app/id590379981")!) }
			alert.addAction(okAction)

			let tutorialTitle = NSLocalizedString("install openvpn show tutorial button title", comment: "title of the show tutorial button of prompt to ask users if they want to install the openvpn connect app")
			let tutorialAction = UIAlertAction(title: tutorialTitle, style: .default) { action in self.showVPNTutorial(action) }
			alert.addAction(tutorialAction)

			let cancelTitle = NSLocalizedString("install openvpn connect app prompt cancel button title", comment: "title of cancel button of prompt to ask users if they want to install the openvpn connect app")
			let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
			alert.addAction(cancelAction)
			controller.present(alert, animated: true, completion: nil)
		}
	}

	deinit {
		if let o = observer {
			NotificationCenter.default.removeObserver(o)
		}
	}
}

extension VPNSettingsManager: UIDocumentInteractionControllerDelegate {
	func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
		let id = (controller.annotation as! [AnyHashable: Any])["id"] as! String
		if let index = VPNManager.shared.ovpnProfiles.index(where: { $0.id == id }), application == "net.openvpn.connect.app" {
			VPNManager.shared.didInstall(VPNManager.shared.ovpnProfiles[index])
			let indexPath = IndexPath(row: index, section: listSection)
			self.controller?.tableView.reloadRows(at: [indexPath], with: .none)
			VPNSettingsManager.sendingFile = true
		}
	}

	func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
		try? FileManager.default.removeItem(at: profileURL)
		VPNSettingsManager.sendingFile = false
		VPNSettingsManager.docController = nil
	}

	func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
		if !VPNSettingsManager.sendingFile {
			try? FileManager.default.removeItem(at: profileURL)
			VPNSettingsManager.docController = nil
		}
	}
}

extension VPNSettingsManager: VPNManagerDelegate {
	func vpnManager(_ manager: VPNManager, didChangeOVPNProfileListFrom oldProfiles: [OVPNProfile], to newProfiles: [OVPNProfile]) {
		updateProfiles(from: oldProfiles, to: newProfiles)
	}

	func vpnManager(_ manager: VPNManager, didChangeIPSecProfileListFrom oldProfiles: [IPSecProfile], to newProfiles: [IPSecProfile]) {
		updateProfiles(from: oldProfiles, to: newProfiles)
	}

	private func updateProfiles(from oldProfiles: [VPNProfile], to newProfiles: [VPNProfile]) {
		let profilesAreIPSec = oldProfiles is [IPSecProfile] && newProfiles is [IPSecProfile]
		let profilesAreOVPN = oldProfiles is [OVPNProfile] && newProfiles is [OVPNProfile]
		assert(profilesAreIPSec != profilesAreOVPN)
		guard profilesAreIPSec == isIPSec else {
			return
		}
		let sectionDiff = numberOfSections - (controller?.tableView.numberOfSections ?? numberOfSections)
		let section = IndexSet(integer: listSection)
		if oldProfiles.count == newProfiles.count {
			var changed = false
			for i in 0 ..< oldProfiles.count {
				let from = oldProfiles[i]
				let to = newProfiles[i]
				if from.equals(to) || !to.unchanged(since: from) {
					changed = true
					break
				}
			}
			if !changed {
				return
			}
		}
		switch sectionDiff {
			case -1:	controller?.tableView.deleteSections(section, with: .fade)
			case  0:	controller?.tableView.reloadSections(section, with: .none)
			case  1:	controller?.tableView.insertSections(section, with: .fade)
			default:	fatalError("profile list changes should not cause more than 1 section to (dis)appear")
		}
	}
}
