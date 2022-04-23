//
//  ChildSettingsManager.swift
//  SnowHaze
//
//
//  Copyright © 2022 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

internal class ChildSettingsManager<Parent: SettingsViewManager>: SettingsViewManager {
	internal weak var parent: Parent?
	private var resetPending = false

	init(parent: Parent) {
		self.parent = parent
		super.init()
		controller = parent.controller
	}

	override func setup() {
		super.setup()
		header.icon = parent?.header.icon
		header.delegate = parent?.header.delegate
		header.color = assessmentResultColor
	}

	override var assessmentResultColor: UIColor {
		return parent?.assessmentResultColor ?? PolicyAssessmentResult.color(for: .veryBad)
	}

	func needsReset() {
		resetPending = true
	}

	func reset() { }

	func resetIfNeeded() {
		if resetPending {
			resetPending = false
			reset()
		}
	}
}
