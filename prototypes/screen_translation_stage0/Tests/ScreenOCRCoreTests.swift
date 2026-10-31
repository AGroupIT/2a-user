import Foundation

@main
struct ScreenOCRCoreTests {
  static func main() {
    let revisions = OCRRevisionGate()
    precondition(!revisions.isCurrent(0))
    let frameA = revisions.advance()
    precondition(revisions.isCurrent(frameA))
    let frameB = revisions.advance()
    precondition(frameB > frameA && !revisions.isCurrent(frameA) && revisions.isCurrent(frameB))
    DispatchQueue.concurrentPerform(iterations: 1000) { _ in precondition(!revisions.isCurrent(frameA)) }
    revisions.stop()
    let afterStop = revisions.advance()
    precondition(!revisions.isCurrent(frameB) && !revisions.isCurrent(afterStop))
    let newSession = OCRRevisionGate()
    let newFrame = newSession.advance()
    precondition(newSession.isCurrent(newFrame))
    // Different sessions may reuse the same numeric revision; owner identity matters.
    precondition(!revisions.isCurrent(newFrame))
    DispatchQueue.concurrentPerform(iterations: 1000) { _ in precondition(!revisions.isCurrent(frameB)) }
    func near(_ actual: Double, _ expected: Double) { precondition(abs(actual - expected) < 0.000_001, "\(actual) != \(expected)") }
    func box(_ actual: OCRBox, _ expected: [Double]) {
      for (a, b) in zip([actual.x, actual.y, actual.width, actual.height], expected) { near(a, b) }
    }
    let pages = SnapshotViewportPages(width: 720, height: 1280)
    precondition(pages.boxes.count == 4)
    near(pages.boxes[0].height * 1280, 405)
    near(pages.boxes[0].y, 0)
    near(pages.boxes.last!.y + pages.boxes.last!.height, 1)
    for (previous, next) in zip(pages.boxes, pages.boxes.dropFirst()) {
      precondition(next.y > previous.y && next.y <= previous.y + previous.height)
      precondition(previous.y + previous.height - next.y >= previous.height * 0.2 - 0.000001)
      near(next.x, 0); near(next.width, 1)
    }
    near(pages.duration, 60)
    for (time, index) in [(0.0, 0), (14.999, 0), (15, 1), (30, 2), (45, 3), (60, 3), (-15, 0)] {
      precondition(pages.pageIndex(atSeconds: time) == index)
    }
    precondition(pages.pageIndex(atSeconds: .nan) == 0)
    precondition(pages.pageIndex(atSeconds: .infinity) == 3)
    precondition(pages.pageIndex(atSeconds: -.infinity) == 0)
    near(pages.clampedSkip(current: 10, interval: 15), 25)
    near(pages.clampedSkip(current: 25, interval: -15), 10)
    near(pages.clampedSkip(current: 10, interval: -100), 0)
    precondition(pages.clampedSkip(current: 50, interval: 15) < pages.duration)
    precondition(pages.pageIndex(atSeconds: pages.clampedSkip(current: 50, interval: 15)) == 3)
    near(pages.clampedSkip(current: .nan, interval: 15), 15)
    near(pages.clampedSkip(current: 10, interval: .nan), 10)
    precondition(pages.clampedSkip(current: 10, interval: .infinity) < pages.duration)
    near(pages.clampedSkip(current: 10, interval: -.infinity), 0)
    for plan in [SnapshotViewportPages(width: 1280, height: 720), SnapshotViewportPages(width: 1920, height: 720)] {
      precondition(plan.boxes == [OCRBox(x: 0, y: 0, width: 1, height: 1)])
      near(plan.duration, 15)
    }
    for plan in [SnapshotViewportPages(width: 0, height: 1280), SnapshotViewportPages(width: -720, height: 1280),
                 SnapshotViewportPages(width: .nan, height: 1280), SnapshotViewportPages(width: 720, height: .infinity),
                 SnapshotViewportPages(width: 720, height: 1280, aspect: 0),
                 SnapshotViewportPages(width: 720, height: 1280, overlap: 1),
                 SnapshotViewportPages(width: 720, height: 1280, cap: 0),
                 SnapshotViewportPages(width: 720, height: 1280, cap: 3),
                 SnapshotViewportPages(width: 1, height: 1000000, cap: 100)] {
      precondition(plan.boxes.isEmpty && plan.duration == 0)
      precondition(plan.pageIndex(atSeconds: 0) == nil)
      near(plan.clampedSkip(current: 10, interval: 15), 0)
    }
    box(OCRBox.fromVision(x: 0.1, y: 0.2, width: 0.3, height: 0.1), [0.1, 0.7, 0.3, 0.1])
    box(OCRBox.fromVision(x: -0.1, y: 0.8, width: 0.4, height: 0.4), [0, 0, 0.3, 0.2])
    box(OCRBox.fromVision(x: 0.9, y: -0.2, width: 0.4, height: 0.4), [0.9, 0.8, 0.1, 0.2])
    box(OCRBox.fromVision(x: 0.2, y: 0.25, width: 0.5, height: 0.2,
      imageRegion: (x: 0.1, y: 0.5, width: 0.8, height: 0.4)), [0.26, 0.32, 0.4, 0.08])
    // Native Vision TOPROW fixture: upper-half ROI maps back to full-image bbox.
    box(OCRBox.fromVision(x: 0.095, y: 0.4866666666666667, width: 0.3325, height: 0.1666666666666667,
      imageRegion: (x: 0, y: 0.5, width: 1, height: 0.5)), [0.095, 0.1733333333333333, 0.3325, 0.0833333333333333])
    let source = OCRBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    let expected: [[Double]] = [
      [0.1, 0.2, 0.3, 0.4], [0.6, 0.2, 0.3, 0.4],
      [0.6, 0.4, 0.3, 0.4], [0.1, 0.4, 0.3, 0.4],
      [0.2, 0.1, 0.4, 0.3], [0.4, 0.1, 0.4, 0.3],
      [0.4, 0.6, 0.4, 0.3], [0.2, 0.6, 0.4, 0.3]]
    let corners = [OCRBox(x: 0, y: 0, width: 0.1, height: 0.2),
                   OCRBox(x: 0.9, y: 0, width: 0.1, height: 0.2),
                   OCRBox(x: 0, y: 0.8, width: 0.1, height: 0.2),
                   OCRBox(x: 0.9, y: 0.8, width: 0.1, height: 0.2)]
    let positions: [[[Double]]] = [
      [[0, 0], [0.9, 0], [0, 0.8], [0.9, 0.8]],
      [[0.9, 0], [0, 0], [0.9, 0.8], [0, 0.8]],
      [[0.9, 0.8], [0, 0.8], [0.9, 0], [0, 0]],
      [[0, 0.8], [0.9, 0.8], [0, 0], [0.9, 0]],
      [[0, 0], [0, 0.9], [0.8, 0], [0.8, 0.9]],
      [[0.8, 0], [0.8, 0.9], [0, 0], [0, 0.9]],
      [[0.8, 0.9], [0.8, 0], [0, 0.9], [0, 0]],
      [[0, 0.9], [0, 0], [0.8, 0.9], [0.8, 0]]]
    for value in 1...8 {
      let orientation = OCROrientation(rawValue: value)!
      precondition(orientation.rawValue == value)
      box(orientation.orient(source), expected[value - 1])
      for (index, corner) in corners.enumerated() {
        let size: [Double] = value < 5 ? [0.1, 0.2] : [0.2, 0.1]
        box(orientation.orient(corner), positions[value - 1][index] + size)
      }
    }
    precondition(OCRText.normalize("\n 不含电池\t 尺寸：30 × 20 cm　¥１２３.50 \r\n 不是纯棉 ") == "不含电池 尺寸：30 × 20 cm ¥１２３.50 不是纯棉")
    precondition(OCRText.normalize("Cafe\u{301}\u{00a0}  2\u{202f}kg") == "Café 2 kg")
    precondition(OCRText.normalize("\t\n　") == "")
    func block(_ id: String, _ x: Double, _ y: Double) -> OCRBlock {
      OCRBlock(id: id, text: id, box: OCRBox(x: x, y: y, width: 0.1, height: 0.04), confidence: 0.9)
    }
    let layout = [block("right-price", 0.6, 0.1), block("left-label", 0.1, 0.105),
                  block("next-row", 0.05, 0.16), block("below", 0.1, 0.3)]
    let order = ["left-label", "right-price", "next-row", "below"]
    precondition(OCRText.readingOrder(layout).map(\.id) == order)
    precondition(OCRText.readingOrder(Array(layout.reversed())).map(\.id) == order)
    let chain = [block("A", 0.7, 0.10), block("B", 0.3, 0.115), block("C", 0.1, 0.13)]
    precondition(OCRText.readingOrder(chain).map(\.id) == ["B", "A", "C"])
    for input in [chain, Array(chain.reversed()), [chain[1], chain[2], chain[0]]] {
      precondition(OCRText.readingOrder(input).map(\.id) == ["B", "A", "C"])
    }
    precondition(OCRText.readingOrder([]).isEmpty)
    func fingerprint(_ value: UInt8) -> ScreenFingerprint { ScreenFingerprint(samples: [UInt8](repeating: value, count: 16)) }
    near(fingerprint(0).distance(to: fingerprint(255)), 1)
    near(fingerprint(40).distance(to: fingerprint(45)), 5 / 255)
    near(ScreenFingerprint(samples: [0, 255]).distance(to: ScreenFingerprint(samples: [255, 255])), 0.5)
    precondition(fingerprint(0).distance(to: ScreenFingerprint(samples: [0])) == 1)
    precondition(ScreenFingerprint(samples: []).distance(to: ScreenFingerprint(samples: [])) == 0)
    let priceScreen = [UInt8](repeating: 80, count: 96 * 160)
    var changedPrice = priceScreen
    changedPrice[7_111] = 160
    let originalPrice = ScreenFingerprint(samples: priceScreen)
    let updatedPrice = ScreenFingerprint(samples: changedPrice)
    precondition(originalPrice.distance(to: updatedPrice) < 0.012)
    precondition(originalPrice.hasLocalizedChange(to: updatedPrice))
    precondition(updatedPrice.hasLocalizedChange(to: originalPrice))
    precondition(!originalPrice.hasLocalizedChange(to: ScreenFingerprint(samples: [UInt8](repeating: 100, count: 96 * 160))))
    precondition(!originalPrice.hasLocalizedChange(to: originalPrice))
    precondition(originalPrice.hasLocalizedChange(to: ScreenFingerprint(samples: [80])))
    precondition(!ScreenFingerprint(samples: []).hasLocalizedChange(to: ScreenFingerprint(samples: [])))
    precondition(!fingerprint(0).hasLocalizedChange(to: fingerprint(255), threshold: 2))
    precondition(fingerprint(80).hasLocalizedChange(to: fingerprint(81), threshold: -1))
    precondition(originalPrice.hasLocalizedChange(to: updatedPrice, threshold: .nan))
    let grid = ScreenFingerprint(samples: [UInt8](repeating: 80, count: 12))
    var gridChange = [UInt8](repeating: 80, count: 12)
    gridChange[5] = 180; gridChange[10] = 180
    let changedGrid = ScreenFingerprint(samples: gridChange)
    precondition(grid.changedBounds(to: changedGrid, columns: 4, rows: 3) ==
      OCRBox(x: 0.25, y: 1.0 / 3, width: 0.5, height: 2.0 / 3))
    precondition(grid.changedBounds(to: grid, columns: 4, rows: 3) == nil)
    precondition(grid.changedBounds(to: changedGrid, columns: 4, rows: 3, threshold: 2) == nil)
    precondition(grid.changedBounds(to: changedGrid, columns: 4, rows: 3, threshold: .nan) != nil)
    let fullGrid = OCRBox(x: 0, y: 0, width: 1, height: 1)
    precondition(grid.changedBounds(to: changedGrid, columns: 0, rows: 3) == fullGrid)
    precondition(grid.changedBounds(to: changedGrid, columns: Int.max, rows: 3) == fullGrid)
    precondition(grid.changedBounds(to: fingerprint(80), columns: 4, rows: 3) == fullGrid)
    let baseArea = ScreenFingerprint(samples: Array(repeating: 80, count: 100))
    var bannerPixels = Array(repeating: UInt8(80), count: 100)
    for index in 0..<10 { bannerPixels[index] = 220 }
    let bannerA = ScreenFingerprint(samples: bannerPixels)
    near(baseArea.changedFraction(to: bannerA), 0.1)
    var animationGate = ScreenStability(settleSeconds: 0.4, changedAreaThreshold: 0.15)
    precondition(!animationGate.observe(baseArea, now: 0))
    precondition(!animationGate.observe(bannerA, now: 0.2))
    precondition(animationGate.observe(baseArea, now: 0.41))
    precondition(!animationGate.observe(bannerA, now: 1))
    var pagePixels = Array(repeating: UInt8(80), count: 100)
    for index in 0..<30 { pagePixels[index] = 220 }
    let page = ScreenFingerprint(samples: pagePixels)
    near(baseArea.changedFraction(to: page), 0.3)
    precondition(!animationGate.observe(page, now: 2))
    precondition(animationGate.observe(page, now: 2.41))
    precondition(!animationGate.observe(page, now: 3))
    var stability = ScreenStability()
    precondition(!stability.observe(fingerprint(100), now: 0))
    precondition(!stability.observe(fingerprint(102), now: 0.2))
    precondition(stability.observe(fingerprint(100), now: 0.41))
    precondition(!stability.observe(fingerprint(103), now: 1))
    precondition(!stability.observe(fingerprint(100), now: 20))
    precondition(!stability.observe(fingerprint(200), now: 21))
    precondition(!stability.observe(fingerprint(201), now: 21.2))
    precondition(stability.observe(fingerprint(200), now: 21.41))
    precondition(!stability.observe(fingerprint(200), now: 22))
    // A brief animation returning to the same delivered screen is not another result.
    precondition(!stability.observe(fingerprint(0), now: 23))
    precondition(!stability.observe(fingerprint(200), now: 23.1))
    precondition(!stability.observe(fingerprint(200), now: 24))
    stability.reset()
    precondition(!stability.observe(fingerprint(200), now: 30))
    precondition(stability.observe(fingerprint(200), now: 30.41))
    // Clock regression starts a new stability window; no elapsed-time shortcut.
    precondition(!stability.observe(fingerprint(200), now: 10))
    precondition(stability.observe(fingerprint(200), now: 10.41))
    var moving = ScreenStability()
    precondition(!moving.observe(fingerprint(0), now: 0))
    precondition(!moving.observe(fingerprint(100), now: 0.3))
    precondition(!moving.observe(fingerprint(200), now: 0.6))
    precondition(!moving.observe(fingerprint(200), now: 0.8))
    precondition(moving.observe(fingerprint(200), now: 1.01))
    print("PASS: revision stop/latest/session/concurrent guards; Vision clipping; all 8 EXIF non-square/corner transforms; NFC/whitespace fidelity; deterministic anchored reading rows; grayscale distance and sparse glyph change; settle/jitter/change/reset/clock semantics")
  }
}
