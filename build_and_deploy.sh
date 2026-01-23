#!/bin/bash

echo "🏗️  Building 2a-user web..."
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful"

    echo "📋 Copying firebase-messaging-sw.js..."
    cp web/firebase-messaging-sw.js build/web/

    echo "✅ Ready to deploy!"
    echo ""
    echo "To deploy, copy build/web/* to the server:"
    echo "scp -r build/web/* user@server:/path/to/2a-user/"
else
    echo "❌ Build failed"
    exit 1
fi
