//
//  URLRequestHelpers.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

extension URLRequest {
	mutating func setFormEncoded(data: [String: String]) {
		let str = data.reduce("") { pre, data in
			let (key, value) = data
			var res = pre
			if !res.isEmpty {
				res += "&"
			}
			res += key.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
			res += "="
			res += value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
			return res
		}
		let data = str.data(using: .utf8)!
		httpMethod = "POST"
		httpBody = data
		setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
		setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
	}

	func headers(set headers: [String: String]) -> Bool {
		for (key, value) in headers {
			if allHTTPHeaderFields?[key] != value {
				return false
			}
		}
		return true
	}

	func headers(unset notHeaders: Set<String>) -> Bool {
		for key in notHeaders {
			if allHTTPHeaderFields?[key] != nil {
				return false
			}
		}
		return true
	}

	func changedHeaders(set setHeaders: [String: String], clear clearHeaders: Set<String>) -> URLRequest {
		var ret = self
		var headers = ret.allHTTPHeaderFields ?? [:]
		for (key, value) in setHeaders {
			headers[key] = value
		}
		for key in clearHeaders {
			headers[key] = nil
		}
		ret.allHTTPHeaderFields = headers
		return ret
	}

	func with(url: URL?) -> URLRequest {
		var ret = self
		ret.url = url
		return ret
	}

	var isHTTPGet: Bool {
		return httpMethod == "GET"
	}
}
