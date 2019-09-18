//
//	SettingsViewController.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

private let subscriptionRow = 0
private let vpnRow = 1
private let premiumSection = 0

class SettingsViewController: UIViewController, SettingsDetailViewControllerDelegate {
	enum SettingsType {
		case subscription
		case vpn

		fileprivate var indexPath: IndexPath {
			switch self {
				case .subscription:	return IndexPath(row: subscriptionRow, section: premiumSection)
				case .vpn:			return IndexPath(row: vpnRow, section: premiumSection)
			}
		}
	}

	@IBOutlet weak var tableView: UITableView!

	static var requestedType: (type: SettingsType?, unfold: Bool)?

	private let repCounter = RepeatCounter()

	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.title = NSLocalizedString("settings title", comment: "title for settings controller navigation item")
		tableView.backgroundView = nil
		tableView.backgroundColor = .clear
		tableView.alwaysBounceVertical = false
		splitMergeController?.backgroundImage = #imageLiteral(resourceName: "Background")
		splitMergeController?.backgroundColor = .background
		let requestedType = SettingsViewController.requestedType
		self.showSettings(requestedType?.type, unfold: requestedType?.unfold ?? false)
		SettingsViewController.requestedType = nil
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if let (multiple, expired) = VPNManager.shared.profileExpirationWarningConfig {
			let title: String
			let message: String
			switch (multiple, expired) {
				case (false, true):
					title = NSLocalizedString("vpn profile expiration warning single profile expired alert title", comment: "title of alert to warn users that a single installed VPN profile has expired")
					message = NSLocalizedString("vpn profile expiration warning single profile expired alert message", comment: "message of alert to warn users that a single installed VPN profile has expired")
				case (false, false):
					title = NSLocalizedString("vpn profile expiration warning single profile expiring alert title", comment: "title of alert to warn users that a single installed VPN profile is about to expire")
					message = NSLocalizedString("vpn profile expiration warning single profile expiring alert message", comment: "message of alert to warn users that a single installed VPN profile is about to expire")
				case (true, true):
					title = NSLocalizedString("vpn profile expiration warning multiple profiles expired alert title", comment: "title of alert to warn users that multiple installed VPN profiles have expired")
					message = NSLocalizedString("vpn profile expiration warning multiple profiles expired alert message", comment: "message of alert to warn users that multiple installed VPN profiles have expired")
				case (true, false):
					title = NSLocalizedString("vpn profile expiration warning multiple profiles expiring alert title", comment: "title of alert to warn users that multiple installed VPN profiles are about to expire")
					message = NSLocalizedString("vpn profile expiration warning multiple profiles expiring alert message", comment: "message of alert to warn users that multiple installed VPN profiles are about to expire")
			}
			let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
			let renewTitle = NSLocalizedString("vpn profile expiration warning alert vpn settings button title", comment: "title of vpn settings button of alert to warn users of VPN profile expiration")
			let renewAction = UIAlertAction(title: renewTitle, style: .default) { [weak self] _ in
				self?.showSettings(.vpn, unfold: false)
			}
			let okTitle = NSLocalizedString("vpn profile expiration warning alert ignore button title", comment: "title of ignore button of alert to warn users of VPN profile expiration")
			let okAction = UIAlertAction(title: okTitle, style: .cancel, handler: nil)
			alert.addAction(renewAction)
			alert.addAction(okAction)
			present(alert, animated: true) {
				VPNManager.shared.didDisplayProfileExpirationWarning()
			}
		}

		VPNManager.shared.swapIPSecCreds(runningLongerThan: 60 * 60, force: false)

