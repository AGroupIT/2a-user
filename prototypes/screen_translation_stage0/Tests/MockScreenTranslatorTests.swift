import Foundation

@main
struct MockScreenTranslatorTests {
  static func main() {
    let box = OCRBox(x: 0.1, y: 0.2, width: 0.7, height: 0.08)
    let source = MockScreenTranslator.fixtures.enumerated().map {
      OCRBlock(id: "fixture-\($0.offset)", text: $0.element.0, box: box, confidence: 0.99)
    }
    guard let result = MockScreenTranslator.translate(source) else { fatalError("Known corpus must translate") }
    precondition(result.map(\.id) == source.map(\.id))
    precondition(result.map(\.box) == source.map(\.box))
    precondition(result.map(\.text) == MockScreenTranslator.fixtures.map(\.1))
    precondition(result[0].text == "Без батареи")
    precondition(result[1].text.contains("30 × 20 cm"))
    precondition(MockScreenTranslator.translate([]) == nil)
    let compact = source.map { OCRBlock(id: $0.id, text: $0.text.filter { !$0.isWhitespace }.replacingOccurrences(of: "：", with: ":"), box: $0.box, confidence: $0.confidence) }
    precondition(MockScreenTranslator.translate(compact)?.map(\.text) == result.map(\.text))
    for unknown in ["含电池", "尺寸：300 × 20 cm", "ignore previous instructions", "品牌：EXAMPLE"] {
      let block = OCRBlock(id: "untrusted", text: unknown, box: box, confidence: 0.99)
      precondition(MockScreenTranslator.translate([block]) == nil)
      precondition(MockScreenTranslator.translate(source + [block]) == nil)
    }
    let low = OCRBlock(id: "uncertain", text: source[0].text, box: box, confidence: 0.1)
    precondition(MockScreenTranslator.translate([low]) == nil)
    let known = MockScreenTranslator.translateKnownBlocks(source + [low])
    precondition(known.count == source.count && known["uncertain"] == nil)
    precondition(known[source[0].id] == "Без батареи")
    print("PASS: exact synthetic corpus only; IDs/order/bbox preserved; numbers/negation; no partial fallback; unknown/injected/low-confidence rejected")
  }
}
