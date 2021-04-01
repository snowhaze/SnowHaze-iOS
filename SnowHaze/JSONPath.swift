//
//  JSONPath.swift
//  SnowHaze
//
//
//  Copyright © 2021 Illotros GmbH. All rights reserved.
//

import Foundation
struct JSONPath: CustomStringConvertible, CustomDebugStringConvertible {
	enum ParseError: Error {
		case missingRoot
		case invalidSyntax(String)
		case escapeUnsupported
		case filterExpressionUnsupported
		case scriptExpressionUnsupported
	}

	enum MatchError: Error {
		case invalidJSON
		case internalError
	}

	private enum Operation {
		case root
		case recursive(String)
		case children([String])
		case slice(Int, Int, Int)

		var encode: String {
			switch self {
				case .root:
					return "$"
				case .recursive(let name):
					return "..'\(name)'"
				case .children(let names):
					let escaped = names.map { "'\($0)'" }
					let joined = escaped.joined(separator: ",")
					return "[\(joined)]"
				case .slice(let start, let end, let step):
					let encodedStart = start == 0 ? "" : String(start)
					let encodedEnd = end == Int.max ? "" : String(end)
					let encodedStep = step == 1 ? "" : String(step)
					return "[\(encodedStart):\(encodedEnd):\(encodedStep)]"
			}
		}
	}

	private static let dolarSign: UInt32 = 0x24
	private static let quote: UInt32 = 0x27
	private static let openBrace: UInt32 = 0x28
	private static let star: UInt32 = 0x2a
	private static let comma: UInt32 = 0x2c
	private static let minus: UInt32 = 0x2d
	private static let dot: UInt32 = 0x2e
	private static let zero: UInt32 = 0x30
	private static let colon: UInt32 = 0x3a
	private static let questionMark: UInt32 = 0x3f
	private static let openBracket: UInt32 = 0x5b
	private static let backslash: UInt32 = 0x5c
	private static let closeBracket: UInt32 = 0x5d

	private static let word: Set<UInt32> = [0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x5f]

