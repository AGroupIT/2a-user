#if DEBUG || SCREEN_TRANSLATION_STAGE0 || SCREEN_TRANSLATION_LIVE
import Foundation
import Vision
import CoreImage
import ImageIO
import CoreVideo
import CryptoKit

struct ScreenOCREvent {
  let frameID: UInt64
  let state: String
  let blocks: [OCRBlock]
  let durationMs: Double
  let image: CVPixelBuffer?
  let expandedBlocks: Int
  let contentScale: Double
  let paintingDurationMs: Double
  let previous: Bool
  let cacheHit: Bool
  let regionArea: Double
  let translations: [String: String]
  let unplacedBlockCount: Int
  let untranslatedBlockIDs: Set<String>
  let failureReasonCounts: [String: Int]
  let translationDurationMs: Double
  let translationCacheHits: Int
  let errorCode: String
  let retryAfterSeconds: Double

  init(frameID: UInt64, state: String, blocks: [OCRBlock], durationMs: Double,
       image: CVPixelBuffer? = nil, expandedBlocks: Int = 0, contentScale: Double = 1,
       paintingDurationMs: Double = 0, previous: Bool = false, cacheHit: Bool = false, regionArea: Double = 1,
       translations: [String: String] = [:], translationDurationMs: Double = 0,
       translationCacheHits: Int = 0, retryAfterSeconds: Double = 0, errorCode: String = "", untranslatedBlockIDs: Set<String> = [], failureReasonCounts: [String: Int] = [:], unplacedBlockCount: Int = 0) {
    self.frameID = frameID; self.state = state; self.blocks = blocks
    self.durationMs = durationMs; self.image = image; self.expandedBlocks = expandedBlocks
    self.contentScale = contentScale; self.paintingDurationMs = paintingDurationMs
    self.previous = previous; self.cacheHit = cacheHit; self.regionArea = regionArea
    self.translations = translations; self.translationDurationMs = translationDurationMs
    self.translationCacheHits = translationCacheHits; self.retryAfterSeconds = retryAfterSeconds; self.errorCode = errorCode
    self.unplacedBlockCount = unplacedBlockCount
    self.failureReasonCounts = failureReasonCounts
    self.untranslatedBlockIDs = untranslatedBlockIDs
  }
}

/// One active OCR, one latest pending raw frame, and two session-scoped rendered
/// results. The small cache avoids OCR when a transient overlay disappears.
@available(iOS 27.0, *)
final class ScreenOCRPipeline {
  private struct Cached {
    let checksum: Data?
    let fingerprint: ScreenFingerprint
    let orientation: CGImagePropertyOrientation
    let size: CGSize
    let event: ScreenOCREvent
  }
  private struct Frame {
    let id: UInt64
    let checksum: Data?
    let image: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    let fingerprint: ScreenFingerprint
    let size: CGSize
    let region: OCRBox?
    let preserved: [OCRBlock]
    let previous: ScreenOCREvent?
  }
  private let worker = DispatchQueue(label: "com.twoalogistic.screenprobe.ocr", qos: .userInitiated)
  private let lock = NSLock()
  private let mailbox = LatestMailbox<ScreenOCREvent>()
  private let onEvent: (ScreenOCREvent) -> Void
  private let translationClient: ScreenTranslationClient?
  private let viewport: ScreenTranslationViewport?
  private let navigationEnabled: Bool
  private var navigationPaused = false
  private var captureOrientation: CGImagePropertyOrientation?
  private let sessionID = UUID()
  private var processingAllowed: Bool
  private var resetRequested = false
  private var retryDeadline: TimeInterval = 0
  private var lastPresentation: ScreenOCREvent?
  private let revisions = OCRRevisionGate()
  private var active = true
  private var frameID: UInt64 = 0
  private var pending: Frame?
  private var working = false
  private var request: VNRecognizeTextRequest?
  private var cache: [Cached] = []
  // Source sample queue only.
  private var reference: ScreenFingerprint?
  private var stability = ScreenStability(threshold: 0.012, settleSeconds: 0.4, changedAreaThreshold: 0.15)
  private var orientation: CGImagePropertyOrientation?
  private var size: CGSize = .zero
  private var reusedCurrent = false
  private var reusedChecksum: Data?
  private var lastSnapshotAt: TimeInterval = 0
  private var smallChangeCandidate: ScreenFingerprint?
  private var smallChangeSince: TimeInterval = 0

