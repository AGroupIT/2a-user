#!/bin/bash
# Build script for Flutter Web + Android AAB/APK
# Web deploy goes through GitHub + Coolify. APK files are uploaded to the
# production backend releases volume on the new Coolify server.

set -e  # Exit on error

# ── Configuration ──
PRODUCTION_SSH="root@5.188.158.33"
RELEASES_DIR="/var/lib/docker/volumes/zc9s2du0h9jtyxlnaq552rkd-releases/_data"
DOWNLOAD_BASE="${DOWNLOAD_BASE:-https://prod-api.cp.2a-logistic.com/releases}"

COOLIFY_API="${COOLIFY_API:-https://cp.2a-logistic.com/api/v1}"
COOLIFY_APP_UUID="t4zsq97vzl8h46lkidi0f29w"
COOLIFY_WEB_BRANCH="coolify-web-production"
WEB_URL="https://cabinet.2a-logistic.ru"
WEB_API_BASE_URL="${WEB_API_BASE_URL:-https://prod-api.cp.2a-logistic.com/api}"
WEB_MEDIA_BASE_URL="${WEB_MEDIA_BASE_URL:-https://prod-api.cp.2a-logistic.com}"
MOBILE_API_BASE_URL="${MOBILE_API_BASE_URL:-$WEB_API_BASE_URL}"
MOBILE_MEDIA_BASE_URL="${MOBILE_MEDIA_BASE_URL:-$WEB_MEDIA_BASE_URL}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new)

ensure_android_java_home() {
  local android_studio_jbr="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  if [ -d "$android_studio_jbr" ]; then
    export JAVA_HOME="$android_studio_jbr"
    echo "☕ Using Android Studio JBR: $JAVA_HOME"
  fi
}

load_coolify_token() {
  if [ -n "${COOLIFY_TOKEN:-}" ]; then
    return 0
  fi

  if command -v security >/dev/null 2>&1; then
    local keychain_account
    for keychain_account in "${COOLIFY_KEYCHAIN_ACCOUNT:-}" "${USER:-}" "${SUDO_USER:-}" "$(stat -f %Su "$PWD" 2>/dev/null || true)"; do
      if [ -z "$keychain_account" ]; then
        continue
      fi

      local keychain_token
      keychain_token=$(security find-generic-password -a "$keychain_account" -s 2a-logistic-coolify-token -w 2>/dev/null || true)
      if [ -n "$keychain_token" ]; then
        export COOLIFY_TOKEN="$keychain_token"
        return 0
      fi
    done
  fi

  if command -v launchctl >/dev/null 2>&1; then
    local launchctl_token
    launchctl_token=$(launchctl getenv COOLIFY_TOKEN 2>/dev/null || true)
    if [ -n "$launchctl_token" ]; then
      export COOLIFY_TOKEN="$launchctl_token"
    fi
  fi
}

# RuStore API
RUSTORE_API="https://public-api.rustore.ru"
RUSTORE_KEY_ID="2351027924"
RUSTORE_PRIVATE_KEY="$HOME/.rustore/private_key_user.pem"
RUSTORE_PACKAGE="com.twoalogistic.user"
RUSTORE_CONTACT_EMAIL="${RUSTORE_CONTACT_EMAIL:-info@2a-logistic.ru}"
RUSTORE_CONTACT_WEBSITE="${RUSTORE_CONTACT_WEBSITE:-https://2a-logistic.ru}"
RUSTORE_CONTACT_VK="${RUSTORE_CONTACT_VK:-}"

