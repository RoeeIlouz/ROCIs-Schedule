import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final isGuest = authService.isGuest || user == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildSectionHeader(context, l10n.translate('account')),
          _buildSectionCard(context, [
            if (isGuest) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeadingIcon(
                          context,
                          Icons.person_outline_rounded,
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('guest_account'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.translate('guest_mode_subtitle'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.login_rounded, size: 18),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        label: Text(l10n.translate('sign_in_or_register')),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage:
                      user.photoURL != null && user.photoURL!.isNotEmpty
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null || user.photoURL!.isEmpty
                      ? Text(
                          (user.displayName != null &&
                                  user.displayName!.isNotEmpty)
                              ? user.displayName![0].toUpperCase()
                              : (user.email != null && user.email!.isNotEmpty
                                    ? user.email![0].toUpperCase()
                                    : 'U'),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  (user.displayName != null && user.displayName!.isNotEmpty)
                      ? user.displayName!
                      : 'User',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.email != null && user.email!.isNotEmpty)
                      Text(user.email!),
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: user.uid));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.translate('copied_to_clipboard'),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'UID: ${user.uid}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.cloud_done_rounded,
                  Colors.teal,
                ),
                title: Text(l10n.translate('cloud_sync')),
                subtitle: Text(l10n.translate('cloud_sync_active')),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.logout_rounded,
                  Colors.redAccent,
                ),
                title: Text(
                  l10n.translate('sign_out'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  await context.read<AuthService>().signOut();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ]),
          _buildSectionHeader(context, l10n.translate('appearance')),
          _buildSectionCard(context, [
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.brightness_medium_rounded,
                theme.colorScheme.primary,
              ),
              title: Text(l10n.translate('theme_mode')),
              subtitle: Text(
                _getThemeModeName(context, themeProvider.themeMode),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
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
                          Icons.brightness_auto_rounded,
                          themeProvider,
                        ),
                        _buildThemeOption(
                          context,
                          ThemeMode.light,
                          l10n.translate('light'),
                          Icons.light_mode_rounded,
                          themeProvider,
                        ),
                        _buildThemeOption(
                          context,
                          ThemeMode.dark,
                          l10n.translate('dark'),
                          Icons.dark_mode_rounded,
                          themeProvider,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.blur_on_rounded,
                Colors.teal,
              ),
              title: Text(l10n.translate('glassmorphism')),
              value: themeProvider.useGlassmorphism,
              onChanged: (v) => themeProvider.setUseGlassmorphism(v),
            ),
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.palette_outlined,
                Colors.pink,
              ),
              title: Text(l10n.translate('material_you')),
              value: themeProvider.useDynamicColor,
              onChanged: (v) => themeProvider.setUseDynamicColor(v),
            ),
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.dark_mode_outlined,
                Colors.indigo,
              ),
              title: Text(l10n.translate('amoled_mode')),
              value: themeProvider.isAmoled,
              onChanged: themeProvider.themeMode == ThemeMode.light
                  ? null
                  : (v) => themeProvider.setIsAmoled(v),
            ),
          ]),
          _buildSectionHeader(context, l10n.translate('notifications')),
          _buildSectionCard(context, [
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.notifications_active_outlined,
                Colors.amber,
              ),
              title: Text(l10n.translate('class_reminders')),
              value: themeProvider.enableReminders,
              onChanged: (v) async {
                await themeProvider.setEnableReminders(v);
                if (!v) {
                  await NotificationService().cancelAll();
                }
              },
            ),
          ]),
          _buildSectionHeader(context, l10n.translate('preferences')),
          _buildSectionCard(context, [
            SwitchListTile(
              secondary: _buildLeadingIcon(
                context,
                Icons.access_time_rounded,
                Colors.blue,
              ),
              title: Text(l10n.translate('time_format_24h')),
              value: themeProvider.use24HourFormat,
              onChanged: (v) => themeProvider.setUse24HourFormat(v),
            ),
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.language_rounded,
                Colors.green,
              ),
              title: Text(l10n.translate('language')),
              subtitle: Text(
                _getLocaleName(context, themeProvider.locale),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (context) => SafeArea(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: Text(
                              l10n.translate('language'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          const Divider(),
                          _buildLocaleOption(
                            context,
                            null,
                            l10n.translate('system'),
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('en'),
                            'English',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('he'),
                            'עברית',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('es'),
                            'Español',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('de'),
                            'Deutsch',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('fr'),
                            'Français',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('ar'),
                            'العربية',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('hi'),
                            'हिन्दी',
                            themeProvider,
                          ),
                          _buildLocaleOption(
                            context,
                            const Locale('sv'),
                            'Svenska',
                            themeProvider,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
          _buildSectionHeader(context, l10n.translate('ecosystem_apps')),
          _buildSectionCard(context, [
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.task_alt_rounded,
                Colors.teal,
              ),
              title: Text(l10n.translate('rocis_tasks_title')),
              subtitle: Text(l10n.translate('rocis_tasks_subtitle')),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => CrossAppBridgeService.openRocisTasks(),
            ),
            ListTile(
              leading: _buildLeadingIcon(
                context,
                Icons.sync_rounded,
                Colors.blueAccent,
              ),
              title: Text(l10n.translate('sync_now')),
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
          ]),
          const SizedBox(height: 24),
          Center(
            child: Text(
              l10n.translate('made_with'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'v1.1.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildSectionCard(BuildContext context, List<Widget> children) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.08);
    final List<Widget> dividedChildren = [];
    for (int i = 0; i < children.length; i++) {
      dividedChildren.add(children[i]);
      if (i < children.length - 1) {
        dividedChildren.add(
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
            indent: 64,
            endIndent: 16,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: dividedChildren),
          ),
        ),
      ),
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
    final isSelected =
        (locale == null && provider.locale == null) ||
        (locale != null &&
            provider.locale?.languageCode == locale.languageCode);
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
}
