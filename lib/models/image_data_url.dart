import 'dart:convert';
import 'dart:typed_data';

/// Profile photos travel inside the Firestore user document as a data URL,
/// since the project has no Storage bucket. Keep them small: this is the
/// most bytes a photo may take before encoding.
const maxInlineImageBytes = 400 * 1024;

const _prefix = 'data:';

bool isImageDataUrl(String url) => url.startsWith(_prefix);

/// Packs [bytes] as `data:<mime>;base64,...`. Throws [ArgumentError] when
/// the image is too big to live in a document.
String encodeImageDataUrl(Uint8List bytes, {String mimeType = 'image/jpeg'}) {
  if (bytes.length > maxInlineImageBytes) {
    throw ArgumentError.value(
      bytes.length,
      'bytes',
      'Image is larger than $maxInlineImageBytes bytes',
    );
  }
  return '$_prefix$mimeType;base64,${base64Encode(bytes)}';
}

/// The bytes inside a base64 data URL, or null if [url] isn't one.
Uint8List? decodeImageDataUrl(String url) {
  if (!isImageDataUrl(url)) return null;
  final comma = url.indexOf(',');
  if (comma < 0 || !url.substring(0, comma).endsWith(';base64')) return null;
  try {
    return base64Decode(url.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
