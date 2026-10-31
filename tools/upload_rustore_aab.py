#!/usr/bin/env python3
"""Upload one validated 2A User AAB to a new RuStore draft. Never delete/submit.

Credentials exist only in memory and the existing private-key file. The report
contains version/artifact/draft metadata only. No automatic mutation retries.
"""
import argparse
import base64
import datetime as dt
import hashlib
import ssl
import json
import pathlib
import re
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile

API = 'https://public-api-m.rustore.ru'
CA_BUNDLE = pathlib.Path(__file__).resolve().parent / 'certs/rustore-request-ca.pem'
# Public certificates from the URLs in RuStore's migration documentation.
# This CA applies only to RuStore requests; never install it into global trust.
TLS_CONTEXT = ssl.create_default_context(cafile=str(CA_BUNDLE))
PACKAGE = 'com.twoalogistic.user'
KEY_ID = 2351027924
ANDROID_NS = 'http://schemas.android.com/apk/res/android'


def fail(code):
    raise RuntimeError(code)


def proto_fields(data):
    offset = 0
    def varint():
        nonlocal offset
        value = 0
        for shift in range(0, 70, 7):
            if offset >= len(data): fail('INVALID_MANIFEST_PROTO')
            byte = data[offset]; offset += 1
            value |= (byte & 127) << shift
            if byte < 128: return value
        fail('INVALID_MANIFEST_PROTO')
    while offset < len(data):
        tag = varint(); field, wire = tag >> 3, tag & 7
        if not field: fail('INVALID_MANIFEST_PROTO')
        if wire == 0: value = varint()
        elif wire in (1, 2, 5):
            length = varint() if wire == 2 else 8 if wire == 1 else 4
            if length > len(data) - offset: fail('INVALID_MANIFEST_PROTO')
            value = data[offset:offset + length]; offset += length
        else: fail('INVALID_MANIFEST_PROTO')
        yield field, wire, value


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''): digest.update(chunk)
    return digest.hexdigest()


def manifest_version(path):
    with zipfile.ZipFile(path) as bundle:
        info = bundle.getinfo('base/manifest/AndroidManifest.xml')
        if info.file_size > 4 * 1024 * 1024: fail('MANIFEST_TOO_LARGE')
        data = bundle.read(info)
    roots = [v for f, w, v in proto_fields(data) if f == 1 and w == 2]
    if len(roots) != 1: fail('INVALID_MANIFEST_ROOT')
    fields = list(proto_fields(roots[0]))
    if [v for f, w, v in fields if f == 3 and w == 2] != [b'manifest']:
        fail('INVALID_MANIFEST_ROOT')
    result = {}
    for field, wire, value in fields:
        if field != 4 or wire != 2: continue
        attrs = list(proto_fields(value))
        def string(key):
            vals = [v for f, w, v in attrs if f == key and w == 2]
            if len(vals) > 1: fail('DUPLICATE_MANIFEST_ATTRIBUTE')
            return vals[0].decode('utf-8') if vals else ''
        name, ns = string(2), string(1)
        if (name == 'package' and not ns) or (name in ('versionName', 'versionCode') and ns == ANDROID_NS):
            if name in result: fail('DUPLICATE_MANIFEST_ATTRIBUTE')
            result[name] = string(3)
    if set(result) != {'package', 'versionName', 'versionCode'}: fail('VERSION_METADATA_MISSING')
    if not re.fullmatch(r'[1-9][0-9]*', result['versionCode']): fail('INVALID_VERSION_CODE')
    return result['package'], result['versionName'], int(result['versionCode'])


def api_json(path, token=None, payload=None):
    headers = {'Accept': 'application/json'}
    if token: headers['Public-Token'] = token
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode()
        headers['Content-Type'] = 'application/json'
    try:
        with urllib.request.urlopen(urllib.request.Request(API + path, data=data, headers=headers), timeout=40, context=TLS_CONTEXT) as response:
            content = response.read(4 * 1024 * 1024 + 1)
        if len(content) > 4 * 1024 * 1024: fail('API_RESPONSE_TOO_LARGE')
        value = json.loads(content)
    except urllib.error.HTTPError as error:
        fail('API_HTTP_' + str(error.code))
    if not isinstance(value, dict) or value.get('code') != 'OK':
        code = value.get('code', 'INVALID_RESPONSE') if isinstance(value, dict) else 'INVALID_RESPONSE'
        code = code if isinstance(code, str) and re.fullmatch(r'[A-Z0-9_]{1,80}', code) else 'API_ERROR'
        fail(code)
    return value.get('body')


