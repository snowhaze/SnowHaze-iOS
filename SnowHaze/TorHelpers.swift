//
//  TorHelpers.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

// TODO: support other schemes
extension URL {
	var isTorURL: Bool {
		return ["tor", "tors"].contains(normalizedScheme)
	}

	var canTorify: Bool {
		return ["http", "https"].contains(normalizedScheme)
	}

	var detorified: URL? {
		guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
			return nil
		}
		guard let scheme = components.scheme?.lowercased(), ["tor", "tors"].contains(scheme) else {
			return self
		}
		if scheme == "tor" {
			components.scheme = "http"
		} else {
			components.scheme = "https"
		}
		return components.url
	}

	var torified: URL? {
		guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
			return nil
		}
		guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
			return self
		}
		if scheme == "http" {
			components.scheme = "tor"
		} else {
			components.scheme = "tors"
		}
		return components.url
	}
}
