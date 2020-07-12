//
//  Pinger.swift
//  SnowHaze
//
//
//  Copyright © 2017 Illotros GmbH. All rights reserved.
//

import Foundation

class Pinger: NSObject, SimplePingDelegate {
	let hostName: String
	private(set) var hostAddress: String?

	private let pinger: SimplePing
	private let callback: (Pinger, TimeInterval?, Error?) -> Void

	private let queue = DispatchQueue(label: "ch.illotros.snowhaze.pinger")

	private var state: State = .unresolved

	var weight = 0.02

	private(set) var averagePing: TimeInterval?
	private(set) var averageDropRate: Double?

	private enum State {
		case unresolved
		case resolving(Bool) // save if there is a pending start
		case resolved(Timer?)
		case failed
	}

	private var lastSent: UInt16? = nil
	private var lastReport: UInt16? = nil
	private var sentDates = [Date?](repeating: nil, count: 120)

	init(host: String, callback: @escaping (Pinger, TimeInterval?, Error?) -> Void) {
		hostName = host
		pinger = SimplePing(hostName: host)
		self.callback = callback
		super.init()
		pinger.delegate = self
	}

	func resolve() {
		queue.sync {
			internalResolve()
		}
	}

	private func internalResolve() {
		guard case .unresolved = state else {
			return
		}
		pinger.start()
		state = .resolving(false)
	}

	func start() {
		queue.sync {
			switch state {
				case .unresolved:
					internalResolve()
					if case .resolving(false) = state {
						state = .resolving(true)
					}
				case .resolving(false):
					state = .resolving(true)
				case .resolved(nil):
					startTimer()
				default:
					break
			}
		}
	}

	func stop() {
		queue.sync {
			switch state {
				case .resolving(true):
					state = .resolving(false)
				case .resolved(let opt):
					if let timer = opt {
						DispatchQueue.main.async {
							timer.invalidate()
						}
						state = .resolved(nil)
					}
				default:
					break
			}
		}
	}

	private func notify(time: TimeInterval?, error: Error?) {
		DispatchQueue.main.async {
			let weight = self.weight
			if let newTime = time {
				if let average = self.averagePing {
					self.averagePing = average * (1 - weight) + newTime * weight
				} else {
					self.averagePing = newTime
				}
				if let average = self.averageDropRate {
					self.averageDropRate = average * (1 - weight)
				} else {
					self.averageDropRate = 0
				}
			} else if let _ = error {
				if let average = self.averageDropRate {
					self.averageDropRate = average * (1 - weight)  + weight
				} else {
					self.averageDropRate = 1
				}
			}
			self.callback(self, time, error)
		}
	}

	private func startTimer() {
		let timer = DispatchQueue.main.sync {
			Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerFired(_:)), userInfo: nil, repeats: true)
		}
		timerFired(timer)
		state = .resolved(timer)
	}

	/// For internal use only
	@objc private func timerFired(_ timer: Timer) {
		queue.async { [weak self] in
			if let _ = self?.pinger.hostAddress {
				self?.pinger.send(with: nil)
			}
		}
	}

	func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
		queue.async { [weak self] in
			guard let self = self else {
				return
			}
			var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST))

			let success = getnameinfo(
				(address as NSData).bytes.bindMemory(to: sockaddr.self, capacity: address.count),
				socklen_t(address.count),
				&hostStr,
				socklen_t(hostStr.count),
				nil,
				0,
				NI_NUMERICHOST
				) == 0
			if success {
				self.hostAddress = String(cString: hostStr)
			} else {
				self.hostAddress = "?"
			}

			switch self.state {
				case .unresolved, .resolving(false), .failed:
					self.state = .resolved(nil)
				case .resolving(true):
					self.startTimer()
				default:
					break
			}
		}
	}

	func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
		queue.async { [weak self] in
			guard let self = self else {
				return
			}
			if case .resolved(let arg) = self.state, let timer = arg {
				DispatchQueue.main.async {
					timer.invalidate()
				}
			}
			self.state = .failed
			self.notify(time: nil, error: error)
		}
	}

	func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) { }

	func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
		queue.async { [weak self] in
			guard let self = self else {
				return
			}
			self.sentDates.append(Date())
			self.sentDates.removeFirst()
			self.lastSent = sequenceNumber
			if self.diff(sequenceNumber, self.lastReport ?? 0) > 120 {
				self.notify(time: nil, error: NSError(domain: "PingErrorDomain", code: -1, userInfo: nil))
			}
		}
	}

	private func diff(_ a: UInt16, _ b: UInt16) -> UInt16 {
		if a == b {
			return 0
		} else if b < a {
			return a - b
		} else {
			return a + (UInt16.max - b) + 1
		}
	}

	private func index(of seq: UInt16) -> Int? {
		guard let lastSent = self.lastSent else {
			return nil
		}
		let distance = diff(lastSent, seq)
		return distance < 120 ? 120 - 1 - Int(distance) : nil
	}

	private func updateReport(seq: UInt16) {
		if lastReport == nil || diff(lastReport!, seq) > 10000 {
			lastReport = seq
		}
	}

	func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
		queue.async { [weak self] in
			if let self = self, let index = self.index(of: sequenceNumber) {
				self.updateReport(seq: sequenceNumber)
				if let sent = self.sentDates[index] {
					self.notify(time: -sent.timeIntervalSinceNow, error: nil)
				}
			}
		}
	}

	func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data?, sequenceNumber: UInt16, error: Error) {
		queue.async { [weak self] in
			if let self = self {
				self.updateReport(seq: sequenceNumber)
				self.notify(time: nil, error: error)
			}
		}
	}
}