class UploadFailure(RuntimeError):
    def __init__(self, code, provider):
        super().__init__(code)
        self.provider = provider


def safe_provider_error(raw, token):
    # Keep only bounded human diagnostics; never headers, raw payloads or tokens.
    text = raw[:65536].decode('utf-8', 'replace')
    try:
        value = json.loads(text)
    except Exception:
        value = {'message': text}
    if not isinstance(value, dict): value = {'message': str(value)}
    safe = {}
    for key in ('code', 'message', 'errorCode', 'errorMessage'):
        item = value.get(key)
        if not isinstance(item, (str, int)): continue
        item = str(item).replace(token, '[redacted]') if token else str(item)
        item = re.sub(r'https?://[^\s?]+\?[^\s]+', '[URL query redacted]', item)
        item = re.sub(r'[A-Za-z0-9_-]{80,}(?:\.[A-Za-z0-9_-]{10,})*', '[redacted]', item)
        item = ''.join(c for c in item if c in '\n\t' or ord(c) >= 32)
        safe[key] = item[:2048]
    if len(raw) > 65536: safe['truncated'] = True
    return safe


def upload(path, version_id, token):
    # Curl streams the file; Public-Token is stdin-only, never a command argument.
    config = 'header = ' + json.dumps('Public-Token: ' + token) + '\n'
    response = subprocess.run([
        'curl', '--config', '-', '--cacert', str(CA_BUNDLE), '--silent', '--show-error',
        '--max-time', '840', '--write-out', '\n%{http_code}', '--request', 'POST',
        f'{API}/public/v1/application/{PACKAGE}/version/{version_id}/aab',
        '--form', 'file=@' + str(path),
    ], input=config, text=True, capture_output=True, timeout=865)
    raw, separator, status = response.stdout.rpartition('\n')
    if response.returncode or not separator or not status.isdigit():
        raise UploadFailure('UPLOAD_TRANSPORT_ERROR', {'curlExit': response.returncode})
    if len(raw) > 4 * 1024 * 1024: fail('UPLOAD_RESPONSE_TOO_LARGE')
    if not 200 <= int(status) < 300:
        raise UploadFailure('UPLOAD_HTTP_' + status, safe_provider_error(raw.encode(), token))
    parsed = json.loads(raw)
    if parsed.get('code') != 'OK':
        raise UploadFailure('UPLOAD_API_ERROR', safe_provider_error(raw.encode(), token))


