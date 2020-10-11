 //
//  PasswordValidator.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import Sodium

private extension String {
	func firstIndex(with set: CharacterSet) -> String.Index? {
		return firstIndex { $0.unicodeScalars.contains { set.contains($0) } }
	}

	func lastIndex(with set: CharacterSet) -> String.Index? {
		return lastIndex { $0.unicodeScalars.contains { set.contains($0) } }
	}
}

private extension CharacterSet {
	static let special = CharacterSet.alphanumerics.inverted
	static let numbers = CharacterSet.alphanumerics.symmetricDifference(.letters)
	static let specialAndNumbers = CharacterSet.numbers.union(.special)
}

private class LeakCheckStatus {
	private var cancelCallbacks =  [UUID: (Bool?) -> ()]()

	private var leakCheckResults = [String: Bool]()
	private var leakCheckCallbacks = [String: [(Bool?) -> ()]]()

	private let queue = DispatchQueue(label: "ch.illotros.snowhaze.pwvalidate.leakcheck.status")

	func result(for password: String) -> Bool? {
		return queue.sync { leakCheckResults[password] }
	}

	func result(for password: String, addingCallback callback: @escaping (Bool?) -> ()) -> (Bool?, Bool) {
		return queue.sync {
			let result = leakCheckResults[password]
			if result == nil {
				leakCheckCallbacks[password, default: []].append(callback)
				return (nil, leakCheckCallbacks[password]!.count > 1)
			} else {
				return (result, false)
			}
		}
	}

	func notify(result newResult: Bool?, for password: String) {
		queue.sync {
			let callbacks = leakCheckCallbacks[password] ?? []
			leakCheckCallbacks[password] = nil
			let result = newResult ?? leakCheckResults[password]
			leakCheckResults[password] = result
			DispatchQueue.main.async {
				for callback in callbacks {
					callback(result)
				}
			}
		}
	}

	func cancel() {
		queue.sync {
			for (_, callback) in cancelCallbacks {
				callback(nil)
			}
			cancelCallbacks = [:]
		}
	}

	func startWait(cancel: @escaping (Bool?) -> ()) -> () -> Bool {
		return queue.sync {
			let uuid = UUID()
			cancelCallbacks[uuid] = cancel
			return { [weak self] in
				guard let self = self else {
					return true
				}
				return self.queue.sync {
					let canceld = self.cancelCallbacks[uuid] == nil
					self.cancelCallbacks[uuid] = nil
					return canceld
				}
			}
		}
	}

	deinit {
		cancel()
	}
}

struct PasswordValidator {
	let patternChecks: PatternChecks
	let minLength: UInt
	let leakCheckDelay: TimeInterval?

	private let leakStatus = LeakCheckStatus()

	init(pattern: PatternChecks, length: UInt, leakCheckDelay: TimeInterval?) {
		self.patternChecks = pattern
		self.minLength = length
		self.leakCheckDelay = leakCheckDelay
	}

	private static let urlSession = SnowHazeURLSession()

	enum PatternChecks {
		case full
		case characterClasses
		case none

		var validatePatterns: Bool {
			switch self {
				case .full:				return true
				case .characterClasses:	return false
				case .none:				return false
			}
		}

		var validateCharacterClasses: Bool {
			switch self {
				case .full:				return true
				case .characterClasses:	return true
				case .none:				return false
			}
		}
	}

	static let weak = PasswordValidator(pattern: .none, length: 6, leakCheckDelay: 2)
	static let medium = PasswordValidator(pattern: .full, length: 8, leakCheckDelay: 2)
	static let simpleMedium = PasswordValidator(pattern: .characterClasses, length: 12, leakCheckDelay: 2)
	static let strong = PasswordValidator(pattern: .full, length: 15, leakCheckDelay: 2)
	static let strongOffline = PasswordValidator(pattern: .full, length: 15, leakCheckDelay: nil)

	struct Issues: OptionSet {
		let rawValue: UInt

		static let none: Issues = []
		static let tooShort = Issues(rawValue: 0x01)
		static let foundInList = Issues(rawValue: 0x02)
		static let noLowercaseLetter = Issues(rawValue: 0x04)
		static let noUppercaseLetter = Issues(rawValue: 0x08)
		static let noSpecialCharacter = Issues(rawValue: 0x10)
		static let noNumericalDigit = Issues(rawValue: 0x20)
		static let noNonLeadingUppercase = Issues(rawValue: 0x40)
		static let noNonTailingSpecialCharOrDigit = Issues(rawValue: 0x80)
		static let tooSimilar = Issues(rawValue: 0x100)
		static let networkError = Issues(rawValue: 0x200)
	}

