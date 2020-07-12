//
//  CaptureSessionManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

protocol CaptureSessionManagerDelegate: class {
	func sessionManager(_ manger: CaptureSessionManager, didScanBarCode code: String, withCorners corners: [CGPoint])
	func sessionManagerAccessGranted(_ manger: CaptureSessionManager)
}

private func synchronized(_ lock: AnyObject, closure: () -> ()) {
	objc_sync_enter(lock)
	closure()
	objc_sync_exit(lock)
}

class CaptureSessionManager: NSObject {
	weak var delegate: CaptureSessionManagerDelegate?
	var captureSession: AVCaptureSession {
		var res: AVCaptureSession! = nil
		if Thread.isMainThread {
			if internalCaptureSession == nil {
				setupCaptureSession()
			}
			res = internalCaptureSession!
		} else {
			DispatchQueue.main.sync {
				res = self.captureSession
			}
		}
		return res
	}

	var authorizationStatus: AVAuthorizationStatus {
		return AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
	}

	var useFrontCamera = false

	private var internalCaptureSession: AVCaptureSession?
	private var videoInput: AVCaptureDeviceInput?
	private var videoDevice: AVCaptureDevice?
	private var videoConnection: AVCaptureConnection?
	private var running = false
	private var sessionQueue: DispatchQueue
	private var pipelineRunningTask: UIBackgroundTaskIdentifier
	private var metadataOutput: AVCaptureMetadataOutput?

	private var focusMode: AVCaptureDevice.FocusMode {
		get {
			guard let videoInput = videoInput else {
				return .locked
			}
			return videoInput.device.focusMode
		}
		set {
			guard let videoInput = videoInput else {
				return
			}
			let device = videoInput.device
			if device.isFocusModeSupported(newValue) {
				if let _ = try? device.lockForConfiguration() {
					device.focusMode = newValue
					if device.isAutoFocusRangeRestrictionSupported {
						device.autoFocusRangeRestriction = .near
					}
					device.unlockForConfiguration()
				}
			}
		}
	}

	private var exposureMode: AVCaptureDevice.ExposureMode {
		get {
			guard let videoInput = videoInput else {
				return .custom
			}
			return videoInput.device.exposureMode
		}

		set {
			let oldMode = exposureMode
			var newMode = newValue
			if newMode != oldMode {
				if oldMode == .autoExpose {
					newMode = .continuousAutoExposure
				}
				guard let videoInput = videoInput else {
					return
				}
				let device = videoInput.device
				if device.isExposureModeSupported(newMode) {
					if let _ = try?  device.lockForConfiguration() {
						device.exposureMode = newMode
						device.unlockForConfiguration()
					}
				}
			}
		}
	}

	func startRunning() {
		func start() {
#if !(arch(i386) || arch(x86_64))
				sessionQueue.async {
					self.captureSession.startRunning()
					self.running = true
					self.metadataOutput!.metadataObjectTypes = self.metadataOutput!.availableMetadataObjectTypes
				}
#endif
		}
		if authorizationStatus == .authorized {
			start()
		} else if authorizationStatus == .notDetermined {
			AVCaptureDevice.requestAccess(for: AVMediaType.video) { allowed in
				if allowed {
					start()
					self.delegate?.sessionManagerAccessGranted(self)
				}
			}
		}
	}

	func stopRunning() {
		sessionQueue.async {
			self.running = false
			self.captureSession.stopRunning()
			self.captureSessionDidStopRunning()
		}
	}

