import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/app_theme.dart';

/// Small illustrations for the welcome tour, built from the app's own
/// pieces (price pills, stat numbers, brand bars) so the tour shows what
/// the app really looks like. Decorative: each page's text says it all.

const _tabular = [FontFeature.tabularFigures()];
const _shadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 6)),
];

Widget _mark(String brand, double size) =>
    BrandRegistry.findByName(brand)?.mark(size: size) ??
    Icon(Icons.local_gas_station, size: size, color: AppColors.textMuted);

/// Frame shared by every vignette: a soft card the illustration sits in.
class _Frame extends StatelessWidget {
  final Widget child;

  const _Frame({required this.child});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: double.infinity,
        height: 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(28),
        ),
        child: child,
      ),
    );
  }
}

/// Page 1: a quiet map with brand price pills, the cheapest inverted.
class MapVignette extends StatelessWidget {
  const MapVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _RoadsPainter())),
          const Align(
            alignment: Alignment(-0.7, -0.6),
            child: _PricePill(brand: 'Petron', price: '₱59.80/L'),
          ),
          const Align(
            alignment: Alignment(0.6, 0.1),
            child: _PricePill(
              brand: 'Shell',
              price: '₱58.40/L',
              isCheapest: true,
            ),
          ),
          const Align(
            alignment: Alignment(-0.4, 0.8),
            child: _PricePill(brand: 'Caltex', price: '₱60.15/L'),
          ),
        ],
      ),
    );
  }
}

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final minor = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 4;
    canvas
      ..drawLine(
        Offset(0, size.height * 0.35),
        Offset(size.width, size.height * 0.55),
        road,
      )
      ..drawLine(
        Offset(size.width * 0.3, 0),
        Offset(size.width * 0.45, size.height),
        road,
      )
      ..drawLine(
        Offset(size.width * 0.7, 0),
        Offset(size.width * 0.85, size.height),
        minor,
      )
      ..drawLine(
        Offset(0, size.height * 0.8),
        Offset(size.width, size.height * 0.75),
        minor,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PricePill extends StatelessWidget {
  final String brand;
  final String price;
  final bool isCheapest;

  const _PricePill({
    required this.brand,
    required this.price,
    this.isCheapest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCheapest)
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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: isCheapest ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _shadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _mark(brand, 18),
              ),
              const SizedBox(width: 6),
              Text(
                price,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCheapest ? Colors.white : AppColors.ink,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 2: a fill-up log card with its coloured numbers.
class FillUpVignette extends StatelessWidget {
  const FillUpVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(dimension: 28, child: _mark('Seaoil', 28)),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Seaoil Mayapa',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '₱755.47',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFeatures: _tabular,
                ),
              ),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '9.213 L',
                      style: TextStyle(
                        color: AppColors.fuel,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: ' at ₱82.00/L'),
                  ],
                ),
                style: TextStyle(fontSize: 13, fontFeatures: _tabular),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniStat(
                    label: 'Driven',
                    value: '+63 km',
                    color: AppColors.distance,
                  ),
                  _MiniStat(
                    label: 'Efficiency',
                    value: '6.84 km/L',
                    color: AppColors.good,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 3: brands ranked by km/L in your car.
class BrandsVignette extends StatelessWidget {
  const BrandsVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Frame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BrandBar(
            brand: 'Petron',
            value: '10.2 km/L',
            fraction: 1,
            isBest: true,
          ),
          SizedBox(height: 16),
          _BrandBar(brand: 'Shell', value: '9.1 km/L', fraction: 0.82),
          SizedBox(height: 16),
          _BrandBar(brand: 'Caltex', value: '8.4 km/L', fraction: 0.7),
        ],
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  final String brand;
  final String value;
  final double fraction;
  final bool isBest;

  const _BrandBar({
    required this.brand,
    required this.value,
    required this.fraction,
    this.isBest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: _mark(brand, 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      brand,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'Best',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.good,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: _tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  color: AppColors.distance,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 4: the Tuesday price-change nudge.
class TuesdayVignette extends StatelessWidget {
  const TuesdayVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return _Frame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Tuesday · 6:00 AM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.update, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Prices may have changed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: _shadow,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_camera_outlined, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Report new prices',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
