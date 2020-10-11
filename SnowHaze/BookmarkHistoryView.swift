//
//  BookmarkHistoryView.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit

protocol BookmarkHistoryDelegate: StatsViewDelegate {
	var viewControllerForPreviewing: UIViewController { get }
	var viewControllerForSharing: UIViewController { get }

	func previewController(for url: URL) -> PagePreviewController?
	func load(_ type: WebLoadType)

	var historyItems: [[HistoryItem]]? { get }
	func removeHistoryItem(at indexPath: IndexPath)
	func removeSection(atIndex index: Int)
	func didSelect(historyItem item: HistoryItem)

	var bookmarks: [Bookmark] { get }
	func didSelect(bookmark: Bookmark)
	func remove(bookmark: Bookmark)
	func refresh(bookmark: Bookmark)
	func rename(bookmark: Bookmark)

	func makeBookmark(for: URL)

	var downloads: [FileDownload] { get }
	func delete(_ download: FileDownload, at index: Int)
	func share(_ download: FileDownload, from sender: UIView)
	func retry(_ download: FileDownload)
	func cancel(_ download: FileDownload)
}

@IBDesignable
class BookmarkHistoryView: UIView {
	let headerHeight: CGFloat = 30

	private let bookmarkButton = UIButton()
	private let historyBytton = UIButton()
	private let bookmarkCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
	private let historyTableView = UITableView()
	private let historyBGView = UIImageView(image: #imageLiteral(resourceName: "Background"))

	private var historyHeaderCache = [Int: HistoryTableViewSectionHeader]()

	private let downloadsList = DownloadsList()

	private var lefSwipeRecognize: UISwipeGestureRecognizer!
	private var rightSwipeRecognize: UISwipeGestureRecognizer!

	private let dateFormatter = DateFormatter()

	private var showingHistoryInSingleMode = false
	private var isShowingDownloads = false

	private var observers = [NSObjectProtocol]()

	private var internalHistoryItems: [[HistoryItem]]?
	private var internalBookmarks: [Bookmark]?

	// UITableView has a weird issue which makes this necessary
	private lazy var lazySetup: Void = {
		historyTableView.backgroundColor = .clear
	}()

	var hideStats = false {
		didSet {
			setStatsHidden()
		}
	}

	weak var delegate: BookmarkHistoryDelegate? { // should be set before table-/collectionview cells are loaded and cannot be changed, as it is used for 3D touch previews
		didSet {
			reloadBookmarks()
			downloadsList.reload()
		}
	}

	var historyItems: [[HistoryItem]] {
		if internalHistoryItems == nil {
			internalHistoryItems = delegate?.historyItems
		}
		return internalHistoryItems ?? [[HistoryItem]]()
	}

	var bookmarks: [Bookmark] {
		if internalBookmarks == nil {
			internalBookmarks = delegate?.bookmarks ?? []
		}
		return internalBookmarks!
	}

	var constrainedHeight: Bool = false {
		didSet {
			setStatsHidden()
			layoutSubviews()
		}
	}

	var constrainedWidth: Bool = false {
		didSet {
			if constrainedWidth {
				bookmarkButton.setTitleColor(.dimmedTitle, for: [])
				historyBytton.setTitleColor(.dimmedTitle, for: [])
				let historyX: CGFloat
				let bookmarkX: CGFloat
				if showingHistoryInSingleMode {
					historyX = 0
					bookmarkX = -bounds.width
				} else {
					historyX = bounds.width
					bookmarkX = 0
				}
				historyBGView.frame = bounds
				historyBGView.frame.size.height -= headerHeight
				historyBGView.frame.origin.y += headerHeight
				historyBGView.frame.origin.x = historyX

				bookmarkCollectionView.frame = bounds
				bookmarkCollectionView.frame.size.height -= headerHeight
				bookmarkCollectionView.frame.origin.y += headerHeight
				bookmarkCollectionView.frame.origin.x = bookmarkX
			} else {
				bookmarkButton.setTitleColor(.white, for: [])
				historyBytton.setTitleColor(.white, for: [])
				let bookmarkFrame = CGRect(x: 0, y: headerHeight, width: bounds.width / 2 - 0.5, height: bounds.height - headerHeight)
				let historyFrame = CGRect(x: bounds.width / 2 + 0.5, y: headerHeight, width: bounds.width / 2 - 0.5, height: bounds.height - headerHeight)
				bookmarkCollectionView.frame = bookmarkFrame
				historyBGView.frame = historyFrame
			}
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setup()
	}

	override func layoutSubviews() {
		_ = lazySetup
		if constrainedWidth {
			let historyX: CGFloat
			let bookmarkX: CGFloat
			if showingHistoryInSingleMode {
				historyX = 0
				bookmarkX = -bounds.width
			} else {
				historyX = bounds.width
				bookmarkX = 0
			}
			historyBGView.frame = bounds
			historyBGView.frame.size.height -= headerHeight
			historyBGView.frame.origin.y += headerHeight
			historyBGView.frame.origin.x = historyX

			bookmarkCollectionView.frame = bounds
			bookmarkCollectionView.frame.size.height -= headerHeight
			bookmarkCollectionView.frame.origin.y += headerHeight
			bookmarkCollectionView.frame.origin.x = bookmarkX
		} else {
			let bookmarkFrame = CGRect(x: 0, y: headerHeight, width: bounds.width / 2 - 0.5, height: bounds.height - headerHeight)
			let historyFrame = CGRect(x: bounds.width / 2 + 0.5, y: headerHeight, width: bounds.width / 2 - 0.5, height: bounds.height - headerHeight)
			bookmarkCollectionView.frame = bookmarkFrame
			historyBGView.frame = historyFrame
		}
		if !constrainedHeight && isShowingDownloads {
			historyTableView.frame = historyBGView.bounds
			historyTableView.frame.size.height -= historyBGView.bounds.height * 2 / 5
			downloadsList.frame = historyBGView.bounds
			downloadsList.frame.origin.y += historyBGView.bounds.height * 3 / 5
			downloadsList.frame.size.height -= historyBGView.bounds.height * 3 / 5
		} else {
			historyTableView.frame = historyBGView.bounds
			downloadsList.frame = historyBGView.bounds
			downloadsList.frame.origin.y += historyBGView.bounds.height
			downloadsList.frame.size.height -= historyBGView.bounds.height * 3 / 5
		}
	}

	func showHistory(_ history: Bool, animated: Bool) {
		guard showingHistoryInSingleMode != history else {
			return
		}
		defer {
			showingHistoryInSingleMode = history
		}
		historyBytton.isEnabled = !history
		bookmarkButton.isEnabled = history

		lefSwipeRecognize.isEnabled = !history
		rightSwipeRecognize.isEnabled = history

		guard constrainedWidth else {
			return
		}
		let historyX: CGFloat
		let bookmarkX: CGFloat
		if history {
			historyX = 0
			bookmarkX = -bounds.width
		} else {
			historyX = bounds.width
			bookmarkX = 0
		}
		if animated {
			UIView.animate(withDuration: 0.3, animations: {
				self.historyBGView.frame.origin.x = historyX
				self.bookmarkCollectionView.frame.origin.x = bookmarkX
			})
		} else {
			historyBGView.frame.origin.x = historyX
			bookmarkCollectionView.frame.origin.x = bookmarkX
		}
	}

	func showDownloads(_ show: Bool, animated: Bool) {
		guard show != isShowingDownloads else {
			return
		}
		isShowingDownloads = show
		guard !constrainedHeight else {
			return
		}
		func update() {
			if show {
				historyTableView.frame = historyBGView.bounds
				historyTableView.frame.size.height -= historyBGView.bounds.height * 2 / 5
				downloadsList.frame = historyBGView.bounds
				downloadsList.frame.origin.y += historyBGView.bounds.height * 3 / 5
				downloadsList.frame.size.height -= historyBGView.bounds.height * 3 / 5
			} else {
				historyTableView.frame = historyBGView.bounds
				downloadsList.frame = historyBGView.bounds
				downloadsList.frame.origin.y += historyBGView.bounds.height
				downloadsList.frame.size.height -= historyBGView.bounds.height * 3 / 5
			}
		}
		if animated {
			UIView.animate(withDuration: 0.2) { update() }
		} else {
			update()
		}
	}

	override func safeAreaInsetsDidChange() {
		super.safeAreaInsetsDidChange()
		bookmarkCollectionView.contentInset = safeAreaInsets
		bookmarkCollectionView.horizontalScrollIndicatorInsets = safeAreaInsets
		bookmarkCollectionView.verticalScrollIndicatorInsets = safeAreaInsets
	}

	deinit {
		for observer in observers {
			NotificationCenter.default.removeObserver(observer)
		}
	}
}

// MARK: Actions
extension BookmarkHistoryView {
	@objc private func showBookmarks(_ sender: AnyObject) {
		showHistory(false, animated: true)
	}

	@objc private func showHistory(_ sender: AnyObject) {
		showHistory(true, animated: true)
	}
}

// MARK: Internal methosds
private extension BookmarkHistoryView {
	func setup() {
		lefSwipeRecognize = UISwipeGestureRecognizer(target: self, action: #selector(showHistory(_:)))
		lefSwipeRecognize.direction = .left
		lefSwipeRecognize.delegate = self
		addGestureRecognizer(lefSwipeRecognize)

		rightSwipeRecognize = UISwipeGestureRecognizer(target: self, action: #selector(showBookmarks(_:)))
		rightSwipeRecognize.direction = .right
		rightSwipeRecognize.delegate = self
		addGestureRecognizer(rightSwipeRecognize)

		let rect = CGRect(x: 0, y: 0, width: bounds.width, height: headerHeight)
		let header = UIView(frame: rect)
		header.backgroundColor = .bar
		header.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]

		clipsToBounds = true

		let bookmarkTitle = NSLocalizedString("bookmarks view title", comment: "title for bookmark section")
		bookmarkButton.setTitle(bookmarkTitle, for: [])
		bookmarkButton.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth, .flexibleRightMargin]
		header.addSubview(bookmarkButton)
		bookmarkButton.frame = CGRect(x: 0, y: -7, width: bounds.width / 2, height: headerHeight + 5)
		bookmarkButton.isEnabled = false
		bookmarkButton.addTarget(self, action: #selector(showBookmarks(_:)), for: .touchUpInside)
		bookmarkButton.setTitleColor(.white, for: .disabled)

		let historyTitle = NSLocalizedString("history view title", comment: "title for history section")
		historyBytton.setTitle(historyTitle, for: [])
		historyBytton.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth, .flexibleLeftMargin]
		header.addSubview(historyBytton)
		historyBytton.frame = CGRect(x: bounds.width / 2, y: -7, width: bounds.width / 2, height: headerHeight + 5)
		historyBytton.addTarget(self, action: #selector(showHistory(_:)), for: .touchUpInside)
		historyBytton.setTitleColor(.white, for: .disabled)

		let bookmarkBGView = UIImageView(image: #imageLiteral(resourceName: "Background"))
		bookmarkBGView.contentMode = .scaleAspectFill
		historyBGView.contentMode = .scaleAspectFill

		bookmarkCollectionView.dataSource = self
		bookmarkCollectionView.delegate = self
		bookmarkCollectionView.backgroundView = bookmarkBGView
		let layout = bookmarkCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
		layout.itemSize = CGSize(width: 100, height: 160)
		layout.minimumLineSpacing = 30
		layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
		layout.headerReferenceSize = CGSize(width: 100, height: 100)
		bookmarkCollectionView.register(StatsView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "stats")

		historyTableView.dataSource = self
		historyTableView.delegate = self
		historyTableView.alwaysBounceVertical = false
		historyTableView.rowHeight = 50

		historyTableView.frame = historyBGView.bounds
		historyTableView.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleBottomMargin]
		historyTableView.isOpaque = false

		downloadsList.frame = historyBGView.bounds
		downloadsList.frame.origin.y += historyBGView.bounds.height
		downloadsList.frame.size.height -= historyBGView.bounds.height * 3 / 5
		downloadsList.autoresizingMask = [.flexibleWidth, .flexibleHeight, .flexibleTopMargin]
		downloadsList.isOpaque = false
		downloadsList.delegate = self

		bookmarkCollectionView.contentInset = safeAreaInsets
		bookmarkCollectionView.horizontalScrollIndicatorInsets = safeAreaInsets
		bookmarkCollectionView.verticalScrollIndicatorInsets = safeAreaInsets

		bookmarkCollectionView.register(BookmarkCollectionViewCell.self, forCellWithReuseIdentifier: "bookmarkCell")
		historyTableView.register(HistoryTableViewCell.self, forCellReuseIdentifier: "historyCell")

		backgroundColor = .darkSeparator

		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .none
		dateFormatter.doesRelativeDateFormatting = true

		historyBGView.isUserInteractionEnabled = true
		historyBGView.isOpaque = true
		historyBGView.addSubview(historyTableView)
		historyBGView.addSubview(downloadsList)
		historyBGView.clipsToBounds = true

		addSubview(bookmarkCollectionView)
		addSubview(historyBGView)
		addSubview(header)

		let dropInteraction = UIDropInteraction(delegate: self)
		dropInteraction.allowsSimultaneousDropSessions = false
		bookmarkCollectionView.addInteraction(dropInteraction)

		let timeObserver = NotificationCenter.default.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: nil) { [weak self] _ in
			self?.historyHeaderCache = [:]
			self?.historyTableView.reloadSectionIndexTitles()
		}
		observers.append(timeObserver)

		let fontObserver = NotificationCenter.default.addObserver(forName: UIContentSizeCategory.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
			self?.historyTableView.reloadData()
		}
		observers.append(fontObserver)

		if #available(iOS 13, *) {
			addInteraction(UIContextMenuInteraction(delegate: self))
		}
	}

	private func setStatsHidden() {
		if constrainedHeight || hideStats {
			let layout = bookmarkCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
			layout.headerReferenceSize = CGSize(width: 0, height: 0)
		} else {
			let layout = bookmarkCollectionView.collectionViewLayout as! UICollectionViewFlowLayout
			layout.headerReferenceSize = CGSize(width: 85, height: 85)
		}
	}
}

extension BookmarkHistoryView: UITableViewDataSource {
	func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return 30
	}

