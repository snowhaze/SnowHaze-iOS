//
//  Templating.swift
//  SnowHaze
//
//
//  Copyright © 2021 Illotros GmbH. All rights reserved.
//

import Foundation

struct Templating {
	enum Error: Swift.Error {
		case paddingMissing
	}

	static let hexChars = Set<Character>(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"])

	private var mappings = [(Regex, ([String?]) throws -> String)]()

	mutating func add(_ regex: String, with callback: @escaping ([String?]) throws -> String) {
		mappings.append((Regex(pattern: "^(\(regex))"), callback))
	}

	func apply(to string: String) throws -> String {
		var result = ""
		var index = string.startIndex
		while index < string.endIndex {
			let rest = String(string[index...])
			var found = false
			for (regex, callback) in mappings {
				guard let match = regex.firstMatch(in: rest) else {
					continue
				}
				found = true
				let groupCounts = match.rangesCount
				let groups = (0 ..< groupCounts).map { String(match.match(at: $0)) }
				result += try callback(groups)
				index = string.index(index, offsetBy: groups[0].count)
				break
			}
			if !found {
				result.append(string[index])
				index = string.index(after: index)
			}
		}
		return result
	}

	func unescape(_ string: String, safe: Set<Character>) -> (String, Templating) {
		let filtered = safe.filter { $0.isASCII }
		precondition(filtered.count >= 2)
		var bitsPerChar = 1
		while 1 << (bitsPerChar + 1) <= filtered.count {
			bitsPerChar += 1
		}
		let required = 256 / bitsPerChar
		func rnd() -> (String, String) {
			var result = ""
			for _ in 0 ..< required {
				result.append(filtered.randomElement()!)
			}
			var padding = ""
			for _ in 0 ..< 10 {
				padding.append(filtered.randomElement()!)
			}
			return (padding + result + padding, result)
		}
		var unescape = Templating()
		var inverse = Templating()
		for (regex, _) in mappings {
			unescape.mappings.append((regex, { groups -> String in
				let (padded, token) = rnd()
				inverse.add(Regex.escapedPattern(for: padded)) { _ in return groups[0]! }
				inverse.add(Regex.escapedPattern(for: token)) { _ in throw Error.paddingMissing }
				return padded
			}))
		}
		return (try! unescape.apply(to: string), inverse)
	}
}
