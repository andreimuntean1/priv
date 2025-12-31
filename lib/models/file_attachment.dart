class FileAttachment {
  final String id;
  final String? messageId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;

  const FileAttachment({
    required this.id,
    this.messageId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
  });

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'] as String,
      messageId: json['message_id'] as String?,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      fileType: json['file_type'] as String,
      fileSize: json['file_size'] as int,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'file_name': fileName,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
  }

  FileAttachment copyWith({
    String? id,
    String? messageId,
    String? fileName,
    String? fileUrl,
    String? fileType,
    int? fileSize,
    DateTime? uploadedAt,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  // File type helpers
  bool get isImage {
    final imageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
    return imageTypes.any((type) => 
        fileType.toLowerCase().contains(type) || 
        fileName.toLowerCase().endsWith('.$type'));
  }

  bool get isPdf => fileType.toLowerCase().contains('pdf') || 
                   fileName.toLowerCase().endsWith('.pdf');

  bool get isDocument {
    final docTypes = ['doc', 'docx', 'txt', 'rtf', 'odt'];
    return docTypes.any((type) => 
        fileType.toLowerCase().contains(type) || 
        fileName.toLowerCase().endsWith('.$type'));
  }

  bool get isAudio {
    final audioTypes = ['mp3', 'wav', 'ogg', 'aac', 'm4a'];
    return audioTypes.any((type) => 
        fileType.toLowerCase().contains('audio') ||
        fileName.toLowerCase().endsWith('.$type'));
  }

  bool get isVideo {
    final videoTypes = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'];
    return videoTypes.any((type) => 
        fileType.toLowerCase().contains('video') ||
        fileName.toLowerCase().endsWith('.$type'));
  }

  String get displaySize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileAttachment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FileAttachment(id: $id, fileName: $fileName, fileType: $fileType, size: $displaySize)';
  }
}