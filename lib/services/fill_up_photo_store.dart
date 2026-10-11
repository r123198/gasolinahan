import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps fill-up photos inside the app's documents folder, so they survive
/// the picker's temp files being cleared. Photos never leave the phone.
class FillUpPhotoStore {
  static const _folder = 'fill_up_photos';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies a picked image in and returns its permanent path.
  Future<String> keep(String pickedPath) async {
    final dir = await _dir();
    final name =
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(pickedPath)}';
    final copy = await File(pickedPath).copy(p.join(dir.path, name));
    return copy.path;
  }

  /// Deletes every stored photo, for when the account is deleted.
  Future<void> discardAll() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Deletes stored photos; missing files are ignored.
  Future<void> discard(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (e) {
        debugPrint('Could not delete photo $path: $e');
      }
    }
  }
}
