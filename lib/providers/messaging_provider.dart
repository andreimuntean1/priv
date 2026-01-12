import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/user.dart' as app_user;
import '../models/message.dart';
import '../models/file_attachment.dart';
import '../services/supabase_service.dart';
import '../models/typing_event.dart';
import '../services/typing_service.dart';
import '../services/notification_service.dart';

enum MessagingState { idle, loading, sending, error }

class MessagingProvider extends ChangeNotifier {
        // Typing event subscription
        StreamSubscription? _typingSubscription;

        void sendTyping(String chatId, String userId, bool isTyping) async {
          final event = TypingEvent(
            chatId: chatId,
            userId: userId,
            isTyping: isTyping,
            timestamp: DateTime.now(),
          );
          await TypingService.sendTypingEvent(event);
        }

        void subscribeToTyping(String chatId) {
          _typingSubscription?.cancel();
          _typingSubscription = TypingService.subscribeToTypingEvents(chatId).listen((events) {
            _typingUserIds.clear();
            for (final event in events) {
              if (event.isTyping) {
                _typingUserIds.add(event.userId);
              }
            }
            notifyListeners();
          });
        }
      // Typing indicator state
      final Set<String> _typingUserIds = {};
      Set<String> get typingUserIds => _typingUserIds;

      void setUserTyping(String userId, bool isTyping) {
        if (isTyping) {
          _typingUserIds.add(userId);
        } else {
          _typingUserIds.remove(userId);
        }
        notifyListeners();
      }

  final List<Message> _messages = [];
  final List<Message> _searchResults = [];
  app_user.User? _currentUser;
  MessagingState _state = MessagingState.idle;
  String? _errorMessage;
  String _searchQuery = '';
  bool _isSearchActive = false;
  StreamSubscription? _messagesSubscription;

  // Getters
  List<Message> get messages => List.unmodifiable(_messages.where((m) => !m.isDeleted).toList());
  List<Message> get searchResults => List.unmodifiable(_searchResults.where((m) => !m.isDeleted).toList());
  MessagingState get state => _state;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get isSearchActive => _isSearchActive;
  bool get isLoading => _state == MessagingState.loading;
  bool get isSending => _state == MessagingState.sending;



  void updateUser(app_user.User? user) {
    _currentUser = user;
    if (user != null) {
      _initializeMessaging();
    } else {
      _cleanup();
    }
  }

  void _initializeMessaging() {
    _loadMessages();
    _subscribeToMessages();
    if (_currentUser != null) {
       NotificationService().initialize(_currentUser!.id);
    }
  }

  void clearNotifications() {
    NotificationService().clearAll();
  }

  Future<void> _loadMessages() async {
    try {
      _state = MessagingState.loading;
      notifyListeners();

      final messageData = await SupabaseService.getMessages();
      _messages.clear();
      _messages.addAll(
        messageData.map((json) => Message.fromJson(json)).toList(),
      );

      // Populate reply messages
      _populateReplyMessages();

      _state = MessagingState.idle;
      _errorMessage = null;

      // Mark messages as read after loading
      // await markMessagesAsRead();
    } catch (e) {
      _state = MessagingState.error;
      _errorMessage = 'Failed to load messages: $e';
    }
    notifyListeners();
  }

