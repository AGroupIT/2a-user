#if DEBUG || SCREEN_TRANSLATION_STAGE0 || SCREEN_TRANSLATION_LIVE
import AVFoundation
import CoreMedia
import Foundation

/// Video-only QA writer. append/finish must share the Source's serial video queue.
/// There is no frame queue: a busy encoder drops the current frame immediately.
/// Source owns consent, duration, output paths, cancellation and orphan cleanup.
@available(iOS 27.0, *)
final class QAClipWriter {
  private let url: URL
  private let onFinished: (Result<Int, Error>) -> Void
  private var writer: AVAssetWriter?
  private var receiver: AVAssetWriterInput.SampleBufferReceiver?
  private var dimensions: CMVideoDimensions?
  private var pixelFormat: OSType?
  private var origin: CMTime?
  private var lastWrittenTime: CMTime?
  private var frameCount = 0
  private var finishRequested = false
  // finishWriting invokes its callback outside the Source queue.
  private let completionLock = NSLock()
  private var completed = false

  init(url: URL, onFinished: @escaping (Result<Int, Error>) -> Void) {
    self.url = url
    self.onFinished = onFinished
  }

  func append(_ sampleBuffer: CMSampleBuffer) {
    guard !finishRequested else { return }
    guard CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer),
          CMSampleBufferGetNumSamples(sampleBuffer) == 1,
          let image = CMSampleBufferGetImageBuffer(sampleBuffer),
          let format = CMSampleBufferGetFormatDescription(sampleBuffer),
          CMFormatDescriptionGetMediaType(format) == kCMMediaType_Video else {
      fail(Self.failure(3)); return
    }
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    guard pts.isNumeric else { fail(Self.failure(6)); return }
    let size = CMVideoFormatDescriptionGetDimensions(format)
    guard size.width > 0, size.height > 0,
          CVPixelBufferGetWidth(image) == Int(size.width),
          CVPixelBufferGetHeight(image) == Int(size.height) else {
      fail(Self.failure(4)); return
    }
    let subtype = CVPixelBufferGetPixelFormatType(image)
    do {
      if writer == nil { try configure(size: size, pixelFormat: subtype, format: format) }
      guard let writer, let receiver else { throw Self.failure(9) }
      guard writer.status == .writing else { throw writer.error ?? Self.failure(9) }
      guard dimensions?.width == size.width, dimensions?.height == size.height,
            pixelFormat == subtype else { throw Self.failure(5) }
      // Choose the first successfully appended source timestamp as zero.
      let sourceOrigin = origin ?? pts
      let shifted = CMTimeSubtract(pts, sourceOrigin)
      guard shifted.isNumeric, CMTimeCompare(shifted, .zero) >= 0 else { return }
      if let lastWrittenTime, CMTimeCompare(shifted, lastWrittenTime) <= 0 { return }
      var timing = CMSampleTimingInfo(
        duration: CMSampleBufferGetDuration(sampleBuffer),
        presentationTimeStamp: shifted,
        decodeTimeStamp: .invalid)
      var retimed: CMSampleBuffer?
      guard CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault,
        sampleBuffer: sampleBuffer, sampleTimingEntryCount: 1,
        sampleTimingArray: &timing, sampleBufferOut: &retimed) == noErr,
        let retimed else { throw Self.failure(6) }
      let ready = CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(unsafeBuffer: retimed)
      // iOS 26+ receiver reports backpressure without suspending or retaining a queue.
      if try receiver.appendImmediately(ready) {
        origin = sourceOrigin
        lastWrittenTime = shifted
        frameCount += 1
      }
    } catch { fail(error) }
  }

  func finish(cancelled: Bool) {
    if finishRequested {
      if cancelled {
        writer?.cancelWriting()
        complete(.failure(Self.failure(1)))
      }
      return
    }
    finishRequested = true
    guard !cancelled else {
      writer?.cancelWriting()
      complete(.failure(Self.failure(1)))
      return
    }
    guard let writer, let receiver, frameCount > 0 else {
      writer?.cancelWriting()
      complete(.failure(Self.failure(2)))
      return
    }
    guard writer.status == .writing else {
      complete(.failure(writer.error ?? Self.failure(9)))
      return
    }
    receiver.finish()
    let count = frameCount
    // Retain this helper until finalization: Source must await this exact result.
    writer.finishWriting { [self] in
      if writer.status == .completed {
        complete(.success(count))
      } else {
        complete(.failure(writer.error ?? Self.failure(9)))
      }
    }
  }

  private func configure(size: CMVideoDimensions, pixelFormat: OSType,
                         format: CMFormatDescription) throws {
    let output = try AVAssetWriter(outputURL: url, fileType: .mp4)
    // Keep the handle even if encoder setup fails, so cancellation closes it.
    writer = output
    let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
      AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000,
        AVVideoExpectedSourceFrameRateKey: 4, AVVideoMaxKeyFrameIntervalKey: 8,
        AVVideoAllowFrameReorderingKey: false]]
    guard output.canApply(outputSettings: settings, forMediaType: .video) else {
      throw Self.failure(7)
    }
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings,
                                 sourceFormatHint: format)
    guard output.canAdd(input) else { throw Self.failure(8) }
    receiver = output.inputReceiver(for: input)
    dimensions = size
    self.pixelFormat = pixelFormat
    try output.start()
    output.startSession(atSourceTime: .zero)
  }

  private func fail(_ error: Error) {
    finishRequested = true
    writer?.cancelWriting()
    complete(.failure(error))
  }

  private func complete(_ result: Result<Int, Error>) {
    completionLock.lock()
    guard !completed else { completionLock.unlock(); return }
    completed = true
    completionLock.unlock()
    onFinished(result)
  }

  /// Codes: cancelled, empty, invalid buffer, size, changed format, timing,
  /// unsupported settings, incompatible input, writer failure. No screen data.
  private static func failure(_ code: Int) -> NSError {
    NSError(domain: "com.twoalogistic.screenprobe.qa-writer", code: code)
  }
}
#endif
