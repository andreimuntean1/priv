import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/user_status_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/theme.dart';

class UserProfileScreen extends StatelessWidget {
  final User user;

  const UserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profil ${user.username}'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Consumer<UserStatusProvider>(
            builder: (context, userStatusProvider, child) {
          final currentUser = userStatusProvider.getUser(user.id) ?? user;
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Card - exactly like settings page
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: currentUser.avatarUrl != null
                            ? NetworkImage(currentUser.avatarUrl!)
                            : null,
                        child: currentUser.avatarUrl == null
                            ? Text(
                                currentUser.username.isNotEmpty
                                    ? currentUser.username[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppThemeColors.getColors(context.read<ThemeProvider>().themeType).accentText,
                                ),
                              )
                            : null,
                      ),

                      const SizedBox(height: 20),

                      // Username Section
                      Row(
                        children: [
                          const Icon(Icons.person_outline),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nume de utilizator',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentUser.username,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Email Section
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
                                  currentUser.email,
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
            ],
          );
        },
      ),
    ),
  ),
    );
  }
}
