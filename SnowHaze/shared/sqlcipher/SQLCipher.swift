//
//  SQLCipher.swift
//  SnowHaze
//

//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

public class SQLCipher: SQLite {
	public static let keySize = 32

	public struct SetupOptions: OptionSet {
		public let rawValue: Int

		public init(rawValue: Int) {
			self.rawValue = rawValue
		}

		public static let none				= SetupOptions(rawValue: 0)
		public static let defensive			= SetupOptions(rawValue: 1)
		public static let cellSizeCheck		= SetupOptions(rawValue: 2)
		public static let disableMemMap		= SetupOptions(rawValue: 4)
		public static let all: SetupOptions	= [defensive, cellSizeCheck, disableMemMap]

		var setupOptions: [FinalSetupOptions] {
			var result = [FinalSetupOptions]()
			if self.contains(SetupOptions.disableMemMap) {
				result.append(.statement("PRAGMA mmap_size = 0"))
			}
			if self.contains(SetupOptions.defensive) {
				result.append(.config(.defensive(true)))
			}
			if self.contains(SetupOptions.cellSizeCheck) {
				result.append(.statement("PRAGMA cell_size_check = ON"))
			}
			return result
		}
	}

	public enum HashAlgorithm: Equatable {
		case sha1
		case sha256
		case sha512

		fileprivate var name: String {
			switch self {
				case .sha1:		return "SHA1"
				case .sha256:	return "SHA256"
				case .sha512:	return "SHA512"
			}
		}

		public static func ==(_ lhs: HashAlgorithm, _ rhs: HashAlgorithm) -> Bool {
			switch (lhs, rhs) {
				case (.sha1, .sha1):		return true
				case (.sha256, .sha256):	return true
				case (.sha512, .sha512):	return true
				default:					return false
			}
		}
	}

	public enum CipherOptions: Equatable {
		case unspecified

		/// DB version to be opened / saved
		case compatibility(UInt)

		/// KDF itterations, page size, use hmac, plaintext header size, HMAC algorithm, KDF algorithm
		case explicit(kdf: UInt, pageSize: UInt, useHMAC: Bool, headerSize: UInt, hmacAlgo: HashAlgorithm, kdfAlgo: HashAlgorithm)

		private func options(forSetup setup: Bool) -> [FinalSetupOptions] {
			var result = [String]()
			switch self {
				case .unspecified:
					break
				case .compatibility(let version):
					result.append("PRAGMA cipher\(setup ? "" : "_default")_compatibility = \(version)")
				case .explicit(let kdfItter, let pageSize, let useHMAC, let plaintextHeaderSize, let hmacAlgo, let kdfAlgo):
					result.append("PRAGMA \(setup ? "" : "cipher_default_")kdf_iter = \(kdfItter)")
					result.append("PRAGMA cipher\(setup ? "" : "_default")_page_size = \(pageSize)")
					result.append("PRAGMA cipher\(setup ? "" : "_default")_use_hmac = \(useHMAC ? "ON" : "OFF")")
					result.append("PRAGMA cipher\(setup ? "" : "_default")_plaintext_header_size = \(plaintextHeaderSize)")
					result.append("PRAGMA cipher\(setup ? "" : "_default")_hmac_algorithm = HMAC_\(hmacAlgo.name)")
					result.append("PRAGMA cipher\(setup ? "" : "_default")_kdf_algorithm = PBKDF2_HMAC_\(kdfAlgo.name)")
			}
			return result.map{ FinalSetupOptions.statement($0) }
		}

		fileprivate var setupOptions: [FinalSetupOptions] {
			return options(forSetup: true)
		}

		static let v1Defaults = CipherOptions.explicit(kdf: 4000, pageSize: 1024, useHMAC: false, headerSize: 0, hmacAlgo: .sha1, kdfAlgo: .sha1)
		static let v2Defaults = CipherOptions.explicit(kdf: 4000, pageSize: 1024, useHMAC: true, headerSize: 0, hmacAlgo: .sha1, kdfAlgo: .sha1)
		static let v3Defaults = CipherOptions.explicit(kdf: 64000, pageSize: 1024, useHMAC: true, headerSize: 0, hmacAlgo: .sha1, kdfAlgo: .sha1)
		static let v4Defaults = CipherOptions.explicit(kdf: 256000, pageSize: 4096, useHMAC: true, headerSize: 0, hmacAlgo: .sha512, kdfAlgo: .sha512)

