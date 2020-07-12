//
//  StringHelpers.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

extension String {
	static func secureRandom(entropy: Int = 256) -> String {
		var data = Data(count: (entropy + 7) / 8)
		let res = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!) }
		assert(res == errSecSuccess)
		return data.base64EncodedString()
	}
}
