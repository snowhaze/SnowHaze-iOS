//
//  SubscriptionManager.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation
import StoreKit

protocol SubscriptionManagerDelegate: AnyObject {
	func productListDidChange()
	func restoreFinished(succesfully success: Bool)
	func activeAubscriptionStatusChanged(fromId: String?)
	func purchaseFailed(besause description: String?)
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

class SubscriptionManager: NSObject {
	static let tokenUpdatedNotificationName = Notification.Name("subscriptionManagerAuthorizationTokenUpdatedNotificationName")

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
	}

	private lazy var urlSession = URLSession(configuration: .ephemeral, delegate: PinningSessionDelegate(), delegateQueue: nil)

	weak var delegate: SubscriptionManagerDelegate?

	static let shared = SubscriptionManager()

	var hasSubscription: Bool {
		return stilHasSubscription(in: 0)
	}

	func stilHasSubscription(in time: TimeInterval) -> Bool {
		guard activeSubscription != nil else {
			return false
		}
		if subscriptionRenews {
			return true
		}
		return expirationDate?.timeIntervalSinceNow ?? Double.infinity > time
	}

	var hasValidToken: Bool {
		return authorizationToken != nil && (authorizationTokenExpiration ?? .distantPast).timeIntervalSinceNow > 0 && hasSubscription
	}

	private(set) var activeSubscription: String? = DataStore.shared.getString(for: activeSubscriptionIdKey) {
		willSet {
			if activeSubscription != newValue {
				DataStore.shared.set(newValue, for: activeSubscriptionIdKey)
			}
		}
		didSet {
			if hasSubscription && !hasValidToken && PolicyManager.globalManager().autoUpdateAuthToken {
				updateAuthToken(completionHandler: nil)
			}
		}
	}

	private(set) var authorizationToken: String? = DataStore.shared.getString(for: authorizationTokenKey) {
		willSet {
			if authorizationToken != newValue {
				DataStore.shared.set(newValue, for: authorizationTokenKey)
			}
		}
	}

	private var authorizationTokenExpiration: Date? = SubscriptionManager.toDate(DataStore.shared.getDouble(for: authorizationTokenExpirationDateKey)) {
		willSet {
			if authorizationTokenExpiration != newValue {
				DataStore.shared.set(newValue?.timeIntervalSince1970, for: authorizationTokenExpirationDateKey)
			}
		}
		didSet {
			if oldValue != authorizationTokenExpiration {
				setupTokenExpiration()
			}
		}
	}

	private(set) var authorizationTokenUpdateDate: Date? = SubscriptionManager.toDate(DataStore.shared.getDouble(for: authorizationTokenUpdateDateKey)) {
		willSet {
			if authorizationTokenUpdateDate != newValue {
				DataStore.shared.set(newValue?.timeIntervalSince1970, for: authorizationTokenUpdateDateKey)
			}
		}
	}

	var authorizationTokenHash: String? {
		guard let token = authorizationToken else {
			return nil
		}
		var hash = [UInt8](repeating: 0,  count: Int(CC_SHA512_DIGEST_LENGTH))
		let data = token.data(using: .utf8)!
		data.withUnsafeBytes {
			_ = CC_SHA512($0, CC_LONG(data.count), &hash)
		}
		let hex = Data(bytes: hash).hex
		return String(hex[..<hex.index(hex.startIndex, offsetBy: 26)])
	}

	private static func toDate(_ time: Double?) -> Date? {
		if let time = time {
			return Date(timeIntervalSince1970: time)
		} else {
			return nil
		}
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
			}
		}
	}

	private(set) var subscriptionRenews: Bool = (DataStore.shared.getInt(for: activeSubscriptionRenewsKey) ?? 0 != 0) {
		willSet {
			if subscriptionRenews != newValue {
				DataStore.shared.set(Int64(newValue ? 1 : 0), for: activeSubscriptionRenewsKey)
			}
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
					self.authorizationToken = nil
					self.authorizationTokenExpiration = nil
					NotificationCenter.default.post(name: SubscriptionManager.tokenUpdatedNotificationName, object: self)
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
					self.activeSubscription = nil
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

	private(set) var products = SubscriptionManager.loadProducts() {
		willSet {
			let array = newValue.map { $0.dictionary }
			let data = try! JSONSerialization.data(withJSONObject: array)
			DataStore.shared.set(data, for: productsKey)
		}
	}

	private var loadCompletionHandlers = [SKProductsRequest: ([SKProduct]?, Error?) -> Void]()

	private func loadReceipt() -> Data? {
		guard let url = Bundle.main.appStoreReceiptURL else {
			activeSubscription = nil
			return nil
		}
		guard let data = try? Data(contentsOf: url) else {
			activeSubscription = nil
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
				self.products = products.map { .real($0) }
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

	func purchase(_ product: SKProduct) {
		paymentQueue.add(SKPayment(product: product))
	}

	func load(product: String, completionHandler: @escaping (SKProduct?, Error?) -> Void) {
		load(products: [product]) { completionHandler($0?.first, $1) }
	}

	func load(products: [String], completionHandler: @escaping ([SKProduct]?, Error?) -> Void) {
		let request = SKProductsRequest(productIdentifiers: Set(products))
		loadCompletionHandlers[request] = completionHandler
		request.delegate = self
		request.start()
	}

	func updateAuthToken(completionHandler: ((Bool) -> Void)? = nil) {
		guard let data = loadReceipt(), let _ = activeSubscription else {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		if let _ = authorizationToken, (authorizationTokenUpdateDate ?? Date.distantPast).timeIntervalSinceNow > -24 * 60 * 60 {
			if let handler = completionHandler {
				DispatchQueue.main.async {
					handler(false)
				}
			}
			return
		}
		var request = URLRequest(url: URL(string: "https://api.snowhaze.com/index.php")!)
		request.setFormEncoded(data: ["receipt": data.base64EncodedString(), "v": "2", "action": "auth"])
		let dec = InUseCounter.network.inc()
		let task = urlSession.dataTask(with: request) { data, _, error in
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
						let old = self.activeSubscription
						self.activeSubscription = nil
						self.subscriptionRenews = false
						self.expirationDate = nil
						self.authorizationToken = nil
						self.authorizationTokenExpiration = nil
						self.authorizationTokenUpdateDate = nil
						self.delegate?.activeAubscriptionStatusChanged(fromId: old)
						completionHandler?(true)
						NotificationCenter.default.post(name: SubscriptionManager.tokenUpdatedNotificationName, object: self)
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
				let old = self.activeSubscription
				self.activeSubscription = id
				self.subscriptionRenews = renew
				self.expirationDate = Date(timeIntervalSince1970: expiration)
				self.authorizationToken = token
				self.authorizationTokenExpiration = Date(timeIntervalSince1970: tokenExpiration)
				self.authorizationTokenUpdateDate = Date()
				self.delegate?.activeAubscriptionStatusChanged(fromId: old)
				completionHandler?(true)
				NotificationCenter.default.post(name: SubscriptionManager.tokenUpdatedNotificationName, object: self)
			}
		}
		task.resume()
	}
}

extension SubscriptionManager: SKPaymentTransactionObserver {
	func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
		DispatchQueue.main.async {
			for transaction in transactions {
				switch transaction.transactionState {
					case .purchased, .restored:
						let old = self.activeSubscription
						let new = transaction.payment.productIdentifier
						if old != new {
							self.activeSubscription = new
							self.delegate?.activeAubscriptionStatusChanged(fromId: old)
						}
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
