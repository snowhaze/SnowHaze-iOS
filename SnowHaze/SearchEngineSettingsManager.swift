//
//	SearchEngineSettingsManager.swift
//	SnowHaze
//
//
//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit
import Sodium

private let customSection = 3
private let customRow = 0
class SearchEngineSettingsManager: SettingsViewManager, UITextFieldDelegate {
	override func html() -> String {
		return NSLocalizedString("search engine settings explanation", comment: "explanations of the search engine settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.searchEngine]).color
	}

	private lazy var suggestionSearchEngines: [SearchEngineType] = SearchEngine.decode(self.settings.value(for: searchSuggestionEnginesKey).text!)

	private var setupSearx = false

	private var urlField: UITextField?
	private var suggestionField: UITextField?
	private var pathField: UITextField?
	private var errorLabel: UILabel?

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 1 {
			let title: String
			let engine = rawValue(for: indexPath.row)
			switch engine {
				case 0:		title = NSLocalizedString("none search engine display name", comment: "name of none search engine to be displayed to user")
				case 1:		title = NSLocalizedString("bing search engine display name", comment: "name of bing search engine to be displayed to user")
				case 2:		title = NSLocalizedString("google search engine display name", comment: "name of google search engine to be displayed to user")
				case 3:		title = NSLocalizedString("yahoo search engine display name", comment: "name of yahoo search engine to be displayed to user")
				case 4:		title = NSLocalizedString("wikipedia search engine display name", comment: "name of wikipedia search engine to be displayed to user")
				case 5:		title = NSLocalizedString("wolframalpha search engine display name", comment: "name of wolframalpha search engine to be displayed to user")
				case 6:		title = NSLocalizedString("ecosia search engine display name", comment: "name of ecosia search engine to be displayed to user")
				case 7:		title = NSLocalizedString("startpage search engine display name", comment: "name of startpage search engine to be displayed to user")
				case 8:		title = NSLocalizedString("swisscows search engine display name", comment: "name of swisscows search engine to be displayed to user")
				case 9:		title = NSLocalizedString("duckduckgo search engine display name", comment: "name of duckduckgo search engine to be displayed to user")
				case 12:	title = NSLocalizedString("qwant search engine display name", comment: "name of qwant search engine to be displayed to user")
				case 13:	title = NSLocalizedString("custom search engine display name", comment: "name of custom search engine setting to be displayed to user")
				default:	fatalError("invalid index path")
			}
			cell.textLabel?.text = title
			if engine == settings.value(for: searchEngineKey).integer {
				cell.accessoryType = .checkmark
			}
		} else if indexPath.section == 2 {
			let title: String
			let type: SearchEngineType
			switch indexPath.row {
				case 0:		title = NSLocalizedString("main search engine name", comment: "used to refer to the search engine selected by the user")
							type = SearchEngineType(rawValue: settings.value(for: searchEngineKey).integer!) ?? .none
				case 1:		title = NSLocalizedString("wikipedia search engine display name", comment: "name of wikipedia search engine to be displayed to user")
							type = SearchEngineType.wikipedia
				case 2:		title = NSLocalizedString("wolframalpha search engine display name", comment: "name of wolframalpha search engine to be displayed to user")
							type = SearchEngineType.wolframAlpha
				default:	fatalError("invalid index path")
			}
			cell.textLabel?.text = title
			if suggestionSearchEngines.contains(type) {
				cell.accessoryType = .checkmark
			}
		} else if indexPath.section == 3 {
			assert(customSection == 3)
			let generic = NSLocalizedString("custom search engine settings generic settings title", comment: "title of the generic section of the custom search engine settings")
			let searx = NSLocalizedString("custom search engine settings searx settings title", comment: "title of the searx section of the custom search engine settings")
			let items = [generic, searx]
			let segment = UISegmentedControl(items: items)
			segment.frame = CGRect(x: 30, y: 15, width: cell.bounds.width - 60, height: 40)
			segment.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			segment.selectedSegmentIndex = setupSearx ? 1 : 0
			segment.addTarget(self, action: #selector(customTypeChanged(_:)), for: .valueChanged)
			cell.addSubview(segment)
			let url = makeTextField(for: cell)
			url.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			url.center.y = 90
			let searchURL = NSLocalizedString("custom search url setting placeholder", comment: "placeholder of textfield for custom search url")
			url.placeholder = searchURL
			url.delegate = self
			url.keyboardType = .URL
			url.autocorrectionType = .no
			url.autocapitalizationType = .none
			url.textContentType = .URL
			urlField = url
			if !setupSearx {
				url.text = settings.value(for: customSearchURLKey).text
				let suggestion = makeTextField(for: cell)
				suggestion.text = settings.value(for: customSearchSuggestionsURLKey).text
				suggestion.center.y = 140
				let searchApiURL = NSLocalizedString("custom search suggestion api url setting placeholder", comment: "placeholder of textfield for custom search suggestion api url")
				suggestion.placeholder = searchApiURL
				suggestion.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				suggestionField = suggestion
				suggestion.delegate = self
				suggestion.keyboardType = .URL
				suggestion.autocorrectionType = .no
				suggestion.autocapitalizationType = .none
				suggestion.textContentType = .URL
				let path = makeTextField(for: cell)
				path.text = settings.value(for: customSearchSuggestionsJSONPathKey).text
				path.center.y = 190
				let jsonpath = NSLocalizedString("custom search suggestion jsonpath setting placeholder", comment: "placeholder of textfield for custom search suggestion jsonpath")
				path.placeholder = jsonpath
				path.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
				path.delegate = self
				path.keyboardType = .numbersAndPunctuation
				path.autocorrectionType = .no
				path.autocapitalizationType = .none
				pathField = path
			} else {
				url.text = fullToSearx(settings.value(for: customSearchURLKey).text!)
			}
			let label = UILabel(frame: CGRect(x: cell.bounds.minX + 20, y: setupSearx ? 115 : 215, width: cell.bounds.width - 40, height: 50))
			label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
			label.textColor = .title
			label.textAlignment = .center
			label.numberOfLines = 2
			cell.addSubview(label)
			errorLabel = label
			updateUIState()
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		assert(customSection == 3)
		switch section {
			case 0:		return 0
			case 1:		return 12
			case 2:		return 3
			case 3:		return 1
			default:	fatalError("invalid section")
		}
	}

	override var numberOfSections: Int {
		return 4
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		assert(numberOfSections == 4)
		return section == 3 ? super.heightForFooter(inSection: section) : 0
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		return section == 0 ? super.heightForHeader(inSection: section) : 40
	}

	override func titleForHeader(inSection section: Int) -> String? {
		assert(customSection == 3)
		switch section {
			case 0:		return super.titleForHeader(inSection: section)
			case 1:		return NSLocalizedString("search engine selection setting subsection title", comment: "title of settings subsection to choose search engine")
			case 2:		return NSLocalizedString("search suggestion engines setting subsection title", comment: "title of settings subsection to choose search engines for search suggestions")
			case 3:		return NSLocalizedString("custom search engine setting subsection title", comment: "title of settings subsection to setup custom search engines")
			default:	fatalError("invalid section")
		}
	}

	override func heightForRow(atIndexPath indexPath: IndexPath) -> CGFloat {
		assert(customSection == 3)
		if indexPath.section == 3 {
			return setupSearx ? 170 : 270
		}
		return super.heightForRow(atIndexPath: indexPath)
	}

	@objc private func customTypeChanged(_ sender: UISegmentedControl) {
		setupSearx = sender.selectedSegmentIndex == 1
		let indexPath = IndexPath(row: customRow, section: customSection)
		controller.tableView.reloadRows(at: [indexPath], with: .fade)
		controller.tableView.scrollToRow(at: indexPath, at: .none, animated: true)
		if setupSearx {
			let url = settings.value(for: customSearchURLKey).text!
			settings.set(.text(url), for: customSearchURLKey)
			let suggestions = fullToSuggestions(url)
			settings.set(.text(suggestions), for: customSearchSuggestionsURLKey)
			settings.set(.text("$.suggestions.*"), for: customSearchSuggestionsJSONPathKey)
		}
		updateUIState()
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == 1 {
			let engine = rawValue(for: indexPath.row)
			let newEngine = SearchEngineType(rawValue: engine) ?? .none
			let oldEngine = SearchEngineType(rawValue: settings.value(for: searchEngineKey).integer!) ?? .none
			suggestionSearchEngines = SearchEngine.updateSuggestionEngine(new: newEngine, old: oldEngine, inList: suggestionSearchEngines)

			Settings.atomically {
				settings.set(.text(SearchEngine.encode(suggestionSearchEngines)), for: searchSuggestionEnginesKey)
				settings.set(.integer(engine), for: searchEngineKey)
			}
			for cell in tableView.visibleCells {
				let indexPath = tableView.indexPath(for: cell)
				if let indexPath = indexPath, indexPath.section == 1 {
					if rawValue(for: indexPath.row) == engine {
						cell.accessoryType = .checkmark
					} else {
						cell.accessoryType = .none
					}
				}
			}
			reloadSection2(with: newEngine, tableView: tableView)
			updateHeaderColor(animated: true)
		} else if indexPath.section == 2 {
			let mainEngine = SearchEngineType(rawValue: settings.value(for: searchEngineKey).integer!) ?? .none
			let engine: SearchEngineType
			switch indexPath.row {
				case 0:		engine = mainEngine
				case 1:		engine = SearchEngineType.wikipedia
				case 2:		engine = SearchEngineType.wolframAlpha
				default:	fatalError("invalid index path")
			}
			if suggestionSearchEngines.contains(engine) {
				suggestionSearchEngines = SearchEngine.remove(suggestionEngine: engine, from: suggestionSearchEngines)
			} else {
				suggestionSearchEngines = SearchEngine.add(suggestionEngine: engine, to: suggestionSearchEngines)
			}
			settings.set(.text(SearchEngine.encode(suggestionSearchEngines)), for: searchSuggestionEnginesKey)

			reloadSection2(with: mainEngine, tableView: tableView)
			updateHeaderColor(animated: true)
		}
	}

	private func reloadSection2(with defaultEngine: SearchEngineType, tableView: UITableView) {
		for cell in tableView.visibleCells {
			guard let indexPath = tableView.indexPath(for: cell) else {
				continue
			}
			if indexPath.section == 2 {
				let selected: Bool
				switch indexPath.row {
					case 0:		selected = suggestionSearchEngines.contains(defaultEngine)
					case 1:		selected = suggestionSearchEngines.contains(SearchEngineType.wikipedia)
					case 2:		selected = suggestionSearchEngines.contains(SearchEngineType.wolframAlpha)
					default:	fatalError("invalid index path")
				}
				if selected {
					cell.accessoryType = .checkmark
				} else {
					cell.accessoryType = .none
				}
			}
		}
	}

	private func rawValue(for index: Int) -> Int64 {
		return Int64(index + (index < 10 ? 0: 2))
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if textField == urlField {
			suggestionField?.becomeFirstResponder()
		} else if textField == suggestionField {
			pathField?.becomeFirstResponder()
		} else {
			textField.resignFirstResponder()
		}
		return true
	}

	private func fullToSearx(_ full: String) -> String {
		guard let template = PolicyManager.customSearchTemplate(for: "") else {
			return full
		}
		let (unescaped, reverse) = template.unescape(full, safe: Templating.hexChars)
		guard var components = URLComponents(string: unescaped) else {
			return full
		}
		guard let query = components.queryItems?.filter({ $0.name != "q" }) else {
			return full
		}
		if query.isEmpty {
			components.queryItems = nil
		} else {
			components.queryItems = query
		}
		guard let transformed = components.url?.absoluteString else {
			return full
		}
		return (try? reverse.apply(to: transformed)) ?? full
	}

	private func fullToSuggestions(_ searx: String) -> String {
		guard let template = PolicyManager.customSearchTemplate(for: "") else {
			return searx
		}
		let (unescaped, reverse) = template.unescape(searx, safe: Templating.hexChars)
		guard var components = URLComponents(string: unescaped) else {
			return searx
		}
		let query = components.queryItems?.filter({ $0.name != "format" }) ?? []
		components.queryItems = query + [URLQueryItem(name: "format", value: "json")]
		guard let transformed = components.url?.absoluteString else {
			return searx
		}
		return (try? reverse.apply(to: transformed)) ?? searx
	}

	private func searxToFull(_ searx: String) -> String {
		guard let template = PolicyManager.customSearchTemplate(for: "") else {
			return searx
		}
		let (unescaped, reverse) = template.unescape(searx, safe: Templating.hexChars)
		guard var components = URLComponents(string: unescaped) else {
			return searx
		}
		let query = components.queryItems?.filter({ $0.name != "q" }) ?? []
		components.queryItems = query + [URLQueryItem(name: "q", value: "@query@")]
		guard let transformed = components.url?.absoluteString else {
			return searx
		}
		return (try? reverse.apply(to: transformed)) ?? searx
	}

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		update(textField, range: range, replacement: string)
		let text = textField.text ?? ""
		if setupSearx {
			if textField == urlField {
				let full = searxToFull(text)
				let suggestions = fullToSuggestions(full)
				settings.set(.text(full), for: customSearchURLKey)
				settings.set(.text(suggestions), for: customSearchSuggestionsURLKey)
			}
		} else {
			if textField == urlField {
				settings.set(.text(text), for: customSearchURLKey)
			} else if textField == suggestionField {
				settings.set(.text(text), for: customSearchSuggestionsURLKey)
			} else if textField == pathField {
				settings.set(.text(text), for: customSearchSuggestionsJSONPathKey)
			}
		}
		updateUIState()
		return false
	}

	private enum Error: Swift.Error {
		case invalidURL
		case invalidScheme
		case invalidHost
		case templatingError
		case missingQuery
		case missingRoot
		case invalidSyntax(String)
		case escapeUnsupported
		case filterExpressionUnsupported
		case scriptExpressionUnsupported
	}

	private func validateSearchUrl(_ string: String?) -> Error? {
		guard let string = string else {
			return .invalidURL
		}
		let token = Data(Sodium().randomBytes.buf(length: 32)!).hex
		let padding = Data(Sodium().randomBytes.buf(length: 5)!).hex
		let padded = padding + token + padding
		guard let template = PolicyManager.customSearchTemplate(for: padded) else {
			return .templatingError
		}
		guard let templated = try? template.apply(to: string) else {
			return .templatingError
		}
		guard templated.contains(token) else {
			return .missingQuery
		}
		guard let url = URLComponents(string: templated) else {
			return .invalidURL
		}
		guard ["http", "https"].contains(url.scheme?.lowercased()) else {
			return .invalidScheme
		}
		guard !(url.host?.isEmpty ?? true) else {
			return .invalidHost
		}
		return nil
	}

	private func updateUIState() {
		func push(error: Error) {
			if (errorLabel?.text ?? "").isEmpty {
				let msg: String
				switch error {
					case .escapeUnsupported:			msg = NSLocalizedString("escape unsupported jsonpath parse error custom search configuration error message", comment: "error message for bad custom search engine configuration because of escape in jsonpath")
					case .missingRoot:					msg = NSLocalizedString("jsonpath not anchored parse error custom search configuration error message", comment: "error message for bad custom search engine configuration because of unanchored jsonpath")
					case .invalidSyntax(let e):
						let fmt = NSLocalizedString("jsonpath syntax error custom search configuration error message format", comment: "format of error message for bad custom search engine configuration because of syntax error in jsonpath")
						msg = String(format: fmt, e)
					case .filterExpressionUnsupported:	msg = NSLocalizedString("jsonpath filter not supported custom search configuration error message", comment: "error message for bad custom search engine configuration because filters are not supported in jsonpaths")
					case .scriptExpressionUnsupported:	msg = NSLocalizedString("jsonpath script not supported custom search configuration error message", comment: "error message for bad custom search engine configuration because scripts are not supported in jsonpaths")
					case .invalidURL:					msg = NSLocalizedString("url invalid custom search configuration error message", comment: "error message for bad custom search engine configuration because of invalid url")
					case .invalidScheme:				msg = NSLocalizedString("url scheme invalid custom search configuration error message", comment: "error message for bad custom search engine configuration because of invalid url scheme")
					case .invalidHost:					msg = NSLocalizedString("url host invalid custom search configuration error message", comment: "error message for bad custom search engine configuration because of invalid url host")
					case .missingQuery:					msg = NSLocalizedString("missing url query custom search configuration error message", comment: "error message for bad custom search engine configuration because of missing url query")
					case .templatingError:				msg = NSLocalizedString("templating error custom search configuration error message", comment: "error message for bad custom search engine configuration because of a templating error")
				}
				errorLabel?.text = msg
			}
		}
		errorLabel?.text = ""
		if let error = validateSearchUrl(settings.value(for: customSearchURLKey).text) {
			urlField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			push(error: error)
		} else {
			urlField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		}
		if let error = validateSearchUrl(settings.value(for: customSearchSuggestionsURLKey).text) {
			if setupSearx {
				urlField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			} else {
				suggestionField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
			}
			push(error: error)
		} else {
			suggestionField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		}
		let path = settings.value(for: customSearchSuggestionsJSONPathKey).text!
		do {
			let _ = try JSONPath(path)
			pathField?.layer.borderColor = UIColor.veryGoodPrivacy.cgColor
		} catch let rawError {
			let parseError = rawError as! JSONPath.ParseError
			let error: Error
			switch parseError {
				case .missingRoot:					error = .missingRoot
				case .invalidSyntax(let s):			error = .invalidSyntax(s)
				case .escapeUnsupported:			error = .escapeUnsupported
				case .filterExpressionUnsupported:	error = .filterExpressionUnsupported
				case .scriptExpressionUnsupported:	error = .scriptExpressionUnsupported
			}
			push(error: error)
			pathField?.layer.borderColor = UIColor.veryBadPrivacy.cgColor
		}
	}
}
