import Foundation

/// Revision IDs belong to this session instance; a stopped gate never revives.
/// Callers must keep the gate with its session, not compare IDs across sessions.
final class OCRRevisionGate {
  private let lock = NSLock()
  private var revision: UInt64 = 0
  private var stopped = false

  init() {}

  func advance() -> UInt64 {
    lock.lock(); defer { lock.unlock() }
    guard !stopped else { return revision }
    guard revision < UInt64.max else { stopped = true; return revision }
    revision += 1
    return revision
  }

  func isCurrent(_ id: UInt64) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return !stopped && id != 0 && id == revision
  }

  func stop() {
    lock.lock(); defer { lock.unlock() }
    stopped = true
  }
}

/// Normalized coordinates in an already oriented image, origin at top left.
struct OCRBox: Equatable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double

  /// Vision observations are ROI-relative in the checked native runtime.
  /// Map the lower-left ROI into the oriented full image, then flip Y once.
  static func fromVision(x: Double, y: Double, width: Double, height: Double,
                         imageRegion: (x: Double, y: Double, width: Double, height: Double) = (0, 0, 1, 1)) -> OCRBox {
    let h = height.isFinite ? max(0, height) : 0
    let fullX = imageRegion.x + x * imageRegion.width
    let fullY = imageRegion.y + y * imageRegion.height
    let fullH = h * imageRegion.height
    return clipped(x: fullX, y: 1 - fullY - fullH,
                   width: width * imageRegion.width, height: fullH)
  }

  fileprivate static func clipped(x: Double, y: Double, width: Double, height: Double) -> OCRBox {
    func unit(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
    let finiteX = x.isFinite ? x : 0
    let finiteY = y.isFinite ? y : 0
    let w = width.isFinite ? max(0, width) : 0
    let h = height.isFinite ? max(0, height) : 0
    let left = unit(finiteX), top = unit(finiteY)
    return OCRBox(x: left, y: top,
                  width: max(0, unit(finiteX + w) - left),
                  height: max(0, unit(finiteY + h) - top))
  }
}

/// EXIF values match CGImagePropertyOrientation without depending on Apple UI APIs.
enum OCROrientation: Int {
  case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left

  /// Input is a raw-image top-left box; output is in oriented image coordinates.
  /// Vision boxes already produced using an orientation must not be rotated again.
  func orient(_ box: OCRBox) -> OCRBox {
    let b = OCRBox.clipped(x: box.x, y: box.y, width: box.width, height: box.height)
    let points = [(b.x, b.y), (b.x + b.width, b.y),
                  (b.x, b.y + b.height), (b.x + b.width, b.y + b.height)]
    let transformed: [(Double, Double)] = points.map { x, y in
      switch self {
      case .up: return (x, y)
      case .upMirrored: return (1 - x, y)
      case .down: return (1 - x, 1 - y)
      case .downMirrored: return (x, 1 - y)
      case .leftMirrored: return (y, x)
      case .right: return (1 - y, x)
      case .rightMirrored: return (1 - y, 1 - x)
      case .left: return (y, 1 - x)
      }
    }
    let xs = transformed.map(\.0), ys = transformed.map(\.1)
    let left = xs.min()!, top = ys.min()!
    return OCRBox.clipped(x: left, y: top, width: xs.max()! - left, height: ys.max()! - top)
  }
}

struct OCRBlock: Equatable {
  let id: String
  let text: String
  let box: OCRBox
  let confidence: Float
}

