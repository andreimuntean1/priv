import 'package:flutter/services.dart';

class ValidationUtils {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    return null;
  }

  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }
    
    if (username.length < 3) {
      return 'Username must be at least 3 characters long';
    }
    
    if (username.length > 30) {
      return 'Username cannot be longer than 30 characters';
    }
    
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!usernameRegex.hasMatch(username)) {
      return 'Username can only contain letters, numbers, underscores, and hyphens';
    }
    
    return null;
  }

  static String? validateMessage(String? message) {
    if (message == null || message.trim().isEmpty) {
      return null; // Empty messages are allowed when there are attachments
    }
    
    if (message.trim().length > 4000) {
      return 'Message cannot be longer than 4000 characters';
    }
    
    return null;
  }

  static bool isValidFileType(String fileName, List<String> allowedTypes) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedTypes.contains(extension);
  }

  static bool isValidFileSize(int fileSize, int maxSize) {
    return fileSize <= maxSize;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

class TextInputFormatters {
  static TextInputFormatter get usernameFormatter {
    return FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9_-]*$'));
  }

  static TextInputFormatter get messageFormatter {
    return LengthLimitingTextInputFormatter(4000);
  }

  static TextInputFormatter get emailFormatter {
    return FilteringTextInputFormatter.deny(RegExp(r'\s'));
  }
}