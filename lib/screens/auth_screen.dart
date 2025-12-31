import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import 'chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _magicLinkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleAuthSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _sendMagicLink() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = context.read<AuthProvider>();
      
      final success = await authProvider.sendMagicLink(
        email: _emailController.text.trim(),
      );

      if (success && mounted) {
        setState(() {
          _magicLinkSent = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // Auto-navigate when authenticated
            if (authProvider.isAuthenticated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handleAuthSuccess();
              });
            }
            
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/icons/android/play_store_512.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            Text(
                              'Mesagerie Privată',
                              style: Theme.of(context).textTheme.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            Text(
                              _magicLinkSent 
                                  ? 'Verifică mail-ul că ai primit un link epic!'
                                  : 'Introdu mail-ul pentru a primi un link epic',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // epic Link Form
                      if (!_magicLinkSent)
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.send,
                                onFieldSubmitted: (_) => _sendMagicLink(),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  hintText: 'Introdu mail-ul autorizat',
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Mail-ul este obligatoriu măi';
                                  }
                                  if (!value!.contains('@')) {
                                    return 'Da te rog frumos să introduci un email valid';
                                  }
                                  final allowedEmails = [
                                    'andrei.priv@andreimuntean.dev',
                                    'luci.priv@andreimuntean.dev'
                                  ];
                                  if (!allowedEmails.contains(value.trim().toLowerCase())) {
                                    return 'De ce încerci să te loghezi cu un email neautorizat? Mai încearcă.';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              ElevatedButton(
                                onPressed: authProvider.state == AuthState.loading ? null : _sendMagicLink,
                                child: authProvider.state == AuthState.loading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).accentText,
                                        ),
                                      )
                                    : const Text('Trimite Link Epic'),
                              ),
                            ],
                          ),
                        )
                      else
                        // epic link sent confirmation
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.mark_email_read_outlined,
                                size: 48,
                                color: Colors.green[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Link epic Trimis!',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Am trimis un link epic la ${_emailController.text.trim()}. Apasă pe link-ul din email și imposibilul devine posibil, te conectezi imincton.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _magicLinkSent = false;
                                    _emailController.clear();
                                  });
                                },
                                child: const Text('Trimite la alt email'),
                              ),
                            ],
                          ),
                        ),

                      const Spacer(),

                      // Error message
                      if (authProvider.errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            authProvider.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}