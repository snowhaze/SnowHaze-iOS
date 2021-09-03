//
//  Redirector.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

// NOTE: This is currently not yet reliable enough. It can therefore not be enabled from the UI.
struct Redirector {
	static let shared = Redirector()

	private let googleHosts = Set([
		"google.ac",
		"google.ad",
		"google.ae",
		"google.al",
		"google.am",
		"google.as",
		"google.at",
		"google.az",
		"google.ba",
		"google.be",
		"google.bf",
		"google.bg",
		"google.bi",
		"google.bj",
		"google.bs",
		"google.bt",
		"google.by",
		"google.ca",
		"google.cat",
		"google.cd",
		"google.cf",
		"google.cg",
		"google.ch",
		"google.ci",
		"google.cl",
		"google.cm",
		"google.cn",
		"google.co.ao",
		"google.co.bw",
		"google.co.ck",
		"google.co.cr",
		"google.co.id",
		"google.co.il",
		"google.co.in",
		"google.co.je",
		"google.co.jp",
		"google.co.kr",
		"google.co.ls",
		"google.co.ma",
		"google.co.mz",
		"google.co.nz",
		"google.co.th",
		"google.co.tz",
		"google.co.ug",
		"google.co.uk",
		"google.co.uz",
		"google.co.ve",
		"google.co.vi",
		"google.co.za",
		"google.co.zm",
		"google.co.zw",
		"google.com",
		"google.com.af",
		"google.com.ag",
		"google.com.ai",
		"google.com.ar",
		"google.com.au",
		"google.com.bd",
		"google.com.bh",
		"google.com.bn",
		"google.com.bo",
		"google.com.br",
		"google.com.by",
		"google.com.bz",
		"google.com.cn",
		"google.com.co",
		"google.com.cu",
		"google.com.cy",
		"google.com.do",
		"google.com.ec",
		"google.com.eg",
		"google.com.et",
		"google.com.fj",
		"google.com.gh",
		"google.com.gi",
		"google.com.gt",
		"google.com.hk",
		"google.com.iq",
		"google.com.jm",
		"google.com.kh",
		"google.com.kw",
		"google.com.lb",
		"google.com.ly",
		"google.com.mm",
		"google.com.mt",
		"google.com.mx",
		"google.com.my",
		"google.com.na",
		"google.com.ng",
		"google.com.ni",
		"google.com.np",
		"google.com.om",
		"google.com.pa",
		"google.com.pe",
		"google.com.pg",
		"google.com.ph",
		"google.com.pk",
		"google.com.pl",
		"google.com.pr",
		"google.com.py",
		"google.com.qa",
		"google.com.ru",
		"google.com.sa",
		"google.com.sb",
		"google.com.sg",
		"google.com.sl",
		"google.com.sv",
		"google.com.tj",
		"google.com.tn",
		"google.com.tr",
		"google.com.tw",
		"google.com.ua",
		"google.com.uy",
		"google.com.vc",
		"google.com.ve",
		"google.com.vn",
		"google.cv",
		"google.cz",
		"google.de",
		"google.dj",
		"google.dk",
		"google.dm",
		"google.dz",
		"google.ee",
		"google.es",
		"google.fi",
		"google.fm",
		"google.fr",
		"google.ga",
		"google.ge",
		"google.gg",
		"google.gl",
		"google.gm",
		"google.gp",
		"google.gr",
		"google.gy",
		"google.hk",
		"google.hn",
		"google.hr",
		"google.ht",
		"google.hu",
		"google.ie",
		"google.im",
		"google.iq",
		"google.is",
		"google.it",
		"google.it.ao",
		"google.je",
		"google.jo",
		"google.jp",
		"google.kg",
		"google.ki",
		"google.kz",
		"google.la",
		"google.li",
		"google.lk",
		"google.lt",
		"google.lu",
		"google.lv",
		"google.md",
		"google.me",
		"google.mg",
		"google.mk",
		"google.ml",
		"google.mn",
		"google.ms",
		"google.mu",
		"google.mv",
		"google.mw",
		"google.ne",
		"google.net",
		"google.ng",
		"google.nl",
		"google.no",
		"google.nr",
		"google.nu",
		"google.pk",
		"google.pl",
		"google.pn",
		"google.ps",
		"google.pt",
		"google.ro",
		"google.rs",
		"google.ru",
		"google.rw",
		"google.sc",
		"google.se",
		"google.sh",
		"google.si",
		"google.sk",
		"google.sm",
		"google.sn",
		"google.so",
		"google.sr",
		"google.st",
		"google.td",
		"google.tg",
		"google.tk",
		"google.tl",
		"google.tm",
		"google.tn",
		"google.to",
		"google.tt",
		"google.us",
		"google.vg",
		"google.vu",
		"google.ws",
		"www.google.ac",
		"www.google.ad",
		"www.google.ae",
		"www.google.al",
		"www.google.am",
		"www.google.as",
		"www.google.at",
		"www.google.az",
		"www.google.ba",
		"www.google.be",
		"www.google.bf",
		"www.google.bg",
		"www.google.bi",
		"www.google.bj",
		"www.google.bs",
		"www.google.bt",
		"www.google.by",
		"www.google.ca",
		"www.google.cat",
		"www.google.cd",
		"www.google.cf",
		"www.google.cg",
		"www.google.ch",
		"www.google.ci",
		"www.google.cl",
		"www.google.cm",
		"www.google.cn",
		"www.google.co.ao",
		"www.google.co.bw",
		"www.google.co.ck",
		"www.google.co.cr",
		"www.google.co.id",
		"www.google.co.il",
		"www.google.co.in",
		"www.google.co.je",
		"www.google.co.jp",
		"www.google.co.kr",
		"www.google.co.ls",
		"www.google.co.ma",
		"www.google.co.mz",
		"www.google.co.nz",
		"www.google.co.th",
		"www.google.co.tz",
		"www.google.co.ug",
		"www.google.co.uk",
		"www.google.co.uz",
		"www.google.co.ve",
		"www.google.co.vi",
		"www.google.co.za",
		"www.google.co.zm",
		"www.google.co.zw",
		"www.google.com",
		"www.google.com.af",
		"www.google.com.ag",
		"www.google.com.ai",
		"www.google.com.ar",
		"www.google.com.au",
		"www.google.com.bd",
		"www.google.com.bh",
		"www.google.com.bn",
		"www.google.com.bo",
		"www.google.com.br",
		"www.google.com.by",
		"www.google.com.bz",
		"www.google.com.cn",
		"www.google.com.co",
		"www.google.com.cu",
		"www.google.com.cy",
		"www.google.com.do",
		"www.google.com.ec",
		"www.google.com.eg",
		"www.google.com.et",
		"www.google.com.fj",
		"www.google.com.gh",
		"www.google.com.gi",
		"www.google.com.gt",
		"www.google.com.hk",
		"www.google.com.iq",
		"www.google.com.jm",
		"www.google.com.kh",
		"www.google.com.kw",
		"www.google.com.lb",
		"www.google.com.ly",
		"www.google.com.mm",
		"www.google.com.mt",
		"www.google.com.mx",
		"www.google.com.my",
		"www.google.com.na",
		"www.google.com.ng",
		"www.google.com.ni",
		"www.google.com.np",
		"www.google.com.om",
		"www.google.com.pa",
		"www.google.com.pe",
		"www.google.com.pg",
		"www.google.com.ph",
		"www.google.com.pk",
		"www.google.com.pl",
		"www.google.com.pr",
		"www.google.com.py",
		"www.google.com.qa",
		"www.google.com.ru",
		"www.google.com.sa",
		"www.google.com.sb",
		"www.google.com.sg",
		"www.google.com.sl",
		"www.google.com.sv",
		"www.google.com.tj",
		"www.google.com.tn",
		"www.google.com.tr",
		"www.google.com.tw",
		"www.google.com.ua",
		"www.google.com.uy",
		"www.google.com.vc",
		"www.google.com.ve",
		"www.google.com.vn",
		"www.google.cv",
		"www.google.cz",
		"www.google.de",
		"www.google.dj",
		"www.google.dk",
		"www.google.dm",
		"www.google.dz",
		"www.google.ee",
		"www.google.es",
		"www.google.fi",
		"www.google.fm",
		"www.google.fr",
		"www.google.ga",
		"www.google.ge",
		"www.google.gg",
		"www.google.gl",
		"www.google.gm",
		"www.google.gp",
		"www.google.gr",
		"www.google.gy",
		"www.google.hk",
		"www.google.hn",
		"www.google.hr",
		"www.google.ht",
		"www.google.hu",
		"www.google.ie",
		"www.google.im",
		"www.google.iq",
		"www.google.is",
		"www.google.it",
		"www.google.it.ao",
		"www.google.je",
		"www.google.jo",
		"www.google.jp",
		"www.google.kg",
		"www.google.ki",
		"www.google.kz",
		"www.google.la",
		"www.google.li",
		"www.google.lk",
		"www.google.lt",
		"www.google.lu",
		"www.google.lv",
		"www.google.md",
		"www.google.me",
		"www.google.mg",
		"www.google.mk",
		"www.google.ml",
		"www.google.mn",
		"www.google.ms",
		"www.google.mu",
		"www.google.mv",
		"www.google.mw",
		"www.google.ne",
		"www.google.net",
		"www.google.ng",
		"www.google.nl",
		"www.google.no",
		"www.google.nr",
		"www.google.nu",
		"www.google.pk",
		"www.google.pl",
		"www.google.pn",
		"www.google.ps",
		"www.google.pt",
		"www.google.ro",
		"www.google.rs",
		"www.google.ru",
		"www.google.rw",
		"www.google.sc",
		"www.google.se",
		"www.google.sh",
		"www.google.si",
		"www.google.sk",
		"www.google.sm",
		"www.google.sn",
		"www.google.so",
		"www.google.sr",
		"www.google.st",
		"www.google.td",
		"www.google.tg",
		"www.google.tk",
		"www.google.tl",
		"www.google.tm",
		"www.google.tn",
		"www.google.to",
		"www.google.tt",
		"www.google.us",
		"www.google.vg",
		"www.google.vu",
		"www.google.ws",
	])

