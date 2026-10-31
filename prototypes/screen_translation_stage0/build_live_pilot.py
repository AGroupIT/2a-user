"""Build the opted-in same-bundle pilot; never install, deploy or change signing access."""
import base64
import subprocess
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
output = repo.parent / 'outputs' / '2026-10-30-screen-translation-stage0'
output.mkdir(parents=True, exist_ok=True)
config = (repo / 'ios/Flutter/Generated.xcconfig').read_text()
existing = next((line.split('=', 1)[1] for line in config.splitlines() if line.startswith('DART_DEFINES=')), '')
defines = [item for item in existing.split(',') if item and not base64.b64decode(item).decode().startswith('SCREEN_TRANSLATION_ENABLED=')]
defines.append(base64.b64encode(b'SCREEN_TRANSLATION_ENABLED=true').decode())
command = [
    'xcodebuild', '-workspace', 'ios/Runner.xcworkspace', '-scheme', 'Runner',
    '-configuration', 'Profile', '-sdk', 'iphoneos', '-destination', 'generic/platform=iOS',
    '-derivedDataPath', str(output / 'UserRunnerData'),
    'SCREEN_TRANSLATION_INFO_PLIST=Runner/ScreenTranslationLive-Info.plist',
    'SCREEN_TRANSLATION_SWIFT_FLAGS=SCREEN_TRANSLATION_STAGE0 SCREEN_TRANSLATION_PIP_MEDIA SCREEN_TRANSLATION_LIVE',
    'DART_DEFINES=' + ','.join(defines),
    'CODE_SIGN_STYLE=Automatic', 'CODE_SIGN_IDENTITY=Apple Development', 'build',
]
log = output / 'build.log'
with log.open('w') as handle:
    result = subprocess.run(command, cwd=repo, stdout=handle, stderr=subprocess.STDOUT)
print(f'Build exit: {result.returncode}; local log: {log}')
if result.returncode == 0:
    print(f'App: {output / "UserRunnerData/Build/Products/Profile-iphoneos/Runner.app"}')
raise SystemExit(result.returncode)
