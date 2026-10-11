/// Philippine pump prices change once a week, effective 6:00 AM Tuesday.
const _changeHour = 6;

/// The most recent weekly price change at or before [now].
DateTime latestPriceChange(DateTime now) {
  var day = DateTime(now.year, now.month, now.day, _changeHour);
  while (day.weekday != DateTime.tuesday || day.isAfter(now)) {
    day = DateTime(day.year, day.month, day.day - 1, _changeHour);
  }
  return day;
}

/// True when a price reported at [reportedAt] predates this week's change,
/// so the station's board has probably been updated since.
bool pricesMayHaveChanged(DateTime reportedAt, DateTime now) =>
    reportedAt.isBefore(latestPriceChange(now));
