import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  final _gradYearController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthService>().user;
      if (user != null) {
        final profile = await context.read<FirestoreService>().getProfile(
          user.uid,
        );
        if (profile.exists) {
          final data = profile.data() as Map<String, dynamic>;
          _nameController.text = data['name'] ?? '';
          _universityController.text = data['university'] ?? '';
          _gradYearController.text = data['gradYear'] ?? '';
        } else {
          _nameController.text = user.displayName ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _universityController.dispose();
    _gradYearController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthService>().user;
      final l10n = AppLocalizations.of(context)!;
      if (user != null) {
        await context
            .read<FirestoreService>()
            .updateProfile(user.uid, {
              'name': _nameController.text.trim(),
              'university': _universityController.text.trim(),
              'gradYear': _gradYearController.text.trim(),
              'email': user.email,
              'uid': user.uid,
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(l10n.translate('error_timeout'));
              },
            );
      }
      if (mounted) context.go('/schedule');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.translate('retry'),
              onPressed: _saveProfile,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('profile_info'))),
      body: SafeArea(
        child: _isLoading && _nameController.text.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.person_outline, size: 50),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AppTextField(
                        label: l10n.translate('full_name'),
                        hint: 'Enter your name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (v) =>
                            (v?.isNotEmpty ?? false) ? null : 'Required',
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: l10n.translate('university'),
                        hint: 'Where do you study?',
                        controller: _universityController,
                        prefixIcon: Icons.school_outlined,
                        validator: (v) =>
                            (v?.isNotEmpty ?? false) ? null : 'Required',
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: l10n.translate('grad_year'),
                        hint: 'e.g. 2026',
                        controller: _gradYearController,
                        prefixIcon: Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v ?? '') != null)
                            ? null
                            : 'Invalid year',
                      ),
                      const SizedBox(height: 48),
                      AppButton(
                        text: l10n.translate('save_profile'),
                        isLoading: _isLoading,
                        onPressed: _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
