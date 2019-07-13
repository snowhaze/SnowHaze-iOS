//
//  URLInjectionDetection.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

internal extension URL {
	private static let problematicJSFunctions = [
		(false, "alert"),
		(false, "eval"),
		(false, "fetch"),
		(true, "send"),
		(true, "createElement"),
		(true, "removeChild"),
		(true, "setAttribute"),
		(true, "createAttribute"),
		(true, "getElementById"),
		(true, "getElementsByName"),
		(true, "getElementsByTagName"),
		(true, "getElementsByClassName"),
		(true, "getElementsByTagNameNS"),
		(true, "querySelector"),
		(true, "querySelectorAll"),
	]
	private static let problematicJSModify = [
		"location",
		"cookie",
		"innerHTML",
		"src",
		"href",
	]
	private static let problematicJSReads = [
		"cookie",
		"innerHTML",
	]

	private static func genJSRx() -> Regex {
		let funcRxs = problematicJSFunctions.map { fn -> String in
			let (onObj, name) = fn
			let pref = onObj ? "\\w+\\W*." : ""
			return	pref + "\\W*\(name)\\W*\\(.*\\)" +
				"|\\).*" + pref + "\\W*\(name)\\W*\\("
		}
		let modRxs = problematicJSModify.map { name -> String in
			return	"\\w+\\W*\\.\\W*\(name)\\W*(\\.\\W*\\w+\\W*\\(.*\\)|\\W*=\\W*[\\w\"'+\\-{])|"
				+ "\\).*\\w+\\W*\\.\\W*\(name)\\W*\\.\\W*\\w+\\W*\\("
		}
		let readRxs = problematicJSReads.map { name -> String in
			return "\\w+\\W*=\\W*\\w+\\W*\\.\\W*\(name)"
		}
		let rx = (funcRxs + modRxs + readRxs).joined(separator: "|") + "|\\w+\\W*\\[(.*\".+\".*|.*'.+'.*)]"
		return Regex(pattern: rx)
	}

	private static let jsRx = genJSRx()
	private static let htlmRx = Regex(pattern: "<\\W*(/\\W*)?(\\w+\\W*:\\W*)?\\w+\\.*>")

	private static let sqliRx = Regex(pattern: "((\\(\\W*|.+\\Wunion(\\W|\\W.*\\W))select\\W.*(\\w|'.*'|\".*\"|\\*).*|.+\\Winsert(\\W|\\W.*\\W)into\\W.*\\w.*(\\Wvalues\\W|\\Wselect\\W)|\\Wupdate\\W.*\\w.*\\Wset\\W.*\\w.*=.+|.+\\Wdelete(\\W|\\W.*\\W)from\\W.*\\w)", options: .caseInsensitive)

	private static let jsCommentRx = Regex(pattern: "//[^\r\n'\"]*(?:$|[\r\n])|/\\*(?:[^*'\"]|\\*(?!/))*\\*/")

	private func uncomment(_ js: String) -> String {
		return js.replace(URL.jsCommentRx, template: "")
	}

	private func isDangerous(_ string: String, reduced: Bool = false) -> Bool {
		let unescaped = string.unescapedHTMLEntities
		return	uncomment(unescaped).matches(URL.jsRx) ||
				unescaped.matches(URL.htlmRx) ||
				(!reduced && unescaped.matches(URL.sqliRx))
	}

	var potentialXSS: Bool {
		let components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
		if isDangerous(components.path) {
			return true
		}
		if let fragment = components.fragment, isDangerous(fragment, reduced: true) {
			return true
		}
		for param in components.queryItems ?? [] {
			if let value = param.value, isDangerous(value) {
				return true
			}
		}
		return false
	}
}
