import 'package:flutter_test/flutter_test.dart';
import 'package:gasolinahan/models/points_rules.dart';

void main() {
  group('price reports', () {
    test('a standard photo report of 3 products earns 6', () {
      expect(pointsForReport(const ReportContext(productCount: 3)).points, 6);
    });

    test('product bonus is capped at 4 products', () {
      expect(pointsForReport(const ReportContext(productCount: 7)).points, 7);
    });

    test('first report after the Tuesday price change earns +4', () {
      final award = pointsForReport(
        const ReportContext(productCount: 4, isFirstAfterPriceChange: true),
      );
      expect(award.points, 11);
      expect(award.lines.map((l) => l.label), contains('First after Tuesday'));
    });

    test('a station new to the map earns +3', () {
      expect(
        pointsForReport(
          const ReportContext(productCount: 2, isNewStation: true),
        ).points,
        8,
      );
    });

    test('typing prices without a photo earns half', () {
      expect(
        pointsForReport(
          const ReportContext(productCount: 3, hasPhoto: false),
        ).points,
        3,
      );
    });

    test('streak and first-report bonuses are not halved', () {
      final award = pointsForReport(
        const ReportContext(
          productCount: 3,
          hasPhoto: false,
          streakWeeks: 2,
          isFirstReport: true,
        ),
      );
      expect(award.points, 3 + 2 + 5);
      expect(award.lines.map((l) => l.label), contains('3-week streak'));
    });

    test('confirming prices someone reported today earns 1', () {
      expect(
        pointsForReport(
          const ReportContext(productCount: 3, isConfirmation: true),
        ).points,
        1,
      );
    });

    test('nothing when not at the station', () {
      final award = pointsForReport(
        const ReportContext(productCount: 3, isAtStation: false),
      );
      expect(award.points, 0);
      expect(award.reason, 'Report from the station to earn points');
    });

    test('nothing for a second report of the same station today', () {
      expect(
        pointsForReport(
          const ReportContext(
            productCount: 3,
            alreadyRewardedStationToday: true,
          ),
        ).points,
        0,
      );
    });

    test('nothing past the daily report limit', () {
      expect(
        pointsForReport(
          const ReportContext(
            productCount: 3,
            rewardedReportsToday: maxRewardedReportsPerDay,
          ),
        ).points,
        0,
      );
    });

    test('prices far from the area median wait for review', () {
      final award = pointsForReport(
        const ReportContext(productCount: 3, isOutlier: true),
      );
      expect(award.points, 0);
      expect(award.isPending, isTrue);
    });
  });

  group('weekly streak', () {
    final now = DateTime(2026, 10, 14); // a Wednesday

    test('counts consecutive earlier weeks with a report', () {
      final reports = [
        DateTime(2026, 10, 6), // last week
        DateTime(2026, 9, 30), // two weeks ago
        DateTime(2026, 9, 21), // three weeks ago
      ];
      expect(streakWeeksBefore(reports, now), 3);
    });

    test('a missed week ends the streak', () {
      final reports = [DateTime(2026, 10, 6), DateTime(2026, 9, 22)];
      expect(streakWeeksBefore(reports, now), 1);
    });

    test('reports from this week do not count yet', () {
      expect(streakWeeksBefore([DateTime(2026, 10, 13)], now), 0);
    });

    test('the bonus is capped', () {
      expect(weeklyStreakBonus(12), maxWeeklyStreakBonus);
    });
  });

  group('fill-ups', () {
    test('a complete fill-up earns 2', () {
      expect(pointsForFillUp(const FillUpContext()).points, 2);
    });

    test('a fill-up missing details earns 1', () {
      expect(pointsForFillUp(const FillUpContext(isComplete: false)).points, 1);
    });

    test('the 4th fill-up of the month adds +3', () {
      final award = pointsForFillUp(const FillUpContext(fillUpsThisMonth: 3));
      expect(award.points, 5);
    });

    test('the very first fill-up adds a head start', () {
      expect(
        pointsForFillUp(const FillUpContext(isFirstFillUp: true)).points,
        4,
      );
    });

    test('only 2 fill-ups a day and 20 a month earn points', () {
      expect(pointsForFillUp(const FillUpContext(rewardedToday: 2)).points, 0);
      expect(
        pointsForFillUp(const FillUpContext(rewardedThisMonth: 20)).points,
        0,
      );
    });

    test('an odometer that goes backwards earns nothing', () {
      expect(
        pointsForFillUp(const FillUpContext(odometerConsistent: false)).points,
        0,
      );
    });
  });

  test('5% better km/L than last month earns +4', () {
    expect(
      efficiencyBonus(previousKmPerLiter: 10, kmPerLiter: 10.6, tanks: 3),
      4,
    );
    expect(
      efficiencyBonus(previousKmPerLiter: 10, kmPerLiter: 12, tanks: 2),
      0,
    );
  });

  group('tiers', () {
    test('lifetime points decide the tier', () {
      expect(tierFor(0), PointsTier.bronze);
      expect(tierFor(149), PointsTier.bronze);
      expect(tierFor(150), PointsTier.silver);
      expect(tierFor(750), PointsTier.gold);
      expect(tierFor(2500), PointsTier.platinum);
    });

    test('progress to the next tier', () {
      expect(pointsToNextTier(136), 14);
      expect(pointsToNextTier(3000), isNull);
    });
  });
}
