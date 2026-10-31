import Foundation

@main
struct SessionGateTests {
  static func main() {
    let gate = SessionGate()
    let first = gate.begin()
    precondition(gate.sample(first, now: 10) == 1)
    precondition(gate.sample(first, now: 10.1) == nil)
    precondition(gate.sample(first, now: 10.25) == 3)
    gate.stop()
    precondition(!gate.isCurrent(first))
    precondition(gate.sample(first, now: 100) == nil)
    let second = gate.begin()
    precondition(first != second)
    precondition(gate.sample(first, now: 101) == nil)
    precondition(gate.sample(second, now: 101) == 1)
    // stop A -> begin B -> late callback A must not stop/overwrite B.
    var callbackMutations = 0
    let latePiPCallback = { if gate.isCurrent(first) { callbackMutations += 1; gate.stop() } }
    latePiPCallback()
    precondition(callbackMutations == 0 && gate.isCurrent(second))
    let mailbox = LatestMailbox<Int>()
    precondition(mailbox.offer(1))
    for value in 2...100_000 { precondition(!mailbox.offer(value)) }
    precondition(mailbox.take() == 100_000)
    precondition(mailbox.take() == nil)
    precondition(mailbox.offer(100_001))
    precondition(mailbox.take() == 100_001)
    gate.stop()
    DispatchQueue.concurrentPerform(iterations: 1000) { _ in
      precondition(gate.sample(second, now: 500) == nil)
    }
    var automatic = AutomaticPiPIntent()
    automatic.begin(enabled: true)
    automatic.ready = true
    precondition(!automatic.claimArm(), "Picker must complete before automatic PiP")
    automatic.captureActive = true
    precondition(automatic.claimArm())
    precondition(!automatic.claimArm(), "Only one arm per session")
    automatic.stop()
    automatic.ready = true; automatic.captureActive = true
    precondition(!automatic.claimArm(), "Stop revokes automatic start")
    automatic.begin(enabled: true)
    automatic.captureActive = true
    precondition(!automatic.claimArm(), "Capture alone cannot arm a cold layer")
    automatic.ready = true
    precondition(automatic.claimArm())
    automatic.begin(enabled: false)
    automatic.ready = true; automatic.captureActive = true
    precondition(!automatic.claimArm(), "Manual QA remains manual")
    print("PASS: throttling; stop invalidation; restart isolation; latest-only mailbox; concurrent late callbacks")
  }
}
