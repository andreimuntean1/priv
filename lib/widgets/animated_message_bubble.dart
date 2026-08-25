import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/messaging_provider.dart';
import '../providers/user_status_provider.dart';
import '../utils/theme.dart';
import '../providers/theme_provider.dart';

import 'file_attachment_widget.dart';

class AnimatedMessageBubble extends StatefulWidget {
  final Message message;
  final Message? previousMessage;
  final Message? nextMessage;
  final String? searchQuery;
  final Function(Message)? onReply;
  final Function(Message)? onDelete;
  final int animationIndex;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    this.previousMessage,
    this.nextMessage,
    this.searchQuery,
    this.onReply,
    this.onDelete,
    this.animationIndex = 0,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late AnimationController _swipeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  
  double _swipeOffset = 0.0;
  bool _isDragging = false;
  double _startPosition = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Fade-in animation
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Swipe animation controller
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.fastOutSlowIn, // More performant curve
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Reduced from 0.5 for smoother animation
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.fastOutSlowIn, // More performant curve
    ));
    

    
    // Start fade-in animation with reduced staggered delay for better performance
    final delay = (widget.animationIndex * 25).clamp(0, 200); // Reduced from 50ms to 25ms, max 200ms
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) {
        _fadeInController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  void _handleSwipeStart(DragStartDetails details) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isMyMessage = widget.message.senderId == currentUserId;
    
    // Don't start swipe if tapping on avatar area (for other user's messages)
    if (!isMyMessage && _shouldShowAvatar()) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final localPosition = renderBox.globalToLocal(details.globalPosition);
        // Avatar area is approximately 40px wide on the left side
        if (localPosition.dx < 50) {
          return; // Don't start swiping if in avatar area
        }
      }
    }
    
    setState(() {
      _isDragging = true;
      _startPosition = details.globalPosition.dx;
      _swipeOffset = 0.0;
    });
  }

  void _handleSwipeUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isMyMessage = widget.message.senderId == currentUserId;
    
    // Calculate total distance from start position
    final totalDistance = details.globalPosition.dx - _startPosition;
    
    setState(() {
      // For sent messages (right side), swipe left to reply
      // For received messages (left side), swipe right to reply
      if (isMyMessage) {
        // Swipe left (negative distance) for sent messages
        _swipeOffset = totalDistance < 0 ? totalDistance.abs() : 0;
      } else {
        // Swipe right (positive distance) for received messages  
        _swipeOffset = totalDistance > 0 ? totalDistance : 0;
      }
      
      // Limit the swipe distance to 50px max
      _swipeOffset = _swipeOffset.clamp(0.0, 50.0);
    });
  }

  void _handleSwipeEnd(DragEndDetails details) {
    if (!_isDragging) return;
    
    setState(() {
      _isDragging = false;
    });
    
    // Check if swiped enough distance OR has enough velocity
    final hasEnoughDistance = _swipeOffset >= 30.0;
    final hasEnoughVelocity = details.velocity.pixelsPerSecond.dx.abs() > 300;
    final minSwipeForVelocity = _swipeOffset >= 15.0; // Minimum swipe for velocity trigger
    
    if (hasEnoughDistance || (hasEnoughVelocity && minSwipeForVelocity)) {
      _triggerReply();
    }
    
    // Animate back to original position
    _swipeController.forward().then((_) {
      setState(() {
        _swipeOffset = 0.0;
      });
      _swipeController.reset();
    });
  }

  void _triggerReply() {
    if (widget.onReply != null) {
      widget.onReply!(widget.message);
      
      // Show haptic feedback
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isMyMessage = widget.message.senderId == currentUserId;
    final themeType = context.watch<ThemeProvider>().themeType;
    final themeColors = AppThemeColors.getColors(themeType);
    
    final showAvatar = _shouldShowAvatar();
    final showTimestamp = _shouldShowTimestamp();

    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onPanStart: _handleSwipeStart,
              onPanUpdate: _handleSwipeUpdate,
              onPanEnd: _handleSwipeEnd,
              child: Stack(
                children: [

                  
                  // Message content with swipe transform
                  Transform.translate(
                    offset: Offset(
                      isMyMessage ? -_swipeOffset : _swipeOffset,
                      0,
                    ),
                    child: Container(
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
                              Listener(
                                onPointerDown: (event) {
                                  if (kIsWeb) {
                                    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
                                    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
                                    if (isControlPressed || isMetaPressed) {
                                      _triggerReply();
                                    }
                                  }
                                },
                                child: GestureDetector(
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
                                      boxShadow: _isDragging && _swipeOffset > 10.0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Reply indicator
                                        if (widget.message.isReply) _buildReplyIndicator(context),
                                        
                                        // File attachments
                                        if (widget.message.hasAttachments) ...[
                                          ...widget.message.attachments.map(
                                            (attachment) => FileAttachmentWidget(
                                              attachment: attachment,
                                              isMyMessage: isMyMessage,
                                            ),
                                          ),
                                          if (widget.message.content.isNotEmpty) const SizedBox(height: 8),
                                        ],
                                        
                                        // Text content
                                        if (widget.message.content.isNotEmpty)
                                          _buildMessageText(context, isMyMessage),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Timestamp
                          if (showTimestamp) _buildTimestamp(context, isMyMessage),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Consumer<UserStatusProvider>(
      builder: (context, userStatusProvider, child) {
        
        return Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          child: widget.message.sender?.avatarUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.message.sender!.avatarUrl!,
                    fit: BoxFit.cover,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(context),
                  ),
                )
              : _buildDefaultAvatar(context),
        );
      },
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    final username = widget.message.sender?.username ?? 'U';
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
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final isMyMessage = widget.message.senderId == currentUserId;
    
    final themeColors = AppThemeColors.getColors(context.watch<ThemeProvider>().themeType);
    final baseTextColor = isMyMessage
        ? themeColors.accentText
        : themeColors.textPrimary;
    final lightTextColor = baseTextColor.withOpacity(0.7);
    
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: lightTextColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Răspuns la: ${widget.message.replyToMessage?.replyDisplayContent ?? "un mesaj"}',
              style: TextStyle(
                color: lightTextColor,
                fontSize: 12,
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

    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      return _buildHighlightedText(context, textColor);
    }

    return _buildTextWithLinks(context, textColor);
  }

  Widget _buildTextWithLinks(BuildContext context, Color textColor) {
    final text = widget.message.displayContent;
    // Enhanced regex to detect https://, http://, www., and domain.tld patterns
    final linkRegex = RegExp(
      r'(?:https?://)?(?:www\.)?[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?(?:\.[a-zA-Z]{2,})+(?:/[^\s]*)?',
      caseSensitive: false,
    );

    final matches = linkRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: textColor,
          height: 1.3,
        ),
      );
    }

    final spans = <TextSpan>[];
    int start = 0;

    for (final match in matches) {
      // Add text before link
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      // Add clickable link with same color as text but underlined
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: textColor,
          decoration: TextDecoration.underline,
          decorationColor: textColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _launchUrl(url),
      ));

      start = match.end;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: textColor),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.3),
      ),
    );
  }

  void _launchUrl(String url) async {
    try {
      // Clean and validate URL
      String urlToLaunch = url.trim();
      if (!urlToLaunch.startsWith('http://') && !urlToLaunch.startsWith('https://')) {
        urlToLaunch = 'https://$urlToLaunch';
      }
      
      final uri = Uri.parse(urlToLaunch);
      
      // Validate URI has proper scheme and host
      if (uri.scheme.isEmpty || uri.host.isEmpty) {
        throw Exception('Invalid URL format');
      }
      
      // Try different launch modes in order of preference
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e1) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e2) {
          try {
            await launchUrl(uri, mode: LaunchMode.inAppWebView);
          } catch (e3) {
            // Last resort - try with webOnlyWindowName
            await launchUrl(uri);
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Nu se poate deschide link-ul: $url');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }



  Widget _buildHighlightedText(BuildContext context, Color textColor) {
    final text = widget.message.displayContent.toLowerCase();
    final query = widget.searchQuery!.toLowerCase();
    final spans = <TextSpan>[];
    
    int start = 0;
    while (true) {
      final index = text.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: widget.message.displayContent.substring(start),
          style: TextStyle(color: textColor),
        ));
        break;
      }
      
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: widget.message.displayContent.substring(start, index),
          style: TextStyle(color: textColor),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: widget.message.displayContent.substring(index, index + query.length),
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
    final time = DateFormat('HH:mm').format(widget.message.createdAt);
    
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        left: isMyMessage ? 0 : 48,
        right: isMyMessage ? 0 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 4),
            if (widget.message.isSending)
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).textTheme.bodySmall?.color ?? Colors.white54,
                  ),
                ),
              )
            else if (widget.message.isSendFailed)
              GestureDetector(
                onTap: () {
                  context.read<MessagingProvider>().retryMessage(widget.message.id);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 13,
                      color: Colors.redAccent,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Reîncearcă',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                Icons.done,
                size: 13,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.white54,
              ),
          ],
        ],
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
    if (widget.nextMessage == null) return true;
    if (widget.nextMessage!.senderId != widget.message.senderId) return true;
    
    final timeDiff = widget.nextMessage!.createdAt.difference(widget.message.createdAt);
    return timeDiff.inMinutes > 2;
  }

  bool _shouldShowTimestamp() {
    if (widget.message.isSending || widget.message.isSendFailed) return true;
    if (widget.nextMessage == null) return true;
    if (widget.nextMessage!.senderId != widget.message.senderId) return true;
    
    final timeDiff = widget.nextMessage!.createdAt.difference(widget.message.createdAt);
    return timeDiff.inMinutes > 5;
  }

  double _getTopMargin() {
    if (widget.previousMessage == null) return 8;
    if (widget.previousMessage!.senderId != widget.message.senderId) return 16;
    
    final timeDiff = widget.message.createdAt.difference(widget.previousMessage!.createdAt);
    if (timeDiff.inMinutes > 2) return 16;
    
    return 4;
  }

  void _copyMessageToClipboard(BuildContext context) {
    final textToCopy = widget.message.content;
    if (textToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textToCopy));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesaj copiat în clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDeleteMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ciao ciao mesaj'),
          content: const Text('Ești sigur că vrei să ștergi acest mesaj? Acesta va fi șters pentru toți utilizatorii.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anulează'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDelete?.call(widget.message);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Șterge'),
            ),
          ],
        );
      },
    );
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
                widget.onReply?.call(widget.message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiază'),
              onTap: () {
                Navigator.pop(context);
                _copyMessageToClipboard(context);
              },
            ),
            if (widget.message.senderId == context.read<AuthProvider>().currentUser?.id)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Șterge', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(context);
                },
              ),
          ],
        );
      },
    );
  }
}