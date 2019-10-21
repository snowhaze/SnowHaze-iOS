//
//  ScanCodeActivity.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import AVFoundation

protocol ScanCodeActivityDelegate: class {
	func activity(_ activity: ScanCodeActivity, didScanCode code: String)
}

class ScanCodeActivity: UIActivity {
	var source: NSObject?
	var tab: Tab!
	var controller: UIViewController?
	weak var delegate: ScanCodeActivityDelegate?

	var available: Bool {
		return AVCaptureDevice.default(for: AVMediaType.video) != nil
	}

	override var activityType : UIActivity.ActivityType? {
		return UIActivity.ActivityType("Scan Code Activity")
	}

	override var activityTitle : String? {
		return NSLocalizedString("scan code activity title", comment: "title of the activity to scan a (QR) code")
	}

	override var activityImage : UIImage? {
		return #imageLiteral(resourceName: "scan_code")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		for object in activityItems {
			if let tab = object as? Tab {
				self.tab = tab
			}
		}
		return tab != nil
	}

	override class var activityCategory : UIActivity.Category {
		return .action
	}

	override var activityViewController : UIViewController? {
		let vc = ScanCodeViewController()
		vc.useFrontCamera = PolicyManager.manager(for: tab).useFrontCamera
		vc.buttonColor = .button
		vc.codeColor = .title
		vc.errorColor = .title
		vc.errorIcon = #imageLiteral(resourceName: "no_camera")
		vc.fontName = SnowHazeFontName
		vc.modalPresentationStyle = .popover
		vc.delegate = self
		vc.errorMessage = NSLocalizedString("code scan no camera access error message", comment: "error message displayed when user tries to scan a code but has not (yet) granted camera access")
		vc.cancelButtonTitle = NSLocalizedString("code scan view controller cancel button title", comment: "title of button to cancel code scanning")
		vc.doneButtonTitle = NSLocalizedString("code scan view controller done button title", comment: "title of button to finish code scanning")
		vc.previewButtonTitle = NSLocalizedString("code scan view controller preview button title", comment: "title of button to preview scanned code")
		vc.popoverPresentationController?.delegate = self
		if let view = source as? UIView {
			vc.popoverPresentationController?.sourceRect = view.bounds
			vc.popoverPresentationController?.sourceView = view
		} else if let button = source as? UIBarButtonItem {
			vc.popoverPresentationController?.barButtonItem = button
		}
		return vc
	}
}

extension ScanCodeActivity: UIPopoverPresentationControllerDelegate {
	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		activityDidFinish(false)
	}
}

extension ScanCodeActivity: ScanCodeViewControllerDelegate {
	func codeScanner(_ scanner: ScanCodeViewController, canPreviewCode code: String) -> Bool {
		return true
	}

	func codeScanner(_ scanner: ScanCodeViewController, viewControllerForCodePreview code: String) -> UIViewController? {
		let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismiss(_:)))

		let previewVC = PagePreviewController(input: code, tab: tab)
		previewVC.setToolbarItems([space, done], animated: false)

		let nvc = UINavigationController(rootViewController: previewVC)
		nvc.setNavigationBarHidden(true, animated: false)
		nvc.setToolbarHidden(false, animated: false)
		nvc.toolbar.barTintColor = .bar
		nvc.toolbar.tintColor = .button
		nvc.toolbar.isTranslucent = false

		controller = nvc
		return nvc
	}

	func codeScanner(_ scanner: ScanCodeViewController, didSelectCode code: String?) {
		if let code = code {
			delegate?.activity(self, didScanCode: code)
		}
		activityDidFinish(code != nil)
	}

	func codeScannerDidDisappear(_ scanner: ScanCodeViewController) {
		activityDidFinish(false)
	}

	@objc private func dismiss(_ sender: UIBarButtonItem) {
		controller?.dismiss(animated: true, completion: nil)
		controller = nil
	}

	func codeScanner(_ scanner: ScanCodeViewController, canSelectCode code: String) -> Bool {
		return true
	}
}