	func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if historyHeaderCache[section] == nil {
			let item = historyItems[section].first!
			let title = dateFormatter.string(from: item.timestamp)
			historyHeaderCache[section] = HistoryTableViewSectionHeader(title: title, section: section, delegate: self)
		}
		return historyHeaderCache[section]
	}

	func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return section == historyItems.count - 1 ? 1 : 20
	}

	func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return UIView()
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return historyItems[section].count
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		let sectionCount = historyItems.count
		if sectionCount > 0 {
			tableView.separatorStyle = .singleLine
		} else {
			tableView.separatorStyle = .none
		}
		return sectionCount
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell") as! HistoryTableViewCell
		if #available(iOS 13, *) {
			// use context menu
		} else if !cell.previewRegistered, let vc = delegate?.viewControllerForPreviewing {
			vc.registerForPreviewing(with: self, sourceView: cell)
			cell.previewRegistered = true
		}
		cell.historyItem = historyItems[indexPath.section][indexPath.row]
		return cell
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		removeHistoryItem(at: indexPath)
	}
}

extension BookmarkHistoryView: UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		delegate?.didSelect(historyItem: historyItems[indexPath.section][indexPath.row])
		tableView.deselectRow(at: indexPath, animated: true)
	}
}

extension BookmarkHistoryView: UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "stats", for: indexPath)
		if let stackView = view as? StatsView {
			stackView.delegate = self.delegate
		}
		return view
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return bookmarks.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "bookmarkCell", for: indexPath) as! BookmarkCollectionViewCell
		if #available(iOS 13, *) {
			// use context menu
		} else if !cell.previewRegistered, let vc = delegate?.viewControllerForPreviewing {
			vc.registerForPreviewing(with: self, sourceView: cell)
			cell.previewRegistered = true
		}
		cell.bookmark = bookmarks[indexPath.row]
		cell.delegate = self
		return cell
	}
}

