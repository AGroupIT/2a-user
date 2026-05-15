FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG API_BASE_URL=https://prod-api.cp.2a-logistic.com/api
ARG MEDIA_BASE_URL=https://prod-api.cp.2a-logistic.com
ARG SENTRY_DSN=https://175a28fc6b3c9e907471ae9a59d7912a@o4511394003288064.ingest.de.sentry.io/4511394144649296
ARG SENTRY_ENVIRONMENT=production
ARG SENTRY_RELEASE=
ARG SENTRY_DIST=
ARG SENTRY_VERIFY_BUTTON=false

USER root
WORKDIR /workspace

RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /workspace/2a-user
COPY . .
RUN cp -a .coolify/2a-shared /workspace/2a-shared

RUN flutter pub get
RUN FULL_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //') && \
    BUILD_NUMBER=$(echo "$FULL_VERSION" | cut -d'+' -f2) && \
    RESOLVED_SENTRY_RELEASE="${SENTRY_RELEASE:-com.twoalogistic.user@$FULL_VERSION}" && \
    RESOLVED_SENTRY_DIST="${SENTRY_DIST:-$BUILD_NUMBER}" && \
    flutter build web --release --pwa-strategy none \
      --dart-define=API_BASE_URL="$API_BASE_URL" \
      --dart-define=MEDIA_BASE_URL="$MEDIA_BASE_URL" \
      --dart-define=SENTRY_DSN="$SENTRY_DSN" \
      --dart-define=SENTRY_ENVIRONMENT="$SENTRY_ENVIRONMENT" \
      --dart-define=SENTRY_RELEASE="$RESOLVED_SENTRY_RELEASE" \
      --dart-define=SENTRY_DIST="$RESOLVED_SENTRY_DIST" \
      --dart-define=SENTRY_VERIFY_BUTTON="$SENTRY_VERIFY_BUTTON"

FROM nginx:1.27-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /workspace/2a-user/build/web /usr/share/nginx/html

EXPOSE 80