  void _populateReplyMessages() {
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.replyToId != null) {
        final replyToMessage = _messages.firstWhere(
          (m) => m.id == message.replyToId,
          orElse: () => message, // Return original message if reply not found
        );
        
        if (replyToMessage.id != message.id) { // Only if we found a different message
          _messages[i] = message.copyWith(replyToMessage: replyToMessage);
        }
      }
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = SupabaseService.subscribeToMessages().listen(
      (List<Map<String, dynamic>> data) {
        _handleRealtimeMessages(data);
      },
      onError: (error) {
        _errorMessage = 'Real-time connection error: $error';
        notifyListeners();
      },
    );
  }

  void _handleRealtimeMessages(List<Map<String, dynamic>> data) {
    final newMessages = data.map((json) => Message.fromJson(json)).toList();
    
    // Update messages list efficiently
    for (final newMessage in newMessages) {
      final existingIndex = _messages.indexWhere((m) => m.id == newMessage.id);
      if (existingIndex != -1) {
        final existingMessage = _messages[existingIndex];
        
        // Preserve attachments from existing message since real-time doesn't include them
        if (existingMessage.hasAttachments && newMessage.attachments.isEmpty) {
          _messages[existingIndex] = newMessage.copyWith(
            attachments: existingMessage.attachments,
          );
        } else {
          _messages[existingIndex] = newMessage;
        }
      } else {
        // Insert in correct chronological position
        final insertIndex = _messages.indexWhere(
          (m) => m.createdAt.isAfter(newMessage.createdAt),
        );
        if (insertIndex == -1) {
          _messages.add(newMessage);
        } else {
          _messages.insert(insertIndex, newMessage);
        }

        // Real-time payload doesn't include joined data (sender, attachments).
        // If it's not a simple text message or we need sender info, fetch the full record.
        // We do this for ALL new real-time messages to ensure consistency.
        _refreshMessage(newMessage.id!); 
      }
    }

    // Populate reply messages for new messages
    _populateReplyMessages();

    // Update search results if search is active
    if (_isSearchActive) {
      _updateSearchResults();
    }

    notifyListeners();
  }

  Future<bool> sendMessage({
    required String content,
    String? replyToId,
    List<FileAttachment>? attachments,
  }) async {
    if (_currentUser == null || (content.trim().isEmpty && (attachments == null || attachments.isEmpty))) return false;

    try {
      _state = MessagingState.sending;
      notifyListeners();

      List<String>? attachmentIds;
      String? messageType;
      if (attachments != null && attachments.isNotEmpty) {
        attachmentIds = attachments.map((a) => a.id).toList();
        
        // Determine message type based on first attachment
        if (attachments.first.isImage) {
          messageType = 'image';
        } else if (attachments.first.isAudio) {
          messageType = 'audio';
        } else {
          messageType = 'file';
        }
      }

      final messageData = await SupabaseService.sendMessage(
        content: content.trim(),
        senderId: _currentUser!.id,
        replyToId: replyToId,
        attachmentIds: attachmentIds,
        messageType: messageType,
      );

      // If message has attachments, manually update it in the messages list
      if (attachments != null && attachments.isNotEmpty) {
        await _refreshMessage(messageData['id']);
      }

      _state = MessagingState.idle;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _state = MessagingState.error;
      _errorMessage = 'Failed to send message: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> searchMessages(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }

    try {
      _searchQuery = query.trim();
      _isSearchActive = true;
      _state = MessagingState.loading;
      notifyListeners();

      final searchData = await SupabaseService.searchMessages(_searchQuery);
      _searchResults.clear();
      _searchResults.addAll(
        searchData.map((json) => Message.fromJson(json)).toList(),
      );

      _state = MessagingState.idle;
    } catch (e) {
      _state = MessagingState.error;
      _errorMessage = 'Search failed: $e';
    }
    notifyListeners();
  }

  void _updateSearchResults() {
    if (_searchQuery.isEmpty) return;

    _searchResults.clear();
    final query = _searchQuery.toLowerCase();
    _searchResults.addAll(
      _messages.where((message) =>
          !message.isDeleted &&
          (message.content.toLowerCase().contains(query) ||
          message.sender?.username.toLowerCase().contains(query) == true ||
          message.attachments.any((attachment) =>
              attachment.fileName.toLowerCase().contains(query)))),
    );
  }

  void clearSearch() {
    _searchQuery = '';
    _isSearchActive = false;
    _searchResults.clear();
    notifyListeners();
  }

  Message? getMessageById(String messageId) {
    try {
      return _messages.firstWhere((m) => m.id == messageId);
    } catch (e) {
      return null;
    }
  }

  List<Message> getMessagesForToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _messages.where((m) => m.createdAt.isAfter(startOfDay)).toList();
  }

  List<Message> getMessagesForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _messages
        .where((m) =>
            m.createdAt.isAfter(startOfDay) && m.createdAt.isBefore(endOfDay))
        .toList();
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await SupabaseService.deleteMessage(messageId);
      
      // Find the message and update it locally
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = _messages[messageIndex].copyWith(isDeleted: true);
        
        // Update search results if search is active
        if (_isSearchActive) {
          _updateSearchResults();
        }
        
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete message: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _refreshMessage(String messageId) async {
    int retries = 0;
    const maxRetries = 5;
    
    while (retries < maxRetries) {
      try {
        print('Refreshing message $messageId (Attempt ${retries + 1})');
        final messageData = await SupabaseService.getMessageById(messageId);
        
        if (messageData != null) {
          final updatedMessage = Message.fromJson(messageData);
          
          // Check if we need to retry (e.g. expected attachments but found none)
          bool needsRetry = false;
          if (updatedMessage.messageType != MessageType.text && 
              updatedMessage.attachments.isEmpty) {
            print('Message ${updatedMessage.id} expects attachments but found none. Retrying...');
            needsRetry = true;
          }

          final existingIndex = _messages.indexWhere((m) => m.id == messageId);
          
          if (existingIndex != -1) {
            _messages[existingIndex] = updatedMessage;
            _populateReplyMessages();
            notifyListeners();
          } else {
            // Message not found in list, add it
            _messages.add(updatedMessage);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _populateReplyMessages();
            notifyListeners();
          }

          if (!needsRetry) {
             print('Message $messageId refreshed successfully with ${updatedMessage.attachments.length} attachments');
             return;
          }
        }
      } catch (e) {
        print('Error refreshing message $messageId: $e');
      }
      
      retries++;
      if (retries < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    print('Failed to fully hydrate message $messageId after $maxRetries attempts');
  }

  void _cleanup() {
    _messagesSubscription?.cancel();
    _messages.clear();
    _searchResults.clear();
    _searchQuery = '';
    _isSearchActive = false;
    _state = MessagingState.idle;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}