#!/bin/bash
# Build script for Flutter Web with Firebase Messaging Service Worker
# Includes automatic FTP deployment

set -e  # Exit on error

# FTP Configuration
FTP_HOST="188.124.54.40"
FTP_PORT="21"
FTP_USER="administrator_cabinetapp"
FTP_PASS='hS2cCt3!b1@{;$VV'
FTP_PATH="/home/administrator_cabinetapp"

echo "🚀 Building Flutter Web..."
flutter build web --release

echo "📋 Copying firebase-messaging-sw.js..."
cp web/firebase-messaging-sw.js build/web/

echo "✅ Build complete!"

echo ""
echo "📤 Deploying to FTP server..."
lftp -u "$FTP_USER","$FTP_PASS" "ftp://$FTP_HOST:$FTP_PORT" -e "
  set ssl:verify-certificate no
  mirror --reverse --verbose build/web/ $FTP_PATH/
  quit
"

echo ""
echo "🎉 Deployment complete!"
