import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version.dart';

class UpdateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current app version info
  static Future<PackageInfo> getCurrentAppInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// Fetch latest version from Supabase
  static Future<AppVersion?> getLatestVersion() async {
    try {
      final response = await _supabase.rpc('get_latest_app_version');
      
      if (response == null || response.isEmpty) {
        return null;
      }

      return AppVersion.fromJson(response.first);
    } catch (e) {
      print('Error fetching latest version: $e');
      return null;
    }
  }

  /// Check if update is available
  static Future<bool> isUpdateAvailable() async {
    try {
      final currentInfo = await getCurrentAppInfo();
      final latestVersion = await getLatestVersion();

      if (latestVersion == null) return false;

      final currentVersionCode = int.tryParse(currentInfo.buildNumber) ?? 0;
      return latestVersion.versionCode > currentVersionCode;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  /// Get update info if available
  static Future<UpdateInfo?> getUpdateInfo() async {
    try {
      final currentInfo = await getCurrentAppInfo();
      final latestVersion = await getLatestVersion();

      if (latestVersion == null) return null;

      final currentVersionCode = int.tryParse(currentInfo.buildNumber) ?? 0;
      
      if (latestVersion.versionCode > currentVersionCode) {
        return UpdateInfo(
          currentVersion: currentInfo.version,
          currentVersionCode: currentVersionCode,
          latestVersion: latestVersion,
        );
      }

      return null;
    } catch (e) {
      print('Error getting update info: $e');
      return null;
    }
  }

  /// Download and install update
  static Future<bool> downloadUpdate(String downloadUrl) async {
    try {
      final uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      print('Error downloading update: $e');
      return false;
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final int currentVersionCode;
  final AppVersion latestVersion;

  const UpdateInfo({
    required this.currentVersion,
    required this.currentVersionCode,
    required this.latestVersion,
  });

  bool get hasUpdate => latestVersion.versionCode > currentVersionCode;
}