  init(translationClient: ScreenTranslationClient? = nil, viewport: ScreenTranslationViewport? = nil, navigationEnabled: Bool = false, onEvent: @escaping (ScreenOCREvent) -> Void) {
    self.viewport = viewport; self.navigationEnabled = navigationEnabled
    self.translationClient = translationClient; self.processingAllowed = translationClient == nil
    self.onEvent = onEvent
  }

  private static let failureStates: Set<String> = ["translation_failed", "translation_timeout", "no_network", "rate_limited", "unauthorized", "layout_failed", "layout_partial", "translated_partial"]

  func setAppForeground(_ foreground: Bool) {
    guard translationClient != nil else { return }
    lock.lock()
    guard active, processingAllowed != !foreground else { lock.unlock(); return }
    processingAllowed = !foreground
    let prior = lastPresentation
    if !foreground {
      if !Self.failureStates.contains(prior?.state ?? "") { resetRequested = true }
      lock.unlock(); return
    }
    frameID = revisions.advance(); pending = nil
    let id = frameID, obsolete = request
    let delay = max(0, retryDeadline - ProcessInfo.processInfo.systemUptime)
    lock.unlock()
    obsolete?.cancel(); translationClient?.cancel()
    publish(ScreenOCREvent(frameID: id,
      state: Self.failureStates.contains(prior?.state ?? "") ? prior!.state : "paused_in_app",
      blocks: prior?.blocks ?? [], durationMs: 0, image: prior?.image,
      previous: prior?.image != nil, translations: prior?.translations ?? [:], retryAfterSeconds: delay,
      untranslatedBlockIDs: prior?.untranslatedBlockIDs ?? [], failureReasonCounts: prior?.failureReasonCounts ?? [:], unplacedBlockCount: prior?.unplacedBlockCount ?? 0))
  }

  func setNavigationPaused(_ paused: Bool) {
    lock.lock()
    guard active, navigationPaused != paused else { lock.unlock(); return }
    navigationPaused = paused
    frameID = revisions.advance(); pending = nil
    let obsolete = request
    if !paused { resetRequested = true }
    lock.unlock()
    obsolete?.cancel(); translationClient?.cancel()
  }

  func retryCurrentFrame() {
    lock.lock()
    guard active, ProcessInfo.processInfo.systemUptime >= retryDeadline else { lock.unlock(); return }
    cache.removeAll { ["translated_partial", "layout_partial"].contains($0.event.state) }
    resetRequested = true; frameID = revisions.advance(); pending = nil
    let obsolete = request
    lock.unlock()
    obsolete?.cancel(); translationClient?.cancel()
  }