enum OCRText {
  /// NFC and whitespace only. Numbers, punctuation, units and negations are data.
  static func normalize(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  /// Initial horizontal-reading policy: top-to-bottom anchored rows, then left-to-right.
  /// Row tolerance is half the smaller line height. The row anchor is immutable;
  /// fuzzy comparisons are never used as a sort comparator or chained across rows.
  /// This is not a paragraph/table/vertical-writing layout reconstruction algorithm.
  static func readingOrder(_ blocks: [OCRBlock]) -> [OCRBlock] {
    func geometry(_ b: OCRBlock) -> OCRBox {
      OCRBox.clipped(x: b.box.x, y: b.box.y, width: b.box.width, height: b.box.height)
    }
    func tie(_ a: OCRBlock, _ b: OCRBlock) -> Bool {
      if a.id != b.id { return a.id < b.id }
      if a.text != b.text { return a.text < b.text }
      return a.confidence.bitPattern < b.confidence.bitPattern
    }
    let sorted = blocks.sorted { a, b in
      let p = geometry(a), q = geometry(b)
      if p.y != q.y { return p.y < q.y }
      if p.x != q.x { return p.x < q.x }
      if p.height != q.height { return p.height < q.height }
      if p.width != q.width { return p.width < q.width }
      return tie(a, b)
    }
    var rows: [[OCRBlock]] = []
    for block in sorted {
      if let anchor = rows.last?.first {
        let a = geometry(anchor), b = geometry(block)
        if b.y - a.y <= 0.5 * min(a.height, b.height) {
          rows[rows.count - 1].append(block)
          continue
        }
      }
      rows.append([block])
    }
    return rows.flatMap { row in
      row.sorted { a, b in
        let p = geometry(a), q = geometry(b)
        if p.x != q.x { return p.x < q.x }
        if p.y != q.y { return p.y < q.y }
        if p.width != q.width { return p.width < q.width }
        if p.height != q.height { return p.height < q.height }
        return tie(a, b)
      }
    }
  }
}

struct ScreenFingerprint: Equatable {
  private let samples: [UInt8]

  init(samples: [UInt8]) { self.samples = samples }

  /// Detects a changed sampled glyph even when global mean difference is small.
  /// The caller still owns sampling/grid alignment; this cannot detect unsampled pixels.
  func hasLocalizedChange(to other: ScreenFingerprint, threshold: Double = 0.08) -> Bool {
    guard samples.count == other.samples.count else { return true }
    let limit = threshold.isFinite ? min(1, max(0, threshold)) : 0.08
    return zip(samples, other.samples).contains {
      Double(abs(Int($0.0) - Int($0.1))) / 255 > limit
    }
  }

  /// Fraction of sampled cells with a visible change; independent of brightness magnitude.
  func changedFraction(to other: ScreenFingerprint, threshold: Double = 0.08) -> Double {
    guard samples.count == other.samples.count else { return 1 }
    guard !samples.isEmpty else { return 0 }
    let limit = threshold.isFinite ? min(1, max(0, threshold)) : 0.08
    let count = zip(samples, other.samples).filter {
      Double(abs(Int($0.0) - Int($0.1))) / 255 > limit
    }.count
    return Double(count) / Double(samples.count)
  }

  /// Bounding rectangle of changed grid cells, in normalized top-left coordinates.
  /// Invalid geometry/counts conservatively invalidate the full screen.
  func changedBounds(to other: ScreenFingerprint, columns: Int, rows: Int,
                     threshold: Double = 0.08) -> OCRBox? {
    let full = OCRBox(x: 0, y: 0, width: 1, height: 1)
    guard columns > 0, rows > 0, columns <= Int.max / rows,
          samples.count == columns * rows, other.samples.count == samples.count else { return full }
    let limit = threshold.isFinite ? min(1, max(0, threshold)) : 0.08
    var minX = columns, minY = rows, maxX = -1, maxY = -1
    for index in samples.indices {
      guard Double(abs(Int(samples[index]) - Int(other.samples[index]))) / 255 > limit else { continue }
      let x = index % columns, y = index / columns
      minX = min(minX, x); minY = min(minY, y)
      maxX = max(maxX, x); maxY = max(maxY, y)
    }
    guard maxX >= 0 else { return nil }
    return OCRBox(x: Double(minX) / Double(columns), y: Double(minY) / Double(rows),
      width: Double(maxX - minX + 1) / Double(columns), height: Double(maxY - minY + 1) / Double(rows))
  }

  /// Mean absolute grayscale-grid difference, normalized to 0...1.
  /// Caller must use the same grid geometry/orientation, not merely equal byte counts.
  func distance(to other: ScreenFingerprint) -> Double {
    guard samples.count == other.samples.count else { return 1 }
    guard !samples.isEmpty else { return 0 }
    let difference = zip(samples, other.samples).reduce(0.0) {
      $0 + Double(abs(Int($1.0) - Int($1.1)))
    }
    return difference / (Double(samples.count) * 255)
  }
}

/// Simple global-frame stability experiment. No banner/tile motion exclusion is claimed.
/// Storage is bounded to one candidate and one last-emitted fingerprint.
struct ScreenStability {
  private let threshold: Double
  private let settleSeconds: TimeInterval
  private let changedAreaThreshold: Double?
  private var candidate: ScreenFingerprint?
  private var emitted: ScreenFingerprint?
  private var stableSince: TimeInterval?
  private var lastTime: TimeInterval?

