import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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
  app_user.User? Function(String userId)? _userLookup;
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

  void setUserLookup(app_user.User? Function(String userId)? lookup) {
    _userLookup = lookup;
  }

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
    _subscribeToBroadcast();
    if (_currentUser != null) {
       NotificationService().initialize(_currentUser!.id);
    }
  }

  void _subscribeToBroadcast() {
    SupabaseService.initBroadcastChannel(
      onBroadcastReceived: (payload) {
        _handleBroadcastMessage(payload);
      },
    );
  }

  void _handleBroadcastMessage(Map<String, dynamic> payload) {
    try {
      final message = Message.fromJson(payload);
      // Only process messages from other senders (sender already has it optimistically)
      if (message.senderId != _currentUser?.id) {
        _insertOrUpdateIncomingMessage(message);
      }
    } catch (e) {
      print('Error processing broadcast message: $e');
    }
  }

  void clearNotifications() {
    NotificationService().clearAll();
  }

  Future<void> onAppResumed() async {
    clearNotifications();
    _subscribeToMessages();
    _subscribeToBroadcast();

    if (_messages.isNotEmpty) {
      try {
        final lastSentMsg = _messages.lastWhere(
          (m) => m.sendStatus == MessageSendStatus.sent,
          orElse: () => _messages.last,
        );
        final missedData = await SupabaseService.getMessagesSince(lastSentMsg.createdAt);
        if (missedData.isNotEmpty) {
          _handleRealtimeMessages(missedData);
        }
      } catch (e) {
        print('Error syncing missed messages on resume: $e');
      }
    } else {
      _loadMessages();
    }
  }

  Future<void> _loadMessages() async {
    try {
      _state = MessagingState.loading;
      notifyListeners();

      final messageData = await SupabaseService.getMessages();
      _messages.clear();
      _messages.addAll(
        messageData.map((json) {
          var msg = Message.fromJson(json);
          if (msg.sender == null) {
            final sender = _userLookup?.call(msg.senderId) ??
                (msg.senderId == _currentUser?.id ? _currentUser : null);
            if (sender != null) {
              msg = msg.copyWith(sender: sender);
            }
          }
          return msg;
        }).toList(),
      );

      // Populate reply messages
      _populateReplyMessages();

      _state = MessagingState.idle;
      _errorMessage = null;
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

  void _insertOrUpdateIncomingMessage(Message rawMessage) {
    Message message = rawMessage;
    // Resolve sender in-memory immediately for zero network roundtrip
    if (message.sender == null) {
      final resolvedSender = _userLookup?.call(message.senderId) ??
          (message.senderId == _currentUser?.id ? _currentUser : null);
      if (resolvedSender != null) {
        message = message.copyWith(sender: resolvedSender);
      }
    }

    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      final existingMessage = _messages[existingIndex];
      _messages[existingIndex] = message.copyWith(
        attachments: existingMessage.attachments.isNotEmpty && message.attachments.isEmpty
            ? existingMessage.attachments
            : (message.attachments.isNotEmpty ? message.attachments : existingMessage.attachments),
        sender: message.sender ?? existingMessage.sender,
        replyToMessage: existingMessage.replyToMessage ?? message.replyToMessage,
        sendStatus: MessageSendStatus.sent,
      );
    } else {
      final insertIndex = _messages.indexWhere(
        (m) => m.createdAt.isAfter(message.createdAt),
      );
      if (insertIndex == -1) {
        _messages.add(message);
      } else {
        _messages.insert(insertIndex, message);
      }

      // Only refresh if attachments are missing
      if (message.messageType != MessageType.text && message.attachments.isEmpty) {
        _refreshMessage(message.id);
      }
    }

    _populateReplyMessages();

    if (_isSearchActive) {
      _updateSearchResults();
    }

    notifyListeners();
  }

  void _handleRealtimeMessages(List<Map<String, dynamic>> data) {
    final newMessages = data.map((json) => Message.fromJson(json)).toList();
    
    for (final newMessage in newMessages) {
      _insertOrUpdateIncomingMessage(newMessage);
    }
  }

  Future<bool> sendMessage({
    required String content,
    String? replyToId,
    List<FileAttachment>? attachments,
  }) async {
    if (_currentUser == null || (content.trim().isEmpty && (attachments == null || attachments.isEmpty))) return false;

    // 1. Client-generated UUID for seamless reconciliation
    final messageId = const Uuid().v4();
    final now = DateTime.now();

    List<String>? attachmentIds;
    String? messageTypeString;
    MessageType messageType = MessageType.text;
    if (attachments != null && attachments.isNotEmpty) {
      attachmentIds = attachments.map((a) => a.id).toList();
      if (attachments.first.isImage) {
        messageTypeString = 'image';
        messageType = MessageType.image;
      } else if (attachments.first.isAudio) {
        messageTypeString = 'audio';
        messageType = MessageType.audio;
      } else {
        messageTypeString = 'file';
        messageType = MessageType.file;
      }
    }

    // Resolve replyToMessage locally
    Message? replyToMessage;
    if (replyToId != null) {
      replyToMessage = getMessageById(replyToId);
    }

    // 2. OPTIMISTIC INSERTION (0ms perceived latency for sender)
    final optimisticMessage = Message(
      id: messageId,
      content: content.trim(),
      senderId: _currentUser!.id,
      sender: _currentUser,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      messageType: messageType,
      attachments: attachments ?? const [],
      createdAt: now,
      updatedAt: now,
      sendStatus: MessageSendStatus.sending,
    );

    _messages.add(optimisticMessage);
    _populateReplyMessages();
    if (_isSearchActive) {
      _updateSearchResults();
    }
    notifyListeners(); // Instant render!

    // 3. Emit over Realtime Broadcast for ultra-fast peer delivery (<50ms)
    SupabaseService.broadcastMessage({
      'id': messageId,
      'content': content.trim(),
      'sender_id': _currentUser!.id,
      'sender': _currentUser!.toJson(),
      'reply_to_id': replyToId,
      'message_type': messageTypeString ?? 'text',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'file_attachments': attachments?.map((a) => a.toJson()).toList() ?? [],
    });

    // 4. Persist to Supabase Database asynchronously via REST
    try {
      final messageData = await SupabaseService.sendMessage(
        id: messageId,
        content: content.trim(),
        senderId: _currentUser!.id,
        replyToId: replyToId,
        attachmentIds: attachmentIds,
        messageType: messageTypeString,
      );

      final existingIndex = _messages.indexWhere((m) => m.id == messageId);
      if (existingIndex != -1) {
        _messages[existingIndex] = _messages[existingIndex].copyWith(
          sendStatus: MessageSendStatus.sent,
        );
        notifyListeners();
      }

      if (attachments != null && attachments.isNotEmpty) {
        _refreshMessage(messageData['id']);
      }

      return true;
    } catch (e) {
      print('Failed to send message: $e');
      final existingIndex = _messages.indexWhere((m) => m.id == messageId);
      if (existingIndex != -1) {
        _messages[existingIndex] = _messages[existingIndex].copyWith(
          sendStatus: MessageSendStatus.failed,
        );
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> retryMessage(String messageId) async {
    final msg = getMessageById(messageId);
    if (msg == null || _currentUser == null) return false;

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(sendStatus: MessageSendStatus.sending);
      notifyListeners();
    }

    try {
      await SupabaseService.sendMessage(
        id: msg.id,
        content: msg.content,
        senderId: _currentUser!.id,
        replyToId: msg.replyToId,
        messageType: msg.messageType.name,
      );

      final updatedIndex = _messages.indexWhere((m) => m.id == messageId);
      if (updatedIndex != -1) {
        _messages[updatedIndex] = _messages[updatedIndex].copyWith(
          sendStatus: MessageSendStatus.sent,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      final updatedIndex = _messages.indexWhere((m) => m.id == messageId);
      if (updatedIndex != -1) {
        _messages[updatedIndex] = _messages[updatedIndex].copyWith(
          sendStatus: MessageSendStatus.failed,
        );
        notifyListeners();
      }
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