# ── Extract version from pubspec.yaml ──
FULL_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
VERSION=$(echo "$FULL_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2)
echo "📦 Version: $VERSION (build $BUILD_NUMBER)"

sync_coolify_shared() {
  local src="../2a-shared"
  local dst=".coolify/2a-shared"

  if [ ! -d "$src" ]; then
    echo "❌ Shared package not found at $src"
    exit 1
  fi

  echo "🔁 Syncing 2a-shared for Coolify Docker build..."
  mkdir -p .coolify
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      --exclude '.gitignore' \
      --exclude '.dart_tool' \
      --exclude '.gitnexus' \
      --exclude '.code-review-graph' \
      --exclude '.code-review-graphignore' \
      --exclude '.codegraph' \
      --exclude '.claude' \
      --exclude 'AGENTS.md' \
      --exclude 'CLAUDE.md' \
      --exclude 'CHANGELOG.md' \
      --exclude 'README.md' \
      --exclude 'test' \
      --exclude 'build' \
      --exclude '.DS_Store' \
      "$src/" "$dst/"
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -R "$src/." "$dst/"
    find "$dst" \
      \( -name '.git' -o -name '.gitignore' -o -name '.dart_tool' -o -name '.gitnexus' -o -name '.code-review-graph' \
      -o -name '.code-review-graphignore' -o -name '.codegraph' -o -name '.claude' \
      -o -name 'AGENTS.md' -o -name 'CLAUDE.md' -o -name 'CHANGELOG.md' -o -name 'README.md' \
      -o -name 'test' -o -name 'build' -o -name '.DS_Store' \) -prune -exec rm -rf {} +
  fi
}

commit_if_needed() {
  local status
  status=$(git status --short)
  if [ -z "$status" ]; then
    return 0
  fi

  echo ""
  echo "⚠️  Есть незакоммиченные изменения, которые нужны для web deploy:"
  git status --short
  echo ""
  read -p "Закоммитить все изменения и продолжить deploy? [y/N]: " COMMIT_CONFIRM
  if [[ ! "$COMMIT_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Остановлено. Закоммить изменения вручную и запусти скрипт снова."
    exit 1
  fi

  read -p "Commit message [Deploy user web ${FULL_VERSION}]: " COMMIT_MESSAGE
  COMMIT_MESSAGE=${COMMIT_MESSAGE:-"Deploy user web ${FULL_VERSION}"}
  git add -A
  git commit -m "$COMMIT_MESSAGE"
}

push_coolify_branch() {
  echo "📤 Pushing current HEAD to origin/${COOLIFY_WEB_BRANCH}..."
  git fetch origin "$COOLIFY_WEB_BRANCH" >/dev/null 2>&1 || true

  if git rev-parse --verify "origin/${COOLIFY_WEB_BRANCH}" >/dev/null 2>&1 &&
     ! git merge-base --is-ancestor "origin/${COOLIFY_WEB_BRANCH}" HEAD; then
    echo "⚠️  Текущий HEAD не является fast-forward для origin/${COOLIFY_WEB_BRANCH}."
    echo "   Это нормально для параллельной release-ветки, но требует force-with-lease."
    read -p "Обновить ${COOLIFY_WEB_BRANCH} через --force-with-lease? [y/N]: " FORCE_CONFIRM
    if [[ ! "$FORCE_CONFIRM" =~ ^[Yy]$ ]]; then
      echo "Остановлено. Переключись на ${COOLIFY_WEB_BRANCH}, смержи изменения и запусти скрипт снова."
      exit 1
    fi
    git push --force-with-lease="refs/heads/${COOLIFY_WEB_BRANCH}" origin "HEAD:${COOLIFY_WEB_BRANCH}"
  else
    git push origin "HEAD:${COOLIFY_WEB_BRANCH}"
  fi
}

trigger_coolify_deploy() {
  load_coolify_token

  if [ -z "${COOLIFY_TOKEN:-}" ]; then
    echo "⚠️  COOLIFY_TOKEN не задан. Код запушен; запусти deploy в Coolify вручную:"
    echo "   ${WEB_URL} / app ${COOLIFY_APP_UUID}"
    return 0
  fi

  echo "🚀 Triggering Coolify deploy..."
  curl -fsS \
    -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
    "${COOLIFY_API}/deploy?uuid=${COOLIFY_APP_UUID}&force=false"
  echo ""
}

update_manifest_section() {
  local manifest_file="$1"
  local section="$2"
  local latest_version="$3"
  local download_url="$4"
  local size="$5"
  local sha256="$6"
  local changelog="$7"
  local changelog_b64
  changelog_b64=$(printf '%s' "$changelog" | base64 | tr -d '\n')

  ssh "${SSH_OPTS[@]}" "$PRODUCTION_SSH" "python3 - '$RELEASES_DIR/$manifest_file' '$section' '$latest_version' '$download_url' '$size' '$sha256' '$changelog_b64' <<'PYEOF'
import base64
import json
import os
import sys

path, section, latest_version, download_url, size, sha256, changelog_b64 = sys.argv[1:]
try:
    with open(path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}

data[section] = {
    'minVersion': '1.0.0',
    'latestVersion': latest_version,
    'downloadUrl': download_url,
    'size': int(size),
    'sha256': sha256,
    'changelog': base64.b64decode(changelog_b64).decode('utf-8'),
}

if 'ios' not in data:
    data['ios'] = {'minVersion': '1.0.0', 'latestVersion': latest_version, 'storeUrl': ''}

tmp = path + '.tmp'
with open(tmp, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.rename(tmp, path)
print('OK')
PYEOF"
}

# ── Ask what to build ──
echo ""
echo "Что собрать?"
echo "  1) WEB"
echo "  2) RuStore (AAB)"
echo "  3) APK"
echo "  4) APK + WEB"
echo "  5) AAB + WEB"
echo "  6) APK + AAB"
echo "  7) APK + WEB + AAB"
read -p "Выбор [5]: " BUILD_CHOICE
BUILD_CHOICE=${BUILD_CHOICE:-5}

BUILD_WEB=false
BUILD_AAB=false
BUILD_APK=false
case "$BUILD_CHOICE" in
  1) BUILD_WEB=true ;;
  2) BUILD_AAB=true ;;
  3) BUILD_APK=true ;;
  4) BUILD_APK=true; BUILD_WEB=true ;;
  5) BUILD_AAB=true; BUILD_WEB=true ;;
  6) BUILD_APK=true; BUILD_AAB=true ;;
  7) BUILD_APK=true; BUILD_WEB=true; BUILD_AAB=true ;;
  *)
    echo "❌ Неверный выбор: $BUILD_CHOICE"
    exit 1
    ;;
