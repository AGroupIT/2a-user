import Foundation

final class MockTranslationProtocol: URLProtocol, @unchecked Sendable {
  static let lock = NSLock()
  static var handler: ((MockTranslationProtocol) -> Void)?
  static var calls = 0
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock(); Self.calls += 1; let handler = Self.handler; Self.lock.unlock()
    handler?(self)
  }
  override func stopLoading() { }
  func respond(status: Int = 200, headers: [String: String] = [:], chunks: [Data]) {
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
      httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
    for chunk in chunks { client?.urlProtocol(self, didLoad: chunk) }
    client?.urlProtocolDidFinishLoading(self)
  }
  func payload() -> [String: Any] {
    if let body = request.httpBody { return try! JSONSerialization.jsonObject(with: body) as! [String: Any] }
    let stream = request.httpBodyStream!; stream.open(); defer { stream.close() }
    var data = Data(); var bytes = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength: bytes.count); if count <= 0 { break }; data.append(contentsOf: bytes.prefix(count)) }
    return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
  }
  func success(version: String = "model-v1", edit: ((inout [String: Any]) -> Void)? = nil) {
    let p = payload()
    let blocks = p["blocks"] as! [[String: String]]
    var result: [String: Any] = ["sessionId": p["sessionId"]!, "frameId": p["frameId"]!, "status": "ok",
      "translations": blocks.map { ["id": $0["id"]!, "text": "Перевод " + $0["text"]!] },
      "provider": "synthetic", "modelVersion": version, "promptVersion": "prompt-v1", "glossaryVersion": "none-v1", "requestId": "test-request"]
    edit?(&result)
    respond(chunks: [try! JSONSerialization.data(withJSONObject: result)])
  }
}

