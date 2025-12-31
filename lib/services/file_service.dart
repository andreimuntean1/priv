import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/file_attachment.dart';
import 'supabase_service.dart';

class FileService {
  static const Uuid _uuid = Uuid();

  static Future<FileAttachment> uploadFile({
    required String filePath,
    required String fileName,
  }) async {
    try {
      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final fileStats = await file.stat();
      
      // Determine file type
      final fileExtension = fileName.split('.').last.toLowerCase();
      final contentType = _getContentType(fileExtension);
      
      // Upload to Supabase Storage
      final fileUrl = await SupabaseService.uploadFile(
        bucketName: SupabaseService.messageAttachmentsBucket,
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      // Create file attachment record
      final attachmentData = await SupabaseService.createFileAttachment(
        fileName: fileName,
        fileUrl: fileUrl,
        fileType: contentType,
        fileSize: fileStats.size,
      );

      return FileAttachment.fromJson(attachmentData);
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  static Future<FileAttachment> uploadFromBytes({
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      final fileExtension = fileName.split('.').last.toLowerCase();
      final detectedContentType = contentType ?? _getContentType(fileExtension);
      
      // Upload to Supabase Storage
      final fileUrl = await SupabaseService.uploadFile(
        bucketName: SupabaseService.messageAttachmentsBucket,
        fileName: fileName,
        fileBytes: fileBytes,
        contentType: detectedContentType,
      );

      // Create file attachment record
      final attachmentData = await SupabaseService.createFileAttachment(
        fileName: fileName,
        fileUrl: fileUrl,
        fileType: detectedContentType,
        fileSize: fileBytes.length,
      );

      return FileAttachment.fromJson(attachmentData);
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  static String _getContentType(String fileExtension) {
    switch (fileExtension.toLowerCase()) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      
      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'rtf':
        return 'application/rtf';
      
      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      
      // Video
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      
      // Archives
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      
      // Spreadsheets
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      
      // Presentations
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> downloadFile({
    required String fileUrl,
    required String fileName,
    String? savePath,
  }) async {
    try {
      // In a real implementation, you would use a package like dio
      // to download the file and save it to the device storage
      // This is a placeholder implementation
      throw UnimplementedError('File download not yet implemented');
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  static String generateUniqueFileName(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueId = _uuid.v4().substring(0, 8);
    final extension = originalFileName.split('.').last;
    final nameWithoutExtension = originalFileName.substring(
      0, 
      originalFileName.lastIndexOf('.'),
    );
    
    return '${nameWithoutExtension}_${timestamp}_$uniqueId.$extension';
  }

  static bool isImageFile(String fileName) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'];
    final extension = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(extension);
  }

  static bool isVideoFile(String fileName) {
    final videoExtensions = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'];
    final extension = fileName.split('.').last.toLowerCase();
    return videoExtensions.contains(extension);
  }

  static bool isAudioFile(String fileName) {
    final audioExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a'];
    final extension = fileName.split('.').last.toLowerCase();
    return audioExtensions.contains(extension);
  }

  static String getFileTypeDisplayName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      case 'txt':
        return 'Text File';
      case 'zip':
      case 'rar':
      case '7z':
        return 'Archive';
      default:
        if (isImageFile(fileName)) return 'Image';
        if (isVideoFile(fileName)) return 'Video';
        if (isAudioFile(fileName)) return 'Audio';
        return 'File';
    }
  }
}