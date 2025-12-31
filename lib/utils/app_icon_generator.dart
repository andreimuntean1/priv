import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'theme.dart';

class AppIconGenerator extends StatelessWidget {
  const AppIconGenerator({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.getColors(context.watch<ThemeProvider>().themeType);

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon preview
              RepaintBoundary(
                key: const ValueKey('app_icon'),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: themeColors.primary,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    size: 100,
                    color: themeColors.accentText,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _generateIcon(context),
                child: const Text('Generate Icon PNG'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateIcon(BuildContext context) async {
    try {
      // Find the RepaintBoundary
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Convert to image
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Icon generated! Check console for bytes.')),
        );
      }

      // Print bytes length for debugging
      print('Generated PNG with ${pngBytes.length} bytes');
      
    } catch (e) {
      print('Error generating icon: $e');
    }
  }
}

// App icon widget that matches your design
class AppIcon extends StatelessWidget {
  final double size;
  
  const AppIcon({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    final themeColors = AppThemeColors.getColors(context.watch<ThemeProvider>().themeType);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: themeColors.primary,
        borderRadius: BorderRadius.circular(size * 0.2), // 20% border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: size * 0.05,
            offset: Offset(0, size * 0.02),
          ),
        ],
      ),
      child: Icon(
        Icons.chat_bubble_rounded,
        size: size * 0.5, // 50% of container size
        color: themeColors.accentText,
      ),
    );
  }
}