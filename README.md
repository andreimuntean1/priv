# Private Messaging Flutter App

A secure, real-time private messaging application built with Flutter and Supabase, designed for communication between exactly two users.

## Features

### 🚀 Core Functionality
- **Real-time Messaging**: Instant bidirectional message delivery using Supabase real-time subscriptions
- **File Sharing**: Upload and share images, documents, audio, and video files
- **Message Search**: Full-text search through conversation history with result highlighting
- **Reply System**: Reply to specific messages with context threading
- **Message Status**: Delivery and read receipt tracking
- **Responsive Design**: Optimized for both Android and iOS devices

### 🎨 UI/UX Features
- **Modern Design**: Clean, iOS-style interface with smooth animations
- **Dark/Light Themes**: System-adaptive theming with manual override
- **Message Bubbles**: Contextual message grouping and timestamps
- **File Previews**: Inline image preview and file type recognition
- **Search Interface**: Dedicated search mode with advanced filtering

### 🔧 Technical Features
- **Provider State Management**: Efficient state management with proper separation of concerns
- **Offline Support**: Message queuing and sync when connection is restored
- **Push Notifications**: Firebase Cloud Messaging for background notifications
- **File Upload**: Supabase Storage integration with progress tracking
- **Authentication**: Simple email/password auth with profile management
- **Error Handling**: Comprehensive error states and user feedback

## Architecture

### Technology Stack
- **Frontend**: Flutter 3.10+ with Dart
- **Backend**: Supabase (PostgreSQL + Real-time + Storage + Auth)
- **State Management**: Provider pattern
- **Notifications**: Firebase Cloud Messaging
- **File Handling**: Supabase Storage with local caching

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── message.dart
│   └── file_attachment.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   ├── messaging_provider.dart
│   └── theme_provider.dart
├── screens/                  # UI screens
│   ├── splash_screen.dart
│   ├── auth_screen.dart
│   ├── chat_screen.dart
│   └── settings_screen.dart
├── widgets/                  # Reusable components
│   ├── message_bubble.dart
│   ├── chat_input.dart
│   ├── search_bar_widget.dart
│   └── file_attachment_widget.dart
├── services/                 # Business logic
│   ├── supabase_service.dart
│   ├── file_service.dart
│   └── notification_service.dart
└── utils/                    # Utilities
    ├── theme.dart
    ├── constants.dart
    ├── validation_utils.dart
    └── date_time_utils.dart
```

## Setup Instructions

### Prerequisites
- Flutter SDK 3.10.0 or later
- Dart SDK 3.0.0 or later
- Android Studio / VS Code with Flutter extensions
- Supabase account
- Firebase project (for notifications)

### 1. Clone and Setup Flutter Project

```bash
# Navigate to your project directory
cd /path/to/your/project

# Install dependencies
flutter pub get

# For iOS (if developing on macOS)
cd ios && pod install && cd ..
```

### 2. Supabase Configuration

#### Create Supabase Project
1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note your project URL and anon key

#### Setup Database
1. In your Supabase dashboard, go to SQL Editor
2. Run the SQL script from `supabase_schema.sql`
3. Verify that all tables, policies, and triggers were created successfully

#### Configure Storage
1. Go to Storage in your Supabase dashboard
2. Create buckets:
   - `message-attachments` (public)
   - `profile-avatars` (public)
3. Configure storage policies as defined in the SQL script

#### Update Configuration
1. Open `lib/main.dart`
2. Replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with your actual values:

```dart
await Supabase.initialize(
  url: 'https://your-project-id.supabase.co',
  anonKey: 'your-anon-key',
);
```

### 3. Firebase Configuration (for notifications)

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing
3. Add your Flutter app to the project

#### Android Setup
1. Download `google-services.json`
2. Place it in `android/app/`
3. Update `android/build.gradle`:
```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
}
```
4. Update `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'
```

#### iOS Setup
1. Download `GoogleService-Info.plist`
2. Add it to `ios/Runner/` in Xcode
3. Update iOS configuration in Xcode project settings

### 4. Update Configuration Files

#### Update Constants
Open `lib/utils/constants.dart` and update:
```dart
static const String supabaseUrl = 'https://your-project-id.supabase.co';
static const String supabaseAnonKey = 'your-anon-key';
```

#### Update Android Permissions
The `android/app/src/main/AndroidManifest.xml` is already configured with necessary permissions.

#### Update iOS Info.plist
Update the Supabase domain in `ios/Runner/Info.plist`:
```xml
<key>your-supabase-url.supabase.co</key>
```

### 5. Run the Application

```bash
# Check if everything is set up correctly
flutter doctor

