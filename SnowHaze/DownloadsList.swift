//
//  DownloadsList.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

protocol DownloadsListDelegate: AnyObject {
	func numberOfDownloads(inDownloadsList downloadsList: DownloadsList) -> Int
	func downloadsList(_ downloadsList: DownloadsList, downloadAt index: Int) -> FileDownload

	func downloadsList(_ downloadsList: DownloadsList, deleteDownloadAt index: Int)
	func downloadsList(_ downloadsList: DownloadsList, shareDownloadAt index: Int, from sender: UIView)
	func downloadsList(_ downloadsList: DownloadsList, cancelDownloadAt index: Int)
	func downloadsList(_ downloadsList: DownloadsList, retryDownloadAt index: Int)
}

class DownloadsList: UIView {
	weak var delegate: DownloadsListDelegate? {
		didSet {
			reload()
		}
	}

	private var reloadIndices = Set<Int>()

	private let label = UILabel()
	private let tableView = UITableView()

	// UITableView has a weird issue which makes this necessary
	private lazy var lazySetup: Void = {
		tableView.backgroundColor = .clear
	}()

	init() {
		super.init(frame: .zero)
		label.backgroundColor = .bar
		label.textColor = .title
		label.textAlignment = .center
		label.text = "Downloads"

		tableView.alwaysBounceVertical = false
		tableView.dataSource = self
		tableView.delegate = self

		addSubview(label)
		addSubview(tableView)
	}

	override func layoutSubviews() {
		_ = lazySetup

		label.frame = bounds
		label.frame.size.height = 30

		tableView.frame = bounds
		tableView.frame.size.height -= 30
		tableView.frame.origin.y = 30
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func add() {
		let index = tableView.numberOfRows(inSection: 0)
		tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .fade)
	}

	func reload(at index: Int) {
		let reload: () -> () = { [weak self] in
			guard let self = self, !self.reloadIndices.isEmpty else {
				return
			}
			let indexPaths = self.reloadIndices.map { IndexPath(row: $0, section: 0) }
			UIView.performWithoutAnimation {
				self.tableView.reloadRows(at: indexPaths, with: .fade)
			}
			self.reloadIndices = []
		}
		let isFirst = reloadIndices.isEmpty
		reloadIndices.insert(index)
		guard case .progress(_, _) = delegate?.downloadsList(self, downloadAt: index).state else {
			reload()
			return
		}
		if isFirst {
			DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: reload)
		}
	}

	func delete(at index: Int) {
		tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .fade)
		let remaped = reloadIndices.compactMap { other -> Int? in
			guard index != other else {
				return nil
			}
			return (index < other) ? other - 1 : other
		}
		reloadIndices = Set(remaped)
	}

	func reload() {
		reloadIndices = []
		tableView.reloadData()
	}
}

extension DownloadsList: UITableViewDataSource, UITableViewDelegate {
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return delegate?.numberOfDownloads(inDownloadsList: self) ?? 0
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
		if let download = delegate?.downloadsList(self, downloadAt: indexPath.row) {
			cell.textLabel?.textColor = .title
			cell.detailTextLabel?.textColor = .subtitle
			cell.backgroundColor = UIColor(white: 1, alpha: 0.05)
			cell.selectedBackgroundView = UIView()
			cell.selectedBackgroundView?.backgroundColor = UIColor(white: 1, alpha: 0.2)
			cell.textLabel?.text = download.filename
			let subtitle: String
			let icon: UIImage?
			let iconSize: CGFloat
			switch download.state {
				case .complete(_, _, _):
					subtitle = NSLocalizedString("download list download complete subtitle", comment: "download complete subtitle of download list entry")
					icon = #imageLiteral(resourceName: "share")
					iconSize = 25
				case .error(_):
					if download.startable {
						subtitle = NSLocalizedString("download list download error retry subtitle", comment: "retry after download error subtitle of download list entry")
					} else {
						subtitle = NSLocalizedString("download list unrecoverable download error subtitle", comment: "unrecoverable download error subtitle of download list entry")
					}
					icon = download.startable ? #imageLiteral(resourceName: "reload") : nil
					iconSize = 23
				case .progress(let p, let t):
					let fmt = NSLocalizedString("download list download progress subtitle", comment: "download progress subtitle of download list entry")
					subtitle = String(format: fmt, format(bytes: p), format(bytes: t), "\(100 * p / t)")
					icon = #imageLiteral(resourceName: "close")
					iconSize = 20
				case .progressUnknown:
					subtitle = NSLocalizedString("download list unknown download progress subtitle", comment: "unknown download progress subtitle of download list entry")
					icon = #imageLiteral(resourceName: "close")
					iconSize = 20
			}
			cell.detailTextLabel?.text = subtitle
			let resizedIcon: UIImage?
			if let icon = icon {
				let size = CGSize(width: iconSize, height: iconSize)
				resizedIcon = UIGraphicsImageRenderer(size: size).image { context in
					icon.draw(in: CGRect(origin: .zero, size: size))
				}
			} else {
				resizedIcon = nil
			}
			let iconView = UIImageView(image: resizedIcon?.withRenderingMode(.alwaysTemplate))
			iconView.tintColor = .title
			cell.accessoryView = iconView
		}
		return cell
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let download = delegate?.downloadsList(self, downloadAt: indexPath.row) else {
			return
		}
		switch download.state {
			case .complete(_, _, _):
				if let cell = tableView.cellForRow(at: indexPath) {
					delegate?.downloadsList(self, shareDownloadAt: indexPath.row, from: cell)
				}
			case .error(_):
				if download.startable {
					delegate?.downloadsList(self, retryDownloadAt: indexPath.row)
				}
			case .progress(_, _):
				delegate?.downloadsList(self, cancelDownloadAt: indexPath.row)
			case .progressUnknown:
				delegate?.downloadsList(self, cancelDownloadAt: indexPath.row)
		}
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}

	func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		return .delete
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		delegate?.downloadsList(self, deleteDownloadAt: indexPath.row)
	}
}

/// MARK: internals
private extension DownloadsList {
	func format(bytes: Int64) -> String {
		func addDot(to: Int64) -> String {
			var result = "\(to)"
			result.insert(".", at: result.index(result.endIndex, offsetBy: -2))
			return result
		}
		if bytes < 1024 {
			let fmt = NSLocalizedString("download data size bytes format", comment: "format of string to indicate download size with byte precission")
			return String(format: fmt, "\(bytes)")
		} else if bytes < 1024 * 1024 {
			let fmt = NSLocalizedString("download data size kib format", comment: "format of string to indicate download size with 0.01 kibibyte precission")
			return String(format: fmt, addDot(to: 100 * bytes / 1024))
		} else if bytes < 1024 * 1024 * 1024 {
			let fmt = NSLocalizedString("download data size mib format", comment: "format of string to indicate download size with 0.01 mebibyte precission")
			return String(format: fmt, addDot(to: 100 * bytes / 1024 / 1024))
		} else {
			let fmt = NSLocalizedString("download data size gib format", comment: "format of string to indicate download size with 0.01 gibibyte precission")
			return String(format: fmt, addDot(to: 100 * bytes / 1024 / 1024 / 1024))
		}
	}
}
