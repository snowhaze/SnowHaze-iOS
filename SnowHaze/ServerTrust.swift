//
//  ServerTrust.swift
//  SnowHaze
//
//
//  Copyright © 2019 Illotros GmbH. All rights reserved.
//

import Foundation
import CommonCrypto

struct ServerTrust {
	let trust: SecTrust
	init(trust: SecTrust) {
		self.trust = trust
	}

	fileprivate static func sha256(_ data: Data) -> Data {
		var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
		_ = data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG($0.count), &hash) }
		return Data(hash)
	}

	var evOrganization: String? {
		guard let trustInfo = SecTrustCopyResult(trust) as NSDictionary? else {
			return nil
		}
		if trustInfo[kSecTrustExtendedValidation] as? Bool == true {
			return trustInfo[kSecTrustOrganizationName] as? String
		}
		return nil
	}

	var certificates: [ServerCert?] {
		var result = [ServerCert?]()
		for i in 0 ..< SecTrustGetCertificateCount(trust) {
			if let cert = SecTrustGetCertificateAtIndex(trust, i) {
				result.append(ServerCert(cert: cert))
			} else {
				result.append(nil)
			}
		}
		return result
	}

	private var trustInfo: NSDictionary? {
		return SecTrustCopyResult(trust) as NSDictionary?
	}

	var transparency: Bool? {
		return trustInfo?[kSecTrustCertificateTransparency] as? Bool
	}

	var evaluationDate: Date? {
		return trustInfo?[kSecTrustEvaluationDate] as? Date
	}

	var extendedEvaluation: Bool? {
		return trustInfo?[kSecTrustExtendedValidation] as? Bool
	}

	var organization: String? {
		return trustInfo?[kSecTrustOrganizationName] as? String
	}

	var result: SecTrustResultType? {
		return trustInfo?[kSecTrustResultValue] as? SecTrustResultType
	}

	var revocationChecked: Bool? {
		return trustInfo?[kSecTrustRevocationChecked] as? Bool
	}

	var revocationValidUntil: Date? {
		return trustInfo?[kSecTrustRevocationValidUntilDate] as? Date
	}
}

struct ServerCert {
	let cert: SecCertificate
	init(cert: SecCertificate) {
		self.cert = cert
	}

	var subjectSummary: String? {
		return SecCertificateCopySubjectSummary(cert) as String?
	}

	var data: Data {
		return SecCertificateCopyData(cert) as Data
	}

	var sha256: String {
		return ServerTrust.sha256(data).hex
	}

	var key: Key? {
		if let key = SecCertificateCopyKey(cert) {
			return Key(key: key)
		}
		return nil
	}

	var der: DER? {
		return try? DER.parse(data)
	}

	var commonName: String? {
		var name: CFString? = nil
		SecCertificateCopyCommonName(cert, &name)
		return name as String?
	}

	var emailAddresses: [String]? {
		var emails: CFArray? = nil
		SecCertificateCopyEmailAddresses(cert, &emails)
		return emails as? [String]
	}

	var serialNumber: Data? {
		return SecCertificateCopySerialNumberData(cert, nil) as Data?
	}

	struct Key {
		let key: SecKey

		enum Algorithm {
			case rsa
			case ec
			case other

			fileprivate init(raw: String) {
				switch raw as CFString {
					case kSecAttrKeyTypeRSA:
						self = .rsa
					case kSecAttrKeyTypeEC,
						 kSecAttrKeyTypeECSECPrimeRandom:
						self = .ec
					default:
						self = .other
				}
			}
		}

		struct Uses: OptionSet {
			let rawValue: Int
			static let encrypt = Uses(rawValue: 1 << 0)
			static let decrypt = Uses(rawValue: 1 << 1)
			static let derive = Uses(rawValue: 1 << 2)
			static let sign = Uses(rawValue: 1 << 3)
			static let verify = Uses(rawValue: 1 << 4)
			static let wrap = Uses(rawValue: 1 << 5)
			static let unwrap = Uses(rawValue: 1 << 6)

			init(rawValue: Int) {
				self.rawValue = rawValue
			}

			fileprivate init?(attributes: NSDictionary) {
				var rawValue = 0
				let keys = [kSecAttrCanEncrypt, kSecAttrCanDecrypt, kSecAttrCanDerive, kSecAttrCanSign, kSecAttrCanVerify, kSecAttrCanWrap, kSecAttrCanUnwrap]
				let values = keys.compactMap { attributes[$0] as? Bool }
				guard values.count == keys.count else {
					return nil
				}
				values.enumerated().forEach { rawValue |= $1 ? 1 << $0 : 0 }
				self.init(rawValue: rawValue)
			}
		}

		init(key: SecKey) {
			self.key = key
		}

		var data: Data? {
			return SecKeyCopyExternalRepresentation(key, nil) as Data?
		}

		var sha256: String? {
			if let data = data {
				return ServerTrust.sha256(data).hex
			}
			return nil
		}

		var effectiveSize: Int? {
			return attributes?[kSecAttrEffectiveKeySize] as? Int
		}

		var bitSize: Int? {
			return attributes?[kSecAttrKeySizeInBits] as? Int
		}

		var type: Algorithm? {
			if let raw = attributes?[kSecAttrKeyType] as? String {
				return Algorithm(raw: raw)
			}
			return nil
		}

		var uses: Uses? {
			if let attributes = attributes {
				return Uses(attributes: attributes)
			}
			return nil
		}

		private var attributes: NSDictionary? {
			return SecKeyCopyAttributes(key) as NSDictionary?
		}
	}
}
