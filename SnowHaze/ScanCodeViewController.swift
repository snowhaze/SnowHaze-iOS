//
//  ScanCodeViewController.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import AVFoundation

protocol ScanCodeViewControllerDelegate: class {
	func codeScanner(_ scanner: ScanCodeViewController, canPreviewCode code: String) -> Bool
	func codeScanner(_ scanner: ScanCodeViewController, viewControllerForCodePreview code: String) -> UIViewController?
	func codeScanner(_ scanner: ScanCodeViewController, didSelectCode code: String?)
	func codeScanner(_ scanner: ScanCodeViewController, canSelectCode code: String) -> Bool
}

class ScanCodeViewController: UIViewController {
	weak var delegate: ScanCodeViewControllerDelegate?

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

	private(set) var code: String?

	private var codeOverlay: CodeOverlayView!

	private var errorMessageView: UIView!
	private var errorMessageLabel: UILabel!
	private var errorMessageImageView: UIImageView!

	override var prefersStatusBarHidden: Bool {
		return true
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

		DispatchQueue.global().async {
			self.sessionManager = self.useFrontCamera ? ScanCodeViewController.globalFrontSessionManager : ScanCodeViewController.globalSessionManager;
			self.sessionManager.startRunning()
			self.sessionManager.delegate = self;
			
			self.previewLayer = self.useFrontCamera ? ScanCodeViewController.globalFrontPreviewLayer : ScanCodeViewController.globalPreviewLayer

			DispatchQueue.main.async {
				self.previewLayer.frame = self.view.bounds

				let resizingView = self.view as! SublayerResizingView
				resizingView.layersToResize.append(self.previewLayer)
				self.view.layer.insertSublayer(self.previewLayer, at: 0)
				self.view.layer.masksToBounds = true

				if self.previewLayer.connection?.isVideoOrientationSupported ?? false {
					let orientation =  UIApplication.shared.statusBarOrientation;
					if orientation == .landscapeLeft {
						self.previewLayer.connection?.videoOrientation = .landscapeLeft
					} else if orientation == .landscapeRight {
						self.previewLayer.connection?.videoOrientation = .landscapeRight
					} else if orientation == .portrait {
						self.previewLayer.connection?.videoOrientation = .portrait
					} else if orientation == .portraitUpsideDown {
						self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
					}
				}
			}
		}
		NotificationCenter.default.addObserver(self, selector: #selector(didRotate(_:)), name: NSNotification.Name.UIApplicationDidChangeStatusBarOrientation, object: nil)
		let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
		view.addGestureRecognizer(recognizer)
	}

	@objc private func didRotate(_ notification: Notification) {
		if previewLayer.connection?.isVideoOrientationSupported ?? false {
			let orientation = UIApplication.shared.statusBarOrientation
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
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		sessionManager.stopRunning()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		errorMessageView.isHidden = sessionManager?.authorizationStatus == .authorized
		sessionManager?.startRunning()
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

	func addOverlay(for corners: [CGPoint]) {
		let overlay = ShapeOverlayView(frame: view.bounds)
		overlay.corners = corners
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
			self.errorMessageView.isHidden = true
		}
	}

	func sessionManager(_ manger: CaptureSessionManager, didScanBarCode code: String, withCorners corners: [CGPoint]) {
		let viewCorners = corners.map() { self.previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
		if self.code != code {
			DispatchQueue.main.async {
				if self.code != code {
					self.code = code
					self.addOverlay(for: viewCorners)
					self.codeOverlay.code = code
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
