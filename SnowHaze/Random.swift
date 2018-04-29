//
//  Random.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

public extension Array {
	public var randomElement: Element {
		return self[randomIndex]
	}

	public var randomIndex: Int {
		return random(count)
	}

	@discardableResult public mutating func removeRandomElement() -> Element {
		return remove(at: randomIndex)
	}
}

public func random(_ range: Int) -> Int {
	var result = -1
	while result < 0 {
		var rand = 0
		let randPtr = UnsafeMutablePointer<Int>(&rand)
		let opaquePtr = OpaquePointer(randPtr)
		let bytePtr = UnsafeMutablePointer<UInt8>(opaquePtr)
		guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<Int>.size, bytePtr) == errSecSuccess else {
			continue
		}
		let coef = Int.max / range
		if rand < 0 {
			rand = -(rand + 1)
		}
		guard rand < coef * range else {
			continue
		}
		result = rand % range
	}
	return result
}

public func random(_ range: UInt) -> UInt {
	var result: UInt = 0
	var ready = false
	while !ready {
		var rand: UInt = 0
		let randPtr = UnsafeMutablePointer<UInt>(&rand)
		let opaquePtr = OpaquePointer(randPtr)
		let bytePtr = UnsafeMutablePointer<UInt8>(opaquePtr)
		guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt>.size, bytePtr) == errSecSuccess else {
			continue
		}
		let coef = UInt.max / range
		guard rand < coef * range else {
			continue
		}
		result = rand % range
		ready = true
	}
	return result
}