	func autoFocus(at point: CGPoint) {
		guard let device = videoInput?.device else {
			return
		}
		if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
			if let _ = try? device.lockForConfiguration() {
				device.focusPointOfInterest = point
				device.focusMode = .autoFocus
				if device.isAutoFocusRangeRestrictionSupported {
					device.autoFocusRangeRestriction = .near
				}
				device.unlockForConfiguration()
			}
		}
	}

	func continuousFocus(at point: CGPoint) {
		guard let device = videoInput?.device else {
			return
		}
		if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.continuousAutoFocus) {
			if let _ = try?  device.lockForConfiguration() {
				device.focusPointOfInterest = point
				device.focusMode = .continuousAutoFocus
				if device.isAutoFocusRangeRestrictionSupported {
					device.autoFocusRangeRestriction = .near
				}
				device.unlockForConfiguration()
			}
		}
	}

	func expose(at point: CGPoint) {
		guard let device = videoInput?.device else {
			return
		}
		if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
			if let _ = try? device.lockForConfiguration() {
				device.exposurePointOfInterest = point
				device.exposureMode = .continuousAutoExposure
				device.unlockForConfiguration()
			}
		}
	}

	override init() {
		sessionQueue = DispatchQueue(label: "ch.illotros.snowhaze.capturesessionmanager.capture")
		pipelineRunningTask = UIBackgroundTaskIdentifier.invalid
		super.init()
	}

	deinit {
		teardownCaptureSession()
	}

	@objc private func captureSessionNotification(_ notification: Notification) {
		sessionQueue.async {
			if notification.name == NSNotification.Name.AVCaptureSessionWasInterrupted {
				self.captureSessionDidStopRunning()
			} else if notification.name == NSNotification.Name.AVCaptureSessionInterruptionEnded {
				self.captureSession.startRunning()
			} else if notification.name == NSNotification.Name.AVCaptureSessionRuntimeError {
				self.captureSessionDidStopRunning()
				let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
				if let code = error?.code, code == AVError.Code.mediaServicesWereReset.rawValue {
					print("media services were reset")
				} else if let error = error {
					self.handle(nonRecoverableCaptureSessionRuntimeError: error)
				}
			} else if notification.name == NSNotification.Name.AVCaptureSessionDidStartRunning {
				print("session started running")
			} else if notification.name == NSNotification.Name.AVCaptureSessionDidStopRunning {
				print("session stopped running")
			}
		}
	}

	private func setupCaptureSession() {
		assert(Thread.isMainThread)
		internalCaptureSession = AVCaptureSession()

		NotificationCenter.default.addObserver(self, selector: #selector(captureSessionNotification(_:)), name: nil, object: internalCaptureSession)

		if useFrontCamera {
			videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
		} else {
			videoDevice = AVCaptureDevice.default(for: .video)
		}
		videoInput = try? AVCaptureDeviceInput(device: videoDevice!)
		if let input = videoInput, internalCaptureSession!.canAddInput(input) {
			internalCaptureSession!.addInput(input)
		}

		metadataOutput = AVCaptureMetadataOutput()
		let metadataQueue = DispatchQueue(label: "ch.illotros.scancode.codedata")
		metadataOutput!.setMetadataObjectsDelegate(self, queue: metadataQueue)

		if internalCaptureSession!.canAddOutput(metadataOutput!) {
			internalCaptureSession!.addOutput(metadataOutput!)
		}

		return
	}

	private func teardownCaptureSession() {
		if !Thread.isMainThread {
			DispatchQueue.main.sync {
				teardownCaptureSession()
			}
		}
		if let captureSession = internalCaptureSession {
			NotificationCenter.default.removeObserver(self, name: nil, object: captureSession)
			internalCaptureSession = nil
		}
	}

	private func handle(nonRecoverableCaptureSessionRuntimeError error: NSError) {
		print("fatal runtime error \(error), code \(error.code)")
		running = false
		teardownCaptureSession()
	}

	private func captureSessionDidStopRunning() {
		teardownVideoPipeline()
	}

	private func teardownVideoPipeline() {
		videoPipelineDidFinishRunning()
	}

	private func videoPipelineWillStartRunning() {
		pipelineRunningTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
			print("video capture pipeline background task expired")
		})
	}

	private func videoPipelineDidFinishRunning() {
		UIApplication.shared.endBackgroundTask(pipelineRunningTask)
		pipelineRunningTask = UIBackgroundTaskIdentifier.invalid
	}

	private func supportsFocus() -> Bool {
		guard let videoInput = videoInput else {
			return false
		}
		let device = videoInput.device
		return  device.isFocusModeSupported(.locked) || device.isFocusModeSupported(.autoFocus) || device.isFocusModeSupported(.continuousAutoFocus)
	}

	private func supportsExpose() -> Bool {
		guard let videoInput = videoInput else {
			return false
		}
		let device = videoInput.device
		return  device.isExposureModeSupported(.locked) || device.isExposureModeSupported(.autoExpose) || device.isExposureModeSupported(.continuousAutoExposure)
	}
}

extension CaptureSessionManager: AVCaptureMetadataOutputObjectsDelegate {
	func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
		let metadata = metadataObjects
		synchronized(self) {
			for object in metadata {
				guard let code = object as? AVMetadataMachineReadableCodeObject else {
					continue
				}
				self.delegate?.sessionManager(self, didScanBarCode: code.stringValue!, withCorners: code.corners)
			}
		}
	}
}
