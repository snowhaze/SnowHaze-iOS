//
//  Regex.swift
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

struct Regex {
	struct Match {
		let raw: NSTextCheckingResult
		let needle: String
		init(_ dat: NSTextCheckingResult, _ str: String) {
			raw = dat
			needle = str
		}

		var rangesCount: Int {
			return raw.numberOfRanges
		}

		func range(at index: Int = 0) -> Range<String.Index>? {
			return Range(raw.range(at: index), in: needle)
		}

		func match(at index: Int = 0) -> Substring! {
			if let range = range(at: index) {
				return needle[range]
			} else {
				return nil
			}
		}

		func replaceMatch<S: StringProtocol>(at index: Int, with replacement: S) -> String {
			let range = Range(raw.range(at: index), in: needle)!
			return needle.replacingCharacters(in: range, with: replacement)
		}
	}
	var pattern: String {
		didSet {
			updateRegex()
		}
	}
	var expressionOptions: NSRegularExpression.Options {
		didSet {
			updateRegex()
		}
	}
	var matchingOptions: NSRegularExpression.MatchingOptions

	var regex: NSRegularExpression?

	init(pattern: String, options: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) {
		self.pattern = pattern
		self.expressionOptions = options
		self.matchingOptions = matchingOptions
		updateRegex()
	}

	mutating func updateRegex() {
		regex = try? NSRegularExpression(pattern: pattern, options: expressionOptions)
	}

	func firstMatch(in needle: String, range: Range<String.Index>? = nil) -> Match? {
		let range = range == nil ? needle.range : NSRange(range!, in: needle)
		if let res = regex?.firstMatch(in: needle, options: matchingOptions, range: range) {
			return Match(res, needle)
		}
		return nil
	}

	static func escapedTemplate(for original: String) -> String {
		return NSRegularExpression.escapedTemplate(for: original)
	}

	static func escapedPattern(for original: String) -> String {
		return NSRegularExpression.escapedPattern(for: original)
	}
}

extension String {
	func matchData(_ pattern: Regex) -> [Regex.Match] {
		if let regex = pattern.regex {
			return regex.matches(in: self, options: pattern.matchingOptions, range: range).map { Regex.Match($0, self) }
		}
		return []
	}

	func matches(_ pattern: Regex) -> Bool {
		if let regex = pattern.regex {
			return regex.firstMatch(in: self, options: pattern.matchingOptions, range: range) != nil
		}
		return false
	}

	func firstMatch(_ pattern: Regex) -> Substring? {
		guard let regex = pattern.regex else {
			return nil
		}
		guard let match = regex.firstMatch(in: self, options: pattern.matchingOptions, range: self.range) else {
			return nil
		}
		return self[Range(match.range, in: self)!]
	}

	fileprivate var range: NSRange {
		return NSRange(startIndex ..< endIndex, in: self)
	}

	func matches(_ patternString: String) -> Bool {
		return matches(Regex(pattern: patternString))
	}

	func allMatches(_ patternString: String) -> [Substring]? {
		return allMatches(Regex(pattern: patternString))
	}

	func allMatches(_ regex: Regex) -> [Substring]? {
		guard let exp = regex.regex else {
			return nil
		}
		let matches = exp.matches(in: self, options: regex.matchingOptions, range: range)
		return matches.map { check in
			return self[Range(check.range, in: self)!]
		}
	}

	func firstMatch(_ patternString: String) -> Substring? {
		return firstMatch(Regex(pattern: patternString))
	}

	func replace(_ pattern: Regex, template: String) -> String {
		if let regex = pattern.regex {
			return regex.stringByReplacingMatches(in: self, options: pattern.matchingOptions, range: range, withTemplate: template)
		}
		return self
	}

	func replace(_ pattern: String, template: String) -> String {
		return replace(Regex(pattern: pattern), template: template)
	}
}

class RegexCache {
	private static func syncToMain<T>(_ work: () -> T) -> T {
		return Thread.isMainThread ? work() : DispatchQueue.main.sync(execute: work)
	}

	public static let shared = RegexCache()

	private let options: (NSRegularExpression.Options, NSRegularExpression.MatchingOptions)

#if os(iOS)
	var observer: NSObjectProtocol?
#endif

	private lazy var cache: [String: Regex] = {
		let ret = [String: Regex]()
#if os(iOS)
		RegexCache.syncToMain {
			let name = UIApplication.didReceiveMemoryWarningNotification
			let o = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
				self?.cache = [:]
			}
			observer = o
		}
#endif
		return ret
	}()

	public init(options: NSRegularExpression.Options = [], matchingOptions: NSRegularExpression.MatchingOptions = []) {
		self.options = (options, matchingOptions)
	}

	public func get(for pattern: String) -> Regex {
		if let cached = cache[pattern] {
			return cached
		}
		let ret = Regex(pattern: pattern, options: options.0, matchingOptions: options.1)
		cache[pattern] = ret
		return ret
	}

#if os(iOS)
	deinit {
		if let o = observer {
			RegexCache.syncToMain {
				NotificationCenter.default.removeObserver(o)
			}
		}
	}
#endif
}
