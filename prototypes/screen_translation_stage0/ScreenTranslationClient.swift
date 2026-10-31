#if DEBUG || SCREEN_TRANSLATION_STAGE0 || SCREEN_TRANSLATION_LIVE
import Foundation

struct ScreenTranslationResult {
  let translations: [String: String]
  let modelVersion: String
  let promptVersion: String
  let glossaryVersion: String
  let cacheHits: Int
  let untranslatedBlockIDs: Set<String>
  var failureReasonCounts: [String: Int] = [:]
}

struct ScreenTranslationLease {
  let sessionID: UUID
  let expiresAt: Date
  let trialExpiresAt: Date
  let accessReason: String
}

enum ScreenTranslationClientError: Error, Equatable {
  case workerRequired, invalidEndpoint, invalidInput, busy, stopped
  case unauthorized, accessExpired, rateLimited(retryAfterSeconds: Int), timeout, network, cancelled
  case invalidResponse, providerUnavailable, configurationChanged
  case limitExceeded, unsupportedLanguage, invalidModelOutput

  var code: String {
    switch self {
    case .workerRequired: return "WORKER_REQUIRED"
    case .invalidEndpoint: return "INVALID_ENDPOINT"
    case .invalidInput: return "INVALID_INPUT"
    case .busy: return "BUSY"
    case .stopped: return "STOPPED"
    case .unauthorized: return "UNAUTHORIZED"
    case .accessExpired: return "ACCESS_EXPIRED"
    case .rateLimited: return "RATE_LIMITED"
    case .timeout: return "TIMEOUT"
    case .network: return "NETWORK"
    case .cancelled: return "CANCELLED"
    case .invalidResponse: return "INVALID_RESPONSE"
    case .providerUnavailable: return "PROVIDER_UNAVAILABLE"
    case .configurationChanged: return "CONFIGURATION_CHANGED"
    case .limitExceeded: return "LIMIT_EXCEEDED"
    case .unsupportedLanguage: return "UNSUPPORTED_LANGUAGE"
    case .invalidModelOutput: return "INVALID_MODEL_OUTPUT"
    }
  }
  var retryAfterSeconds: Double? {
    if case .rateLimited(let seconds) = self { return Double(seconds) }
    return nil
  }
}

@available(iOS 15.0, *)
final class ScreenTranslationClient {
  private struct Versions: Equatable, Hashable { let model: String; let prompt: String; let glossary: String }
  private struct Key: Hashable { let text: String; let context: String; let versions: Versions }
  private struct Entry { let text: String; let expires: TimeInterval; var access: UInt64; let cost: Int }
  private let endpoint: URL
  private let configuration: URLSessionConfiguration
  private let lock = NSLock()
  private var token: String
  private var stopped = false
  private var active: Transfer?
  private var cacheSession: UUID?
  private var versions: Versions?
  private var cache: [Key: Entry] = [:]
  private var cacheBytes = 0
  private var access: UInt64 = 0
  private var retryNotBefore: TimeInterval = 0
  private var responseFailureReason = ""
  private var stopRequests: Set<UUID> = []
  // Internal injection points for deterministic cache tests; production defaults remain bounded.
  var clock: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  var cacheTTL: TimeInterval = 300
  var cacheCapacity = 256
  var cacheByteLimit = 256 * 1024

  init(endpoint: URL, bearerToken: String, sessionConfiguration: URLSessionConfiguration? = nil) {
    self.endpoint = endpoint; token = bearerToken
    // Always create ephemeral storage. A supplied configuration injects test URLProtocols
    // only; it cannot switch production requests to a background/persistent session.
    let value = URLSessionConfiguration.ephemeral
    if let protocols = sessionConfiguration?.protocolClasses { value.protocolClasses = protocols }
    value.httpShouldSetCookies = false; value.httpCookieStorage = nil
    value.urlCache = nil; value.urlCredentialStorage = nil
    value.requestCachePolicy = .reloadIgnoringLocalCacheData
    value.httpAdditionalHeaders = nil
    configuration = value
  }

