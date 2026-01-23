import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final l10n = AppLocalizations.of(context)!;
    final firestore = context.read<FirestoreService>();

    if (user == null) {
      return Scaffold(body: Center(child: Text(l10n.translate('error'))));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('profile'))),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.getProfile(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['name'] ?? user.displayName ?? 'Student Name';
          final university = data['university'] ?? 'Tech University';
          final gradYear = data['gradYear'] ?? '2026';

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Center(
                child: Text(
                  user.email ?? 'student@university.edu',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              _buildProfileTile(
                context,
                icon: Icons.school_outlined,
                title: l10n.translate('university'),
                subtitle: university,
                onTap: () => context.push('/profile-setup'),
              ),
              _buildProfileTile(
                context,
                icon: Icons.calendar_today_outlined,
                title: l10n.translate('grad_year'),
                subtitle: gradYear,
                onTap: () => context.push('/profile-setup'),
              ),
              const Divider(),
              _buildProfileTile(
                context,
                icon: Icons.settings_outlined,
                title: l10n.translate('settings'),
                onTap: () => context.push('/settings'),
              ),
              _buildProfileTile(
                context,
                icon: Icons.logout,
                title: l10n.translate('sign_out'),
                onTap: () async {
                  await authService.signOut();
                  if (context.mounted) context.go('/login');
                },
                textColor: Theme.of(context).colorScheme.error,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
