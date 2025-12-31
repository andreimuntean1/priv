import 'user.dart';
import 'file_attachment.dart';

enum MessageType { text, image, file, audio }

class Message {
  final String id;
  final String content;
  final String senderId;
  final User? sender;
  final String? replyToId;
  final Message? replyToMessage;
  final MessageType messageType;
  final List<FileAttachment> attachments;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;

  const Message({
    required this.id,
    required this.content,
    required this.senderId,
    this.sender,
    this.replyToId,
    this.replyToMessage,
    this.messageType = MessageType.text,
    this.attachments = const [],
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['sender_id'] as String,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      replyToId: json['reply_to_id'] as String?,
      messageType: _parseMessageType(json['message_type'] as String?),
      attachments: json['file_attachments'] != null
          ? (json['file_attachments'] as List)
              .map((a) => FileAttachment.fromJson(a))
              .toList()
          : [],
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sender_id': senderId,
      'reply_to_id': replyToId,
      'message_type': messageType.name,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      case 'audio':
        return MessageType.audio;
      default:
        return MessageType.text;
    }
  }

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    User? sender,
    String? replyToId,
    Message? replyToMessage,
    MessageType? messageType,
    List<FileAttachment>? attachments,
    bool? isEdited,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      replyToId: replyToId ?? this.replyToId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      messageType: messageType ?? this.messageType,
      attachments: attachments ?? this.attachments,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
    );
  }

  bool get hasAttachments => attachments.isNotEmpty;
  bool get isReply => replyToId != null;
  bool get isRead => readAt != null;
  
  String get displayContent {
    if (isDeleted) return 'This message was deleted';
    if (messageType == MessageType.image && hasAttachments) {
      return content.isEmpty ? '📷 Image' : content;
    }
    if (messageType == MessageType.file && hasAttachments) {
      return content.isEmpty ? '📎 File attachment' : content;
    }
    return content;
  }

  String get replyDisplayContent {
    if (isDeleted) return 'mesaj șters';
    if (hasAttachments && content.trim().isEmpty) {
      // Determine attachment type for display
      if (messageType == MessageType.image || 
          (attachments.isNotEmpty && attachments.first.isImage)) {
        return '📷 Imagine';
      } else if (messageType == MessageType.audio || 
          (attachments.isNotEmpty && attachments.first.isAudio)) {
        return '🎵 Audio';
      } else if (attachments.isNotEmpty && attachments.first.isVideo) {
        return '🎬 Video';
      } else if (attachments.isNotEmpty && attachments.first.isPdf) {
        return '📄 PDF';
      } else if (attachments.isNotEmpty && attachments.first.isDocument) {
        return '📝 Document';
      } else {
        return '📎 Fișier';
      }
    }
    return content.isNotEmpty ? content : 'mesaj';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Message(id: $id, content: $content, senderId: $senderId, type: $messageType)';
  }
}