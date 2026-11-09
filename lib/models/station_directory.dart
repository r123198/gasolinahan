import 'package:cloud_firestore/cloud_firestore.dart';

import 'station_model.dart';

/// Every station, compacted into ONE Firestore document so the map paints
/// with a single read (and one listener). Full details (hours, phone,
/// website) stay on `stations/{id}` and are fetched when a station is
/// opened.
///
/// Document shape:
/// ```
/// directory/stations
///   count: 316
///   updatedAt: <timestamp>
///   lastReportedStation: <stationId>   the entry the latest report changed
///   stations:
///     <stationId>:
///       n: name            b: brand ("" for independents)
///       c: city            a: address
///       la: lat            lo: lng
///       r/p/d: regular / premium / diesel price (only when reported)
///       pp: {product: price}      u: last report (timestamp or millis)
///       am: {rr, wr, cs, ap, atm, cw, oc, cc, h24} 1 = yes, 0 = no,
///           absent = not listed
///       rt: rating         rv: review count
///       st: status (only when not "operational")
///       ns: nearby convenience store name
/// ```
/// Price reports merge `stations.<id>.{r,p,d,pp,u}` into this document
/// (see `ReportWriter`), so prices stay current without re-importing. The
/// report also names its station in `lastReportedStation`, as Firestore rules
/// can only check an entry whose id they are given.
/// The import script in `tool/stations/` writes the same shape.
const directoryCollection = 'directory';
const directoryDocId = 'stations';

const _amenityKeys = {
  'rr': 'restroom',
  'wr': 'accessibleRestroom',
  'cs': 'convenienceStore',
  'ap': 'airPump',
  'atm': 'atm',
  'cw': 'carWash',
  'oc': 'oilChange',
  'cc': 'cardsAccepted',
  'h24': 'open24Hours',
};

Map<String, dynamic> encodeDirectoryEntry(StationModel s) {
  final amenities = s.amenities.toMap();
  return {
    'n': s.name,
    'b': s.brand,
    if (s.city.isNotEmpty) 'c': s.city,
    if (s.address.isNotEmpty) 'a': s.address,
    'la': s.latitude,
    'lo': s.longitude,
    if (s.regularPrice > 0) 'r': s.regularPrice,
    if (s.premiumPrice > 0) 'p': s.premiumPrice,
    if (s.dieselPrice > 0) 'd': s.dieselPrice,
    if (s.productPrices.isNotEmpty) 'pp': s.productPrices,
    if (s.lastUpdated != StationModel.epoch)
      'u': Timestamp.fromDate(s.lastUpdated),
    if (amenities.isNotEmpty)
      'am': {
        for (final MapEntry(:key, :value) in _amenityKeys.entries)
          if (amenities[value] case final flag?) key: flag ? 1 : 0,
      },
    'rt': ?s.rating,
    if (s.reviewCount > 0) 'rv': s.reviewCount,
    if (s.status != StationModel.operational) 'st': s.status,
    if (s.nearbyStore.isNotEmpty) 'ns': s.nearbyStore,
  };
}

StationModel decodeDirectoryEntry(String id, Map<String, dynamic> e) {
  double number(String key) => (e[key] is num) ? (e[key] as num).toDouble() : 0;
  final am = e['am'];
  return StationModel.fromMap({
    'name': e['n'],
    'brand': e['b'],
    'city': e['c'],
    'address': e['a'],
    'latitude': number('la'),
    'longitude': number('lo'),
    'regularPrice': number('r'),
    'premiumPrice': number('p'),
    'dieselPrice': number('d'),
    'productPrices': e['pp'],
    'lastUpdated': e['u'],
    if (am is Map)
      'amenities': {
        for (final MapEntry(:key, :value) in _amenityKeys.entries)
          if (am[key] is num) value: (am[key] as num) != 0,
      },
    'rating': e['rt'],
    'reviewCount': e['rv'],
    'status': e['st'],
    'nearbyStore': e['ns'],
  }, id);
}

/// The stations in a directory document's data, or none when the
/// document is missing or malformed.
List<StationModel> decodeDirectory(Map<String, dynamic>? data) {
  final entries = data?['stations'];
  if (entries is! Map) return const [];
  return [
    for (final MapEntry(:key, :value) in entries.entries)
      if (key is String && value is Map)
        decodeDirectoryEntry(key, Map<String, dynamic>.from(value)),
  ];
}

/// What a price report merges into the directory for one station: the
/// prices it carries plus, for a station not in the directory yet, where
/// and what it is. Shaped for `set(..., SetOptions(merge: true))`.
Map<String, dynamic> directoryPriceUpdate({
  required String stationId,
  required bool stationExists,
  double regularPrice = 0,
  double premiumPrice = 0,
  double dieselPrice = 0,
  Map<String, double> productPrices = const {},
  String name = '',
  String brand = '',
  double latitude = 0,
  double longitude = 0,
  required Object lastUpdated,
}) => {
  'lastReportedStation': stationId,
  'stations': {
    stationId: {
      if (regularPrice > 0) 'r': regularPrice,
      if (premiumPrice > 0) 'p': premiumPrice,
      if (dieselPrice > 0) 'd': dieselPrice,
      if (productPrices.isNotEmpty) 'pp': productPrices,
      'u': lastUpdated,
      if (!stationExists) ...{
        if (name.isNotEmpty) 'n': name,
        if (brand.isNotEmpty) 'b': brand,
        if (latitude != 0) 'la': latitude,
        if (longitude != 0) 'lo': longitude,
      },
    },
  },
};
