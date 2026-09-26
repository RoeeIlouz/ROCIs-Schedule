import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';

/// Confirms and performs permanent deletion of the signed-in account.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (auth.usesPassword && _passwordController.text.isEmpty) {
      setState(() => _error = l10n.translate('delete_account_password'));
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await auth.deleteAccount(
        context.read<FirestoreService>(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (!deleted) {
        setState(() => _deleting = false);
        return;
      }
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('account_deleted'))),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Delete account failed: ${e.code}');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = l10n.translate(
          e.code == 'wrong-password' || e.code == 'invalid-credential'
              ? 'delete_account_wrong_password'
              : 'delete_account_failed',
        );
      });
    } catch (e) {
      debugPrint('Delete account failed: $e');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = l10n.translate('delete_account_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final usesPassword = context.read<AuthService>().usesPassword;

    return AlertDialog(
      title: Text(l10n.translate('delete_account')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('delete_account_confirm')),
          if (usesPassword) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              enabled: !_deleting,
              decoration: InputDecoration(
                labelText: l10n.translate('password'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.translate('cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onError,
                  ),
                )
              : Text(l10n.translate('delete_account')),
        ),
      ],
    );
  }
}
