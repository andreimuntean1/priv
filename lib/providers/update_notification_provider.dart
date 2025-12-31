import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version.dart';
import '../services/update_service.dart';
import 'dart:async';

class UpdateNotificationProvider extends ChangeNotifier {
  static const String _dismissedVersionsKey = 'dismissed_update_versions';
  static const String _remindLaterKey = 'remind_later_timestamp';
  
  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription? _versionSubscription;
  
  AppVersion? _availableUpdate;
  bool _showNotification = false;
  Set<int> _dismissedVersions = {};
  DateTime? _remindLaterUntil;
  
  AppVersion? get availableUpdate => _availableUpdate;
  bool get showNotification => _showNotification;
  
  UpdateNotificationProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _loadDismissedVersions();
    await _loadRemindLaterTimestamp();
    await _checkForUpdates();
    _subscribeToVersionUpdates();
  }
  
  Future<void> _loadDismissedVersions() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedList = prefs.getStringList(_dismissedVersionsKey) ?? [];
    _dismissedVersions = dismissedList.map((v) => int.parse(v)).toSet();
  }
  
  Future<void> _loadRemindLaterTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_remindLaterKey);
    if (timestamp != null) {
      _remindLaterUntil = DateTime.parse(timestamp);
      
      // Clear if expired
      if (_remindLaterUntil!.isBefore(DateTime.now())) {
        _remindLaterUntil = null;
        await prefs.remove(_remindLaterKey);
      }
    }
  }
  
  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await UpdateService.getUpdateInfo();
      
      if (updateInfo != null && updateInfo.hasUpdate) {
        final versionCode = updateInfo.latestVersion.versionCode;
        
        // Don't show if dismissed or reminded later
        if (_dismissedVersions.contains(versionCode)) {
          return;
        }
        
        if (_remindLaterUntil != null && DateTime.now().isBefore(_remindLaterUntil!)) {
          return;
        }
        
        _availableUpdate = updateInfo.latestVersion;
        _showNotification = true;
        notifyListeners();
      }
    } catch (e) {
      // Error checking for updates
    }
  }
  
  void _subscribeToVersionUpdates() {
    try {
      
      _versionSubscription = _supabase
        .from('app_versions')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
          
          if (data.isNotEmpty) {
            // Get the latest version from the stream
            final latest = data.reduce((a, b) {
              final aCode = a['version_code'] as int;
              final bCode = b['version_code'] as int;
              return aCode > bCode ? a : b;
            });
            
            _handleNewVersion(AppVersion.fromJson(latest));
          }
        });
    } catch (e) {
      // Error subscribing to version updates
    }
  }
  
  void _handleNewVersion(AppVersion newVersion) async {
    
    final currentInfo = await UpdateService.getCurrentAppInfo();
    final currentVersionCode = int.tryParse(currentInfo.buildNumber) ?? 0;
    
    // Check if this is actually a new version
    if (newVersion.versionCode > currentVersionCode) {
      
      // Don't show if already dismissed
      if (_dismissedVersions.contains(newVersion.versionCode)) {
        return;
      }
      
      // Don't show if reminded later
      if (_remindLaterUntil != null && DateTime.now().isBefore(_remindLaterUntil!)) {
        return;
      }
      
      
      _availableUpdate = newVersion;
      _showNotification = true;
      notifyListeners();
    } else {
      // Not a new version
    }
  }
  
  Future<void> dismissUpdate() async {
    if (_availableUpdate == null) return;
    
    _dismissedVersions.add(_availableUpdate!.versionCode);
    _showNotification = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedVersionsKey,
      _dismissedVersions.map((v) => v.toString()).toList(),
    );
    
    notifyListeners();
  }
  
  Future<void> remindLater() async {
    _showNotification = false;
    _remindLaterUntil = DateTime.now().add(const Duration(hours: 24));
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_remindLaterKey, _remindLaterUntil!.toIso8601String());
    
    notifyListeners();
  }
  
  void hideNotification() {
    _showNotification = false;
    notifyListeners();
  }
  
  Future<void> openUpdateLink() async {
    if (_availableUpdate != null) {
      await UpdateService.downloadUpdate(_availableUpdate!.downloadUrl);
      hideNotification();
    }
  }
  
  @override
  void dispose() {
    _versionSubscription?.cancel();
    super.dispose();
  }
}
