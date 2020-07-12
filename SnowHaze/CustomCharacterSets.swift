//
//  CustomCharacterSets.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

extension CharacterSet {
	static let profileForebidden = CharacterSet(charactersIn: "\"'\n\r\\")
	static let safebrowsingAllowedCharacters = CharacterSet(charactersIn: "!\"$&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")
	static let urlQueryReserved = CharacterSet(charactersIn: ";/?:@&=+$,")
	static let urlQueryValueAllowed = urlQueryAllowed.subtracting(urlQueryReserved)
}
