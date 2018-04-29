//
//  ArrayHelpers.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

struct Addition<Element>: CustomStringConvertible {
	let index: Int
	let value: Element

	init(index: Int, value: Element) {
		self.index = index
		self.value = value
	}

	var description: String {
		return "Add \(value) at \(index)"
	}
}

struct Deletion<Element>: CustomStringConvertible {
	let index: Int
	let value: Element

	init(index: Int, value: Element) {
		self.index = index
		self.value = value
	}

	var description: String {
		return "Delete \(value) at \(index)"
	}
}

struct Move<Element>: CustomStringConvertible {
	let fromIndex: Int
	let toIndex: Int
	let value: Element

	init(fromIndex: Int, toIndex: Int, value: Element) {
		self.fromIndex = fromIndex
		self.toIndex = toIndex
		self.value = value
	}

	var description: String {
		return "Move \(value) from \(fromIndex) to \(toIndex)"
	}
}

extension Array where Element == String {
	func sentenceJoined(mainSeparator: String, finalSeparator: String) -> String {
		switch count {
			case 0:
				return ""
			case 1:
				return self[0]
			default:
				let final = last!
				let rest = Array(dropLast()).joined(separator: mainSeparator)
				return rest + finalSeparator + final
		}
	}
}

extension Array where Element: Equatable {
/**
	Calculates the difference between two arrays.

	- parameter from: the original array from which the diff is made

	- returns: The changes necessary convert from into self
*/
	func diff(from: [Element]) -> (new: [Addition<Element>], deleted: [Deletion<Element>], moved: [Move<Element>]) {
		var additions = [Addition<Element>]()
		var deletions = [Deletion<Element>]()
		var moves = [Move<Element>]()
		if from.count == 0 {
			additions.reserveCapacity(count)
			for (index, element) in enumerated() {
				let addition = Addition<Element>(index: index, value: element)
				additions.append(addition)
			}
		} else if count == 0 {
			deletions.reserveCapacity(from.count)
			for (index, element) in from.enumerated() {
				let deletion = Deletion<Element>(index: index, value: element)
				deletions.append(deletion)
			}
		} else {
			var map = [Int](repeating: 0, count: (count + 1) * (from.count + 1))
			for row in 1 ... count {
				for column in 1 ... from.count {
					if self[row - 1] == from[column - 1] {
						map[row * (from.count + 1) + column] = map[(row - 1) * (from.count + 1) + (column - 1)] + 1
					} else {
						let l1 = map[(row - 1) * (from.count + 1) + column]
						let l2 = map[row * (from.count + 1) + (column - 1)]
						map[row * (from.count + 1) + column] = l1 < l2 ? l2 : l1
					}
				}
			}
			additions.reserveCapacity(count - map.last!)
			deletions.reserveCapacity(from.count - map.last!)
			var fromIndex = from.count
			var toIndex = count

			while fromIndex > 0 || toIndex > 0 {
				if fromIndex > 0 && toIndex > 0 && self[toIndex - 1] == from[fromIndex - 1] {
					toIndex -= 1
					fromIndex -= 1
				} else if fromIndex == 0 || toIndex > 0 && map[(toIndex - 1) * (from.count + 1) + fromIndex] > map[toIndex * (from.count + 1) + (fromIndex - 1)] {
					toIndex -= 1
					let addition = Addition<Element>(index: toIndex, value: self[toIndex])
					additions.append(addition)
				} else {
					fromIndex -= 1
					let deletion = Deletion<Element>(index: fromIndex, value: from[fromIndex])
					deletions.append(deletion)
				}
			}
			additions = additions.reversed()
			deletions = deletions.reversed()

			var moveAdditionIndexes = [Int]()
			var moveDeletionIndexes = [Int]()

			if additions.count < deletions.count {
				moves.reserveCapacity(additions.count)
				moveAdditionIndexes.reserveCapacity(additions.count)
				moveDeletionIndexes.reserveCapacity(additions.count)
				for (additionIndex, element) in additions.enumerated() {
					if let deletionIndex = deletions.index(where: { $0.value == element.value }) {
						let fromIndex = deletions[deletionIndex].index
						let toIndex = element.index
						let move = Move<Element>(fromIndex: fromIndex, toIndex: toIndex, value: element.value)
						moves.append(move)
						moveAdditionIndexes.append(additionIndex)
						moveDeletionIndexes.append(deletionIndex)
					}
				}
				moveDeletionIndexes.sort()
			} else {
				moves.reserveCapacity(deletions.count)
				moveAdditionIndexes.reserveCapacity(deletions.count)
				moveDeletionIndexes.reserveCapacity(deletions.count)
				for (deletionIndex, element) in deletions.enumerated() {
					if let additionIndex = additions.index(where: { $0.value == element.value }) {
						let fromIndex = element.index
						let toIndex = additions[additionIndex].index
						let move = Move<Element>(fromIndex: fromIndex, toIndex: toIndex, value: element.value)
						moves.append(move)
						moveAdditionIndexes.append(additionIndex)
						moveDeletionIndexes.append(deletionIndex)
					}
				}
				moveAdditionIndexes.sort()
			}
			for index in moveAdditionIndexes.reversed() {
				additions.remove(at: index)
			}
			for index in moveDeletionIndexes.reversed() {
				deletions.remove(at: index)
			}
		}
		return (additions, deletions, moves)
	}

	func firstDifference(from: [Element]) -> Int {
		let minCount = Swift.min(count, from.count)
		for i in 0 ..< minCount {
			if self[i] != from[i] {
				return i
			}
		}
		if count == from.count {
			return -1
		} else {
			return minCount
		}
	}
}

extension Array where Element: Comparable {
/**
	Search for needle index

	- parameter needle: the element to look for
	- returns:  the index of needle or nil if !self.contains { $0 == needle }
	- requires: self is sorted in ascending order
*/
	func binarySearch(needle: Element) -> Int? {
		let index = binarySearchPosition(needle: needle)
		if index == count || self[index] != needle {
			return nil
		} else {
			return index
		}
	}

/**
	Search for needle index.
	Self has to contain needle

	- parameter needle: the element to look for
	- returns:  the index of needle or nil if !self.contains { $0 == needle }
	- requires: self is sorted ascending and self.contains { $0 == needle }
*/
	func binaryFind(needle: Element) -> Int {
		var min = 0;
		var max = count - 1;
		while true {
			let test = (min + max) / 2;
			if self[test] == needle {
				return test
			} else if self[test] < needle {
				min = test + 1
			} else {
				max = test - 1
			}
		}
	}

/**
	Search for proper index for needle

	- parameter needle: the element to look for
	- returns:  the index where needle would be if it were in self
	- requires: self is sorted ascending
*/
	func binarySearchPosition(needle: Element) -> Int {
		if self.isEmpty {
			return 0
		}
		var min = 0;
		var max = count - 1;
		while min < max {
			let test = (min + max) / 2;
			if self[test] == needle {
				return test
			} else if self[test] < needle {
				min = test + 1
			} else {
				max = test - 1
			}
		}
		if min < count && self[min] < needle {
			return min + 1
		} else {
			return  min
		}
	}

/**
	Inserts element in appropriate position

	- parameter element: the element to insert
	- requires: self is sorted ascending
*/
	mutating func binaryInsert(element: Element) {
		let position = binarySearchPosition(needle: element)
		insert(element, at: position)
	}
}
