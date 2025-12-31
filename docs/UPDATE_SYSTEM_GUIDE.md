# In-App Update System Setup Guide

## Overview
This guide explains how to set up and use the in-app update system for your Flutter app using Supabase as the backend.

## Database Setup

1. **Run the database schema script** in your Supabase SQL editor:
   ```sql
   -- Copy and paste the contents of supabase_app_versions_schema.sql
   ```

2. **Verify the table was created** by checking the Supabase dashboard for the `app_versions` table.

## Building and Uploading App Updates

### 1. Build the Android App Bundle (AAB)

```bash
# Navigate to your Flutter project directory
cd /path/to/your/flutter/project

# Clean the project
flutter clean
flutter pub get

# Update version in pubspec.yaml
# version: 1.0.1+2  (increment both version name and build number)

# Build the AAB file
flutter build appbundle --release
```

The AAB file will be generated at: `build/app/outputs/bundle/release/app-release.aab`

### 2. Upload AAB to Supabase Storage

1. **Create a storage bucket** in Supabase (if not already done):
   - Go to Supabase Dashboard > Storage
   - Create a new bucket named `app-updates`
   - Set it to public or configure appropriate policies

2. **Upload the AAB file**:
   - Navigate to the `app-updates` bucket
   - Create a folder structure like: `android/v1.0.1/`
   - Upload the `app-release.aab` file

3. **Get the public URL** of the uploaded file.

### 3. Insert Version Record

Insert a new version record in the `app_versions` table:

```sql
INSERT INTO app_versions (
    version_name,
    version_code,
    platform,
    download_url,
    changelog,
    is_mandatory,
    is_active
) VALUES (
    '1.0.1',                    -- Version name
    2,                          -- Version code (build number)
    'android',                  -- Platform
    'https://your-supabase-url.supabase.co/storage/v1/object/public/app-updates/android/v1.0.1/app-release.aab',
    'Bug fixes and improvements', -- Changelog
    false,                      -- Is mandatory update
    true                        -- Is active
);
```

## User Installation Process

When users download the AAB file through the in-app update system:

1. **Download**: The app will open the device's default browser/download manager
2. **File Location**: The AAB will be downloaded to the device's Downloads folder
3. **Installation Requirements**:
   - Users need to enable "Install unknown apps" for their browser/file manager
   - On Android 8.0+: Settings > Apps > Special app access > Install unknown apps
   - Select the app they'll use to install (usually File Manager or Chrome)
   - Toggle "Allow from this source"

## Testing the Update System

1. **Test with lower version**:
   - Temporarily change your app's version in `pubspec.yaml` to a lower number
   - Build and install this version
   - Upload a higher version AAB to Supabase
   - Test the update detection and download

2. **Test update dialog**:
   - Use the "Check for updates" option in Settings
   - Verify the dialog shows correct version information and changelog

## Configuration Options

### Mandatory Updates
Set `is_mandatory: true` in the database to force users to update:
- Users cannot dismiss the update dialog
- App functionality may be restricted until update

### Update Frequency
The app checks for updates:
- On app startup (after 2-second delay)
- When manually triggered from Settings
- You can modify the check frequency in `main.dart`

### Version Comparison
The system compares:
- Version codes (build numbers) for accurate comparison
- Only shows updates for the same platform (android/ios)
- Only shows active versions (`is_active: true`)

## Security Considerations

1. **Row Level Security**: The database schema includes RLS policies
2. **Storage Policies**: Configure appropriate Supabase storage policies
3. **URL Validation**: The system validates download URLs
4. **Platform Filtering**: Only shows updates for the current platform

## Troubleshooting

### Common Issues:

1. **Update not detected**:
   - Check version codes in database vs app
   - Verify `is_active` is true
   - Check platform matching

2. **Download fails**:
   - Verify Supabase storage URL is correct and public
   - Check device internet connection
   - Verify storage bucket permissions

3. **Installation issues**:
   - Guide users to enable "Install unknown apps"
   - Ensure AAB file is not corrupted
   - Check device compatibility

### Debug Information:

The app logs update-related information to the console. Check the debug logs for:
- Version comparison results
- Download URL responses
- Error messages

## Future Enhancements

Potential improvements:
- In-app download progress indicator
- Automatic installation (requires additional permissions)
- Delta updates for smaller downloads
- Update scheduling
- A/B testing for gradual rollouts