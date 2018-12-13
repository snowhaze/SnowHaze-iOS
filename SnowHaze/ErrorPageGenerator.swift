//
//  ErrorPageGenerator.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum ErrorPageGeneratorType {
	case pageError
}

class ErrorPageGenerator {
	private let bodyPattern = "(?<=\\<body>(\\s|))[^\\s][\\w\\W]*?(?=\\s*\\</body>)"
	private let paragraphPattern = "^<p[^>]*><span[^>]*>\\s*|\\s*</span></p>$"
	private static let fontBase64 = try! Data(contentsOf: Bundle.main.url(forResource: SnowHazeFontName, withExtension: "otf")!).base64EncodedString()

	// Style of reload button
	private let buttonBorder = "none"
	private let buttonBorderRadius = "1.5em"
	private let buttonTextAlign = "center"
	private let buttonTextDecoration = "none"
	private let buttonBGColor = UIColor.button.hex
	private let buttonTextColor = UIColor.title.hex
	private let buttonPaddingVertical = "0.2em"
	private let buttonPaddingHorizontal = "1em"

	// Style of page
	private let pageBGColor = UIColor.background.hex
	private let pageTextColor = UIColor.title.hex
	private let pageTextAlign = "center"
	
	private let type: ErrorPageGeneratorType

	var title: String?
	var message: String?
	var url: URL?
	var description: String?
	var errorCode: Int?
	var errorDomain: String?
	var errorReason: String?
	var file: String?
	var mimeType: String?
	
	init(type: ErrorPageGeneratorType) {
		self.type = type
	}
	
	func getHTML() -> String {
		switch type {
			case .pageError: return getErrorPageHTML()
		}
	}

	private func getErrorPageHTML() -> String {
		let memoryGame = MemoryGame()
		let head = getHead(title: getTitle())

		let domainDesc: String
		if let m = message , !m.isEmpty {
			if let host = url?.host {
				domainDesc = encode(html: String(format: m, "'\(host)'"))
			} else {
				let host = NSLocalizedString("error page unknown domain", comment: "error page domain description where no host is available")
				domainDesc = encode(html: String(format: m, host))
			}
		} else {
			if let host = url?.host {
				let msg = NSLocalizedString("error page unexpected error message with url", comment: "message shown when no error message is available but an url")
				domainDesc = encode(html: String(format: msg, host))
			} else {
				domainDesc = encode(html: NSLocalizedString("error page unexpected error message", comment: "message shown when no error message is available"))
			}
		}

		let body = "<h1>\(getTitle())</h1><p>\(domainDesc)</p>\(getDescription())"

		let moreInformation: String
		if let moreInf = getMoreInformation() {
			let detailsString = NSLocalizedString("error page details section title", comment: "title of the details section on the errorpage")
			let moreInformationString = NSLocalizedString("error page more information button title", comment: "title of the button to get more information about the error")

			let container = "<div id='moreInformation' align='center'><h3>\(encode(html: detailsString)):</h3>\(moreInf)</div>"
			let informationScript = """
			<script language="JavaScript">
				var moreInformation = document.getElementById("moreInformation");
				var moreInformationLink = document.getElementById("moreInformationLink");
				moreInformation.style.display = "none";
				moreInformationLink.style.display = "block";
				moreInformationLink.addEventListener("click", function () {
					moreInformation.style.display = "block";
					moreInformationLink.style.display = "none";
				});
			</script>
			""";
			moreInformation = "<br>\(container)<a href='#' style='color:#\(UIColor.button.hex);text-decoration:none;' "
				+ "id='moreInformationLink'>\(encode(html: moreInformationString))</a>\(informationScript)"
		} else {
			moreInformation = ""
		}

		return "<!DOCTYPE html><html>\(head)<body style=\"\(getBodyCSS())\">\(body)\(getReloadButton())\(moreInformation)\(memoryGame.getHTML())</body></html>"
	}

	private func getTitle() -> String {
		let defaultErrorTitle = NSLocalizedString("error page default title", comment: "default title of the errorpage")
		return encode(html: title ?? defaultErrorTitle)
	}

