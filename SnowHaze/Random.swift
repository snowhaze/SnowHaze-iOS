//
//  Random.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import Sodium

public extension Array {
	var randomElement: Element {
		return self[randomIndex]
	}

	var randomIndex: Int {
		return Int(random(UInt32(count)))
	}

	@discardableResult mutating func removeRandomElement() -> Element {
		return remove(at: randomIndex)
	}
}

public func random(_ bound: UInt32) -> UInt32 {
	return Sodium().randomBytes.uniform(upperBound: bound)
}
