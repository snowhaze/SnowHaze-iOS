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

	private func normalize(history denormalized: [HistoryItem]) -> [HistoryItem] {
		var existingSet = Set<String>(minimumCapacity: maxCount)
		var normalized = [HistoryItem]()
		normalized.reserveCapacity(maxCount)
		var newCount = 0
		for item in denormalized {
			let urlString = item.url.absoluteString
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

	func generateSuggestion(base: String, callback: @escaping ([Suggestion], String) -> Void) {
		let historyItems = normalize(history: historyStore.items(forSearch: base))
		let now = Date().timeIntervalSince1970
		let suggestions = historyItems.map { (item) -> Suggestion in
			let title = item.title
			let urlString = item.url.absoluteString
			let url = item.url
			let priority = 50 - pow(now - item.timestamp.timeIntervalSince1970, 0.1)
			let image = self.image(for: item.timestamp)
			return Suggestion(title: title, subtitle: urlString, url: url, image: image, priority: priority)
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
