import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isDev => dotenv.env['APP_ENV'] == 'dev';

  // Database table names
  static String get usersTable => isDev ? 'users_dev' : 'users';
  static String get messagesTable => isDev ? 'messages_dev' : 'messages';
  static String get fileAttachmentsTable => isDev ? 'file_attachments_dev' : 'file_attachments';
  static String get fcmTokensTable => isDev ? 'fcm_tokens_dev' : 'fcm_tokens';
  static String get messageStatusTable => isDev ? 'message_status_dev' : 'message_status';

  static const String supabaseUrl = 'https://csjsqfqdacymcuijbseh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzanNxZnFkYWN5bWN1aWpic2VoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1MDkzNjUsImV4cCI6MjA3ODA4NTM2NX0.5spSlh55HSnk_HvTPQlNvtmIM7NLpA3siLVPurSh1j8';

  // Storage buckets
  static const String messageAttachmentsBucket = 'message-attachments';
  static const String profileAvatarsBucket = 'profile-avatars';

  // Real-time subscriptions
  static Stream<List<Map<String, dynamic>>> subscribeToMessages() {
    return client
        .from(messagesTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }

  static Stream<List<Map<String, dynamic>>> subscribeToUsers() {
    return client
        .from(usersTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }

  // Database operations
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    final response = await client
        .from(usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  static Future<List<Map<String, dynamic>>> getMessages() async {
    final messages = await client
        .from(messagesTable)
        .select('''
          *,
          sender:$usersTable!sender_id(*),
          file_attachments:$fileAttachmentsTable(*)
        ''')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(messages);
  }

  static Future<Map<String, dynamic>?> getMessageById(String messageId) async {
    final response = await client
        .from(messagesTable)
        .select('''
          *,
          sender:$usersTable!sender_id(*),
          file_attachments:$fileAttachmentsTable(*)
        ''')
        .eq('id', messageId)
        .single();
    return response;
  }

  // Make this static and robust for background usage if client is available
  static Future<Map<String, dynamic>> sendMessage({
    required String content,
    required String senderId,
    String? replyToId,
    List<String>? attachmentIds,
    String? messageType,
    SupabaseClient? backgroundClient,
  }) async {
    final supabase = backgroundClient ?? client;
    
    final response = await supabase.from(messagesTable).insert({
      'content': content,
      'sender_id': senderId,
      'reply_to_id': replyToId,
      'message_type': messageType ?? 'text',
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    // Create new attachment records linked to the message
    if (attachmentIds != null && attachmentIds.isNotEmpty) {
      for (String attachmentId in attachmentIds) {
        try {
          // Get the original attachment data
          final originalAttachment = await supabase.from(fileAttachmentsTable)
            .select('*')
            .eq('id', attachmentId)
            .single();
          // Create a new attachment record with the message_id
          await createFileAttachment(
            fileName: originalAttachment['file_name'],
            fileUrl: originalAttachment['file_url'],
            fileType: originalAttachment['file_type'],
            fileSize: originalAttachment['file_size'],
            messageId: response['id'],
            backgroundClient: supabase,
          );
          // Delete the temporary attachment to clean up
          await supabase.from(fileAttachmentsTable)
            .delete()
            .eq('id', attachmentId);
        } catch (e) {
          // Handle error
        }
      }
      // Fetch the updated message with attachments for return
      final updatedMessage = await supabase
          .from(messagesTable)
          .select('''
            *,
            sender:$usersTable!sender_id(*),
            file_attachments:$fileAttachmentsTable(*)
          ''')
          .eq('id', response['id'])
          .single();
      return updatedMessage;
    }
    return response;
  }

  static Future<String> uploadFile({
    required String bucketName,
    required String fileName,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from(bucketName).uploadBinary(
      path,
      Uint8List.fromList(fileBytes),
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return client.storage.from(bucketName).getPublicUrl(path);
  }

  static Future<Map<String, dynamic>> createFileAttachment({
    required String fileName,
    required String fileUrl,
    required String fileType,
    required int fileSize,
    String? messageId,
    SupabaseClient? backgroundClient,
  }) async {
    final supabase = backgroundClient ?? client;
    final attachmentData = {
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': DateTime.now().toIso8601String(),
    };
    if (messageId != null) {
      attachmentData['message_id'] = messageId;
    }
    return await supabase.from(fileAttachmentsTable).insert(attachmentData).select().single();
  }

  static Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    final response = await client
        .from(messagesTable)
        .select('''
          *,
          sender:$usersTable!sender_id(*),
          file_attachments:$fileAttachmentsTable(*)
        ''')
        .textSearch('content', query);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> deleteMessage(String messageId) async {
    await client
        .from(messagesTable)
        .update({'is_deleted': true})
        .eq('id', messageId);
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? username,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await client.from(usersTable).update(updates).eq('id', userId);
    }
  }



  // --- FCM Token Management ---

  static Future<void> updateFcmToken(String token, String userId) async {
    try {
      await client.from(fcmTokensTable).upsert({
        'user_id': userId,
        'token': token,
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, token');
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }
  
  static Future<void> removeFcmToken(String token) async {
      try {
        await client.from(fcmTokensTable).delete().eq('token', token);
      } catch (e) {
        print('Error removing FCM token: $e');
      }
  }

  // --- Background Actions ---
  

}