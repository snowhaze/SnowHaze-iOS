//
//  TorInfoView.swift
//  SnowHaze
//
//
//  Copyright © 2020 Illotros GmbH. All rights reserved.
//

import Foundation
import UIKit

class TorInfoView: PageInfoDetailsList {
	init(user: String, password: String, service: String?) {
		let service = (service?.isEmpty ?? true) ? nil : service
		super.init(frame: .zero)
		TorServer.shared.getCircuits { [weak self] circuits in
			guard let self = self else {
				return
			}
			guard let circuits = circuits else {
				let error = NSLocalizedString("page information tor details tor connection not established error", comment: "error message when the tor information in the page information cannot be displayed because the connection to the tor network has not been established")
				self.set(state: .error(error), animated: true)
				return
			}
			let filtered = circuits.filter { $0.user == user && $0.password == password && $0.rendezvousQuery == service }
			guard let index = (0 ..< filtered.count).randomElement() else {
				let error = NSLocalizedString("page information tor details circuit lookup failed error", comment: "error message when the tor information in the page information cannot be displayed because the curcuit lookup failed")
				self.set(state: .error(error), animated: true)
				return
			}

			let circuit = filtered[index]
			var data = [PageInfoDetailsList.Entry]()
			if filtered.count > 1 {
				let title = NSLocalizedString("page information tor details circuit selection field title", comment: "title of the circuit selection field for the tor information in the page information view")
				let fmt = NSLocalizedString("page information tor details circuit selection field format", comment: "format of the circuit selection field for the tor information in the page information view")
				data.append(.data(title, String(format: fmt, index, filtered.count)))
			}
			if let id = circuit.id {
				let title = NSLocalizedString("page information tor details circuit id field title", comment: "title of the circuit id field for the tor information in the page information view")
				data.append(.data(title, id))
			}
			if let status = circuit.status {
				let title = NSLocalizedString("page information tor details status field title", comment: "title of the status field for the tor information in the page information view")
				data.append(.data(title, status))
			}
			if let flags = circuit.buildFlags {
				let title = NSLocalizedString("page information tor details build flags field title", comment: "title of the build flags field for the tor information in the page information view")
				data.append(.data(title, flags.joined(separator: ", ")))
			}
			if let purpose = circuit.purpose {
				let title = NSLocalizedString("page information tor details purpose field title", comment: "title of the purpose field for the tor information in the page information view")
				data.append(.data(title, purpose))
			}
			if let state = circuit.hiddenServiceState {
				let title = NSLocalizedString("page information tor hidden service state purpose field title", comment: "title of the hidden service state field for the tor information in the page information view")
				data.append(.data(title, state))
			}
			if let query = circuit.rendezvousQuery {
				let title = NSLocalizedString("page information tor details rendezvous field title", comment: "title of the rendezvous field for the tor information in the page information view")
				data.append(.data(title, query))
			}
			if let date = circuit.created {
				let title = NSLocalizedString("page information tor created date purpose field title", comment: "title of the created date field for the tor information in the page information view")
				data.append(.data(title, self.format(date)))
			}
			if let reason = circuit.reason {
				let title = NSLocalizedString("page information tor details reason field title", comment: "title of the reason field for the tor information in the page information view")
				data.append(.data(title, reason))
			}
			if let reason = circuit.remoteReason {
				let title = NSLocalizedString("page information tor details remote reason field title", comment: "title of the remote reason field for the tor information in the page information view")
				data.append(.data(title, reason))
			}
			for (i, node) in (circuit.nodes ?? []).enumerated() {
				let nodeFormat = NSLocalizedString("page information tor details fallback node nickname format", comment: "format for the fallback for the tor node nickname for the tor information in the page information view")
				data.append(.title(node.nickname ?? String(format: nodeFormat, i + 1)))
				if let fp = node.fingerprint {
					let title = NSLocalizedString("page information tor details fingerprint field title", comment: "title of the node fingerprint field for the tor information in the page information view")
					data.append(.data(title, fp))
				}
				if let ip = node.IPv4 {
					let title = NSLocalizedString("page information tor details ipv4 field title", comment: "title of the node ipv4 field for the tor information in the page information view")
					data.append(.data(title, ip))
				}
				if let ip = node.IPv6 {
					let title = NSLocalizedString("page information tor details ipv6 field title", comment: "title of the node ipv6 field for the tor information in the page information view")
					data.append(.data(title, ip))
				}
				if let code = node.country, let country = Locale.current.localizedString(forRegionCode: code) {
					let title = NSLocalizedString("page information tor details country field title", comment: "title of the node country field for the tor information in the page information view")
					data.append(.data(title, country))
				}
			}
			self.set(state: .data(data), animated: true)
		}
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
