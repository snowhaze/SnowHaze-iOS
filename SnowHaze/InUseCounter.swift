//
//  InUseCounter.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

class InUseCounter {
	static let network = InUseCounter(using: { using in
		// although isNetworkActivityIndicatorVisible remains deprecated, iOS 13 has restarted displaying it
		UIApplication.shared.isNetworkActivityIndicatorVisible = using
	})

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
			blockGuard.called()
			self.queue.async {
				self.count -= 1
				if self.count == 0 {
					self.using(false)
				}
			}
		}
	}
}
