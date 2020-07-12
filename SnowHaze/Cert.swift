//
//  Cert.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
struct Cert {
	let version: UInt64
	let notValidBefore: Date
	let notValidAfter: Date
	init?(der: DER) {
		guard let root = der as? DER.Collection, case .sequence = root.type, root.elements.count == 3 else {
			return nil
		}
		guard let certData = root.elements[0] as? DER.Collection, case .sequence = certData.type, (7 ... 10).contains(certData.elements.count) else {
			return nil
		}
		guard let versionData = (certData.elements[0] as? DER.End)?.data, (1 ... 8).contains(versionData.count) else {
			return nil
		}
		var version = UInt64()
		for byte in versionData {
			version = (version << 8) | UInt64(byte)
		}
		self.version = version
		guard let validityData = (certData.elements[4] as? DER.Collection), case .sequence = validityData.type, let _ = validityData.elements as? [DER.Date], validityData.elements.count == 2 else {
			return nil
		}
		notValidBefore = (validityData.elements[0] as! DER.Date).value
		notValidAfter = (validityData.elements[1] as! DER.Date).value
	}
}
