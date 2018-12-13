//
//  HTMLParser.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

/**
 *	Primitive HTML parser. Should only be used on controlled input (e.g. to format localized strings).
 */
class HTMLParser {
	private let multipleSpaceRx = Regex(pattern: "\\s+")
	private let brRx = Regex(pattern: "< ?br ?/? ?>")
	private let pStartRx = Regex(pattern: "< ?p ?>")
	private let pEndRx = Regex(pattern: "< ?(p ?/?|/?p ?) ?>")
	private let modRx = Regex(pattern: "< ?(u|strong) ?>([^<]*)< ?/ ?\\1 ?>")

	let attributedString: NSAttributedString
	var string: String {
		return attributedString.string
	}

	init(html: String, boldFont: UIFont) {
		var tmp = html.replace(multipleSpaceRx, template: " ")
		tmp = tmp.replace(brRx, template: "\n")
		tmp = tmp.replace(pStartRx, template: "")
		tmp = tmp.replace(pEndRx, template: "\n\n")
		let matches = modRx.regex!.matches(in: tmp, range: NSRange(tmp.startIndex ..< tmp.endIndex, in: tmp))

		enum Mod: String {
			case Underline = "u"
			case Strong = "strong"
		}
		var offset = 0
		let nsString = tmp as NSString
		var mods = [(Mod, NSRange)]()
		for match in matches {
			let modRange = match.range(at: 1)
			var contentRange = match.range(at: 2)
			let mod = Mod(rawValue: nsString.substring(with: modRange))!
			contentRange.location = match.range.location - offset
			mods.append((mod, contentRange))
			offset += match.range.length - contentRange.length
		}
		tmp = tmp.replace(modRx, template: "$2")
		let tmpAttrString = NSMutableAttributedString(string: tmp)
		for (mod, range) in mods {
			switch mod {
				case .Underline:	tmpAttrString.addAttribute(NSAttributedString.Key.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
				case .Strong:		tmpAttrString.addAttribute(NSAttributedString.Key.font, value: boldFont, range: range)
			}
		}
		attributedString = NSAttributedString(attributedString: tmpAttrString)
	}
}