		public var kdfItterations: UInt {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.kdfItterations
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.kdfItterations
						case 2:		return CipherOptions.v2Defaults.kdfItterations
						case 3:		return CipherOptions.v3Defaults.kdfItterations
						default:	return CipherOptions.v4Defaults.kdfItterations
					}
				case .explicit(let kdf, _, _, _, _, _):
					return kdf
			}
		}

		public var cipherPageSize: UInt {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.cipherPageSize
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.cipherPageSize
						case 2:		return CipherOptions.v2Defaults.cipherPageSize
						case 3:		return CipherOptions.v3Defaults.cipherPageSize
						default:	return CipherOptions.v4Defaults.cipherPageSize
					}
				case .explicit(_, let pageSize, _, _, _, _):
					return pageSize
			}
		}

		public var useHMAC: Bool {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.useHMAC
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.useHMAC
						case 2:		return CipherOptions.v2Defaults.useHMAC
						case 3:		return CipherOptions.v3Defaults.useHMAC
						default:	return CipherOptions.v4Defaults.useHMAC
					}
				case .explicit(_, _, let useHMAC, _, _, _):
					return useHMAC
			}
		}

		public var plaintextHeaderSize: UInt {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.plaintextHeaderSize
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.plaintextHeaderSize
						case 2:		return CipherOptions.v2Defaults.plaintextHeaderSize
						case 3:		return CipherOptions.v3Defaults.plaintextHeaderSize
						default:	return CipherOptions.v4Defaults.plaintextHeaderSize
					}
				case .explicit(_, _, _, let headerSize, _, _):
					return headerSize
			}
		}

		public var hmacAlgorithm: HashAlgorithm {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.hmacAlgorithm
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.hmacAlgorithm
						case 2:		return CipherOptions.v2Defaults.hmacAlgorithm
						case 3:		return CipherOptions.v3Defaults.hmacAlgorithm
						default:	return CipherOptions.v4Defaults.hmacAlgorithm
					}
				case .explicit(_, _, _, _, let hmacAlgo, _):
					return hmacAlgo
			}
		}

		public var kdfAlgorithm: HashAlgorithm {
			switch self {
				case .unspecified:
					return CipherOptions.v4Defaults.kdfAlgorithm
				case .compatibility(let version):
					switch version {
						case 1:		return CipherOptions.v1Defaults.kdfAlgorithm
						case 2:		return CipherOptions.v2Defaults.kdfAlgorithm
						case 3:		return CipherOptions.v3Defaults.kdfAlgorithm
						default:	return CipherOptions.v4Defaults.kdfAlgorithm
					}
				case .explicit(_, _, _, _, _, let kdfAlgo):
					return kdfAlgo
			}
		}

		public func set(kdf: UInt? = nil, pageSize: UInt? = nil, useHMAC: Bool? = nil, headerSize: UInt? = nil, hmacAlgorithm: HashAlgorithm? = nil, kdfAlgorithm: HashAlgorithm? = nil) -> CipherOptions {
			let kdf = kdf ?? self.kdfItterations
			let pageSize = pageSize ?? self.cipherPageSize
			let useHMAC = useHMAC ?? self.useHMAC
			let headerSize = headerSize ?? self.plaintextHeaderSize
			let hmacAlgorithm = hmacAlgorithm ?? self.hmacAlgorithm
			let kdfAlgorithm = kdfAlgorithm ?? self.kdfAlgorithm
			return .explicit(kdf: kdf, pageSize: pageSize, useHMAC: useHMAC, headerSize: headerSize, hmacAlgo: hmacAlgorithm, kdfAlgo: kdfAlgorithm)
		}

		public static func ==(_ lhs: CipherOptions, _ rhs: CipherOptions) -> Bool {
			switch (lhs, rhs) {
				case (.unspecified, .unspecified):
					return true
				case (.unspecified, _):
					return v4Defaults == rhs
				case (_, .unspecified):
					return lhs == v4Defaults
				case (.compatibility(let lv), .compatibility(let rv)):
					let left = (1...4).contains(lv) ? lv : 4
					let right = (1...4).contains(rv) ? rv : 4
					return left == right
				case (.compatibility(let lv), _):
					let left = (1...4).contains(lv) ? lv : 4
					switch left {
						case 1:		return v1Defaults == rhs
						case 2:		return v2Defaults == rhs
						case 3:		return v3Defaults == rhs
						case 4:		return v4Defaults == rhs
						default:	fatalError("unreachable")
					}
				case (_, .compatibility(let rv)):
					let right = (1...4).contains(rv) ? rv : 4
					switch right {
						case 1:		return lhs == v1Defaults
						case 2:		return lhs == v2Defaults
						case 3:		return lhs == v3Defaults
						case 4:		return lhs == v4Defaults
						default:	fatalError("unreachable")
					}
				case (.explicit(let kdfl, let pgSzl, let hmacl, let hdrSzl, let hmacAlgol, let kdfAlgol), .explicit(let kdfr, let pgSzr, let hmacr, let hdrSzr, let hmacAlgor, let kdfAlgor)):
					return kdfl == kdfr && pgSzl == pgSzr && hmacl == hmacr && hdrSzl == hdrSzr && hmacAlgol == hmacAlgor && kdfAlgol == kdfAlgor
			}
		}
	}

	private static func keyingOption(key: String) -> [FinalSetupOptions] {
		return [FinalSetupOptions.statement("PRAGMA key = \(key.sqliteEscaped)")]
	}

	private static func keyingOption(key: Foundation.Data) -> [FinalSetupOptions] {
		return [FinalSetupOptions.statement("PRAGMA key = \"\(key.sqliteEscaped)\"")]
	}

	public init?(path: String, key: String, flags: OpenFlags = .rwCreate, cipherOptions: CipherOptions = .unspecified, setupOptions: SetupOptions = .none) {
		let setup = setupOptions.setupOptions + SQLCipher.keyingOption(key: key) + cipherOptions.setupOptions
		super.init(path: path, openName: path, flags: flags, setup: setup)
	}

	public init?(url: URL, key: String, flags: OpenFlags = .rwCreate, cipherOptions: CipherOptions = .unspecified, setupOptions: SetupOptions = .none) {
		guard url.isFileURL else {
			return nil
		}
		let setup = setupOptions.setupOptions + SQLCipher.keyingOption(key: key) + cipherOptions.setupOptions
		super.init(path: url.path, openName: url.absoluteString, flags: [flags, .uri], setup: setup)
	}

	public init?(path: String, key: Foundation.Data, flags: OpenFlags = .rwCreate, cipherOptions: CipherOptions = .unspecified, setupOptions: SetupOptions = .none) {
		let setup = setupOptions.setupOptions + SQLCipher.keyingOption(key: key) + cipherOptions.setupOptions
		super.init(path: path, openName: path, flags: flags, setup: setup)
	}

	public init?(url: URL, key: Foundation.Data, flags: OpenFlags = .rwCreate, cipherOptions: CipherOptions = .unspecified, setupOptions: SetupOptions = .none) {
		guard url.isFileURL else {
			return nil
		}
		let setup = setupOptions.setupOptions + SQLCipher.keyingOption(key: key) + cipherOptions.setupOptions
		super.init(path: url.path, openName: url.absoluteString, flags: [flags, .uri], setup: setup)
	}

	public func rekey(_ new: String) throws {
		try execute("PRAGMA rekey = \(new.sqliteEscaped)")
	}

	public func rekey(_ new: Foundation.Data) throws {
		try execute("PRAGMA rekey = \"\(new.sqliteEscaped)\"")
	}
}
