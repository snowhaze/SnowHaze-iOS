//
//  MemoryGame.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class MemoryGame {
	private static let images = [#imageLiteral(resourceName: "snowflake"), #imageLiteral(resourceName: "javascript"), #imageLiteral(resourceName: "searchengine"), #imageLiteral(resourceName: "mediaplayback"), #imageLiteral(resourceName: "https"), #imageLiteral(resourceName: "appearance"), #imageLiteral(resourceName: "popovers"), #imageLiteral(resourceName: "warning"), #imageLiteral(resourceName: "fingerprint"), #imageLiteral(resourceName: "crown"), #imageLiteral(resourceName: "openvpn"), #imageLiteral(resourceName: "weabsitedata"), #imageLiteral(resourceName: "useragent"), #imageLiteral(resourceName: "history"), #imageLiteral(resourceName: "trackingprotection"), #imageLiteral(resourceName: "bookmark"), #imageLiteral(resourceName: "contentblocker"), #imageLiteral(resourceName: "defaults"), #imageLiteral(resourceName: "contact"), #imageLiteral(resourceName: "acknowledgements")]

	private static let cssCardProto = """
		.card-%@ .picture {
			background-image: url("data:image/png;base64,%@");
		}
	"""

	private static let htmlCardProto = """
		<div class="card card-%@">
			<span class="cover"></span>
			<span class="picture"></span>
		</div>
	"""

	private static let cssProto = """
	<style>
		#winmessage {
			display: none;
			width: 100%%;
			text-align: center;
			margin: auto;
			margin-top: 2em;
		}

		#board {
			margin: auto;
			margin-top: 2em;
			display: none;
			transition: all 1s;
			-webkit-user-select: none;
			user-select: none;
		}

		.row {
			display: flex;
			width: 100%%;
			height: %@%%;
			padding: 5px 0;
			box-sizing: border-box;
		}

		.card {
			width: %@%%;
			height: 100%%;
			border-radius: 25%%;
			margin: 0 5px;
			transition: all 1s;
			box-sizing: border-box;
			border: 5px solid #49444E;
			background-color: #49444E;
		}
		.card span {
			position: relative;
			display: block;
			margin: 0;
			padding: 0;
			width: 99%%;
			height: 99%%;
			transition: all 1s;
			border-radius: 25%%;
		}
		.card .cover {
			margin: auto;
			background: #49444E url("data:image/png;base64,%@") 0 0/cover no-repeat;
			z-index: 1000;
		}
		.card .picture {
			top: -100%%;
			background: #49444E 0 0/cover no-repeat;
			transform: rotateY(180deg);
			z-index: 900;
			right: 1px;
			bottom: 1px;
			width: 101%%;
			height: 101%%;
		}

		.found {
			opacity: 0;
		}

		.selected {
			transform: rotateY(-180deg);
		}

		.selected .picture {
			z-index: 1100;
		}
		%@
	</style>
	"""

	private static let javascriptProto = """
	<script language="JavaScript">
	const numTiles = %@;
	var cards = document.getElementsByClassName("card");
	var board = document.getElementById("board");
	var winmessage = document.getElementById("winmessage");

	function selectCard() {
		var selectedCards = Array.prototype.slice.call(document.getElementsByClassName("selected"));
		selectedCards = selectedCards.filter(function (t) { return !t.classList.contains("found"); });
		if (!this.classList.contains("selected") && selectedCards.length < 2) {
			this.classList.add("selected");
			checkCards();
		}

	}

	function checkCards() {
		var selectedCards = Array.prototype.slice.call(document.getElementsByClassName("selected"));
		selectedCards = selectedCards.filter(function (t) { return !t.classList.contains("found"); });
		if (selectedCards.length >= 2) {
			var first = selectedCards[0];
			var second = selectedCards[1];
			if (first.classList.length === second.classList.length) {
				for (i = 0; i < first.classList.length; i++) {
					if (!second.classList.contains(first.classList.item(i))) break;
				}
				if (i >= first.classList.length) {
					setTimeout(function () {
						first.classList.add("found");
						second.classList.add("found");
						if (document.getElementsByClassName("found").length === numTiles) {
							showWinMessage();
						}
					}, 750);
					return;
				}
			}
			setTimeout(unselectCards, 1000);
		}
	}

	function unselectCards() {
		var selectedCards = Array.prototype.slice.call(document.getElementsByClassName("selected"));
		selectedCards = selectedCards.filter(function (t) { return !t.classList.contains("found"); });
		for (var card of selectedCards) {
			card.classList.remove("selected");
		}
	}

	function showWinMessage() {
		board.style.display = "none";
		winmessage.style.display = "block";
		setTimeout(function () {
			winmessage.style.display = "none";
		}, 10000);
	}

	function resizeBoard() {
		var width = window.innerWidth;
		var height = window.innerHeight;
		var size = Math.min(width, height) - 10;
		board.style.height = size + "px";
		board.style.width = size + "px";
	}

	for (var card of cards) {
		card.addEventListener('click', selectCard, false);
	}

	resizeBoard();

	board.style.display = "block";

	window.addEventListener('resize', resizeBoard);
	</script>
	"""

	let width: Int
	let height: Int

	var size: Int {
		return width * height
	}

	lazy var selectedImages = randomize()

	init(width: Int = 4, height: Int = 4) {
		self.width = width
		self.height = height
	}

	private func randomize() -> [Int] {
		var selected = [Int]()
		for _ in 0 ..< (size + 1) / 2 {
			var random: Int
			repeat {
				random = MemoryGame.images.randomIndex
			} while (selected.contains(random))
			selected.append(random)
		}
		return selected
	}

	private func getCSS() -> String {
		let cardCss = selectedImages.map({ index in
			let image = MemoryGame.images[index]
			UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
			let context = UIGraphicsGetCurrentContext()
			let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
			UIColor.button.setFill()
			context?.scaleBy(x: 1, y: -1)
			context?.translateBy(x: 0, y: -image.size.height)
			if let cgImage = image.cgImage {
				context?.clip(to: rect, mask: cgImage)
			}
			context?.fill(rect)
			let base64: String
			if let coloredImage = UIGraphicsGetImageFromCurrentImageContext() {
				base64 = coloredImage.pngData()?.base64EncodedString() ?? ""
			} else {
				base64 = ""
			}
			UIGraphicsEndImageContext()

			return String(format: MemoryGame.cssCardProto, String(index), base64)
		}).joined()

		let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? NSDictionary
		let primaryIconsDictionary = iconsDictionary?["CFBundlePrimaryIcon"] as? NSDictionary
		let iconFiles = primaryIconsDictionary?["CFBundleIconFiles"] as? [String]
		let sortedIcons = iconFiles?.sorted { ($0 as NSString).compare($1, options: .numeric) == .orderedAscending }
		let base64: String
		if let iconFile = sortedIcons?.last {
			if let icon = UIImage(named: iconFile) {
				base64 = icon.pngData()?.base64EncodedString() ?? ""
			} else {
				base64 = ""
			}
		} else {
			base64 = ""
		}

		return String(format: MemoryGame.cssProto, String(100.0 / Double(height)), String(100.0 / Double(width)), base64, cardCss)
	}

	private func getJavascript() -> String {
		return String(format: MemoryGame.javascriptProto, String(size))
	}

	func getHTML() -> String {
		var selected = selectedImages + selectedImages
		var html = "<div id=\"board\">"
		for _ in 0 ..< height {
			html += "<div class=\"row\">"
			for _ in 0 ..< width {
				let cardNum = selected.removeRandomElement()
				html += String(format: MemoryGame.htmlCardProto, String(cardNum))
			}
			html += "</div>"
		}
		html += "</div>";
		let congratMessage = NSLocalizedString("congratulation message html", comment: "HTML of message shown when the memory game is won")
		html += """
		<div id="winmessage">
		<h1>\(congratMessage)</h1>
		</div>
		"""
		return getCSS() + html + getJavascript()
	}
}
