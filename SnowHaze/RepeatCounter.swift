//
//  RepeatCounter.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation


class RepeatCounter {
	private(set) var count: Int = 0
	private(set) var lastTry: TimeInterval = 0
	private(set) var disabled: Bool = false

	var repetitions: Int
	var delay: TimeInterval

	init(repetitions: Int = 5, delay: TimeInterval = 1) {
		self.repetitions = repetitions
		self.delay = delay
	}

	var full: Bool {
		return (count == repetitions) && !disabled
	}

	func inc() -> Bool {
		guard !disabled else {
			return false
		}
		let timestamp = Date().timeIntervalSince1970
		if timestamp - lastTry <= delay {
			count += 1
		} else {
			count = 1
		}
		lastTry = timestamp
		return full
	}

	func reset() {
		count = 0
		lastTry = 0
		disabled = false
	}

	func disable() {
		disabled = true
	}
}