# Run on connected device/emulator
flutter run

# For release build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Database Schema

### Tables
- **users**: User profiles extending Supabase auth
- **messages**: Chat messages with metadata
- **file_attachments**: File uploads linked to messages
- **message_status**: Message delivery and read status

### Key Features
- Row Level Security (RLS) for data protection
- Real-time subscriptions for live updates
- Full-text search capabilities
- Automatic user profile creation on signup
- File storage with public access URLs

## Usage Guide

### Authentication
1. **Sign Up**: Create account with email, password, and username
2. **Sign In**: Login with existing credentials
3. **Profile**: Update username and avatar in settings

### Messaging
1. **Send Message**: Type and send text messages
2. **File Attachment**: Use + button to attach camera, gallery, or files
3. **Reply**: Long-press message and select reply
4. **Search**: Tap search icon to find messages

### File Sharing
- **Images**: Auto-preview in chat with download option
- **Documents**: File icon with name, size, and download
- **Size Limits**: 10MB for files, 5MB for images
- **Supported Types**: Images, documents, audio, video files

### Settings
- **Theme**: Light, dark, or system adaptive
- **Profile**: Change username and avatar
- **Notifications**: Configure push notification preferences

## Customization

### Themes
Modify `lib/utils/theme.dart` to customize:
- Colors and typography
- Component styles
- Animation durations

### Message Limits
Update `lib/utils/constants.dart`:
- Maximum message length
- File size limits
- Supported file types

### UI Components
All widgets in `lib/widgets/` are customizable:
- Message bubble styling
- Input field appearance
- Search interface design

## Security Considerations

### Data Protection
- All API calls use Supabase RLS policies
- File uploads are validated for type and size
- User input is sanitized and validated

### Authentication
- Secure email/password authentication
- JWT tokens for API authorization
- Automatic session management

### Privacy
- End-to-end message encryption (implement as needed)
- Secure file storage with access controls
- Optional message deletion

## Performance Optimization

### Message Loading
- Pagination for large conversation histories
- Efficient real-time subscription management
- Local caching for offline access

### File Handling
- Progressive image loading
- File size validation before upload
- Cached network images for performance

### State Management
- Provider pattern for efficient rebuilds
- Lazy loading of conversation data
- Memory management for large files

## Troubleshooting

### Common Issues

#### Supabase Connection
- Verify URL and anon key are correct
- Check network connectivity
- Ensure RLS policies are properly configured

#### File Upload Issues
- Check file size limits
- Verify storage bucket permissions
- Ensure supported file types

#### Notification Problems
- Verify Firebase configuration
- Check device notification permissions
- Test FCM token generation

#### Build Issues
- Run `flutter clean && flutter pub get`
- Update Flutter to latest stable version
- Check platform-specific configurations

## Contributing

### Development Setup
1. Follow setup instructions above
2. Create feature branches from main
3. Write tests for new functionality
4. Follow Flutter/Dart style guidelines

### Code Style
- Use `flutter format` for formatting
- Follow effective Dart guidelines
- Add documentation for public APIs
- Write descriptive commit messages

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
1. Check existing GitHub issues
2. Create new issue with detailed description
3. Include device/platform information
4. Provide reproduction steps

## Roadmap

### Planned Features
- [ ] Voice message recording and playback
- [ ] Message reactions (emoji)
- [ ] Message editing and deletion
- [ ] Advanced search filters
- [ ] Export conversation history
- [ ] Multiple chat support
- [ ] End-to-end encryption
- [ ] Desktop application (Flutter Desktop)

### Technical Improvements
- [ ] Offline message sync
- [ ] Message backup and restore
- [ ] Performance monitoring
- [ ] Automated testing suite
- [ ] CI/CD pipeline
- [ ] Analytics integration

---

Built with ❤️ using Flutter and Supabase