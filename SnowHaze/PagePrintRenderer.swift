//
//  PagePrintManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class PagePrintRenderer: UIPrintPageRenderer {
	private let pageIndexSeparator = NSLocalizedString("page offset indication preposition", comment: "preposition indication offset in set e.g. page 5 'of' 7")
	private let webView: WKWebView
	private let title: String
	private let url: String
	private let date: String

	private let numberFormatter = NumberFormatter()

	init(webView: WKWebView) {
		self.webView = webView
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .short
		dateFormatter.timeStyle = .medium
		date = dateFormatter.string(from: Date())
		let urlString = webView.url?.absoluteString ?? ""
		if let titleString = webView.title {
			title = titleString
			url = urlString
		} else {
			title = urlString
			url = ""
		}
		super.init()

		headerHeight = 20
		footerHeight = 20
		let formatter = webView.viewPrintFormatter()
		addPrintFormatter(formatter, startingAtPageAt: 0)
	}

	override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
		// draw page numbers
		let pageNumberString = numberFormatter.string(from: NSNumber(value: pageIndex + 1))!
		let pageCountString = numberFormatter.string(from: NSNumber(value: numberOfPages))!
		let indexString = pageNumberString + " " + pageIndexSeparator + " " + pageCountString
		let attributes = [NSAttributedString.Key.font: UIFont.snowHazeFont(size: 12)]
		let indexSize = indexString.size(withAttributes: attributes)
		let indexY = footerRect.maxY - indexSize.height
		let indexX = footerRect.maxX - indexSize.width
		indexString.draw(at: CGPoint(x: indexX, y: indexY), withAttributes: attributes)

		// draw date
		let dateSize = date.size(withAttributes: attributes)
		let	dateY = footerRect.maxY - dateSize.height
		let dateX = footerRect.minX
		date.draw(at: CGPoint(x: dateX, y: dateY), withAttributes: attributes)

		// draw url
		let urlSize = url.size(withAttributes: attributes)
		let urlY = footerRect.maxY - urlSize.height
		let urlX = max(dateX + dateSize.width + 10, min(indexX - urlSize.width - 10, footerRect.midX - urlSize.width / 2))
		let maxWidth = footerRect.width - 20 - dateSize.width - indexSize.width
		let urlWidth = min(maxWidth, urlSize.width)
		url.draw(in: CGRect(x: urlX, y: urlY, width: urlWidth, height: urlSize.height), withAttributes: attributes)
	}

	override func drawHeaderForPage(at pageIndex: Int, in headerRect: CGRect) {
		let attributes = [NSAttributedString.Key.font: UIFont.snowHazeFont(size: 12)]
		let titleSize = title.size(withAttributes: attributes)
		let titleX = max(headerRect.minX, headerRect.midX - titleSize.width / 2)
		let titleY = headerRect.minX
		let titleWidth = min(headerRect.width, titleSize.width)
		title.draw(in: CGRect(x: titleX, y: titleY, width: titleWidth, height: titleSize.height), withAttributes: attributes)
	}
}