extension BookmarkHistoryView: UICollectionViewDelegate {
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		delegate?.didSelect(bookmark: bookmarks[indexPath.row])
		collectionView.deselectItem(at: indexPath, animated: true)
	}
}

// MARK: History View
extension BookmarkHistoryView {
	func reloadHistory() {
		internalHistoryItems = nil
		historyHeaderCache = [:]
		historyTableView.reloadData()
	}

	func removeHistoryItem(at indexPath: IndexPath) {
		delegate?.removeHistoryItem(at: indexPath)
	}

	func removeHistoryItems(in sectionIndex: Int) {
		delegate?.removeSection(atIndex: sectionIndex)
	}

	func insertHistoryItem(section: Int, index: Int?) {
		internalHistoryItems = nil
		if let index = index {
			historyTableView.insertRows(at: [IndexPath(row: index, section: section)], with: .automatic)
		} else {
			for index in (section ... historyItems.count).reversed() {
				if let header = historyHeaderCache[index] {
					historyHeaderCache[index] = nil
					historyHeaderCache[index + 1] = header
					header.section = index + 1
				}
			}
			historyTableView.insertSections(IndexSet(integer: section), with: .automatic)
		}
	}

	func deleteHistoryItems(section: Int, index: Int?) {
		internalHistoryItems = nil
		if let index = index {
			historyTableView.deleteRows(at: [IndexPath(row: index, section: section)], with: .automatic)
		} else {
			historyHeaderCache[section] = nil
			for index in section ... historyItems.count {
				if let header = historyHeaderCache[index] {
					historyHeaderCache[index] = nil
					historyHeaderCache[index - 1] = header
					header.section = index - 1
				}
			}
			historyTableView.deleteSections(IndexSet(integer: section), with: .automatic)
		}
	}
}

