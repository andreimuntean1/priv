import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'package:provider/provider.dart';

import '../models/file_attachment.dart';
import '../models/message.dart';
import '../services/file_service.dart';
import '../providers/messaging_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';

class EnhancedChatInput extends StatefulWidget {
  final Function(String content, List<FileAttachment>? attachments, String? replyToId) onSendMessage;
  final Message? replyToMessage;
  final VoidCallback? onClearReply;
  final VoidCallback? onFocus;
  final FocusNode? focusNode;

  const EnhancedChatInput({
    super.key,
    required this.onSendMessage,
    this.replyToMessage,
    this.onClearReply,
    this.onFocus,
    this.focusNode,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  late FocusNode _focusNode;
  final FocusNode _keyboardFocusNode = FocusNode();
  final List<FileAttachment> _attachments = [];
  
  bool _isComposing = false;
  bool _showAttachmentMenu = false;
  bool _isUploading = false;

  // Size limitations
  static const int maxImageSizeMB = 10; // 10MB for images
  static const int maxVideoSizeMB = 100; // 100MB for videos
  static const int maxVideoLengthSeconds = 300; // 5 minutes
  static const int imageCompressionQuality = 85; // 85% quality
  static const int maxImageDimension = 1920; // Max width/height

  late AnimationController _attachmentMenuController;
  late AnimationController _replyBarController;
  late Animation<double> _attachmentMenuAnimation;
  late Animation<double> _replyBarAnimation;

  @override
  void initState() {
    super.initState();
    
    _focusNode = widget.focusNode ?? FocusNode();
    
    _attachmentMenuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _replyBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _attachmentMenuAnimation = CurvedAnimation(
      parent: _attachmentMenuController,
      curve: Curves.easeInOut,
    );
    
    _replyBarAnimation = CurvedAnimation(
      parent: _replyBarController,
      curve: Curves.easeOut,
    );
    
    _textController.addListener(() {
      setState(() {
        _isComposing = _textController.text.isNotEmpty;
      });
      // Typing indicator logic
      final provider = context.read<MessagingProvider>();
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        provider.sendTyping('main', userId, _textController.text.isNotEmpty);
      }
    });
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.onFocus != null) {
        widget.onFocus!();
      }
    });
  }

  @override
  void didUpdateWidget(EnhancedChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate reply bar when reply message changes
    if (widget.replyToMessage != null && oldWidget.replyToMessage == null) {
      _replyBarController.forward();
    } else if (widget.replyToMessage == null && oldWidget.replyToMessage != null) {
      _replyBarController.reverse();
    }
  }

  @override
  void dispose() {
    _attachmentMenuController.dispose();
    _replyBarController.dispose();
    _textController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _toggleAttachmentMenu() {
    setState(() {
      _showAttachmentMenu = !_showAttachmentMenu;
    });
    
    if (_showAttachmentMenu) {
      _attachmentMenuController.forward();
    } else {
      _attachmentMenuController.reverse();
    }
  }

  void _hideAttachmentMenu() {
    if (_showAttachmentMenu) {
      setState(() {
        _showAttachmentMenu = false;
      });
      _attachmentMenuController.reverse();
    }
  }

  Future<void> _processAndUploadImage(XFile imageFile) async {
    final file = File(imageFile.path);
    final fileSize = await file.length();
    
    // Check file size
    if (fileSize > maxImageSizeMB * 1024 * 1024) {
      _showErrorSnackBar('Image too large. Max size: ${maxImageSizeMB}MB');
      return;
    }

    // Compress image if needed
    Uint8List? compressedBytes;
    try {
      final originalBytes = await file.readAsBytes();
      final image = img.decodeImage(originalBytes);
      
      if (image != null) {
        // Resize if dimensions are too large
        img.Image resizedImage = image;
        if (image.width > maxImageDimension || image.height > maxImageDimension) {
          if (image.width > image.height) {
            resizedImage = img.copyResize(image, width: maxImageDimension);
          } else {
            resizedImage = img.copyResize(image, height: maxImageDimension);
          }
        }
        
        // Compress
        compressedBytes = img.encodeJpg(resizedImage, quality: imageCompressionQuality);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to process image: $e');
      return;
    }

    // Upload processed image
    try {
      final attachment = await FileService.uploadFromBytes(
        fileBytes: compressedBytes ?? await file.readAsBytes(),
        fileName: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: 'image/jpeg',
      );
      
      setState(() {
        _attachments.add(attachment);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
    }
  }

  Future<void> _processAndUploadVideo(XFile videoFile) async {
    final file = File(videoFile.path);
    final fileSize = await file.length();
    
    // Check file size before processing
    if (fileSize > maxVideoSizeMB * 1024 * 1024) {
      _showErrorSnackBar('Video too large. Max size: ${maxVideoSizeMB}MB');
      return;
    }

    try {
      // Show compression progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Compressing video...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      // Compress video
      final compressedVideo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (compressedVideo != null) {
        final compressedFile = File(compressedVideo.path!);
        final compressedSize = await compressedFile.length();
        
        // Check compressed size
        if (compressedSize > maxVideoSizeMB * 1024 * 1024) {
          _showErrorSnackBar('Video still too large after compression. Try a shorter video.');
          return;
        }

        // Upload compressed video
        final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final attachment = await FileService.uploadFile(
          filePath: compressedVideo.path!,
          fileName: fileName,
        );
        
        setState(() {
          _attachments.add(attachment);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorSnackBar('Failed to process video: $e');
    }
  }

  Future<void> _pickMediaFromCamera() async {
    _hideAttachmentMenu();
    
    // Show media type selection for camera
    final mediaType = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Produ o poză'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Produ un video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    try {
      setState(() {
        _isUploading = true;
      });
      
      final picker = ImagePicker();
      XFile? pickedFile;

      if (mediaType == 'image') {
        pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          await _processAndUploadImage(pickedFile);
        }
      } else {
        pickedFile = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: maxVideoLengthSeconds),
        );
        if (pickedFile != null) {
          await _processAndUploadVideo(pickedFile);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to capture media: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickMediaFromGallery() async {
    _hideAttachmentMenu();
    
    // Show media type selection for gallery
    final mediaType = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Alege o poză'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Alege un video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    try {
      setState(() {
        _isUploading = true;
      });
      
      final picker = ImagePicker();
      XFile? pickedFile;

      if (mediaType == 'image') {
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          await _processAndUploadImage(pickedFile);
        }
      } else {
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          await _processAndUploadVideo(pickedFile);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick media: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    _hideAttachmentMenu();
    
    try {
      setState(() {
        _isUploading = true;
      });
      
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
        type: FileType.custom,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path == null) continue;
          
          final attachment = await FileService.uploadFile(
            filePath: file.path!,
            fileName: file.name,
          );
          
          setState(() {
            _attachments.add(attachment);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload file: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _removeAttachment(FileAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }

  Future<void> _sendMessage() async {
    final content = _textController.text.trim();
    
    if (content.isEmpty && _attachments.isEmpty) return;

    widget.onSendMessage(
      content,
      _attachments.isNotEmpty ? List.from(_attachments) : null,
      widget.replyToMessage?.id,
    );

    _textController.clear();
    setState(() {
      _attachments.clear();
      _isComposing = false;
    });
    
    // Clear reply after sending
    if (widget.onClearReply != null) {
      widget.onClearReply!();
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

  @override
  Widget build(BuildContext context) {
    final themeType = context.watch<ThemeProvider>().themeType;
    final themeColors = AppThemeColors.getColors(themeType);

    return Container(
      decoration: BoxDecoration(
        color: themeColors.background, // Background color visible behind rounded corners
      ),
      child: Container(
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Reply bar
            if (widget.replyToMessage != null)
              SizeTransition(
                sizeFactor: _replyBarAnimation,
                child: _buildReplyBar(themeColors),
              ),

          // File attachments preview
          if (_attachments.isNotEmpty) _buildAttachmentPreview(),

          // Loading indicator for file upload
          if (_isUploading) _buildUploadingIndicator(),

          // Attachment menu
          if (_showAttachmentMenu) _buildAttachmentMenu(themeColors),

          // Input row
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Attachment button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: themeColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: AnimatedRotation(
                        turns: _showAttachmentMenu ? 0.125 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.add,
                          color: themeColors.accentText,
                          size: 20,
                        ),
                      ),
                      onPressed: _isUploading ? null : _toggleAttachmentMenu,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Focus(
                      focusNode: _keyboardFocusNode, 
                      onKeyEvent: (node, event) {
                        if (kIsWeb && 
                            event is KeyDownEvent && 
                            event.logicalKey == LogicalKeyboardKey.enter && 
                            !HardwareKeyboard.instance.isShiftPressed) {
                          _sendMessage();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF616161),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: widget.replyToMessage != null 
                                ? 'Răspunde...' 
                                : 'Scrie un mesaj...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onTap: _hideAttachmentMenu,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  if (_isComposing || _attachments.isNotEmpty || widget.replyToMessage != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: themeColors.accentText,
                          size: 20,
                        ),
                        onPressed: _isUploading ? null : _sendMessage,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildReplyBar(AppThemeColors themeColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF616161).withOpacity(0.3),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFF616161),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: themeColors.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(1.5),
                bottomRight: Radius.circular(1.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Răspunzi la ${widget.replyToMessage?.sender?.username ?? "cineva"}',
                  style: TextStyle(
                    color: themeColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.replyToMessage?.replyDisplayContent ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 20,
            ),
            onPressed: widget.onClearReply,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentThumbnail(FileAttachment attachment) {
    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.fileUrl,
          fit: BoxFit.cover,
        ),
      );
    } else if (attachment.isVideo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              color: Colors.grey[800],
              child: const Icon(
                Icons.video_library,
                color: Colors.white,
                size: 40,
              ),
            ),
            const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 30,
            ),
          ],
        ),
      );
    } else {
      return const Icon(Icons.insert_drive_file, color: Colors.white);
    }
  }

  Widget _buildAttachmentPreview() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = _attachments[index];
          return Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildAttachmentThumbnail(attachment),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeAttachment(attachment),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Se încarcă fișierul...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu(AppThemeColors themeColors) {
    return SizeTransition(
      sizeFactor: _attachmentMenuAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildAttachmentOption(
              icon: Icons.camera_alt,
              label: 'Media',
              onTap: _pickMediaFromCamera,
              themeColors: themeColors,
            ),
            const SizedBox(width: 16),
            _buildAttachmentOption(
              icon: Icons.photo_library,
              label: 'Galerie',
              onTap: _pickMediaFromGallery,
              themeColors: themeColors,
            ),
            const SizedBox(width: 16),
            _buildAttachmentOption(
              icon: Icons.attach_file,
              label: 'Fișier',
              onTap: _pickFiles,
              themeColors: themeColors,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppThemeColors themeColors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFF616161),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: themeColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}