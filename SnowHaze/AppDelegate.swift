//
//  AppDelegate.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import UIKit
import CoreSpotlight

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		return true
	}

	func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
		if userActivity.activityType == CSSearchableItemActionType {
			guard let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
				return false
			}
			if let data = id.firstMatch("(?<=^bookmark-).+$"), let location = String(data).firstMatch("(?<=[0-9]-).+$") {
				if let url = URL(string: String(location)) {
					MainViewController.loadInFreshTab(input: url.absoluteString, type: .url)
				}
			}
			return true
		}
		return false
	}

	func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
		if shortcutItem.type == bookmarkApplicationShortcutType {
			guard let location = shortcutItem.userInfo?["url"] as? String, let url = URL(string: location) else {
				completionHandler(false)
				return
			}
			MainViewController.loadInFreshTab(input: url.absoluteString, type: .url) {
				completionHandler(true)
			}
		} else if shortcutItem.type == newTabApplicationShortcutType {
			MainViewController.addEmptyTab(self) {
				completionHandler(true)
			}
		} else if shortcutItem.type == openVPNSettingsApplicationShortcutType {
			MainViewController.openSettings(type: .vpn) {
				completionHandler(true)
			}
		} else {
			completionHandler(false)
		}
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
		guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return false
		}
		guard let scheme = components.scheme?.lowercased() else {
			return false
		}
		let isControl: Bool
		switch scheme {
			case "shtps", "snowhaze-secure":
				components.scheme = "https"
				isControl = false
			case "shtp", "snowhaze-insecure":
				components.scheme = "http"
				isControl = false
			case "shc", "snowhaze-control":
				isControl = true
			default:
				return false
		}
		if isControl {
			let queryItems = components.queryItems ?? []
			let inputs = queryItems.filter { $0.name.lowercased() == "input" }
			let queries = inputs.map { $0.value ?? "" }
			if queries.count > 5 {
				return false
			}
			queries.forEach { MainViewController.loadInFreshTab(input: $0, type: .plainInput) }
			let openSettings = queryItems.filter { $0.name.lowercased() == "open-setting" }
			let settings = openSettings.compactMap { (item: URLQueryItem) -> SettingsViewController.SettingsType? in
				switch item.value?.lowercased() {
					case "vpn":				return .vpn
					case "subscription":	return .subscription
					default:				return nil
				}
			}
			let unfold = queryItems.contains { $0.name.lowercased() == "unfold-explanation" }
			if let type = settings.last {
				MainViewController.openSettings(type: type, unfold: unfold)
			}
			if queryItems.contains(where: { $0.name.lowercased() == "rotate-ipsec-credentials" }) {
				MainViewController.rotateIPSecCreds()
			}
		} else {
			let query = components.url?.absoluteString ?? ""
			MainViewController.loadInFreshTab(input: query, type: .url)
		}
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

	func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
		DownloadManager.shared.handleBackgroundTaskEvent(completionHandler: completionHandler)
	}
}

