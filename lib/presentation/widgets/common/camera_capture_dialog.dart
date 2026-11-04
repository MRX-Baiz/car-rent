import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

class CameraCaptureDialog extends StatefulWidget {
  const CameraCaptureDialog({super.key});

  @override
  State<CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<CameraCaptureDialog> {
  // Official camera plugin state
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = false;
  String? _error;

  // camera_macos plugin state
  CameraMacOSController? _macOSController;
  final GlobalKey _macOSCameraKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (!Platform.isMacOS) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = AppCopy.noCameraAvailable;
          _isInitializing = false;
        });
        return;
      }

      // Select first camera
      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = context.trError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _macOSController?.destroy();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (Platform.isMacOS) {
      if (_macOSController == null) return;
      try {
        final CameraMacOSFile? captured = await _macOSController!.takePicture();
        if (captured != null && captured.bytes != null) {
          final tempDir = Directory.systemTemp;
          final tmpFile = File(
              '${tempDir.path}/carrent_camera_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tmpFile.writeAsBytes(captured.bytes!);
          if (mounted) {
            Navigator.of(context).pop(tmpFile);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: AppText(context.trError(e))));
        }
      }
      return;
    }

    // Windows / other OS
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.isTakingPicture) {
      return;
    }
    try {
      final file = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(File(file.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(context.trError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canTakePicture = Platform.isMacOS
        ? _macOSController != null
        : _controller?.value.isInitialized == true;

    // A fixed 600x600 box is wider than most phone screens; bound it to the
    // viewport so the dialog fits on any device.
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: viewport.width < 600 ? viewport.width * 0.92 : 600,
        height: viewport.height < 700 ? viewport.height * 0.8 : 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  AppCopy.cameraCapture,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildCameraPreview(),
              ),
            ),
            const SizedBox(height: 16),
            if (canTakePicture)
              FilledButton.icon(
                onPressed: _takePicture,
                icon: const Icon(Icons.camera_alt),
                label: const AppText(AppCopy.takePhoto),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (Platform.isMacOS) {
      return CameraMacOSView(
        key: _macOSCameraKey,
        fit: BoxFit.cover,
        cameraMode: CameraMacOSMode.photo,
        isVideoMirrored: false,
        onCameraInizialized: (CameraMacOSController macOSController) {
          if (mounted) {
            setState(() {
              _macOSController = macOSController;
            });
          }
        },
      );
    }

    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: AppText(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: AppText(AppCopy.preparing));
    }
    return CameraPreview(_controller!);
  }
}