		if !LockController.isDisengagingUILock {
			for indexPath in tableView.indexPathsForSelectedRows ?? [] {
				tableView.deselectRow(at: indexPath, animated: true)
			}
		}
	}

	func settingsDetailViewControllerShowSubscriptionSettings(_ settingsDetailVC: SettingsDetailViewController) {
		showSettings(.subscription, unfold: false)
	}

	func showSettings(_ type: SettingsType?, unfold: Bool) {
		SettingsViewController.requestedType = nil
		if let indexPath = type?.indexPath {
			animateToManager(at: indexPath, unfold: unfold)
		} else {
			splitMergeController?.detailViewController = nil
		}
	}

	private func animateToManager(at indexPath: IndexPath, unfold: Bool) {
		SettingsViewController.requestedType = nil
		showManager(for: indexPath, unfold: unfold)
		tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
		tableView.scrollToRow(at: indexPath, at: .none, animated: true)
	}

	private func showManager(for indexPath: IndexPath, unfold: Bool) {
		let detailVC = storyboard?.instantiateViewController(withIdentifier: "settingsDetailViewController") as? SettingsDetailViewController
		detailVC?.delegate = self
		detailVC?.manager = settingsViewManager(for: indexPath)
		detailVC?.manager.controller = detailVC
		let originalImage = UIImage(named: imageName(for: indexPath))!
		let image = originalImage.withRenderingMode(.alwaysTemplate)
		detailVC?.manager.header.icon = image
		detailVC?.navigationItem.title = title(for: indexPath)
		splitMergeController?.detailViewController = detailVC
		if unfold {
			UIView.animate(withDuration: 0.2) { [weak detailVC] in
				detailVC?.expand()
			}
		}
	}

	@available (iOS 11, *)
	override func viewSafeAreaInsetsDidChange() {
		super.viewSafeAreaInsetsDidChange()
		tableView.reloadData()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
}

extension SettingsViewController: UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		assert(premiumSection == 0)
		switch section {
			case 0:		return 2
			case 1:		return 9
			case 2:		return 6
			case 3:		return 1
			case 4:		return 2
			default:	return 0
		}
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let title = self.tableView(tableView, titleForHeaderInSection: section)!;
		let label = UILabel()
		UIFont.setSnowHazeFont(on: label)
		label.text = title
		label.textColor = .button
		let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
		label.frame = view.bounds
		label.frame.origin.x = tableView.separatorInset.left
		label.frame.size.width -= tableView.separatorInset.left
		view.addSubview(label)
		label.autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleRightMargin]
		return view
	}

	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return section == 0 ? 40 : 30
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		assert(premiumSection == 0)
		switch section {
			case 0:		return NSLocalizedString("premium settings title", comment: "title for premium settings section")
			case 1:		return NSLocalizedString("general settings title", comment: "title for general settings section")
			case 2:		return NSLocalizedString("privacy settings title", comment: "title for privacy settings section")
			case 3:		return NSLocalizedString("default settings title", comment: "title for default settings section")
			case 4:		return NSLocalizedString("about settings title", comment: "title for about settings section")
			default:	return nil
		}
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return 5
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
		cell.textLabel?.textColor = .title
		cell.textLabel?.text = title(for: indexPath)
		let originalImage = UIImage(named: imageName(for: indexPath))!
		let height: CGFloat = 44
		let size = CGSize(width: height, height: height)
		UIGraphicsBeginImageContextWithOptions(size, false, 0)
		let context = UIGraphicsGetCurrentContext()
		context!.scaleBy(x: 1, y: -1)
		context!.translateBy(x: 0, y: -height)
		context!.draw(originalImage.cgImage!, in: CGRect(origin: CGPoint.zero, size: size))
		let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		let image = scaledImage!.withRenderingMode(.alwaysTemplate)
		cell.imageView?.image = image
		cell.imageView?.contentMode = .scaleAspectFit
		cell.imageView?.tintColor = .tabCellBackground
		UIFont.setSnowHazeFont(on: cell.textLabel!)
		cell.selectedBackgroundView = UIView()
		cell.selectedBackgroundView?.backgroundColor = UIColor(white: 1, alpha: 0.2)
		return cell
	}
}

