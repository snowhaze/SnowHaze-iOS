//
//  ContentType.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

struct ContentTypes: OptionSet {
	let rawValue: Int64

	static let document 				= ContentTypes(rawValue: 1 << 0)
	static let image 					= ContentTypes(rawValue: 1 << 1)
	static let styleSheet				= ContentTypes(rawValue: 1 << 2)
	static let script					= ContentTypes(rawValue: 1 << 3)
	static let font						= ContentTypes(rawValue: 1 << 4)
	static let raw						= ContentTypes(rawValue: 1 << 5)
	static let svgDocument				= ContentTypes(rawValue: 1 << 6)
	static let media					= ContentTypes(rawValue: 1 << 7)
	static let popup					= ContentTypes(rawValue: 1 << 8)
	static let thirdPartyScripts		= ContentTypes(rawValue: 1 << 20)

	static let allTypes: ContentTypes	= [document, image, styleSheet, script, font, raw, svgDocument, media, popup, thirdPartyScripts]
	static let imageTypes: ContentTypes	= [image, svgDocument]
	static let none: ContentTypes		= []
}