	private func getHead(title: String) -> String {
		let viewPort = "<meta name='viewport' content='initial-scale=1.0,user-scalable=no'>"
		return "<head><title>\(title)</title>\(getCSSStyle())\(viewPort)</head>"
	}

	private func getDescription() -> String {
		if let desc = description , !desc.isEmpty {
			return "<p>\(encode(html: desc))</p>"
		}
		return "<p></p>"
	}

	private func getMoreInformation() -> String? {
		var rows = [String]()

		if let errReason = errorReason {
			let reasonDescriptor = NSLocalizedString("error page error reason description", comment: "description of the error reason on the errorpage")
			rows.append("<td>\(encode(html: reasonDescriptor)):</td><td>\(encode(html: errReason))</td>")
		}
		if let errURL = url {
			let urlDescriptor = NSLocalizedString("error page error url description", comment: "description of the url on the errorpage")
			rows.append("<td>\(encode(html: urlDescriptor)):</td><td>\(encode(html: errURL.absoluteString))</td>")
		}
		if let errFile = file {
			let errorFileDescriptor = NSLocalizedString("error page error file description", comment: "description of the error file on the errorpage")
			rows.append("<td>\(encode(html: errorFileDescriptor)):</td><td>\(encode(html: errFile))</td>")
		}
		if let errMimeType = mimeType {
			let errorMimeTypeDescriptor = NSLocalizedString("error page error mime type description", comment: "description of the error mime type on the errorpage")
			rows.append("<td>\(encode(html: errorMimeTypeDescriptor)):</td><td>\(encode(html: errMimeType))</td>")
		}
		if let errCode = errorCode {
			let errorCodeDescriptor = NSLocalizedString("error page error code description", comment: "description of the error code on the errorpage")
			rows.append("<td>\(encode(html: errorCodeDescriptor)):</td><td>\(errCode)</td>")
		}
		if let errDom = errorDomain {
			let errorDomainDescriptor = NSLocalizedString("error page error domain description", comment: "description of the error domain on the errorpage")
			rows.append("<td>\(encode(html: errorDomainDescriptor)):</td><td>\(encode(html: errDom))</td>")
		}

		guard !rows.isEmpty else {
			return nil
		}

		return "<table><tr>\(rows.joined(separator: "</tr><tr>"))</tr></table>"
	}

	private func getReloadButton() -> String {
		if let u = url {
			let reloadButtonTitle = NSLocalizedString("error page reload button title", comment: "title of the reload button on the errorpage")
			return "<a href='\(u.absoluteString)' style='\(getButtonCSS())'>\(encode(html: reloadButtonTitle))</a><br>"
		}
		return ""
	}

	private func getCSSStyle() -> String {
		let css = "#moreInformationLink {"
				+	"display: none;"
				+ "}"
		let font = "@font-face {"
			+ "font-family: '\(SnowHazeFontName)';"
			+ "src: url('data:font/otf;base64,\(ErrorPageGenerator.fontBase64)') format('opentype');}"
		return "<style>\(css)\(font)</style>"
	}

	private func getBodyCSS() -> String {
		return "background-color:#\(pageBGColor); color:#\(pageTextColor); text-align:\(pageTextAlign);"
			+ "font-family:'\(SnowHazeFontName)'; overflow-wrap: break-word;"
	}

	private func getButtonCSS() -> String {
		return "border:\(buttonBorder); border-radius:\(buttonBorderRadius); text-align:\(buttonTextAlign); text-decoration:\(buttonTextDecoration);"
			+ "background-color:#\(buttonBGColor); color:#\(buttonTextColor); padding:\(buttonPaddingVertical) \(buttonPaddingHorizontal);"
	}

	private func encode(html text: String) -> String {
		let att = NSAttributedString(string: text)
		let htmlData = try! att.data(from: NSRange(text.startIndex ..< text.endIndex, in: text), documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType: NSAttributedString.DocumentType.html])
		let html = String(data: htmlData, encoding: .utf8)!
		let body = String(html.firstMatch(bodyPattern) ?? "")
		return body.replace(paragraphPattern, template: "")
	}
}
