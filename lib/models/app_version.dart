class AppVersion {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String? changelog;
  final DateTime updatedAt;

  const AppVersion({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    this.changelog,
    required this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      versionCode: json['version_code'] as int,
      versionName: json['version_name'] as String,
      downloadUrl: json['download_url'] as String,
      changelog: json['changelog'] as String?,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : (json['created_at'] != null 
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_code': versionCode,
      'version_name': versionName,
      'download_url': downloadUrl,
      'changelog': changelog,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'AppVersion(versionCode: $versionCode, versionName: $versionName)';
  }
}