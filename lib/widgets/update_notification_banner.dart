import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/update_notification_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import 'package:flutter/foundation.dart';

class UpdateNotificationBanner extends StatefulWidget {
  const UpdateNotificationBanner({super.key});

  @override
  State<UpdateNotificationBanner> createState() => _UpdateNotificationBannerState();
}

class _UpdateNotificationBannerState extends State<UpdateNotificationBanner> {
  bool _isExpanded = false;
  
  Future<void> _dismiss() async {
    context.read<UpdateNotificationProvider>().dismissUpdate();
  }
  
  Future<void> _remindLater() async {
    context.read<UpdateNotificationProvider>().remindLater();
  }
  
  void _updateNow() {
    context.read<UpdateNotificationProvider>().openUpdateLink();
  }

  @override
  Widget build(BuildContext context) {
    final updateProvider = context.watch<UpdateNotificationProvider>();
    final themeType = context.watch<ThemeProvider>().themeType;
    final themeColors = AppThemeColors.getColors(themeType);
    
    if (!updateProvider.showNotification || updateProvider.availableUpdate == null) {
      return const SizedBox.shrink();
    }
    
    final update = updateProvider.availableUpdate!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: 4,
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: themeColors.primary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: SafeArea(
            bottom: false,
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.system_update,
                        color: themeColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kIsWeb ? 'Aplicația s-o actualizat' : 'Actualizare Disponibilă',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: themeColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Versiunea ${update.versionName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: themeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: themeColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: _dismiss,
                    ),
                  ],
                ),
                
                if (update.changelog != null && update.changelog!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          update.changelog!,
                          style: TextStyle(
                            fontSize: 13,
                            color: themeColors.textPrimary,
                          ),
                          maxLines: _isExpanded ? null : 3,
                          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                if (!kIsWeb)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _updateNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColors.primary,
                            foregroundColor: themeColors.accentText,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Actualizează amu ni'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _remindLater,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeColors.textSecondary,
                          side: BorderSide(color: themeColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Lasă-mă în pace'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

