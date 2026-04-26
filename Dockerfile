FROM ghcr.io/cirruslabs/flutter:stable AS builder

ARG API_BASE_URL=https://prod-api.cp.2a-logistic.com/api
ARG MEDIA_BASE_URL=https://prod-api.cp.2a-logistic.com

USER root
WORKDIR /workspace

RUN git config --global --add safe.directory /sdks/flutter

WORKDIR /workspace/2a-user
COPY . .
RUN cp -a .coolify/2a-shared /workspace/2a-shared

RUN flutter pub get
RUN flutter build web --release --pwa-strategy none \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=MEDIA_BASE_URL="$MEDIA_BASE_URL"

FROM nginx:1.27-alpine

COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /workspace/2a-user/build/web /usr/share/nginx/html

EXPOSE 80
