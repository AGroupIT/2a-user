#!/bin/sh

set -eu

log() {
  echo "Sentry dSYM: $*"
}

write_stamp() {
  if [ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]; then
    mkdir -p "$(dirname "${SCRIPT_OUTPUT_FILE_0}")"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "${SCRIPT_OUTPUT_FILE_0}"
  fi
}

load_token_from_keychain() {
  if ! command -v security >/dev/null 2>&1; then
    return 0
  fi

  for account in "${SENTRY_KEYCHAIN_ACCOUNT:-}" "${USER:-}" "${SUDO_USER:-}" "$(id -un 2>/dev/null || true)"; do
    if [ -z "${account}" ]; then
      continue
    fi

    security find-generic-password \
      -a "${account}" \
      -s 2a-user-sentry-auth-token \
      -w 2>/dev/null && return 0
  done
}

find_sentry_cli() {
  for candidate in \
    "${SENTRY_CLI_EXECUTABLE:-}" \
    "$(command -v sentry-cli 2>/dev/null || true)" \
    "/opt/homebrew/bin/sentry-cli" \
    "/usr/local/bin/sentry-cli" \
    "${SRCROOT}/../.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli" \
    "${SRCROOT}/../.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli-Darwin-universal"; do
    if [ -n "${candidate}" ] && [ -x "${candidate}" ]; then
      echo "${candidate}"
      return 0
    fi
  done
}

if [ "${CONFIGURATION:-}" != "Release" ]; then
  log "skip, configuration is ${CONFIGURATION:-unknown}"
  write_stamp
  exit 0
fi

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  log "skip, DWARF_DSYM_FOLDER_PATH is empty"
  write_stamp
  exit 0
fi

dsym_file_name="${DWARF_DSYM_FILE_NAME:-Runner.app.dSYM}"
dsym_path="${DWARF_DSYM_FOLDER_PATH}/${dsym_file_name}"
upload_path=""

if [ -d "${dsym_path}" ]; then
  upload_path="${dsym_path}"
elif [ -d "${DWARF_DSYM_FOLDER_PATH}" ]; then
  upload_path="${DWARF_DSYM_FOLDER_PATH}"
fi

if [ -z "${upload_path}" ]; then
  log "skip, dSYM folder was not found"
  write_stamp
  exit 0
fi

sentry_token="${SENTRY_AUTH_TOKEN:-}"
if [ -z "${sentry_token}" ]; then
  sentry_token="$(load_token_from_keychain || true)"
fi

if [ -z "${sentry_token}" ]; then
  log "skip, SENTRY_AUTH_TOKEN is empty and Keychain item 2a-user-sentry-auth-token was not found"
  write_stamp
  exit 0
fi

sentry_cli="$(find_sentry_cli || true)"
if [ -z "${sentry_cli}" ]; then
  log "skip, sentry-cli was not found. Install it with: brew install getsentry/tools/sentry-cli"
  write_stamp
  exit 0
fi

sentry_org="${SENTRY_ORG:-2a-logistic}"
sentry_project="${SENTRY_PROJECT:-2a-user}"
sentry_url="${SENTRY_URL:-}"

if [ -z "${sentry_url}" ]; then
  log "skip, SENTRY_URL is empty; runtime errors are sent through the Sentry SDK DSN"
  write_stamp
  exit 0
fi

log "uploading ${upload_path} to ${sentry_org}/${sentry_project}"

if SENTRY_AUTH_TOKEN="${sentry_token}" SENTRY_URL="${sentry_url}" \
  "${sentry_cli}" debug-files upload \
    --org "${sentry_org}" \
    --project "${sentry_project}" \
    --include-sources \
    "${upload_path}"; then
  log "upload completed"
else
  log "warning, upload failed; Archive is left successful"
fi

write_stamp
