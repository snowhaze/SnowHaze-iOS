//
//  DER.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

class DER {
	class Collection: DER {
		let elements: [DER]
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			var sequenceData = data
			var elements = [DER]()
			while !sequenceData.isEmpty {
				elements.append(try DER.parse(&sequenceData))
			}
			self.elements = elements
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			let delimitors: [Swift.String]
			switch type {
				case .sequence:	delimitors = ["[", "]"]
				case .set	:	delimitors = ["{", "}"]
				default:	fatalError("Sequence is not of sequence type")
			}
			return delimitors[0] + elements.map({ $0.description }).joined(separator: ", ") + delimitors[1]
		}
	}
	class String: DER {
		let value: Swift.String
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			let encoding: Swift.String.Encoding
			switch type {
				case .utf8String:		encoding = .utf8
				case .printableString:	encoding = .utf8
				case .ia5String:		encoding = .ascii
				default:			throw Error.internalParseError
			}
			guard let value = Swift.String(data: data, encoding: encoding) else {
				throw Error.stringEncoding
			}
			self.value = value
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
		}
	}
	class End: DER {
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			return "<End of Input: \(data.reduce("") { $0 + Swift.String(format: "%02x", $1) })>"
		}
	}
	class OID: DER {
		let indexes: [Int]
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			var offset = 0
			var indexes = [Int]()
			if offset < data.count {
				offset += 1
				let byte1 = data[0]
				indexes += [Int(byte1 / 40), Int(byte1 % 40)]
				while offset < data.count {
					var index = 0
					var byte: UInt8
					var count = 0
					repeat {
						count += 1
						byte = data[offset]
						offset += 1
						index = (index << 7) | Int(byte & 0x7F)
					} while byte >= 128 && count < MemoryLayout.size(ofValue: index) && offset < data.count
					// TODO: support setting all bits of index
					if byte >= 128 {
						throw offset < data.count ? Error.unsupportedIndexSize : Error.reachedEndOfData
					}
					indexes.append(index)
				}
			}
			self.indexes = indexes
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			return indexes.map({ "\($0)" }).joined(separator: ".")
		}
	}
	class Date: DER {
		private static let formatter: DateFormatter = {
			let ret = DateFormatter()
			ret.locale = Locale(identifier: "en_US")
			ret.dateFormat = "yyMMddHHmmssZ"
			return ret
		}()
		let value: Foundation.Date
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			guard let string = Swift.String(data: data, encoding: .utf8) else {
				throw Error.stringEncoding
			}
			guard let value = Date.formatter.date(from: string) else {
				throw Error.dateEncoding
			}
			self.value = value
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			return value.description
		}
	}
	class Simple: DER {
		let value: Bool?

		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			switch type {
				case .null:
					guard data.isEmpty else {
						throw Error.invalidDERData
					}
					value = nil
				case .boolean:
					guard data.count == 1 else {
						throw Error.invalidDERData
					}
					if data[0] == 0x00 {
						value = false
					} else if data[0] == 0xFF {
						value = true
					} else {
						throw Error.invalidDERData
					}
				default:
					throw Error.internalParseError
			}
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		override var description: Swift.String {
			if let value = value {
				return value ? "true" : "false"
			} else {
				return "null"
			}
		}
	}
	class Data: DER {
		fileprivate override init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
			try super.init(type: type, cls: cls, constructed: constructed, data: data)
		}

		// TODO: implement number & bit string
		override var description: Swift.String {
			return "<Data: \(data.reduce("") { $0 + Swift.String(format: "%02x", $1) })>"
		}
	}

	enum Error: Swift.Error {
		case reachedEndOfData
		case oversizedLength
		case invalidDERData
		case uncosumedDataRemaining
		case internalParseError
		case stringEncoding
		case dateEncoding
		case unsupportedIndexSize
	}

	enum DataType: UInt8 {
		case unsupported		= 255
		case endOfInput			= 0x00
		case boolean			= 0x01
		case integer			= 0x02
		case bitString			= 0x03
		case octetString		= 0x04
		case null				= 0x05
		case objectID			= 0x06
		case utf8String			= 0x0C
		case sequence 			= 0x10
		case set	 			= 0x11
		case printableString	= 0x13
		case ia5String 			= 0x16
		case utcDate 			= 0x17
	}

	enum DataClass: UInt8 {
		case universal		= 0x00
		case application	= 0x40
		case contextDefined	= 0x80
		case priv			= 0xC0
	}

	let type: DataType
	let cls: DataClass
	let constructed: Bool
	let data: Foundation.Data

	private init(type: DataType, cls: DataClass, constructed: Bool, data: Foundation.Data) throws {
		self.type = type
		self.cls = cls
		self.data = data
		self.constructed = constructed
	}

	var description: Swift.String {
		return "<Unsupported DER Data: \(data.reduce("") { $0 + Swift.String(format: "%02x", $1) })>"
	}

	private static func parse(_ data: inout Foundation.Data) throws -> DER {
		var usedBytes = 2
		guard data.count >= usedBytes else {
			throw Error.reachedEndOfData
		}
		let typeInfo = data[0]
		let sizeSize = data[1]
		let rawType = typeInfo & 0x1F
		let rawClass = typeInfo & 0xC0
		let constructed = typeInfo & 0x20 != 0
		let cls = DataClass(rawValue: rawClass)!
		let size: Int
		if sizeSize < 0x80 {
			size = Int(sizeSize)
		} else if (sizeSize & 0x7F) > MemoryLayout.size(ofValue: usedBytes) {
			throw Error.oversizedLength
		} else {
			usedBytes += Int(sizeSize & 0x7F)
			guard data.count >= usedBytes else {
				throw Error.reachedEndOfData
			}
			var result: UInt = 0
			for i in 2 ..< usedBytes {
				result = (result << 8) | UInt(data[i])
			}
			guard let signed = Int(exactly: result) else {
				throw Error.oversizedLength
			}
			size = signed
		}
		guard data.count >= usedBytes + size else {
			throw Error.reachedEndOfData
		}
		let currentData = Foundation.Data(data[usedBytes ..< (usedBytes + size)])
		data = Foundation.Data(data[(usedBytes + size)...])
		switch rawType {
			case 0x00:	return try End(type: .endOfInput, cls: cls, constructed: constructed, data: currentData)
			case 0x01:	return try Simple(type: .boolean, cls: cls, constructed: constructed, data: currentData)
			case 0x02:	return try Data(type: .integer, cls: cls, constructed: constructed, data: currentData)
			case 0x03:	return try Data(type: .bitString, cls: cls, constructed: constructed, data: currentData)
			case 0x04:	return try Data(type: .octetString, cls: cls, constructed: constructed, data: currentData)
			case 0x05:	return try Simple(type: .null, cls: cls, constructed: constructed, data: currentData)
			case 0x06:	return try OID(type: .objectID, cls: cls, constructed: constructed, data: currentData)
			case 0x0C:	return try String(type: .utf8String, cls: cls, constructed: constructed, data: currentData)
			case 0x10:	return try Collection(type: .sequence, cls: cls, constructed: constructed, data: currentData)
			case 0x11:	return try Collection(type: .set, cls: cls, constructed: constructed, data: currentData)
			case 0x13:	return try String(type: .printableString, cls: cls, constructed: constructed, data: currentData)
			case 0x16:	return try String(type: .ia5String, cls: cls, constructed: constructed, data: currentData)
			case 0x17:	return try Date(type: .utcDate, cls: cls, constructed: constructed, data: currentData)
			default: 	print(Swift.String(format: "0x%02X", rawType)); return try DER(type: .unsupported, cls: cls, constructed: constructed, data: currentData)
		}
	}

	static func parse(_ data: Foundation.Data) throws -> DER {
		var data = data
		let result = try parse(&data)
		guard data.isEmpty else {
			throw Error.uncosumedDataRemaining
		}
		return result
	}
}
