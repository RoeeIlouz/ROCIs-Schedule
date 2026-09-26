import 'package:rocis_schedule/core/config/app_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/services/sync_service.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:rocis_schedule/shared/widgets/ics_import_dialog.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/app_color_picker_sheet.dart';
import 'package:rocis_schedule/features/profile/widgets/about_app_dialog.dart';
import 'package:rocis_schedule/features/profile/widgets/delete_account_dialog.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match the navigation shell, which decides by window width.
        final isDesktop = MediaQuery.sizeOf(context).width >= 850;
        final bottomPadding = isDesktop ? 24.0 : 120.0;

        Widget content = ListView(
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            // 1. ACCOUNT SECTION
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
                          onPressed: () => context.push('/login'),
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
                        : l10n.translate('profile'),
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
                  // Signing out drops back to guest mode, not a login wall.
                  onTap: () => context.read<AuthService>().signOut(),
                ),
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.delete_outline_rounded,
                    theme.colorScheme.error,
                  ),
                  title: Text(
                    l10n.translate('delete_account'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: Text(l10n.translate('delete_account_desc')),
                  onTap: () => showDeleteAccountDialog(context),
                ),
              ],
            ]),

            // 2. APPEARANCE SECTION
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
                onTap: () => _showThemePicker(context, themeProvider, l10n),
              ),
              if (!kIsWeb) ...[
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
              ],
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.color_lens_outlined,
                  Colors.orange,
                ),
                title: Text(l10n.translate('accent_color')),
                subtitle: Text(
                  themeProvider.useDynamicColor
                      ? l10n.translate('system')
                      : '#${(themeProvider.customSeedColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeProvider.customSeedColor,
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                onTap: () async {
                  await AppColorPickerSheet.show(
                    context: context,
                    title: l10n.translate('accent_color'),
                    initialColor: themeProvider.customSeedColor,
                    onResetToDefault: () {
                      themeProvider.setCustomSeedColor(const Color(0xFF6366F1));
                    },
                    resetLabel: l10n.translate('reset_colors'),
                    onColorChanged: (c) {
                      themeProvider.setCustomSeedColor(c);
                    },
                  );
                },
              ),
              if (!kIsWeb) ...[
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
              ],
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

            // 3. NOTIFICATIONS SECTION
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
              if (themeProvider.enableReminders)
                ListTile(
                  leading: _buildLeadingIcon(
                    context,
                    Icons.schedule_rounded,
                    Colors.blue,
                  ),
                  title: Text(l10n.translate('reminder_lead_time')),
                  subtitle: Text(
                    _getReminderLeadTimeLabel(
                      context,
                      themeProvider.reminderLeadMinutes,
                    ),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    _showReminderLeadTimePicker(context, themeProvider, l10n);
                  },
                ),
            ]),

            // 4. PREFERENCES SECTION
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
                  _showLanguagePicker(context, themeProvider, l10n);
                },
              ),
            ]),

            // 5. CROSS-APP ECOSYSTEM SECTION
            if (themeProvider.enableTasksIntegration) ...[
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
                        SnackBar(content: Text(l10n.translate('syncing_data'))),
                      );
                      await syncService.fullSync();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.translate('sync_complete')),
                          ),
                        );
                      }
                    }
                  },
                ),
              ]),
            ],

            // 6. DATA & TIMETABLE SECTION
            _buildSectionHeader(context, l10n.translate('data_and_storage')),
            _buildSectionCard(context, [
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.upload_file_rounded,
                  Colors.teal,
                ),
                title: Text(l10n.translate('export_timetable')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final courseProvider = context.read<CourseProvider>();
                  final icsData = IcsImportService.exportIcsContent(
                    courseProvider.courses,
                    courseProvider.events,
                    semesters: courseProvider.semesters,
                  );
                  await Clipboard.setData(ClipboardData(text: icsData));
                  HapticFeedback.lightImpact();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('copied_to_clipboard')),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.download_rounded,
                  Colors.blue,
                ),
                title: Text(l10n.translate('import_timetable')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showIcsImportDialog(context),
              ),
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.delete_sweep_rounded,
                  Colors.redAccent,
                ),
                title: Text(
                  l10n.translate('clear_cache_title'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.translate('clear_cache_title')),
                      content: Text(l10n.translate('clear_cache_confirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(l10n.translate('cancel')),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(l10n.translate('delete')),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await context.read<CourseProvider>().clearLocalData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('clear_cache_success')),
                        ),
                      );
                    }
                  }
                },
              ),
            ]),

            // 7. ABOUT SECTION
            _buildSectionHeader(context, l10n.translate('about')),
            _buildSectionCard(context, [
              ListTile(
                leading: _buildLeadingIcon(
                  context,
                  Icons.info_outline_rounded,
                  Colors.indigo,
                ),
                title: Text(l10n.translate('about_app')),
                subtitle: Text(l10n.translate('about_app_subtitle')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => AboutAppDialog.show(context),
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
              child: GestureDetector(
                onTap: () => AboutAppDialog.show(context),
                child: Text(
                  'v${AppConfig.appVersion}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        );

        if (isDesktop) {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: content,
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.translate('settings'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: content,
        );
      },
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

  void _showThemePicker(
    BuildContext context,
    ThemeProvider themeProvider,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.translate('theme_mode'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeCard(
                      context,
                      mode: ThemeMode.system,
                      label: l10n.translate('system'),
                      icon: Icons.brightness_auto_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        themeProvider.setThemeMode(ThemeMode.system);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeCard(
                      context,
                      mode: ThemeMode.light,
                      label: l10n.translate('light'),
                      icon: Icons.light_mode_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        themeProvider.setThemeMode(ThemeMode.light);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeCard(
                      context,
                      mode: ThemeMode.dark,
                      label: l10n.translate('dark'),
                      icon: Icons.dark_mode_rounded,
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        themeProvider.setThemeMode(ThemeMode.dark);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context, {
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? primary : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getReminderLeadTimeLabel(BuildContext context, int minutes) {
    final l10n = AppLocalizations.of(context)!;
    switch (minutes) {
      case 10:
        return l10n.translate('10_min_before');
      case 15:
        return l10n.translate('15_min_before');
      case 30:
        return l10n.translate('30_min_before');
      case 60:
        return l10n.translate('1_hour_before');
      default:
        return '$minutes min';
    }
  }

  void _showReminderLeadTimePicker(
    BuildContext context,
    ThemeProvider themeProvider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.translate('reminder_lead_time'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildLeadTimeOption(
                context,
                10,
                l10n.translate('10_min_before'),
                themeProvider,
              ),
              _buildLeadTimeOption(
                context,
                15,
                l10n.translate('15_min_before'),
                themeProvider,
              ),
              _buildLeadTimeOption(
                context,
                30,
                l10n.translate('30_min_before'),
                themeProvider,
              ),
              _buildLeadTimeOption(
                context,
                60,
                l10n.translate('1_hour_before'),
                themeProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadTimeOption(
    BuildContext context,
    int minutes,
    String label,
    ThemeProvider provider,
  ) {
    final isSelected = provider.reminderLeadMinutes == minutes;
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
        provider.setReminderLeadMinutes(minutes);
        Navigator.pop(context);
      },
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    ThemeProvider themeProvider,
    AppLocalizations l10n,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                '🌐',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('en'),
                'English',
                '🇺🇸',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('he'),
                'עברית',
                '🇮🇱',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('es'),
                'Español',
                '🇪🇸',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('de'),
                'Deutsch',
                '🇩🇪',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('fr'),
                'Français',
                '🇫🇷',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('ar'),
                'العربية',
                '🇸🇦',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('hi'),
                'हिन्दी',
                '🇮🇳',
                themeProvider,
              ),
              _buildLocaleOption(
                context,
                const Locale('sv'),
                'Svenska',
                '🇸🇪',
                themeProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocaleOption(
    BuildContext context,
    Locale? locale,
    String label,
    String flag,
    ThemeProvider provider,
  ) {
    final isSelected =
        (locale == null && provider.locale == null) ||
        (locale != null &&
            provider.locale?.languageCode == locale.languageCode);
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 22)),
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
