//
//  PageInformationView.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class PageInformationView: UIView {
	private let main: PageInformationOverview

	private var secondary: UIView?

	var callback: (([String: SQLite.Data], Bool) -> Void)?

	init(url: URL, tab: Tab) {
		main = PageInformationOverview(url: url, tab: tab)
		super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
		main.frame = bounds
		main.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		addSubview(main)
	}

	func push(_ view: UIView) {
		guard secondary == nil else {
			return
		}
		let secondary = UIView(frame: bounds)
		secondary.frame.origin.x += bounds.width
		view.frame = secondary.bounds
		view.frame.origin.y += 30
		view.frame.size.height -= 30
		view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		secondary.addSubview(view)
		let back = UIButton(type: .system)
		let backTitle = NSLocalizedString("page information back button title", comment: "title of back button in page information view")
		back.setTitle(backTitle, for: [])
		back.setTitleColor(.button, for: [])
		back.frame = secondary.bounds
		back.frame.size.height = 40
		back.frame.size.width = 100
		back.frame.origin.x = 10
		back.contentHorizontalAlignment = .leading
		back.addTarget(self, action: #selector(pop), for: .touchUpInside)
		back.autoresizingMask = [.flexibleBottomMargin, .flexibleRightMargin]
		secondary.addSubview(back)
		addSubview(secondary)
		secondary.autoresizingMask = [.flexibleHeight, .flexibleWidth]
		self.secondary = secondary
		UIView.animate(withDuration: 0.2) {
			self.main.frame.origin.x -= self.bounds.width
			self.secondary?.frame = self.bounds
		}
	}

	@objc func pop() {
		guard let secondary = secondary else {
			return
		}
		self.secondary = nil
		UIView.animate(withDuration: 0.2, animations: {
			self.main.frame = self.bounds
			secondary.frame.origin.x += self.bounds.width
		}, completion: { _ in
			secondary.removeFromSuperview()
		})
	}

	func complete(settings: [String: SQLite.Data], temporary: Bool) {
		callback?(settings, temporary)
	}

	override init(frame: CGRect) {
		fatalError("init(frame:) has not been implemented")
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
