//
//  JSONFetcher.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class JSONFetcher: DataFetcher {
	func fetchJSON(from url: URL, callback: @escaping (Any?) -> Void) {
		fetch(url) { (data) -> Void in
			guard let data = data else {
				callback(nil)
				return
			}
			let json = try? JSONSerialization.jsonObject(with: data)
			callback(json)
		}
	}
}
