import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../models/user.dart' as app_user;
import '../services/supabase_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState.initial;
  app_user.User? _currentUser;
  String? _errorMessage;

  AuthState get state => _state;
  app_user.User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  String? get currentUserEmail => _supabase.auth.currentUser?.email;

  final SupabaseClient _supabase = SupabaseService.client;

  AuthProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen to auth state changes
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      print('Auth state change: $event');
      print('Session user: ${session?.user?.email}');

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session?.user != null) {
            print('User signed in: ${session!.user.email}');
            _loadUserProfile(session.user.id);
          }
          break;
        case AuthChangeEvent.signedOut:
          print('User signed out');
          if (_currentUser != null) {
            // Cleanup if needed
          }
          _currentUser = null;
          _state = AuthState.unauthenticated;
          notifyListeners();
          break;
        case AuthChangeEvent.userUpdated:
          if (session?.user != null) {
            print('User updated: ${session!.user.email}');
            _loadUserProfile(session.user.id);
          }
          break;
        default:
          break;
      }
    });

    // Check if user is already signed in
    final session = _supabase.auth.currentSession;
    if (session?.user != null) {
      _loadUserProfile(session!.user.id);
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      final userData = await SupabaseService.getUserById(userId);
      if (userData != null) {
        _currentUser = app_user.User.fromJson(userData);
        _state = AuthState.authenticated;
        _errorMessage = null;
        
        // Notify listeners so other providers can react to user being loaded
        notifyListeners();
      } else {
        _state = AuthState.error;
        _errorMessage = 'Nu te-am găsit, habar n-am cine ești.';
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'No stai să vezi ce am pățit când încercam să încarc profilu tău: $e';
    }
    notifyListeners();
  }

  Future<bool> sendMagicLink({required String email}) async {
    try {
      _state = AuthState.loading;
      _errorMessage = null;
      notifyListeners();

      // Check if email is authorized
      final allowedEmails = [
        'andrei.priv@andreimuntean.dev',
        'luci.priv@andreimuntean.dev'
      ];
      
      if (!allowedEmails.contains(email.trim().toLowerCase())) {
        _state = AuthState.error;
        _errorMessage = 'Îmi pare rău, nu știu cine ți-o zis că ai voie aici, da n-ai.';
        notifyListeners();
        return false;
      }

      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kIsWeb ? Uri.base.origin : 'privmessaging://auth/callback',
      );

      _state = AuthState.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'No stai să vezi ce am pățit când încercam să-ți trimit linkul cel epic: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _state = AuthState.loading;
      notifyListeners();

      await _supabase.auth.signOut();
      _currentUser = null;
      _state = AuthState.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'Sign out failed: $e';
    }
    notifyListeners();
  }

  Future<bool> updateProfile({String? username, String? avatarUrl}) async {
    if (_currentUser == null) return false;

    try {
      _state = AuthState.loading;
      notifyListeners();

      await SupabaseService.updateUserProfile(
        userId: _currentUser!.id,
        username: username,
        avatarUrl: avatarUrl,
      );

      // Reload user profile
      await _loadUserProfile(_currentUser!.id);
      return true;
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = 'No stai să vezi ce am pățit când încercam să actualizez profilu tău: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      _errorMessage = 'No stai să vezi ce am pățit când încercam să resetez parola: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Simple user selection for 2-user system
  Future<List<app_user.User>> getAllUsers() async {
    try {
      final response = await _supabase.from('users').select();
      return response.map<app_user.User>((json) => app_user.User.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}