	private init() { }

	func redirect(_ original: URL) -> URL? {
		guard let comps = URLComponents(url: original, resolvingAgainstBaseURL: true), let host = comps.host else {
			return nil
		}
		if googleHosts.contains(host) && comps.path == "/url" {
			// https://www.google.ch/url?q=https://de.wikipedia.org/wiki/Test_(Begriffskl%25C3%25A4rung)&sa=U&ved=0ahUKEwik16rmrPnXAhUIOhQKHQj-DmUQFggYMAE&usg=AOvVaw2pUEKQD6-Jw9hnyxoGU3FA
			for param in comps.queryItems ?? [] {
				if param.name == "q" {
					if let value = param.value {
						return URL(string: value, relativeTo: URL(string: "https://" + host))
					} else {
						return nil
					}
				}
			}
		} else if host == "www.codingame.com" && comps.path == "/servlet/mlinkservlet" {
			// https://www.codingame.com/servlet/mlinkservlet?lmid=69110184mAbCOY&ltpl=3&link=https%3A%2F%2Fwww.codingame.com%2Fgames%2Fpuzzles%2F359%3Futm_term%3Den%26amp%3Butm_source%3DDigest%26amp%3Butm_medium%3Dpuzzle%26amp%3Butm_content%3Dview%26amp%3Butm_campaign%3DNotifications
			for param in comps.queryItems ?? [] {
				if param.name == "link" {
					if let value = param.value?.unescapedHTMLEntities {
						return URL(string: value, relativeTo: original)
					} else {
						return nil
					}
				}
			}
		} else if host == "o.ello.co" {
			// https://o.ello.co/http://danbassini.com/about-me
			let path = comps.path
			let lowered = path.lowercased()
			guard lowered.hasPrefix("/https://") || lowered.hasPrefix("/http://") else {
				return nil
			}
			let index1 = path.index(after: path.startIndex)
			let url = String(path[index1...])
			return URL(string: url)
		} else if host == "waltrapp.co" && comps.path == "/link.php" {
			// https://waltrapp.co/link.php?page=https:%2F%2Fsoftorino.com%2Firingg
			for param in comps.queryItems ?? [] {
				if param.name == "page" {
					if let value = param.value {
						return URL(string: value, relativeTo: original)
					} else {
						return nil
					}
				}
			}
		} else if host == "www.awin1.com" && comps.path == "/cread.php" {
			// http://www.awin1.com/cread.php?awinmid=3738&awinaffid=101301&clickref=731-534-19935623-0&p=https:%2F%2Fwww.anglianhome.co.uk%2Fenquiry-4?id%3D26426.7773&from=50680
			for param in comps.queryItems ?? [] {
				if param.name == "p" {
					if let value = param.value {
						return URL(string: value, relativeTo: original)
					} else {
						return nil
					}
				}
			}
		} else if host == "xp.apple.com" && comps.path == "/report/2/its_mail_sf" {
			// https://xp.apple.com/report/2/its_mail_sf?responseType=redirect&redirectUrl=https:%2F%2Fbuy.itunes.apple.com%2FWebObjects%2FMZFinance.woa%2Fwa%2FaccountSummary
			var isRedirect = false
			var url: URL? = nil
			for param in comps.queryItems ?? [] {
				if param.name == "responseType" {
					if param.value == "redirect" {
						if let url = url {
							return url
						} else {
							isRedirect = true
						}
					} else {
						return nil
					}
				} else if param.name == "redirectUrl" {
					if let value = param.value {
						url = URL(string: value)
						guard ["http", "https"].contains(url?.normalizedScheme) else {
							return nil
						}
						guard let host = url?.normalizedHost else {
							return nil
						}
						guard host == "apple.com" || host.hasSuffix(".apple.com") else {
							return nil
						}
					}
					if isRedirect {
						return url
					}
				}
			}
			return nil
		}
		return nil
	}
}
