//
//  UIColor+SnowHazeColors.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

extension UIColor {
	static let bar						= UIColor(red:  50 / 255.0, green:  47 / 255.0, blue:  56 / 255.0, alpha: 1   )
	static let button					= UIColor(red: 162 / 255.0, green: 135 / 255.0, blue:  84 / 255.0, alpha: 1   )
	static let separator				= UIColor(red: 200 / 255.0, green: 199 / 255.0, blue: 204 / 255.0, alpha: 1   )
	static let darkSeparator			= UIColor(red:  92 / 255.0, green:  94 / 255.0, blue: 102 / 255.0, alpha: 1   )
	static let background				= UIColor(red:  49 / 255.0, green:  43 / 255.0, blue:  53 / 255.0, alpha: 1   )
	static let switchOff				= UIColor(red: 181 / 255.0, green: 181 / 255.0, blue: 181 / 255.0, alpha: 1   )
	static let switchOn					= UIColor(red: 180 / 255.0, green: 150 / 255.0, blue:  89 / 255.0, alpha: 1   )
	static let localSettingsOnSubtitle	= UIColor(red: 168 / 255.0, green: 126 / 255.0, blue:  45 / 255.0, alpha: 1   )
	static let deselectedTutorialPage	= UIColor(red: 181 / 255.0, green: 166 / 255.0, blue: 170 / 255.0, alpha: 1   )
	static let selectedTutorialPage		= UIColor(red: 191 / 255.0, green: 151 / 255.0, blue:  90 / 255.0, alpha: 1   )
	static let tutorialTextBG			= UIColor(red: 	42 / 255.0, green:  41 / 255.0, blue:  45 / 255.0, alpha: 1   )
	static let tutorialTextBGSeparator	= UIColor(red: 194 / 255.0, green: 153 / 255.0, blue:  90 / 255.0, alpha: 0.78)
	static let tutorialSecondaryButton	= UIColor(red:  54 / 255.0, green:  51 / 255.0, blue:  56 / 255.0, alpha: 1   )
	static let tutorialButtonBorder		= UIColor(red: 150 / 255.0, green: 150 / 255.0, blue: 150 / 255.0, alpha: 1   )
	static let tutorialIconBorder		= UIColor(red: 188 / 255.0, green: 186 / 255.0, blue: 189 / 255.0, alpha: 1   )

	static let veryGoodPrivacy			= UIColor(red:  71 / 255.0, green: 167 / 255.0, blue:  36 / 255.0, alpha: 1   )
	static let goodPrivacy				= UIColor(red: 120 / 255.0, green: 218 / 255.0, blue:  85 / 255.0, alpha: 1   )
	static let okPrivacy				= UIColor(red: 255 / 255.0, green: 217 / 255.0, blue:  68 / 255.0, alpha: 1   )
	static let passablePrivacy			= UIColor(red: 247 / 255.0, green: 167 / 255.0, blue:  48 / 255.0, alpha: 1   )
	static let badPrivacy				= UIColor(red: 241 / 255.0, green: 119 / 255.0, blue:  60 / 255.0, alpha: 1   )
	static let veryBadPrivacy			= UIColor(red: 232 / 255.0, green:  15 / 255.0, blue:  30 / 255.0, alpha: 1   )

	static let httpsStats				= UIColor(red: 136 / 255.0, green: 176 / 255.0, blue:   0 / 255.0, alpha: 1   )
	static let trackerStats				= UIColor(red: 200 / 255.0, green: 113 / 255.0, blue:  55 / 255.0, alpha: 1   )
	static let cookieStats				= UIColor(red:  44 / 255.0, green: 137 / 255.0, blue: 160 / 255.0, alpha: 1   )
	static let vpnStats					= UIColor(red: 160 / 255.0, green:  44 / 255.0, blue:  90 / 255.0, alpha: 1   )

	static let title					= UIColor(white: 0.98 , alpha: 1  )
	static let darkTitle				= UIColor(white: 0.665, alpha: 1  )
	static let popover					= UIColor(white: 0.91 , alpha: 1  )
	static let popoverDismiss			= UIColor(white: 0    , alpha: 0.3)
	static let subtitle					= UIColor(white: 0.75 , alpha: 1  )
	static let localSettingsTitle		= UIColor(white: 0.4  , alpha: 1  )
	static let localSettingsOffSubtitle	= UIColor(white: 0.71 , alpha: 1  )
	static let settingsIcon				= UIColor(white: 0.96 , alpha: 1  )
	static let pageInfoTitleBG			= UIColor(white: 0.6  , alpha: 1  )
	static let pageInfoEvenCellBG		= UIColor(white: 0.85 , alpha: 1  )
	static let pageInfoOddCellBG		= UIColor(white: 0.95 , alpha: 1  )

	static let httpWarning				= okPrivacy

	var hex: String {
		var red: CGFloat = 0
		var green: CGFloat = 0
		var blue: CGFloat = 0
		getRed(&red, green: &green, blue: &blue, alpha: nil)
		let redInt = Int(red * 255 + 0.5)
		let greenInt = Int(green * 255 + 0.5)
		let blueInt = Int(blue * 255 + 0.5)
		return String(format: "%.2X%.2X%.2X", redInt, greenInt, blueInt)
	}
}
