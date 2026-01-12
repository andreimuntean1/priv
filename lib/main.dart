import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'providers/auth_provider.dart';
import 'providers/messaging_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_status_provider.dart';
import 'providers/update_notification_provider.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';
import 'services/notification_service.dart';

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: "assets/.env");
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: kIsWeb 
      ? FirebaseOptions(
          apiKey: dotenv.env['FIREBASE_WEB_API_KEY'] ?? '',
          authDomain: dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'] ?? '',
          projectId: dotenv.env['FIREBASE_WEB_PROJECT_ID'] ?? '',
          storageBucket: dotenv.env['FIREBASE_WEB_STORAGE_BUCKET'] ?? '',
          messagingSenderId: dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID'] ?? '',
          appId: dotenv.env['FIREBASE_WEB_APP_ID'] ?? '',
        )
      : null,
  );
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const PrivateMessagingApp());
}

class PrivateMessagingApp extends StatefulWidget {
  const PrivateMessagingApp({super.key});

  @override
  State<PrivateMessagingApp> createState() => _PrivateMessagingAppState();
}

class _PrivateMessagingAppState extends State<PrivateMessagingApp> {
  late AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    
    // Handle links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    
    // Handle links when app is launched
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Failed to get initial app link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');
    print('Query parameters: ${uri.queryParameters}');
    print('Fragment: ${uri.fragment}');
    
    bool isMobileDeepLink = uri.scheme == 'privmessaging' && uri.host == 'auth' && uri.path == '/callback';
    bool isWebAuth = kIsWeb && (uri.queryParameters.containsKey('code') || uri.fragment.contains('access_token'));

    if (isMobileDeepLink || isWebAuth) {
      // Handle OAuth code flow
      final code = uri.queryParameters['code'];
      
      if (code != null) {
        print('Authorization code received: $code');
        // Exchange the code for a session using Supabase's auth flow
        Supabase.instance.client.auth.exchangeCodeForSession(code).then((response) {
          print('Session exchange successful: ${response.session?.user?.email}');
        }).catchError((error) {
          print('Error exchanging code for session: $error');
        });
        return;
      }
      
      // Handle direct token flow (fallback)
      String? accessToken;
      String? refreshToken;
      String? type;
      
      // Check query parameters first
      accessToken = uri.queryParameters['access_token'];
      refreshToken = uri.queryParameters['refresh_token'];
      type = uri.queryParameters['type'];
      
      // If not in query parameters, check fragment
      if (accessToken == null && uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        accessToken = fragmentParams['access_token'];
        refreshToken = fragmentParams['refresh_token'];
        type = fragmentParams['type'];
      }
      
      print('Extracted - Access token: ${accessToken != null ? 'present' : 'null'}');
      print('Extracted - Refresh token: ${refreshToken != null ? 'present' : 'null'}');
      print('Extracted - Type: $type');
      
      if (accessToken != null) {
        // Set the session in Supabase
        Supabase.instance.client.auth.setSession(accessToken).then((_) {
          print('Session set successfully');
        }).catchError((error) {
          print('Error setting session: $error');
        });
      } else {
        print('No access token or code found in deep link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ThemeProvider>(
          create: (_) => ThemeProvider()..loadThemeMode(),
          update: (_, authProvider, themeProvider) {
            // Reload theme when user authenticates
            if (authProvider.isAuthenticated && authProvider.currentUserEmail != null) {
              themeProvider!.loadThemeMode(userEmail: authProvider.currentUserEmail);
            }
            return themeProvider!;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => UserStatusProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => UpdateNotificationProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MessagingProvider>(
          create: (_) => MessagingProvider(),
          update: (_, authProvider, messagingProvider) =>
              messagingProvider!..updateUser(authProvider.currentUser),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Priv',
            theme: AppTheme.getTheme(themeProvider.themeType),
            themeMode: ThemeMode.dark,
            home: const MainApp(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Notifications if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        await NotificationService().initialize(userId);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final authProvider = context.read<AuthProvider>();
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground
        // Clear notifications as user is now "in chat"
        context.read<MessagingProvider>().clearNotifications();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background
        break;
    }
  }


  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}