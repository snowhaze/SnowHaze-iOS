//
//  StringURLHelpers.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

private let domainRx = Regex(pattern: "^https?://(?:[^@/?#]+@)?([^:/\\s?#]+)(?::|/|#|\\?|$)")

internal extension String {
	var punycodeExtension: String? {
		guard let replaced = ("http://" + self).punycodeURL?.absoluteString else {
			return nil
		}
		let idx = replaced.index(replaced.startIndex, offsetBy: 7)
		return String(replaced[idx...])
	}

	var punycodeURL: URL? {
		if let url = validated(URL(string: self)) {
			return url
		}
		guard components(separatedBy: .whitespacesAndNewlines).count == 1 else {
			return nil
		}
		guard let match = matchData(domainRx).first, match.rangesCount == 2 else {
			return nil
		}
		let domain = String(match.match(at: 1))
		let encoded = Punycode.encode(domain: domain)
		let replaced = match.replaceMatch(at: 1, with: encoded)
		return validated(URL(string: replaced))
	}

	var isLocalhostExtendable: Bool {
		guard let url = validated(URL(string: "http://" + self.lowercased())) else {
			return false
		}
		return url.host == "localhost"
	}

	var hasWPrefix: Bool {
		return hasPrefix("www.") || hasPrefix("w3.") || hasPrefix("www3.")
	}

	private func validated(_ url: URL?) -> URL? {
		guard let url = url else {
			return nil
		}
		guard let scheme = url.scheme?.lowercased() else {
			return nil
		}
		guard url.absoluteString.components(separatedBy: .whitespacesAndNewlines).count == 1 else {
			return nil
		}
		if scheme == "data" && !url.absoluteString.contains(" ") {
			return url
		}
		guard let host = url.host else {
			return nil
		}
		guard WebViewURLSchemes.contains(scheme) else {
			return nil
		}
		let ok = host.contains(".") || host == "localhost" || host.contains(":")
		return ok ? url : nil
	}

	func extendToURL(https: Bool = false, www: Bool = false) -> URL? {
		let prefix = (https ? "https" : "http") + "://" + (www ? "www." : "")
		return validated(URL(string: prefix + self))
	}
}

