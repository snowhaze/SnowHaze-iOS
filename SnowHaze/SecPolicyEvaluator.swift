//
//  SecPolicyEvaluator.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

enum SecChallengeHandlerIssue {
	case unrecoverable
	case domainMismatch(certDomain: String?)
	case invalidCert
	case none
	case notEvaluated
}

enum SecChallengeHandlerPolicy {
	case strict
	case allowDomainMismatch
	case allowInvalidCerts
}

enum PinningMode {
	case none
	case certs([SecCertificate])
	case keys([SecKey])
}

class SecPolicyEvaluator {
	private let domain: String
	private let trust: SecTrust

	private(set) var issue: SecChallengeHandlerIssue = .notEvaluated
	private(set) var error: Int = Int(errSecSuccess)

	private func result(for policy: SecPolicy) throws -> Bool {
		let uspecifiedResult = SecTrustResultType.unspecified
		let proceedResult = SecTrustResultType.proceed
		var result = SecTrustResultType.invalid
		SecTrustSetPolicies(trust, policy)
		let error = SecTrustEvaluate(trust, &result)
		guard error == errSecSuccess else {
			let errorDomain = "ch.illotros.snowhaze.internalErrorDomain.OSStatus"
			throw NSError(domain: errorDomain, code: Int(error), userInfo: nil)
		}
		return (result == uspecifiedResult || result == proceedResult)
	}

	func evaluate(_ policy: SecChallengeHandlerPolicy, completionHandler: @escaping (Bool) -> Void) {
		let callback: (Bool) -> Void = { result in
			DispatchQueue.main.sync { completionHandler(result) }
		}
		DispatchQueue.global(qos: .userInitiated).async {
			self.error = Int(errSecSuccess)
			if policy != .allowInvalidCerts {
				do {
					guard try self.result(for: SecPolicyCreateSSL(true, nil)) else {
						self.issue = .invalidCert
						callback(false)
						return
					}
					if policy != .allowDomainMismatch {
						guard try self.result(for: SecPolicyCreateSSL(true, self.domain as CFString)) else {
							let res: String?
							if let cert = SecTrustGetCertificateAtIndex(self.trust, 0) {
								res = SecCertificateCopySubjectSummary(cert) as String?
							} else {
								res = nil
							}
							self.issue = .domainMismatch(certDomain: res)
							callback(false)
							return
						}
					}
				} catch let error {
					self.issue = .unrecoverable
					self.error = (error as NSError).code
					callback(false)
					return
				}
			}
			self.issue = .none
			callback(true)
		}
	}

	func pin(with mode: PinningMode) -> Bool {
		switch mode {
			case .none:
				return true
			case .certs(let certs):
				let pinnedData = certs.map { SecCertificateCopyData($0) }
				guard let cert = SecTrustGetCertificateAtIndex(trust, 0) else {
					return false
				}
				return pinnedData.contains(SecCertificateCopyData(cert))
			case .keys(let keys):
				guard let cert = SecTrustGetCertificateAtIndex(trust, 0) else {
					return false
				}
				guard let key = SecPolicyEvaluator.key(for: cert) else {
					return false
				}
				return keys.contains(key)
		}
	}

	private static func key(for cert: SecCertificate) -> SecKey? {
		var t: SecTrust?
		guard SecTrustCreateWithCertificates(cert, nil, &t) == errSecSuccess else {
			return nil
		}
		return SecTrustCopyPublicKey(t!)
	}

	static func cert(named name: String, in bundle: Bundle = Bundle.main) -> SecCertificate! {
		guard let path = bundle.path(forResource: name, ofType: ".cer") else {
			return nil
		}
		guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData else {
			return nil
		}
		return SecCertificateCreateWithData(nil, data)
	}

	static func key(named name: String, in bundle: Bundle = Bundle.main) -> SecKey! {
		guard let cert = cert(named: name, in: bundle) else {
			return nil
		}
		return key(for: cert)
	}

	init(domain: String, trust: SecTrust) {
		self.domain = domain
		self.trust = trust
	}
}
