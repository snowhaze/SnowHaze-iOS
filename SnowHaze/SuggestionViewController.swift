//
//  SuggestionViewController.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let rowHeight: CGFloat = 44

private let blockTime: TimeInterval = 0.3

protocol SuggestionViewControllerDelegate: class {
	func suggestionController(_ controller: SuggestionViewController, didSelectURL url: URL)
}

protocol SuggestionSource {
	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> ())
	func cancelSuggestions()
}

extension SuggestionSource {
	func cancelSuggestions() { }
}

class SuggestionViewController: UITableViewController {
	var blocks = [(date: Date, index: Int)]()

	var sources = [SuggestionSource]()
	var backgroundColor: UIColor? {
		set {
			view.backgroundColor = newValue
		}
		get {
			return view.backgroundColor
		}
	}
	var titleColor: UIColor = .black
	var subtitleColor: UIColor = .lightGray
	var selectionColor: UIColor?
	weak var delegate: SuggestionViewControllerDelegate?

	private var completeSources = Set<String>()

	var hasSelection: Bool {
		return tableView.indexPathForSelectedRow != nil
	}

	var canSelectNext: Bool {
		return !suggestions.isEmpty && (!hasSelection || tableView.indexPathForSelectedRow!.item < suggestions.count - 1)
	}

	var canSelectPrevious: Bool {
		return !suggestions.isEmpty && (hasSelection && tableView.indexPathForSelectedRow!.item > 0)
	}

	var baseString: String? {
		didSet {
			suggestions = []
			blocks = []
			completeSources.removeAll()
			tableView.reloadData()
			guard let oldBase = baseString else {
				return
			}
			for source in sources {
				source.generateSuggestion(base: baseString!) { suggestions, id in
					if oldBase == self.baseString && !self.completeSources.contains(id) {
						self.completeSources.insert(id)
						self.add(suggestions)
					}
				}
			}
		}
	}

	var alwaysBounce: Bool {
		set {
			tableView.alwaysBounceVertical = newValue
		}
		get {
			return tableView.alwaysBounceVertical
		}
	}

	private var suggestions = [Suggestion]()

	private func add(_ newSuggestions: [Suggestion]) {
		guard !newSuggestions.isEmpty else {
			return
		}
		let oldSuggestions = suggestions
		suggestions.append(contentsOf: newSuggestions)
		suggestions.sort { $0.priority > $1.priority }
		let index = suggestions.firstDifference(from: oldSuggestions)
		assert(index >= 0)
		blocks.append((Date(timeIntervalSinceNow: blockTime), index))
		tableView.reloadData()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		tableView.separatorInset = UIEdgeInsets(top: 0, left: 80, bottom: 0, right: 0)
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return rowHeight
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return suggestions.count
	}

	override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		let now = Date()
		blocks = blocks.filter { $0.date > now }
		return !blocks.contains(where: { $0.index <= indexPath.row })
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let suggestion = suggestions[indexPath.row]
		open(suggestion)
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let reuseID = "cell"
		var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: reuseID)
		if cell == nil {
			cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseID)
		}
		let suggestion = suggestions[indexPath.row]
		var image: UIImage? = nil
		if let unsized = suggestion.image {
			let length: CGFloat = 40
			let size = CGSize(width: length, height: length)
			UIGraphicsBeginImageContext(size)
			unsized.draw(in: CGRect(origin: .zero, size: size))
			image = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
		}
		cell.textLabel?.text = suggestion.title
		cell.textLabel?.textColor = titleColor
		cell.detailTextLabel?.text = suggestion.subtitle
		cell.detailTextLabel?.textColor = subtitleColor
		cell.imageView?.image = image
		cell.backgroundColor = tableView.backgroundColor
		if let selectionColor = selectionColor {
			cell.selectedBackgroundView = UIView()
			cell.selectedBackgroundView!.backgroundColor = selectionColor
		}
		return cell
	}

	func selectNext() {
		guard canSelectNext else {
			return
		}
		let indexPath: IndexPath
		if hasSelection {
			let oldIndexPath = tableView.indexPathForSelectedRow!
			indexPath = IndexPath(item: oldIndexPath.item + 1, section: 0)
		} else {
			indexPath = IndexPath(item: 0, section: 0)
		}
		tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
	}

	func selectPrevious() {
		guard canSelectPrevious else {
			return
		}
		let oldIndexPath = tableView.indexPathForSelectedRow!
		let indexPath = IndexPath(item: oldIndexPath.item - 1, section: 0)
		tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
	}

	func openSelection() {
		guard hasSelection else {
			return
		}
		let indexPath = tableView.indexPathForSelectedRow!
		let suggestion = suggestions[indexPath.row]
		open(suggestion)
	}

	func open(_ suggestion: Suggestion) {
		delegate?.suggestionController(self, didSelectURL: suggestion.url)
		suggestion.selectionCallback?()
	}

	func cancelSuggestions() {
		for source in sources {
			source.cancelSuggestions()
		}
	}
}

func ==(_ lhs: Suggestion, _ rhs: Suggestion) -> Bool {
	return	lhs.title == rhs.title &&
			lhs.subtitle == rhs.subtitle &&
			lhs.url == rhs.url &&
			lhs.image == rhs.image &&
			lhs.priority == rhs.priority
}

class Suggestion: Equatable {
	let title: String?
	let subtitle: String?
	let	url: URL
	let image: UIImage?
	let priority: Double

	var selectionCallback: (() -> ())?

	init(title: String?, subtitle: String?, url: URL, image: UIImage?, priority: Double) {
		self.title = title
		self.subtitle = subtitle
		self.url = url
		self.image = image
		self.priority = priority
	}
}
