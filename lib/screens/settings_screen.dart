import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';
import '../screens/auth_screen.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _usernameController.text = user?.username ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final success = await context.read<AuthProvider>().updateProfile(
      username: _usernameController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      _isEditing = false;
    });

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nume legendar de utilizator o fost actualizat cu succes no'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AuthProvider>().errorMessage ?? 'Ec 9:11, timpul și evenimentele neprevăzute o făcut să nu putem actualiza numele de utilizator, scuzați!',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconectare'),
        content: const Text('Ești sigur sigur sigur că vrei să te deconnectești?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Dăi pace'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deconectează-te'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }




  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        // Reset to original username if cancelling
        final user = context.read<AuthProvider>().currentUser;
        _usernameController.text = user?.username ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setări'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _updateUsername,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvează'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).primaryColor,
                            backgroundImage: user.avatarUrl != null
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? Text(
                                    user.username.isNotEmpty
                                        ? user.username[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Username Section
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _isEditing
                                ? TextFormField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nume legendar de utilizator',
                                      border: OutlineInputBorder(),
                                    ),
                                    enabled: !_isLoading,
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nume legendar de utilizator',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.username,
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                          ),
                          IconButton(
                            icon: Icon(_isEditing ? Icons.close : Icons.edit),
                            onPressed: _isLoading ? null : _toggleEditMode,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Email Section (Read-only)
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // App Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.read<ThemeProvider>().incrementEasterEggTap();
                        },
                        child: Icon(
                          Icons.palette_outlined,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temă',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.watch<ThemeProvider>().themeType == AppThemeType.parkside
                                  ? 'Parkside'
                                  : 'Implicit',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<AppThemeType>(
                        value: context.watch<ThemeProvider>().themeType,
                        underline: const SizedBox(),
                        onChanged: (AppThemeType? newValue) {
                          if (newValue != null) {
                            context.read<ThemeProvider>().setThemeType(newValue);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: AppThemeType.defaultDark,
                            child: Text('Implicit'),
                          ),
                          DropdownMenuItem(
                            value: AppThemeType.parkside,
                            child: Text('Parkside'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Parkside Easter Egg Logo
              if (context.watch<ThemeProvider>().showParksideEasterEgg)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: GestureDetector(
                        onTap: () async {
                          final url = Uri.parse('https://www.lidl.ro/c/parkside/s10068914');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Image.asset(
                          'assets/images/parkside_logo.png',
                          width: 200,
                          height: 200,
                        ),
                      ),
                    ),
                  ),
                ),

              // Sign Out Button
              ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Deconectează-te',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    ),
  ),
    );
  }
}