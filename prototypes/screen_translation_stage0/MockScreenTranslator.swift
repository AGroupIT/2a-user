import Foundation

/// Deterministic QA fixture, never a general translator or fallback provider.
/// Unknown or low-confidence input remains raw OCR; nothing leaves the device.
enum MockScreenTranslator {
  static let fixtures: [(String, String)] = [
    ("不含电池", "Без батареи"),
    ("尺寸：30 × 20 cm", "Размер: 30 × 20 cm"),
    ("数量：2 件", "Кол-во: 2 шт."),
    ("材质：不锈钢", "Материал: нерж. сталь")
  ]

  private static func fixtureKey(_ text: String) -> String {
    // Only this fixed QA corpus tolerates OCR spacing and colon typography.
    // Never use this equivalence as a general translation/cache normalization.
    OCRText.normalize(text).filter { !$0.isWhitespace }.replacingOccurrences(of: ":", with: "：")
  }

  /// Visual QA mode may replace only exact known fixtures. Unmatched source
  /// areas stay unchanged; UI must label the result as a partial mock layout.
  static func translateKnownBlocks(_ blocks: [OCRBlock]) -> [String: String] {
    let dictionary = Dictionary(uniqueKeysWithValues: fixtures.map { (fixtureKey($0.0), $0.1) })
    var known: [String: String] = [:]
    for block in blocks where block.confidence >= 0.8 {
      if let translated = dictionary[fixtureKey(block.text)] { known[block.id] = translated }
    }
    return known
  }

  static func translate(_ blocks: [OCRBlock]) -> [OCRBlock]? {
    guard !blocks.isEmpty, blocks.count <= 50 else { return nil }
    let dictionary = Dictionary(uniqueKeysWithValues: fixtures.map { (fixtureKey($0.0), $0.1) })
    var translated: [OCRBlock] = []
    for block in blocks {
      guard block.confidence >= 0.8, let text = dictionary[fixtureKey(block.text)] else { return nil }
      translated.append(OCRBlock(id: block.id, text: text, box: block.box, confidence: block.confidence))
    }
    return translated
  }
}
