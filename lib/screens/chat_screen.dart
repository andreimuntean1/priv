import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/messaging_provider.dart';
import '../widgets/animated_message_bubble.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/typing_indicator.dart';
import '../providers/user_status_provider.dart'; // Added import
import '../models/message.dart';
import '../models/user.dart';
import '../utils/theme.dart';
import 'settings_screen.dart';
import 'user_profile_screen.dart';
import '../providers/theme_provider.dart';
import '../widgets/update_notification_banner.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _screenFocusNode = FocusNode();
  final FocusNode _inputFocusNode = FocusNode();
  bool _showSearchBar = false;
  List<String> _usernames = [];
  Message? _replyToMessage;
  bool _userHasScrolledUp = false;
  bool _isAtBottom = true;
  double _previousKeyboardHeight = 0.0;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsernames();
    _setupScrollListener();
    // Subscribe to typing events
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().subscribeToTyping('main');
    });
    
    // Initial scroll to bottom with multiple attempts to ensure it works
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      
      // Additional delayed scroll to handle cases where messages load after UI
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToBottom();
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _scrollToBottom();
      });
    });
  }

  void _setupScrollListener() {
    bool isUpdating = false;
    
    _scrollController.addListener(() {
      if (_scrollController.hasClients && !isUpdating) {
        isUpdating = true;
        
        // Use post frame callback to avoid excessive setState calls
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final isAtBottom = _scrollController.position.pixels >= 
                _scrollController.position.maxScrollExtent - 100;
            
            if (_isAtBottom != isAtBottom || _userHasScrolledUp == isAtBottom) {
              setState(() {
                _isAtBottom = isAtBottom;
                _userHasScrolledUp = !isAtBottom;
              });
            }
          }
          isUpdating = false;
        });
      }
    });
  }



  Future<void> _loadUsernames() async {
    final authProvider = context.read<AuthProvider>();
    final users = await authProvider.getAllUsers();
    if (mounted) {
      setState(() {
        _usernames = users.map((user) => user.username).toList();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _screenFocusNode.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentPos = _scrollController.position.pixels;
      final distance = maxExtent - currentPos;
      
      // For large distances, jump immediately for better performance
      if (distance > 1000) {
        _scrollController.jumpTo(maxExtent);
      } else {
        // For shorter distances, use smooth animation
        _scrollController.animateTo(
          maxExtent,
          duration: Duration(milliseconds: (distance / 4).clamp(150, 300).round()),
          curve: Curves.easeOutCubic,
        );
      }
      
      setState(() {
        _userHasScrolledUp = false;
        _isAtBottom = true;
      });
    }
  }

  void _scrollToBottomIfNeeded() {
    if (!_userHasScrolledUp && _scrollController.hasClients) {
      _scrollToBottom();
    }
  }

  void _handleKeyboardChange(double keyboardHeight) {
    // Only auto-scroll if keyboard opens (height increases) and user hasn't scrolled up
    if (keyboardHeight > _previousKeyboardHeight && !_userHasScrolledUp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomIfNeeded();
      });
    }
    _previousKeyboardHeight = keyboardHeight;
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
    });
    
    if (!_showSearchBar) {
      context.read<MessagingProvider>().clearSearch();
      // Auto-scroll when exiting search
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottomIfNeeded();
      });
    }
  }



  void _handleReplyToMessage(Message message) {
    setState(() {
      _replyToMessage = message;
    });

    // Auto-scroll to bottom when replying
    _scrollToBottom();
    
    // Request focus on input
    _inputFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final currentYear = now.year;
    final messageYear = date.year;
    
    // Romanian day names
    const dayNames = [
      'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică'
    ];
    
    // Romanian month names
    const monthNames = [
      'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
      'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie'
    ];
    
    final dayName = dayNames[date.weekday - 1];
    final day = date.day;
    final monthName = monthNames[date.month - 1];
    
    if (messageYear == currentYear) {
      return '$dayName, $day $monthName';
    } else {
      return '$day $monthName $messageYear';
    }
  }

  bool _shouldShowDateHeader(Message message, Message? previousMessage) {
    if (previousMessage == null) return true;
    
    final messageDate = DateTime(
      message.createdAt.year,
      message.createdAt.month,
      message.createdAt.day,
    );
    
    final previousDate = DateTime(
      previousMessage.createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );
    
    return !messageDate.isAtSameMomentAs(previousDate);
  }

  Widget _buildDateHeader(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).otherMessage.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(date),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  int _buildItemCount(List<Message> messages) {
    int count = 0;
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previousMessage = i > 0 ? messages[i - 1] : null;
      
      if (_shouldShowDateHeader(message, previousMessage)) {
        count++; // Date header
      }
      count++; // Message
    }
    return count;
  }

  Widget _buildListItem(List<Message> messages, int index) {
    int currentItemIndex = 0;
    
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previousMessage = i > 0 ? messages[i - 1] : null;
      
      // Check if we need a date header
      if (_shouldShowDateHeader(message, previousMessage)) {
        if (currentItemIndex == index) {
          return _buildDateHeader(message.createdAt);
        }
        currentItemIndex++;
      }
      
      // Check if this is the message item
      if (currentItemIndex == index) {
        final nextMessage = i < messages.length - 1 ? messages[i + 1] : null;
        
        return AnimatedMessageBubble(
          message: message,
          previousMessage: previousMessage,
          nextMessage: nextMessage,
          searchQuery: _showSearchBar ? context.read<MessagingProvider>().searchQuery : null,
          animationIndex: i,
          onReply: (replyMessage) {
            _handleReplyToMessage(replyMessage);
          },
          onDelete: (messageToDelete) async {
            final success = await context.read<MessagingProvider>().deleteMessage(messageToDelete.id);
            if (success) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Victorie! Mesaj șters cu succes'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No năcaz că nu ți-am putut șterge mesaju'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      }
      currentItemIndex++;
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // Track keyboard height changes
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleKeyboardChange(keyboardHeight);
    });

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!kIsWeb) return KeyEventResult.ignored;
        
        if (event is KeyDownEvent) {
          final isControlPressed = HardwareKeyboard.instance.isControlPressed;
          final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
          
          // Ctrl/Cmd + F
          if ((isControlPressed || isMetaPressed) && 
              event.logicalKey == LogicalKeyboardKey.keyF) {
            if (!_showSearchBar) {
              _toggleSearch();
            }
            return KeyEventResult.handled;
          }
          
          // Esc to cancel reply
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_replyToMessage != null) {
              _clearReply();
              return KeyEventResult.handled;
            } else if (_showSearchBar) {
              _toggleSearch();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(73),
        child: Container(
          decoration: BoxDecoration(
            color: AppThemeColors.getColors(context.watch<ThemeProvider>().themeType).otherMessage,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        // Open Other User's Profile
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              final currentUser = context.read<AuthProvider>().currentUser;
                              final userStatusProvider = context.read<UserStatusProvider>();
                              final allUsers = userStatusProvider.users.values.where((u) => u.id != currentUser?.id).toList();
                              if (allUsers.isNotEmpty) {
                                return UserProfileScreen(user: allUsers.first);
                              }
                              return const SizedBox.shrink(); 
                            }
                          ),
                        );
                      },
                      child: Consumer<UserStatusProvider>(
                        builder: (context, userStatusProvider, child) {
                          final currentUser = context.read<AuthProvider>().currentUser;
                          final allUsers = userStatusProvider.users.values.where((u) => u.id != currentUser?.id).toList();
                          
                          if (allUsers.isEmpty) {
                             return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Chat privat',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Stai că ne gândim...',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              );
                          }
                          
                          final otherUser = allUsers.first; 

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                otherUser.username, 
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).background.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                          onPressed: _toggleSearch,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).background.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          // Settings Icon
                          icon: Icon(Icons.settings, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Update notification banner
              const UpdateNotificationBanner(),
              
              // Search Bar
              if (_showSearchBar)
            SearchBarWidget(
              onSearchChanged: (query) {
                context.read<MessagingProvider>().searchMessages(query);
              },
              onClearSearch: () {
                context.read<MessagingProvider>().clearSearch();
              },
            ),

          // Messages List
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, messagingProvider, child) {
                final messages = _showSearchBar && messagingProvider.isSearchActive
                    ? messagingProvider.searchResults
                    : messagingProvider.messages;

                // Auto-scroll to bottom when messages change (new messages arrive or first load)
                final currentMessageCount = messages.length;
                if (currentMessageCount != _previousMessageCount) {
                  _previousMessageCount = currentMessageCount;
                  
                  // For new messages or initial load, scroll to bottom
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (currentMessageCount > 0) {
                      _scrollToBottom(); // Force scroll for new messages and initial load
                    }
                  });
                }

                if (messagingProvider.isLoading && messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _buildItemCount(messages),
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 1000, // Cache more items for smoother scrolling
                  addAutomaticKeepAlives: true,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false, // Disable for performance
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _buildListItem(messages, index),
                    );
                  },
                );
              },
            ),
          ),

          // Typing Indicator
          TypingIndicator(chatId: 'main'),

          // Chat Input
          if (!_showSearchBar)
            EnhancedChatInput(
              focusNode: _inputFocusNode,
              replyToMessage: _replyToMessage,
              onClearReply: _clearReply,
              onFocus: () {
                // Auto-scroll when input gets focus (keyboard opens)
                if (!_userHasScrolledUp) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottomIfNeeded();
                  });
                }
              },
              onSendMessage: (content, attachments, replyToId) async {
                final success = await context.read<MessagingProvider>().sendMessage(
                  content: content,
                  attachments: attachments,
                  replyToId: replyToId,
                );

                if (success) {
                  // Clear reply after successful send
                  _clearReply();
                  
                  // Scroll to bottom after sending
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollToBottom();
                  });
                }
              },
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Încă cam nimica',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Scrie ceva, nu fii timid!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}