def write_report(path, report):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    temp.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aab', type=pathlib.Path, required=True)
    parser.add_argument('--version-name', required=True)
    parser.add_argument('--version-code', type=int, required=True)
    parser.add_argument('--expected-sha256', required=True)
    parser.add_argument('--whats-new-file', type=pathlib.Path, required=True)
    parser.add_argument('--report', type=pathlib.Path, required=True)
    parser.add_argument('--private-key', type=pathlib.Path, default=pathlib.Path.home()/'.rustore/private_key_user.pem')
    parser.add_argument('--resume-report', type=pathlib.Path)
    args = parser.parse_args()
    report = None
    stage = 'preflight'
    try:
        if not args.aab.is_file() or args.aab.suffix.lower() != '.aab': fail('AAB_NOT_FOUND')
        if args.version_code <= 0 or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){2}', args.version_name): fail('INVALID_VERSION_ARGUMENTS')
        if not re.fullmatch(r'[a-f0-9]{64}', args.expected_sha256): fail('INVALID_EXPECTED_SHA256')
        digest = sha256_file(args.aab)
        if digest != args.expected_sha256: fail('ARTIFACT_SHA256_MISMATCH')
        if manifest_version(args.aab) != (PACKAGE, args.version_name, args.version_code): fail('AAB_MANIFEST_VERSION_MISMATCH')
        notes = args.whats_new_file.read_text().strip()
        if not notes or len(notes) > 5000: fail('INVALID_WHATS_NEW')
        if not args.private_key.is_file(): fail('PRIVATE_KEY_UNAVAILABLE')
        timestamp = dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000+00:00')
        signed = subprocess.run(['openssl', 'dgst', '-sha512', '-sign', str(args.private_key)],
            input=(str(KEY_ID) + timestamp).encode(), capture_output=True, check=True).stdout
        auth = api_json('/public/auth/', payload={'keyId': KEY_ID, 'timestamp': timestamp,
            'signature': base64.b64encode(signed).decode()})
        token = auth.get('jwe') if isinstance(auth, dict) else None
        if not isinstance(token, str) or not token: fail('INVALID_AUTH_RESPONSE')
        versions = api_json(f'/public/v1/application/{PACKAGE}/version?page=0&size=100', token)
        versions = versions.get('content') if isinstance(versions, dict) else None
        if not isinstance(versions, list): fail('INVALID_VERSION_LIST')
        if args.resume_report:
            if args.report.resolve() != args.resume_report.resolve(): fail('RESUME_MUST_UPDATE_SAME_REPORT')
            previous = json.loads(args.resume_report.read_text())
            if previous.get('status') == 'uploaded_draft_not_submitted': fail('ALREADY_UPLOADED_NO_REPEAT')
            if any(previous.get(k) != v for k, v in {'package': PACKAGE, 'versionName': args.version_name,
                'versionCode': args.version_code, 'sha256': digest}.items()): fail('RESUME_REPORT_MISMATCH')
            version_id = previous.get('versionId')
            if not isinstance(version_id, int): fail('INVALID_RESUME_VERSION_ID')
            target = next((v for v in versions if v.get('versionId') == version_id), None)
            if not target or target.get('versionStatus') != 'DRAFT': fail('RESUME_TARGET_NOT_DRAFT')
            report = previous
        else:
            if args.report.exists(): fail('REPORT_ALREADY_EXISTS_USE_EXPLICIT_RESUME')
            if any(v.get('versionStatus') == 'DRAFT' for v in versions): fail('EXISTING_DRAFT_REQUIRES_REVIEW_NO_DELETE')
            if any(isinstance(v.get('versionCode'), int) and v['versionCode'] >= args.version_code for v in versions):
                fail('VERSION_CODE_NOT_NEW')
            report = {'package': PACKAGE, 'versionName': args.version_name, 'versionCode': args.version_code,
                'sha256': digest, 'size': args.aab.stat().st_size, 'status': 'create_requested',
                'createdAt': dt.datetime.now(dt.timezone.utc).isoformat()}
            write_report(args.report, report)
            stage = 'create'
            version_id = api_json(f'/public/v1/application/{PACKAGE}/version', token, {
                'whatsNew': notes, 'publishType': 'MANUAL', 'partialValue': 100, 'developerContacts': {
                    'email': 'info@2a-logistic.ru', 'website': 'https://2a-logistic.ru'}})
            if not isinstance(version_id, int) or version_id <= 0: fail('INVALID_CREATED_VERSION_ID')
            report.update({'versionId': version_id, 'status': 'draft_created'})
            write_report(args.report, report)
        stage = 'upload'
        upload(args.aab, version_id, token)
        report['status'] = 'uploaded_draft_not_submitted'
        write_report(args.report, report)
        print(json.dumps({k: report[k] for k in ['versionId', 'versionName', 'versionCode', 'status', 'sha256']}))
    except Exception as error:
        code = str(error) if isinstance(error, RuntimeError) else type(error).__name__
        if report:
            report['lastStage'] = stage
            report['lastErrorCode'] = code
            if isinstance(error, UploadFailure): report['providerError'] = error.provider
            if stage == 'create': report['status'] = 'create_outcome_requires_read_check'
            elif stage == 'upload': report['status'] = 'upload_outcome_requires_read_check'
            write_report(args.report, report)
        failure = {'status': 'failed', 'stage': stage, 'errorCode': code}
        if isinstance(error, UploadFailure): failure['providerError'] = error.provider
        print(json.dumps(failure, ensure_ascii=False), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
