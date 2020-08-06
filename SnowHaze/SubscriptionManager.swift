//
//  SubscriptionManager.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import StoreKit
import CommonCrypto

protocol SubscriptionManagerDelegate: AnyObject {
	func productListDidChange()
	func restoreFinished(succesfully success: Bool)
	func activeSubscriptionChanged(fromId: String?)
	func purchaseFailed(besause description: String?)
	func apiErrorOccured(_ error: V3APIConnection.Error)
	func hasPreexistingPayments(until expiration: Date, renews: Bool, purchasing: SubscriptionManager.Product)
	func verificationBlobChanged(from: String?)
}

private let monthlyId = "ch.illotros.ios.snowhaze.premium.monthly"
private let yearlyId = "ch.illotros.ios.snowhaze.premium.yearly"

private let lastProductUpdateKey = "ch.illotros.snowhaze.subscriptionmanager.lastproductupdate"

private let productsKey = "ch.illotros.snowhaze.subscriptionmanager.products"
private let activeSubscriptionIdKey = "ch.illotros.snowhaze.subscriptionmanager.activesubscription.id"
private let activeSubscriptionExpirationKey = "ch.illotros.snowhaze.subscriptionmanager.activesubscription.expiration"
private let activeSubscriptionRenewsKey = "ch.illotros.snowhaze.subscriptionmanager.activesubscription.renew"
private let authorizationTokenKey = "ch.illotros.snowhaze.subscriptionmanager.authorizationtoken"
private let authorizationTokenExpirationDateKey = "ch.illotros.snowhaze.subscriptionmanager.authorizationtoken.expiration"
private let authorizationTokenUpdateDateKey = "ch.illotros.snowhaze.subscriptionmanager.authorizationtoken.updatedate"
private let verificationBlobKey = "ch.illotros.snowhaze.subscriptionmanager.authorizationtoken.verification-blob"

class SubscriptionManager: NSObject {
	enum Status {
		case confimed
		case likely
		case none

		var confirmed: Bool {
			switch self {
				case .confimed:	return true
				case .likely:	return false
				case .none:		return false
			}
		}

		var possible: Bool {
			switch self {
				case .confimed:	return true
				case .likely:	return true
				case .none:		return false
			}
		}
	}
	static let tokenUpdatedNotification = Notification.Name("subscriptionManagerAuthorizationTokenUpdatedNotificationName")
	static let statusUpdatedNotification = Notification.Name("subscriptionManagerSubscriptionStatusChangedNotificationName")

	private lazy var paymentQueue: SKPaymentQueue = {
		let queue = SKPaymentQueue.default()
		queue.add(self)
		return queue
	}()

	private override init() {
		super.init()
		_ = loadReceipt()
		setupTokenExpiration()
		setupSubscriptionExpiration()
		lastNotifiedStatus = status
		NotificationCenter.default.addObserver(self, selector: #selector(masterSecretChanged), name: V3APIConnection.masterSecretChangedNotification, object: nil)
	}

	private lazy var urlSession = SnowHazeURLSession()

	weak var delegate: SubscriptionManagerDelegate?

	static let shared = SubscriptionManager()

	static var status: Status {
		return shared.status
	}

	var status: Status {
		return status(in: 0)
	}

	func status(in time: TimeInterval) -> Status {
		guard activeSubscription != nil || V3APIConnection.hasSecret else {
			return .none
		}
		if subscriptionRenews {
			return .confimed
		}
		guard let expirationDate = expirationDate else {
			return activeSubscription != nil ? .likely : .none
		}
		return expirationDate.timeIntervalSinceNow >= time ? .confimed : .none
	}

	private var lastNotifiedStatus: Status!
	private func possibleStatusChange() {
		if status != lastNotifiedStatus {
			lastNotifiedStatus = status
			NotificationCenter.default.post(name: SubscriptionManager.statusUpdatedNotification, object: self)
		}
	}

	@objc private func masterSecretChanged() {
		possibleStatusChange()
	}

	var hasValidToken: Bool {
		return !validTokens.isEmpty
	}

	private func set(activeSubscription new: String?) {
		if let _ = new {
			V3APIConnection.invalidateReceipt()
		}
		let old = self.activeSubscription
		guard old != new else {
			return
		}
		activeSubscription = new
		delegate?.activeSubscriptionChanged(fromId: old)
	}

	private(set) var activeSubscription: String? = DataStore.shared.getString(for: activeSubscriptionIdKey) {
		willSet {
			if activeSubscription != newValue {
				DataStore.shared.set(newValue, for: activeSubscriptionIdKey)
			}
		}
		didSet {
			if status.possible && !hasValidToken && PolicyManager.globalManager().autoUpdateAuthToken {
				updateAuthToken(completionHandler: nil)
			}
			possibleStatusChange()
		}
	}

	func tryWithTokens(work: @escaping (String?, @escaping () -> Void) -> Void) {
		func dispatch(with tokens: [String]) {
			var tokens = tokens
			let token = tokens.isEmpty ? nil : tokens.removeFirst()
			work(token) {
				assert(token != nil)
				DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval.random(in: 0 ... 10)) {
					dispatch(with: tokens)
				}
			}
		}
		if !hasValidToken && status.confirmed && PolicyManager.globalManager().autoUpdateAuthToken {
			SubscriptionManager.shared.updateAuthToken { success in
				DispatchQueue.main.async {
					dispatch(with: self.validTokens.shuffled())
				}
			}
		} else {
			DispatchQueue.main.async {
				dispatch(with: self.validTokens.shuffled())
			}
		}
	}

