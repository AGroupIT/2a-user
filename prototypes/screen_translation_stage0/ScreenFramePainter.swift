#if DEBUG || SCREEN_TRANSLATION_STAGE0 || SCREEN_TRANSLATION_LIVE
import CoreGraphics
import CoreImage
import CoreText
import CoreVideo
import Foundation
import ImageIO

/// Raster reflow of known OCR regions, not semantic reconstruction or inpainting.
/// Source imagery hidden by a protected PiP remains hidden.
@available(iOS 27.0, *)
enum ScreenFramePainter {
  struct Output {
    let image: CVPixelBuffer
    let expandedBlocks: Int
    let contentScale: Double
    let layoutHeight: CGFloat
    /// Compatibility only: list pages are no longer produced.
    let overflowBlocks: [OCRBlock]
    /// Full translations for genuine geometry/fit anomalies, never silently discarded.
    let unplacedBlocks: [OCRBlock]
  }

  struct TextLayout {
    let text: String
    let fontSize: CGFloat
    let height: CGFloat
    var singleLine = false
  }

  struct Item {
    let block: OCRBlock
    let original: CGRect
    var target: CGRect
    let layout: TextLayout?
    var padding: CGFloat = 2
  }

  struct Band {
    let sourceTop: CGFloat
    var sourceBottom: CGFloat
    var outputTop: CGFloat
    var height: CGFloat
    var items: [Item]
  }

  struct Plan {
    let bands: [Band]
    let extendedHeight: CGFloat
    let expandedBlocks: Int
    let overflowBlocks: [OCRBlock]
    let unplacedBlocks: [OCRBlock]
  }

  private static let colorSpace = CGColorSpaceCreateDeviceRGB()
  private static let imageContext = CIContext(options: [.cacheIntermediates: false])
  private static let padding: CGFloat = 2
  private static let maximumHeight: CGFloat = 1_000_000

