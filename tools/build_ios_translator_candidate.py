"""Development-signed iOS Release candidate; no install, archive or publication.

Android has a separate future translator and must not use these native flags.
Standard iOS Xcode builds include the live module; this helper keeps a separate
local candidate output. Android and web remain feature-off.
"""
import base64
import subprocess
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
output = repo.parent / 'outputs' / '2026-10-31-screen-translation-prerelease' / 'ios-release'
output.mkdir(parents=True, exist_ok=True)
config = (repo / 'ios/Flutter/Generated.xcconfig').read_text()
existing = next((line.split('=', 1)[1] for line in config.splitlines() if line.startswith('DART_DEFINES=')), '')
overrides = {'SCREEN_TRANSLATION_ENABLED': 'true', 'SENTRY_REPLAY_SESSION_SAMPLE_RATE': '0.0', 'SENTRY_REPLAY_ON_ERROR_SAMPLE_RATE': '0.0'}
defines = [item for item in existing.split(',') if item and base64.b64decode(item).decode().split('=', 1)[0] not in overrides]
defines.extend(base64.b64encode(f'{key}={value}'.encode()).decode() for key, value in overrides.items())
command = [
    'xcodebuild', '-jobs', '2', '-workspace', 'ios/Runner.xcworkspace', '-scheme', 'Runner',
    '-configuration', 'Release', '-sdk', 'iphoneos', '-destination', 'generic/platform=iOS',
    '-derivedDataPath', str(output),
    'SCREEN_TRANSLATION_INFO_PLIST=Runner/ScreenTranslationLive-Info.plist',
    'SCREEN_TRANSLATION_SWIFT_FLAGS=SCREEN_TRANSLATION_PIP_MEDIA SCREEN_TRANSLATION_LIVE',
    'DART_DEFINES=' + ','.join(defines),
    'CODE_SIGN_STYLE=Automatic', 'CODE_SIGN_IDENTITY=Apple Development', 'build',
]
with (output / 'build.log').open('w') as handle:
    result = subprocess.run(command, cwd=repo, stdout=handle, stderr=subprocess.STDOUT)
print(f'Release build exit: {result.returncode}')
print(f'App: {output / "Build/Products/Release-iphoneos/Runner.app"}')
raise SystemExit(result.returncode)
