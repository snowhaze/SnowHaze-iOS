//
//  DispatchHelpers.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation

func syncToMainThread<T>(_ work: () -> T) -> T {
	return Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
}

class BlockCallGuard {
	private var wasCalled = false
	deinit {
		guard wasCalled else {
			fatalError("Block Was not Called")
		}
	}

	func called() {
		guard !wasCalled else {
			fatalError("Block Was Called twice")
		}
		wasCalled = true
	}
}

class SyncBlockCallGuard {
	private var wasCalled = false
	init() {
		DispatchQueue.main.async {
			guard self.wasCalled else {
				fatalError("Block Was not Called Withing the same Run Loop Itteration")
			}
		}
	}

	func called() {
		guard !wasCalled else {
			fatalError("Block Was Called twice")
		}
		wasCalled = true
	}
}