// MARK: Bookmark View
extension BookmarkHistoryView {
	func reloadBookmarks() {
		internalBookmarks = nil
		_ = bookmarks
		bookmarkCollectionView.reloadData()
	}

	func reloadBookmarks(new: [Int]?, deleted: [Int]?, movedFrom: [Int]?, movedTo: [Int]?) {
		let addIndexPaths = new?.map { IndexPath(item: $0, section: 0) } ?? []
		let deleteIndexPaths = deleted?.map { IndexPath(item: $0, section: 0) } ?? []
		let fromIndexPaths = movedFrom?.map { IndexPath(item: $0, section: 0) } ?? []
		let toIndexPaths = movedTo?.map { IndexPath(item: $0, section: 0) } ?? []
		bookmarkCollectionView.performBatchUpdates({ () -> () in
			self.bookmarkCollectionView.insertItems(at: addIndexPaths)
			self.bookmarkCollectionView.deleteItems(at: deleteIndexPaths)
			for (fromPath, toPath) in zip(fromIndexPaths, toIndexPaths) {
				self.bookmarkCollectionView.moveItem(at: fromPath, to: toPath)
			}
			internalBookmarks = nil
			_ = bookmarks
		}, completion: nil)
	}
}

// MARK: Downloads List
extension BookmarkHistoryView {
	func reloadDownloads() {
		downloadsList.reload()
	}