  /// A lease is acquired once on the bounded startup worker, not per frame/config fetch.
  func beginSession(sessionID: UUID, shouldStart: () -> Bool = { true }) throws -> ScreenTranslationLease {
    guard !Thread.isMainThread else { throw ScreenTranslationClientError.workerRequired }
    let url = try sessionEndpoint()
    let transfer = Transfer(origin: url)
    lock.lock()
    guard !stopped else { lock.unlock(); throw ScreenTranslationClientError.stopped }
    guard active == nil else { lock.unlock(); throw ScreenTranslationClientError.busy }
    guard shouldStart() else { lock.unlock(); throw ScreenTranslationClientError.cancelled }
    guard !token.isEmpty else { lock.unlock(); throw ScreenTranslationClientError.unauthorized }
    let bearer = token
    active = transfer
    lock.unlock()
    defer { lock.lock(); if active === transfer { active = nil }; lock.unlock() }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"; request.timeoutInterval = 8
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: ["sessionId": sessionID.uuidString])
    transfer.start(request, configuration: configuration)
    let (response, body) = try transfer.wait(milliseconds: 8000)
    try Self.checkSessionStatus(response, body: body)
    guard let value = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          Set(value.keys) == ["sessionId", "status", "expiresAt", "trialExpiresAt", "accessReason"],
          let returned = value["sessionId"] as? String, UUID(uuidString: returned) == sessionID,
          value["status"] as? String == "active", let reason = value["accessReason"] as? String,
          ["trial", "warehouse_activity"].contains(reason),
          let expiry = Self.leaseDate(value["expiresAt"]), let trialExpiry = Self.leaseDate(value["trialExpiresAt"]) else {
      throw ScreenTranslationClientError.invalidResponse
    }
    // Authority remains server-side. This only bounds a malicious/corrupt reply;
    // small device/server clock skew must not create an unbounded local session.
    let remaining = expiry.timeIntervalSinceNow
    guard remaining > -300, remaining <= 4 * 60 * 60 + 300 else { throw ScreenTranslationClientError.invalidResponse }
    try transfer.ensureNotCancelled()
    lock.lock(); let ended = stopped; lock.unlock()
    guard !ended else { throw ScreenTranslationClientError.stopped }
    return ScreenTranslationLease(sessionID: sessionID, expiresAt: expiry, trialExpiresAt: trialExpiry, accessReason: reason)
  }

  /// Call before stop(): auth is captured only in this bounded in-memory operation.
  /// Server revocation is best effort; cancellation/TTL still bound client/server lifetimes.
  func stopSession(sessionID: UUID) {
    guard let url = try? sessionEndpoint() else { return }
    lock.lock()
    guard !token.isEmpty, !stopRequests.contains(sessionID), stopRequests.count < 16 else { lock.unlock(); return }
    stopRequests.insert(sessionID)
    let bearer = token, configuration = configuration
    lock.unlock()
    DispatchQueue.global(qos: .utility).async {
      let transfer = Transfer(origin: url)
      var request = URLRequest(url: url)
      request.httpMethod = "POST"; request.timeoutInterval = 3
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
      request.httpBody = try? JSONSerialization.data(withJSONObject: ["sessionId": sessionID.uuidString, "action": "stop"])
      transfer.start(request, configuration: configuration)
      _ = try? transfer.wait(milliseconds: 3000)
    }
  }

  private func sessionEndpoint() throws -> URL {
    guard Self.secureOrigin(endpoint), endpoint.path == "/api/screen-translate/v1", endpoint.query == nil,
          endpoint.fragment == nil else { throw ScreenTranslationClientError.invalidEndpoint }
    return endpoint.deletingLastPathComponent().appendingPathComponent("session")
  }
  private static func leaseDate(_ raw: Any?) -> Date? {
    guard let string = raw as? String, string.utf8.count <= 64 else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: string) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: string)
  }
  private static func checkSessionStatus(_ response: HTTPURLResponse, body: Data) throws {
    if response.statusCode == 200 { return }
    if response.statusCode == 403, errorCode(body) == "ACCESS_EXPIRED" { throw ScreenTranslationClientError.accessExpired }
    switch response.statusCode {
    case 401, 403: throw ScreenTranslationClientError.unauthorized
    case 429: throw ScreenTranslationClientError.rateLimited(retryAfterSeconds: retryAfter(response))
    case 408, 504: throw ScreenTranslationClientError.timeout
    case 500...599: throw ScreenTranslationClientError.providerUnavailable
    default: throw ScreenTranslationClientError.invalidResponse
    }
  }
  private static func errorCode(_ body: Data) -> String? {
    let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
    return (json?["error"] as? [String: Any])?["code"] as? String
  }

  /// Blocking entry point: pipeline must call this on its bounded worker, never the UI thread.
  func translate(sessionID: UUID, frameID: UInt64, blocks: [OCRBlock], timeoutMs: Int = 8000, shouldStart: () -> Bool = { true }) throws -> ScreenTranslationResult {
    guard !Thread.isMainThread else { throw ScreenTranslationClientError.workerRequired }
    guard Self.secureOrigin(endpoint), endpoint.path == "/api/screen-translate/v1", endpoint.query == nil,
          endpoint.fragment == nil else { throw ScreenTranslationClientError.invalidEndpoint }
    let normalized = blocks.map { OCRText.normalize($0.text) }
    guard blocks.count <= 50, Set(blocks.map(\.id)).count == blocks.count,
          blocks.allSatisfy({ !$0.id.isEmpty && $0.id.utf8.count <= 128 }),
          normalized.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.count <= 1000 }), normalized.reduce(0, { $0 + $1.unicodeScalars.count }) <= 6000,
          timeoutMs > 0 else { throw ScreenTranslationClientError.invalidInput }
    // JSON array serialization avoids delimiter collisions and excludes bbox/IDs from context.
    let context = String(data: try JSONSerialization.data(withJSONObject: normalized), encoding: .utf8)!
    let transfer = Transfer(origin: endpoint)
    lock.lock()
    guard !stopped else { lock.unlock(); throw ScreenTranslationClientError.stopped }
    guard active == nil else { lock.unlock(); throw ScreenTranslationClientError.busy }
    guard shouldStart() else { lock.unlock(); throw ScreenTranslationClientError.cancelled }
    guard !token.isEmpty else { lock.unlock(); throw ScreenTranslationClientError.unauthorized }
    let retryRemaining = retryNotBefore - clock()
    guard retryRemaining <= 0 else {
      lock.unlock(); throw ScreenTranslationClientError.rateLimited(retryAfterSeconds: Int(ceil(retryRemaining)))
    }
    if cacheSession != sessionID { clearCache(); versions = nil; cacheSession = sessionID }
    responseFailureReason = ""
    active = transfer
    let bearer = token
    let knownVersions = versions
    let now = clock()
    removeExpired(now: now)
    var hits: [String: String] = [:]
    if let knownVersions {
      for (index, block) in blocks.enumerated() {
        let key = Key(text: normalized[index], context: context, versions: knownVersions)
        if var entry = cache[key] {
          access &+= 1; entry.access = access; cache[key] = entry; hits[block.id] = entry.text
        }
      }
    }
    lock.unlock()
    defer { lock.lock(); if active === transfer { active = nil }; lock.unlock() }
    if blocks.isEmpty || hits.count == blocks.count {
      try transfer.ensureNotCancelled()
      return ScreenTranslationResult(translations: hits, modelVersion: knownVersions?.model ?? "",
        promptVersion: knownVersions?.prompt ?? "", glossaryVersion: knownVersions?.glossary ?? "", cacheHits: hits.count, untranslatedBlockIDs: [])
    }
    let missing = blocks.enumerated().filter { hits[$0.element.id] == nil }
    let budget = min(8000, timeoutMs)
    // Allow transport/auth overhead beyond the bounded server translation budget.
    let transportBudget = budget + 2000
    let payload: [String: Any] = ["sessionId": sessionID.uuidString, "frameId": frameID,
      "sourceLanguage": "zh-Hans", "targetLanguage": "ru", "clientTimeoutMs": budget, "allowPartial": true,
      "blocks": missing.map { ["id": $0.element.id, "text": normalized[$0.offset]] }]
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"; request.timeoutInterval = Double(transportBudget) / 1000
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + bearer, forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    transfer.start(request, configuration: configuration)
    let (response, body) = try transfer.wait(milliseconds: transportBudget)
    if response.statusCode != 200,
       let errorBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
       let error = errorBody["error"] as? [String: Any], let code = error["code"] as? String,
       code == "INVALID_MODEL_OUTPUT" {
      let allowed: Set<String> = ["STRUCTURE", "IDS", "NUMBERS", "SKU", "UNITS", "MODEL_ENVELOPE", "MODEL_JSON"]
      if let reason = error["reason"] as? String, allowed.contains(reason) {
        lock.lock(); responseFailureReason = reason; lock.unlock()
      }
      throw ScreenTranslationClientError.invalidModelOutput
    }
    if response.statusCode == 403, Self.errorCode(body) == "ACCESS_EXPIRED" {
      throw ScreenTranslationClientError.accessExpired
    }
    switch response.statusCode {
    case 200: break
    case 401, 403: throw ScreenTranslationClientError.unauthorized
    case 429:
      let seconds = Self.retryAfter(response)
      lock.lock(); retryNotBefore = clock() + Double(seconds); lock.unlock()
      throw ScreenTranslationClientError.rateLimited(retryAfterSeconds: seconds)
    case 408, 504: throw ScreenTranslationClientError.timeout
    case 500...599: throw ScreenTranslationClientError.providerUnavailable
    default:
      if let errorBody = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
         errorBody["status"] as? String == "error", let error = errorBody["error"] as? [String: Any],
         let code = error["code"] as? String {
        switch code {
        case "LIMIT_EXCEEDED": throw ScreenTranslationClientError.limitExceeded
        case "UNSUPPORTED_LANGUAGE": throw ScreenTranslationClientError.unsupportedLanguage
        case "INVALID_MODEL_OUTPUT": throw ScreenTranslationClientError.invalidModelOutput
        case "INVALID_INPUT": throw ScreenTranslationClientError.invalidInput
        case "UNAUTHORIZED": throw ScreenTranslationClientError.unauthorized
        case "TIMEOUT": throw ScreenTranslationClientError.timeout
        case "PROVIDER_UNAVAILABLE": throw ScreenTranslationClientError.providerUnavailable
        default: break
        }
      }
      throw ScreenTranslationClientError.invalidResponse
    }
    let expectedKeys: Set<String> = ["sessionId", "frameId", "status", "translations", "provider", "modelVersion", "promptVersion", "glossaryVersion", "requestId"]
    guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let responseStatus = json["status"] as? String, ["ok", "partial"].contains(responseStatus),
          Set(json.keys) == (responseStatus == "partial" ? expectedKeys.union(["failedBlocks"]) : expectedKeys),
          let returnedSession = json["sessionId"] as? String, UUID(uuidString: returnedSession) == sessionID,
          let returnedFrame = json["frameId"] as? NSNumber,
          CFGetTypeID(returnedFrame) != CFBooleanGetTypeID(), returnedFrame.stringValue == String(frameID),
          let rows = json["translations"] as? [[String: Any]], rows.count <= missing.count else {
      throw ScreenTranslationClientError.invalidResponse
    }
    func version(_ name: String) throws -> String {
      guard let value = json[name] as? String, !value.isEmpty, value.utf8.count <= 256 else {
        throw ScreenTranslationClientError.invalidResponse
      }
      return value
    }
    let received = try Versions(model: version("modelVersion"), prompt: version("promptVersion"), glossary: version("glossaryVersion"))
    _ = try version("provider"); _ = try version("requestId")
    let source = Dictionary(uniqueKeysWithValues: missing.map { ($0.element.id, normalized[$0.offset]) })
    var translated: [String: String] = [:]
    var responseCharacters = 0
    for row in rows {
      guard Set(row.keys) == ["id", "text"], let id = row["id"] as? String, let original = source[id],
            translated[id] == nil, let text = row["text"] as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.unicodeScalars.count <= 4096,
            Self.preservesOriginalNumbers(original, in: text) else { throw ScreenTranslationClientError.invalidResponse }
      responseCharacters += text.unicodeScalars.count
      guard responseCharacters <= 18000 else { throw ScreenTranslationClientError.invalidResponse }
      translated[id] = text
    }
    var untranslatedIDs: Set<String> = []
    var failureReasonCounts: [String: Int] = [:]
    if responseStatus == "partial" {
      let allowedReasons: Set<String> = ["STRUCTURE", "IDS", "NUMBERS", "SKU", "UNITS", "MODEL_ENVELOPE", "MODEL_JSON"]
      guard let failed = json["failedBlocks"] as? [[String: Any]], !failed.isEmpty,
            failed.count + translated.count == source.count else { throw ScreenTranslationClientError.invalidResponse }
      for failure in failed {
        let keys = Set(failure.keys)
        guard keys == ["id", "code"] || keys == ["id", "code", "reason"],
              let id = failure["id"] as? String, source[id] != nil, translated[id] == nil,
              !untranslatedIDs.contains(id), failure["code"] as? String == "INVALID_MODEL_OUTPUT" else {
          throw ScreenTranslationClientError.invalidResponse
        }
        if let reason = failure["reason"] {
          guard let reason = reason as? String, allowedReasons.contains(reason) else { throw ScreenTranslationClientError.invalidResponse }
        }
        failureReasonCounts[failure["reason"] as? String ?? "UNSPECIFIED", default: 0] += 1
        untranslatedIDs.insert(id)
      }
    }
    guard translated.count + untranslatedIDs.count == source.count else { throw ScreenTranslationClientError.invalidResponse }
    try transfer.ensureNotCancelled()
    lock.lock()
    defer { lock.unlock() }
    guard !stopped else { throw ScreenTranslationClientError.stopped }
    try transfer.ensureNotCancelled()
    if let old = versions, old != received {
      clearCache(); versions = received
      if !hits.isEmpty { throw ScreenTranslationClientError.configurationChanged }
    }
    versions = received
    for (index, block) in blocks.enumerated() {
      guard let text = translated[block.id] else { continue }
      let key = Key(text: normalized[index], context: context, versions: received)
      insert(text, key: key, now: clock())
    }
    return ScreenTranslationResult(translations: hits.merging(translated, uniquingKeysWith: { _, new in new }),
      modelVersion: received.model, promptVersion: received.prompt, glossaryVersion: received.glossary, cacheHits: hits.count, untranslatedBlockIDs: untranslatedIDs, failureReasonCounts: failureReasonCounts)
  }

  func failureReason() -> String { lock.lock(); defer { lock.unlock() }; return responseFailureReason }

  func cancel() { lock.lock(); let pending = active; lock.unlock(); pending?.cancel() }
  func stop() {
    lock.lock(); stopped = true; token = ""; clearCache(); versions = nil; cacheSession = nil
    let pending = active; lock.unlock(); pending?.cancel()
  }
  deinit { stop() }

  private func clearCache() { cache.removeAll(); cacheBytes = 0 }
  private func removeExpired(now: TimeInterval) {
    for (key, entry) in cache where entry.expires <= now { cache.removeValue(forKey: key); cacheBytes -= entry.cost }
  }
  private func insert(_ text: String, key: Key, now: TimeInterval) {
    if let old = cache.removeValue(forKey: key) { cacheBytes -= old.cost }
    let cost = text.utf8.count + key.text.utf8.count + key.context.utf8.count +
      key.versions.model.utf8.count + key.versions.prompt.utf8.count + key.versions.glossary.utf8.count + 128
    guard cost <= cacheByteLimit, cacheCapacity > 0 else { return }
    access &+= 1
    cache[key] = Entry(text: text, expires: now + min(300, max(0, cacheTTL)), access: access, cost: cost); cacheBytes += cost
    while cache.count > min(256, cacheCapacity) || cacheBytes > min(256 * 1024, cacheByteLimit) {
      guard let oldest = cache.min(by: { $0.value.access < $1.value.access }) else { break }
      cache.removeValue(forKey: oldest.key); cacheBytes -= oldest.value.cost
    }
  }
  private static func secureOrigin(_ url: URL) -> Bool {
    url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.password == nil
  }
  private static func numbers(_ text: String) -> [String] {
    let expression = try! NSRegularExpression(pattern: "\\p{Nd}+")
    let value = text as NSString
    return expression.matches(in: text, range: NSRange(location: 0, length: value.length)).map {
      value.substring(with: $0.range).compactMap(\.wholeNumberValue).map(String.init).joined()
    }
  }
  // Source literals must survive; valid translation may introduce digits from
  // written Chinese numerals or technical terms (e.g. 二维 -> 2D).
  private static func preservesOriginalNumbers(_ source: String, in translated: String) -> Bool {
    var counts: [String: Int] = [:]
    for value in numbers(translated) { counts[value, default: 0] += 1 }
    for value in numbers(source) {
      guard counts[value, default: 0] > 0 else { return false }
      counts[value, default: 0] -= 1
    }
    return true
  }
  private static func retryAfter(_ response: HTTPURLResponse) -> Int {
    guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return 1 }
    if let seconds = Double(raw), seconds.isFinite { return Int(min(60, max(0, ceil(seconds)))) }
    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
    guard let date = formatter.date(from: raw) else { return 1 }
    return Int(min(60, max(0, ceil(date.timeIntervalSinceNow))))
  }

  private final class Transfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let origin: URL
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var outcome: Result<(HTTPURLResponse, Data), ScreenTranslationClientError>?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var cancellation = false
    init(origin: URL) { self.origin = origin }
    func start(_ request: URLRequest, configuration: URLSessionConfiguration) {
      lock.lock()
      guard outcome == nil else { lock.unlock(); return }
      let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
      self.session = session
      let task = session.dataTask(with: request); self.task = task
      lock.unlock(); task.resume()
    }
    func wait(milliseconds: Int) throws -> (HTTPURLResponse, Data) {
      if semaphore.wait(timeout: .now() + .milliseconds(milliseconds)) == .timedOut { finish(.failure(.timeout)) }
      lock.lock(); let result = outcome!; lock.unlock()
      return try result.get()
    }
    func ensureNotCancelled() throws {
      lock.lock(); let value = cancellation; lock.unlock()
      if value { throw ScreenTranslationClientError.cancelled }
    }
    func cancel() { lock.lock(); cancellation = true; lock.unlock(); finish(.failure(.cancelled)) }
    private func finish(_ result: Result<(HTTPURLResponse, Data), ScreenTranslationClientError>) {
      lock.lock()
      guard outcome == nil else { lock.unlock(); return }
      outcome = result; let session = self.session; self.session = nil; task = nil
      lock.unlock(); semaphore.signal(); session?.invalidateAndCancel()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
      guard let http = response as? HTTPURLResponse, response.expectedContentLength <= 128 * 1024 else {
        completionHandler(.cancel); finish(.failure(.invalidResponse)); return
      }
      lock.lock(); self.response = http; let done = outcome != nil; lock.unlock()
      completionHandler(done ? .cancel : .allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
      lock.lock()
      guard outcome == nil else { lock.unlock(); return }
      guard chunk.count <= 128 * 1024 - data.count else { lock.unlock(); finish(.failure(.invalidResponse)); return }
      data.append(chunk); lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
      lock.lock(); let response = self.response, body = data; lock.unlock()
      if let error = error as? URLError {
        finish(.failure(error.code == .timedOut ? .timeout : (error.code == .cancelled ? .cancelled : .network)))
      } else if error != nil { finish(.failure(.network)) }
      else if let response { finish(.success((response, body))) }
      else { finish(.failure(.invalidResponse)) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
      guard let url = request.url, ScreenTranslationClient.secureOrigin(url),
            url.host?.lowercased() == origin.host?.lowercased(), (url.port ?? 443) == (origin.port ?? 443) else {
        completionHandler(nil); finish(.failure(.invalidResponse)); return
      }
      completionHandler(request)
    }
  }
}
#endif
