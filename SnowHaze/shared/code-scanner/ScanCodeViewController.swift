//
//  ScanCodeViewController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

protocol ScanCodeViewControllerDelegate: AnyObject {
	func codeScanner(_ scanner: ScanCodeViewController, canPreviewCode code: String) -> Bool
	func codeScanner(_ scanner: ScanCodeViewController, viewControllerForCodePreview code: String) -> UIViewController?
	func codeScanner(_ scanner: ScanCodeViewController, didSelectCode code: String?)
	func codeScanner(_ scanner: ScanCodeViewController, canSelectCode code: String) -> Bool
	func codeScannerDidDisappear(_ scanner: ScanCodeViewController)
}

extension ScanCodeViewControllerDelegate {
	func codeScanner(_ scanner: ScanCodeViewController, canPreviewCode code: String) -> Bool {
		return false
	}

	func codeScanner(_ scanner: ScanCodeViewController, viewControllerForCodePreview code: String) -> UIViewController? {
		return nil
	}

	func codeScanner(_ scanner: ScanCodeViewController, didSelectCode code: String?) { }

	func codeScanner(_ scanner: ScanCodeViewController, canSelectCode code: String) -> Bool {
		return true
	}

	func codeScannerDidDisappear(_ scanner: ScanCodeViewController) { }
}

class ScanCodeViewController: UIViewController {
	weak var delegate: ScanCodeViewControllerDelegate?

	var simulatorDebugCode: String?

	var errorMessage: String? = "No Camera access" {
		didSet {
			errorMessageLabel?.text = errorMessage
		}
	}

	var errorIcon: UIImage? = nil {
		didSet {
			errorMessageImageView?.image = errorIcon?.withRenderingMode(.alwaysTemplate)
		}
	}

	var buttonColor = UIColor.blue {
		didSet {
			codeOverlay?.buttonColor = buttonColor
		}
	}

	var successOverlayColor = UIColor.green
	var failOverlayColor = UIColor.red

	var errorColor = UIColor.white {
		didSet {
			errorMessageLabel?.textColor = errorColor
			errorMessageImageView?.tintColor = errorColor
		}
	}

	var fontName: String? {
		didSet {
			codeOverlay?.fontName = fontName
			if let name = fontName {
				errorMessageLabel?.font = UIFont(name: name, size: errorMessageLabel.font.pointSize)
			} else {
				errorMessageLabel?.font = UIFont.systemFont(ofSize: errorMessageLabel.font.pointSize)
			}
		}
	}

	var codeColor = UIColor.white {
		didSet {
			codeOverlay?.codeColor = codeColor
		}
	}

	var codeBackgroundColor = UIColor.black {
		didSet {
			codeOverlay?.codeBackgroundColor = codeBackgroundColor
		}
	}

	var cancelButtonTitle = "Cancel" {
		didSet {
			codeOverlay?.cancelButtonTitle = cancelButtonTitle
		}
	}

	var doneButtonTitle = "Done" {
		didSet {
			codeOverlay?.doneButtonTitle = doneButtonTitle
		}
	}

	var previewButtonTitle = "Preview" {
		didSet {
			codeOverlay?.previewButtonTitle = previewButtonTitle
		}
	}

	var codeFilter = try! NSRegularExpression(pattern: ".*")

	var showScanResult = true {
		didSet {
			codeOverlay?.showScanResult = showScanResult
		}
	}

	var showControlButtons = true {
	   didSet {
		   codeOverlay?.showControlButtons = showControlButtons
	   }
   }

	var metadataTypes: [AVMetadataObject.ObjectType]? {
		didSet {
			sessionManager?.metadataTypes = metadataTypes
		}
	}

	var repeatInterval: TimeInterval = 10

	var useFrontCamera = false

	private static var globalSessionManager = CaptureSessionManager()
	private static var globalPreviewLayer: AVCaptureVideoPreviewLayer = {
		let ret = AVCaptureVideoPreviewLayer(session: globalSessionManager.captureSession)
		ret.videoGravity = AVLayerVideoGravity.resizeAspectFill
		return ret
	}()

	private static var globalFrontSessionManager: CaptureSessionManager = {
		let ret = CaptureSessionManager()
		ret.useFrontCamera = true
		return ret
	}()

	private static var globalFrontPreviewLayer: AVCaptureVideoPreviewLayer = {
		let ret = AVCaptureVideoPreviewLayer(session: globalFrontSessionManager.captureSession)
		ret.videoGravity = AVLayerVideoGravity.resizeAspectFill
		return ret
	}()