private let htmlEntities: [Substring: UInt32] = [
	"quot":		34,
	"ldquo":	8220,
	"rdquo":	8221,
	"lsquo":	8216,
	"rsquo":	8217,
	"prime":	8242,
	"Prime":	8243,
	"amp":		38,
	"ndash":	8211,
	"mdash":	8212,
	"hellip":	8230,
	"lt":		60,
	"gt":		62,
	"nbsp":		160,
	"thinsp":	8201,
	"ensp":		8194,
	"emsp":		8195,
	"iexcl":	161,
	"cent":		162,
	"pound":	163,
	"curren":	164,
	"yen":		165,
	"brvbar":	166,
	"sect":		167,
	"uml":		168,
	"copy":		169,
	"ordf":		170,
	"laquo":	171,
	"not":		172,
	"shy":		173,
	"reg":		174,
	"macr":		175,
	"deg":		176,
	"plusmn":	177,
	"sup2":		178,
	"sup3":		179,
	"acute":	180,
	"micro":	181,
	"para":		182,
	"middot":	183,
	"cedil":	184,
	"sup1":		185,
	"ordm":		186,
	"raquo":	187,
	"frac14":	188,
	"frac12":	189,
	"frac34":	190,
	"iquest":	191,
	"Agrave":	192,
	"Aacute":	193,
	"Acirc":	194,
	"Atilde":	195,
	"Auml":		196,
	"Aring":	197,
	"AElig":	198,
	"Ccedil":	199,
	"Egrave":	200,
	"Eacute":	201,
	"Ecirc":	202,
	"Euml":		203,
	"Igrave":	204,
	"Iacute":	205,
	"Icirc":	206,
	"Iuml":		207,
	"ETH":		208,
	"Ntilde":	209,
	"Ograve":	210,
	"Oacute":	211,
	"Ocirc":	212,
	"Otilde":	213,
	"Ouml":		214,
	"times":	215,
	"Oslash":	216,
	"Ugrave":	217,
	"Uacute":	218,
	"Ucirc":	219,
	"Uuml":		220,
	"Yacute":	221,
	"THORN":	222,
	"szlig":	223,
	"agrave":	224,
	"aacute":	225,
	"acirc":	226,
	"atilde":	227,
	"auml":		228,
	"aring":	229,
	"aelig":	230,
	"ccedil":	231,
	"egrave":	232,
	"eacute":	233,
	"ecirc":	234,
	"euml":		235,
	"igrave":	236,
	"iacute":	237,
	"icirc":	238,
	"iuml":		239,
	"eth":		240,
	"ntilde":	241,
	"ograve":	242,
	"oacute":	243,
	"ocirc":	244,
	"otilde":	245,
	"ouml":		246,
	"divide":	247,
	"oslash":	248,
	"ugrave":	249,
	"uacute":	250,
	"ucirc":	251,
	"uuml":		252,
	"yacute":	253,
	"thorn":	254,
	"yuml":		255,
	"Amacr":	256,
	"amacr":	257,
	"Abreve":	258,
	"abreve":	259,
	"Aogon":	260,
	"aogon":	261,
	"Cacute":	262,
	"cacute":	263,
	"Ccirc":	264,
	"ccirc":	265,
	"Cdod":		266,
	"cdot":		267,
	"Ccaron":	268,
	"ccaron":	269,
	"Dcaron":	270,
	"dcaron":	271,
	"Dstrok":	272,
	"dstrok":	273,
	"Emacr":	274,
	"emacr":	275,
	"Edot":		278,
	"edot":		279,
	"Eogon":	280,
	"eogon":	281,
	"Ecaron":	282,
	"ecaron":	283,
	"Gcirc":	284,
	"gcirc":	285,
	"Gbreve":	286,
	"gbreve":	287,
	"GDot":		288,
	"gdot":		289,
	"Gcedil":	290,
	"gcedil":	291,
	"Hcirc":	292,
	"hcirc":	293,
	"Hstrok":	294,
	"hstrok":	295,
	"Itilde":	296,
	"itilde":	297,
	"Imacr":	298,
	"imacr":	299,
	"Iogon":	302,
	"iogon":	303,
	"Idot":		304,
	"inodot":	305,
	"IJlog":	306,
	"ijlig":	307,
	"Jcirc":	308,
	"jcirc":	309,
	"Kcedil":	310,
	"kcedli":	311,
	"kgreen":	312,
	"Lacute":	313,
	"lacute":	314,
	"Lcedil":	315,
	"lcedil":	316,
	"Lcaron":	317,
	"lcaron":	318,
	"Lmodot":	319,
	"lmidot":	320,
	"Lstrok":	321,
	"lstrok":	322,
	"Nacute":	323,
	"nacute":	324,
	"Ncedil":	325,
	"ncedil":	326,
	"Ncaron":	327,
	"ncaron":	328,
	"napos":	329,
	"ENG":		330,
	"eng":		331,
	"Omacr":	332,
	"omacr":	333,
	"Odblac":	336,
	"odblac":	337,
	"OElig":	338,
	"oelig":	339,
	"Racute":	340,
	"racute":	341,
	"Rcedil":	342,
	"rcedil":	343,
	"Rcaron":	344,
	"rcaron":	345,
	"Sacute":	346,
	"sacute":	347,
	"Scirc":	348,
	"scirc":	349,
	"Scedil":	350,
	"scedil":	351,
	"Scaron":	352,
	"scaron":	353,
	"Tcedil":	354,
	"tcedil":	355,
	"Tcaron":	356,
	"tcaron":	357,
	"Tstrok":	358,
	"tstrok":	359,
	"Utilde":	360,
	"utilde":	361,
	"Umacr":	362,
	"umacr":	363,
	"Ubreve":	364,
	"ubeve":	365,
	"Uring":	366,
	"uring":	367,
	"Udblac":	368,
	"udblac":	369,
	"Uogon":	370,
	"uogon":	371,
	"Wcirc":	372,
	"wcirc":	373,
	"Ycirc":	374,
	"ycirc":	375,
	"Yuml":		376,
	"Zacute":	377,
	"zacute":	378,
	"Zdot":		379,
	"zdot":		380,
	"Zcaron":	381,
	"zcaron":	382,
	"fnof":		402,
	"imped":	437,
	"gacute":	501,
	"jmath":	567,
	"trade":	8482
]

internal extension String {
	private static let rx: Regex = {
		let rxCmp = htmlEntities.keys.sorted(by: { $0.count > $1.count }).map { Regex.escapedPattern(for: String($0)) }
		let pattern = "&(?:#?(x[0-9a-fA-F]{1,7}|[0-9]{1,7})|(\(rxCmp.joined(separator: "|"))));?"
		return Regex(pattern: pattern)
	}()

	var unescapedHTMLEntities: String {
		var result = ""
		var pos = startIndex
		while let match = String.rx.firstMatch(in: self, range: pos ..< endIndex) {
			let num = match.match(at: 1)
			let name = match.match(at: 2)
			let entityNum: UInt32
			if let s = name {
				entityNum = htmlEntities[s]!
			} else {
				let isHex = num!.hasPrefix("x") || num!.hasPrefix("X")
				let text = isHex ? num![num!.index(after: num!.startIndex)...] : num!
				entityNum = UInt32(text, radix: isHex ? 16 : 10)!
			}
			let range = match.range()!
			guard let scalar = UnicodeScalar(entityNum) else {
				result += self[pos ..< range.upperBound]
				pos = range.upperBound
				continue
			}
			let value = String(Character(scalar))
			result += self[pos ..< range.lowerBound] + value
			pos = range.upperBound
		}
		result  += self[pos ..< endIndex]
		return result
	}
}
