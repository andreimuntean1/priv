import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';

import '../utils/theme.dart';
import '../providers/theme_provider.dart';
import '../screens/user_profile_screen.dart';
import 'file_attachment_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final Message? previousMessage;
  final Message? nextMessage;
  final String? searchQuery;
  final Function(Message)? onReply;

  const MessageBubble({
    super.key,
    required this.message,
    this.previousMessage,
    this.nextMessage,
    this.searchQuery,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isMyMessage = message.senderId == currentUserId;
    final themeType = context.watch<ThemeProvider>().themeType;
    final themeColors = AppThemeColors.getColors(themeType);
    
    final showAvatar = _shouldShowAvatar();
    final showTimestamp = _shouldShowTimestamp();

    return Container(
      margin: EdgeInsets.only(
        top: _getTopMargin(),
        bottom: showTimestamp ? 8 : 4,
        left: isMyMessage ? 48 : 16,
        right: isMyMessage ? 16 : 48,
      ),
      child: Column(
        crossAxisAlignment: isMyMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Message bubble
          Row(
            mainAxisAlignment: isMyMessage
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar (for other user's messages)
              if (!isMyMessage && showAvatar) _buildAvatar(context),
              if (!isMyMessage && !showAvatar) const SizedBox(width: 40),
              
              // Message content
              GestureDetector(
                onLongPress: () => _showMessageOptions(context),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMyMessage
                        ? themeColors.myMessage
                        : themeColors.otherMessage,
                    borderRadius: _getBorderRadius(isMyMessage, showAvatar),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply indicator
                      if (message.isReply) _buildReplyIndicator(context),
                      
                      // File attachments
                      if (message.hasAttachments) ...[
                        ...message.attachments.map(
                          (attachment) => FileAttachmentWidget(
                            attachment: attachment,
                            isMyMessage: isMyMessage,
                          ),
                        ),
                        if (message.content.isNotEmpty) const SizedBox(height: 8),
                      ],
                      
                      // Text content
                      if (message.content.isNotEmpty)
                        _buildMessageText(context, isMyMessage),
                    ],
                  ),
                ),
              ),


            ],
          ),

          // Timestamp
          if (showTimestamp) _buildTimestamp(context, isMyMessage),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToUserProfile(context),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: message.sender?.avatarUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  message.sender!.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultAvatar(context),
                ),
              )
            : _buildDefaultAvatar(context),
      ),
    );
  }

  void _navigateToUserProfile(BuildContext context) {
    if (message.sender != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            user: message.sender!,
          ),
        ),
      );
    }
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    final username = message.sender?.username ?? 'U';
    return Center(
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : 'U',
        style: TextStyle(
          color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).accentText,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }



  Widget _buildReplyIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Răspuns la: ${message.replyToMessage?.content ?? "un mesaj"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageText(BuildContext context, bool isMyMessage) {
    final themeColors = AppThemeColors.getColors(context.watch<ThemeProvider>().themeType);
    final textColor = isMyMessage
        ? themeColors.accentText
        : themeColors.textPrimary;

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      return _buildHighlightedText(context, textColor);
    }

    return Text(
      message.displayContent,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.3,
      ),
    );
  }

  Widget _buildHighlightedText(BuildContext context, Color textColor) {
    final text = message.displayContent.toLowerCase();
    final query = searchQuery!.toLowerCase();
    final spans = <TextSpan>[];
    
    int start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: message.displayContent.substring(start),
          style: TextStyle(color: textColor),
        ));
        break;
      }
      
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: message.displayContent.substring(start, index),
          style: TextStyle(color: textColor),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: message.displayContent.substring(index, index + query.length),
        style: TextStyle(
          color: textColor,
          backgroundColor: Colors.yellow.withOpacity(0.3),
          fontWeight: FontWeight.w600,
        ),
      ));
      
      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, bool isMyMessage) {
    final time = DateFormat('HH:mm').format(message.createdAt);
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        left: isMyMessage ? 0 : 48,
        right: isMyMessage ? 0 : 0,
      ),
      child: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 11,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  BorderRadius _getBorderRadius(bool isMyMessage, bool showAvatar) {
    const radius = Radius.circular(20);
    const smallRadius = Radius.circular(6);

    if (isMyMessage) {
      return BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: showAvatar ? smallRadius : radius,
      );
    } else {
      return BorderRadius.only(
        topLeft: radius,
        topRight: radius,
        bottomLeft: showAvatar ? smallRadius : radius,
        bottomRight: radius,
      );
    }
  }

  bool _shouldShowAvatar() {
    if (nextMessage == null) return true;
    if (nextMessage!.senderId != message.senderId) return true;
    
    final timeDiff = nextMessage!.createdAt.difference(message.createdAt);
    return timeDiff.inMinutes > 2;
  }

  bool _shouldShowTimestamp() {
    if (nextMessage == null) return true;
    if (nextMessage!.senderId != message.senderId) return true;
    
    final timeDiff = nextMessage!.createdAt.difference(message.createdAt);
    return timeDiff.inMinutes > 5;
  }

  double _getTopMargin() {
    if (previousMessage == null) return 8;
    if (previousMessage!.senderId != message.senderId) return 16;
    
    final timeDiff = message.createdAt.difference(previousMessage!.createdAt);
    if (timeDiff.inMinutes > 2) return 16;
    
    return 4;
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Răspunde'),
              onTap: () {
                Navigator.pop(context);
                onReply?.call(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiază'),
              onTap: () {
                Navigator.pop(context);
                // Implement copy to clipboard
              },
            ),
            if (message.senderId == context.read<AuthProvider>().currentUser?.id)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Șterge', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // Implement delete message
                },
              ),
          ],
        );
      },
    );
  }
}