extension SettingsViewController: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		showManager(for: indexPath, unfold: false)
	}

	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		if scrollView.bounds.origin.y < -10 {
			if repCounter.inc() {
				repCounter.disable()
				let droppingView = DroppingImagesView(frame: scrollView.bounds)
				droppingView.imageColor = .button
				droppingView.frame.origin = CGPoint.zero
				tableView.backgroundView = droppingView
				var imageNames = [String]()
				var paths: [UIBezierPath] = []
				for section in 0 ..< numberOfSections(in: tableView) {
					for row in 0 ..< tableView(tableView, numberOfRowsInSection: section) {
						let indexPath = IndexPath(row: row, section: section)
						imageNames.append(imageName(for: indexPath))
						paths.append(imageBound(for: indexPath))
					}
				}
				droppingView.paths = paths
				droppingView.images = imageNames.map { UIImage(named: $0)! }
			}
		}
	}
}

// Internals
extension SettingsViewController {
	private func title(for indexPath: IndexPath) -> String {
		assert(premiumSection == 0)
		assert(subscriptionRow == 0)
		assert(vpnRow == 1)
		switch (indexPath.section, indexPath.row) {
			case (0, 0):	return NSLocalizedString("subscription settings title", comment: "title for subscription settings")
			case (0, 1):	return NSLocalizedString("vpn settings title", comment: "title for vpn settings")

			case (1, 0):	return NSLocalizedString("application settings title", comment: "title for application settings")
			case (1, 1):	return NSLocalizedString("javascript settings title", comment: "title for javascript settings")
			case (1, 2):	return NSLocalizedString("search engine settings title", comment: "title for search engine settings")
			case (1, 3):	return NSLocalizedString("media playback settings title", comment: "title for media playback settings")
			case (1, 4):	return NSLocalizedString("https settings title", comment: "title for https settings")
			case (1, 5):	return NSLocalizedString("appearance settings title", comment: "title for appearance settings")
			case (1, 6):	return NSLocalizedString("popover settings title", comment: "title for popover settings")
			case (1, 7):	return NSLocalizedString("warnings settings title", comment: "title for warnings settings")
			case (1, 8):	return NSLocalizedString("passcode settings title", comment: "title for passcode settings")

			case (2, 0):	return NSLocalizedString("website data settings title", comment: "title for website data settings")
			case (2, 1):	return NSLocalizedString("user agent settings title", comment: "title for user agent settings")
			case (2, 2):	return NSLocalizedString("history settings title", comment: "title for history settings")
			case (2, 3):	return NSLocalizedString("tracking protection settings title", comment: "title for tracking protection settings")
			case (2, 4):	return NSLocalizedString("external bookmarks settings title", comment: "title for external bookmarks settings")
			case (2, 5):	return NSLocalizedString("content type blockers settings title", comment: "title for content type blockers settings")

			case (3, 0):	return NSLocalizedString("defaults settings title", comment: "title for defaults settings")

			case (4, 0):	return NSLocalizedString("contact settings title", comment: "title for contact section")
			case (4, 1):	return NSLocalizedString("acknowledgements settings title", comment: "title for acknowledgements")

			default:		fatalError("invalid index path")
		}
	}

