//
//  Search.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

protocol SearchListener: class {
	func search(_ search: Search, indexDidUpdateTo index: UInt, of count: UInt)
}

class Search {
	private let tab: Tab
	private let javascriptCount = JSGenerator.named("SearchInit")!
	private let javascriptSearch = JSGenerator.named("SearchSelect")!

	weak var listener: SearchListener?

	//The actual match index. If the value of matchIndex is equal to count the last match is reached
	private(set) var matchIndex: UInt = 0 {
		didSet {
			listener?.search(self, indexDidUpdateTo: matchIndex, of: matchCount)
		}
	}
	private(set) var matchCount: UInt = 0

	private var searchInitiated = false

	var searchPattern: String {
		didSet {
			countMatches()
		}
	}

	init(tab: Tab, searchPattern: String = "") {
		self.tab = tab
		self.searchPattern = searchPattern
		countMatches()
	}

	private func countMatches() {
		let search = searchPattern
		guard let script = javascriptCount.generate(with: ["searchPattern" : search as AnyObject]) else {
			return
		}
		matchCount = 0
		searchInitiated = false
		let throttle: TimeInterval
		switch search.count {
			case 1:		throttle = 1
			case 2:		throttle = 0.5
			case 3:		throttle = 0.5
			default:	throttle = 0
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + throttle) { [weak self] in
			guard let self = self, self.searchPattern == search, !self.searchInitiated else {
				return
			}
			self.searchInitiated = true
			self.tab.controller?.evaluate(script) { (result, error) -> () in
				DispatchQueue.main.async { [weak self] in
					guard let self = self, let count = result as? NSNumber, search == self.searchPattern else {
						return
					}
					self.matchCount = count.uintValue
					self.matchIndex = search.isEmpty ? 0 : 1
				}
			}
		}
	}

	private func highlight(backwards back: Bool) {
		guard matchCount > 0 && matchIndex > 0 else {
			return
		}
		let newMatchIndex: UInt
		if back {
			if matchIndex > 1 {
				newMatchIndex = matchIndex - 1
			} else {
				newMatchIndex = matchCount
			}
		} else {
			if matchIndex < matchCount {
				newMatchIndex = matchIndex + 1
			} else {
				newMatchIndex = min(1, matchCount)
			}
		}
		let parameters = ["select": NSNumber(value: newMatchIndex as UInt), "deselect": NSNumber(value: matchIndex as UInt)]
		guard let script = javascriptSearch.generate(with: parameters) else {
			return
		}
		matchIndex = newMatchIndex

		tab.controller?.evaluate(script, completionHandler: nil)
	}

	func highlightNext() {
		highlight(backwards: false)
	}

	func highlightPrev() {
		highlight(backwards: true)
	}
}