	private var validTokens: [String] {
		guard let tokens = authorizationTokens, status.confirmed else {
			return []
		}
		let now = Date()
		return tokens.filter({ $0.1 > now }).map { $0.0 }
	}

	private static func loadTokens() -> [(String, Date)]? {
		if let token = DataStore.shared.getString(for: authorizationTokenKey) {
			let data = token.data(using: .utf8)!
			if let decode = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
				let tokens = decode.map { dictionary -> (String, Date)? in
					let possibleToken = dictionary["token"]
					let possibleExpiration = dictionary["expiration"]
					guard let token = possibleToken as? String, let expiration = possibleExpiration as? TimeInterval else {
						return nil
					}
					return (token, Date(timeIntervalSince1970: expiration))
				}
				return tokens as? [(String, Date)]
			} else if let time = DataStore.shared.getDouble(for: authorizationTokenExpirationDateKey) {
				let date = Date(timeIntervalSince1970: time)
				return [(token, date)]
			} else {
				return nil
			}
		} else {
			return nil
		}
	}

	func clearSubscriptionInfoTokens() {
		subscriptionRenews = false
		expirationDate = nil
		authorizationTokenUpdateDate = nil
		authorizationTokens = nil
		set(verificationBlob: nil)
	}

	private var authorizationTokens = SubscriptionManager.loadTokens() {
		willSet {
			func areEqual(_ a: [(String, Date)]?, _ b: [(String, Date)]?) -> Bool {
				guard let a = a else {
					return b == nil
				}
				guard let b = b else {
					return false
				}
				return a.elementsEqual(b, by: { $0 == $1 })
			}
			if !areEqual(authorizationTokens, newValue) {
				let tokens = newValue?.map { return ["token": $0.0, "expiration": $0.1.timeIntervalSince1970] }
				let json: String?
				if let tokens = tokens {
					let data = try! JSONSerialization.data(withJSONObject: tokens)
					json = String(data: data, encoding: .utf8)!
				} else {
					json = nil
				}
				DataStore.shared.set(json, for: authorizationTokenKey)
				DataStore.shared.delete(authorizationTokenExpirationDateKey)
			}
		}
		didSet {
			func equal(_ lhs: [(String, Date)]?, _ rhs: [(String, Date)]?) -> Bool {
				guard let a = lhs, let b = rhs else {
					return lhs == nil && rhs == nil
				}
				guard a.count == b.count else {
					return false
				}
				for i in 0..<a.count {
					guard a[i].0 == b[i].0 && a[i].1 == b[i].1 else {
						return false
					}
				}
				return true
			}
			if !equal(oldValue, authorizationTokens) {
				NotificationCenter.default.post(name: SubscriptionManager.tokenUpdatedNotification, object: self)
			}
		}
	}

	var hasVerificationBlob: Bool {
		return verificationBlob != nil
	}

	var verificationBlobBase64: String? {
		return verificationBlob?.base64EncodedString()
	}

	private var verificationBlob = DataStore.shared.getData(for: verificationBlobKey) {
		willSet {
			if newValue != verificationBlob {
				DataStore.shared.set(newValue, for: verificationBlobKey)
			}
		}
	}

	private func set(verificationBlob: Data?) {
		let oldBlob = self.verificationBlobBase64
		self.verificationBlob = verificationBlob
		delegate?.verificationBlobChanged(from: oldBlob)
	}

	private(set) var authorizationTokenUpdateDate: Date? = SubscriptionManager.toDate(DataStore.shared.getDouble(for: authorizationTokenUpdateDateKey)) {
		willSet {
			if authorizationTokenUpdateDate != newValue {
				DataStore.shared.set(newValue?.timeIntervalSince1970, for: authorizationTokenUpdateDateKey)
			}
		}
	}

	var authorizationTokenHash: String? {
		guard validTokens.count == 1, let token = validTokens.first else {
			return nil
		}
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA512_DIGEST_LENGTH))
		let data = token.data(using: .utf8)!
		_ = data.withUnsafeBytes { CC_SHA512($0.baseAddress, CC_LONG($0.count), &hash)}
		return Data(hash).hex
	}

	private static func toDate(_ time: Double?) -> Date? {
		if let time = time {
			return Date(timeIntervalSince1970: time)
		} else {
			return nil
		}
	}

	private var authorizationTokenExpiration: Date? {
		return authorizationTokens?.map({ $0.1 }).min()
	}

	private(set) var expirationDate: Date? = SubscriptionManager.toDate(DataStore.shared.getDouble(for: activeSubscriptionExpirationKey)) {
		willSet {
			if expirationDate != newValue {
				DataStore.shared.set(newValue?.timeIntervalSince1970, for: activeSubscriptionExpirationKey)
			}
		}
		didSet {
			if expirationDate != oldValue {
				setupSubscriptionExpiration()
				possibleStatusChange()
			}
		}
	}

	private(set) var subscriptionRenews: Bool = (DataStore.shared.getInt(for: activeSubscriptionRenewsKey) ?? 0 != 0) {
		willSet {
			if subscriptionRenews != newValue {
				DataStore.shared.set(Int64(newValue ? 1 : 0), for: activeSubscriptionRenewsKey)
			}
		}
		didSet {
			possibleStatusChange()
		}
	}

	private func setupTokenExpiration() {
		guard let date = authorizationTokenExpiration else {
			return
		}
		let timeInterval = date.timeIntervalSinceNow
		guard timeInterval >= 0 else {
			DispatchQueue.main.async {
				if self.authorizationTokenExpiration?.timeIntervalSinceNow ?? 0 <= 0 {
					let now = Date()
					let newTokens = (self.authorizationTokens ?? []).filter { $0.1 > now }
					if newTokens.isEmpty {
						self.authorizationTokens = nil
						self.set(verificationBlob: nil)
					} else {
						self.authorizationTokens = newTokens
						// don't update verification blob, since newTokens is just a filtered version of previous tokens
					}
				}
			}
			return
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + timeInterval + 0.01) {
			self.setupTokenExpiration()
		}
	}

	private func setupSubscriptionExpiration() {
		guard let date = expirationDate else {
			return
		}
		let timeInterval = date.timeIntervalSinceNow
		guard timeInterval >= 0 else {
			DispatchQueue.main.async {
				if !self.subscriptionRenews && self.expirationDate?.timeIntervalSinceNow ?? 0 <= 0 {
					self.set(activeSubscription: nil)
				}
			}
			return
		}
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + timeInterval + 0.01) {
			self.setupSubscriptionExpiration()
		}
	}

	enum Product {
		static let formatter: NumberFormatter = {
			let formatter = NumberFormatter()
			formatter.numberStyle = .currency
			return formatter
		}()

		case real(SKProduct)
		case cached([String: String])

		var product: SKProduct? {
			switch self {
				case .real(let p):	return p
				case .cached(_):	return nil
			}
		}

		var id: String {
			switch self {
				case .real(let prod):	return prod.productIdentifier
				case .cached(let dict):	return dict["id"]!
			}
		}

		var description: String {
			switch id {
				case monthlyId:	return NSLocalizedString("snowhaze premium billed monthly option description", comment: "title of the option to be billed monthly for snowhaze premium")
				case yearlyId:	return NSLocalizedString("snowhaze premium billed yearly option description", comment: "title of the option to be billed yearly for snowhaze premium")
				default:		fatalError("unsuported id")
			}
		}

		var priceString: String {
			switch self {
				case .real(let product):
					Product.formatter.locale = product.priceLocale
					return Product.formatter.string(from: product.price) ?? "\(product.price)"
				case .cached(let dict):
					return dict["price"]!
			}
		}

		fileprivate var dictionary: [String: String] {
			switch self {
				case .real(_):			return ["id": id, "description": description, "price": priceString]
				case .cached(let dict):	return dict
			}
		}
	}

	private static func loadProducts() -> [Product] {
		guard let data = DataStore.shared.getData(for: productsKey) else {
			return []
		}
		guard let array = (try? JSONSerialization.jsonObject(with: data) as? [[String: String]]) ?? nil else {
			return []
		}
		return array.map({ Product.cached($0) }).filter { [monthlyId, yearlyId].contains($0.id) }
	}

	var products: (yearly: Product?, monthly: Product?)? {
		guard !productsArray.isEmpty else {
			return nil
		}
		let yearly = productsArray.first { $0.id == yearlyId }
		let montly = productsArray.first { $0.id == monthlyId }
		return (yearly, montly)
	}

	private var productsArray = SubscriptionManager.loadProducts() {
		willSet {
			let array = newValue.map { $0.dictionary }
			let data = try! JSONSerialization.data(withJSONObject: array)
			DataStore.shared.set(data, for: productsKey)
		}
	}

	private var loadCompletionHandlers = [SKProductsRequest: ([SKProduct]?, Error?) -> Void]()

	private func loadReceipt() -> Data? {
		guard let url = Bundle.main.appStoreReceiptURL else {
			set(activeSubscription: nil)
			return nil
		}
		guard let data = try? Data(contentsOf: url) else {
			set(activeSubscription: nil)
			return nil
		}
		return data
	}

	func updateProducts(force: Bool = false, completionHandler: ((Bool) -> Void)?) {
		let timestamp = DataStore.shared.getDouble(for: lastProductUpdateKey) ?? -Double.infinity
		let date = Date(timeIntervalSince1970: timestamp)
		guard force || date.timeIntervalSinceNow < -2 * 24 * 60 * 60 else {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		let ids = Set([monthlyId, yearlyId])
		let request = SKProductsRequest(productIdentifiers: ids)
		loadCompletionHandlers[request] = { products, _ in
			if let products = products {
				self.productsArray = products.map { .real($0) }
				self.delegate?.productListDidChange()
				DataStore.shared.set(Date().timeIntervalSince1970, for: lastProductUpdateKey)
			}
			completionHandler?(products != nil)
		}
		request.delegate = self
		request.start()
	}

	func restorePurchases() {
		paymentQueue.restoreCompletedTransactions()
	}

	func purchase(_ product: Product, force: Bool = false) {
		if let skProduct = product.product {
			purchase(skProduct, force: force)
		} else {
			load(product: product.id) { [weak self] product, error in
				if let product = product {
					self?.purchase(product, force: force)
				}
			}
		}
	}

	private func purchase(_ product: SKProduct, force: Bool) {
		if V3APIConnection.hasSecret && !force {
			V3APIConnection.getSubscriptionDuration { [weak self] subscription, error in
				if let error = error {
					self?.delegate?.apiErrorOccured(error)
					return
				}
				if let (expiration, renews) = subscription, renews || expiration.timeIntervalSinceNow > 2 * 24 * 60 * 60 {
					self?.delegate?.hasPreexistingPayments(until: expiration, renews: renews, purchasing: Product.real(product))
					return
				}
				self?.paymentQueue.add(SKPayment(product: product))
			}
		} else {
			paymentQueue.add(SKPayment(product: product))
		}
	}

	private func load(product: String, completionHandler: @escaping (SKProduct?, Error?) -> Void) {
		load(products: [product]) { completionHandler($0?.first, $1) }
	}

	private func load(products: [String], completionHandler: @escaping ([SKProduct]?, Error?) -> Void) {
		let request = SKProductsRequest(productIdentifiers: Set(products))
		loadCompletionHandlers[request] = completionHandler
		request.delegate = self
		request.start()
	}

	private func updateAuthTokenV2(completionHandler: ((Bool) -> Void)?) {
		guard let data = loadReceipt(), let _ = activeSubscription else {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		var request = URLRequest(url: URL(string: "https://api.snowhaze.com/index.php")!)
		request.setFormEncoded(data: ["receipt": data.base64EncodedString(), "v": "3", "action": "auth"])
		let dec = InUseCounter.network.inc()
		urlSession.performDataTask(with: request) { data, _, error in
			dec()
			guard let data = data, let dictionary = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
				if let handler = completionHandler {
					DispatchQueue.main.async {
						handler(false)
					}
				}
				return
			}
			guard let token = dictionary["token"] as? String, let renew = dictionary["renew"] as? Bool, let expiration = dictionary["expiration"] as? Double, let tokenExpiration = dictionary["token_expiration"] as? Double, let id = dictionary["id"] as? String else {
				if let expired = dictionary["expired"] as? Bool, expired {
					DispatchQueue.main.async {
						if !V3APIConnection.hasSecret {
							self.subscriptionRenews = false
							self.expirationDate = nil
							self.authorizationTokens = nil
							self.set(verificationBlob: nil)
							self.authorizationTokenUpdateDate = nil
							self.set(activeSubscription: nil)
						}
						completionHandler?(true)
					}
				}
				if let handler = completionHandler {
					DispatchQueue.main.async {
						handler(false)
					}
				}
				return
			}
			DispatchQueue.main.async {
				if !V3APIConnection.hasSecret {
					self.subscriptionRenews = renew
					self.expirationDate = Date(timeIntervalSince1970: expiration)
					self.authorizationTokens = [(token, Date(timeIntervalSince1970: tokenExpiration))]
					self.set(verificationBlob: nil)
					self.authorizationTokenUpdateDate = Date()
					self.set(activeSubscription: id)
				}
				completionHandler?(true)
			}
		}
	}

	private func updateAuthTokenV3(completionHandler: ((Bool) -> Void)?) {
		if activeSubscription == nil, (authorizationTokenUpdateDate ?? Date.distantPast).timeIntervalSinceNow > -1 * 60 * 60 {
			if let completionHandler = completionHandler {
				DispatchQueue.main.async {
					completionHandler(false)
				}
			}
			return
		}
		V3APIConnection.withUploadedReceipt { error in
			guard error == nil else {
				completionHandler?(false)
				return
			}
			var completionCount = 0
			var ok = true
			var tokens: [(String, Date)]? = nil
			var verificationBlob: Data? = nil
			func complete(success: Bool) {
				ok = ok && success
				completionCount += 1
				if completionCount == 2, V3APIConnection.hasSecret {
					if ok {
						if tokens!.isEmpty {
							self.authorizationTokens = nil
							self.set(verificationBlob: nil)
						} else {
							self.authorizationTokens = tokens
							self.set(verificationBlob: verificationBlob!)
						}
						self.authorizationTokenUpdateDate = Date()
					}
					completionHandler?(ok)
				}
			}
			V3APIConnection.getTokens { tokenData, error in
				if case .accountNotAuthorized = error {
					tokens = []
					complete(success: true)
					return
				}
				guard error == nil else {
					complete(success: false)
					return
				}
				let (newTokens, expiration, verification) = tokenData!
				tokens = tokens ?? newTokens.map { ($0, Date(timeIntervalSince1970: Double(expiration))) }
				verificationBlob = verification
				complete(success: true)
			}
			V3APIConnection.getSubscriptionDuration { data, error in
				guard error == nil else {
					complete(success: false)
					return
				}
				if let data = data {
					let (date, renews) = data
					self.subscriptionRenews = renews
					self.expirationDate = date
				} else {
					self.subscriptionRenews = false
					self.expirationDate = nil
					tokens = []
					self.set(activeSubscription: nil)
				}
				complete(success: true)
			}
		}
	}

	func updateAuthToken(completionHandler: ((Bool) -> Void)? = nil) {
		if !validTokens.isEmpty, (authorizationTokenUpdateDate ?? Date.distantPast).timeIntervalSinceNow > -24 * 60 * 60 {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		if V3APIConnection.hasSecret {
			updateAuthTokenV3(completionHandler: completionHandler)
		} else {
			updateAuthTokenV2(completionHandler: completionHandler)
		}
	}
}

extension SubscriptionManager: SKPaymentTransactionObserver {
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		DispatchQueue.main.async {
			for transaction in transactions {
				switch transaction.transactionState {
					case .purchased, .restored:
						self.set(activeSubscription: transaction.payment.productIdentifier)
						queue.finishTransaction(transaction)
					case .failed:
						self.delegate?.purchaseFailed(besause: transaction.error?.localizedDescription)
						queue.finishTransaction(transaction)
					default:
						break
				}
			}
		}
	}

	func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
		DispatchQueue.main.async {
			self.delegate?.restoreFinished(succesfully: false)
		}
	}

	func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
		DispatchQueue.main.async {
			self.delegate?.restoreFinished(succesfully: true)
		}
	}
}

extension SubscriptionManager: SKProductsRequestDelegate {
	func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
		DispatchQueue.main.async {
			let handler = self.loadCompletionHandlers[request]!
			self.loadCompletionHandlers[request] = nil
			handler(response.products, nil)
		}
	}

	func request(_ request: SKRequest, didFailWithError error: Error) {
		print("SKRequest failed with \(error)")
		DispatchQueue.main.async {
			if let productRequest = request as? SKProductsRequest {
				let handler = self.loadCompletionHandlers[productRequest]!
				self.loadCompletionHandlers[productRequest] = nil
				handler(nil, error)
			}
		}
	}
}
