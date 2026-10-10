import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'odometer_parser.dart';

enum OdometerScanStatus { read, unreadable, cancelled, failed }

class OdometerScanResult {
  final OdometerScanStatus status;
  final double? km;
  const OdometerScanResult(this.status, [this.km]);
}

/// Photographs the dashboard and reads the odometer with on-device OCR.
class OdometerScanner {
  final ImagePicker _picker = ImagePicker();

  Future<OdometerScanResult> scan() async {
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
      );
      if (photo == null) {
        return const OdometerScanResult(OdometerScanStatus.cancelled);
      }
      final text = await recognizer.processImage(
        InputImage.fromFilePath(photo.path),
      );
      final lines = [
        for (final block in text.blocks)
          for (final line in block.lines) line.text,
      ];
      final km = parseOdometer(lines);
      return km == null
          ? const OdometerScanResult(OdometerScanStatus.unreadable)
          : OdometerScanResult(OdometerScanStatus.read, km);
    } on PlatformException {
      return const OdometerScanResult(OdometerScanStatus.failed);
    } finally {
      await recognizer.close();
    }
  }
}
