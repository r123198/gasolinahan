import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../components/app_primary_button.dart';
import '../components/report_camera_painters.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/app_theme.dart';

class CameraOverlayView extends StatefulWidget {
  const CameraOverlayView({super.key});

  @override
  State<CameraOverlayView> createState() => _CameraOverlayViewState();
}

class _CameraOverlayViewState extends State<CameraOverlayView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

  /// True while [_initCamera] runs, so a lifecycle resume arriving before
  /// the first start finishes doesn't open a second controller.
  bool _initializing = false;
  FlashMode _flashMode = FlashMode.auto;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive) {
      if (controller == null || !controller.value.isInitialized) return;
      // Drop the controller from state *before* disposing it so no rebuild
      // can hand a disposed controller to CameraPreview.
      setState(() {
        _controller = null;
        _isInitialized = false;
      });
      controller.dispose();
    } else if (state == AppLifecycleState.resumed &&
        controller == null &&
        _errorMessage == null) {
      _initCamera();
    }
  }

  Future<void> _retry() async {
    setState(() => _errorMessage = null);
    await _initCamera();
  }

  static String _friendlyCameraError(CameraException e) => switch (e.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      'Camera access is off. Allow it in Settings to scan price boards.',
    _ => "Couldn't start the camera. Try again.",
  };

  Future<void> _initCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera found on this phone.');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } on CameraException catch (e) {
      debugPrint('Camera init failed: ${e.code} ${e.description}');
      if (mounted) setState(() => _errorMessage = _friendlyCameraError(e));
    } finally {
      _initializing = false;
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, file.path);
      }
    } on CameraException catch (e) {
      debugPrint('Capture failed: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() => _isCapturing = false);
      showAppToast(context, "Couldn't take the photo. Try again.");
    }
  }

  void _toggleFlash() {
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    _flashMode = next;
    _controller?.setFlashMode(next);
    setState(() {});
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.always => Icons.flash_on_rounded,
    _ => Icons.flash_off_rounded,
  };

  String get _flashLabel => switch (_flashMode) {
    FlashMode.auto => 'Auto',
    FlashMode.always => 'On',
    _ => 'Off',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _errorMessage != null
          ? _buildError()
          : switch (_controller) {
              final controller? when _isInitialized => _buildCamera(controller),
              _ => _buildLoading(),
            },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSpinner(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: 'Try again',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              onPressed: _retry,
            ),
            const SizedBox(height: 8),
            AppTextButton(
              onPressed: () => Navigator.pop(context),
              foregroundColor: Colors.white,
              child: const Text(
                'Go back',
                style: TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera(CameraController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Positioned.fill(child: CameraPreview(controller)),

        // Dark overlay with cutout window
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: ScanOverlayPainter()),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  AppIconButton(
                    tooltip: 'Close camera',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Price scanner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AppIconButton(
                    tooltip: 'Flash: $_flashLabel',
                    onPressed: _toggleFlash,
                    icon: Icon(_flashIcon, color: Colors.white, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instructions - positioned above the scan window
        Positioned(
          left: 32,
          right: 32,
          top: MediaQuery.of(context).size.height * 0.18,
          child: Column(
            children: [
              const Text(
                'Scan the price board',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fit the whole board inside the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Corner guides inside the cutout
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final rectW = w - 48;
                final rectH = h * 0.35;
                final left = 24.0;
                final top = h * 0.28;
                return CustomPaint(
                  painter: CornersPainter(
                    rect: Rect.fromLTWH(left, top, rectW, rectH),
                  ),
                );
              },
            ),
          ),
        ),

        // Tips at bottom of scan area
        Positioned(
          left: 32,
          right: 32,
          bottom: MediaQuery.of(context).size.height * 0.30,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildTip(Icons.wb_sunny_outlined, 'Good lighting'),
              _buildTip(Icons.straighten_outlined, 'Hold steady'),
              _buildTip(Icons.crop_free_rounded, 'Fill the frame'),
            ],
          ),
        ),

        // Bottom controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.80),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flash label
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_flashIcon, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Flash $_flashLabel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Capture button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Spacer to balance layout (no gallery — camera only)
                      const SizedBox(width: 48),
                      // Shutter button
                      Semantics(
                        button: true,
                        enabled: !_isCapturing,
                        label: _isCapturing ? 'Taking photo' : 'Take photo',
                        excludeSemantics: true,
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: GestureDetector(
                          onTap: _isCapturing ? null : _capturePhoto,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isCapturing
                                    ? Colors.grey
                                    : Colors.white,
                              ),
                              child: _isCapturing
                                  ? const Padding(
                                      padding: EdgeInsets.all(18),
                                      child: AppSpinner(
                                        color: Colors.black54,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      // Cancel button
                      _buildBottomButton(
                        icon: Icons.close_rounded,
                        label: 'Cancel',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