  func submit(_ source: CVPixelBuffer, orientation sourceOrientation: CGImagePropertyOrientation) {
    let image: CVPixelBuffer
    let orientation: CGImagePropertyOrientation
    if let viewport {
      guard let cropped = ScreenFrameSampler.cropped(source, orientation: sourceOrientation, viewport: viewport) else {
        orientationUnavailable(); return
      }
      image = cropped; orientation = .up
      if captureOrientation != sourceOrientation {
        reference = nil; stability.reset(); reusedCurrent = false
      }
      captureOrientation = sourceOrientation
    } else { image = source; orientation = sourceOrientation }
    let now = ProcessInfo.processInfo.systemUptime
    lock.lock()
    let enabled = active && processingAllowed && !navigationPaused && now >= retryDeadline
    let reset = enabled && resetRequested
    if reset { resetRequested = false }
    lock.unlock()
    guard enabled else { return }
    if reset { reference = nil; stability.reset(); reusedCurrent = false; reusedChecksum = nil }
    let size = CGSize(width: CVPixelBufferGetWidth(image), height: CVPixelBufferGetHeight(image))
    let fingerprint = ScreenFrameSampler.sample(image, orientation: orientation, excludeStatusBar: viewport == nil)
    let checksum = imageChecksum(image)
    lock.lock(); let inFlight = working; lock.unlock()
    let geometryChanged = self.orientation != orientation || self.size != size
    let area = reference.map { $0.changedFraction(to: fingerprint) } ?? 1
    // Minor animation does not cancel a captured snapshot in flight.
    let changedVisual = geometryChanged || area >= 0.15
    var refreshSmallChange = false
    if !changedVisual, !inFlight, now - lastSnapshotAt >= 5,
       reference?.hasLocalizedChange(to: fingerprint) == true {
      if let candidate = smallChangeCandidate {
        let age = now - smallChangeSince
        refreshSmallChange = (candidate.changedFraction(to: fingerprint) < 0.005 && age >= 0.8) || age >= 1.5
        smallChangeCandidate = fingerprint
      } else { smallChangeCandidate = fingerprint; smallChangeSince = now }
    } else { smallChangeCandidate = nil }
    let changed = changedVisual || refreshSmallChange
    lock.lock()
    let base = cache.last { $0.orientation == orientation && $0.size == size }
    let exact = cache.last { checksum != nil && $0.orientation == orientation && $0.size == size && $0.checksum == checksum }
    lock.unlock()
    if changed {
      self.orientation = orientation; self.size = size; reference = fingerprint
      lastSnapshotAt = now; smallChangeCandidate = nil
      stability.reset(); reusedCurrent = false; reusedChecksum = nil
      lock.lock()
      guard active && processingAllowed && !navigationPaused else { lock.unlock(); return }
      frameID = revisions.advance()
      let id = frameID
      pending = nil
      let obsolete = request
      lock.unlock()
      obsolete?.cancel(); translationClient?.cancel()
      if let exact {
        reusedCurrent = true; reusedChecksum = checksum
        publish(ScreenOCREvent(frameID: id, state: exact.event.state, blocks: exact.event.blocks,
          durationMs: 0, image: exact.event.image, expandedBlocks: exact.event.expandedBlocks,
          contentScale: exact.event.contentScale, cacheHit: true,
          translations: exact.event.translations, translationCacheHits: exact.event.translations.count,
          untranslatedBlockIDs: exact.event.untranslatedBlockIDs, failureReasonCounts: exact.event.failureReasonCounts, unplacedBlockCount: exact.event.unplacedBlockCount))
        return
      }
      publish(ScreenOCREvent(frameID: id, state: "waiting_stability", blocks: base?.event.blocks ?? [],
        durationMs: 0, image: base?.event.image, previous: base?.event.image != nil,
        translations: base?.event.translations ?? [:], untranslatedBlockIDs: base?.event.untranslatedBlockIDs ?? [], failureReasonCounts: base?.event.failureReasonCounts ?? [:], unplacedBlockCount: base?.event.unplacedBlockCount ?? 0))
    }
    guard !reusedCurrent, stability.observe(fingerprint, now: now) else { return }
    let region = base.flatMap { partialRegion(previous: $0.fingerprint, current: fingerprint, blocks: $0.event.blocks) }
    let preserved = region.map { roi in base?.event.blocks.filter { !intersects($0.box, roi) } ?? [] } ?? []
    lock.lock()
    guard active && processingAllowed && !navigationPaused else { lock.unlock(); return }
    pending = Frame(id: frameID, checksum: checksum, image: image, orientation: orientation, fingerprint: fingerprint,
      size: size, region: region, preserved: preserved, previous: base?.event)
    let startWorker = !working
    if startWorker { working = true }
    lock.unlock()
    if startWorker { worker.async { [weak self] in self?.drain() } }
  }

  func orientationUnavailable() {
    stability.reset(); reference = nil; reusedCurrent = false; reusedChecksum = nil
    lock.lock()
    guard active && !navigationPaused else { lock.unlock(); return }
    frameID = revisions.advance(); pending = nil
    let id = frameID, obsolete = request
    lock.unlock()
    obsolete?.cancel(); translationClient?.cancel()
    publish(ScreenOCREvent(frameID: id, state: "orientation_unavailable", blocks: [], durationMs: 0))
  }

  func stop() {
    lock.lock()
    active = false; revisions.stop(); pending = nil; cache.removeAll(); lastPresentation = nil
    let obsolete = request
    lock.unlock()
    obsolete?.cancel(); translationClient?.stop()
    _ = mailbox.take()
  }