	private func pwTooShort(_ password: String) -> Bool {
		return password.count < minLength
	}

	private static let map: [Character: Character] = [
		"a":		"4",
		"а":		"4",
		"д":		"4",
		"ч":		"4",
		"@":		"4",
		"i":		"1",
		"¡":		"1",
		"і":		"1",
		"l":		"1",
		"o":		"0",
		"о":		"0",
		"з":		"3",
		"e":		"3",
		"е":		"3",
		"€":		"3",
		"£":		"3",
		"w":		"3",
		"щ":		"3",
		"ш":		"3",
		"m":		"3",
		"м":		"3",
		"s":		"5",
		"ѕ":		"5",
		"t":		"7",
		"T":		"7",
		"т":		"7",
		"+":		"7",
		"÷":		"7",
		"±":		"7",
		"†":		"7",
		"‡":		"7",
		"$":		"5",
		"§":		"5",
		"z":		"2",
		"g":		"9",
		"!":		"1",
		"h":		"4",
		"н":		"4",
		"k":		"4",
		"к":		"4",
		"n":		"4",
		"ภ":			"4",
		"л":		"4",
		"и":		"4",
		"п":		"4",
		"ถุ":			"4",
		"^":		"4",
		"ˆ":		"4",
		"b":		"8",
		"ъ":		"8",
		"ь":		"8",
		"в":		"8",
		"ы":		"8",
		"6":		"8",
		"б":		"8",
		"¶":		"p",
		"р":		"p",
		"c":		"(",
		"с":		"(",
		"{":		"(",
		"<":		"(",
		"‹":		"(",
		"«":		"(",
		"©":		"(",
		"¢":		"(",
		"[":		"(",
		"}":		"?",
		">":		"?",
		"›":		"?",
		"»":		"?",
		"]":		"?",
		")":		"?",
		"¿":		"?",
		"d":		"8",
		"ð":		"8",
		"þ":		"8",
		"%":		"9",
		"&":		"9",
		"‰":		"9",
		"#":		"4",
		"æ":		"4",
		"œ":		"4",
		":":		"1",
		";":		"1",
		"j":		"1",
		".":		"0",
		",":		"0",
		"‚":		"0",
		" ̧":		"0",
		"x":		"0",
		"*":		"0",
		"×":		"0",
		"х":		"0",
		"q":		"9",
		"r":		"2",
		"г":		"2",
		"я":		"2",
		"®":		"2",
		"ƒ":		"f",
		"v":		"u",
		"y":		"9",
		"у":		"9",
		"¥":		"9",
		"\r":		"0",
		"\n":		"0",
		" ":		"0",
		"\u{0001}":	"0",
		"\u{0002}":	"0",
		"\u{0003}":	"0",
		"\u{0004}":	"0",
		"\u{0005}":	"0",
		"\u{0006}":	"0",
		"\u{0007}":	"0",
		"\u{0008}":	"0",
		"\u{0009}":	"0",
		"\u{000F}":	"0",
		"\u{0010}":	"0",
		"\u{0011}":	"0",
		"\u{0012}":	"0",
		"\u{0013}":	"0",
		"\u{0015}":	"0",
		"\u{0017}":	"0",
		"\u{0019}":	"0",
		"\u{001A}":	"0",
		"\u{001B}":	"0",
		"\u{001C}":	"0",
		"\u{001E}":	"0",
		"\u{001F}":	"0",
		"\u{007F}":	"0",
		"\u{0080}":	"0",
		"\u{0081}":	"0",
		"\u{0082}":	"0",
		"\u{0083}":	"0",
		"\u{0084}":	"0",
		"\u{0085}":	"0",
		"\u{0086}":	"0",
		"\u{0087}":	"0",
		"\u{0088}":	"0",
		"\u{0089}":	"0",
		"\u{008A}":	"0",
		"\u{008B}":	"0",
		"\u{008C}":	"0",
		"\u{008D}":	"0",
		"\u{008E}":	"0",
		"\u{008F}":	"0",
		"\u{0090}":	"0",
		"\u{0091}":	"0",
		"\u{0092}":	"0",
		"\u{0093}":	"0",
		"\u{0094}":	"0",
		"\u{0095}":	"0",
		"\u{0096}":	"0",
		"\u{0097}":	"0",
		"\u{0098}":	"0",
		"\u{0099}":	"0",
		"\u{009A}":	"0",
		"\u{009B}":	"0",
		"\u{009C}":	"0",
		"\u{009D}":	"0",
		"\u{009E}":	"0",
		"\u{009F}":	"0",
		"\u{00AD}":	"0",
		"\u{FEFF}":	"0",
		"ø":		"0",
		"°":		"0",
		"¤":		"0",
		"·":		"0",
		"•":		"0",
		"ю":		"0",
		"♥":			"0",
		"♣":			"0",
		"μ":		"u",
		"ц":		"u",
		"¬":		"-",
		"_":		"-",
		"~":		"-",
		" ̃":		"-",
		"—":		"-",
		"–":		"-",
		" ̈":		"-",
		" ̄":		"-",
		"=":		"-",
		"\'":		"1",
		"’":		"1",
		"\"":		"1",
		"“":		"1",
		"”":		"1",
		"„":		"1",
		"`":		"1",
		" ́":		"1",
		"‘":		"1",
		"|":		"1",
		"¦":		"1",
		"ๅ":			"1",
		"\\":		"/",
		"⁄":		"/",
	]

