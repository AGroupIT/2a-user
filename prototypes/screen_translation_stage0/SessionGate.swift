import Foundation

/// Main-thread intent: the system picker must finish before auto PiP is armed.
struct AutomaticPiPIntent {
  private(set) var enabled = false
  var captureActive = false
  var ready = false
  private(set) var armed = false
  mutating func begin(enabled: Bool) { self = Self(); self.enabled = enabled }
  mutating func claimArm() -> Bool {
    guard enabled, captureActive, ready, !armed else { return false }
    armed = true
    return true
  }
  mutating func stop() { self = Self() }
}

/// No screen content, credentials, timers or persistent storage.
final class SessionGate {
  private let lock = NSLock()
  private var token: UUID?
  private var lastSample: TimeInterval?
  private var received: UInt64 = 0

  func begin() -> UUID {
    lock.lock(); defer { lock.unlock() }
    let value = UUID()
    token = value
    lastSample = nil
    received = 0
    return value
  }

  func stop() {
    lock.lock(); defer { lock.unlock() }
    token = nil
    lastSample = nil
  }

  func isCurrent(_ value: UUID) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return token == value
  }

  /// Counts all video callbacks; emits at most four diagnostic events/second.
  func sample(_ value: UUID, now: TimeInterval) -> UInt64? {
    lock.lock(); defer { lock.unlock() }
    guard token == value else { return nil }
    received += 1
    if let lastSample, now - lastSample < 0.25 { return nil }
    lastSample = now
    return received
  }
}

/// One queued delivery and one latest value, regardless of producer speed.
final class LatestMailbox<Value> {
  private let lock = NSLock()
  private var pending: Value?
  private var scheduled = false

  func offer(_ value: Value) -> Bool {
    lock.lock(); defer { lock.unlock() }
    pending = value
    guard !scheduled else { return false }
    scheduled = true
    return true
  }

  func take() -> Value? {
    lock.lock(); defer { lock.unlock() }
    let result = pending
    pending = nil
    scheduled = false
    return result
  }
}
