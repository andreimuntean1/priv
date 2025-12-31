import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/messaging_provider.dart';
import '../providers/auth_provider.dart';

class TypingIndicator extends StatelessWidget {
  final String chatId;
  const TypingIndicator({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MessagingProvider>(context);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final typingUserIds = provider.typingUserIds.where((id) => id != currentUserId).toList();
    if (typingUserIds.isEmpty) {
      return SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            typingUserIds.length == 1
              ? 'Someone is typing...'
              : 'Multiple people are typing...',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
