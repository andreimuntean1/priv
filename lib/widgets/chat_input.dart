import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/file_attachment.dart';
import '../services/file_service.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import 'package:provider/provider.dart';

class ChatInput extends StatefulWidget {
  final Function(String content, List<FileAttachment>? attachments, String? replyToId) onSendMessage;

  const ChatInput({
    super.key,
    required this.onSendMessage,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<FileAttachment> _attachments = [];
  
  bool _isComposing = false;
  bool _showAttachmentMenu = false;
  bool _isUploading = false;

  late AnimationController _attachmentMenuController;
  late Animation<double> _attachmentMenuAnimation;

  @override
  void initState() {
    super.initState();
    
    _attachmentMenuController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _attachmentMenuAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _attachmentMenuController,
      curve: Curves.easeInOut,
    ));

    _textController.addListener(() {
      setState(() {
        _isComposing = _textController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _attachmentMenuController.dispose();
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

  Future<void> _pickImage(ImageSource source) async {
    _hideAttachmentMenu();
    
    try {
      setState(() {
        _isUploading = true;
      });

      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final attachment = await FileService.uploadFile(
          filePath: image.path,
          fileName: image.name,
        );
        
        setState(() {
          _attachments.add(attachment);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    _hideAttachmentMenu();
    
    try {
      setState(() {
        _isUploading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final attachment = await FileService.uploadFile(
          filePath: file.path!,
          fileName: file.name,
        );
        
        setState(() {
          _attachments.add(attachment);
        });
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
      null, // replyToId - would be set when replying
    );

    _textController.clear();
    setState(() {
      _attachments.clear();
      _isComposing = false;
    });
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
        color: themeColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // File attachments preview
          if (_attachments.isNotEmpty) _buildAttachmentPreview(),

          // Loading indicator for file upload
          if (_isUploading) _buildUploadingIndicator(),

          // Attachment menu
          if (_showAttachmentMenu) _buildAttachmentMenu(),

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

                  // Text input
                  Expanded(
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
                          hintText: 'Scrie un mesaj...',
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

                  const SizedBox(width: 8),

                  // Send button (removed voice input)
                  if (_isComposing || _attachments.isNotEmpty)
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
    );
  }

  Widget _buildAttachmentPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _attachments.map((attachment) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: attachment.isImage
                          ? Image.network(
                              attachment.fileUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image),
                            )
                          : Center(
                              child: Icon(
                                _getFileIcon(attachment),
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeAttachment(attachment),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUploadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Uploading file...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return AnimatedBuilder(
      animation: _attachmentMenuAnimation,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: _attachmentMenuAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_camera,
                  label: 'Camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                _buildAttachmentOption(
                  icon: Icons.attach_file,
                  label: 'File',
                  onTap: _pickFile,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(FileAttachment attachment) {
    if (attachment.isPdf) return Icons.picture_as_pdf;
    if (attachment.isDocument) return Icons.description;
    if (attachment.isAudio) return Icons.audiotrack;
    if (attachment.isVideo) return Icons.videocam;
    return Icons.attach_file;
  }
}