	func addDownload() {
		downloadsList.add()
	}

	func reload(download index: Int) {
		downloadsList.reload(at: index)
	}

	func delete(download index: Int) {
		downloadsList.delete(at: index)
	}
}

// MARK: Stats View
extension BookmarkHistoryView {
	func reloadStats() {
		bookmarkCollectionView.reloadData()
	}
}

extension BookmarkHistoryView: BookmarkCollectionViewCellDelegate {
	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestDeleteBookmark bookmark: Bookmark) {
		delegate?.remove(bookmark: bookmark)
	}

	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestRefreshBookmark bookmark: Bookmark) {
		delegate?.refresh(bookmark: bookmark)
	}

	func bookmarkCell(_ cell: BookmarkCollectionViewCell, didRequestRenameBookmark bookmark: Bookmark) {
		delegate?.rename(bookmark: bookmark)
	}
}

extension BookmarkHistoryView: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
}

extension BookmarkHistoryView: HistoryTableViewSectionHeaderDelegate {
	func historySectionHeader(_ header: HistoryTableViewSectionHeader, commitDeletionOfSection sectionIndex: Int) {
		removeHistoryItems(in: sectionIndex)
	}
}

extension BookmarkHistoryView: UIDropInteractionDelegate {
	func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
		return session.canLoadObjects(ofClass: URL.self) && session.items.count == 1
	}

	func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
		let location = session.location(in: self)
		if bounds.contains(location) {
			return UIDropProposal(operation: .copy)
		} else {
			return UIDropProposal(operation: .cancel)
		}
	}

	func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
		if session.canLoadObjects(ofClass: URL.self) {
			_ = session.loadObjects(ofClass: URL.self) { [weak self]  urls in
				assert(urls.count == 1)
				DispatchQueue.main.async {
					if let self = self, let delegate = self.delegate {
						delegate.makeBookmark(for: urls[0])
					}
				}
			}
		}
	}
}

