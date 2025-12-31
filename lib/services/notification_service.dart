import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:private_messaging/services/supabase_service.dart';
import 'package:private_messaging/main.dart'; // To access Supabase credentials constants if defined, or we hardcode for background

const String categoryMessage = 'MESSAGE_CATEGORY';

// Background Handler (Must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  // Local notifications kept for foreground (if we ever need it) or specific use cases, 
  // but simpler now.
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  
  // Expose token flow
  Stream<String> get onTokenRefresh => _firebaseMessaging.onTokenRefresh;

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    // 1. Initialize Local Notifications (Basic setup)
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(initSettings);

    // 1.1 Create High Importance Channel (Android) to ensure Heads-up notifications
    // Even if using Firebase system notifications, valid channel config is required for pop-ups.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'message_channel', // id
      'Messages', // title
      description: 'Notifications for new messages', // description
      importance: Importance.max, // Importance.max = Heads Up
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Request Permissions (Firebase)
    await requestPermission();
    
    // 3. Get & Save Token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await SupabaseService.updateFcmToken(token, userId);
    }
    
    // 4. Token Refresh Listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      SupabaseService.updateFcmToken(newToken, userId);
    });

    // 5. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
       print('Foreground message received: ${message.data}');
       // We do not show notification in foreground as per requirements.
    });
    
    // 6. Background Message Handler Setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _isInitialized = true;
  }

  Future<void> requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> clearAll() async {
    await _localNotifications.cancelAll();
  }
}