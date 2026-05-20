import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen camera screen with live preview.
///
/// Push via root navigator so the bottom nav bar is fully covered:
/// ```dart
/// final file = await Navigator.of(context, rootNavigator: true)
///     .push<File>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
/// ```
/// Returns the captured [File] if the user confirms, or `null` if they back out.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _initializing = true;

  /// Captured image (shown in preview/confirm state)
  XFile? _captured;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]); // restore all orientations
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera found on this device.';
          _initializing = false;
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera unavailable: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await ctrl.takePicture();
      setState(() {
        _captured = file;
        _capturing = false;
      });
    } catch (e) {
      setState(() => _capturing = false);
    }
  }

  void _retake() => setState(() => _captured = null);

  void _confirm() {
    if (_captured == null) return;
    Navigator.of(context).pop(File(_captured!.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _captured != null ? _buildPreview() : _buildViewfinder(),
    );
  }

  // ── Live viewfinder ────────────────────────────────────────────────────────

  Widget _buildViewfinder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_initializing)
          const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          )
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          _CameraPreviewFill(controller: _controller!),

        // Semi-transparent vignette at top and bottom
        _Vignette(),

        // Back button
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            ),
          ),
        ),

        // Title
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: const Text(
                'Scan Medication',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),

        // Corner bracket frame
        if (!_initializing && _error == null)
          Center(
            child: FractionallySizedBox(
              widthFactor: 0.82,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _CornerBracket(top: true, left: true),
                    _CornerBracket(top: true, left: false),
                    _CornerBracket(top: false, left: true),
                    _CornerBracket(top: false, left: false),
                  ],
                ),
              ),
            ),
          ),

        // Bottom controls
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Align the medication label inside the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Shutter button
                  GestureDetector(
                    onTap: _initializing || _error != null ? null : _capture,
                    child: AnimatedScale(
                      scale: _capturing ? 0.88 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _capturing
                            ? const Padding(
                                padding: EdgeInsets.all(22),
                                child: CircularProgressIndicator(
                                  color: Colors.black54,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black87,
                                size: 32,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gallery fallback
                  TextButton.icon(
                    onPressed: () async {
                      // Pop back with a null signal so scan_page can open gallery picker
                      Navigator.of(context).pop('gallery');
                    },
                    icon: const Icon(Icons.image_outlined,
                        color: Colors.white60, size: 18),
                    label: const Text(
                      'Upload from Photos',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Captured preview / confirm ─────────────────────────────────────────────

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen image preview
        Image.file(File(_captured!.path), fit: BoxFit.cover),

        // Vignette
        _Vignette(),

        // Status chip
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00C853), size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Photo captured',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom confirm panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Use This Photo'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: const Color(0xFF0066CC),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _retake,
                        icon: const Icon(Icons.refresh,
                            color: Colors.white60, size: 18),
                        label: const Text(
                          'Retake',
                          style: TextStyle(
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Fills its parent with the camera preview — crop-to-cover, no distortion.
///
/// Key insight: [CameraPreview] internally applies `AspectRatio(1/controller.aspectRatio)`
/// in portrait mode. We must NOT add another AspectRatio wrapper; we only calculate
/// the uniform scale needed so the already-correct preview covers the screen.
class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final screenRatio = size.width / size.height; // portrait ~0.46

    // CameraPreview in portrait renders at 1/aspectRatio (e.g. 9/16 ≈ 0.5625).
    // Do NOT apply a second AspectRatio — that causes the visible stretching.
    final previewRatio = 1.0 / controller.value.aspectRatio;

    // Uniform scale so the preview covers the screen (crop-to-cover):
    //   • previewRatio > screenRatio → preview is less tall → scale by height
    //   • previewRatio < screenRatio → preview is taller  → scale by width
    final double scale = previewRatio > screenRatio
        ? size.height * previewRatio / size.width
        : size.width / (size.height * previewRatio);

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: CameraPreview(controller), // no AspectRatio wrapper here
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent],
          stops: const [0, 0.35],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.top, required this.left});
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? -1 : null,
      bottom: !top ? -1 : null,
      left: left ? -1 : null,
      right: !left ? -1 : null,
      child: SizedBox(
        width: 32,
        height: 32,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: top
                  ? const BorderSide(color: Colors.white, width: 3)
                  : BorderSide.none,
              bottom: !top
                  ? const BorderSide(color: Colors.white, width: 3)
                  : BorderSide.none,
              left: left
                  ? const BorderSide(color: Colors.white, width: 3)
                  : BorderSide.none,
              right: !left
                  ? const BorderSide(color: Colors.white, width: 3)
                  : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft: top && left ? const Radius.circular(6) : Radius.zero,
              topRight: top && !left ? const Radius.circular(6) : Radius.zero,
              bottomLeft:
                  !top && left ? const Radius.circular(6) : Radius.zero,
              bottomRight:
                  !top && !left ? const Radius.circular(6) : Radius.zero,
            ),
          ),
        ),
      ),
    );
  }
}
