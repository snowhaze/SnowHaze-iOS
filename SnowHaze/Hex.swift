//
//  Hex.swift
//  SnowHaze
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

public extension Data {
	private static let nonHexChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF").inverted
	init?(hex: String) {
		guard hex.rangeOfCharacter(from: Data.nonHexChars) == nil, hex.count % 2 == 0 else {
			return nil
		}
		self.init(capacity: hex.count / 2)
		func value(char: Character) -> UInt8 {
			switch char {
				case "0":		return 0
				case "1":		return 1
				case "2":		return 2
				case "3":		return 3
				case "4":		return 4
				case "5":		return 5
				case "6":		return 6
				case "7":		return 7
				case "8":		return 8
				case "9":		return 9
				case "A", "a":	return 10
				case "B", "b":	return 11
				case "C", "c":	return 12
				case "D", "d":	return 13
				case "E", "e":	return 14
				case "F", "f":	return 15
				default: fatalError()
			}
		}
		for i in 0 ..< hex.count / 2 {
			let index0 = hex.index(hex.startIndex, offsetBy: 2 * i)
			let index1 = hex.index(after: index0)
			append(16 * value(char: hex[index0]) + value(char: hex[index1]))
		}
	}

	var hex: String {
		return reduce("") { $0 + String(format: "%02x", $1) }
	}
}
