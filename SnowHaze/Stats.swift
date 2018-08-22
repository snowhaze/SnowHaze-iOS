//
//  Stats.swift
//  SnowHaze
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

import Foundation

let statsResetNotificationName = Notification.Name(rawValue: "StatsResetNotification")

class Stats {
	static let shared = Stats(prefix: "ch.illotros.ios.snowhaze.stats.")

	private var oldCookiesCount = NSMapTable<WKWebsiteDataStore, NSNumber>.weakToStrongObjects()

	var protectedSiteLoads: UInt {
		return UInt(DataStore.shared.getInt(for: protectedLoadKey) ?? 0)
	}

	var blockedTrackers: UInt {
		return UInt(DataStore.shared.getInt(for: blockedTrackersKey) ?? 0)
	}

	var upgradedLoads: UInt {
		return UInt(DataStore.shared.getInt(for: upgradedLoadsKey) ?? 0)
	}

	var ephemeralCookies: UInt {
		return UInt(DataStore.shared.getInt(for: ephemeralCookiesKey) ?? 0)
	}

	var aliveCookies: UInt {
		guard let enumerator = oldCookiesCount.objectEnumerator() else {
			return 0
		}
		var total: UInt = 0
		while let number = enumerator.nextObject() as? NSNumber {
			total += number.uintValue
		}
		return total
	}

	var killedCookies: UInt {
		return max(aliveCookies, ephemeralCookies) - aliveCookies
	}

	var isCleared: Bool {
		return protectedSiteLoads == 0 && blockedTrackers == 0 && upgradedLoads == 0 && ephemeralCookies == 0
	}

	private func policyManager(tab: Tab, url: URL? = nil) -> PolicyManager {
		if let url = url {
			return PolicyManager.manager(for: url, in: tab)
		}
		return PolicyManager.manager(for: tab)
	}

	func reset() {
		DataStore.shared.delete(protectedLoadKey)
		DataStore.shared.delete(blockedTrackersKey)
		DataStore.shared.delete(upgradedLoadsKey)
		DataStore.shared.delete(ephemeralCookiesKey)
		NotificationCenter.default.post(name: statsResetNotificationName, object: self)
	}

	private let protectedLoadKey: String
	private let blockedTrackersKey: String
	private let upgradedLoadsKey: String
	private let ephemeralCookiesKey: String

	private init(prefix: String) {
		protectedLoadKey = prefix + "protected.loads"
		blockedTrackersKey = prefix + "blocked.trackers"
		upgradedLoadsKey = prefix + "upgraded.loads"
		ephemeralCookiesKey = prefix + "ephemeral.cookies"
	}

	private var vpnConnected: Bool {
		guard SubscriptionManager.shared.hasSubscription else {
			return false
		}
		if VPNManager.shared.ipsecConnected {
			return true
		}
		var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
		let err = getifaddrs(&ifaddr)
		assert(err == 0)
		let original = ifaddr
		defer {
			freeifaddrs(original)
		}
		while ifaddr != nil {
			let iff = ifaddr!.pointee
			let type = iff.ifa_addr.pointee.sa_family
			let inet = [UInt8(AF_INET), UInt8(AF_INET6)]
			if inet.contains(type), let p = iff.ifa_dstaddr, inet.contains(p.pointee.sa_family) {
				if String(cString: iff.ifa_name).matches("^utun[0-9]+$") {
					return true
				}
			}
			ifaddr = iff.ifa_next
		}
		return false
	}

	func loading(_ url: URL?, in tab: Tab) {
		guard let url = url else {
			return
		}
		let policy = policyManager(tab: tab, url: url)
		guard policy.keepStats else {
			return
		}
		if vpnConnected {
			DataStore.shared.set(Int64(protectedSiteLoads) + 1, for: protectedLoadKey)
		}
		guard let host = url.host else {
			return
		}
		let trackers = policy.blockTrackingScripts ? DomainList(type: .popularSites).trackerCount(for: host) : 0
		DataStore.shared.set(Int64(blockedTrackers) + trackers, for: blockedTrackersKey)
	}

	func upgradedLoad(of url: URL, in tab: Tab) {
		let policy = policyManager(tab: tab, url: url)
		guard policy.keepStats else {
			return
		}
		DataStore.shared.set(Int64(upgradedLoads) + 1, for: upgradedLoadsKey)
	}

	private func set(_ count: Int, for store: WKWebsiteDataStore) {
		let new = UInt(count)
		let old = min(oldCookiesCount.object(forKey: store)?.uintValue ?? 0, new)
		oldCookiesCount.setObject(NSNumber(value: new), forKey: store)
		DataStore.shared.set(Int64(ephemeralCookies + new - old), for: ephemeralCookiesKey)
	}

	func updateCookieCount(for tab: Tab) {
		let policy = policyManager(tab: tab)
		guard policy.keepStats, !policy.allowPermanentDataStorage, let store = tab.controller?.webbsiteDataStore else {
			return
		}
		if #available(iOS 11, *) {
			store.httpCookieStore.getAllCookies { self.set($0.filter({ !$0.isSessionOnly }).count, for: store) }
		} else {
			store.fetchDataRecords(ofTypes: Set(arrayLiteral: WKWebsiteDataTypeCookies)) { self.set($0.count, for: store) }
		}
	}
}