// MARK: UIViewControllerPreviewingDelegate
extension BookmarkHistoryView: UIViewControllerPreviewingDelegate {
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		if #available(iOS 13, *) {
			// use context menu
			return nil
		} else if let cell = previewingContext.sourceView as? HistoryTableViewCell {
			guard let indexPath = historyTableView.indexPath(for: cell) else {
				return nil
			}
			let item = historyItems[indexPath.section][indexPath.row]
			let url = item.url as URL
			if let previewVC = delegate?.previewController(for: url) {
				let openHistoryTitle = NSLocalizedString("open history item preview action title", comment: "title of preview action to open the url of a history item")
				let open = UIPreviewAction(title: openHistoryTitle, style: .default) { [weak self] _, _ in
					self?.delegate?.didSelect(historyItem: item)
				}
				let copyHistoryTitle = NSLocalizedString("copy history item preview action title", comment: "title of preview action to copy the url of a history item")
				let copy = UIPreviewAction(title: copyHistoryTitle, style: .default) { _, _ in
					UIPasteboard.general.url = item.url
				}
				let shareHistoryTitle = NSLocalizedString("share history item preview action title", comment: "title of preview action to share the url of a history item")
				let share = UIPreviewAction(title: shareHistoryTitle, style: .default) { [weak self] _, _ in
					let items = [item.title as AnyObject, item.url as AnyObject]
					let controller = UIActivityViewController(activityItems: items, applicationActivities: [])
					controller.popoverPresentationController?.sourceView = cell.superview
					controller.popoverPresentationController?.sourceRect = cell.frame
					self?.delegate?.viewControllerForSharing.present(controller, animated: true, completion: nil)
				}
				previewVC.previewActionItems = [open, copy, share]
				return previewVC
			}
			return nil
		} else if let cell = previewingContext.sourceView as? BookmarkCollectionViewCell {
			guard let indexPath = bookmarkCollectionView.indexPath(for: cell) else {
				return nil
			}
			let bookmark = bookmarks[indexPath.row]
			let url = bookmark.URL as URL
			if let previewVC = delegate?.previewController(for: url) {
				let openBookmarkTitle = NSLocalizedString("open bookmark preview action title", comment: "title of preview action to open the url of a bookmark")
				let open = UIPreviewAction(title: openBookmarkTitle, style: .default) { [weak self] _, _ in
					self?.delegate?.didSelect(bookmark: bookmark)
				}
				let copyBookmarkTitle = NSLocalizedString("copy bookmark preview action title", comment: "title of preview action to copy the url of a bookmark")
				let copy = UIPreviewAction(title: copyBookmarkTitle, style: .default) { _, _ in
					UIPasteboard.general.url = bookmark.URL
				}
				let shareBookmarkTitle = NSLocalizedString("share bookmark preview action title", comment: "title of preview action to share the url of a bookmark")
				let share = UIPreviewAction(title: shareBookmarkTitle, style: .default) { [weak self] _, _ in
					let items = [bookmark.title as AnyObject, bookmark.URL as AnyObject, bookmark.favicon as AnyObject]
					let controller = UIActivityViewController(activityItems: items, applicationActivities: [])
					controller.popoverPresentationController?.sourceView = cell.superview
					controller.popoverPresentationController?.sourceRect = cell.frame
					self?.delegate?.viewControllerForSharing.present(controller, animated: true, completion: nil)
				}
				previewVC.previewActionItems = [open, copy, share]
				return previewVC
			}
			return nil
		}
		fatalError("previewingContext.sourceView should be eigther a HistoryTableViewCell or a BookmarkCollectionViewCell")
	}

	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
		guard let previewer = viewControllerToCommit as? PagePreviewController else {
			return
		}
		delegate?.load(previewer.commitLoad)
	}
}