	private static var previewLayer: AVCaptureVideoPreviewLayer!

	private var sessionManager: CaptureSessionManager!
	private var previewLayer: AVCaptureVideoPreviewLayer!

	private var processedScans = [ScanResult: Date]()
	private enum ScanResult: Hashable {
		case unreadable
		case ok(String)
		case filtered(String)

		static func ==(_ lhs: ScanResult, _ rhs: ScanResult) -> Bool {
			switch (lhs, rhs) {
				case (.unreadable, unreadable):
					return true
				case (.ok(let a), .ok(let b)):
					return a == b
				case (.filtered(let a), .filtered(let b)):
					return a == b
				default:
					return false
			}
		}

		init(code: String?, filter: NSRegularExpression) {
			if let code = code {
				let range = NSRange(code.startIndex ..< code.endIndex, in: code)
				let match = filter.firstMatch(in: code, range: range)
				self = match == nil ? .filtered(code) : .ok(code)
			} else {
				self = .unreadable
			}
		}

		var validCode: String? {
			switch self {
				case .ok(let code):	return code
				default:			return nil
			}
		}

		var success: Bool {
			switch self {
				case .ok(_):	return true
				default:		return false
			}
		}
	}

	private var codeOverlay: CodeOverlayView!

	private var errorMessageView: UIView!
	private var errorMessageLabel: UILabel!
	private var errorMessageImageView: UIImageView!

	override var prefersStatusBarHidden: Bool {
		return true
	}

	private var hasCameraAccess: Bool {
		return sessionManager?.authorizationStatus == .authorized && sessionManager?.hasCamera ?? false
	}

	override func loadView() {
		preferredContentSize = CGSize(width: 400, height: 300)
		view = SublayerResizingView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
		view.backgroundColor = .black
		codeOverlay = CodeOverlayView(view: view)
		codeOverlay.delegate = self
		codeOverlay.codeBackgroundColor = codeBackgroundColor
		codeOverlay.buttonColor = buttonColor
		codeOverlay.codeColor = codeColor
		codeOverlay.fontName = fontName
		codeOverlay.cancelButtonTitle = cancelButtonTitle
		codeOverlay.doneButtonTitle = doneButtonTitle
		codeOverlay.previewButtonTitle = previewButtonTitle
		codeOverlay.showScanResult = showScanResult
		codeOverlay.showControlButtons = showControlButtons

		errorMessageView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
		errorMessageView.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
		errorMessageView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
		view.addSubview(errorMessageView)

		errorMessageLabel = UILabel(frame: CGRect(x: 0, y: 150, width: 300, height: 100))
		errorMessageLabel.text = errorMessage
		errorMessageLabel.numberOfLines = 3
		errorMessageLabel.textColor = errorColor
		errorMessageLabel.textAlignment = .center
		if let name = fontName {
			errorMessageLabel.font = UIFont(name: name, size: errorMessageLabel.font.pointSize)
		}
		errorMessageView.addSubview(errorMessageLabel)

		errorMessageImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
		errorMessageImageView.image = errorIcon?.withRenderingMode(.alwaysTemplate)
		errorMessageImageView.contentMode = .scaleAspectFit
		errorMessageImageView.tintColor = errorColor
		errorMessageView.addSubview(errorMessageImageView)

		typealias SCVC = ScanCodeViewController
		sessionManager = useFrontCamera ? SCVC.globalFrontSessionManager : SCVC.globalSessionManager;
		sessionManager.startRunning()
		sessionManager.delegate = self;
		sessionManager.metadataTypes = metadataTypes

		previewLayer = useFrontCamera ? SCVC.globalFrontPreviewLayer : SCVC.globalPreviewLayer

		previewLayer.frame = view.bounds

		let resizingView = view as! SublayerResizingView
		resizingView.layersToResize.append(previewLayer)
		view.layer.insertSublayer(previewLayer, at: 0)
		view.layer.masksToBounds = true

		if previewLayer.connection?.isVideoOrientationSupported ?? false {
			let orientation: UIInterfaceOrientation?
			if #available(iOS 13, *) {
				orientation = view.window?.windowScene?.interfaceOrientation
			} else {
				orientation = UIApplication.shared.statusBarOrientation
			}
			if orientation == .landscapeLeft {
				previewLayer.connection?.videoOrientation = .landscapeLeft
			} else if orientation == .landscapeRight {
				previewLayer.connection?.videoOrientation = .landscapeRight
			} else if orientation == .portrait {
				previewLayer.connection?.videoOrientation = .portrait
			} else if orientation == .portraitUpsideDown {
				previewLayer.connection?.videoOrientation = .portraitUpsideDown
			}
		}
		let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		view.addGestureRecognizer(recognizer)
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: nil) { [weak self] _ in
			if self?.previewLayer.connection?.isVideoOrientationSupported ?? false {
				let orientation: UIInterfaceOrientation?
				if #available(iOS 13, *) {
					orientation = self?.view.window?.windowScene?.interfaceOrientation
				} else {
					orientation = UIApplication.shared.statusBarOrientation
				}
				if orientation == .landscapeLeft {
					self?.previewLayer.connection?.videoOrientation = .landscapeLeft
				} else if orientation == .landscapeRight {
					self?.previewLayer.connection?.videoOrientation = .landscapeRight
				} else if orientation == .portrait {
					self?.previewLayer.connection?.videoOrientation = .portrait
				} else if orientation == .portraitUpsideDown {
					self?.previewLayer.connection?.videoOrientation = .portraitUpsideDown
				}
			}
		}
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		sessionManager.stopRunning()
		delegate?.codeScannerDidDisappear(self)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		errorMessageView.isHidden = hasCameraAccess
		sessionManager?.startRunning()

