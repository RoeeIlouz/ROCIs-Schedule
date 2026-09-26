import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

/// App-bar entry to the account: guests get an unobtrusive person outline
/// that opens sign-in; signed-in users see their avatar, which opens settings.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final auth = context.watch<AuthService>();
    final user = auth.user;

    if (auth.isGuest || user == null) {
      return IconButton(
        icon: const Icon(Icons.person_outline_rounded),
        tooltip: l10n.translate('sign_in_to_sync'),
        onPressed: () => context.push('/login'),
      );
    }

    final photo = user.photoURL;
    final name = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email ?? '');
    return IconButton(
      tooltip: l10n.translate('account'),
      onPressed: () => context.go('/settings'),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: photo != null && photo.isNotEmpty
            ? NetworkImage(photo)
            : null,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