  init(threshold: Double = 0.025, settleSeconds: Double = 0.4, changedAreaThreshold: Double? = nil) {
    self.changedAreaThreshold = changedAreaThreshold.map { $0.isFinite ? min(1, max(0, $0)) : 0.15 }
    self.threshold = threshold.isFinite ? min(1, max(0, threshold)) : 0.025
    self.settleSeconds = settleSeconds.isFinite ? max(0, settleSeconds) : 0.4
  }

  /// Emits once after a changed candidate settles. Small jitter does not reset its timer.
  /// Returning to an already emitted screen after a brief transient does not emit again.
  mutating func observe(_ fingerprint: ScreenFingerprint, now: TimeInterval) -> Bool {
    guard now.isFinite else { reset(); return false }
    if let lastTime, now < lastTime { reset() }
    lastTime = now
    func differs(_ a: ScreenFingerprint, _ b: ScreenFingerprint) -> Bool {
      if let area = changedAreaThreshold { return a.changedFraction(to: b) >= area }
      return a.distance(to: b) > threshold
    }
    if candidate == nil || differs(candidate!, fingerprint) {
      candidate = fingerprint
      stableSince = now
    }
    guard let candidate, let stableSince, now - stableSince >= settleSeconds else { return false }
    if let emitted, !differs(emitted, candidate) { return false }
    emitted = fingerprint
    self.candidate = fingerprint
    return true
  }

  mutating func reset() {
    candidate = nil
    emitted = nil
    stableSince = nil
    lastTime = nil
  }
}

/// An edge-anchored strip with the same 16:9 aspect as the PiP output.
struct ScreenTranslationViewport {
  let pipAtTop: Bool
  func box(width: Double, height: Double) -> OCRBox {
    guard width.isFinite, height.isFinite, width > 0, height > 0 else {
      return OCRBox(x: 0, y: 0, width: 1, height: 1)
    }
    let fraction = min(1, width * 9 / 16 / height)
    return OCRBox(x: 0, y: pipAtTop ? 1 - fraction : 0, width: 1, height: fraction)
  }
}

/// Full-width strips of an already oriented snapshot; normalized origin is top left.
/// Invalid geometry/configuration or a snapshot requiring more than `cap` pages
/// yields an empty plan rather than silently leaving gaps. At most eight pages.
struct SnapshotViewportPages {
  let boxes: [OCRBox]
  static let secondsPerPage: Double = 15
  var duration: Double { Double(boxes.count) * Self.secondsPerPage }

  init(width: Double, height: Double, aspect: Double = 16.0 / 9.0,
       overlap: Double = 0.2, cap: Int = 8) {
    guard width.isFinite, height.isFinite, width > 0, height > 0,
          aspect.isFinite, aspect > 0, overlap.isFinite, overlap >= 0, overlap < 1,
          cap > 0 else { boxes = []; return }
    let stripHeight = min(1, (width / height) / aspect)
    let step = stripHeight * (1 - overlap)
    guard stripHeight > 0, step > 0 else { boxes = []; return }
    let intervals = ceil((1 - stripHeight) / step)
    guard intervals.isFinite, intervals < Double(min(8, cap)) else { boxes = []; return }
    let count = Int(intervals) + 1
    boxes = (0..<count).map { index in
      OCRBox(x: 0, y: min(Double(index) * step, 1 - stripHeight), width: 1, height: stripHeight)
    }
  }

  /// Each strip occupies [index * 15, (index + 1) * 15). Out-of-range times clamp.
  /// Empty plans return nil; NaN is treated as the start of the snapshot.
  func pageIndex(atSeconds seconds: Double) -> Int? {
    guard !boxes.isEmpty else { return nil }
    let time = clampedTime(seconds)
    return min(boxes.count - 1, Int(time / Self.secondsPerPage))
  }

  /// Relative seek for PiP controls, clamped to [0, duration - 0.000001].
  /// An invalid interval is ignored. Empty plans always return zero.
  func clampedSkip(current: Double, interval: Double) -> Double {
    let start = clampedTime(current)
    return clampedTime(start + (interval.isNaN ? 0 : interval))
  }

  private func clampedTime(_ seconds: Double) -> Double {
    guard duration > 0 else { return 0 }
    if seconds.isNaN { return 0 }
    return min(duration - 0.000001, max(0, seconds))
  }
}
