//
//  InUseCounter.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

class InUseCounter {
	static let network = InUseCounter(using: { using in UIApplication.shared.isNetworkActivityIndicatorVisible = using })

	private class BlockCallGuard {
		var called = false
		deinit {
			guard called else {
				fatalError("Block Was not Called")
			}
		}
	}

	let using: (Bool) -> Void
	let queue: DispatchQueue
	private(set) var count: UInt = 0

	init(using: @escaping (Bool) -> Void, queue: DispatchQueue = DispatchQueue.main) {
		self.using = using
		self.queue = queue
	}

	func inc() -> () -> Void {
		queue.async {
			self.count += 1
			if self.count == 1 {
				self.using(true)
			}
		}
		let blockGuard = BlockCallGuard()
		return {
			precondition(!blockGuard.called)
			blockGuard.called = true
			self.queue.async {
				self.count -= 1
				if self.count == 0 {
					self.using(false)
				}
			}
		}
	}
}
