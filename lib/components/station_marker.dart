import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/station_model.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import 'brand_logo.dart';

/// How a station's price sits against the cheapest one around.
enum PriceTier { cheapest, low, mid, high }

/// Within this of the cheapest price still reads as a good deal.
const lowTierMargin = 0.5;

/// Beyond this above the cheapest price reads as expensive.
const highTierMargin = 1.5;

/// [price] against the [cheapest] price on the map (both per liter).
PriceTier priceTierOf(double price, double cheapest) {
  final gap = price - cheapest;
  if (gap <= 0) return PriceTier.cheapest;
  if (gap <= lowTierMargin) return PriceTier.low;
  if (gap <= highTierMargin) return PriceTier.mid;
  return PriceTier.high;
}

const _pillWidth = 160.0;
const _pillHeight = 46.0;
const _cheapestTagHeight = 24.0;
const _discSize = 40.0;
const _pointerHeight = 8.0;

/// Marker box size for [Marker.width]/[Marker.height]; the box sits above
/// the point so the pointer's tip marks the station.
Size stationMarkerSize({required bool hasPrice, required bool isCheapest}) {
  if (!hasPrice) return const Size(_discSize, _discSize + _pointerHeight);
  return Size(
    _pillWidth,
    _pillHeight + _pointerHeight + (isCheapest ? _cheapestTagHeight : 0),
  );
}

/// A station on the map. With a reported price: a pill with the brand's
/// mark and the price, coloured by [tier] (ink for the cheapest, green
/// when close to it, white in the middle, amber when well above). Without
/// one: a small disc with the brand's mark, ringed in the brand's colour.
/// Closed stations are faded.
class StationMarker extends StatelessWidget {
  final StationModel station;
  final double price;
  final PriceTier? tier;
  final VoidCallback onTap;

  const StationMarker({
    super.key,
    required this.station,
    required this.price,
    required this.tier,
    required this.onTap,
  });

  bool get _hasPrice => price > 0 && tier != null;

  @override
  Widget build(BuildContext context) {
    final label = StringBuffer(station.displayName);
    if (_hasPrice) label.write(', ${formatPricePerLiter(price)}');
    if (tier == PriceTier.cheapest) label.write(', cheapest nearby');
    if (!station.isOpen) label.write(', closed');
    return Semantics(
      button: true,
      label: label.toString(),
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: station.isOpen ? 1 : 0.55,
        child: GestureDetector(
          onTap: onTap,
          child: _hasPrice ? _pricePill() : _brandDisc(),
        ),
      ),
    );
  }

  Widget _mark(double size) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: brandAccent(station.brand), width: 2),
    ),
    child: brandLogoWidget(station.brand, size - 10, stationName: station.name),
  );

  Widget _brandDisc() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x29000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _mark(_discSize),
        ),
        CustomPaint(
          size: const Size(12, _pointerHeight),
          painter: _TrianglePainter(
            color: Colors.white,
            borderColor: brandAccent(station.brand),
          ),
        ),
      ],
    );
  }

  Widget _pricePill() {
    final (fill, border, text) = switch (tier!) {
      PriceTier.cheapest => (AppColors.ink, AppColors.ink, Colors.white),
      PriceTier.low => (
        AppColors.goTint,
        AppColors.goStrong,
        AppColors.goStrong,
      ),
      PriceTier.mid => (Colors.white, AppColors.divider, AppColors.ink),
      PriceTier.high => (
        const Color(0xFFFEF3C7),
        AppColors.warning,
        AppColors.warning,
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (tier == PriceTier.cheapest)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.ink),
            ),
            child: const Text(
              'Cheapest',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        // scaleDown: a long price or a wide font shrinks the pill rather
        // than spilling past the marker box.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.fromLTRB(3, 3, 12, 3),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _mark(30),
                const SizedBox(width: 6),
                Text(
                  formatPricePerLiter(price),
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        CustomPaint(
          size: const Size(14, _pointerHeight),
          painter: _TrianglePainter(color: fill, borderColor: border),
        ),
      ],
    );
  }
}

/// Paints a small triangle pointer below the marker bubble.
class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) =>
      old.color != color || old.borderColor != borderColor;
}
