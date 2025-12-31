import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {

  // App Information
  static const String appName = 'Private Messaging';
  static const String appVersion = '1.0.0';
  
  // Supabase Configuration
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // File Upload Limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
  static const List<String> allowedFileTypes = [
    'pdf', 'doc', 'docx', 'txt', 'rtf',
    'mp3', 'wav', 'ogg', 'aac', 'm4a',
    'mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'
  ];
  
  // Message Limits
  static const int maxMessageLength = 4000;
  static const int maxAttachmentsPerMessage = 5;
  
  // UI Configuration
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 500);
  
  // Pagination
  static const int messagesPerPage = 50;
  static const int searchResultsPerPage = 20;
  
  // Notification Configuration
  static const String notificationChannelId = 'private_messaging_channel';
  static const String notificationChannelName = 'Private Messages';
  static const String notificationChannelDescription = 'Notifications for new private messages';
  
  // Storage Keys
  static const String themePreferenceKey = 'theme_mode';
  static const String notificationPreferenceKey = 'notifications_enabled';
  static const String autoDownloadPreferenceKey = 'auto_download_media';
  
  // API Endpoints (if using custom backend)
  static const String baseApiUrl = 'https://your-api-domain.com/api/v1';
  
  // Error Messages
  static const String networkErrorMessage = 'Please check your internet connection';
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String authErrorMessage = 'Authentication failed. Please sign in again.';
  static const String fileUploadErrorMessage = 'Failed to upload file. Please try again.';
  
  // Success Messages
  static const String messagesSentMessage = 'Message sent successfully';
  static const String profileUpdatedMessage = 'Profile updated successfully';
  static const String fileUploadedMessage = 'File uploaded successfully';
}