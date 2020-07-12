//
//  Hex.swift
//  SnowHaze
//
//
//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation
import Sodium

public extension Data {
	init?(hex: String) {
		guard let unhexed = Sodium().utils.hex2bin(hex) else {
			return nil
		}
		self = Data(unhexed)
	}

	var hex: String {
		return Sodium().utils.bin2hex(Bytes(self))!
	}
}