	private func settingsViewManager(for indexPath: IndexPath) -> SettingsViewManager {
		assert(premiumSection == 0)
		assert(subscriptionRow == 0)
		assert(vpnRow == 1)
		switch (indexPath.section, indexPath.row) {
			case (0, 0):	return SubscriptionSettingsManager()
			case (0, 1):	return VPNSettingsManager()

			case (1, 0):	return AppSettingsManager()
			case (1, 1):	return JavaScriptSettingsManager()
			case (1, 2):	return SearchEngineSettingsManager()
			case (1, 3):	return MediaPlaybackSettingsManager()
			case (1, 4):	return HTTPSSettingsManager()
			case (1, 5):	return AppearanceSettingsManager()
			case (1, 6):	return PopoverSettingsManager()
			case (1, 7):	return WarningsSettingsManager()
			case (1, 8):	return PasscodeSettingsManager()

			case (2, 0):	return WebsiteDataSettingsManager()
			case (2, 1):	return UserAgentSettingsManager()
			case (2, 2):	return HistorySettingsManager()
			case (2, 3):	return TrackingSettingsManager()
			case (2, 4):	return ExternalBookmarksSettingsManager()
			case (2, 5):	return ContentTypeBlockerSettingsManager()

			case (3, 0):	return DefaultsSettingsManager()

			case (4, 0):	return ContactSettingsManager()
			case (4, 1):	return AcknowledgementsSettingsManager()

			default:		fatalError("invalid index path")
		}
	}

	private func imageName(for indexPath: IndexPath) -> String {
		assert(premiumSection == 0)
		assert(subscriptionRow == 0)
		assert(vpnRow == 1)
		switch (indexPath.section, indexPath.row) {
			case (0, 0):	return "crown"
			case (0, 1):	return "openvpn"

			case (1, 0):	return "snowflake"
			case (1, 1):	return "javascript"
			case (1, 2):	return "searchengine"
			case (1, 3):	return "mediaplayback"
			case (1, 4):	return "https"
			case (1, 5):	return "appearance"
			case (1, 6):	return "popovers"
			case (1, 7):	return "warning"
			case (1, 8):	return "fingerprint"

			case (2, 0):	return "weabsitedata"
			case (2, 1):	return "useragent"
			case (2, 2):	return "history"
			case (2, 3):	return "trackingprotection"
			case (2, 4):	return "bookmark"
			case (2, 5):	return "contentblocker"

			case (3, 0):	return "defaults"

			case (4, 0):	return "contact"
			case (4, 1):	return "acknowledgements"

			default:		fatalError("invalid index path")
		}
	}

	private func imageBound(for indexPath: IndexPath) -> UIBezierPath {
		assert(premiumSection == 0)
		assert(subscriptionRow == 0)
		assert(vpnRow == 1)
		switch (indexPath.section, indexPath.row) {
			case (0, 0):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: 0,y: -15))
				path.addLine(to: CGPoint(x: 16,y: -5))
				path.addLine(to: CGPoint(x: 13,y: 13))
				path.addLine(to: CGPoint(x: -13,y: 13))
				path.addLine(to: CGPoint(x: -16,y: -5))
				path.close()
				return path
			case (0, 1):
				let rect = CGRect(x: -19, y: -19, width: 38, height: 38)
				return UIBezierPath(ovalIn: rect)

