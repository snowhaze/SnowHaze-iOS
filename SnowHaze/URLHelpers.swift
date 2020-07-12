//
//  URLHelpers.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

extension URL {
	var normalizedScheme: String? {
		return scheme?.lowercased()
	}

	var normalizedHost: String? {
		return host?.lowercased()
	}
}

extension URLComponents {
	var normalizedScheme: String? {
		return scheme?.lowercased()
	}

	var normalizedHost: String? {
		return host?.lowercased()
	}
}
