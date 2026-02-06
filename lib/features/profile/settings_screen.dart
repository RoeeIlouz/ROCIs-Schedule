import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: Theme.of(context).copyWith(
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.primary;
            }
            return null;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.primaryContainer;
            }
            return null;
          }),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.translate('settings').toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          children: [
            _buildSectionHeader(context, l10n.translate('account')),
            _buildSettingsTile(
              context,
              icon: Icons.person_outline,
              title: l10n.translate('profile_info'),
              subtitle: l10n.translate('profile_subtitle'),
              onTap: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(context, l10n.translate('appearance')),
            _buildSettingsTile(
              context,
              icon: Icons.brightness_6_outlined,
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
                // Show a simple bottom sheet for theme selection
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
                          ThemeMode.light,
                          l10n.translate('light'),
                          Icons.light_mode_outlined,
                          themeProvider,
                        ),
                        _buildThemeOption(
                          context,
                          ThemeMode.dark,
                          l10n.translate('dark'),
                          Icons.dark_mode_outlined,
                          themeProvider,
                        ),
                        _buildThemeOption(
                          context,
                          ThemeMode.system,
                          l10n.translate('system'),
                          Icons.settings_suggest_outlined,
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
              icon: Icons.palette_outlined,
              title: l10n.translate('material_you'),
              value: themeProvider.useDynamicColor,
              onChanged: (val) => themeProvider.setUseDynamicColor(val),
            ),
            _buildSwitchTile(
              context,
              icon: Icons.contrast_outlined,
              title: l10n.translate('amoled_mode'),
              value: themeProvider.isAmoled,
              onChanged: isDark
                  ? (val) => themeProvider.setIsAmoled(val)
                  : null,
            ),
            _buildSwitchTile(
              context,
              icon: Icons.access_time_outlined,
              title: l10n.translate('time_format_24h'),
              value: themeProvider.use24HourFormat,
              onChanged: (val) => themeProvider.setUse24HourFormat(val),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(context, l10n.translate('data_sync')),
            _buildSettingsTile(
              context,
              icon: Icons.sync_rounded,
              title: l10n.translate('sync_now'),
              onTap: () {},
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
            _buildSettingsTile(
              context,
              icon: Icons.delete_outline_rounded,
              title: l10n.translate('trash'),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {},
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<AuthService>().signOut();
                  if (context.mounted) context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
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
    return locale.languageCode == 'he'
        ? l10n.translate('hebrew')
        : l10n.translate('english');
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
