//
//  FileDownload.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation

protocol FileDownloadDelegate: class {
	func downloadStatusChanged(_ download: FileDownload, index: Int)
	func downloadDeleted(_ download: FileDownload, index: Int)
	func newDownloadStarted(_ download: FileDownload)
}

class FileDownload {
	private static let folder: URL = {
		let library = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first!
		return URL(fileURLWithPath: library).appendingPathComponent("Downloads")
	}()

	private let request: URLRequest?
	private let fetcher: DataFetcher?
	private(set) var state = DataFetcher.DownloadEvent.progressUnknown
	private init?(url: URL, cookies: [HTTPCookie], tab: Tab) {
		let url = url.detorified ?? url
		guard ["http", "https", "data"].contains(url.normalizedScheme) else {
			return nil
		}
		var request = URLRequest(url: url)
		request.allHTTPHeaderFields = request.allHTTPHeaderFields ?? [:]
		request.allHTTPHeaderFields!["Accept"] = "*/*"
		self.request = request
		self.fetcher = DataFetcher(tab: tab, cookies: cookies)
	}

	private init(fileUrl: URL) {
		self.state = .complete(url: fileUrl, file: nil, mime: nil)
		self.request = nil
		self.fetcher = nil
	}

	var startable: Bool {
		return fetcher?.usable ?? false
	}

	private static func sanitize(fileName: String?) -> String {
		if let fileName = fileName, !fileName.isEmpty, ![".", ".."].contains(fileName) {
			return fileName.replacingOccurrences(of: "/", with: "-")
		}
		return NSLocalizedString("download fallback file name", comment: "file name used for downloaded file if none can be determined")
	}

	var url: URL? {
		switch state {
			case .complete(let url, _, _):	return url
			default:						return nil
		}
	}

	var filename: String {
		switch state {
			case .complete(let url, _, _):	return FileDownload.sanitize(fileName: url.lastPathComponent)
			default:						return FileDownload.sanitize(fileName: request?.url?.lastPathComponent)
		}
	}

	var progress: Double {
		switch state {
			case .progressUnknown:			return -1
			case .progress(let p, let t):	return (p > t) ? -1 : Double(p) / Double(t)
			case .complete(_, _, _):		return 1
			case .error(_):					return -Double.infinity
		}
	}

	private static func file(for name: String?) -> URL {
		let sanitized = sanitize(fileName: name)
		let index = sanitized.lastIndex(of: ".")
		let prefix: String
		let suffix: String
		if let index = index, index != sanitized.startIndex {
			prefix = String(sanitized[sanitized.startIndex ..< index])
			suffix = String(sanitized[index...])
		} else {
			prefix = sanitized
			suffix = ""
		}
		var count = 1
		while true {
			let file: String
			if count == 1 {
				file = prefix + suffix
			} else {
				file = prefix + " \(count)" + suffix
			}
			let url = folder.appendingPathComponent(file)
			if !FileManager.default.fileExists(atPath: url.path) {
				return url
			}
			count += 1
		}
	}

	func start() {
		let requestURL = request?.url
		fetcher!.download(request!) { event in
			self.state = event
			if case .complete(let url, let file, let mime) = event {
				var suggested = file ?? requestURL?.lastPathComponent
				if mime == "application/x-openvpn-profile", let name = suggested, !name.contains(".") {
					suggested = name + ".ovpn"
				}
				let dst = FileDownload.file(for: suggested)
				try! FileManager.default.moveItem(at: url, to: dst)
				self.state = .complete(url: dst, file: nil, mime: nil)
			}
			FileDownload.stateChanged(self)
		}
	}

	func stop() {
		fetcher?.cancel()
	}

	private func delete() {
		if case .complete(let url, nil, nil) = self.state {
			try! FileManager.default.removeItem(at: url)
		}
	}

	static weak var delegate: FileDownloadDelegate?

	static var downloads = initOldDownloads()

	private static func initOldDownloads() -> [FileDownload] {
		if !FileManager.default.fileExists(atPath: folder.path) {
			try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		}
		let urls = try! FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
		return urls.map { FileDownload(fileUrl: $0) }
	}

	private class func stateChanged(_ download: FileDownload) {
		let index = downloads.firstIndex(where: { download === $0 })
		if let index = index {
			delegate?.downloadStatusChanged(download, index: index)
		}
	}

	class func start(for url: URL, cookies: [HTTPCookie], tab: Tab) {
		guard let download = FileDownload(url: url, cookies: cookies, tab: tab) else {
			return
		}
		downloads.append(download)
		delegate?.newDownloadStarted(download)
		download.start()
	}

	class var progress: Double {
		var ok = true
		var progress: Int64 = 0
		var total: Int64 = 0
		for download in downloads {
			switch download.state {
				case .complete(_, _, _):	break
				case .error(_):				break
				case .progress(let p, let t):
					progress += p
					total += t
				case .progressUnknown:
					ok = false
			}
		}
		return (ok && total > 0) ? Double(progress) / Double(total) : -1
	}

	class func delete(at index: Int) {
		guard index < downloads.count else {
			return
		}
		let download = downloads[index]
		download.stop()
		download.delete()
		downloads.remove(at: index)
		delegate?.downloadDeleted(download, index: index)
	}
}