	private static func normalize(_ pw: String) -> String {
		let composed = pw.precomposedStringWithCompatibilityMapping
		let folded = composed.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: nil)
		return String(folded.map { PasswordValidator.map[$0] ?? $0 })
	}

	private func cancelLeakChecks() {
		leakStatus.cancel()
	}

	private static func leakCheckAPICall(for normalized: String, callback: @escaping (Bool?) -> ()) {
		let sodium = Sodium()
		let longSize = 16

		let normalized = normalized.bytes
		let short = sodium.genericHash.hash(message: normalized, outputLength: 2)!
		let long = sodium.genericHash.hash(message: normalized, outputLength: longSize)!
		var read = Set<[UInt8]>()
		read.insert(short)
		while read.count < 10 {
			read.insert(sodium.randomBytes.buf(length: 2)!)
		}
		let sorted = read.sorted { $0[0] < $1[0] || ($0[0] == $1[0] && $0[1] < $1[1]) }
		for key in sorted {
			let path = String(format: "%02x/%02x.b64", key[0], key[1])
			let url = URL(string: "https://api.snowhaze.com/pw-check/" + path)!
			PasswordValidator.urlSession.performDataTask(with: url) { data, response, error in
				guard key == short else {
					return
				}
				guard error == nil, let httpResponse = response as? HTTPURLResponse else {
					callback(nil)
					return
				}
				guard httpResponse.statusCode == 200, let data = data else {
					callback(nil)
					return
				}
				guard let decoded = Data(base64Encoded: data), decoded.count % longSize == 0 else {
					callback(nil)
					return
				}
				let bytes = Bytes(decoded)
				for i in 0 ..< bytes.count / longSize {
					if long == Bytes(bytes[i * longSize ..< (i + 1) * longSize]) {
						callback(true)
						return
					}
				}
				callback(false)
			}
		}
	}

	private func passwordInLeakedList(_ password: String, callback: @escaping (Bool?) -> ()) {
		guard let leakCheckDelay = leakCheckDelay else {
			return callback(false)
		}
		let canceled = leakStatus.startWait(cancel: callback)
		let status = leakStatus
		let normalized = PasswordValidator.normalize(password)
		if let result = status.result(for: normalized) {
			callback(result)
			return
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + leakCheckDelay) { [weak status] in
			guard !canceled(), let status = status else {
				return
			}
			let (result, pending) = status.result(for: normalized, addingCallback: callback)
			assert(!pending || result == nil)
			if pending {
				return
			} else if let result = result {
				callback(result)
				return
			}
			PasswordValidator.leakCheckAPICall(for: normalized) { [weak status] result in
				guard let status = status else {
					return
				}
				status.notify(result: result, for: normalized)
			}
		}
	}

	private func noLowercaseLetter(_ password: String) -> Bool {
		guard patternChecks.validateCharacterClasses else {
			return false
		}
		return password.firstIndex(with: .lowercaseLetters) == nil
	}

	private func noUppercaseLetter(_ password: String) -> Bool {
		guard patternChecks.validateCharacterClasses else {
			return false
		}
		return password.firstIndex(with: .uppercaseLetters) == nil
	}

	private func noSpecialChar(_ password: String) -> Bool {
		guard patternChecks.validateCharacterClasses else {
			return false
		}
		return password.firstIndex(with: .special) == nil
	}

	private func noNumDigit(_ password: String) -> Bool {
		guard patternChecks.validateCharacterClasses else {
			return false
		}
		return password.firstIndex(with: .numbers) == nil
	}

	private func noNonLeadingUppercase(_ password: String) -> Bool {
		guard patternChecks.validatePatterns else {
			return false
		}
		guard let upper = password.lastIndex(with: .uppercaseLetters) else {
			return true
		}
		guard let lower = password.firstIndex(with: .lowercaseLetters) else {
			return true
		}
		return upper <= lower
	}

	private func noNonTailingSpecialChar(_ password: String) -> Bool {
		guard patternChecks.validatePatterns else {
			return false
		}
		guard let alpha = password.lastIndex(with: .letters) else {
			return true
		}
		guard let special = password.firstIndex(with: .specialAndNumbers) else {
			return true
		}
		return alpha <= special
	}

	private func dist(s1: Substring, s2: Substring) -> Int {
		var row = [UInt](repeating: 0, count: s2.count + 1)
		row[0] = .max - 1
		var map = [[UInt]](repeating: row, count: s1.count + 1)
		map[0] = [UInt](repeating: .max - 1, count: s2.count + 1)
		map[0][0] = 0
		var index1 = s1.startIndex
		for i in 0 ..< s1.count {
			let c1 = s1[index1]
			index1 = s1.index(after: index1)
			var index2 = s2.startIndex
			for j in 0 ..< s2.count {
				let c2 = s2[index2]
				index2 = s2.index(after: index2)
				if c1 == c2 {
					map[i + 1][j + 1] = min(map[i][j], min(map[i + 1][j], map[i][j + 1]) + 1)
				} else {
					map[i + 1][j + 1] = min(map[i][j], min(map[i + 1][j], map[i][j + 1])) + 1
				}
			}
		}
		return Int(map[s1.count][s2.count])
	}

	func tooSimilar(password: String, blacklist: Set<String>) -> Bool {
		for element in blacklist {
			let forbidden = PasswordValidator.normalize(element)
			let password = PasswordValidator.normalize(password)
			let size = 4
			var score = 0
			guard forbidden.count >= size && password.count >= size else {
				continue
			}
			var forbiddenStart = forbidden.startIndex
			var forbiddenEnd = forbidden.index(forbiddenStart, offsetBy: size - 1)
			for _ in 0 ..< (forbidden.count - size + 1) {
				forbiddenEnd = forbidden.index(after: forbiddenEnd)
				let submail = forbidden[forbiddenStart ..< forbiddenEnd]
				forbiddenStart = forbidden.index(after: forbiddenStart)
				var pwStart = password.startIndex
				var pwEnd = password.index(pwStart, offsetBy: size - 1)
				for _ in 0 ..< (password.count - size + 1) {
					pwEnd = password.index(after: pwEnd)
					let subpw = password[pwStart ..< pwEnd]
					pwStart = password.index(after: pwStart)
					let distance = dist(s1: submail, s2: subpw)
					score += 100 / ((distance + 1) * (distance + 1) * (distance + 1))
				}
				assert(pwEnd == password.endIndex)
			}
			assert(forbiddenEnd == forbidden.endIndex)
			let allowance = (forbidden.count - size + 1) * (password.count - size + 1)
			if 2 * score / allowance > 4 {
				return true
			}
		}
		return false
	}

	func issues(for password: String, blacklist: Set<String> = [], callback: @escaping (Issues) -> ()) {
		var issues = Issues.none
		issues = pwTooShort(password) ? [issues, .tooShort] : issues
		issues = noLowercaseLetter(password) ? [issues, .noLowercaseLetter] : issues
		issues = noUppercaseLetter(password) ? [issues, .noUppercaseLetter] : issues
		issues = noSpecialChar(password) ? [issues, .noSpecialCharacter] : issues
		issues = noNumDigit(password) ? [issues, .noNumericalDigit] : issues
		issues = noNonLeadingUppercase(password) ? [issues, .noNonLeadingUppercase] : issues
		issues = noNonTailingSpecialChar(password) ? [issues, .noNonTailingSpecialCharOrDigit] : issues
		issues = tooSimilar(password: password, blacklist: blacklist) ? [issues, .tooSimilar] : issues
		guard issues == Issues.none else {
			callback(issues)
			return
		}
		passwordInLeakedList(password) { found in
			guard let found = found else {
				callback(Issues.networkError)
				return
			}
			callback( found ? .foundInList : .none )
		}
	}

	func validate(_ password: String, blacklist: Set<String> = [], callback: @escaping (Bool) -> ()) {
		return issues(for: password, blacklist: blacklist) { callback($0 == .none) }
	}
}
