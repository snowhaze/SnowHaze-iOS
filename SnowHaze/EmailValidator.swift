//
//  EmailValidator.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

private extension CharacterSet {
	static let ascii: CharacterSet = {
		var result = CharacterSet()
		for i in 0 ..< 128 {
			let scalar = UnicodeScalar(i)!
			let insert = result.insert(scalar)
			assert(insert.0)
		}
		return result
	}()
}

private let specials = CharacterSet(charactersIn: "()<>@,;:\\\".[]")
private let control = CharacterSet(charactersIn: "\u{00}\u{01}\u{02}\u{03}\u{04}\u{05}\u{06}\u{07}\u{08}\u{09}\u{0A}\u{0B}\u{0C}\u{0D}\u{0E}\u{0F}\u{10}\u{11}\u{12}\u{13}\u{14}\u{15}\u{16}\u{17}\u{18}\u{19}\u{1A}\u{1B}\u{1C}\u{1D}\u{1E}\u{1F}\u{7F}")
private let space = CharacterSet(charactersIn: " ")
private let validAtom = specials.union(control).union(space).inverted.intersection(.ascii)
private let validQtext = CharacterSet(charactersIn: "\"\\\r").inverted.intersection(.ascii)
private let validDtext = CharacterSet(charactersIn: "[]\\\r").inverted.intersection(.ascii)

private extension Substring {
	var firstCharDropped: Substring {
		let start = index(after: startIndex)
		let end = endIndex
		return self[start ..< end]
	}

	func drop(prefix: String) -> Substring? {
		guard hasPrefix(prefix) else {
			return nil
		}
		let length = prefix.count
		let start = index(startIndex, offsetBy: length)
		let end = endIndex
		return self[start ..< end]
	}

	func drop(in charSet: CharacterSet, single: Bool = true) -> Substring? {
		func allValid(_ char: Character) -> Bool {
			let scalars = char.unicodeScalars
			guard !scalars.isEmpty && (!single || scalars.count == 1) else {
				return false
			}
			return scalars.allSatisfy { charSet.contains($0) }
		}
		guard allValid(first!) else {
			return nil
		}
		return firstCharDropped
	}

	func strip(in charSet: CharacterSet, min: Int = 0, single: Bool = true) -> Substring? {
		var min = min
		var stripped = self
		while !stripped.isEmpty {
			guard let new = stripped.drop(in: charSet, single: single) else {
				break
			}
			min -= 1
			stripped = new
		}
		return min > 0 ? nil : stripped
	}

	func drop(listOf validator: (Substring) -> Substring?, separator: (Substring) -> Substring?, min: Int = 0) -> Substring? {
		var min = min
		guard var remainder = validator(self) else {
			return min > 0 ? nil : self
		}
		min -= 1
		while let unSep = separator(remainder) {
			guard let next = validator(unSep) else {
				return nil
			}
			remainder = next
			min -= 1
		}
		return min > 0 ? nil : remainder
	}

	func drop(listOf validator: (Substring) -> Substring?, min: Int = 0) -> Substring? {
		var min = min
		guard var remainder = validator(self) else {
			return min > 0 ? nil : self
		}
		min -= 1
		while true {
			guard let next = validator(remainder) else {
				break
			}
			remainder = next
		}
		return min > 0 ? nil : remainder
	}
}

struct EmailValidator {
	private func validate(atom: Substring) -> Substring? {
		return atom.strip(in: validAtom, min: 1, single: true)
	}

	private func validate(linearWhiteSpace: Substring) -> Substring? {
		let validate: (Substring) -> Substring? = { test in
			if let space = test.drop(prefix: "\r\n ") ?? test.drop(prefix: "\r\n") {
				return space
			}
			if let htab = test.drop(prefix: "\r\n\t") ?? test.drop(prefix: "\r\n\t") {
				return htab
			}
			return nil
		}
		return linearWhiteSpace.drop(listOf: validate, min: 1)
	}

	private func validate(qtext: Substring) -> Substring? {
		guard !qtext.isEmpty else {
			return nil
		}
		return qtext.drop(in: validQtext, single: true) ?? validate(linearWhiteSpace: qtext)
	}

	private func validate(quotedPair: Substring) -> Substring? {
		guard quotedPair.count >= 2 else {
			return nil
		}
		return quotedPair.drop(prefix: "\\")?.drop(in: .ascii, single: true)
	}

	private func validate(quotedString: Substring) -> Substring? {
		guard let unquoted = quotedString.drop(prefix: "\"") else {
			return nil
		}
		let validator: (Substring) -> Substring? = {
			return self.validate(qtext: $0) ?? self.validate(quotedPair: $0)
		}
		return unquoted.drop(listOf: validator)?.drop(prefix: "\"")
	}

	private func validate(word: Substring) -> Substring? {
		return validate(atom: word) ?? validate(quotedString: word)
	}

	private func validate(localPart: Substring) -> Substring? {
		return localPart.drop(listOf: { validate(word: $0) }, separator: { $0.drop(prefix: ".") }, min: 1)
	}

	private func validate(domainRef: Substring) -> Substring? {
		return validate(atom: domainRef)
	}

	private func validate(dtext: Substring) -> Substring? {
		guard !dtext.isEmpty else {
			return nil
		}
		return dtext.drop(in: validDtext, single: false) ?? validate(linearWhiteSpace: dtext)
	}

	private func validate(domainLiteral: Substring) -> Substring? {
		guard let undelim = domainLiteral.drop(prefix: "[") else {
			return nil
		}
		let validator: (Substring) -> Substring? = {
			return self.validate(dtext: $0) ?? self.validate(quotedPair: $0)
		}
		return undelim.drop(listOf: validator)?.drop(prefix: "]")
	}

	private func validate(subDomain: Substring) -> Substring? {
		return validate(domainRef: subDomain) ?? validate(domainLiteral: subDomain)
	}

	private func validate(domain: Substring) -> Substring? {
		let min = allowSimpleDomain ? 1 : 2
		return domain.drop(listOf: { validate(subDomain: $0) }, separator: { $0.drop(prefix: ".") }, min: min)
	}

	private func validate(addrSpec: Substring) -> Substring? {
		guard let domain = validate(localPart: addrSpec)?.drop(prefix: "@") else {
			return nil
		}
		return validate(domain: domain)
	}

	func validate(_ email: String) -> Bool {
		let rest = validate(addrSpec: Substring(email))
		return rest?.isEmpty ?? false
	}

	let allowSimpleDomain: Bool

	init(allowSimpleDomain: Bool) {
		self.allowSimpleDomain = allowSimpleDomain
	}

	static let simpleDomains = EmailValidator(allowSimpleDomain: true)
	static let fullDomains = EmailValidator(allowSimpleDomain: false)
}
