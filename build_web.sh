#!/bin/bash
# Build script for Flutter Web + Android AAB/APK
# Includes automatic deployment (FTP for web, SCP for APK, RuStore for AAB)

set -e  # Exit on error

# ── Configuration ──
FTP_HOST="188.124.54.40"
FTP_PORT="21"
FTP_USER="administrator_cabinetapp"
FTP_PASS='hS2cCt3!b1@{;$VV'
FTP_PATH="/home/administrator_cabinetapp"

SSH_HOST="administrator@188.124.54.40"
RELEASES_DIR="/home/administrator/web/2alogistic.2a-marketing.ru/public_html/backend/public/releases"
DOWNLOAD_BASE="https://2alogistic.2a-marketing.ru/releases"

# RuStore API
RUSTORE_API="https://public-api.rustore.ru"
RUSTORE_KEY_ID="2351027924"
RUSTORE_PRIVATE_KEY="$HOME/.rustore/private_key_user.pem"
RUSTORE_PACKAGE="com.twoalogistic.user"

# ── Extract version from pubspec.yaml ──
FULL_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
VERSION=$(echo "$FULL_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2)
echo "📦 Version: $VERSION (build $BUILD_NUMBER)"

# ── Ask what to build ──
echo ""
echo "Что собрать?"
echo "  1) Только Web"
echo "  2) Только AAB (Android → RuStore)"
echo "  3) Web + AAB"
echo "  4) Только APK (прямая установка)"
echo "  5) Web + APK"
read -p "Выбор [3]: " BUILD_CHOICE
BUILD_CHOICE=${BUILD_CHOICE:-3}

BUILD_WEB=false
BUILD_AAB=false
BUILD_APK=false
[[ "$BUILD_CHOICE" == "1" || "$BUILD_CHOICE" == "3" || "$BUILD_CHOICE" == "5" ]] && BUILD_WEB=true
[[ "$BUILD_CHOICE" == "2" || "$BUILD_CHOICE" == "3" ]] && BUILD_AAB=true
[[ "$BUILD_CHOICE" == "4" || "$BUILD_CHOICE" == "5" ]] && BUILD_APK=true

# ── Build Web ──
if $BUILD_WEB; then
  echo ""
  echo "🌐 Building Flutter Web..."
  flutter build web --release --pwa-strategy none

  echo "📋 Copying firebase-messaging-sw.js..."
  cp web/firebase-messaging-sw.js build/web/

  echo "📤 Deploying Web to FTP..."
  lftp -u "$FTP_USER","$FTP_PASS" "ftp://$FTP_HOST:$FTP_PORT" -e "
    set ssl:verify-certificate no
    mirror --reverse --verbose --delete build/web/ $FTP_PATH/
    quit
  "
  echo "✅ Web deployed: https://cabinet.2a-logistic.ru"
fi

# ── Build AAB for RuStore ──
if $BUILD_AAB; then
  echo ""
  echo "🤖 Building Android AAB..."
  flutter build appbundle --release

  AAB_PATH="build/app/outputs/bundle/release/app-release.aab"

  if [ ! -f "$AAB_PATH" ]; then
    echo "❌ AAB not found at $AAB_PATH"
    exit 1
  fi

  AAB_SIZE=$(stat -f%z "$AAB_PATH" 2>/dev/null || stat -c%s "$AAB_PATH" 2>/dev/null)
  echo "  Size: $AAB_SIZE bytes ($(echo "$AAB_SIZE / 1048576" | bc) MB)"

  # ── RuStore: Ask for whatsNew ──
  echo ""
  echo "📝 Что нового для RuStore (Enter чтобы пропустить):"
  read -r RUSTORE_WHATS_NEW
  RUSTORE_WHATS_NEW=${RUSTORE_WHATS_NEW:-"Исправление ошибок и улучшения стабильности"}

  # ── RuStore: Check private key ──
  if [ ! -f "$RUSTORE_PRIVATE_KEY" ]; then
    echo "❌ RuStore private key not found at $RUSTORE_PRIVATE_KEY"
    echo "   Создайте файл с приватным ключом: ~/.rustore/private_key_user.pem"
    exit 1
  fi

  # ── RuStore: Step 1 — Auth ──
  echo ""
  echo "🔐 RuStore: Авторизация..."

  TIMESTAMP=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000+00:00'))")
  SIGN_DATA="${RUSTORE_KEY_ID}${TIMESTAMP}"

  SIGNATURE=$(echo -n "$SIGN_DATA" | openssl dgst -sha512 -sign "$RUSTORE_PRIVATE_KEY" | base64)

  AUTH_RESPONSE=$(curl -s -X POST "${RUSTORE_API}/public/auth/" \
    -H "Content-Type: application/json" \
    -d "{
      \"keyId\": ${RUSTORE_KEY_ID},
      \"timestamp\": \"${TIMESTAMP}\",
      \"signature\": \"${SIGNATURE}\"
    }")

  AUTH_CODE=$(echo "$AUTH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))" 2>/dev/null)
  if [ "$AUTH_CODE" != "OK" ]; then
    echo "❌ RuStore auth failed:"
    echo "$AUTH_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$AUTH_RESPONSE"
    exit 1
  fi

  JWE_TOKEN=$(echo "$AUTH_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['body']['jwe'])")
  echo "  ✅ Токен получен (TTL: 15 мин)"

  # ── RuStore: Step 2 — Get last published version ──
  echo "📋 RuStore: Получение последней опубликованной версии..."

  VERSIONS_RESPONSE=$(curl -s -X GET "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version?page=0&size=10" \
    -H "Public-Token: ${JWE_TOKEN}")

  PARSED=$(echo "$VERSIONS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data.get('body', {}).get('content', [])
active = None
drafts = []
for v in items:
    if v.get('versionStatus') == 'ACTIVE' and not active:
        active = v
    if v.get('versionStatus') == 'DRAFT':
        drafts.append(str(v['versionId']))
if active:
    print(f\"ACTIVE_ID={active['versionId']}\")
    print(f\"ACTIVE_NAME={active.get('versionName','')}\")
    print(f\"ACTIVE_CODE={active.get('versionCode','')}\")
else:
    print('ACTIVE_ID=')
print(f\"DRAFT_IDS={' '.join(drafts)}\")
" 2>/dev/null)

  eval "$PARSED"

  if [ -n "$ACTIVE_ID" ]; then
    echo "  ✅ Последняя опубликованная: v${ACTIVE_NAME} (code ${ACTIVE_CODE}, id ${ACTIVE_ID})"
  else
    echo "  ⚠️  Активная версия не найдена, будет создан новый черновик"
  fi

  # Clean up existing drafts (API allows only one draft)
  if [ -n "$DRAFT_IDS" ] && [ "$DRAFT_IDS" != "" ]; then
    for DRAFT_ID in $DRAFT_IDS; do
      echo "  🗑 Удаление старого черновика #${DRAFT_ID}..."
      curl -s -X DELETE "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version/${DRAFT_ID}" \
        -H "Public-Token: ${JWE_TOKEN}" > /dev/null
    done
  fi

  # ── RuStore: Step 3 — Create draft as copy of published version ──
  echo "📝 RuStore: Создание черновика на основе опубликованной версии..."

  WHATS_NEW_JSON=$(python3 -c "import json; print(json.dumps('$RUSTORE_WHATS_NEW'))")

  DRAFT_RESPONSE=$(curl -s -X POST "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version" \
    -H "Content-Type: application/json" \
    -H "Public-Token: ${JWE_TOKEN}" \
    -d "{
      \"whatsNew\": ${WHATS_NEW_JSON},
      \"publishType\": \"INSTANTLY\",
      \"partialValue\": 100
    }")

  DRAFT_CODE=$(echo "$DRAFT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))" 2>/dev/null)
  if [ "$DRAFT_CODE" != "OK" ]; then
    echo "❌ Ошибка создания черновика:"
    echo "$DRAFT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$DRAFT_RESPONSE"
    exit 1
  fi

  VERSION_ID=$(echo "$DRAFT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['body'])")
  echo "  ✅ Черновик создан: versionId=${VERSION_ID}"

  # ── RuStore: Step 4 — Upload AAB ──
  echo "📤 RuStore: Загрузка AAB (это может занять несколько минут)..."

  UPLOAD_RESPONSE=$(curl -s -X POST "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version/${VERSION_ID}/aab" \
    -H "Public-Token: ${JWE_TOKEN}" \
    -F "file=@${AAB_PATH}")

  UPLOAD_CODE=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))" 2>/dev/null)
  if [ "$UPLOAD_CODE" != "OK" ]; then
    echo "❌ Ошибка загрузки AAB:"
    echo "$UPLOAD_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$UPLOAD_RESPONSE"
    exit 1
  fi
  echo "  ✅ AAB загружен"

  # ── RuStore: Step 5 — Submit for moderation ──
  echo "📨 RuStore: Отправка на модерацию..."

  COMMIT_RESPONSE=$(curl -s -X POST "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version/${VERSION_ID}/commit?priorityUpdate=0" \
    -H "Public-Token: ${JWE_TOKEN}")

  COMMIT_CODE=$(echo "$COMMIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',''))" 2>/dev/null)
  if [ "$COMMIT_CODE" != "OK" ]; then
    echo "⚠️  Ошибка отправки на модерацию:"
    echo "$COMMIT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$COMMIT_RESPONSE"
    echo ""
    echo "   AAB загружен как черновик. Отправьте на модерацию вручную в консоли RuStore."
  else
    echo "  ✅ Отправлено на модерацию"
  fi

  echo "✅ RuStore: Версия ${VERSION} загружена и отправлена на модерацию"
fi

# ── Build APK (direct install) ──
if $BUILD_APK; then
  echo ""
  echo "🤖 Building Android APK..."
  flutter build apk --release

  APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

  if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found at $APK_PATH"
    exit 1
  fi

  APK_SHA256=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
  APK_SIZE=$(stat -f%z "$APK_PATH" 2>/dev/null || stat -c%s "$APK_PATH" 2>/dev/null)
  APK_FILENAME="2a-user-${VERSION}.apk"

  echo "  SHA256: $APK_SHA256"
  echo "  Size:   $APK_SIZE bytes ($(echo "$APK_SIZE / 1048576" | bc) MB)"

  echo ""
  read -p "Changelog (Enter чтобы пропустить): " CHANGELOG
  CHANGELOG=${CHANGELOG:-""}

  echo ""
  echo "📤 Uploading APK to server..."
  scp "$APK_PATH" "${SSH_HOST}:${RELEASES_DIR}/${APK_FILENAME}"

  # Create/update symlink for latest APK (used on site footer)
  echo "🔗 Updating latest APK symlink..."
  ssh "$SSH_HOST" "cd ${RELEASES_DIR} && ln -sf ${APK_FILENAME} 2a-user-latest.apk"

  echo "📝 Updating version.json (android-user section)..."

  CHANGELOG_ESCAPED=$(echo "$CHANGELOG" | sed 's/"/\\"/g' | tr '\n' ' ')

  ssh "$SSH_HOST" "python3 - <<'PYEOF'
import json, os
path = '${RELEASES_DIR}/version-user.json'
try:
    with open(path, 'r') as f:
        data = json.load(f)
except:
    data = {}
data['android'] = {
    'minVersion': '1.0.0',
    'latestVersion': '${FULL_VERSION}',
    'downloadUrl': '${DOWNLOAD_BASE}/${APK_FILENAME}',
    'size': ${APK_SIZE},
    'sha256': '${APK_SHA256}',
    'changelog': '${CHANGELOG_ESCAPED}'
}
tmp = path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.rename(tmp, path)
print('OK')
PYEOF"

  echo "✅ APK deployed: ${DOWNLOAD_BASE}/${APK_FILENAME}"
fi

echo ""
echo "🎉 Done!"
