#!/bin/bash

# Private Messaging App Setup Script
echo "🚀 Setting up Private Messaging Flutter App..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n1)"

# Check Flutter doctor
echo "🔍 Checking Flutter setup..."
flutter doctor

# Install dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Check if iOS directory exists and run pod install
if [ -d "ios" ]; then
    echo "🍎 Installing iOS dependencies..."
    cd ios
    if command -v pod &> /dev/null; then
        pod install
    else
        echo "⚠️ CocoaPods not found. Please install it if you plan to build for iOS:"
        echo "   sudo gem install cocoapods"
    fi
    cd ..
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Set up your Supabase project:"
echo "   - Create account at https://supabase.com"
echo "   - Create new project"
echo "   - Run the SQL script in supabase_schema.sql"
echo "   - Update lib/main.dart with your Supabase URL and key"
echo ""
echo "2. Set up Firebase for notifications:"
echo "   - Create project at https://console.firebase.google.com"
echo "   - Add your app and download config files"
echo "   - Place google-services.json in android/app/"
echo "   - Place GoogleService-Info.plist in ios/Runner/"
echo ""
echo "3. Run the app:"
echo "   flutter run"
echo ""
echo "📚 Check README.md for detailed setup instructions"