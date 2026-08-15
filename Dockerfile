# syntax=docker/dockerfile:1.10
FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG API_BASE_URL=https://prod-api.cp.2a-logistic.com/api
ARG MEDIA_BASE_URL=https://prod-api.cp.2a-logistic.com
ARG SENTRY_DSN=https://98a0571e1550242f4574ec83627361b8@sentry.cp.2a-logistic.com/2
ARG SENTRY_URL=https://sentry.cp.2a-logistic.com
ARG SENTRY_PROJECT=2a-user
ARG SENTRY_ORG=sentry
ARG SENTRY_ENVIRONMENT=production
ARG SENTRY_RELEASE=
ARG SENTRY_VERIFY_BUTTON=false
ARG FLUTTER_TAG=3.47.0-0.3.pre
ARG FLUTTER_REVISION=7c7929adb0767c020659a422ae86df9ec0d5f82a

USER root
WORKDIR /workspace

RUN git config --global --add safe.directory /sdks/flutter
RUN git -C /sdks/flutter fetch --depth=1 origin \
      "refs/tags/${FLUTTER_TAG}:refs/tags/${FLUTTER_TAG}" && \
    git -C /sdks/flutter checkout --detach "${FLUTTER_REVISION}" && \
    test "$(git -C /sdks/flutter rev-parse HEAD)" = "${FLUTTER_REVISION}" && \
    flutter precache --web

WORKDIR /workspace/2a-user
COPY . .
RUN cp -a .coolify/2a-shared /workspace/2a-shared

RUN flutter pub get
RUN --mount=type=secret,id=SENTRY_AUTH_TOKEN \
    FULL_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //') && \
    BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2) && \
    SOURCE_HASH=$( \
      { \
        find lib web assets .coolify/2a-shared -type f -print0 | \
          LC_ALL=C sort -z | xargs -0 sha256sum; \
        sha256sum pubspec.yaml pubspec.lock; \
        printf '%s\n' \
          "flutter=$FLUTTER_REVISION" \
          "api=$API_BASE_URL" \
          "media=$MEDIA_BASE_URL" \
          "dsn=$SENTRY_DSN" \
          "environment=$SENTRY_ENVIRONMENT" \
          "verify=$SENTRY_VERIFY_BUTTON"; \
      } | sha256sum | cut -c1-12 \
    ) && \
    RESOLVED_SENTRY_RELEASE="${SENTRY_RELEASE:-com.twoalogistic.user@$FULL_VERSION}" && \
    RESOLVED_SENTRY_DIST="$BUILD_NUMBER-$SOURCE_HASH" && \
    echo "Sentry artifact identity: $RESOLVED_SENTRY_RELEASE / $RESOLVED_SENTRY_DIST" && \
    flutter build web --release --pwa-strategy none \
      --source-maps \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=MEDIA_BASE_URL="$MEDIA_BASE_URL" \
      --dart-define=SENTRY_DSN="$SENTRY_DSN" \
      --dart-define=SENTRY_ENVIRONMENT="$SENTRY_ENVIRONMENT" \
      --dart-define=SENTRY_RELEASE="$RESOLVED_SENTRY_RELEASE" \
      --dart-define=SENTRY_DIST="$RESOLVED_SENTRY_DIST" \
      --dart-define=SENTRY_VERIFY_BUTTON="$SENTRY_VERIFY_BUTTON" && \
    if [ ! -s /run/secrets/SENTRY_AUTH_TOKEN ]; then \
      echo "ERROR: SENTRY_AUTH_TOKEN build secret is required for a production web build." >&2; \
      exit 1; \
    fi && \
    export SENTRY_AUTH_TOKEN="$(cat /run/secrets/SENTRY_AUTH_TOKEN)" && \
    SENTRY_URL="$SENTRY_URL" \
    SENTRY_PROJECT="$SENTRY_PROJECT" \
    SENTRY_ORG="$SENTRY_ORG" \
    SENTRY_RELEASE="$RESOLVED_SENTRY_RELEASE" \
    SENTRY_DIST="$RESOLVED_SENTRY_DIST" \
      dart run sentry_dart_plugin \
        --sentry-define=url="$SENTRY_URL" \
        --sentry-define=project="$SENTRY_PROJECT" \
        --sentry-define=org="$SENTRY_ORG" \
        --sentry-define=release="$RESOLVED_SENTRY_RELEASE" \
        --sentry-define=dist="$RESOLVED_SENTRY_DIST" \
        --sentry-define=commits=false && \
    sed -i '/^[[:space:]]*\/\/# sourceMappingURL=.*$/d' build/web/main.dart.js && \
    find build/web -type f -name '*.map' -delete

FROM nginx:1.27-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /workspace/2a-user/build/web /usr/share/nginx/html

EXPOSE 80
