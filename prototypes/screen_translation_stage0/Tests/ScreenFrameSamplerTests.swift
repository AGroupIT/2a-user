import CoreVideo
import Foundation
import ImageIO

@main
struct ScreenFrameSamplerTests {
  static func main() {
    func image(patch: CGRect? = nil) -> CVPixelBuffer {
      var value: CVPixelBuffer?
      precondition(CVPixelBufferCreate(kCFAllocatorDefault, 96, 160, kCVPixelFormatType_32BGRA,
        [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary, &value) == kCVReturnSuccess)
      let buffer = value!
      CVPixelBufferLockBaseAddress(buffer, [])
      let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(buffer)
      for y in 0..<160 { for x in 0..<96 {
        let black = patch?.contains(CGPoint(x: x, y: y)) == true
        let i = y * stride + x * 4
        bytes[i] = black ? 0 : 255; bytes[i + 1] = bytes[i]; bytes[i + 2] = bytes[i]; bytes[i + 3] = 255
      } }
      CVPixelBufferUnlockBaseAddress(buffer, [])
      return buffer
    }
    let clean = image()
    let baseline = ScreenFrameSampler.sample(clean, orientation: .up)
    let clock = ScreenFrameSampler.sample(image(patch: CGRect(x: 0, y: 0, width: 96, height: 8)), orientation: .up)
    precondition(baseline == clock, "The actual top status-bar rows must be ignored")
    let fullClock = ScreenFrameSampler.sample(image(patch: CGRect(x: 0, y: 0, width: 96, height: 8)), orientation: .up, excludeStatusBar: false)
    let fullClean = ScreenFrameSampler.sample(clean, orientation: .up, excludeStatusBar: false)
    precondition(fullClock != fullClean, "A cropped strip must retain its top text rows")
    precondition(ScreenFrameSampler.changedRegion(from: fullClean, to: fullClock, excludeStatusBar: false)!.y == 0)
    precondition(ScreenFrameSampler.changedRegion(from: baseline, to: clock) == nil)
    let below = ScreenFrameSampler.sample(image(patch: CGRect(x: 24, y: 16, width: 24, height: 16)), orientation: .up)
    let region = ScreenFrameSampler.changedRegion(from: baseline, to: below)!
    func near(_ value: Double, _ expected: Double, tolerance: Double = 0.00001) { precondition(abs(value - expected) < tolerance, "\\(value) vs \\(expected)") }
    near(region.x, 0.25); near(region.y, 0.1); near(region.width, 0.25); near(region.height, 0.1)
    let bottom = ScreenFrameSampler.sample(image(patch: CGRect(x: 0, y: 152, width: 96, height: 8)), orientation: .up)
    precondition(ScreenFrameSampler.changedRegion(from: baseline, to: bottom) != nil, "Bottom rows must remain observed")
    let patch = image(patch: CGRect(x: 24, y: 40, width: 24, height: 20))
    let expected: [(Double, Double, Double, Double)] = [
      (0.25, 0.25, 0.25, 0.125), (0.5, 0.25, 0.25, 0.125),
      (0.5, 0.625, 0.25, 0.125), (0.25, 0.625, 0.25, 0.125),
      (0.25, 0.25, 0.125, 0.25), (0.625, 0.25, 0.125, 0.25),
      (0.625, 0.5, 0.125, 0.25), (0.25, 0.5, 0.125, 0.25)]
    for raw in 1...8 {
      let orientation = CGImagePropertyOrientation(rawValue: UInt32(raw))!
      let result = ScreenFrameSampler.changedRegion(from: ScreenFrameSampler.sample(clean, orientation: orientation),
        to: ScreenFrameSampler.sample(patch, orientation: orientation))!
      let e = expected[raw - 1]
      near(result.x, e.0, tolerance: 0.025); near(result.y, e.1, tolerance: 0.025)
      near(result.width, e.2, tolerance: 0.025); near(result.height, e.3, tolerance: 0.025)
    }
    let split = image(patch: CGRect(x: 0, y: 0, width: 96, height: 80))
    func gray(_ image: CVPixelBuffer, x: Int, y: Int) -> UInt8 {
      CVPixelBufferLockBaseAddress(image, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
      return CVPixelBufferGetBaseAddress(image)!.assumingMemoryBound(to: UInt8.self)[y * CVPixelBufferGetBytesPerRow(image) + x * 4]
    }
    for top in [true, false] {
      let viewport = ScreenTranslationViewport(pipAtTop: top)
      let crop = ScreenFrameSampler.cropped(split, orientation: .up, viewport: viewport)!
      precondition(CVPixelBufferGetWidth(crop) == 96 && CVPixelBufferGetHeight(crop) == 54)
      precondition(gray(crop, x: 48, y: 27) == (top ? 255 : 0), "Crop must use the opposite half")
      let rotated = ScreenFrameSampler.cropped(split, orientation: .down, viewport: viewport)!
      precondition(gray(rotated, x: 48, y: 27) == (top ? 0 : 255), "Orientation must precede crop")
    }
    let bands = image()
    CVPixelBufferLockBaseAddress(bands, [])
    let bandBytes = CVPixelBufferGetBaseAddress(bands)!.assumingMemoryBound(to: UInt8.self)
    let bandStride = CVPixelBufferGetBytesPerRow(bands)
    let shades: [UInt8] = [20, 80, 140, 220]
    for y in 0..<160 { for x in 0..<96 {
      let offset = y * bandStride + x * 4
      bandBytes[offset] = shades[y / 40]
      bandBytes[offset + 1] = shades[y / 40]
      bandBytes[offset + 2] = shades[y / 40]
    } }
    CVPixelBufferUnlockBaseAddress(bands, [])
    let parts = ScreenFrameSampler.snapshotParts(bands)!
    precondition(parts.count == 4)
    precondition(gray(parts.first!, x: 0, y: 0) == shades[0])
    let last = parts.last!
    precondition(gray(last, x: 0, y: CVPixelBufferGetHeight(last) - 1) == shades[3])
    var seen = Set<UInt8>()
    for part in parts {
      precondition(CVPixelBufferGetWidth(part) == 96)
      precondition((54...55).contains(CVPixelBufferGetHeight(part)))
      precondition(CVPixelBufferGetIOSurface(part) != nil)
      for y in 0..<CVPixelBufferGetHeight(part) { seen.insert(gray(part, x: 48, y: y)) }
    }
    precondition(Set(shades).isSubset(of: seen), "Snapshot pages must retain both middle bands")
    let middleBox = OCRBox(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
    for raw in 1...8 {
      let crop = ScreenFrameSampler.cropped(bands,
        orientation: CGImagePropertyOrientation(rawValue: UInt32(raw))!, box: middleBox)!
      precondition(CVPixelBufferGetWidth(crop) == (raw <= 4 ? 48 : 80))
      precondition(CVPixelBufferGetHeight(crop) == (raw <= 4 ? 80 : 48))
      precondition(CVPixelBufferGetIOSurface(crop) != nil)
      let values = Set((0..<CVPixelBufferGetHeight(crop)).flatMap { y in
        (0..<CVPixelBufferGetWidth(crop)).map { x in gray(crop, x: x, y: y) }
      })
      precondition(values == Set([shades[1], shades[2]]), "Oriented generic crop must retain the selected middle")
    }
    for invalid in [OCRBox(x: -.infinity, y: 0, width: 1, height: 1),
                    OCRBox(x: 0, y: 0, width: 0, height: 1),
                    OCRBox(x: 0.5, y: 0, width: 1, height: 1),
                    OCRBox(x: 0, y: -0.1, width: 1, height: 1)] {
      precondition(ScreenFrameSampler.cropped(bands, orientation: .up, box: invalid) == nil)
    }
    var portrait: CVPixelBuffer?
    precondition(CVPixelBufferCreate(nil, 720, 1280, kCVPixelFormatType_32BGRA,
      [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary, &portrait) == kCVReturnSuccess)
    precondition(ScreenFrameSampler.snapshotParts(portrait!)!.count == 4)
    precondition(ScreenTranslationViewport(pipAtTop: true).box(width: 720, height: 1280).height == 405.0 / 1280)
    precondition(ScreenTranslationViewport(pipAtTop: false).box(width: 720, height: 1280).y == 0)
    print("PASS: actual pixels exclude top5%, retain bottom, map changed bounds, all8 orientations, generic crop and snapshot full-height parts")
  }
}
