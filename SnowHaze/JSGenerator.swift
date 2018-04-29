//
//  JSGenerator.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class JSGenerator {

	static var scriptCache: [String : JSGenerator] = [:]

	let script: String

	init?(scriptName: String) {
		guard let path = Bundle.main.path(forResource: scriptName, ofType: "js") else {
			return nil
		}
		var encoding = String.Encoding.utf8
		guard let result = try? String(contentsOfFile: path, usedEncoding: &encoding) else {
			return nil
		}
		script = result
		JSGenerator.scriptCache[scriptName] = self
	}

	static func named(_ name: String) -> JSGenerator? {
		if let generator = scriptCache[name] {
			return generator
		}
		return JSGenerator(scriptName: name)
	}

	private(set) lazy var parameters: Set<String> = {
		let list = self.script.allMatches("(?<=\\$)\\w+(?=\\$)") ?? []
		let strings = list.map { String($0) }
		return Set<String>(strings)
	}()

	func generate(with parameters: [String : AnyObject] = [:]) -> String? {
		guard parameters.count == self.parameters.count else {
			return nil
		}
		var script = self.script
		//If there are parameters to set, set them now
		for (parameter, value) in parameters {
			if !self.parameters.contains(parameter) {
				return nil
			}
			let rawOption = JSONSerialization.ReadingOptions.allowFragments.rawValue
			let option = JSONSerialization.WritingOptions(rawValue: rawOption)
			guard let valueData = try? JSONSerialization.data(withJSONObject: value, options: option) else {
				return nil
			}
			guard let valueString = String(data: valueData, encoding: .utf8) else {
				return nil
			}
			let escapedValue = Regex.escapedTemplate(for: valueString)
			script = script.replace("\\$\(parameter)\\$", template: escapedValue)
		}
		return script
	}
}
