class TypingEvent {
  final String chatId;
  final String userId;
  final bool isTyping;
  final DateTime timestamp;

  TypingEvent({
    required this.chatId,
    required this.userId,
    required this.isTyping,
    required this.timestamp,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      chatId: json['chat_id'] as String,
      userId: json['user_id'] as String,
      isTyping: json['is_typing'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'chat_id': chatId,
    'user_id': userId,
    'is_typing': isTyping,
    'timestamp': timestamp.toIso8601String(),
  };
}
