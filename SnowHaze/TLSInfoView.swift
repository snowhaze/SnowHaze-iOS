//
//  TLSInfoView.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class TLSInfoView: PageInfoDetailsList {
	init(sec: ServerTrust) {
		super.init(frame: .zero)
		var data = [PageInfoDetailsList.Entry]()
		if let org = sec.evOrganization {
			let evOrg = NSLocalizedString("page information tls details ev organization field title", comment: "title of the ev organization field for the tls information in the page information view")
			data.append(.data(evOrg, org))
		}
		if let transparency = sec.transparency {
			let certTransparency = NSLocalizedString("page information tls details transparency field title", comment: "title of the certificate transparency field for the tls information in the page information view")
			let yes = NSLocalizedString("page information tls details transparency true value", comment: "true value of the certificate transparency field for the tls information in the page information view")
			let no = NSLocalizedString("page information tls details transparency false value", comment: "false value of the certificate transparency field for the tls information in the page information view")
			data.append(.data(certTransparency, transparency ? yes : no))
		}
		if let date = sec.revocationValidUntil {
			let checkExpiry = NSLocalizedString("page information tls details revocation check expiration field title", comment: "title of the revocation check expiration field for the tls information in the page information view")
			data.append(.data(checkExpiry, format(date)))
		}
		if let date = sec.evaluationDate {
			let evaluation = NSLocalizedString("page information tls details evaluation date field title", comment: "title of the evaluation date field for the tls information in the page information view")
			data.append(.data(evaluation, format(date)))
		}
		for (i, cert) in sec.certificates.enumerated() {
			guard let cert = cert else {
				continue
			}
			let certFormat = NSLocalizedString("page information tls details certificate title format", comment: "format for the title for the certificate section for the tls information in the page information view")
			data.append(.title(String(format: certFormat, i + 1)))
			if let nr = cert.serialNumber {
				let serial = NSLocalizedString("page information tls details cert serial number field title", comment: "title of the certificate serial number for the tls information in the page information view")
				data.append(.data(serial, nr.hex))
			}
			if let name = cert.commonName {
				let cn = NSLocalizedString("page information tls details cert common name field title", comment: "title of the certificate common name for the tls information in the page information view")
				data.append(.data(cn, name))
			}
			if let der = cert.der, let parsed = Cert(der: der) {
				let notBefore = NSLocalizedString("page information tls details cert not valid before field title", comment: "title of the certificate not valid before for the tls information in the page information view")
				let notAfter = NSLocalizedString("page information tls details cert not valid after field title", comment: "title of the certificate not valid after for the tls information in the page information view")
				data.append(.data(notBefore, format(parsed.notValidBefore)))
				data.append(.data(notAfter, format(parsed.notValidAfter)))
			}
			if let key = cert.key {
				if let type = key.type, let size = key.effectiveSize {
					let typeName: String
					switch type {
						case .rsa:		typeName = NSLocalizedString("page information tls details cert rsa key type", comment: "rsa type for the certificate key type for the tls information in the page information view")
						case .ec:		typeName = NSLocalizedString("page information tls details cert ec key type", comment: "elliptic curve type for the certificate key type for the tls information in the page information view")
						case .other:	typeName = NSLocalizedString("page information tls details cert unknown key type", comment: "unknown type for the certificate key type for the tls information in the page information view")
					}
					let keyType = NSLocalizedString("page information tls details cert key type field title", comment: "title of the certificate key type for the tls information in the page information view")
					data.append(.data(keyType, "\(typeName)/\(size)"))
				}
				if let uses = key.uses {
					let keyUses = NSLocalizedString("page information tls details cert key uses field title", comment: "title of the certificate key usages for the tls information in the page information view")
					let names: [(ServerCert.Key.Uses, String)] = [
						(.encrypt, NSLocalizedString("page information tls details cert encrypt key usage", comment: "encrypt usage for the certificate key usages for the tls information in the page information view")),
						(.decrypt, NSLocalizedString("page information tls details cert decrypt key usage", comment: "decrypt usage for the certificate key usages for the tls information in the page information view")),
						(.derive, NSLocalizedString("page information tls details cert derive key usage", comment: "derive usage for the certificate key usages for the tls information in the page information view")),
						(.sign, NSLocalizedString("page information tls details cert sign key usage", comment: "sign usage for the certificate key usages for the tls information in the page information view")),
						(.verify, NSLocalizedString("page information tls details cert verify key usage", comment: "verify usage for the certificate key usages for the tls information in the page information view")),
						(.wrap, NSLocalizedString("page information tls details cert wrap key usage", comment: "wrap usage for the certificate key usages for the tls information in the page information view")),
						(.unwrap, NSLocalizedString("page information tls details cert unwrap key usage", comment: "unwrap usage for the certificate key usages for the tls information in the page information view")),
					]
					let usesNames = names.compactMap { (use, name) in
						return uses.contains(use) ? name : nil
					}
					data.append(.data(keyUses, usesNames.joined(separator: ", ")))
				}
				if let hash = key.sha256 {
					let keyHash = NSLocalizedString("page information tls details cert key sha256 field title", comment: "title of the certificate key sha256 for the tls information in the page information view")
					data.append(.data(keyHash, hash))
				}
			}
			let sha256 = NSLocalizedString("page information tls details cert sha256 field title", comment: "title of the certificate sha256 for the tls information in the page information view")
			data.append(.data(sha256, cert.sha256))
		}
		set(state: .data(data), animated: false)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
