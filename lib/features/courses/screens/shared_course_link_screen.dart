import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/features/courses/widgets/import_course_preview_sheet.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/web/browser_url.dart';

/// Target of `https://schedule.rocisapps.com/share?d=…|id=…` links (App Link
/// on Android, `/share` route on web). Shows the import preview, then opens
/// the course list.
class SharedCourseLinkScreen extends StatefulWidget {
  final Uri link;

  const SharedCourseLinkScreen({super.key, required this.link});

  @override
  State<SharedCourseLinkScreen> createState() => _SharedCourseLinkScreenState();
}

class _SharedCourseLinkScreenState extends State<SharedCourseLinkScreen> {
  final CourseShareService _shareService = CourseShareService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLink());
  }

  Future<void> _openLink() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final shareData = await _shareService.resolveQrString(
        widget.link.toString(),
      );
      if (!mounted) return;
      await ImportCoursePreviewSheet.show(context, shareData: shareData);
    } catch (e) {
      final expired = e.toString().contains('expired');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.translate(
              expired ? 'course_share_expired' : 'invalid_course_qr',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (kIsWeb) replaceBrowserUrl('/');
    if (mounted) context.go('/courses');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
