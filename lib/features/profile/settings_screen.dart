import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, l10n.translate('appearance')),
          _buildSettingsTile(
            context,
            icon: Icons.palette_outlined,
            title: l10n.translate('theme_mode'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getThemeModeName(context, themeProvider.themeMode),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildThemeOption(
                        context,
                        ThemeMode.system,
                        l10n.translate('system'),
                        Icons.brightness_auto,
                        themeProvider,
                      ),
                      _buildThemeOption(
                        context,
                        ThemeMode.light,
                        l10n.translate('light'),
                        Icons.light_mode,
                        themeProvider,
                      ),
                      _buildThemeOption(
                        context,
                        ThemeMode.dark,
                        l10n.translate('dark'),
                        Icons.dark_mode,
                        themeProvider,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildSwitchTile(
            context,
            icon: Icons.auto_awesome_rounded,
            title: l10n.translate('glassmorphism'),
            value: themeProvider.useGlassmorphism,
            onChanged: (v) => themeProvider.setUseGlassmorphism(v),
          ),
          _buildSwitchTile(
            context,
            icon: Icons.color_lens_outlined,
            title: l10n.translate('material_you'),
            value: themeProvider.useDynamicColor,
            onChanged: (v) => themeProvider.setUseDynamicColor(v),
          ),
          _buildSwitchTile(
            context,
            icon: Icons.brightness_2_outlined,
            title: l10n.translate('amoled_mode'),
            value: themeProvider.isAmoled,
            onChanged: themeProvider.themeMode == ThemeMode.light
                ? null
                : (v) => themeProvider.setIsAmoled(v),
          ),
          _buildSectionHeader(context, l10n.translate('notifications')),
          _buildSwitchTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: l10n.translate('class_reminders'),
            value: themeProvider.enableReminders,
            onChanged: (v) async {
              await themeProvider.setEnableReminders(v);
              if (!v) {
                await NotificationService().cancelAll();
              }
            },
          ),
          _buildSectionHeader(context, l10n.translate('preferences')),
          _buildSwitchTile(
            context,
            icon: Icons.access_time_rounded,
            title: l10n.translate('time_format_24h'),
            value: themeProvider.use24HourFormat,
            onChanged: (v) => themeProvider.setUse24HourFormat(v),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.language_outlined,
            title: l10n.translate('language'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getLocaleName(context, themeProvider.locale),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLocaleOption(
                        context,
                        null,
                        l10n.translate('system'),
                        themeProvider,
                      ),
                      _buildLocaleOption(
                        context,
                        const Locale('en'),
                        l10n.translate('english'),
                        themeProvider,
                      ),
                      _buildLocaleOption(
                        context,
                        const Locale('he'),
                        l10n.translate('hebrew'),
                        themeProvider,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildSectionHeader(context, l10n.translate('ecosystem_apps')),
          _buildSettingsTile(
            context,
            icon: Icons.task_alt_rounded,
            title: l10n.translate('rocis_tasks_title'),
            subtitle: l10n.translate('rocis_tasks_subtitle'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => CrossAppBridgeService.openRocisTasks(),
          ),
          _buildSectionHeader(context, l10n.translate('data_sync')),
          _buildSettingsTile(
            context,
            icon: Icons.sync_rounded,
            title: l10n.translate('sync_now'),
            onTap: () async {
              final syncService = context.read<SyncService?>();
              if (syncService != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('loading'))),
                );
                await syncService.fullSync();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync completed')),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: (context.watch<AuthService?>()?.isGuest ?? true)
                ? ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.login_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.translate('sign_in')),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: () async {
                      await context.read<AuthService>().signOut();
                      if (context.mounted) context.go('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.translate('sign_out')),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 48),
          Center(
            child: Text(
              l10n.translate('made_with'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          : null,
      trailing: trailing != null
          ? IconTheme.merge(
              data: IconThemeData(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              child: trailing,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    String label,
    IconData icon,
    ThemeProvider provider,
  ) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        provider.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLocaleOption(
    BuildContext context,
    Locale? locale,
    String label,
    ThemeProvider provider,
  ) {
    final isSelected = provider.locale == locale;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        provider.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  String _getLocaleName(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context)!;
    if (locale == null) return l10n.translate('system');
    switch (locale.languageCode) {
      case 'he':
        return 'עברית';
      case 'es':
        return 'Español';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'hi':
        return 'हिन्दी';
      case 'sv':
        return 'Svenska';
      case 'en':
      default:
        return 'English';
    }
  }

  String _getThemeModeName(BuildContext context, ThemeMode mode) {
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case ThemeMode.system:
        return l10n.translate('system');
      case ThemeMode.light:
        return l10n.translate('light');
      case ThemeMode.dark:
        return l10n.translate('dark');
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}