			case (1, 0):
				let rect = CGRect(x: -17, y: -17, width: 34, height: 34)
				return UIBezierPath(ovalIn: rect)
			case (1, 1):
				let path = UIBezierPath()
				path.move(to: CGPoint(x:-15 , y:17))
				path.addLine(to: CGPoint(x: -15, y: 13))
				path.addLine(to: CGPoint(x: -9,y: 10))
				path.addLine(to: CGPoint(x: -9,y: -18))
				path.addLine(to: CGPoint(x: 15,y: -18))
				path.addLine(to: CGPoint(x: 15,y: 17))
				path.close()
				return path
			case (1, 2):
				let rect = CGRect(x: -18, y: -17, width: 35, height: 32)
				return UIBezierPath(rect: rect)
			case (1, 3):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: -11, y: -15))
				path.addLine(to: CGPoint(x: 14, y: 0))
				path.addLine(to: CGPoint(x: -11, y: 15))
				path.close()
				return path
			case (1, 4):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: -18, y: 18))
				path.addLine(to: CGPoint(x: -20, y: 17))
				path.addLine(to: CGPoint(x: 5, y: -20))
				path.addLine(to: CGPoint(x: 16, y: -16))
				path.addLine(to: CGPoint(x: 20, y: -3))
				path.addLine(to: CGPoint(x: -17, y: 20))
				path.close()
				return path
			case (1, 5):
				let rect = CGRect(x: -10, y: -18, width: 20, height: 36)
				return UIBezierPath(rect: rect)
			case (1, 6):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: 0, y: -16))
				path.addLine(to: CGPoint(x: 9, y: -16))
				path.addLine(to: CGPoint(x: 17, y: -8))
				path.addLine(to: CGPoint(x: 17, y: 18))
				path.addLine(to: CGPoint(x: -17, y: 18))
				path.addLine(to: CGPoint(x: -17, y: -8))
				path.addLine(to: CGPoint(x: -9, y: -16))
				path.close()
				return path
			case (1, 7):
				let rect = CGRect(x: -18, y: -18, width: 36, height: 36)
				return UIBezierPath(ovalIn: rect)
			case (1, 8):
				let rect = CGRect(x: -19, y: -19, width: 38, height: 38)
				return UIBezierPath(ovalIn: rect)

			case (2, 0):
				let rect = CGRect(x: -17, y: -17, width: 34, height: 34)
				return UIBezierPath(ovalIn: rect)
			case (2, 1):
				let rect = CGRect(x: -18, y: -18, width: 36, height: 36)
				return UIBezierPath(ovalIn: rect)
			case (2, 2):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: -15,y: 18))
				path.addLine(to: CGPoint(x: -15,y: -17))
				path.addLine(to: CGPoint(x: 15,y: -17))
				path.addLine(to: CGPoint(x: 15,y: -12))
				path.addLine(to: CGPoint(x: 11,y: -8))
				path.addLine(to: CGPoint(x: 11,y: 18))
				path.close()
				return path
			case (2, 3):
				let rect = CGRect(x: -20, y: -13, width: 40, height: 27)
				return UIBezierPath(ovalIn: rect)
			case (2, 4):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: -10,y: -15))
				path.addLine(to: CGPoint(x: 10,y: -15))
				path.addLine(to: CGPoint(x: 10,y: 16))
				path.addLine(to: CGPoint(x: 0,y: 7))
				path.addLine(to: CGPoint(x: -10,y: 16))
				path.close()
				return path
			case (2, 5):
				let rect = CGRect(x: -18, y: -16, width: 36, height: 32)
				return UIBezierPath(rect: rect)

			case (3, 0):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: 15,y: 20))
				path.addLine(to: CGPoint(x: 18, y: -5))
				path.addLine(to: CGPoint(x: 15,y: -20))
				path.addLine(to: CGPoint(x: -14,y: -20))
				path.addLine(to: CGPoint(x: -18,y: -13))
				path.addLine(to: CGPoint(x: -14,y: 20))
				path.close()
				return path

			case (4, 0):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: -18, y: 1))
				path.addLine(to: CGPoint(x: 15, y: -15))
				path.addLine(to: CGPoint(x: 9, y: 9))
				path.addLine(to: CGPoint(x: -4, y: 16))
				path.close()
				return path
			case (4, 1):
				let path = UIBezierPath()
				path.move(to: CGPoint(x: 0,y: 9))
				path.addLine(to: CGPoint(x: -10.6,y: 14.6))
				path.addLine(to: CGPoint(x: -8.6,y: 2.8))
				path.addLine(to: CGPoint(x: -17.1,y: -5.6))
				path.addLine(to: CGPoint(x: -5.3,y: -7.3))
				path.addLine(to: CGPoint(x: 0,y: -18))
				path.addLine(to: CGPoint(x: 5.3,y: -7.3))
				path.addLine(to: CGPoint(x: 17.1,y: -5.56))
				path.addLine(to: CGPoint(x: 8.56,y: 2.78))
				path.addLine(to: CGPoint(x: 10.56,y: 14.55))
				path.close()
				return path

			default:		fatalError("invalid index path")
		}
	}
}
