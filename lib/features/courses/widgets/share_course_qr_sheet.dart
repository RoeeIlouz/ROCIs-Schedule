import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

enum ShareQrMode {
  offline,
  cloud,
}

class ShareCourseQrSheet extends StatefulWidget {
  final Course course;
  final List<ScheduleEvent> events;
  final CourseShareService? shareService;

  const ShareCourseQrSheet({
    super.key,
    required this.course,
    required this.events,
    this.shareService,
  });

  static Future<void> show(
    BuildContext context, {
    required Course course,
    required List<ScheduleEvent> events,
    CourseShareService? shareService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCourseQrSheet(
        course: course,
        events: events,
        shareService: shareService,
      ),
    );
  }

  @override
  State<ShareCourseQrSheet> createState() => _ShareCourseQrSheetState();
}

class _ShareCourseQrSheetState extends State<ShareCourseQrSheet> {
  late final CourseShareService _shareService;
  ShareQrMode _selectedMode = ShareQrMode.offline;

  late String _offlinePayload;
  String? _cloudPayload;
  bool _isUploadingCloud = false;
  String? _cloudError;

  @override
  void initState() {
    super.initState();
    _shareService = widget.shareService ?? CourseShareService();
    _generateOfflinePayload();
  }

  void _generateOfflinePayload() {
    _offlinePayload =
        _shareService.generateOfflinePayload(widget.course, widget.events);
  }

  Future<void> _switchToCloudMode() async {
    setState(() {
      _selectedMode = ShareQrMode.cloud;
    });

    if (_cloudPayload != null || _isUploadingCloud) return;

    setState(() {
      _isUploadingCloud = true;
      _cloudError = null;
    });

    try {
      final link = await _shareService.uploadCloudCourse(
        widget.course,
        widget.events,
      );
      if (mounted) {
        setState(() {
          _cloudPayload = link;
          _isUploadingCloud = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cloudError = e.toString();
          _isUploadingCloud = false;
        });
      }
    }
  }

  String get _currentPayload {
    if (_selectedMode == ShareQrMode.cloud) {
      return _cloudPayload ?? _offlinePayload;
    }
    return _offlinePayload;
  }

  void _copyToClipboard(BuildContext context, AppLocalizations l10n) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _currentPayload));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate('qr_data_copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = widget.course.color;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        opacity: 0.22,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.qr_code_2_rounded,
                        color: primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('share_course_qr'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.course.name}${widget.course.code.isNotEmpty ? ' (${widget.course.code})' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Segmented Toggle
                SegmentedButton<ShareQrMode>(
                  segments: [
                    ButtonSegment(
                      value: ShareQrMode.offline,
                      label: Text(l10n.translate('offline_direct')),
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: ShareQrMode.cloud,
                      label: Text(l10n.translate('cloud_share_7days')),
                      icon: const Icon(Icons.cloud_outlined, size: 18),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (Set<ShareQrMode> newSelection) {
                    if (newSelection.first == ShareQrMode.cloud) {
                      _switchToCloudMode();
                    } else {
                      setState(() {
                        _selectedMode = ShareQrMode.offline;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // QR Code Display Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isUploadingCloud
                      ? SizedBox(
                          width: 200,
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: primary),
                              const SizedBox(height: 16),
                              Text(
                                l10n.translate('gcal_syncing'),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _cloudError != null
                          ? SizedBox(
                              width: 200,
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _cloudError!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _switchToCloudMode,
                                    child: Text(l10n.translate('gcal_error')),
                                  ),
                                ],
                              ),
                            )
                          : QrImageView(
                              data: _currentPayload,
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: primary,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                ),
                const SizedBox(height: 16),

                // Event Count Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: primary),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.events.length} ${l10n.translate('course_time_slots')}',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Mode Explanation Banner
                Text(
                  _selectedMode == ShareQrMode.offline
                      ? l10n.translate('offline_direct_course_desc')
                      : l10n.translate('cloud_share_course_desc'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),

                // Action Button: Copy QR Data
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _copyToClipboard(context, l10n),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(l10n.translate('copy_qr_data')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
