import 'package:flutter/widgets.dart';

import '../models/image_data_url.dart';

/// The image behind a profile photo URL: inline data (our own uploads) or
/// a web address (e.g. a Google account photo). Null when there is none.
ImageProvider? profileImageProvider(String url) {
  if (url.isEmpty) return null;
  final bytes = decodeImageDataUrl(url);
  if (bytes != null) return MemoryImage(bytes);
  if (isImageDataUrl(url)) return null; // malformed: show the placeholder
  return NetworkImage(url);
}