  private func isCurrent(_ id: UInt64) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return active && processingAllowed && !navigationPaused && revisions.isCurrent(id)
  }

  private func drain() {
    while true {
      lock.lock()
      guard active, let frame = pending else { working = false; lock.unlock(); return }
      pending = nil
      lock.unlock()
      autoreleasepool { recognize(frame) }
    }
  }

  private func recognize(_ frame: Frame) {
    guard isCurrent(frame.id) else { return }
    let started = ProcessInfo.processInfo.systemUptime
    let recognition = VNRecognizeTextRequest()
    recognition.recognitionLevel = .accurate
    recognition.recognitionLanguages = ["zh-Hans", "en-US"]
    recognition.usesLanguageCorrection = false
    if let roi = frame.region {
      recognition.regionOfInterest = CGRect(x: roi.x, y: 1 - roi.y - roi.height, width: roi.width, height: roi.height)
    } else { recognition.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: viewport == nil ? 0.95 : 1) }
    lock.lock()
    guard active, frameID == frame.id else { lock.unlock(); return }
    request = recognition
    lock.unlock()
    defer { lock.lock(); if request === recognition { request = nil }; lock.unlock() }
    publish(ScreenOCREvent(frameID: frame.id, state: "recognizing", blocks: frame.previous?.blocks ?? [],
      durationMs: 0, image: frame.previous?.image, previous: frame.previous?.image != nil,
      regionArea: frame.region.map { $0.width * $0.height } ?? 1,
      translations: frame.previous?.translations ?? [:], untranslatedBlockIDs: frame.previous?.untranslatedBlockIDs ?? [], failureReasonCounts: frame.previous?.failureReasonCounts ?? [:], unplacedBlockCount: frame.previous?.unplacedBlockCount ?? 0))
    let id = frame.id
    let deadline = DispatchWorkItem { [weak self, weak recognition] in
      guard let self, let recognition else { return }
      self.lock.lock()
      guard self.active, self.frameID == id, self.request === recognition else { self.lock.unlock(); return }
      self.frameID = self.revisions.advance()
      let expiredID = self.frameID
      self.pending = nil
      self.lock.unlock()
      recognition.cancel(); self.translationClient?.cancel()
      self.publish(ScreenOCREvent(frameID: expiredID, state: "ocr_timeout", blocks: [], durationMs: 3000))
    }
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3, execute: deadline)
    defer { deadline.cancel() }
    do {
      try VNImageRequestHandler(cvPixelBuffer: frame.image, orientation: frame.orientation).perform([recognition])
      lock.lock(); if request === recognition { request = nil }; lock.unlock()
      deadline.cancel()
      guard isCurrent(frame.id) else { return }
      let ocrElapsed = (ProcessInfo.processInfo.systemUptime - started) * 1000
      let observations = recognition.results ?? []
      guard observations.count + frame.preserved.count <= 50 else {
        publish(ScreenOCREvent(frameID: frame.id, state: "ocr_limit", blocks: [], durationMs: 0)); return
      }
      let lines: [OCRBlock] = observations.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = OCRText.normalize(candidate.string)
        guard !text.isEmpty else { return nil }
        let box = observation.boundingBox
        return OCRBlock(id: "new", text: text,
          box: OCRBox.fromVision(x: box.minX, y: box.minY, width: box.width, height: box.height,
            imageRegion: (Double(recognition.regionOfInterest.minX), Double(recognition.regionOfInterest.minY),
                          Double(recognition.regionOfInterest.width), Double(recognition.regionOfInterest.height))), confidence: candidate.confidence)
      }
      let combined = OCRText.readingOrder(frame.preserved + lines)
      guard combined.reduce(0, { $0 + $1.text.count }) <= 6000 else {
        publish(ScreenOCREvent(frameID: frame.id, state: "ocr_limit", blocks: [], durationMs: 0)); return
      }
      guard isCurrent(frame.id) else { return }
      let ordered = combined.enumerated().map { OCRBlock(id: "b\($0.offset)", text: $0.element.text,
        box: $0.element.box, confidence: $0.element.confidence) }
      var translations: [String: String] = [:]
      var untranslatedIDs: Set<String> = []
      var failureReasonCounts: [String: Int] = [:]
      var translationElapsed: Double = 0
      var translationHits = 0
      if let translationClient {
        let eligible = ordered.filter { block in block.text.unicodeScalars.contains {
          (0x3400...0x9fff).contains($0.value) || (0xf900...0xfaff).contains($0.value)
        } }
        if !eligible.isEmpty {
          // PiP keeps a completed translated snapshot until the next one is ready.
          publish(ScreenOCREvent(frameID: frame.id, state: "translating", blocks: ordered,
            durationMs: ocrElapsed, image: frame.previous?.image,
            previous: frame.previous?.image != nil, translations: frame.previous?.translations ?? [:], untranslatedBlockIDs: frame.previous?.untranslatedBlockIDs ?? [], failureReasonCounts: frame.previous?.failureReasonCounts ?? [:], unplacedBlockCount: frame.previous?.unplacedBlockCount ?? 0))
          let translationStarted = ProcessInfo.processInfo.systemUptime
          do {
            let translated = try translationClient.translate(sessionID: sessionID, frameID: frame.id,
              blocks: eligible, timeoutMs: 8000, shouldStart: { [weak self] in self?.isCurrent(frame.id) == true })
            translations = translated.translations
            untranslatedIDs = translated.untranslatedBlockIDs
            failureReasonCounts = translated.failureReasonCounts
            translationHits = translated.cacheHits
            translationElapsed = (ProcessInfo.processInfo.systemUptime - translationStarted) * 1000
          } catch {
            guard isCurrent(frame.id) else { return }
            let typed = error as? ScreenTranslationClientError
            let state: String
            switch typed?.code {
            case "ACCESS_EXPIRED": state = "access_expired"
            case "UNAUTHORIZED": state = "unauthorized"
            case "RATE_LIMITED": state = "rate_limited"
            case "TIMEOUT": state = "translation_timeout"
            case "NETWORK": state = "no_network"
            case "CANCELLED": return
            default: state = "translation_failed"
            }
            let delay = typed?.retryAfterSeconds ?? 0
            lock.lock(); retryDeadline = ProcessInfo.processInfo.systemUptime + delay; lock.unlock()
            publish(ScreenOCREvent(frameID: frame.id, state: state, blocks: ordered,
              durationMs: ocrElapsed, image: frame.previous?.image,
              previous: frame.previous?.image != nil, translations: frame.previous?.translations ?? [:],
              translationDurationMs: (ProcessInfo.processInfo.systemUptime - translationStarted) * 1000,
              retryAfterSeconds: delay, errorCode: (typed?.code ?? "UNKNOWN") + (translationClient.failureReason().isEmpty ? "" : "/" + translationClient.failureReason())))
            return
          }
        }
      } else { translations = MockScreenTranslator.translateKnownBlocks(ordered) }
      guard isCurrent(frame.id) else { return }
      let paintingStarted = ProcessInfo.processInfo.systemUptime
      let painted: ScreenFramePainter.Output
      do {
        painted = try ScreenFramePainter.paint(source: frame.image, orientation: frame.orientation,
          blocks: ordered, translations: translations,
          pageSize: navigationEnabled ? nil : viewport == nil ? CGSize(width: 720, height: 1280) : CGSize(width: 960, height: 540),
          minimumFontSize: navigationEnabled ? 3 : viewport != nil ? 18 : 10,
          preserveLayout: navigationEnabled || viewport != nil)
      } catch {
        publish(ScreenOCREvent(frameID: frame.id, state: "layout_failed", blocks: ordered, durationMs: ocrElapsed, errorCode: "LAYOUT_" + String((error as NSError).code))); return
      }
      let event = ScreenOCREvent(frameID: frame.id, state: ordered.isEmpty ? "no_text" : translationClient == nil ? "recognized" : !painted.unplacedBlocks.isEmpty ? "layout_partial" : untranslatedIDs.isEmpty ? "translated" : "translated_partial",
        blocks: ordered, durationMs: ocrElapsed, image: painted.image, expandedBlocks: painted.expandedBlocks,
        contentScale: painted.contentScale, paintingDurationMs: (ProcessInfo.processInfo.systemUptime - paintingStarted) * 1000,
        regionArea: frame.region.map { $0.width * $0.height } ?? 1,
        translations: translations, translationDurationMs: translationElapsed, translationCacheHits: translationHits, untranslatedBlockIDs: untranslatedIDs, failureReasonCounts: failureReasonCounts, unplacedBlockCount: painted.unplacedBlocks.count)
      lock.lock()
      if active && frameID == frame.id {
        cache.removeAll { $0.orientation == frame.orientation && $0.size == frame.size && $0.fingerprint == frame.fingerprint }
        cache.append(Cached(checksum: frame.checksum, fingerprint: frame.fingerprint, orientation: frame.orientation, size: frame.size, event: event))
        if cache.count > 2 { cache.removeFirst(cache.count - 2) }
      }
      lock.unlock()
      publish(event)
    } catch {
      publish(ScreenOCREvent(frameID: frame.id, state: "ocr_failed", blocks: [], durationMs: 0))
    }
  }

  private func publish(_ event: ScreenOCREvent) {
    lock.lock(); let current = active && revisions.isCurrent(event.frameID); lock.unlock()
    guard current, mailbox.offer(event) else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, let latest = self.mailbox.take() else { return }
      self.lock.lock(); defer { self.lock.unlock() }
      guard self.active, self.frameID == latest.frameID else { return }
      // UI assignment only; renderer runs later, outside this lock.
      self.lastPresentation = latest
      self.onEvent(latest)
    }
  }

  /// Exact source-plane digest is used only for the two-entry in-memory OCR
  /// snapshot cache. A downsample match alone never reuses a painted screenshot.
  private func imageChecksum(_ image: CVPixelBuffer) -> Data? {
    guard CVPixelBufferLockBaseAddress(image, .readOnly) == kCVReturnSuccess else { return nil }
    defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
    var digest = SHA256()
    var format = CVPixelBufferGetPixelFormatType(image)
    withUnsafeBytes(of: &format) { digest.update(bufferPointer: $0) }
    let planes = CVPixelBufferGetPlaneCount(image)
    if planes == 0 {
      guard let base = CVPixelBufferGetBaseAddress(image) else { return nil }
      digest.update(bufferPointer: UnsafeRawBufferPointer(start: base,
        count: CVPixelBufferGetBytesPerRow(image) * CVPixelBufferGetHeight(image)))
    } else {
      for plane in 0..<planes {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(image, plane) else { return nil }
        digest.update(bufferPointer: UnsafeRawBufferPointer(start: base,
          count: CVPixelBufferGetBytesPerRowOfPlane(image, plane) * CVPixelBufferGetHeightOfPlane(image, plane)))
      }
    }
    return Data(digest.finalize())
  }

  private func partialRegion(previous: ScreenFingerprint, current: ScreenFingerprint, blocks: [OCRBlock]) -> OCRBox? {
    guard let dirty = ScreenFrameSampler.changedRegion(from: previous, to: current, excludeStatusBar: viewport == nil) else { return nil }
    let minimumTop = viewport == nil ? 0.05 : 0
    var left = max(0, dirty.x - 0.02), top = max(minimumTop, dirty.y - 0.02)
    var right = min(1, dirty.x + dirty.width + 0.02), bottom = min(1, dirty.y + dirty.height + 0.02)
    // Do not split an old text line at the ROI edge.
    for _ in 0...blocks.count {
      let before = [left, top, right, bottom]
      let roi = OCRBox(x: left, y: top, width: right - left, height: bottom - top)
      for block in blocks where intersects(block.box, roi) {
        left = min(left, block.box.x); top = max(minimumTop, min(top, block.box.y))
        right = max(right, min(1, block.box.x + block.box.width))
        bottom = max(bottom, min(1, block.box.y + block.box.height))
      }
      if before == [left, top, right, bottom] { break }
    }
    guard (right - left) * (bottom - top) < 0.55 else { return nil }
    return OCRBox(x: left, y: top, width: right - left, height: bottom - top)
  }

  private func intersects(_ a: OCRBox, _ b: OCRBox) -> Bool {
    a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.y + a.height > b.y
  }

  deinit { stop() }
}
#endif
