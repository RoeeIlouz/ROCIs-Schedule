import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const AboutAppDialog(),
    );
  }

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  int _tapCount = 0;

  static const String _websiteUrl = 'https://rocisapps.com';
  static const String _githubUrl =
      'https://github.com/RoeeIlouz/ROCIs-Schedule';
  static const String _supportEmail = 'support@rocisapps.com';

  Future<void> _launch(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {'subject': 'ROCIs Schedule Feedback & Support'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/logo.png',
              width: 44,
              height: 44,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('app_title'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    _tapCount++;
                    if (_tapCount >= 5 && !themeProvider.betaFeaturesUnlocked) {
                      HapticFeedback.heavyImpact();
                      themeProvider.setBetaFeaturesUnlocked(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('beta_mode_unlocked')),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } else if (_tapCount < 5 &&
                        !themeProvider.betaFeaturesUnlocked) {
                      HapticFeedback.selectionClick();
                    }
                  },
                  child: Text(
                    'v0.0.3',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              l10n.translate('about_app_description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              title: Text(l10n.translate('visit_website')),
              subtitle: const Text('rocisapps.com'),
              onTap: () => _launch(_websiteUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.code_rounded,
                color: theme.colorScheme.secondary,
                size: 22,
              ),
              title: Text(l10n.translate('view_github')),
              subtitle: const Text('RoeeIlouz/ROCIs-Schedule'),
              onTap: () => _launch(_githubUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.mail_outline_rounded,
                color: Colors.teal,
                size: 22,
              ),
              title: Text(l10n.translate('contact_support')),
              subtitle: const Text(_supportEmail),
              onTap: _sendEmail,
            ),

            // BETA FEATURES PANEL
            if (themeProvider.betaFeaturesUnlocked) ...[
              const SizedBox(height: 12),
              Material(
                color: (isDark ? Colors.purpleAccent : Colors.deepPurple)
                    .withValues(alpha: isDark ? 0.12 : 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: (isDark ? Colors.purpleAccent : Colors.deepPurple)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.science_rounded,
                            size: 20,
                            color: isDark
                                ? Colors.purpleAccent
                                : Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.translate('beta_features'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.purpleAccent
                                  : Colors.deepPurple,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? Colors.purpleAccent
                                          : Colors.deepPurple)
                                      .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'BETA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.purpleAccent
                                    : Colors.deepPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.translate('rocis_tasks_integration'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          l10n.translate('rocis_tasks_integration_desc'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: themeProvider.enableTasksIntegration,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          themeProvider.setEnableTasksIntegration(val);
                        },
                      ),
                      if (themeProvider.enableTasksIntegration) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.translate('cross_app_sync_active'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.teal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}
