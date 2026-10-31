import CoreGraphics
import CoreText
import CoreVideo
import Foundation
import ImageIO

@main
struct ScreenFramePainterTests {
  static func main() throws {
    typealias RGB = (UInt8, UInt8, UInt8)
    let colors: [RGB] = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 255)]
    func image(width: Int, height: Int, quadrants: Bool) -> CVPixelBuffer {
      var buffer: CVPixelBuffer?
      precondition(CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
        [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary, &buffer) == kCVReturnSuccess)
      let value = buffer!
      CVPixelBufferLockBaseAddress(value, [])
      let bytes = CVPixelBufferGetBaseAddress(value)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(value)
      for y in 0..<height { for x in 0..<width {
        let c: RGB = quadrants ? colors[(y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1)] : (255, 255, 255)
        let i = y * stride + x * 4
        bytes[i] = c.2; bytes[i + 1] = c.1; bytes[i + 2] = c.0; bytes[i + 3] = 255
      } }
      CVPixelBufferUnlockBaseAddress(value, [])
      return value
    }
    func pixel(_ image: CVPixelBuffer, _ x: Int, _ y: Int) -> RGB {
      CVPixelBufferLockBaseAddress(image, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
      let bytes = CVPixelBufferGetBaseAddress(image)!.assumingMemoryBound(to: UInt8.self)
      let i = y * CVPixelBufferGetBytesPerRow(image) + x * 4
      return (bytes[i + 2], bytes[i + 1], bytes[i])
    }
    func same(_ a: RGB, _ b: RGB) {
      precondition(abs(Int(a.0) - Int(b.0)) <= 2 && abs(Int(a.1) - Int(b.1)) <= 2 && abs(Int(a.2) - Int(b.2)) <= 2,
                   "Pixel \(a) != \(b)")
    }
    let input = image(width: 80, height: 40, quadrants: true)
    let corners = [[0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
                   [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]]
    for raw in 1...8 {
      let output = try ScreenFramePainter.paint(source: input, orientation: CGImagePropertyOrientation(rawValue: UInt32(raw))!, blocks: [], translations: [:])
      let w = CVPixelBufferGetWidth(output.image), h = CVPixelBufferGetHeight(output.image)
      precondition(w == (raw < 5 ? 80 : 40) && h == (raw < 5 ? 40 : 80))
      precondition(output.expandedBlocks == 0 && output.contentScale == 1 && CVPixelBufferGetIOSurface(output.image) != nil)
      for (index, point) in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)].enumerated() {
        same(pixel(output.image, point.0, point.1), colors[corners[raw - 1][index]])
      }
    }
    let copy = try ScreenFramePainter.paint(source: input, orientation: .up, blocks: [], translations: [:])
    for y in 0..<40 { for x in 0..<80 { same(pixel(copy.image, x, y), pixel(input, x, y)) } }
    let portrait = try ScreenFramePainter.paint(source: input, orientation: .up, blocks: [], translations: [:],
      pageSize: CGSize(width: 720, height: 1280))
    precondition(CVPixelBufferGetWidth(portrait.image) == 720 && CVPixelBufferGetHeight(portrait.image) == 1280)
    for (i, p) in [(322, 622), (397, 622), (322, 657), (397, 657)].enumerated() {
      same(pixel(portrait.image, p.0, p.1), colors[i])
    }
    let white = image(width: 200, height: 120, quadrants: false)
    let block = OCRBlock(id: "price", text: "价格", box: OCRBox(x: 0.55, y: 0.1, width: 0.1, height: 0.125), confidence: 1)
    let unknown = OCRBlock(id: "unknown", text: "品牌", box: OCRBox(x: 0.8, y: 0.1, width: 0.15, height: 0.125), confidence: 1)
    let later = OCRBlock(id: "later", text: "底部", box: OCRBox(x: 0.1, y: 0.7, width: 0.2, height: 0.1), confidence: 1)
    // Distinct unknown source crop must survive reflow in its original source-band position.
    CVPixelBufferLockBaseAddress(white, [])
    let bytes = CVPixelBufferGetBaseAddress(white)!.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(white)
    let originalUnknown = ScreenFramePainter.pixelRect(unknown.box, width: 200, height: 120)
    for y in Int(originalUnknown.minY)..<Int(originalUnknown.maxY) {
      for x in Int(originalUnknown.minX)..<Int(originalUnknown.maxX) {
        let i = y * stride + x * 4; bytes[i] = 0; bytes[i + 1] = 255; bytes[i + 2] = 0
      }
    }
    CVPixelBufferUnlockBaseAddress(white, [])
    let full = String(repeating: "Батарея не входит в комплект. Размер 30 × 20 cm; цена 123 ₽. ", count: 4)
    let blocks = [block, unknown, later]
    let plan = try ScreenFramePainter.plan(blocks: blocks, translations: ["price": full], width: 200, height: 120)
    precondition(plan.expandedBlocks == 1 && plan.bands.count == 2 && plan.extendedHeight > 120)
    let translated = plan.bands[0].items.first { $0.block.id == "price" }!
    let movedUnknown = plan.bands[0].items.first { $0.block.id == "unknown" }!
    precondition(translated.layout!.text == full && !translated.layout!.text.contains("\u{2026}"))
    precondition(translated.target.width > translated.original.width && translated.target.height > translated.original.height)
    precondition(movedUnknown.target == movedUnknown.original)
    precondition(translated.target.minY >= plan.bands[0].sourceBottom && plan.bands[1].outputTop > plan.bands[1].sourceTop)
    for band in plan.bands {
      for (i, item) in band.items.enumerated() {
        precondition(item.target.minX >= 0 && item.target.maxX <= 200 && item.target.minY >= 0 && item.target.maxY <= plan.extendedHeight)
        for other in band.items.dropFirst(i + 1) { precondition(!item.target.intersects(other.target)) }
      }
    }
    // Independently check CoreText has room for every UTF16 code unit, including the final sentence.
    let layout = translated.layout!
    let attr = NSAttributedString(string: full, attributes: [NSAttributedString.Key(kCTFontAttributeName as String):
      CTFontCreateWithName("Helvetica" as CFString, layout.fontSize, nil)])
    let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(location: 0, length: 0),
      CGPath(rect: CGRect(x: 0, y: 0, width: translated.target.width - 4, height: translated.target.height - 4), transform: nil), nil)
    precondition(CTFrameGetVisibleStringRange(frame).length == (full as NSString).length)
    let output = try ScreenFramePainter.paint(source: white, orientation: .up, blocks: blocks, translations: ["price": full],
      pageSize: CGSize(width: 720, height: 1280))
    let scale = CGFloat(output.contentScale)
    precondition(scale > 0 && scale <= 1 && output.expandedBlocks == 1)
    let dx = (720 - 200 * scale) / 2, dy = (1280 - output.layoutHeight * scale) / 2
    same(pixel(output.image, Int(dx + movedUnknown.target.midX * scale), Int(dy + movedUnknown.target.midY * scale)), (0, 255, 0))
    precondition(dy + plan.extendedHeight * scale <= 1280 && dx + 200 * scale <= 720)
    // Regression: an icon beside a narrow label is not represented by any OCR box.
    // Expansion must insert space below the source band, preserving every icon pixel.
    let iconSource = image(width: 200, height: 120, quadrants: false)
    CVPixelBufferLockBaseAddress(iconSource, [])
    let iconBytes = CVPixelBufferGetBaseAddress(iconSource)!.assumingMemoryBound(to: UInt8.self)
    let iconStride = CVPixelBufferGetBytesPerRow(iconSource)
    for y in 20..<40 { for x in 65..<85 {
      let i = y * iconStride + x * 4
      iconBytes[i] = 0; iconBytes[i + 1] = 0; iconBytes[i + 2] = 255
    } }
    CVPixelBufferUnlockBaseAddress(iconSource, [])
    let narrow = OCRBlock(id: "narrow", text: "说明", box: OCRBox(x: 0.1, y: 20.0 / 120,
      width: 0.2, height: 20.0 / 120), confidence: 1)
    let iconTranslation = "Полная характеристика товара: батарея не входит в комплект."
    let iconPlan = try ScreenFramePainter.plan(blocks: [narrow], translations: ["narrow": iconTranslation], width: 200, height: 120)
    let iconItem = iconPlan.bands[0].items[0]
    precondition(iconItem.target.minY >= iconPlan.bands[0].sourceBottom && iconItem.layout!.text == iconTranslation)
    let iconOutput = try ScreenFramePainter.paint(source: iconSource, orientation: .up,
      blocks: [narrow], translations: ["narrow": iconTranslation], pageSize: CGSize(width: 720, height: 1280))
    precondition(iconOutput.contentScale == 1)
    let iconDX = 260, iconDY = Int((1280 - iconPlan.extendedHeight) / 2)
    // Fractional centering can blend at edges: use an integer page height matching parity.
    let exactHeight = Int(iconPlan.extendedHeight) + 200
    let exactIcon = try ScreenFramePainter.paint(source: iconSource, orientation: .up,
      blocks: [narrow], translations: ["narrow": iconTranslation], pageSize: CGSize(width: 720, height: exactHeight))
    precondition(exactIcon.contentScale == 1)
    for y in 20..<40 { for x in 65..<85 { same(pixel(exactIcon.image, x + iconDX, y + 100), (255, 0, 0)) } }
    same(pixel(iconOutput.image, iconDX + 75, iconDY + 30), (255, 0, 0))
    for raw in 1...8 {
      let o = CGImagePropertyOrientation(rawValue: UInt32(raw))!
      let small = OCRBlock(id: "single", text: "字", box: OCRBox(x: 0.1, y: 0.1, width: 0.7, height: 0.6), confidence: 1)
      let painted = try ScreenFramePainter.paint(source: image(width: 200, height: 120, quadrants: false),
        orientation: o, blocks: [small], translations: ["single": "Р"])
      let w = CVPixelBufferGetWidth(painted.image), h = CVPixelBufferGetHeight(painted.image)
      precondition(painted.contentScale == 1)
      var dark = 0
      for y in Int(Double(h) * 0.1)..<Int(Double(h) * 0.7) {
        for x in Int(Double(w) * 0.1)..<Int(Double(w) * 0.8) { if pixel(painted.image, x, y).0 < 200 { dark += 1 } }
      }
      precondition(dark > 5, "Already-oriented bbox must not be rotated twice: \(raw)")
    }
    // Short translated labels must not duplicate an entire source band merely
    // because CoreText's baseline/padding needs a few additional pixels.
    let compactBlocks = (0..<12).map { index in
      OCRBlock(id: "row\(index)", text: "文字", box: OCRBox(x: 0.1, y: Double(index) * 0.07,
        width: 0.8, height: 0.025), confidence: 1)
    }
    let compactText = Dictionary(uniqueKeysWithValues: compactBlocks.map { ($0.id, "Размер товара") })
    let compactPlan = try ScreenFramePainter.plan(blocks: compactBlocks, translations: compactText, width: 720, height: 1280)
    precondition(compactPlan.extendedHeight < 1400, "Short labels must not double page height")
    for band in compactPlan.bands {
      let item = band.items[0]
      precondition(item.target.minY == band.outputTop, "Replacement must start in the original row")
    }
    let fixedSource = image(width: 720, height: 405, quadrants: false)
    let fixedLabel = OCRBlock(id: "fixed", text: "不含电池", box: OCRBox(x: 0.1, y: 0.2, width: 0.35, height: 0.08), confidence: 1)
    let fixedPlan = try ScreenFramePainter.plan(blocks: [fixedLabel], translations: ["fixed": "Без батареек"],
      width: 720, height: 405, minimumFontSize: 18, preserveLayout: true)
    precondition(fixedPlan.extendedHeight == 405 && fixedPlan.expandedBlocks == 0)
    precondition(fixedPlan.bands[0].items[0].target == fixedPlan.bands[0].items[0].original)
    let fixed = try ScreenFramePainter.paint(source: fixedSource, orientation: .up, blocks: [fixedLabel],
      translations: ["fixed": "Без батареек"], pageSize: CGSize(width: 960, height: 540),
      minimumFontSize: 18, preserveLayout: true)
    precondition(fixed.expandedBlocks == 0 && fixed.layoutHeight == 405)
    precondition(abs(fixed.contentScale - 4.0 / 3) < 0.000001, "Matching strip must fill PiP including upscaling")
    // Live labels first consume safe whitespace on BOTH sides at the source font.
    let corridorSource = image(width: 720, height: 405, quadrants: false)
    let center = OCRBlock(id: "center", text: "电池", box: OCRBox(x: 330.0 / 720, y: 160.0 / 405,
      width: 60.0 / 720, height: 32.0 / 405), confidence: 1)
    let leftNeighbor = OCRBlock(id: "left", text: "左", box: OCRBox(x: 120.0 / 720, y: 160.0 / 405,
      width: 80.0 / 720, height: 32.0 / 405), confidence: 1)
    let rightNeighbor = OCRBlock(id: "right", text: "右", box: OCRBox(x: 520.0 / 720, y: 160.0 / 405,
      width: 80.0 / 720, height: 32.0 / 405), confidence: 1)
    func fill(_ buffer: CVPixelBuffer, _ rect: CGRect, _ color: RGB) {
      CVPixelBufferLockBaseAddress(buffer, [])
      let data = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
      let stride = CVPixelBufferGetBytesPerRow(buffer)
      for y in Int(rect.minY)..<Int(rect.maxY) { for x in Int(rect.minX)..<Int(rect.maxX) {
        let offset = y * stride + x * 4
        data[offset] = color.2; data[offset + 1] = color.1; data[offset + 2] = color.0
      } }
      CVPixelBufferUnlockBaseAddress(buffer, [])
    }
    func cgImage(_ buffer: CVPixelBuffer) -> CGImage {
      CVPixelBufferLockBaseAddress(buffer, .readOnly)
      defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
      return CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer),
        height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!.makeImage()!
    }
    let corridorBlocks = [leftNeighbor, center, rightNeighbor]
    let safe = ScreenFramePainter.horizontalCorridors(cgImage(corridorSource), blocks: corridorBlocks)
    let corridorPlan = try ScreenFramePainter.plan(blocks: corridorBlocks, translations: ["center": "Без батареек"],
      width: 720, height: 405, minimumFontSize: 18, preserveLayout: true, horizontalCorridors: safe)
    let centralItem = corridorPlan.bands[0].items.first { $0.block.id == "center" }!
    precondition(centralItem.target.minX < centralItem.original.minX && centralItem.target.maxX > centralItem.original.maxX)
    precondition(centralItem.layout!.singleLine && centralItem.layout!.fontSize >= 23)
    precondition(centralItem.layout!.text == "Без батареек")
    precondition(corridorPlan.extendedHeight == 405 && centralItem.target.minY == centralItem.original.minY)
    for item in corridorPlan.bands[0].items where item.block.id != "center" { precondition(item.target == item.original) }
    let sharedPlan = try ScreenFramePainter.plan(blocks: corridorBlocks,
      translations: ["left": "Левая подпись товара", "center": "Без батареек", "right": "Правая подпись товара"],
      width: 720, height: 405, minimumFontSize: 18, preserveLayout: true, horizontalCorridors: safe)
    for (index, item) in sharedPlan.bands[0].items.enumerated() {
      for other in sharedPlan.bands[0].items.dropFirst(index + 1) { precondition(!item.target.intersects(other.target)) }
      precondition(item.target.minY == item.original.minY && item.target.height == item.original.height)
    }
    let liveCorridor = try ScreenFramePainter.paint(source: corridorSource, orientation: .up, blocks: corridorBlocks,
      translations: ["center": "Без батареек"], minimumFontSize: 18, preserveLayout: true)
    precondition(liveCorridor.contentScale == 1 && liveCorridor.layoutHeight == 405)
    // Non-OCR icons are hard stops, even when only one colored pixel blocks a column.
    fill(corridorSource, CGRect(x: 280, y: 160, width: 10, height: 32), (255, 0, 0))
    fill(corridorSource, CGRect(x: 430, y: 170, width: 1, height: 1), (0, 0, 255))
    fill(corridorSource, CGRect(x: 120, y: 160, width: 80, height: 32), (0, 255, 0))
    let iconCorridors = ScreenFramePainter.horizontalCorridors(cgImage(corridorSource), blocks: corridorBlocks)
    precondition(iconCorridors["center"]!.minX >= 292 && iconCorridors["center"]!.maxX <= 428)
    let protected = try ScreenFramePainter.paint(source: corridorSource, orientation: .up, blocks: corridorBlocks,
      translations: ["center": "Материал"], minimumFontSize: 18, preserveLayout: true)
    precondition(protected.layoutHeight == 405 && protected.contentScale == 1)
    for y in 0..<405 { for x in 0..<720 where x < 292 || x >= 428 || y < 160 || y >= 192 {
      same(pixel(protected.image, x, y), pixel(corridorSource, x, y))
    } }
    // Source-sized captions stay in the original interface; no global18px floor or list pages.
    let normalSource = image(width: 720, height: 1280, quadrants: false)
    var smallLabels: [OCRBlock] = []
    var shortRussian: [String: String] = [:]
    for index in 0..<20 {
      let h = 8 + index % 9
      let label = OCRBlock(id: "small\(index)", text: "合成标签", box: OCRBox(x: 60.0 / 720,
        y: Double(40 + index * 48) / 1280, width: 150.0 / 720, height: Double(h) / 1280), confidence: 1)
      smallLabels.append(label); shortRussian[label.id] = "Размер \(index + 1) cm"
    }
    fill(normalSource, CGRect(x: 400, y: 400, width: 40, height: 60), (255, 0, 0))
    let normalCorridors = ScreenFramePainter.layoutCorridors(cgImage(normalSource), blocks: smallLabels)
    let normalPlan = try ScreenFramePainter.plan(blocks: smallLabels, translations: shortRussian, width: 720,
      height: 1280, minimumFontSize: 3, preserveLayout: true, horizontalCorridors: normalCorridors)
    precondition(normalPlan.unplacedBlocks.isEmpty && normalPlan.overflowBlocks.isEmpty)
    precondition(normalPlan.extendedHeight == 1280 && normalPlan.expandedBlocks == 0)
    for item in normalPlan.bands.flatMap(\.items) {
      precondition(item.layout?.text == shortRussian[item.block.id])
      precondition(item.layout!.fontSize >= 3 && item.layout!.fontSize <= 32)
    }
    precondition(normalPlan.bands.flatMap(\.items).contains { ($0.layout?.fontSize ?? 0) >= 14 }, "Use safe blank space to keep labels readable")
    let normal = try ScreenFramePainter.paint(source: normalSource, orientation: .up, blocks: smallLabels,
      translations: shortRussian, minimumFontSize: 3, preserveLayout: true)
    precondition(normal.unplacedBlocks.isEmpty && normal.overflowBlocks.isEmpty && normal.layoutHeight == 1280 && normal.contentScale == 1)
    for y in 400..<460 { for x in 400..<440 { same(pixel(normal.image, x, y), (255, 0, 0)) } }
    // Adaptive padding allows a5px source caption to retain full glyphs at its original small scale.
    let five = OCRBlock(id: "five", text: "字", box: OCRBox(x: 50.0 / 720, y: 200.0 / 405,
      width: 100.0 / 720, height: 5.0 / 405), confidence: 1)
    let fivePlan = try ScreenFramePainter.plan(blocks: [five], translations: ["five": "Размер 30"],
      width: 720, height: 405, minimumFontSize: 3, preserveLayout: true)
    let fiveItem = fivePlan.bands[0].items[0]
    precondition(fivePlan.unplacedBlocks.isEmpty && fiveItem.layout!.text == "Размер 30" && fiveItem.padding <= 0.6)
    precondition(fiveItem.target == fiveItem.original && fiveItem.layout!.fontSize == 3)
    // A tiny label may borrow verified blank rows, stopping before a non-OCR graphic.
    let verticalSource = image(width: 720, height: 405, quadrants: false)
    let tiny = OCRBlock(id: "tiny", text: "字", box: OCRBox(x: 340.0 / 720, y: 160.0 / 405,
      width: 4.0 / 720, height: 4.0 / 405), confidence: 1)
    fill(verticalSource, CGRect(x: 0, y: 175, width: 720, height: 5), (0, 0, 255))
    fill(verticalSource, CGRect(x: 0, y: 130, width: 720, height: 5), (255, 0, 0))
    let verticalCorridors = ScreenFramePainter.layoutCorridors(cgImage(verticalSource), blocks: [tiny])
    precondition(verticalCorridors["tiny"]!.minY >= 135 && verticalCorridors["tiny"]!.maxY <= 175)
    let fullTiny = "Полный перевод небольшой подписи без сокращений"
    let vertical = try ScreenFramePainter.paint(source: verticalSource, orientation: .up,
      blocks: [tiny], translations: ["tiny": fullTiny], minimumFontSize: 3, preserveLayout: true)
    precondition(vertical.unplacedBlocks.isEmpty && vertical.overflowBlocks.isEmpty && vertical.layoutHeight == 405)
    for rect in [CGRect(x: 0, y: 175, width: 720, height: 5), CGRect(x: 0, y: 130, width: 720, height: 5)] {
      for y in Int(rect.minY)..<Int(rect.maxY) { for x in Int(rect.minX)..<Int(rect.maxX) {
        same(pixel(vertical.image, x, y), pixel(verticalSource, x, y))
      } }
    }
    // Pathological geometry remains per-block metadata, not a whole-screen exception or hidden list page.
    let impossible = try ScreenFramePainter.plan(blocks: [tiny], translations: ["tiny": String(repeating: "Полный текст ", count: 100)],
      width: 720, height: 405, minimumFontSize: 3, preserveLayout: true)
    precondition(impossible.unplacedBlocks.count == 1 && impossible.unplacedBlocks[0].text == String(repeating: "Полный текст ", count: 100))
    precondition(impossible.overflowBlocks.isEmpty && impossible.bands[0].items[0].layout == nil)
    let zeroBox = OCRBlock(id: "zero", text: "字", box: OCRBox(x: 0.2, y: 0.2, width: 0, height: 0), confidence: 1)
    let zeroPlan = try ScreenFramePainter.plan(blocks: [zeroBox], translations: ["zero": "Полный текст"],
      width: 720, height: 405, minimumFontSize: 3, preserveLayout: true)
    precondition(zeroPlan.unplacedBlocks.first?.text == "Полный текст" && zeroPlan.bands.isEmpty)
    do {
      let bad = OCRBlock(id: "bad", text: "字", box: OCRBox(x: .nan, y: 0, width: 0.2, height: 0.2), confidence: 1)
      _ = try ScreenFramePainter.plan(blocks: [bad], translations: ["bad": "Текст"], width: 720, height: 405, preserveLayout: true)
      preconditionFailure("Nonfinite geometry must remain an explicit invalid input")
    } catch { }
    // Side gutters use a neutral light canvas even when captured corners are black.
    let neutral = try ScreenFramePainter.paint(source: white, orientation: .up, blocks: [], translations: [:],
      pageSize: CGSize(width: 720, height: 1280))
    let gutter = pixel(neutral.image, 0, 0)
    precondition(gutter.0 > 240 && gutter.1 > 240 && gutter.2 > 240)
    do {
      _ = try ScreenFramePainter.paint(source: input, orientation: .up, blocks: [], translations: [:], pageSize: CGSize(width: CGFloat.nan, height: 1280))
      preconditionFailure("Invalid page accepted")
    } catch { }
    print("PASS: all 8 orientations; exact untranslated pixels; portrait page; full UTF16 text; expansion and neighbor shifts; unknown crop and neighboring non-OCR icon preservation; one-page bounds; live bilateral whitespace, adaptive source fonts and padding, safe vertical gaps, explicit per-block anomalies without list pages, pixel/icon/shared-gap protection; invalid page rejection")
  }
}
