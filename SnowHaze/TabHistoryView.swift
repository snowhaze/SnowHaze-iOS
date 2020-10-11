//
//  TabHistoryView.swift
//  SnowHaze
//
//
//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation
import WebKit
import UIKit

class TabHistoryView: UIView, UITableViewDelegate, UITableViewDataSource {
	private let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 30))
	private let tableView = UITableView(frame: CGRect(x: 0, y: 30, width: 300, height: 160), style: .plain)
	private let history: [WKBackForwardListItem]
	var load: ((WKBackForwardListItem) -> ())?

	init(history: [WKBackForwardListItem], title: String) {
		self.history = history
		super.init(frame: CGRect(x: 0, y: 0, width: 300, height: 190))

		label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		label.textColor = .localSettingsTitle
		label.text = title
		label.textAlignment = .center
		addSubview(label)

		tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		tableView.delegate = self
		tableView.dataSource = self
		tableView.backgroundColor = .clear
		tableView.rowHeight = 44
		tableView.alwaysBounceVertical = false
		addSubview(tableView)

		bounds.size.height = tableView.rowHeight * CGFloat(history.count) + bounds.size.height - tableView.frame.height
		bounds.size.width = 350
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return history.count
	}

	func getCell(for tableView: UITableView) -> UITableViewCell {
		let id = "cell"
		if let cell = tableView.dequeueReusableCell(withIdentifier: id) {
			return cell
		}
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: id)
		cell.backgroundColor = .clear
		cell.tintColor = .button
		cell.textLabel?.textColor = .darkTitle
		cell.detailTextLabel?.textColor = .darkTitle
		return cell
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = getCell(for: tableView)
		cell.textLabel?.text = history[indexPath.row].title
		cell.detailTextLabel?.text = history[indexPath.row].url.absoluteString
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: false)
		load?(history[indexPath.row])
	}

	func flashScrollIndicator() {
		tableView.flashScrollIndicators()
	}
}
