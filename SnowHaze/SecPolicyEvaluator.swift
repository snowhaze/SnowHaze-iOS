//
//  SecPolicyEvaluator.swift
//  SnowHaze
//
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

	func evaluate(_ policy: SecChallengeHandlerPolicy, completionHandler: @escaping (Bool) -> Void) {
		let callback: (Bool) -> Void = { result in
			DispatchQueue.main.sync { completionHandler(result) }
		}
		DispatchQueue.global(qos: .userInitiated).async {
			self.error = Int(errSecUnimplemented)
			if policy != .allowInvalidCerts {
				let evalDomain = policy == .allowDomainMismatch ? nil : self.domain as CFString
				self.error = Int(SecTrustSetPolicies(self.trust, SecPolicyCreateSSL(true, evalDomain)))
				guard self.error == Int(errSecSuccess) else {
					self.issue = .unrecoverable
					callback(false)
					return
				}
				var error: CFError? = nil
				let result = SecTrustEvaluateWithError(self.trust, &error)
				guard (error == nil) == result else {
					self.issue = .unrecoverable
					callback(false)
					return
				}
				if let error = error {
					// weird hack to get around compiler bug
					// TODO: remove once compiler is fixed
					guard let error = (error as Any) as? NSError else {
						self.issue = .unrecoverable
						callback(false)
						return
					}
					guard error.domain == kCFErrorDomainOSStatus as String else {
						self.issue = .unrecoverable
						callback(false)
						return
					}
					self.error = error.code
					if error.code == errSecHostNameMismatch {
						self.issue = .domainMismatch(certDomain: ServerTrust(trust: self.trust).certificates[0]?.commonName)
						callback(false)
						return
					} else {
						print(error)
						self.issue = .invalidCert
						callback(false)
						return
					}
				}
			}
			self.error = Int(errSecSuccess)
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
