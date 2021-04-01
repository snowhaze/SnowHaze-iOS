//
//  SchemeType.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum SchemeType {
	private static let calleeRx = Regex(pattern: "^(?:[a-z-]+):(?://)?(.+)$", options: .caseInsensitive)

	case unknown				// ?
	case http					// Regular HTTP URL
	case call(String?, Bool)	// FaceTime or Phone Call
	case store					// Apple App Store
	case itunes					// Apple iTunes Store
	case mail					// Apple Mail
	case messages				// Apple Messages
	case maps					// Apple Maps
	case calendar				// Apple Calendar
	case whatsapp				// WhatsApp
	case intent(URL?)			// Android Intent URI
	case shortcuts				// Apple Shortcuts
	case testFlight				// Apple TestFlight
	case books					// Apple Books
	case music					// Apple Music
	case appleTv				// Apple TV
	case googleEarth			// Google Earth
	case duolingo				// Duolingo
	case evernote				// Evernote
	case facebook				// Facebook
	case fbMessenger			// Facebook Messenger
	case fitbit					// Fitbit
	case flickr					// Flickr
	case googleCalendar			// Google Calendar
	case googleDocs				// Google Docs
	case googleDrive			// Google Drive
	case gmail					// Google Gmail
	case googleHome				// Google Home
	case googleMaps				// Google Maps
	case googlePhotos			// Google Photos
	case googleSheets			// Google Sheets
	case googleTranslate		// Google Translate
	case googleVoice			// Google Voice
	case hulu					// Hulu
	case imdb					// IMDB
	case instagram				// Instagram
	case lastpass				// Lastpass
	case netflix				// Netflix
	case paypal					// Paypal mobile cash
	case photoscan				// Google PhotoScan
	case pinterest				// Pinterest
	case planner				// Microsoft Planner
	case podcast				// Apple Podcast
	case powerpoint				// Microsoft Powerpoint
	case protonmail				// Protonmail
	case sbb					// SBB
	case signal					// Signal
	case shazam					// Shazam
	case skype					// Skype
	case slack					// Slack
	case snapchat				// Snapchat
	case ooklaSpeedtest			// Ookla Speedtest
	case spotify				// Spotify
	case telegram				// Telegram
	case trello					// Trello
	case twitter				// Twitter
	case udemy					// Udemy
	case waze					// Waze
	case word					// Microsoft Word
	case youtube				// Youtube
	case zuludesk				// Zuludesk
	case zoom					// Zoom
	case settings				// Apple Settings

	case twintPrepaid			// Twint Prepaid
	case twintUBS				// Twint UBS
	case twintZKB				// Twint ZKB
	case twintCS				// Twint CS
	case twintBCV				// Twint BCV
	case twintRaiffeisen		// Twint Raiffeisen
	case twintPostfinance		// Twint Postfinance
	case twintOKB				// Twint OKB
	case twintZugerKB			// Twint ZugerKB
	case twintBCGE				// Twint BCGE
	case twintNAB				// Twint NAB
	case twintAPPKB				// Twint APPKB
	case twintBCVS				// Twint BCVS
	case twintSGKB				// Twint SGKB
	case twintGKB				// Twint GKB
	case twintBCF				// Twint BCF
	case twintBCJ				// Twint BCJ
	case twintBCN				// Twint BCN

	private static let twintRx = Regex(pattern: "twint-issuer([1-4][0-9]|[1-9]|50)")

	init(_ url: URL?) {
		guard let target = url, let scheme = target.normalizedScheme else {
			self = .unknown
			return
		}
		let urlString = target.absoluteString
		switch scheme {
			case "http", "https":
				if let host = target.normalizedHost {
					if host == "itunes.apple.com" {
						self = .itunes
						return
					}
					if host == "maps.apple.com" && target.query != nil {
						self = .maps
						return
					}
				}
				self = .http
			case "tel", "facetime", "facetime-audio":
				if let match = SchemeType.calleeRx.firstMatch(in: urlString) {
					self = .call(String(match.match(at: 1)), scheme != "tel")
				} else {
					self = .call(nil, scheme != "tel")
				}
			case "intent":
				let components = target.absoluteString.components(separatedBy: ";")
				let fallbackURLs = components.filter { $0.hasPrefix("S.browser_fallback_url=") }
				let args = fallbackURLs.first?.components(separatedBy: "=").dropFirst()
				let arg = args?.joined(separator: "=")
				if let arg = arg?.removingPercentEncoding, let fallback = URL(string: arg) {
					self = .intent(fallback)
				} else {
					self = .intent(nil)
				}
			case "itms-appss", "itms-apps", "macappstores":
				self = .store
			case "itmss":
				self = .itunes
			case "itms-beta":
				self = .testFlight
			case "mailto":
				self = .mail
			case "sms":
				self = .messages
			case "webcal", "calshow":
				self = .calendar
			case "whatsapp":
				self = .whatsapp
			case "workflow":
				self = .shortcuts
			case "ibooks":
				self = .books
			case "map":
				self = .maps
			case "music":
				self = .music
			case "videos", "imovie":
				self = .appleTv
			case "duolingo":
				self = .duolingo
			case "evernote":
				self = .evernote
			case "fb":
				self = .facebook
			case "fb-messenger":
				self = .fbMessenger
			case "fitbit":
				self = .fitbit
			case "flickr":
				self = .flickr
			case "googlecalendar":
				self = .googleCalendar
			case "googledocs":
				self = .googleDocs
			case "googledrive":
				self = .googleDrive
			case "googleearth", "comgoogleearth":
				self = .googleEarth
			case "googlegmail":
				self = .gmail
			case "googlehome", "chromecast":
				self = .googleHome
			case "googlemaps":
				self = .googleMaps
			case "googlephotos":
				self = .googlePhotos
			case "googlesheets":
				self = .googleSheets
			case "googletranslate":
				self = .googleTranslate
			case "googlevoice":
				self = .googleVoice
			case "hulu":
				self = .hulu
			case "imdb":
				self = .imdb
			case "instagram":
				self = .instagram
			case "lastpass":
				self = .lastpass
			case "nflx":
				self = .netflix
			case "paypal":
				self = .paypal
			case "photoscan":
				self = .photoscan
			case "pinterest":
				self = .pinterest
			case "planner":
				self = .planner
			case "podcast", "feed":
				self = .podcast
			case "powerpoint":
				self = .powerpoint
			case "protonmail":
				self = .protonmail
			case "sbbmobile":
			   self = .sbb
			case "sgnl":
				self = .signal
			case "shazam":
				self = .shazam
			case "skype":
				self = .skype
			case "slack":
				self = .slack
			case "snapchat":
				self = .snapchat
			case "speedtest":
				self = .ooklaSpeedtest
			case "spotify":
				self = .spotify
			case "tg", "tgapp":
				self = .telegram
			case "trello":
				self = .trello
			case "twitter":
				self = .twitter
			case "udemy":
				self = .udemy
			case "waze":
				self = .waze
			case "word":
				self = .word
			case "youtube":
				self = .youtube
			case "zuludesk":
				self = .zuludesk
			case "zoomus":
				self = .zoom
			case "prefs":
				self = .settings
			case "twint-issuer1":
				self = .twintPrepaid
			case "twint-issuer2":
				   self = .twintUBS
			case "twint-issuer3":
				   self = .twintZKB
			case "twint-issuer4":
				   self = .twintCS
			case "twint-issuer5":
				   self = .twintBCV
			case "twint-issuer6":
				   self = .twintRaiffeisen
			case "twint-issuer7":
				   self = .twintPostfinance
			case "twint-issuer8":
				   self = .twintOKB
			case "twint-issuer9":
				   self = .twintZugerKB
			case "twint-issuer10":
				   self = .twintBCGE
			case "twint-issuer11":
				   self = .twintNAB
			case "twint-issuer12":
				   self = .twintAPPKB
			case "twint-issuer13":
				   self = .twintBCVS
			case "twint-issuer14":
				   self = .twintSGKB
			case "twint-issuer15":
				   self = .twintGKB
			case "twint-issuer16":
				   self = .twintBCF
			case "twint-issuer17":
				   self = .twintBCJ
			case "twint-issuer18":
				   self = .twintBCN
			default:
				self = .unknown
		}
	}

	var appName: String? {
		switch self {
			case .store:			return NSLocalizedString("open url in app app store app name", comment: "name of the app store app used to confirm opening of url in other app")
			case .itunes:			return NSLocalizedString("open url in app itunes app name", comment: "name of the itunes app used to confirm opening of url in other app")
			case .mail:				return NSLocalizedString("open url in app mail app name", comment: "name of the mail app used to confirm opening of url in other app")
			case .messages:			return NSLocalizedString("open url in app messages app name", comment: "name of the messages app used to confirm opening of url in other app")
			case .maps:				return NSLocalizedString("open url in app maps app name", comment: "name of the maps app used to confirm opening of url in other app")
			case .calendar:			return NSLocalizedString("open url in app calendar app name", comment: "name of the calendar app used to confirm opening of url in other app")
			case .whatsapp:			return NSLocalizedString("open url in app whatsapp app name", comment: "name of the whatsapp app used to confirm opening of url in other app")
			case .shortcuts: 		return NSLocalizedString("open url in app shortcuts app name", comment: "name of the shortcuts app used to confirm opening of url in other app")
			case .testFlight:		return NSLocalizedString("open url in app testflight app name", comment: "name of the testflight app used to confirm opening of url in other app")
			case .books:			return NSLocalizedString("open url in app books app name", comment: "name of the books app used to confirm opening of url in other app")
			case .music:			return NSLocalizedString("open url in app music app name", comment: "name of the music app used to confirm opening of url in other app")
			case .appleTv:			return NSLocalizedString("open url in app apple tv app name", comment: "name of the apple tv app used to confirm opening of url in other app")
			case .duolingo:			return NSLocalizedString("open url in app duolingo app name", comment: "name of the duolingo app used to confirm opening of url in other app")
			case .evernote:			return NSLocalizedString("open url in app evernote app name", comment: "name of the evernote app used to confirm opening of url in other app")
			case .facebook:			return NSLocalizedString("open url in app facebook app name", comment: "name of the facebook app used to confirm opening of url in other app")
			case .fbMessenger:		return NSLocalizedString("open url in app facebook messenger app name", comment: "name of the facebook messenger app used to confirm opening of url in other app")
			case .fitbit:			return NSLocalizedString("open url in app fitbit app name", comment: "name of the fitbit app used to confirm opening of url in other app")
			case .flickr:			return NSLocalizedString("open url in app flickr app name", comment: "name of the flickr app used to confirm opening of url in other app")
			case .googleCalendar:	return NSLocalizedString("open url in app google calendar app name", comment: "name of the google calendar app used to confirm opening of url in other app")
			case .googleDocs:		return NSLocalizedString("open url in app google docs app name", comment: "name of the google docs app used to confirm opening of url in other app")
			case .googleDrive:		return NSLocalizedString("open url in app google drive app name", comment: "name of the google drive app used to confirm opening of url in other app")
			case .googleEarth:		return NSLocalizedString("open url in app google earth app name", comment: "name of the google earth app used to confirm opening of url in other app")
			case .gmail:			return NSLocalizedString("open url in app gmail app name", comment: "name of the gmail app used to confirm opening of url in other app")
			case .googleHome:		return NSLocalizedString("open url in app google home app name", comment: "name of the google home app used to confirm opening of url in other app")
			case .googleMaps:		return NSLocalizedString("open url in app google maps app name", comment: "name of the google maps app used to confirm opening of url in other app")
			case .googlePhotos:		return NSLocalizedString("open url in app google photos app name", comment: "name of the google photos app used to confirm opening of url in other app")
			case .googleSheets:		return NSLocalizedString("open url in app google sheets app name", comment: "name of the google sheets app used to confirm opening of url in other app")
			case .googleTranslate:	return NSLocalizedString("open url in app google translate app name", comment: "name of the google translate app used to confirm opening of url in other app")
			case .googleVoice:		return NSLocalizedString("open url in app google voice app name", comment: "name of the google voice app used to confirm opening of url in other app")
			case .hulu:				return NSLocalizedString("open url in app hulu app name", comment: "name of the hulu app used to confirm opening of url in other app")
			case .imdb:				return NSLocalizedString("open url in app imdb app name", comment: "name of the imdb app used to confirm opening of url in other app")
			case .instagram:		return NSLocalizedString("open url in app instagram app name", comment: "name of the instagram app used to confirm opening of url in other app")
			case .lastpass:			return NSLocalizedString("open url in app lastpass app name", comment: "name of the lastpass app used to confirm opening of url in other app")
			case .netflix:			return NSLocalizedString("open url in app netflix app name", comment: "name of the netflix app used to confirm opening of url in other app")
			case .paypal:			return NSLocalizedString("open url in app paypal app name", comment: "name of the paypal app used to confirm opening of url in other app")
			case .photoscan:		return NSLocalizedString("open url in app photoscan app name", comment: "name of the photoscan app used to confirm opening of url in other app")
			case .pinterest:		return NSLocalizedString("open url in app pinterest app name", comment: "name of the pinterest app used to confirm opening of url in other app")
			case .planner:			return NSLocalizedString("open url in app planner app name", comment: "name of the planner app used to confirm opening of url in other app")
			case .podcast:			return NSLocalizedString("open url in app podcast app name", comment: "name of the podcast app used to confirm opening of url in other app")
			case .powerpoint:		return NSLocalizedString("open url in app powerpoint app name", comment: "name of the powerpoint app used to confirm opening of url in other app")
			case .protonmail:		return NSLocalizedString("open url in app protonmail app name", comment: "name of the protonmail app used to confirm opening of url in other app")
			case .sbb:			return NSLocalizedString("open url in app sbb app name", comment: "name of the sbb app used to confirm opening of url in other app")
			case .signal:			return NSLocalizedString("open url in app signal app name", comment: "name of the signal app used to confirm opening of url in other app")
			case .shazam:			return NSLocalizedString("open url in app shazam app name", comment: "name of the shazam app used to confirm opening of url in other app")
			case .skype:			return NSLocalizedString("open url in app skype app name", comment: "name of the skype app used to confirm opening of url in other app")
			case .slack:			return NSLocalizedString("open url in app slack app name", comment: "name of the slack app used to confirm opening of url in other app")
			case .snapchat:			return NSLocalizedString("open url in app snapchat app name", comment: "name of the snapchat app used to confirm opening of url in other app")
			case .ooklaSpeedtest:	return NSLocalizedString("open url in app ookla speedtest app name", comment: "name of the ookla speedtest app used to confirm opening of url in other app")
			case .spotify:			return NSLocalizedString("open url in app spotify app name", comment: "name of the spotify app used to confirm opening of url in other app")
			case .telegram:			return NSLocalizedString("open url in app telegram app name", comment: "name of the telegram app used to confirm opening of url in other app")
			case .trello:			return NSLocalizedString("open url in app trello app name", comment: "name of the trello app used to confirm opening of url in other app")
			case .twitter:			return NSLocalizedString("open url in app twitter app name", comment: "name of the twitter app used to confirm opening of url in other app")
			case .udemy:			return NSLocalizedString("open url in app udemy app name", comment: "name of the udemy app used to confirm opening of url in other app")
			case .waze:				return NSLocalizedString("open url in app waze app name", comment: "name of the waze app used to confirm opening of url in other app")
			case .word:				return NSLocalizedString("open url in app word app name", comment: "name of the word app used to confirm opening of url in other app")
			case .youtube:			return NSLocalizedString("open url in app youtube app name", comment: "name of the youtube app used to confirm opening of url in other app")
			case .zuludesk:			return NSLocalizedString("open url in app zuludesk app name", comment: "name of the zuludesk app used to confirm opening of url in other app")
			case .zoom:				return NSLocalizedString("open url in app zoom app name", comment: "name of the zoom app used to confirm opening of url in other app")
			case .settings:			return NSLocalizedString("open url in app settings app name", comment: "name of the settings app used to confirm opening of url in other app")
			case .unknown:			return nil
			case .http:				return nil
			case .intent(_):		return nil
			case .call(_, true):	return NSLocalizedString("open url in app facetime app name", comment: "name of the facetime app used to confirm opening of url in other app")
			case .call(_, false):	return NSLocalizedString("open url in app phone app name", comment: "name of the phone app used to confirm opening of url in other app")

			case .twintPrepaid:		return NSLocalizedString("open url in app twint prepaid app name", comment: "name of the twint prepaid app used to confirm opening of url in other app")
			case .twintUBS:			return NSLocalizedString("open url in app twint ubs app name", comment: "name of the twint ubs app used to confirm opening of url in other app")
			case .twintZKB:			return NSLocalizedString("open url in app twint zkb app name", comment: "name of the twint zkb app used to confirm opening of url in other app")
			case .twintCS:			return NSLocalizedString("open url in app twint credit suisse app name", comment: "name of the twint credit suisse app used to confirm opening of url in other app")
			case .twintBCV:			return NSLocalizedString("open url in app twint bcv app name", comment: "name of the twint bcv app used to confirm opening of url in other app")
			case .twintRaiffeisen:	return NSLocalizedString("open url in app twint raiffeisen app name", comment: "name of the twint raiffeisen app used to confirm opening of url in other app")
			case .twintPostfinance:	return NSLocalizedString("open url in app twint postfinance app name", comment: "name of the twint postfinance app used to confirm opening of url in other app")
			case .twintOKB:			return NSLocalizedString("open url in app twint okb app name", comment: "name of the twint okb app used to confirm opening of url in other app")
			case .twintZugerKB:		return NSLocalizedString("open url in app twint zugerkb app name", comment: "name of the twint zugerkb app used to confirm opening of url in other app")
			case .twintBCGE:		return NSLocalizedString("open url in app twint bcge app name", comment: "name of the twint bcge app used to confirm opening of url in other app")
			case .twintNAB:			return NSLocalizedString("open url in app twint nab app name", comment: "name of the twint nab app used to confirm opening of url in other app")
			case .twintAPPKB:		return NSLocalizedString("open url in app twint appkb app name", comment: "name of the twint appkb app used to confirm opening of url in other app")
			case .twintBCVS:		return NSLocalizedString("open url in app twint bcvs app name", comment: "name of the twint bcvs app used to confirm opening of url in other app")
			case .twintSGKB:	return NSLocalizedString("open url in app twint sgkb app name", comment: "name of the twint sgkb app used to confirm opening of url in other app")
			case .twintGKB:	return NSLocalizedString("open url in app twint gkb app name", comment: "name of the twint gkb app used to confirm opening of url in other app")
			case .twintBCF:	return NSLocalizedString("open url in app twint bcf app name", comment: "name of the twint bcf app used to confirm opening of url in other app")
			case .twintBCJ:	return NSLocalizedString("open url in app twint bcj app name", comment: "name of the twint bcj app used to confirm opening of url in other app")
			case .twintBCN:	return NSLocalizedString("open url in app twint bcm app name", comment: "name of the twint bcn app used to confirm opening of url in other app")
		}
	}

	var needsCheck: Bool {
		switch self {
			case .whatsapp:			return true
			case .testFlight:		return true
			case .shortcuts:		return true
			case .call(_, _):		return true
			case .itunes:			return true
			case .mail:				return true
			case .maps:				return true
			case .calendar:			return true
			case .books:			return true
			case .music:			return true
			case .appleTv:			return true
			case .googleEarth:		return true
			case .duolingo:			return true
			case .evernote:			return true
			case .facebook:			return true
			case .fbMessenger:		return true
			case .fitbit:			return true
			case .flickr:			return true
			case .googleCalendar:	return true
			case .googleDocs:		return true
			case .googleDrive:		return true
			case .gmail:			return true
			case .googleHome:		return true
			case .googleMaps:		return true
			case .googlePhotos:		return true
			case .googleSheets:		return true
			case .googleTranslate:	return true
			case .googleVoice:		return true
			case .hulu:				return true
			case .imdb:				return true
			case .instagram:		return true
			case .lastpass:			return true
			case .netflix:			return true
			case .paypal:			return true
			case .photoscan:		return true
			case .pinterest:		return true
			case .planner:			return true
			case .podcast:			return true
			case .powerpoint:		return true
			case .protonmail:		return true
			case .sbb:				return true
			case .signal:			return true
			case .shazam:			return true
			case .skype:			return true
			case .slack:			return true
			case .snapchat:			return true
			case .ooklaSpeedtest:	return true
			case .spotify:			return true
			case .telegram:			return true
			case .trello:			return true
			case .twitter:			return true
			case .udemy:			return true
			case .waze:				return true
			case .word:				return true
			case .youtube:			return true
			case .zuludesk:			return true
			case .zoom:				return true
			case .twintPrepaid:		return true
			case .twintUBS:			return true
			case .twintZKB:			return true
			case .twintCS:			return true
			case .twintBCV:			return true
			case .twintRaiffeisen:	return true
			case .twintPostfinance:	return true
			case .twintOKB:			return true
			case .twintZugerKB:		return true
			case .twintBCGE:		return true
			case .twintNAB:			return true
			case .twintAPPKB:		return true
			case .twintBCVS:		return true
			case .twintSGKB:		return true
			case .twintGKB:			return true
			case .twintBCF:			return true
			case .twintBCJ:			return true
			case .twintBCN:			return true
			case .unknown:			return false
			case .http:				return false
			case .store:			return false
			case .messages:			return false
			case .intent(_):		return false
			case .settings:			return false
		}
	}
}