#if targetEnvironment(simulator)
		if !(sessionManager?.hasCamera ?? true) {
			DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
				guard let self = self, let code = self.simulatorDebugCode, let manager = self.sessionManager else {
					return
				}
				self.sessionManager(manager, didScanBarCode: code, withCorners: [])
			}
		}
#endif
	}

	@objc private func handleTap(_ recognizer: UIGestureRecognizer) {
		let tapPoint = recognizer.location(in: view)
		focus(at: tapPoint)
		expose(at: tapPoint)
	}

	func focus(at point: CGPoint) {
		let convertedFocusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
		sessionManager.autoFocus(at: convertedFocusPoint)
	}

	func expose(at point: CGPoint) {
		let convertedExposurePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
		sessionManager.expose(at: convertedExposurePoint)
	}

	func addOverlay(for corners: [CGPoint], success: Bool) {
		let overlay = ShapeOverlayView(frame: view.bounds)
		overlay.corners = corners
		overlay.overlayColor = success ? successOverlayColor : failOverlayColor
		view.addSubview(overlay)
		UIView.animate(withDuration: 0.6, animations: {
			overlay.alpha = 0;
		}, completion: { finished in
			overlay.removeFromSuperview()
		})
	}
}

extension ScanCodeViewController: CaptureSessionManagerDelegate {
	func sessionManagerAccessGranted(_ manger: CaptureSessionManager) {
		DispatchQueue.main.async {
			self.errorMessageView.isHidden = self.hasCameraAccess
		}
	}

	func sessionManager(_ manger: CaptureSessionManager, didScanBarCode code: String?, withCorners corners: [CGPoint]) {
		DispatchQueue.main.async {
			let viewCorners = corners.map() { self.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
			let scan = ScanResult(code: code, filter: self.codeFilter)
			self.processedScans = self.processedScans.filter { $1.timeIntervalSinceNow > -self.repeatInterval }
			if self.processedScans[scan] == nil {
				self.processedScans[scan] = Date()
				self.addOverlay(for: viewCorners, success: scan.success)
				self.codeOverlay.code = scan.validCode

				if let code = scan.validCode, !self.showScanResult, self.delegate?.codeScanner(self, canSelectCode: code) ?? true {
					self.delegate?.codeScanner(self, didSelectCode: code)
				}
			}
		}
	}
}

extension ScanCodeViewController: CodeOverlayViewDelegate {
	func codeOverlayView(_ overlay: CodeOverlayView, canPreviewCode code: String) -> Bool {
		return delegate?.codeScanner(self, canPreviewCode: code) ?? false
	}

	func codeOverlayView(_ overlay: CodeOverlayView, previewCode code: String) {
		if let controller = delegate?.codeScanner(self, viewControllerForCodePreview: code) {
			present(controller, animated: true, completion: nil)
		}
	}

	func codeOverlayView(_ overlay: CodeOverlayView, didSelectCode code: String?) {
		if let delegate = delegate {
			delegate.codeScanner(self, didSelectCode: code)
		} else {
			presentingViewController?.dismiss(animated: true, completion: nil)
		}
	}

	func codeOverlayView(_ overlay: CodeOverlayView, canSelectCode code: String) -> Bool {
		return delegate?.codeScanner(self, canSelectCode: code) ?? true
	}
}