@main
struct ScreenTranslationClientTests {
  final class Box<T>: @unchecked Sendable {
    let lock = NSLock(); var value: T?
    func set(_ value: T) { lock.lock(); self.value = value; lock.unlock() }
    func get() -> T { lock.lock(); defer { lock.unlock() }; return value! }
  }
  static func main() throws {
    let endpoint = URL(string: "https://screen-translate.invalid/api/screen-translate/v1")!
    let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [MockTranslationProtocol.self]
    func client() -> ScreenTranslationClient { ScreenTranslationClient(endpoint: endpoint, bearerToken: "synthetic-test-token", sessionConfiguration: configuration) }
    func block(_ id: String, _ text: String) -> OCRBlock { OCRBlock(id: id, text: text, box: OCRBox(x: 0, y: 0, width: 1, height: 1), confidence: 1) }
    let session = UUID()
    let a = block("a", "商品30"), b = block("b", "电池20"), c = block("c", "规格10")
    func install(_ handler: @escaping (MockTranslationProtocol) -> Void) {
      MockTranslationProtocol.lock.lock(); MockTranslationProtocol.handler = handler; MockTranslationProtocol.calls = 0; MockTranslationProtocol.lock.unlock()
    }
    func calls() -> Int { MockTranslationProtocol.lock.lock(); defer { MockTranslationProtocol.lock.unlock() }; return MockTranslationProtocol.calls }
    func work<T>(_ action: @escaping () throws -> T) -> Result<T, Error> {
      let result = Box<Result<T, Error>>(), done = DispatchSemaphore(value: 0)
      DispatchQueue.global().async { result.set(Result { try action() }); done.signal() }
      precondition(done.wait(timeout: .now() + 4) == .success, "Worker did not terminate")
      return result.get()
    }
    func expect<T>(_ error: ScreenTranslationClientError, _ action: @escaping () throws -> T) {
      switch work(action) {
      case .success: preconditionFailure("Expected \(error.code)")
      case .failure(let actual): precondition(actual as? ScreenTranslationClientError == error, "Wrong typed error")
      }
    }
    func leaseReply(_ mock: MockTranslationProtocol, edit: ((inout [String: Any]) -> Void)? = nil) {
      let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      var value: [String: Any] = ["sessionId": session.uuidString, "status": "active",
        "expiresAt": formatter.string(from: Date().addingTimeInterval(3600)),
        "trialExpiresAt": formatter.string(from: Date().addingTimeInterval(14 * 86400)), "accessReason": "trial"]
      edit?(&value)
      mock.respond(chunks: [try! JSONSerialization.data(withJSONObject: value)])
    }
    install { mock in
      precondition(mock.request.url?.path == "/api/screen-translate/session")
      precondition(mock.payload() as NSDictionary == ["sessionId": session.uuidString] as NSDictionary)
      precondition(mock.request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token")
      leaseReply(mock)
    }
    let leaseClient = client()
    let lease = try work { try leaseClient.beginSession(sessionID: session) }.get()
    precondition(lease.sessionID == session && lease.accessReason == "trial" && lease.expiresAt > Date())
    for edit in [
      { (value: inout [String: Any]) in value["sessionId"] = UUID().uuidString },
      { value in value["extra"] = "unexpected" },
      { value in value["expiresAt"] = "" },
      { value in value["status"] = "stopped" },
      { value in value["accessReason"] = "arbitrary" },
      { value in value["trialExpiresAt"] = 123 },
      { value in value["expiresAt"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(5 * 3600)) },
    ] {
      install { mock in leaseReply(mock, edit: edit) }
      expect(.invalidResponse) { try client().beginSession(sessionID: session) }
    }
    install { mock in leaseReply(mock, edit: { value in
      value["accessReason"] = "warehouse_activity"
      value["trialExpiresAt"] = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-30 * 86400))
    }) }
    let warehouseLease = try work { try client().beginSession(sessionID: session) }.get()
    precondition(warehouseLease.accessReason == "warehouse_activity")
    for (status, code, expected) in [(403, "ACCESS_EXPIRED", ScreenTranslationClientError.accessExpired),
                                   (401, "UNAUTHORIZED", .unauthorized), (403, "UNAUTHORIZED", .unauthorized)] {
      install { $0.respond(status: status, chunks: [try! JSONSerialization.data(withJSONObject: ["status": "error", "error": ["code": code]])]) }
      expect(expected) { try client().beginSession(sessionID: session) }
      expect(expected) { try client().translate(sessionID: session, frameID: 9000, blocks: [a]) }
    }
    let revoked = DispatchSemaphore(value: 0)
    install { mock in
      precondition(mock.payload() as NSDictionary == ["sessionId": session.uuidString, "action": "stop"] as NSDictionary)
      precondition(mock.request.url?.path == "/api/screen-translate/session")
      precondition(mock.request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token")
      mock.respond(chunks: [try! JSONSerialization.data(withJSONObject: ["sessionId": session.uuidString, "status": "stopped"])])
      revoked.signal()
    }
    let stopping = client(); stopping.stopSession(sessionID: session); stopping.stopSession(sessionID: session); stopping.stop()
    precondition(revoked.wait(timeout: .now() + 2) == .success)
    precondition(calls() == 1, "Best-effort stop must retain captured auth without duplicate requests")
    let leaseStarted = DispatchSemaphore(value: 0), leaseDone = DispatchSemaphore(value: 0)
    let cancellationResult = Box<Result<ScreenTranslationLease, Error>>()
    install { _ in leaseStarted.signal() }
    let cancellingLease = client()
    DispatchQueue.global().async {
      cancellationResult.set(Result { try cancellingLease.beginSession(sessionID: session) }); leaseDone.signal()
    }
    precondition(leaseStarted.wait(timeout: .now() + 2) == .success)
    cancellingLease.cancel()
    precondition(leaseDone.wait(timeout: .now() + 1) == .success)
    if case .failure(let error) = cancellationResult.get() { precondition(error as? ScreenTranslationClientError == .cancelled) }
    else { preconditionFailure("Cancelled startup must not return a valid lease") }
    install { mock in
      let p = mock.payload()
      precondition(Set(p.keys) == ["sessionId", "frameId", "sourceLanguage", "targetLanguage", "clientTimeoutMs", "blocks", "allowPartial"])
      precondition(p["allowPartial"] as? Bool == true)
      precondition(p["sourceLanguage"] as? String == "zh-Hans" && p["targetLanguage"] as? String == "ru")
      precondition(mock.request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token")
      let rows = p["blocks"] as! [[String: String]]
      precondition(rows.allSatisfy { Set($0.keys) == ["id", "text"] })
      mock.success()
    }
    let cancelledBeforeStart = client()
    expect(.cancelled) { try cancelledBeforeStart.translate(sessionID: session, frameID: 1, blocks: [a], shouldStart: { false }) }
    precondition(calls() == 0, "Invalidated work must never start HTTP")
    let cached = client()
    var now: TimeInterval = 100; cached.clock = { now }
    let first = try work { try cached.translate(sessionID: session, frameID: 1, blocks: [a, b]) }.get()
    precondition(first.cacheHits == 0 && first.translations.count == 2)
    let changedIDs = [block("new-a", "商品30"), block("new-b", "电池20")]
    let reused = try work { try cached.translate(sessionID: session, frameID: 2, blocks: changedIDs) }.get()
    precondition(reused.cacheHits == 2 && reused.translations["new-a"] == first.translations["a"] && calls() == 1)
    now = 401
    let expired = try work { try cached.translate(sessionID: session, frameID: 3, blocks: [a, b]) }.get()
    precondition(expired.cacheHits == 0)
    precondition(calls() == 2)
    _ = try work { try cached.translate(sessionID: session, frameID: 4, blocks: [a]) }.get()
    precondition(calls() == 3, "Different whole-screen context must miss")
    let beforeEmpty = calls()
    let empty = try work { try cached.translate(sessionID: session, frameID: 5, blocks: []) }.get()
    precondition(empty.translations.isEmpty)
    precondition(calls() == beforeEmpty)
    let lru = client(); lru.cacheCapacity = 2
    _ = try work { try lru.translate(sessionID: session, frameID: 6, blocks: [a, b, c]) }.get()
    let partial = try work { try lru.translate(sessionID: session, frameID: 7, blocks: [a, b, c]) }.get()
    precondition(partial.cacheHits == 2 && partial.translations.count == 3)
    install { $0.success(version: "model-v2") }
    expect(.configurationChanged) { try lru.translate(sessionID: session, frameID: 8, blocks: [a, b, c]) }
    let newVersion = try work { try lru.translate(sessionID: session, frameID: 9, blocks: [a, b, c]) }.get()
    precondition(newVersion.modelVersion == "model-v2" && newVersion.cacheHits == 0)
    install { $0.success() }
    let byteBounded = client(); byteBounded.cacheByteLimit = 1
    _ = try work { try byteBounded.translate(sessionID: session, frameID: 10, blocks: [a]) }.get()
    let byteMiss = try work { try byteBounded.translate(sessionID: session, frameID: 11, blocks: [a]) }.get()
    precondition(byteMiss.cacheHits == 0)
    precondition(calls() == 2)
    install { mock in
      let rows = mock.payload()["blocks"] as! [[String: String]]
      if rows.count == 2 {
        mock.success(edit: { body in
          body["status"] = "partial"
          body["translations"] = (body["translations"] as! [[String: String]]).filter { $0["id"] == "a" }
          body["failedBlocks"] = [["id": "b", "code": "INVALID_MODEL_OUTPUT", "reason": "NUMBERS"]]
        })
      } else { precondition(rows[0]["id"] == "b"); mock.success() }
    }
    let partialClient = client()
    let partialResult = try work { try partialClient.translate(sessionID: session, frameID: 1000, blocks: [a, b]) }.get()
    precondition(partialResult.untranslatedBlockIDs == ["b"] && partialResult.translations["a"] != nil && partialResult.translations["b"] == nil)
    precondition(partialResult.failureReasonCounts == ["NUMBERS": 1])
    let repaired = try work { try partialClient.translate(sessionID: session, frameID: 1001, blocks: [a, b]) }.get()
    precondition(repaired.failureReasonCounts.isEmpty)
    precondition(repaired.untranslatedBlockIDs.isEmpty && repaired.translations.count == 2 && repaired.cacheHits == 1)
    for badID in ["a", "foreign"] {
      install { mock in mock.success(edit: { body in
        body["status"] = "partial"
        body["translations"] = (body["translations"] as! [[String: String]]).filter { $0["id"] == "a" }
        body["failedBlocks"] = [["id": badID, "code": "INVALID_MODEL_OUTPUT", "reason": "NUMBERS"]]
      }) }
      expect(.invalidResponse) { try client().translate(sessionID: session, frameID: 1002, blocks: [a, b]) }
    }
    install { mock in mock.success(edit: { body in
      body["status"] = "partial"; body["failedBlocks"] = [[String: String]]()
    }) }
    expect(.invalidResponse) { try client().translate(sessionID: session, frameID: 1003, blocks: [a, b]) }
    install { $0.respond(status: 401, chunks: []) }
    let unauthorized = client(); expect(.unauthorized) { try unauthorized.translate(sessionID: session, frameID: 12, blocks: [a]) }
    install { $0.respond(status: 429, headers: ["Retry-After": "120"], chunks: []) }
    let limited = client(); expect(.rateLimited(retryAfterSeconds: 60)) { try limited.translate(sessionID: session, frameID: 13, blocks: [a]) }
    expect(.rateLimited(retryAfterSeconds: 60)) { try limited.translate(sessionID: session, frameID: 130, blocks: [a]) }
    precondition(calls() == 1, "Retry-After cooldown must prevent a second request")
    install { request in
      let payload = request.payload()
      precondition(payload["clientTimeoutMs"] as? Int == 8000)
      precondition(request.request.timeoutInterval == 10)
      request.success()
    }
    _ = try work { try client().translate(sessionID: session, frameID: 131, blocks: [a]) }.get()
    install { $0.respond(status: 502, chunks: [Data("{\"status\":\"error\",\"error\":{\"code\":\"INVALID_MODEL_OUTPUT\",\"reason\":\"NUMBERS\"}}".utf8)]) }
    let invalidModel = client(); expect(.invalidModelOutput) { try invalidModel.translate(sessionID: session, frameID: 132, blocks: [a]) }
    precondition(invalidModel.failureReason() == "NUMBERS")
    install { $0.respond(status: 503, chunks: []) }
    let unavailable = client(); expect(.providerUnavailable) { try unavailable.translate(sessionID: session, frameID: 14, blocks: [a]) }
    install { $0.success(edit: { $0["frameId"] = 999 }) }
    let wrongFrame = client(); expect(.invalidResponse) { try wrongFrame.translate(sessionID: session, frameID: 15, blocks: [a]) }
    install { $0.success(edit: { $0["translations"] = [["id": "a", "text": "Товар31"]] }) }
    let wrongDigits = client(); expect(.invalidResponse) { try wrongDigits.translate(sessionID: session, frameID: 16, blocks: [a]) }
    install { $0.success(edit: { $0["translations"] = [["id": "a", "text": "Товар30"], ["id": "a", "text": "Товар20"]] }) }
    let duplicate = client(); expect(.invalidResponse) { try duplicate.translate(sessionID: session, frameID: 17, blocks: [a, b]) }
    install { $0.success(edit: { $0["command"] = "synthetic forbidden field" }) }
    let extra = client(); expect(.invalidResponse) { try extra.translate(sessionID: session, frameID: 18, blocks: [a]) }
    install { $0.respond(chunks: [Data(repeating: 65, count: 80000), Data(repeating: 65, count: 80000)]) }
    let oversized = client(); expect(.invalidResponse) { try oversized.translate(sessionID: session, frameID: 19, blocks: [a]) }
    install { $0.client?.urlProtocol($0, didFailWithError: URLError(.notConnectedToInternet)) }
    let offline = client(); expect(.network) { try offline.translate(sessionID: session, frameID: 20, blocks: [a]) }
    install { _ in }
    for (source, translated) in [("二维扫码 1234", "2D-сканер 1234"), ("数量两件", "Количество 2 шт."),
                                   ("优惠100元减20元", "Скидка 20 при покупке от 100")] {
      install { mock in mock.success(edit: { $0["translations"] = [["id": "numeric", "text": translated]] }) }
      let checked = try work { try client().translate(sessionID: session, frameID: 2000, blocks: [block("numeric", source)]) }.get()
      precondition(checked.translations["numeric"] == translated)
    }
    for (source, translated) in [("价格1234", "Цена 1235"), ("数量2和2", "Количество 2")] {
      install { mock in mock.success(edit: { $0["translations"] = [["id": "numeric", "text": translated]] }) }
      expect(.invalidResponse) { try client().translate(sessionID: session, frameID: 2001, blocks: [block("numeric", source)]) }
    }
    install { _ in }
    let timeout = client(); expect(.timeout) { try timeout.translate(sessionID: session, frameID: 21, blocks: [a], timeoutMs: 30) }
    let started = DispatchSemaphore(value: 0), done = DispatchSemaphore(value: 0)
    let cancellation = Box<Result<ScreenTranslationResult, Error>>()
    install { _ in started.signal() }
    let cancellable = client()
    DispatchQueue.global().async {
      cancellation.set(Result { try cancellable.translate(sessionID: session, frameID: 22, blocks: [a], timeoutMs: 3000) }); done.signal()
    }
    precondition(started.wait(timeout: .now() + 2) == .success)
    cancellable.cancel()
    precondition(done.wait(timeout: .now() + 0.2) == .success, "Cancellation must wake worker immediately")
    if case .failure(let error) = cancellation.get() { precondition(error as? ScreenTranslationClientError == .cancelled) }
    else { preconditionFailure("Cancelled call succeeded") }
    cancellable.stop()
    expect(.stopped) { try cancellable.translate(sessionID: session, frameID: 23, blocks: [a]) }
    let insecure = ScreenTranslationClient(endpoint: URL(string: "http://screen-translate.invalid/api/screen-translate/v1")!, bearerToken: "synthetic")
    expect(.invalidEndpoint) { try insecure.translate(sessionID: session, frameID: 24, blocks: [a]) }
    precondition(ScreenTranslationClientError.rateLimited(retryAfterSeconds: 3).retryAfterSeconds == 3)
    print("PASS: bounded HTTP contract; session/frame/IDs/numbers/extra-field guards; TTL/context/version/LRU/bytes; no empty calls; errors; streaming cap; immediate cancellation; stop; HTTPS")
  }
}
