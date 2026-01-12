import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // Load environment variables manually
  final envVars = <String, String>{};
  
  void loadEnvFile(String path) {
    print('Reading $path');
    final file = File(path);
    if (!file.existsSync()) return;
    
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        envVars[key] = value;
      }
    }
  }

  print('Loading .env file...');
  if (File('.env').existsSync()) {
    loadEnvFile('.env');
  } else if (File('assets/.env').existsSync()) {
    print('Note: .env not found in root, loading from assets/.env...');
    loadEnvFile('assets/.env');
  } else {
    print('Error: Could not find .env file in root or assets/.env');
    return;
  }

  final supabaseUrl = envVars['SUPABASE_URL'] ?? '';
  final supabaseKey = envVars['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    print('Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env');
    return;
  }
  
  print('Supabase URL: ${supabaseUrl.substring(0, 10)}...');

  final users = [
    {
      'email': 'priv.test1@andreimuntean.dev',
      'password': 'password123',
      'data': {'is_dev': true, 'username': 'Priv Test 1'}
    },
    {
      'email': 'priv.test2@andreimuntean.dev',
      'password': 'password123',
      'data': {'is_dev': true, 'username': 'Priv Test 2'}
    }
  ];

  final client = http.Client();

  for (final user in users) {
    try {
      print('Creating user: ${user['email']}...');
      
      final url = Uri.parse('$supabaseUrl/auth/v1/signup');
      final response = await client.post(
        url,
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': user['email'],
          'password': user['password'],
          'data': user['data'],
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        print('User created successfully. ID: ${responseData['id'] ?? responseData['user']?['id']}');
      } else {
        print('Failed to create user. Status: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Unexpected Error creating user ${user['email']}: $e');
    }
  }
  client.close();
}

