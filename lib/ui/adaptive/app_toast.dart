import 'dart:async';

import 'package:flutter/material.dart';

import 'app_platform.dart';

const _toastDuration = Duration(seconds: 3);
const _toastAnimation = Duration(milliseconds: 250);
const _toastDefaultColor = Color(0xFF111827);

OverlayEntry? _activeToast;

/// Shows a short message.
///
/// Android uses a floating [SnackBar]. iOS has no snackbar, so a banner
/// slides in from the top instead.
void showAppToast(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = _toastDuration,
}) {
  if (!isCupertino(context)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
    return;
  }

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeToast?.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastBanner(
      message: message,
      color: backgroundColor ?? _toastDefaultColor,
      duration: duration,
      onDismissed: () {
        if (_activeToast == entry) _activeToast = null;
        entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _ToastBanner extends StatefulWidget {
  final String message;
  final Color color;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastBanner({
    required this.message,
    required this.color,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner> {
  bool _visible = false;
  Timer? _hideTimer;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
    _hideTimer = Timer(widget.duration, _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _visible = false);
    _removeTimer = Timer(_toastAnimation, widget.onDismissed);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: IgnorePointer(
          child: AnimatedSlide(
            duration: _toastAnimation,
            curve: Curves.easeOutCubic,
            offset: _visible ? Offset.zero : const Offset(0, -1.5),
            child: AnimatedOpacity(
              duration: _toastAnimation,
              opacity: _visible ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Material(
                    color: widget.color,
                    elevation: 6,
                    shadowColor: const Color(0x33000000),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
