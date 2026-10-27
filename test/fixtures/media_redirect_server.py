"""Run the browser redirect regression against disposable loopback servers."""
import json
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

state = {"goodAuthorized": False, "sameOriginSinkHits": 0,
         "thirdPartyHits": 0, "thirdPartyAuthorized": False}

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", self.headers.get("Access-Control-Request-Headers", "Authorization,X-Warehouse-Protocol"))

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def do_GET(self):
        if self.server.third_party:
            state["thirdPartyHits"] += 1
            state["thirdPartyAuthorized"] |= bool(self.headers.get("Authorization"))
        if self.path == "/api/good":
            state["goodAuthorized"] = self.headers.get("Authorization") == "Bearer fixture-test-only"
            body = bytes([1, 2, 3])
        elif self.path in ("/api/redirect-same", "/api/redirect-cross"):
            self.send_response(302)
            self.cors()
            location = "/api/sink" if self.path.endswith("same") else f"http://127.0.0.1:{secondary.server_port}/sink"
            self.send_header("Location", location)
            self.end_headers()
            return
        elif self.path == "/api/sink":
            state["sameOriginSinkHits"] += 1
            body = b"unexpected redirect"
        elif self.path == "/stats":
            body = json.dumps(state).encode()
        else:
            body = b"unexpected request"
        self.send_response(200)
        self.cors()
        self.send_header("Content-Type", "application/json" if self.path == "/stats" else "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

primary = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
secondary = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
primary.third_party = False
secondary.third_party = True
for server in (primary, secondary):
    threading.Thread(target=server.serve_forever, daemon=True).start()
try:
    result = subprocess.run(["flutter", "test", "--no-pub", "--platform", "chrome",
        f"--dart-define=MEDIA_REDIRECT_TEST_ORIGIN=http://127.0.0.1:{primary.server_port}",
        "test/core/media/browser_media_redirect_test.dart"])
    print(json.dumps({"redirect_fixture": state, "exit_code": result.returncode}))
    raise SystemExit(result.returncode)
finally:
    for server in (primary, secondary):
        server.shutdown()
        server.server_close()
