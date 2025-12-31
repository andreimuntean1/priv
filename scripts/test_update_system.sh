#!/bin/bash

# Test script for the in-app update system
# This script helps verify the update system components are working correctly

echo "🚀 Testing In-App Update System"
echo "=================================="

echo ""
echo "1. Checking Flutter dependencies..."
flutter pub deps --style=compact | grep -E "(package_info_plus|url_launcher)"

echo ""
echo "2. Checking for syntax errors..."
flutter analyze --no-fatal-infos --no-fatal-warnings

echo ""
echo "3. Checking if update system files exist..."
echo "   ✓ Database schema: $(ls -la supabase_app_versions_schema.sql 2>/dev/null && echo "EXISTS" || echo "MISSING")"
echo "   ✓ App Version Model: $(ls -la lib/models/app_version.dart 2>/dev/null && echo "EXISTS" || echo "MISSING")"
echo "   ✓ Update Service: $(ls -la lib/services/update_service.dart 2>/dev/null && echo "EXISTS" || echo "MISSING")"
echo "   ✓ Update Dialog: $(ls -la lib/widgets/update_dialog.dart 2>/dev/null && echo "EXISTS" || echo "MISSING")"
echo "   ✓ Test Data: $(ls -la test_update_data.sql 2>/dev/null && echo "EXISTS" || echo "MISSING")"

echo ""
echo "4. Checking current app version in pubspec.yaml..."
grep "version:" pubspec.yaml

echo ""
echo "5. Testing update system integration..."
grep -n "UpdateDialog\|UpdateService" lib/main.dart lib/screens/settings_screen.dart

echo ""
echo "✅ Update System Test Complete!"
echo ""
echo "📋 Next steps to test the complete system:"
echo "1. Run the database schema in Supabase SQL editor"
echo "2. Insert test data using test_update_data.sql"
echo "3. Build and run the app: flutter run"
echo "4. Check Settings → 'Verifică actualizări'"
echo "5. Verify update dialog appears with test version"