//
//  HistorySuggestionSource.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

private let maxCount = 3

class HistorySuggestionSource: SuggestionSource {
	private let historyStore = HistoryStore.store
	private let timeFormatter: DateFormatter = DateFormatter()
	private let dateFormatter: DateFormatter = DateFormatter()

	private func priority(for item: (item: HistoryItem, rank: Double)) -> Double {
		let now = Date().timeIntervalSince1970
		return 10 * (-40 + pow(now - item.item.timestamp.timeIntervalSince1970, 0.2)) / item.rank
	}

	private func normalize(history denormalized: [(HistoryItem, Double)]) -> [(item: HistoryItem, rank: Double)] {
		var existingSet = Set<String>(minimumCapacity: maxCount)
		var normalized = [(HistoryItem, Double)]()
		normalized.reserveCapacity(maxCount)
		var newCount = 0
		let sorted = denormalized.sorted {  priority(for: $0) > priority(for: $1) }
		for item in sorted {
			let urlString = item.0.url.absoluteString.lowercased()
			if !existingSet.contains(urlString) {
				existingSet.insert(urlString)
				normalized.append(item)
				newCount += 1
			}
			if newCount >= maxCount {
				break
			}
		}
		return normalized
	}

	init() {
		timeFormatter.timeStyle = .short
		timeFormatter.dateStyle = .none
		dateFormatter.timeStyle = .none
		dateFormatter.dateStyle = .short
	}

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> ()) {
		let historyItems = normalize(history: historyStore.items(forSearch: base))
		let suggestions = historyItems.map { (item) -> Suggestion in
			let title = item.item.title
			let urlString = item.item.url.absoluteString
			let url = item.item.url
			let ranking = priority(for: item)
			let image = self.image(for: item.item.timestamp)
			return Suggestion(title: title, subtitle: urlString, url: url, image: image, priority: ranking)
		}
		callback(suggestions, "history")
	}

	private func image(for date: Date) -> UIImage {
		let width: CGFloat = 50
		let height: CGFloat = 50
		let center: CGFloat = 4
		let dateString = dateFormatter.string(from: date)
		let timeString = timeFormatter.string(from: date)
		typealias Keys = NSAttributedString.Key
		let attributes = [Keys.foregroundColor: UIColor.title, Keys.font: UIFont.systemFont(ofSize: 12)]
		let dateSize = dateString.size(withAttributes: attributes)
		let timeSize = timeString.size(withAttributes: attributes)
		UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)
		timeString.draw(at: CGPoint(x: (width - timeSize.width) / 2, y: height / 2 - timeSize.height - center / 2), withAttributes: attributes)
		dateString.draw(at: CGPoint(x: (width - dateSize.width) / 2, y: height / 2 + center / 2), withAttributes: attributes)
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return image!
	}
}
