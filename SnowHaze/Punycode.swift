//
//  Punycode.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

public class Punycode {
	private static let base: UInt64			= 36
	private static let tmin: UInt64			= 1
	private static let tmax: UInt64			= 26
	private static let skew: UInt64			= 38
	private static let damp: UInt64			= 700
	private static let initial_bias: UInt64	= 72
	private static let initial_n: UInt32	= 0x80

	private static func adapt(delta initDelta: UInt64, numpoints: UInt64, firsttime: Bool) -> UInt64 {
		var delta = initDelta / (firsttime ? damp : 2)
		delta += delta + (delta / numpoints)
		var k: UInt64 = 0
		while delta > ((base - tmin) * tmax) / 2  {
			delta = delta / (base - tmin)
			k = k + base
		}
		return k + (((base - tmin + 1) * delta) / (delta + skew))
	}

	private static func value(_ point: UInt32) -> UInt64? {
		if point >= 0x30 && point <= 0x39 {
			return UInt64(point - 0x30 + 26)
		} else if point >= 0x41 && point <= 0x5A {
			return UInt64(point - 0x41)
		} else if point >= 0x61 && point <= 0x7A {
			return UInt64(point - 0x61)
		} else {
			return nil
		}
	}

	private static func point(_ value: UInt64) -> UInt32 {
		if value < 26 {
			return UInt32(value + 0x61)
		} else {
			assert(value < 36)
			return UInt32(value - 26 + 0x30)
		}
	}

	public static func decode(_ inputStr: String) -> String? {
		var input = ArraySlice(inputStr.unicodeScalars.map({ $0.value }))
		var n = initial_n
		var i: UInt64 = 0
		var bias = initial_bias
		var output = ArraySlice<UInt32>()
		var lastDelim = -1
		for (i, point) in input.enumerated() where point == 0x2D {
			lastDelim = i
		}
		if lastDelim >= 0 {
			output = input[0 ..< lastDelim]
			if output.contains(where: { $0 >= initial_n }) {
				return nil
			}
			input = input[lastDelim + 1 ..< input.count]
		} else if input.contains(where: { $0 >= initial_n }) {
			return nil
		} else {
			return inputStr
		}
		while !input.isEmpty {
			let oldi = i
			var w: UInt64 = 1
			var k = base
			while true {
				guard !input.isEmpty else {
					return nil
				}
				let point = input.remove(at: input.startIndex)
				guard let digit = value(point) else {
					return nil
				}
				let (addI, overflow1) = digit.multipliedReportingOverflow(by: w)
				if overflow1 {
					return nil
				}
				let (newI, overflow2) = i.addingReportingOverflow(addI)
				if overflow2 {
					return nil
				}
				i = newI
				let t: UInt64
				if k <= bias {
					t = tmin
				} else if k >= bias + tmax {
					t = tmax
				} else {
					t = k - bias
				}
				if digit < t {
					break
				}
				let (newW, overflow3) = w.multipliedReportingOverflow(by: base - t)
				if overflow3 {
					return nil
				}
				w = newW
				k += base
			}
			bias = adapt(delta: i - oldi, numpoints: UInt64(output.count) + 1, firsttime: oldi == 0)
			let (newN, overflow) = UInt64(n).addingReportingOverflow(i / UInt64(output.count + 1))
			guard !overflow, let newLowerN = UInt32(exactly: newN) else {
				return nil
			}
			n = newLowerN
			i = i % UInt64(output.count + 1)
			guard let index = Int(exactly: i) else {
				return nil
			}
			output.insert(n, at: index)
			i += 1
		}
		var out = ""
		for point in output {
			guard let scalar = UnicodeScalar(point) else {
				return nil
			}
			out.unicodeScalars.append(scalar)
		}
		return out
	}

	public static func encode(_ inputStr: String) -> String? {
		let input = inputStr.unicodeScalars.map { $0.value }
		var output = input.filter { $0 < initial_n }
		var n = initial_n
		var delta: UInt64 = 0
		var bias = initial_bias
		var h = output.count
		let b = h
		if b == input.count && !input.contains(0x2D) {
			return inputStr
		} else if b > 0 {
			output.append( 0x2D )
		}
		while h < input.count {
			let m = input.filter({ $0 >= n }).min()!
			let (mulRes, overflow1) = UInt64(m - n).multipliedReportingOverflow(by: UInt64(h) + 1)
			if overflow1 {
				return nil
			}
			let (newDelta, overflow2) = delta.addingReportingOverflow(mulRes)
			if overflow2 {
				return nil
			}
			delta = newDelta
			n = m
			for c in input {
				if c < n {
					let (incedDelta, overflow3) = delta.addingReportingOverflow(1)
					if overflow3 {
						return nil
					}
					delta = incedDelta
				}
				if c == n {
					var q = delta
					var k = base
					while true {
						let t: UInt64
						if k <= bias {
							t = tmin
						} else if k >= bias + tmax {
							t = tmax
						} else {
							t = k - bias
						}
						if q < t {
							break
						}
			 		output.append(point(t + ((q - t) % (base - t))))
						q = (q - t) / (base - t)
						k += base
					}
					output.append(point(q))
					bias = adapt(delta: delta, numpoints: UInt64(h) + 1, firsttime: h == b)
					delta = 0
					h += 1
		 	}
			}
			delta += 1
			n += 1
		}
		var out = ""
		for point in output {
			guard let scalar = UnicodeScalar(point) else {
				return nil
			}
			out.unicodeScalars.append(scalar)
		}
		return out
	}

	private static func encode(domainComponent input: String) -> String {
		guard let enc = encode(input) else {
			return input
		}
		return enc == input || enc == input + "-" ? input : "xn--" + enc
	}

	private static func decode(domainComponent encoded: String) -> String {
		guard encoded.hasPrefix("xn--") && encoded.count > 4 else {
			return encoded
		}
		let sub = String(encoded[encoded.index(encoded.startIndex, offsetBy: 4)...])
		let enc = sub.contains("-") ? sub : "-" + sub
		return decode(enc) ?? encoded
	}

	public static func encode(domain: String) -> String {
		let components = domain.components(separatedBy: ".")
		let encodedComponents = components.map { encode(domainComponent: $0.lowercased()) }
		return encodedComponents.joined(separator: ".")
	}

	public static func decode(domain encoded: String) -> String {
		let components = encoded.components(separatedBy: ".")
		let decodedComponents = components.map { decode(domainComponent: $0) }
		return decodedComponents.joined(separator: ".")
	}

	private init() {
		fatalError("Not instanciable")
	}
}
