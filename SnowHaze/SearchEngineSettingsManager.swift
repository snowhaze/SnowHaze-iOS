//
//	SearchEngineSettingsManager.swift
//	SnowHaze
//

//	Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class SearchEngineSettingsManager: SettingsViewManager {
	override func html() -> String {
		return NSLocalizedString("search engine settings explanation", comment: "explanations of the search engine settings")
	}

	override var assessmentResultColor: UIColor {
		return PolicyAssessor(wrapper: settings).assess([.searchEngine]).color
	}

	private lazy var suggestionSearchEngines: [SearchEngineType] = SearchEngine.decode(self.settings.value(for: searchSuggestionEnginesKey).text!)

	override func cellForRow(atIndexPath indexPath: IndexPath, tableView: UITableView) -> UITableViewCell {
		let cell = getCell(for: tableView)
		if indexPath.section == 1 {
			let title: String
			switch indexPath.row {
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
				default:	fatalError("invalid index path")
			}
			cell.textLabel?.text = title
			if Int64(indexPath.row) == settings.value(for: searchEngineKey).integer {
				cell.accessoryType = .checkmark
			}
		} else if indexPath.section == 2{
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
		}
		return cell
	}

	override func numberOfRows(inSection section: Int) -> Int {
		switch section {
			case 0:		return 0
			case 1:		return 10
			case 2:		return 3
			default:	fatalError("invalid section")
		}
	}

	override var numberOfSections: Int {
		return 3
	}

	override func heightForFooter(inSection section: Int) -> CGFloat {
		return section == 2 ? super.heightForFooter(inSection: section) : 0
	}

	override func heightForHeader(inSection section: Int) -> CGFloat {
		return section == 0 ? super.heightForHeader(inSection: section) : 40
	}

	override func titleForHeader(inSection section: Int) -> String? {
		switch section {
			case 0:		return super.titleForHeader(inSection: section)
			case 1:		return NSLocalizedString("search engine selection setting subsection title", comment: "title of settings subsection to choose search engine")
			case 2:		return NSLocalizedString("search suggestion engines setting subsection title", comment: "title of settings subsection to choose search engines for search suggestions")
			default:	fatalError("invalid section")
		}
	}

	override func didSelectRow(atIndexPath indexPath: IndexPath, tableView: UITableView) {
		if indexPath.section == 1 {
			if indexPath.row == 10 && !SubscriptionManager.shared.hasSubscription {
				controller.switchToSubscriptionSettings()
				return
			}
			let engine = Int64(indexPath.row)
			let newEngine = SearchEngineType(rawValue: engine) ?? .none
			let oldEngine = SearchEngineType(rawValue: settings.value(for: searchEngineKey).integer!) ?? .none
			suggestionSearchEngines = SearchEngine.updateSuggestionEngine(new: newEngine, old: oldEngine, inList: suggestionSearchEngines)

			Settings.atomically {
				settings.set(.text(SearchEngine.encode(suggestionSearchEngines)), for: searchSuggestionEnginesKey)
				settings.set(.integer(engine), for: searchEngineKey)
			}
			for cell in tableView.visibleCells {
				let indexPath = tableView.indexPath(for: cell)
				if indexPath?.section == 1 {
					if indexPath?.row == Int(engine) {
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
}
