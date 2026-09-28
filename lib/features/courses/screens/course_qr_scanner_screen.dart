import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/features/courses/widgets/import_course_preview_sheet.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

class CourseQrScannerScreen extends StatefulWidget {
  final CourseShareService? shareService;

  const CourseQrScannerScreen({super.key, this.shareService});

  static Future<bool?> open(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CourseQrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<CourseQrScannerScreen> createState() => _CourseQrScannerScreenState();
}

class _CourseQrScannerScreenState extends State<CourseQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final CourseShareService _shareService;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    _shareService = widget.shareService ?? CourseShareService();

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _cameraFacing,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeString(String raw) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();
    _controller.stop();

    final l10n = AppLocalizations.of(context)!;

    try {
      final shareData = await _shareService.resolveQrString(raw);

      if (!mounted) return;

      final didImport = await ImportCoursePreviewSheet.show(
        context,
        shareData: shareData,
      );

      if (didImport == true && mounted) {
        Navigator.pop(context, true);
        return;
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('expired')
            ? l10n.translate('course_share_expired')
            : l10n.translate('invalid_course_qr');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _controller.start();
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    HapticFeedback.lightImpact();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (files.isEmpty || files.first.path == null) {
        return;
      }

      final path = files.first.path!;
      final capture = await _controller.analyzeImage(path);

      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('invalid_course_qr')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final rawValue = capture.barcodes.first.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        await _handleBarcodeString(rawValue);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;
    final size = MediaQuery.of(context).size;
    final scanBoxSize = (size.width * 0.72).clamp(240.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isProcessing) return;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleBarcodeString(raw);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        size: 64,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('camera_permission_required'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Viewfinder Overlay Mask
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  width: double.infinity,
                  height: double.infinity,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Viewfinder Rounded Framing Border & Laser
          Align(
            alignment: Alignment.center,
            child: Container(
              width: scanBoxSize,
              height: scanBoxSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primary.withValues(alpha: 0.8),
                  width: 2.5,
                ),
              ),
              child: Stack(
                children: [
                  // Corner Highlights
                  ..._buildCornerMarkers(primary),

                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: scanBoxSize * _scanAnimation.value,
                        left: 12,
                        right: 12,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primary.withValues(alpha: 0.0),
                                primary,
                                primary.withValues(alpha: 0.0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Top Header & Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GlassContainer(
                    borderRadius: BorderRadius.circular(30),
                    opacity: 0.25,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    ),
                  ),
                  const Spacer(),
                  // Torch Toggle
                  GlassContainer(
                    borderRadius: BorderRadius.circular(30),
                    opacity: 0.25,
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _controller.toggleTorch();
                        setState(() {
                          _isTorchOn = !_isTorchOn;
                        });
                      },
                      tooltip: _isTorchOn
                          ? l10n.translate('turn_off_flash')
                          : l10n.translate('turn_on_flash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Flip Camera Toggle
                  GlassContainer(
                    borderRadius: BorderRadius.circular(30),
                    opacity: 0.25,
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded,
                          color: Colors.white),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _controller.switchCamera();
                        setState(() {
                          _cameraFacing = _cameraFacing == CameraFacing.back
                              ? CameraFacing.front
                              : CameraFacing.back;
                        });
                      },
                      tooltip: l10n.translate('flip_camera'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Instruction & Gallery Import Button
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.translate('scan_course_qr'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.translate('offline_direct_course_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    tintColor: primary,
                    opacity: 0.25,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickImageFromGallery,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.translate('pick_from_gallery'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 6. Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: BorderRadius.circular(16),
                  opacity: 0.4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('gcal_syncing'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers(Color color) {
    const size = 20.0;
    const thickness = 4.0;

    return [
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(4)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ),
      ),
    ];
  }
}