  static func paint(source: CVPixelBuffer, orientation: CGImagePropertyOrientation,
                    blocks: [OCRBlock], translations: [String: String],
                    pageSize: CGSize? = nil, minimumFontSize: CGFloat = 10, preserveLayout: Bool = false) throws -> Output {
    let oriented = CIImage(cvPixelBuffer: source).oriented(orientation)
    let extent = oriented.extent.integral
    guard validSize(extent.size),
          let original = imageContext.createCGImage(oriented, from: extent,
                                                    format: .RGBA8, colorSpace: colorSpace) else {
      throw failure(1)
    }
    let width = original.width, height = original.height
    let requestedPage = pageSize ?? CGSize(width: width, height: height)
    guard validSize(requestedPage) else { throw failure(2) }
    let pageWidth = Int(requestedPage.width.rounded()), pageHeight = Int(requestedPage.height.rounded())
    guard pageWidth > 0, pageHeight > 0 else { throw failure(2) }
    let corridors = preserveLayout ? layoutCorridors(original, blocks: blocks) : [:]
    let initial = try plan(blocks: blocks, translations: translations, width: width, height: height, minimumFontSize: minimumFontSize, preserveLayout: preserveLayout, horizontalCorridors: corridors)
    var inPlace: Set<String> = []
    for item in initial.bands.flatMap(\.items) where !preserveLayout && item.layout != nil && item.target.width > item.original.width {
      let expanded = CGRect(x: item.target.minX, y: item.original.minY, width: item.target.width, height: item.original.height)
      let left = CGRect(x: expanded.minX, y: expanded.minY, width: max(0, item.original.minX - expanded.minX), height: expanded.height)
      let right = CGRect(x: item.original.maxX, y: expanded.minY, width: max(0, expanded.maxX - item.original.maxX), height: expanded.height)
      let background = borderColor(original, around: item.original)
      if uniform(original, rectangle: left, background: background) && uniform(original, rectangle: right, background: background) {
        inPlace.insert(item.block.id)
      }
    }
    let plan = preserveLayout || inPlace.isEmpty ? initial : try plan(blocks: blocks, translations: translations, width: width, height: height,
      minimumFontSize: minimumFontSize, inPlaceExpansionIDs: inPlace, preserveLayout: preserveLayout, horizontalCorridors: corridors)
    let fittedScale = min(CGFloat(pageWidth) / CGFloat(width), CGFloat(pageHeight) / plan.extendedHeight)
    let scale = preserveLayout ? fittedScale : min(1, fittedScale)
    guard scale.isFinite, scale > 0 else { throw failure(3) }
    let horizontalInset = (CGFloat(pageWidth) - CGFloat(width) * scale) / 2
    let verticalInset = (CGFloat(pageHeight) - plan.extendedHeight * scale) / 2
    let attributes: [CFString: Any] = [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
      kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
    var destination: CVPixelBuffer?
    guard CVPixelBufferCreate(kCFAllocatorDefault, pageWidth, pageHeight, kCVPixelFormatType_32BGRA,
      attributes as CFDictionary, &destination) == kCVReturnSuccess, let destination else { throw failure(4) }
    guard CVPixelBufferLockBaseAddress(destination, []) == kCVReturnSuccess else { throw failure(5) }
    defer { CVPixelBufferUnlockBaseAddress(destination, []) }
    guard let bytes = CVPixelBufferGetBaseAddress(destination),
          let context = CGContext(data: bytes, width: pageWidth, height: pageHeight, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(destination), space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
      throw failure(5)
    }
    // All subsequent layout coordinates are top-left source pixels.
    let pageBackground: [CGFloat] = [0.97, 0.97, 0.98]
    context.setFillColor(CGColor(colorSpace: colorSpace, components: pageBackground + [1])!)
    context.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
    context.translateBy(x: horizontalInset, y: CGFloat(pageHeight) - verticalInset)
    context.scaleBy(x: scale, y: -scale)
    context.interpolationQuality = scale == 1 ? .none : .high
    context.textMatrix = .identity

    var unplaced = plan.unplacedBlocks
    if preserveLayout {
      drawImage(original, in: CGRect(x: 0, y: 0, width: width, height: height), context: context)
    }
    var cursor: CGFloat = 0
    var shift: CGFloat = 0
    for band in plan.bands {
      if !preserveLayout {
      try drawStrip(original, from: cursor, to: band.sourceTop, at: cursor + shift, context: context)
      let bandBackground = borderColor(original,
        around: CGRect(x: 0, y: band.sourceTop, width: CGFloat(width), height: band.sourceBottom - band.sourceTop))
      context.setFillColor(CGColor(colorSpace: colorSpace, components: bandBackground + [1])!)
      context.fill(CGRect(x: 0, y: band.outputTop, width: CGFloat(width), height: band.height))
      try drawStrip(original, from: band.sourceTop, to: band.sourceBottom, at: band.outputTop, context: context)
      }
      // PreserveLayout draws the source once; only translated patches may be cleared.
      for item in band.items where !preserveLayout || item.layout != nil {
        let old = item.original.offsetBy(dx: 0, dy: band.outputTop - band.sourceTop)
        let background = borderColor(original, around: item.original)
        context.setFillColor(CGColor(colorSpace: colorSpace, components: background + [1])!)
        context.fill(old)
      }
      for item in band.items {
        if let layout = item.layout {
          let plannedTextRect = item.target.insetBy(dx: item.padding, dy: item.padding)
          if preserveLayout && !fits(layout, in: plannedTextRect.size) {
            unplaced.append(OCRBlock(id: item.block.id, text: layout.text, box: item.block.box, confidence: item.block.confidence))
            guard let crop = original.cropping(to: item.original) else { throw failure(6) }
            drawImage(crop, in: item.original, context: context)
            continue
          }
          let background = borderColor(original, around: item.original)
          context.setFillColor(CGColor(colorSpace: colorSpace, components: background + [1])!)
          context.fill(item.target)
          let luminance = 0.2126 * background[0] + 0.7152 * background[1] + 0.0722 * background[2]
          let foreground = CGColor(gray: luminance > 0.55 ? 0 : 1, alpha: 1)
          let textRect = item.target.insetBy(dx: item.padding, dy: item.padding)
          context.saveGState()
          context.translateBy(x: textRect.minX, y: textRect.maxY)
          context.scaleBy(x: 1, y: -1)
          if layout.singleLine {
            let line = CTLineCreateWithAttributedString(attributed(layout.text, fontSize: layout.fontSize, color: foreground))
            let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
            context.textPosition = CGPoint(x: max(0, -bounds.minX), y: (textRect.height - bounds.height) / 2 - bounds.minY)
            CTLineDraw(line, context)
          } else {
            let frame = textFrame(layout.text, fontSize: layout.fontSize, color: foreground,
              rect: CGRect(origin: .zero, size: textRect.size))
            guard CTFrameGetVisibleStringRange(frame).length == (layout.text as NSString).length else { throw failure(8) }
            CTFrameDraw(frame, context)
          }
          context.restoreGState()
        } else if !preserveLayout {
          guard let crop = original.cropping(to: item.original) else { throw failure(6) }
          drawImage(crop, in: item.target, context: context)
        }
      }
      shift += band.height - (band.sourceBottom - band.sourceTop)
      cursor = band.sourceBottom
    }
    if !preserveLayout { try drawStrip(original, from: cursor, to: CGFloat(height), at: cursor + shift, context: context) }
    return Output(image: destination, expandedBlocks: plan.expandedBlocks, contentScale: Double(scale), layoutHeight: plan.extendedHeight, overflowBlocks: [], unplacedBlocks: OCRText.readingOrder(unplaced))
  }

  /// Deterministic bounded layout, exposed internally for geometry/full-text tests.
  static func plan(blocks: [OCRBlock], translations: [String: String], width: Int, height: Int, minimumFontSize: CGFloat = 10, inPlaceExpansionIDs: Set<String> = [], preserveLayout: Bool = false, horizontalCorridors: [String: CGRect] = [:]) throws -> Plan {
    guard width > 0, height > 0, blocks.count <= 50,
          translations.values.reduce(0, { $0 + $1.utf16.count }) <= 36000,
          Set(blocks.map(\.id)).count == blocks.count else { throw failure(7) }
    // No translated items means an exact source copy; do not rearrange unknown OCR.
    let hasTranslation = blocks.contains {
      translations[$0.id]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
    guard hasTranslation else { return Plan(bands: [], extendedHeight: CGFloat(height), expandedBlocks: 0, overflowBlocks: [], unplacedBlocks: []) }
    let minimumFont = minimumFontSize.isFinite ? min(32, max(10, minimumFontSize)) : 10
    var items: [Item] = []
    var unplaced: [OCRBlock] = []
    func unplacedBlock(_ block: OCRBlock, _ translated: String) -> OCRBlock {
      OCRBlock(id: block.id, text: translated, box: block.box, confidence: block.confidence)
    }
    for block in blocks {
      let rectangle = pixelRect(block.box, width: width, height: height)
      let translated = translations[block.id].flatMap {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
      }
      if rectangle.isEmpty {
        if let translated {
          guard preserveLayout, block.box.x.isFinite, block.box.y.isFinite,
                block.box.width.isFinite, block.box.height.isFinite,
                block.box.width >= 0, block.box.height >= 0 else { throw failure(7) }
          unplaced.append(unplacedBlock(block, translated))
        }
        continue
      }
      var target = rectangle
      var layout: TextLayout?
      var itemPadding = padding
      if let translated, preserveLayout {
        // Prefer a readable size when safe blank space exists; 18 is not a floor.
        let proposed = horizontalCorridors[block.id] ?? rectangle
        let page = CGRect(x: 0, y: 0, width: width, height: height)
        let corridor = proposed.isNull || !proposed.minX.isFinite || !proposed.minY.isFinite ||
          !proposed.width.isFinite || !proposed.height.isFinite ? rectangle : proposed.intersection(page)
        let font = min(32, max(18, (rectangle.height * 0.75).rounded(.down)))
        itemPadding = min(2, min(rectangle.width, rectangle.height) * 0.1)
        let line = CTLineCreateWithAttributedString(attributed(translated, fontSize: font, color: CGColor(gray: 0, alpha: 1)))
        let needed = ceil(lineWidth(line)) + 2 * itemPadding
        if needed > rectangle.width, !corridor.isEmpty, corridor.contains(rectangle) {
          target.size.width = min(corridor.width, needed)
          target.origin.x = min(corridor.maxX - target.width, max(corridor.minX, rectangle.midX - target.width / 2))
        }
        if !corridor.isEmpty, corridor.contains(rectangle),
           let measured = try? measureLive(translated, width: max(0.01, target.width - 2 * itemPadding), fontSize: font) {
          target.size.height = min(corridor.height, max(rectangle.height, measured.height + 2 * itemPadding))
          target.origin.y = min(corridor.maxY - target.height, max(corridor.minY, rectangle.midY - target.height / 2))
        }
        layout = fitLive(translated, size: target.insetBy(dx: itemPadding, dy: itemPadding).size,
                         preferredFont: font, minimumFont: 3)
        if layout == nil {
          unplaced.append(unplacedBlock(block, translated))
          target = rectangle
        }
      } else if let translated {
        var font = min(32, max(minimumFont, (rectangle.height * 0.75).rounded(.down)))
        let innerWidth = max(1, rectangle.width - 2 * padding)
        var measured = try measure(translated, width: innerWidth, fontSize: font)
        while font > minimumFont && measured.height + 2 * padding > rectangle.height {
          font -= 1
          measured = try measure(translated, width: innerWidth, fontSize: font)
        }
        if measured.height > rectangle.height * 1.5 || rectangle.width <= 2 * padding {
          let nextColumn = blocks.filter { $0.id != block.id }.map { pixelRect($0.box, width: width, height: height) }
            .filter { $0.minX > rectangle.minX && $0.minY < rectangle.maxY && $0.maxY > rectangle.minY }
            .map(\.minX).min() ?? CGFloat(width)
          let available = max(rectangle.width, nextColumn - rectangle.minX - 4)
          target.size.width = min(available, max(rectangle.width, min(320, CGFloat(width) * 0.45)))
          target.origin.x = max(0, min(rectangle.minX, CGFloat(width) - target.width))
          guard target.width > 2 * padding else { throw failure(8) }
          measured = try measure(translated, width: target.width - 2 * padding, fontSize: font)
        }
        target.size.height = max(rectangle.height, measured.height + 2 * padding)
        layout = measured
      }
      items.append(Item(block: block, original: rectangle, target: target, layout: layout, padding: itemPadding))
    }
    items.sort {
      if $0.original.minY != $1.original.minY { return $0.original.minY < $1.original.minY }
      if $0.original.minX != $1.original.minX { return $0.original.minX < $1.original.minX }
      return $0.block.id < $1.block.id
    }
    var bands: [Band] = []
    for item in items {
      if let last = bands.last, item.original.minY < last.sourceBottom {
        bands[bands.count - 1].sourceBottom = max(last.sourceBottom, item.original.maxY)
        bands[bands.count - 1].items.append(item)
      } else {
        bands.append(Band(sourceTop: item.original.minY, sourceBottom: item.original.maxY,
                          outputTop: 0, height: 0, items: [item]))
      }
    }
    var shift: CGFloat = 0
    var expanded = 0
    for index in bands.indices {
      let top = bands[index].sourceTop
      bands[index].outputTop = top + shift
      var placed: [CGRect] = []
      var bottom = bands[index].sourceBottom - top
      for itemIndex in bands[index].items.indices {
        var item = bands[index].items[itemIndex]
        item.target.origin.y -= top
        let grows = item.layout != nil &&
          (item.target.width > item.original.width || item.target.height > item.original.height)
        if grows && !preserveLayout {
          // Replace the source row. Insert only the overflow below its original bottom;
          // putting the entire replacement after the row duplicates its height.
          item.target.origin.y = item.target.width > item.original.width && !inPlaceExpansionIDs.contains(item.block.id)
            ? bands[index].sourceBottom - top + 2 : item.original.minY - top
        }
        var attempts = 0
        while !preserveLayout, let collision = placed.first(where: { $0.intersects(item.target) }) {
          item.target.origin.y = collision.maxY + 2
          attempts += 1
          guard attempts <= blocks.count else { throw failure(9) }
        }
        placed.append(item.target)
        if !preserveLayout { bottom = max(bottom, item.target.maxY) }
        if grows && !preserveLayout { expanded += 1 }
        item.target.origin.y += bands[index].outputTop
        bands[index].items[itemIndex] = item
      }
      bands[index].height = bottom
      shift += bottom - (bands[index].sourceBottom - top)
      guard CGFloat(height) + shift <= maximumHeight else { throw failure(9) }
    }
    return Plan(bands: bands, extendedHeight: CGFloat(height) + shift, expandedBlocks: expanded,
      overflowBlocks: [], unplacedBlocks: OCRText.readingOrder(unplaced))
  }

  /// Already oriented top-left normalized bbox -> integral top-left source pixels.
  static func pixelRect(_ box: OCRBox, width: Int, height: Int) -> CGRect {
    guard box.x.isFinite, box.y.isFinite, box.width.isFinite, box.height.isFinite,
          box.width > 0, box.height > 0 else { return .zero }
    let left = (min(1, max(0, box.x)) * Double(width)).rounded(.down)
    let right = (min(1, max(0, box.x + box.width)) * Double(width)).rounded(.up)
    let top = (min(1, max(0, box.y)) * Double(height)).rounded(.down)
    let bottom = (min(1, max(0, box.y + box.height)) * Double(height)).rounded(.up)
    guard right > left, bottom > top else { return .zero }
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }

  /// Full string and fixed preferred font; grow height instead of truncating content.
  static func measure(_ text: String, width: CGFloat, fontSize: CGFloat) throws -> TextLayout {
    guard width.isFinite, width > 0, text.utf16.count <= 6000 else { throw failure(8) }
    let font = min(32, max(3, fontSize))
    let framesetter = CTFramesetterCreateWithAttributedString(attributed(text, fontSize: font, color: CGColor(gray: 0, alpha: 1)))
    var range = CFRange()
    let suggested = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil,
      CGSize(width: width, height: maximumHeight), &range)
    var height = max(font * 1.5, ceil(suggested.height) + 2)
    for _ in 0..<4 {
      guard height <= maximumHeight else { throw failure(8) }
      let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0),
        CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil), nil)
      if CTFrameGetVisibleStringRange(frame).length == (text as NSString).length {
        return TextLayout(text: text, fontSize: font, height: height)
      }
      height += font * 2
    }
    throw failure(8)
  }

  private static func lineWidth(_ line: CTLine) -> CGFloat {
    let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
    return max(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)), bounds.maxX) - min(0, bounds.minX)
  }

  /// Bounded adaptive source-font fit. Full strings only; an actual nonfit is reported per block.
  private static func fitLive(_ text: String, size: CGSize, preferredFont: CGFloat,
                              minimumFont: CGFloat) -> TextLayout? {
    guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
    var font = preferredFont
    while font >= minimumFont {
      if let layout = try? measureLive(text, width: size.width, fontSize: font),
         layout.height <= size.height, fits(layout, in: size) { return layout }
      if font == minimumFont { break }
      font = max(minimumFont, font - 0.5)
    }
    return nil
  }

  private static func fits(_ layout: TextLayout, in size: CGSize) -> Bool {
    guard size.width > 0, size.height > 0 else { return false }
    if layout.singleLine {
      let line = CTLineCreateWithAttributedString(attributed(layout.text, fontSize: layout.fontSize, color: CGColor(gray: 0, alpha: 1)))
      let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
      return lineWidth(line) <= size.width && ceil(bounds.height) + 1 <= size.height
    }
    let frame = textFrame(layout.text, fontSize: layout.fontSize, color: CGColor(gray: 0, alpha: 1),
                          rect: CGRect(origin: .zero, size: size))
    return CTFrameGetVisibleStringRange(frame).length == (layout.text as NSString).length
  }

  /// Live one-line labels use actual glyph bounds rather than a font-size multiplier.
  private static func measureLive(_ text: String, width: CGFloat, fontSize: CGFloat) throws -> TextLayout {
    guard text.utf16.count <= 6000, width > 0 else { throw failure(8) }
    let line = CTLineCreateWithAttributedString(attributed(text, fontSize: fontSize, color: CGColor(gray: 0, alpha: 1)))
    if !text.contains(where: { $0.isNewline }), lineWidth(line) <= width {
      let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
      return TextLayout(text: text, fontSize: fontSize, height: ceil(bounds.height) + 1, singleLine: true)
    }
    return try measure(text, width: width, fontSize: fontSize)
  }

  /// Every candidate column is checked across the full label height. OCR neighbors
  /// reserve half of shared whitespace, so independently expanded labels cannot overlap.
  static func horizontalCorridors(_ image: CGImage, blocks: [OCRBlock]) -> [String: CGRect] {
    let page = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    let rects = blocks.map { ($0.id, pixelRect($0.box, width: image.width, height: image.height)) }
    var result: [String: CGRect] = [:]
    for (id, rect) in rects where !rect.isEmpty {
      var left: CGFloat = 0, right = page.width
      for (otherID, other) in rects where otherID != id && other.minY < rect.maxY && other.maxY > rect.minY {
        if other.maxX <= rect.minX { left = max(left, floor((other.maxX + rect.minX) / 2)) }
        else if other.minX >= rect.maxX { right = min(right, ceil((rect.maxX + other.minX) / 2)) }
        else { left = rect.minX; right = rect.maxX }
      }
      guard let crop = image.cropping(to: CGRect(x: 0, y: rect.minY, width: CGFloat(image.width), height: rect.height)) else { continue }
      var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
      var ready = false
      pixels.withUnsafeMutableBytes { storage in
        guard let context = CGContext(data: storage.baseAddress, width: crop.width, height: crop.height,
          bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height)); ready = true
      }
      guard ready else { continue }
      let background = borderColor(image, around: rect)
      func free(_ x: Int) -> Bool {
        for y in 0..<crop.height {
          let offset = (y * crop.width + x) * 4
          for channel in 0..<3 where abs(CGFloat(pixels[offset + channel]) / 255 - background[channel]) > 0.04 { return false }
        }
        return true
      }
      var minX = Int(rect.minX), maxX = Int(rect.maxX)
      while minX > Int(left), free(minX - 1) { minX -= 1 }
      while maxX < Int(right), free(maxX) { maxX += 1 }
      // Keep two pixels of separation from graphics and neighboring text.
      let safeLeft = min(rect.minX, CGFloat(minX) + 2)
      let safeRight = max(rect.maxX, CGFloat(maxX) - 2)
      result[id] = CGRect(x: safeLeft, y: rect.minY, width: safeRight - safeLeft, height: rect.height)
    }
    return result
  }

  /// Borrow only verified blank pixels, with midpoint reservation between neighboring rows.
  /// The original screen and images never move or change size.
  static func layoutCorridors(_ image: CGImage, blocks: [OCRBlock]) -> [String: CGRect] {
    let horizontal = horizontalCorridors(image, blocks: blocks)
    let rects = blocks.map { ($0.id, pixelRect($0.box, width: image.width, height: image.height)) }
    var result = horizontal
    for (id, rect) in rects where !rect.isEmpty {
      let corridor = horizontal[id] ?? rect
      var top: CGFloat = 0, bottom = CGFloat(image.height)
      for (otherID, other) in rects where otherID != id && !other.isEmpty {
        let otherCorridor = horizontal[otherID] ?? other
        guard otherCorridor.minX < corridor.maxX && otherCorridor.maxX > corridor.minX else { continue }
        if other.maxY <= rect.minY { top = max(top, ceil((other.maxY + rect.minY) / 2)) }
        else if other.minY >= rect.maxY { bottom = min(bottom, floor((rect.maxY + other.minY) / 2)) }
        else { top = rect.minY; bottom = rect.maxY }
      }
      guard let crop = image.cropping(to: CGRect(x: corridor.minX, y: 0, width: corridor.width, height: CGFloat(image.height))) else { continue }
      var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
      var ready = false
      pixels.withUnsafeMutableBytes { storage in
        guard let context = CGContext(data: storage.baseAddress, width: crop.width, height: crop.height,
          bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height)); ready = true
      }
      guard ready else { continue }
      let background = borderColor(image, around: rect)
      func free(_ y: Int) -> Bool {
        guard y >= 0, y < crop.height else { return false }
        for x in 0..<crop.width {
          let offset = (y * crop.width + x) * 4
          for channel in 0..<3 where abs(CGFloat(pixels[offset + channel]) / 255 - background[channel]) > 0.04 { return false }
        }
        return true
      }
      var minY = Int(rect.minY), maxY = Int(rect.maxY)
      while minY > Int(top), free(minY - 1) { minY -= 1 }
      while maxY < Int(bottom), free(maxY) { maxY += 1 }
      result[id] = CGRect(x: corridor.minX, y: min(rect.minY, CGFloat(minY) + 1), width: corridor.width,
        height: max(rect.maxY, CGFloat(maxY) - 1) - min(rect.minY, CGFloat(minY) + 1))
    }
    return result
  }

  private static func validSize(_ size: CGSize) -> Bool {
    size.width.isFinite && size.height.isFinite && size.width >= 1 && size.height >= 1 &&
      size.width <= 8192 && size.height <= 8192 && size.width * size.height <= 16_777_216
  }

  private static func attributed(_ text: String, fontSize: CGFloat, color: CGColor) -> NSAttributedString {
    NSAttributedString(string: text, attributes: [
      NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, fontSize, nil),
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color])
  }

  private static func textFrame(_ text: String, fontSize: CGFloat, color: CGColor, rect: CGRect) -> CTFrame {
    CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attributed(text, fontSize: fontSize, color: color)),
      CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
  }

  private static func drawImage(_ image: CGImage, in rectangle: CGRect, context: CGContext) {
    context.saveGState()
    context.translateBy(x: rectangle.minX, y: rectangle.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(origin: .zero, size: rectangle.size))
    context.restoreGState()
  }

  private static func drawStrip(_ image: CGImage, from top: CGFloat, to bottom: CGFloat,
                                at outputTop: CGFloat, context: CGContext) throws {
    guard bottom > top else { return }
    let source = CGRect(x: 0, y: top, width: CGFloat(image.width), height: bottom - top)
    guard let crop = image.cropping(to: source) else { throw failure(6) }
    drawImage(crop, in: CGRect(x: 0, y: outputTop, width: source.width, height: source.height), context: context)
  }

  /// Expansion is allowed only across an actually uniform source corridor.
  /// Inspect every pixel so a neighboring non-OCR icon cannot be sampled away.
  private static func uniform(_ image: CGImage, rectangle: CGRect, background: [CGFloat]) -> Bool {
    guard !rectangle.isEmpty else { return true }
    let rect = rectangle.integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard !rect.isEmpty, let crop = image.cropping(to: rect) else { return false }
    let width = crop.width, height = crop.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    var ready = false
    pixels.withUnsafeMutableBytes { storage in
      guard let context = CGContext(data: storage.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
      context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height)); ready = true
    }
    guard ready else { return false }
    for offset in stride(from: 0, to: pixels.count, by: 4) {
      for channel in 0..<3 where abs(CGFloat(pixels[offset + channel]) / 255 - background[channel]) > 0.08 { return false }
    }
    return true
  }

  private static func borderColor(_ image: CGImage, around patch: CGRect) -> [CGFloat] {
    var locations: [(CGFloat, CGFloat)] = []
    for index in 0..<8 {
      let t = (CGFloat(index) + 0.5) / 8
      locations.append((patch.minX + patch.width * t, patch.minY - 2))
      locations.append((patch.minX + patch.width * t, patch.maxY + 2))
      locations.append((patch.minX - 2, patch.minY + patch.height * t))
      locations.append((patch.maxX + 2, patch.minY + patch.height * t))
    }
    var pixels = [UInt8](repeating: 0, count: locations.count * 4)
    pixels.withUnsafeMutableBytes { storage in
      guard let data = storage.baseAddress,
            let context = CGContext(data: data, width: locations.count, height: 1, bitsPerComponent: 8,
              bytesPerRow: locations.count * 4, space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
      context.interpolationQuality = .none
      for (index, point) in locations.enumerated() {
        let x = min(CGFloat(image.width - 1), max(0, floor(point.0)))
        let y = min(CGFloat(image.height - 1), max(0, floor(point.1)))
        guard let sample = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else { continue }
        context.draw(sample, in: CGRect(x: index, y: 0, width: 1, height: 1))
      }
    }
    var buckets: [Int: (count: Int, channels: [CGFloat])] = [:]
    for index in locations.indices {
      let c = (0..<3).map { CGFloat(pixels[index * 4 + $0]) / 255 }
      guard pixels[index * 4 + 3] > 0 else { continue }
      // Pure capture masks and dark glyphs should not turn a light card into a black patch.
      if c.allSatisfy({ $0 < 0.08 }) { continue }
      let key = (Int(c[0] * 7) << 6) | (Int(c[1] * 7) << 3) | Int(c[2] * 7)
      var bucket = buckets[key] ?? (0, [0, 0, 0])
      bucket.count += 1
      for channel in 0..<3 { bucket.channels[channel] += c[channel] }
      buckets[key] = bucket
    }
    guard let selected = buckets.sorted(by: {
      $0.value.count == $1.value.count ? $0.key > $1.key : $0.value.count > $1.value.count
    }).first?.value else { return [0.97, 0.97, 0.98] }
    return selected.channels.map { $0 / CGFloat(selected.count) }
  }

  private static func failure(_ code: Int) -> NSError {
    NSError(domain: "com.twoalogistic.screenprobe.frame-painter", code: code)
  }
}
#endif
