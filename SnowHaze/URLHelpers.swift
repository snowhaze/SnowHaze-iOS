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

	var isOnion: Bool {
		return normalizedHost?.hasSuffix(".onion") ?? false
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

extension URLProtectionSpace {
	var normalizedHost: String {
		return host.lowercased()
	}
}

extension WKSecurityOrigin {
	var normalizedHost: String {
		return host.lowercased()
	}
}

extension WKNavigationAction {
	var loadedMainURL: URL? {
		guard targetFrame?.isMainFrame ?? false else {
			return nil
		}
		return request.url
	}
}
