import 'package:flutter/material.dart';
import 'utils/app_icon_generator.dart';

void main() {
  runApp(const IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppIconGenerator();
  }
}