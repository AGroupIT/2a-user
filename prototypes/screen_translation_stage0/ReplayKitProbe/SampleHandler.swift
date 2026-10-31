import CoreMedia
import CoreVideo
import Foundation
import ReplayKit

/// Diagnostic extension only: observes video metadata, never retains or stores pixels.
/// ReplayKit callback ownership ends before each override returns.
final class SampleHandler: RPBroadcastSampleHandler {
  private struct Metadata: Encodable {
    let schemaVersion: Int
    let sessionId: String
    let state: String
    let processId: Int32
    let uptimeSeconds: TimeInterval
    let sessionDurationSeconds: TimeInterval
    let videoCallbacks: UInt64
    let validVideoBuffers: UInt64
    let invalidVideoBuffers: UInt64
    let width: Int?
    let height: Int?
    let pixelFormatFourCC: UInt32?
    let orientationExif: Int?
    let presentationTimeSeconds: Double?
    let metadataWriteFailures: UInt64
  }

  private let lock = NSLock()
  private var session: UUID?
  private var state = "idle"
  private var startedAt: TimeInterval = 0
  private var lastWriteAt: TimeInterval = -.infinity
  private var videoCallbacks: UInt64 = 0
  private var validVideoBuffers: UInt64 = 0
  private var invalidVideoBuffers: UInt64 = 0
  private var writeFailures: UInt64 = 0
  private var width: Int?
  private var height: Int?
  private var pixelFormat: UInt32?
  private var orientation: Int?
  private var presentationTime: Double?

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    // setupInfo may contain application data: intentionally do not inspect it.
    lock.lock()
    defer { lock.unlock() }
    session = UUID()
    state = "started"
    startedAt = ProcessInfo.processInfo.systemUptime
    lastWriteAt = -.infinity
    videoCallbacks = 0; validVideoBuffers = 0; invalidVideoBuffers = 0; writeFailures = 0
    width = nil; height = nil; pixelFormat = nil; orientation = nil; presentationTime = nil
    writeMetadata(force: true)
  }

  override func broadcastPaused() {
    lock.lock()
    defer { lock.unlock() }
    guard session != nil else { return }
    state = "paused"
    writeMetadata(force: true)
  }

  override func broadcastResumed() {
    lock.lock()
    defer { lock.unlock() }
    guard session != nil else { return }
    state = "resumed"
    writeMetadata(force: true)
  }

  override func broadcastFinished() {
    lock.lock()
    defer { lock.unlock() }
    guard session != nil else { return }
    state = "finished"
    writeMetadata(force: true)
    // No asynchronous tasks exist. Any later queued video/lifecycle callback sees nil.
    session = nil
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
    // Discard app audio, microphone audio and future unknown types immediately;
    // do not access their buffer contents, attachments, format or timing.
    guard sampleBufferType == .video else { return }
    lock.lock()
    defer { lock.unlock() }
    guard session != nil, state == "started" || state == "resumed" else { return }
    videoCallbacks &+= 1
    if CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer),
       let image = CMSampleBufferGetImageBuffer(sampleBuffer) {
      validVideoBuffers &+= 1
      width = CVPixelBufferGetWidth(image)
      height = CVPixelBufferGetHeight(image)
      pixelFormat = CVPixelBufferGetPixelFormatType(image)
      // Read only the documented orientation attachment, never image bytes.
      let value = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString,
                                  attachmentModeOut: nil) as? NSNumber
      let exif = value?.intValue
      orientation = exif.flatMap { (1...8).contains($0) ? $0 : nil }
      let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
      presentationTime = seconds.isFinite ? seconds : nil
    } else {
      invalidVideoBuffers &+= 1
    }
    writeMetadata(force: false)
  }

  /// Called only while holding lock; disk work is bounded to one tiny JSON each second
  /// plus lifecycle events. No sample buffer is captured by a closure or queued task.
  private func writeMetadata(force: Bool) {
    guard let session else { return }
    let now = ProcessInfo.processInfo.systemUptime
    guard force || now - lastWriteAt >= 1 else { return }
    lastWriteAt = now
    let metadata = Metadata(schemaVersion: 1, sessionId: session.uuidString, state: state,
      processId: ProcessInfo.processInfo.processIdentifier, uptimeSeconds: now,
      sessionDurationSeconds: max(0, now - startedAt), videoCallbacks: videoCallbacks,
      validVideoBuffers: validVideoBuffers, invalidVideoBuffers: invalidVideoBuffers,
      width: width, height: height, pixelFormatFourCC: pixelFormat, orientationExif: orientation,
      presentationTimeSeconds: presentationTime, metadataWriteFailures: writeFailures)
    do {
      let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true)
      let output = cache.appendingPathComponent("ScreenTranslationReplayKitProbe.json", isDirectory: false)
      let data = try JSONEncoder().encode(metadata)
      try data.write(to: output, options: .atomic)
    } catch {
      // Never include error descriptions, screen data or setupInfo in diagnostics/logs.
      writeFailures &+= 1
    }
  }
}