@available(iOS 13.0, *)
extension BookmarkHistoryView: UIContextMenuInteractionDelegate {
	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
		let url: URL
		let bookmark: Bookmark?
		let historyItem: HistoryItem?
		let source: UIView
		let bookmarkLocation = interaction.location(in: bookmarkCollectionView)
		let historyLocation = interaction.location(in: historyTableView)
		if bookmarkCollectionView.bounds.contains(bookmarkLocation) {
			historyItem = nil
			guard let indexPath = bookmarkCollectionView.indexPathForItem(at: bookmarkLocation) else {
				return nil
			}
			guard let cell = bookmarkCollectionView.cellForItem(at: indexPath) as? BookmarkCollectionViewCell else {
				return nil
			}
			source = cell
			url = cell.bookmark.URL
			bookmark = cell.bookmark
		} else if historyTableView.bounds.contains(historyLocation) {
			bookmark = nil
			guard let indexPath = historyTableView.indexPathForRow(at: historyLocation) else {
				return nil
			}
			guard let cell = historyTableView.cellForRow(at: indexPath) as? HistoryTableViewCell else {
				return nil
			}
			guard let item = cell.historyItem else {
				return nil
			}
			source = cell
			historyItem = item
			url = item.url
		} else {
			return nil
		}
		var menus = [UIMenu]()
		var urlActions = [UIMenuElement]()
		let openTitle = NSLocalizedString("open url bookmark or history context menu action title", comment: "title of the action to open the url in the bookmark or history context menu")
		urlActions.append(UIAction(title: openTitle, image: #imageLiteral(resourceName: "open-context").withRenderingMode(.alwaysTemplate)) { [weak self] _ in
			self?.delegate?.load(.url(url))
		})
		let copyTitle = NSLocalizedString("copy url bookmark or history context menu action title", comment: "title of the action to copy the url in the bookmark or history context menu")
		urlActions.append(UIAction(title: copyTitle, image: #imageLiteral(resourceName: "copy-context").withRenderingMode(.alwaysTemplate)) { _ in
			UIPasteboard.general.url = url
		})
		menus.append(UIMenu(title: url.absoluteString, options: .displayInline, children: urlActions))
		if let bookmark = bookmark {
			var bookmarkActions = [UIMenuElement]()
			let shareTitle = NSLocalizedString("share bookmark context menu action title", comment: "title of the action to share the bookmark in the bookmark context menu")
			bookmarkActions.append(UIAction(title: shareTitle, image: #imageLiteral(resourceName: "share-context").withRenderingMode(.alwaysTemplate)) { [weak self, weak bookmark, weak source] _ in
				guard let bookmark = bookmark, let source = source else {
					return
				}
				let items = [bookmark.title as AnyObject, bookmark.URL as AnyObject, bookmark.favicon as AnyObject]
				let controller = UIActivityViewController(activityItems: items, applicationActivities: [])
				controller.popoverPresentationController?.sourceView = source.superview
				controller.popoverPresentationController?.sourceRect = source.frame
				self?.delegate?.viewControllerForSharing.present(controller, animated: true, completion: nil)
			})
			let renameTitle = NSLocalizedString("rename bookmark context menu action title", comment: "title of the action to rename the bookmark in the bookmark context menu")
			bookmarkActions.append(UIAction(title: renameTitle, image: #imageLiteral(resourceName: "rename-context").withRenderingMode(.alwaysTemplate)) { [weak self, weak bookmark] _ in
				if let bookmark = bookmark {
					self?.delegate?.rename(bookmark: bookmark)
				}
			})
			let reloadTitle = NSLocalizedString("reload bookmark context menu action title", comment: "title of the action to reload the bookmark in the bookmark context menu")
			bookmarkActions.append(UIAction(title: reloadTitle, image: #imageLiteral(resourceName: "reload-context").withRenderingMode(.alwaysTemplate)) { [weak self, weak bookmark] _ in
				if let bookmark = bookmark {
					self?.delegate?.refresh(bookmark: bookmark)
				}
			})
			let deleteTitle = NSLocalizedString("delete bookmark context menu action title", comment: "title of the action to delete the bookmark in the bookmark context menu")
			bookmarkActions.append(UIAction(title: deleteTitle, image: #imageLiteral(resourceName: "delete-context").withRenderingMode(.alwaysTemplate), attributes: .destructive) { [weak self, weak bookmark] _ in
				if let bookmark = bookmark {
					self?.delegate?.remove(bookmark: bookmark)
				}
			})
			let bookmarkTitle = NSLocalizedString("bookmark context menu title", comment: "title of the bookmark context menu")
			menus.append(UIMenu(title: bookmark.displayName ?? bookmarkTitle, options: .displayInline, children: bookmarkActions))
		}
		if let historyItem = historyItem {
			var historyActions = [UIMenuElement]()
			let shareTitle = NSLocalizedString("share history context menu action title", comment: "title of the action to share the history item in the history context menu")
			historyActions.append(UIAction(title: shareTitle, image: #imageLiteral(resourceName: "share-context").withRenderingMode(.alwaysTemplate)) { [weak self, weak historyItem, weak source] _ in
				guard let historyItem = historyItem, let source = source else {
					return
				}
				let items = [historyItem.title as AnyObject, historyItem.url as AnyObject]
				let controller = UIActivityViewController(activityItems: items, applicationActivities: [])
				controller.popoverPresentationController?.sourceView = source.superview
				controller.popoverPresentationController?.sourceRect = source.frame
				self?.delegate?.viewControllerForSharing.present(controller, animated: true, completion: nil)
			})
			menus.append(UIMenu(title: historyItem.title, options: .displayInline, children: historyActions))
		}
		return UIContextMenuConfiguration(identifier: nil) { [weak self] () -> UIViewController? in
			return self?.delegate?.previewController(for: url)
		} actionProvider: { _ -> UIMenu? in
			return UIMenu(title: url.absoluteString, children: menus)
		}
	}
}

extension BookmarkHistoryView: DownloadsListDelegate {
	func downloadsList(_ downloadsList: DownloadsList, deleteDownloadAt index: Int) {
		if let delegate = delegate {
			delegate.delete(delegate.downloads[index], at: index)
		}
	}

	func downloadsList(_ downloadsList: DownloadsList, shareDownloadAt index: Int, from sender: UIView) {
		if let delegate = delegate {
			delegate.share(delegate.downloads[index], from: sender)
		}
	}

	func downloadsList(_ downloadsList: DownloadsList, cancelDownloadAt index: Int) {
		if let delegate = delegate {
			delegate.cancel(delegate.downloads[index])
		}
	}

	func downloadsList(_ downloadsList: DownloadsList, retryDownloadAt index: Int) {
		if let delegate = delegate {
			delegate.retry(delegate.downloads[index])
		}
	}

	func numberOfDownloads(inDownloadsList downloadsList: DownloadsList) -> Int {
		return delegate?.downloads.count ?? 0
	}

	func downloadsList(_ downloadsList: DownloadsList, downloadAt index: Int) -> FileDownload {
		return delegate!.downloads[index]
	}
}
