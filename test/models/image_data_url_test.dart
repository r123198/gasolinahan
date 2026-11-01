import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/image_data_url.dart';
import 'package:gasolinahan/ui/profile_image.dart';

void main() {
  final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

  test('round-trips image bytes through a data URL', () {
    final url = encodeImageDataUrl(bytes);
    expect(url, startsWith('data:image/jpeg;base64,'));
    expect(isImageDataUrl(url), isTrue);
    expect(decodeImageDataUrl(url), bytes);
  });

  test('refuses an image too big for a Firestore document', () {
    final big = Uint8List(maxInlineImageBytes + 1);
    expect(() => encodeImageDataUrl(big), throwsArgumentError);
  });

  test('returns null for web addresses and broken data URLs', () {
    expect(decodeImageDataUrl('https://example.com/a.jpg'), isNull);
    expect(decodeImageDataUrl('data:image/jpeg;base64,***'), isNull);
    expect(decodeImageDataUrl('data:image/jpeg,plain'), isNull);
  });

  test('picks the image provider that matches the URL', () {
    expect(profileImageProvider(''), isNull);
    expect(profileImageProvider(encodeImageDataUrl(bytes)), isA<MemoryImage>());
    expect(
      profileImageProvider('https://example.com/a.jpg'),
      isA<NetworkImage>(),
    );
    expect(profileImageProvider('data:image/jpeg;base64,***'), isNull);
  });
}
