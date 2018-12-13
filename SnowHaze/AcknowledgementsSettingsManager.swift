//
//  AcknowledgementsSettingsManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class AcknowledgementsSettingsManager: SettingsViewManager {
	override func html() -> String {
		let format = NSLocalizedString("acknowledgements settings explanation format", comment: "format for explanations of the acknowledgements settings tab")
		return String(format: format, versionDescription)
	}

	var textViews = [Int: UITextView]()

	private func textView(forSection section: Int) -> UITextView {
		if let textView = textViews[section] {
			return textView
		}
		let text: String
		switch section {
			case 1:		text = OnePasswordExtensionLicense
			case 2:		text = SQLCipherLicense
			case 3:		text = EasyPrivacyLicense
			case 4:		text = TexGyreLicense
			case 5:		text = PhishTankLicense
			case 6:		text = ReadabilityLicense
			case 7:		text = SimplePingLicense
			default:	fatalError("invalid section index")
		}
		let textView = UITextView()
		UIFont.setSnowHazeFont(on: textView)
		textView.text = text
		textView.isEditable = false
		textView.textColor = .lightText
		textView.backgroundColor = .clear
		textView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		textView.alwaysBounceVertical = false
		textViews[section] = textView
		return textView
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessmentResult.color(for: .good)
	}

	override var numberOfSections: Int {
		return 8
	}

	override func numberOfRows(inSection section: Int) -> Int {
		return section == 0 ? 0 : 1
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		if section == 0 {
			return super.heightForHeader(inSection: section)
		} else if section == 1 {
			return 30
		} else {
			return 50
		}
	}

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = super.getCell(for: tableView)
		for view in cell.subviews {
			if view is UITextView {
				view.removeFromSuperview()
			}
		}
		let textView = self.textView(forSection: indexPath.section)
		textView.frame = cell.bounds.insetBy(dx: 10, dy: 0)
		cell.addSubview(textView)
		tableView.separatorStyle = .none
		return cell
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		let textView = self.textView(forSection: indexPath.section)
		let text = textView.text
		let width = controller.tableView.bounds.width
		let rect = text?.boundingRect(with: CGSize(width: width - 40, height: 10000), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font : textView.font!], context: nil)
		return rect!.size.height + 20
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		return section == 0 ? super.heightForFooter(inSection: section) : 0
	}

	override func titleForHeader(inSection section: Int) -> String? {
		switch section {
			case 0:		return super.titleForHeader(inSection: section)
			case 1:		return "1PasswordExtension".localizedUppercase
			case 2:		return "SQLCipher".localizedUppercase
			case 3:		return "EasyPrivacy".localizedUppercase
			case 4:		return "TeX Gyre Adventor".localizedUppercase
			case 5:		return "PhishTank".localizedUppercase
			case 6:		return "Readability".localizedUppercase
			case 7:		return "Simple Ping".localizedUppercase
			default:	fatalError("invalid section index")
		}
	}
}

private let OnePasswordExtensionLicense = """
	Copyright (c) 2014 AgileBits Inc.

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	"""



private let SQLCipherLicense = """
	Copyright (c) 2008, ZETETIC LLC
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
	* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	* Neither the name of the ZETETIC LLC nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY ZETETIC LLC ''AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL ZETETIC LLC BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	"""

private let EasyPrivacyLicense = """
	The modified EasyPrivacy list can be requested by sending an email to support@snowhaze.com. EasyList is licensed under creative commons' Attribution-ShareAlike 3.0 Unported, which can be found at creativecommons.org/licenses/by-sa/3.0/legalcode.
	"""

private let TexGyreLicense = """
	Copyright 2007--2009 for TeX Gyre extensions by B. Jackowski and J.M. Nowacki (on behalf of TeX Users Groups).

	http://tug.org/fonts/licenses/GUST-FONT-LICENSE.txt
	This work may be distributed and/or modified under the conditions of the LaTeX Project Public License, either version 1.3c of this license or (at your option) any later version.

	The latest version of the LaTeX Project Public License is in http://www.latex-project.org/lppl.txt and version 1.3c or later is part of all distributions of LaTeX version 2006/05/20 or later.
	"""

private let PhishTankLicense = """
	https://phishtank.com/

	This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 Generic License. To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
	"""

private let ReadabilityLicense = """
	Copyright (c) 2010 Arc90 Inc

	Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
	"""

private let SimplePingLicense = """
	Sample code project: SimplePing
	Version: 5.0

	IMPORTANT: This Apple software is supplied to you by Apple Inc. ("Apple") in consideration of your agreement to the following terms, and your use, installation, modification or redistribution of this Apple software constitutes acceptance of these terms. If you do not agree with these terms, please do not use, install, modify or redistribute this Apple software.

	In consideration of your agreement to abide by the following terms, and subject to these terms, Apple grants you a personal, non-exclusive license, under Apple's copyrights in this original Apple software (the "Apple Software"), to use, reproduce, modify and redistribute the Apple Software, with or without modifications, in source and/or binary forms; provided that if you redistribute the Apple Software in its entirety and without modifications, you must retain this notice and the following text and disclaimers in all such redistributions of the Apple Software. Neither the name, trademarks, service marks or logos of Apple Inc. may be used to endorse or promote products derived from the Apple Software without specific prior written permission from Apple. Except as expressly stated in this notice, no other rights or licenses, express or implied, are granted by Apple herein, including but not limited to any patent rights that may be infringed by your derivative works or by other works in which the Apple Software may be incorporated.

	The Apple Software is provided by Apple on an "AS IS" basis. APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

	IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	"""