esac

# ── Build Web ──
if $BUILD_WEB; then
  echo ""
  sync_coolify_shared

  echo "🌐 Building Flutter Web..."
  flutter build web --release --pwa-strategy none \
    --dart-define=API_BASE_URL="$WEB_API_BASE_URL" \
    --dart-define=MEDIA_BASE_URL="$WEB_MEDIA_BASE_URL"

  echo "📋 Copying firebase-messaging-sw.js..."
  cp web/firebase-messaging-sw.js build/web/

  commit_if_needed
  push_coolify_branch
  trigger_coolify_deploy
  echo "✅ Web deploy queued: ${WEB_URL}"
fi

# ── Build AAB for RuStore ──
if $BUILD_AAB; then
  echo ""
  echo "🤖 Building Android AAB for RuStore (without REQUEST_INSTALL_PACKAGES)..."
  AAB_PATH="build/app/outputs/bundle/rustoreRelease/app-rustore-release.aab"
  if [[ "${RUSTORE_REUSE_AAB:-}" =~ ^(1|true|yes)$ ]] && [ -f "$AAB_PATH" ]; then
    echo "♻️  Reusing existing AAB: $AAB_PATH"
  else
    ensure_android_java_home
    flutter build appbundle --release --flavor rustore \
      --dart-define=APP_DISTRIBUTION=rustore \
      --dart-define=API_BASE_URL="$MOBILE_API_BASE_URL" \
      --dart-define=MEDIA_BASE_URL="$MOBILE_MEDIA_BASE_URL"
  fi

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

  DRAFT_PAYLOAD=$(RUSTORE_WHATS_NEW="$RUSTORE_WHATS_NEW" \
    RUSTORE_CONTACT_EMAIL="$RUSTORE_CONTACT_EMAIL" \
    RUSTORE_CONTACT_WEBSITE="$RUSTORE_CONTACT_WEBSITE" \
    RUSTORE_CONTACT_VK="$RUSTORE_CONTACT_VK" \
    python3 -c '
import json
import os

contact = {"email": os.environ["RUSTORE_CONTACT_EMAIL"].strip()}
website = os.environ.get("RUSTORE_CONTACT_WEBSITE", "").strip()
vk = os.environ.get("RUSTORE_CONTACT_VK", "").strip()
if website:
    contact["website"] = website
if vk:
    contact["vkCommunity"] = vk

payload = {
    "whatsNew": os.environ["RUSTORE_WHATS_NEW"],
    "publishType": "INSTANTLY",
    "partialValue": 100,
    "developerContacts": contact,
}
print(json.dumps(payload, ensure_ascii=False))
')

  echo "  Контакты разработчика: ${RUSTORE_CONTACT_EMAIL}, ${RUSTORE_CONTACT_WEBSITE}"

  DRAFT_RESPONSE=$(curl -s -X POST "${RUSTORE_API}/public/v1/application/${RUSTORE_PACKAGE}/version" \
    -H "Content-Type: application/json" \
    -H "Public-Token: ${JWE_TOKEN}" \
    -d "$DRAFT_PAYLOAD")

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
  echo "🤖 Building Android APK for direct install (with REQUEST_INSTALL_PACKAGES)..."
  ensure_android_java_home
  flutter build apk --release --flavor direct \
    --dart-define=APP_DISTRIBUTION=direct \
    --dart-define=API_BASE_URL="$MOBILE_API_BASE_URL" \
    --dart-define=MEDIA_BASE_URL="$MOBILE_MEDIA_BASE_URL"

  APK_PATH="build/app/outputs/flutter-apk/app-direct-release.apk"

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
  echo "📤 Uploading APK to new production server..."
  scp "${SSH_OPTS[@]}" "$APK_PATH" "${PRODUCTION_SSH}:${RELEASES_DIR}/${APK_FILENAME}"
  ssh "${SSH_OPTS[@]}" "$PRODUCTION_SSH" "chmod 644 '${RELEASES_DIR}/${APK_FILENAME}'"

  # Create/update symlink for latest APK (used on site footer)
  echo "🔗 Updating latest APK symlink..."
  ssh "${SSH_OPTS[@]}" "$PRODUCTION_SSH" "cd '${RELEASES_DIR}' && ln -sf '${APK_FILENAME}' 2a-user-latest.apk"

  echo "📝 Updating version.json (android-user section)..."

  update_manifest_section "version-user.json" "android" "$FULL_VERSION" "${DOWNLOAD_BASE}/${APK_FILENAME}" "$APK_SIZE" "$APK_SHA256" "$CHANGELOG"

  echo "✅ APK deployed: ${DOWNLOAD_BASE}/${APK_FILENAME}"
fi