	private static let digit: Set<UInt32> = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]

	private static func parseRoot(_ input: Substring.UnicodeScalarView) -> (Operation, Substring.UnicodeScalarView)? {
		guard input.first?.value == dolarSign else {
			return nil
		}
		return (Operation.root, input.dropFirst())
	}

	private let operations: [Operation]

	private init(operations: [Operation]) {
		self.operations = operations
	}

	init(_ code: String) throws {
		operations = try JSONPath.parse(code)
	}

	private static func parseName(_ input: Substring.UnicodeScalarView) throws -> (String, Substring.UnicodeScalarView)? {
		guard !input.isEmpty else {
			return nil
		}
		var index = input.startIndex
		if input.first?.value == quote {
			while true {
				index = input.index(after: index)
				if index == input.endIndex {
					return nil
				} else if input[index].value == quote {
					let initial = input.index(after: input.startIndex)
					let unicode = input[initial ..< index]
					let next = input.index(after: index)
					if next != input.endIndex && input[next].value == quote {
						throw ParseError.escapeUnsupported
					}
					return (String(unicode), input[next...])
				} else if input[index].value == backslash {
					throw ParseError.escapeUnsupported
				}
			}
		} else if input.first?.value == star {
			return ("*", input.dropFirst())
		} else {
			while true {
				if index == input.endIndex || !word.contains(input[index].value) {
					guard index != input.startIndex else {
						return nil
					}
					let unicode = input[input.startIndex ..< index]
					return (String(unicode), input[index...])
				}
				index = input.index(after: index)
			}
		}
	}

	private static func parseDescendents(_ input: Substring.UnicodeScalarView, recursive: Bool) throws -> (Operation, Substring.UnicodeScalarView)? {
		let prefixLength = recursive ? 2 : 1
		let start = input.startIndex
		guard input.count >= prefixLength else {
			return nil
		}
		let nameStart = input.index(start, offsetBy: prefixLength)
		guard input[start].value == dot, !recursive || input[input.index(after: start)].value == dot else {
			return nil
		}
		guard let (name, remaining) = try parseName(input[nameStart ..< input.endIndex]) else {
			return nil
		}
		return (recursive ? .recursive(name) : .children([name]), remaining)
	}

	private static func parseScript(_ input: Substring.UnicodeScalarView) throws {
		if input.first?.value == openBrace {
			throw ParseError.scriptExpressionUnsupported
		}
	}

	private static func parseFilter(_ input: Substring.UnicodeScalarView) throws {
		guard input.count >= 2 else {
			return
		}
		let next = input.index(after: input.startIndex)
		if input[input.startIndex].value == questionMark && input[next].value == openBrace {
			throw ParseError.scriptExpressionUnsupported
		}
	}

	private static func parseExpression(_ input: Substring.UnicodeScalarView) throws -> (String, Substring.UnicodeScalarView)? {
		if let result = try parseName(input) {
			return result
		}
		try parseScript(input)
		try parseFilter(input)
		return nil
	}

	private static func parseNumber(_ input: Substring.UnicodeScalarView) -> (Int?, Substring.UnicodeScalarView)? {
		let negative: Bool
		var index = input.startIndex
		if input.first?.value == minus {
			negative = true
			index = input.index(after: index)
		} else {
			negative = false
		}
		let leadingZeros = index < input.endIndex && input[index].value == zero
		while index < input.endIndex && input[index].value == zero {
			index = input.index(after: index)
		}
		let start = index
		while index < input.endIndex && digit.contains(input[index].value) {
			index = input.index(after: index)
		}
		let remaining = input[index...]
		guard index > start else {
			guard !negative || leadingZeros else {
				return nil
			}
			return (leadingZeros ? 0 : nil, remaining)
		}
		let number = String(input[start..<index])
		let int = Int(negative ? "-" + number : number)
		return (int ?? (negative ? Int.min : Int.max), remaining)
	}

	private static func parseSlice(_ input: Substring.UnicodeScalarView) throws -> (Operation, Substring.UnicodeScalarView)? {
		guard input.first?.value == openBracket else {
			return nil
		}
		guard let (start, afterStart) = parseNumber(input[input.index(after: input.startIndex)...]) else {
			return nil
		}
		guard afterStart.first?.value == colon else {
			return nil
		}
		let next = afterStart.index(after: afterStart.startIndex)
		guard let (end, afterEnd) = parseNumber(afterStart[next...]) else {
			return nil
		}
		let step: Int
		let remaining: Substring.UnicodeScalarView
		if afterEnd.first?.value == colon {
			let next = afterEnd.index(after: afterEnd.startIndex)
			guard let (rawStep, afterStep) = parseNumber(afterEnd[next...]) else {
				return nil
			}
			step = rawStep ?? 1
			remaining = afterStep
		} else {
			step = 1
			remaining = afterEnd
		}
		guard remaining.first?.value == closeBracket else {
			return nil
		}
		return (.slice(start ?? 0, end ?? Int.max, step), remaining[remaining.index(after: remaining.startIndex)...])
	}

	private static func parseChildren(_ input: Substring.UnicodeScalarView) throws -> (Operation, Substring.UnicodeScalarView)? {
		guard input.first?.value == openBracket else {
			return nil
		}
		var remaining = input[input.index(after: input.startIndex)...]
		var names = [String]()
		while true {
			guard !remaining.isEmpty else {
				return nil
			}
			guard let (name, rest) = try parseExpression(remaining) else {
				return nil
			}
			names.append(name)
			guard rest.first?.value != closeBracket else {
				return (.children(names), rest.dropFirst())
			}
			guard rest.first?.value == comma else {
				return nil
			}
			remaining = rest[rest.index(after: rest.startIndex)...]
		}
	}

	private static func parse(_ input: String) throws -> [Operation] {
		var remaining = Substring(input).unicodeScalars
		var op: Operation
		var ops = [Operation]()
		guard let result = parseRoot(remaining) else {
			throw ParseError.missingRoot
		}
		(op, remaining) = result
		ops.append(op)
		while !remaining.isEmpty {
			if let result = try parseDescendents(remaining, recursive: true) {
				(op, remaining) = result
				ops.append(op)
			} else if let result = try parseDescendents(remaining, recursive: false) {
				(op, remaining) = result
				ops.append(op)
			} else if let result = try parseSlice(remaining) {
				(op, remaining) = result
				ops.append(op)
			} else if let result = try parseChildren(remaining) {
				(op, remaining) = result
				ops.append(op)
			} else {
				throw ParseError.invalidSyntax(String(remaining))
			}
		}
		return ops
	}

	private func children(of json: Any) throws -> [(String, Any)] {
		if let array = json as? [Any] {
			return array.enumerated().map { (String($0.0), $0.1) }
		} else if let dictionary = json as? [String: Any] {
			return dictionary.map { $0 }
		} else {
			throw MatchError.invalidJSON
		}
	}

	private func internalApply(to json: Any, isRoot: Bool) throws -> [Any] {
		guard let operation = operations.first else {
			return [json]
		}
		let remainingOps = Array(operations.dropFirst())
		if json is String || json is Double || (json as Any? == nil) {
			return []
		}
		switch operation {
			case .root:
				guard isRoot else {
					throw MatchError.internalError
				}
				return try JSONPath(operations: remainingOps).internalApply(to: json, isRoot: true)
			case .recursive(let name):
				let childs = try children(of: json)
				let filtered: [Any]
				if name == "*" {
					filtered = childs.map { $0.1 }
				} else {
					filtered = childs.filter({ $0.0 == name }).map { $0.1 }
				}
				var intermediate = [Any]()
				for child in filtered {
					intermediate += try JSONPath(operations: remainingOps).internalApply(to: child, isRoot: false)
				}
				for (_, child) in childs {
					intermediate += try internalApply(to: child, isRoot: false)
				}
				return intermediate
			case .children(let names):
				let childs = try children(of: json)
				var intermediate = [Any]()
				for name in names {
					let filtered: [Any]
					if name == "*" {
						filtered = childs.map { $0.1 }
					} else {
						filtered = childs.filter({ $0.0 == name }).map { $0.1 }
					}
					for child in filtered {
						intermediate += try JSONPath(operations: remainingOps).internalApply(to: child, isRoot: false)
					}
				}
				return intermediate
			case .slice(let rawStart, let rawEnd, let rawStep):
				guard let array = json as? [Any] else {
					return []
				}
				guard !array.isEmpty else {
					return []
				}
				let start = min(max(0, rawStart < 0 ? array.count + rawStart : rawStart), array.count - 1)
				let end = min(max(-1, rawEnd < 0 ? array.count + rawEnd : rawEnd), array.count)
				let step = rawStep == 0 ? 1 : rawStep
				var filtered = [Any]()
				if step > 0 {
					var index = start
					while index < end {
						filtered.append(array[index])
						index += step
					}
				} else {
					var index = start
					while index > end {
						filtered.append(array[index])
						index += step
					}
				}
				var intermediate = [Any]()
				for child in filtered {
					intermediate += try JSONPath(operations: remainingOps).internalApply(to: child, isRoot: false)
				}
				return intermediate
		}
	}

	func apply(to json: Any) throws -> [Any] {
		return try internalApply(to: json, isRoot: true)
	}

	func apply(toJSON json: Data, allowFragments: Bool = true) throws -> [Any] {
		return try apply(to: JSONSerialization.jsonObject(with: json, options: allowFragments ? .fragmentsAllowed : []))
	}

	func apply(toJSON json: String, allowFragments: Bool = true) throws -> [Any] {
		return try apply(toJSON: json.data(using: .utf8)!, allowFragments: allowFragments)
	}

	var encoded: String {
		let encoded = operations.map { $0.encode }
		return encoded.joined(separator: "")
	}

	var description: String {
		let data = try! JSONSerialization.data(withJSONObject: encoded, options: .fragmentsAllowed)
		return "JSONPath(\(String(data: data, encoding: .utf8)!))"
	}

	var debugDescription: String {
		return description
	}
}
