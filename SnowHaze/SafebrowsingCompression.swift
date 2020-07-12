//
//  SafebrowsingCompression.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

private struct Rice {
	enum Error: Swift.Error {
		case invalidCompressedData
		case invalidParameter
		case overflow
	}

	private let k: Int
	private let initial: Int64?
	private let data: Data
	let count: Int
	private var index = Int64()

	var ints: [Int64]!

	private mutating func advanceBit() throws -> Bool {
		let byte = index / 8
		guard byte < data.count else {
			throw Error.invalidCompressedData
		}
		let bit = index % 8
		index += 1
		return (data[Int(byte)] >> bit) & 1 == 1
	}

	private mutating func getUnaryCoded() throws -> Int64 {
		var result = Int64()
		while try advanceBit() {
			result += 1
		}
		return result
	}

	private mutating func getBinaryCoded() throws -> Int64 {
		var result = Int64()
		for i in 0 ..< k {
			result += (try advanceBit() ? 1 : 0) << i
		}
		return result
	}

	mutating func decode() throws {
		guard let initial = initial else {
			ints = []
			return
		}
		var result = [Int64]()
		result.reserveCapacity(count)
		result.append(initial)
		for _ in 0 ..< count {
			let q = try getUnaryCoded()
			let r = try getBinaryCoded()
			let (shifted, multOverflow) = q.multipliedReportingOverflow(by: 1 << k)
			guard !multOverflow else {
				throw Error.overflow
			}
			let (diff, add1Overflow) = shifted.addingReportingOverflow(r)
			guard !add1Overflow else {
				throw Error.overflow
			}
			let (value, add2Overflow) = diff.addingReportingOverflow(result.last!)
			guard !add2Overflow else {
				throw Error.overflow
			}
			result.append(value)
		}
		guard (index - 1) / 8 == data.count - 1  else {
			print((index - 1) / 8, data.count - 1)
			throw Error.invalidCompressedData
		}
		ints = result
	}

	mutating func decoded() throws -> [Int64] {
		if let result = ints {
			return result
		}
		try decode()
		return ints!
	}

	init(k: Int, initial: Int64?, data: Data, count: Int) throws {
		guard k < 32 else {
			throw Error.invalidParameter
		}
		guard (initial != nil) || (count == 0) else {
			throw Error.invalidParameter
		}
		self.k = k
		self.initial = initial
		self.data = data
		self.count = count
	}
}

func safebrowsingCompression(for name: Any?) -> SafebrowsingCompression? {
	switch name as? String {
		case "RAW":		return SafebrowsingRawCompression()
		case "RICE":	return SafebrowsingRiceCompression()
		default:		return nil
	}
}

protocol SafebrowsingCompression {
	func decode(additions: [String: Any]) -> Set<Data>?
	func decode(deletions: [String: Any]) -> Set<Int>?
}

struct SafebrowsingRawCompression: SafebrowsingCompression {
	func decode(additions: [String: Any]) -> Set<Data>? {
		guard let rawDict = additions["rawHashes"] as? [String:Any] else {
			return nil
		}
		guard let prefixSize = rawDict["prefixSize"] as? Int else {
		   return nil
		}
		guard let rawHashes = rawDict["rawHashes"] as? String else {
		   return nil
		}
		guard let prefixes = Data(base64Encoded: rawHashes), prefixes.count % prefixSize == 0 else {
			return nil
		}
		var additions = Set<Data>()
		for i in 0 ..< prefixes.count / prefixSize {
			additions.insert(prefixes.subdata(in: prefixSize * i ..< prefixSize * (i + 1)))
		}
		return additions
	}

	func decode(deletions: [String: Any]) -> Set<Int>? {
		guard let rawIndices = deletions["rawIndices"] as? [Int] else {
			return nil
		}
		return Set(rawIndices)
	}
}

struct SafebrowsingRiceCompression: SafebrowsingCompression {
	func decode(additions: [String: Any]) -> Set<Data>? {
		guard let riceDict = additions["riceHashes"] as? [String: Any] else {
			return nil
		}
		let first: Int64
		if let value = riceDict["firstValue"] {
			guard let firstStr = value as? String, let decoded = Int64(firstStr) else {
				return nil
			}
			first = decoded
		} else {
			first = 0
		}
		guard let k = riceDict["riceParameter"] as? Int else {
			return nil
		}
		guard let count = riceDict["numEntries"] as? Int else {
			return nil
		}
		guard let base64 = riceDict["encodedData"] as? String, let data = Data(base64Encoded: base64) else {
			return nil
		}
		guard var rice = try? Rice(k: k, initial: first, data: data, count: count) else {
			return nil
		}
		guard let ints = try? rice.decoded() else {
			return nil
		}
		guard let i = ints.last, i <= Int(UInt32.max) else {
			return nil
		}
		return Set(ints.map { (i: Int64) -> Data in Data([UInt8(i & 0xFF), UInt8((i >> 8) & 0xFF), UInt8((i >> 16) & 0xFF), UInt8(i >> 24)]) })
	}

	func decode(deletions: [String: Any]) -> Set<Int>? {
		guard let riceDict = deletions["riceIndices"] as? [String: Any] else {
			return nil
		}
		let first: Int64
		if let value = riceDict["firstValue"] {
			guard let firstStr = value as? String, let decoded = Int64(firstStr) else {
				return nil
			}
			first = decoded
		} else {
			first = 0
		}
		guard let k = riceDict["riceParameter"] as? Int else {
			return nil
		}
		guard let count = riceDict["numEntries"] as? Int else {
			return nil
		}
		guard let base64 = riceDict["encodedData"] as? String, let data = Data(base64Encoded: base64) else {
			return nil
		}
		guard var rice = try? Rice(k: k, initial: first, data: data, count: count) else {
			return nil
		}
		return try? Set(rice.decoded().map { Int($0) })
	}
}
