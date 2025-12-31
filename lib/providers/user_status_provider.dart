import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/user.dart' as app_user;
import '../services/supabase_service.dart';

class UserStatusProvider extends ChangeNotifier {
  final Map<String, app_user.User> _users = {};
  StreamSubscription? _usersSubscription;

  // Getters
  Map<String, app_user.User> get users => Map.unmodifiable(_users);
  
  app_user.User? getUser(String userId) {
    return _users[userId];
  }

  void initialize() {
    _subscribeToUsers();
  }

  void _subscribeToUsers() {
    _usersSubscription?.cancel();
    _usersSubscription = SupabaseService.subscribeToUsers().listen(
      (List<Map<String, dynamic>> data) {
        _handleUserUpdates(data);
      },
      onError: (error) {
        print('User status subscription error: $error');
      },
    );
  }

  void _handleUserUpdates(List<Map<String, dynamic>> data) {
    bool hasChanges = false;
    
    for (final userData in data) {
      final user = app_user.User.fromJson(userData);
      
      // Store new data
      final previousUser = _users[user.id];
      _users[user.id] = user;
      
      // Check if user data changed (username, avatar, etc)
      if (previousUser != user) {
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    super.dispose();
  }
}