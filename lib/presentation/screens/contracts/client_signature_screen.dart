import 'package:car_rent_manager/core/localization/app_localizations.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:car_rent_manager/presentation/widgets/common/app_text.dart';

class ClientSignatureScreen extends StatefulWidget {
  const ClientSignatureScreen({super.key, required this.clientName});
  final String clientName;

  @override
  State<ClientSignatureScreen> createState() => _ClientSignatureScreenState();
}

class _ClientSignatureScreenState extends State<ClientSignatureScreen> {
  final List<List<Offset>> _strokes = [];
  bool _exporting = false;

  bool get _hasSignature => _strokes.any((stroke) {
        var length = 0.0;
        for (var i = 1; i < stroke.length; i++) {
          length += (stroke[i] - stroke[i - 1]).distance;
        }
        return length > 0.08;
      });

  Future<void> _confirm() async {
    if (!_hasSignature || _exporting) return;
    setState(() => _exporting = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1000, 400);
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
      SignaturePainter(_strokes).paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1000, 400);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError(AppCopy.signatureIsEmpty);
      if (mounted) {
        Navigator.of(context).pop<Uint8List>(data.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText(AppCopy.unableToSaveTryAgain)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText(AppCopy.clientSignature)),
        body: SafeArea(
            child: SingleChildScrollView(
                child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AppText(widget.clientName,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const AppText(AppCopy.signWithYourFingerInTheWhiteArea6872ef),
            const SizedBox(height: 20),
            AspectRatio(
                aspectRatio: 2.5,
                child: LayoutBuilder(builder: (context, box) {
                  Offset normalized(Offset position) => Offset(
                      (position.dx / box.maxWidth).clamp(0, 1),
                      (position.dy / box.maxHeight).clamp(0, 1));
                  return Semantics(
                      label: context.tr(AppCopy.signatureDrawingArea),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey)),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _exporting
                              ? null
                              : (details) => setState(() {
                                    _strokes.add(
                                        [normalized(details.localPosition)]);
                                  }),
                          onPanUpdate: _exporting
                              ? null
                              : (details) => setState(() {
                                    if (_strokes.isNotEmpty) {
                                      _strokes.last.add(
                                          normalized(details.localPosition));
                                    }
                                  }),
                          child: ClipRect(
                              child: CustomPaint(
                                  painter: SignaturePainter(_strokes))),
                        ),
                      ));
                })),
            TextButton.icon(
                onPressed: _exporting ? null : () => setState(_strokes.clear),
                icon: const Icon(Icons.clear),
                label: const AppText(AppCopy.clearAndStartAgain)),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _hasSignature && !_exporting ? _confirm : null,
                icon: const Icon(Icons.check),
                label: AppText(_exporting
                    ? 'Enregistrement…'
                    : AppCopy.confirmMySignature)),
          ]),
        ))),
      );
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width / 250
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
