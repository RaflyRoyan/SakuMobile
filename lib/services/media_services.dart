import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Camera/gallery, on-device OCR, QR decoding and the share sheet.
/// Injected through `AppServices` so widget tests never touch plugins.
abstract class MediaServices {
  /// Path of the picked image, or null when cancelled.
  Future<String?> ambilGambar({required bool kamera});

  /// OCR text of a receipt photo, one visual line per text line, top to bottom.
  Future<String> bacaTeks(String path);

  /// Raw value of the first QR code in the image, or null.
  Future<String?> bacaQr(String path);

  Future<void> bagikanGambar(Uint8List png, {required String namaFile, required String teks});
}

class NoopMediaServices implements MediaServices {
  @override
  Future<String?> ambilGambar({required bool kamera}) async => null;
  @override
  Future<String> bacaTeks(String path) async => '';
  @override
  Future<String?> bacaQr(String path) async => null;
  @override
  Future<void> bagikanGambar(Uint8List png, {required String namaFile, required String teks}) async {}
}

class PluginMediaServices implements MediaServices {
  final _picker = ImagePicker();

  @override
  Future<String?> ambilGambar({required bool kamera}) async {
    final f = await _picker.pickImage(
      source: kamera ? ImageSource.camera : ImageSource.gallery,
      // Large enough for OCR of small receipt text, small enough to stay fast.
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 90,
    );
    return f?.path;
  }

  @override
  Future<String> bacaTeks(String path) async {
    final recognizer = TextRecognizer();
    try {
      final hasil = await recognizer.processImage(InputImage.fromFilePath(path));
      return susunBaris([
        for (final b in hasil.blocks)
          for (final l in b.lines) (teks: l.text, kotak: l.boundingBox),
      ]);
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<String?> bacaQr(String path) async {
    final scanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
    try {
      final codes = await scanner.processImage(InputImage.fromFilePath(path));
      for (final c in codes) {
        if (c.rawValue != null && c.rawValue!.isNotEmpty) return c.rawValue;
      }
      return null;
    } finally {
      await scanner.close();
    }
  }

  @override
  Future<void> bagikanGambar(Uint8List png, {required String namaFile, required String teks}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: namaFile)],
      fileNameOverrides: [namaFile],
      text: teks,
    ));
  }
}

/// ML Kit returns a receipt's left column (item names) and right column
/// (prices) as separate blocks. Joins lines whose vertical centres overlap
/// into one text line (left to right), then orders lines top to bottom, so
/// `parseStruk` sees "Bakmi Ayam   70.000" on one line.
String susunBaris(List<({String teks, Rect kotak})> potongan) {
  final sisa = [...potongan]..sort((a, b) => a.kotak.center.dy.compareTo(b.kotak.center.dy));
  final baris = <List<({String teks, Rect kotak})>>[];
  for (final p in sisa) {
    final h = p.kotak.height;
    final cocok = baris.where((b) {
      final ref = b.first.kotak;
      // Same row when centres are within half the smaller line height.
      final batas = (h < ref.height ? h : ref.height) * 0.5;
      return (ref.center.dy - p.kotak.center.dy).abs() <= batas;
    }).firstOrNull;
    if (cocok != null) {
      cocok.add(p);
    } else {
      baris.add([p]);
    }
  }
  return baris.map((b) {
    b.sort((x, y) => x.kotak.left.compareTo(y.kotak.left));
    return b.map((p) => p.teks).join('   ');
  }).join('\n');
}
