import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final firestore = context.read<FirestoreService>();

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.translate('profile'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 45,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                l10n.translate('guest_mode_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              tintColor: theme.colorScheme.primary,
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.translate('guest_mode_banner'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(l10n.translate('sign_in')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileTile(
              context,
              icon: Icons.settings_outlined,
              title: l10n.translate('settings'),
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('profile'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot?>(
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
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Center(
                child: Text(
                  user.email ?? 'student@university.edu',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 28),
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
                textColor: theme.colorScheme.error,
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
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
