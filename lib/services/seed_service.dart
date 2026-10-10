import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeedService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> seed() async {
    final log = StringBuffer();

    try {
      log.writeln('--- Seeding Firestore ---');

      // 1. Create users
      log.writeln(await _seedUsers());

      // 2. Create stations
      log.writeln(await _seedStations());

      // 3. Create sample reports
      log.writeln(await _seedReports());

      log.writeln('--- Seeding complete ---');
    } catch (e) {
      log.writeln('ERROR: $e');
    } finally {
      // Sign out the last seeded user
      await _auth.signOut();
    }

    return log.toString();
  }

  Future<String> _seedUsers() async {
    final log = StringBuffer();
    final users = _getUserData();

    for (final userData in users) {
      try {
        // Create auth user
        final credential = await _auth.createUserWithEmailAndPassword(
          email: userData['email'] as String,
          password: userData['password'] as String,
        );

        final uid = credential.user!.uid;
        await credential.user!.updateDisplayName(userData['name'] as String);

        // Create Firestore user doc
        await _firestore.collection('users').doc(uid).set({
          'name': userData['name'],
          'email': userData['email'],
          'profileImageUrl': '',
          'joinDate': userData['joinDate'],
          'subscriptionTier': userData['subscriptionTier'],
          'reportsCount': userData['reportsCount'],
          'points': userData['points'],
          'amountSaved': userData['amountSaved'],
        });

        log.writeln('Created user: ${userData['email']} (uid: $uid)');

        // Sign out so we can create the next user
        await _auth.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          log.writeln('User already exists: ${userData['email']}');
          await _auth.signOut();
        } else {
          log.writeln('Auth error for ${userData['email']}: ${e.message}');
        }
      }
    }

    return log.toString();
  }

  Future<String> _seedStations() async {
    final log = StringBuffer();
    final stations = _getStationData();

    for (final station in stations) {
      final id = station.remove('_id') as String;
      try {
        await _firestore.collection('stations').doc(id).set(station);
        log.writeln('Created station: ${station['name']}');
      } catch (e) {
        log.writeln('Error creating station ${station['name']}: $e');
      }
    }

    return log.toString();
  }

  Future<String> _seedReports() async {
    final log = StringBuffer();
    final reports = _getReportData();

    for (final report in reports) {
      try {
        await _firestore.collection('reports').add(report);
        log.writeln('Created report for station: ${report['stationId']}');
      } catch (e) {
        log.writeln('Error creating report: $e');
      }
    }

    return log.toString();
  }

  // ── Seed Data ─────────────────────────────────────────

  List<Map<String, dynamic>> _getUserData() {
    return [
      {
        'name': 'Maria Santos',
        'email': 'maria@gasolinahan.com',
        'password': 'Test1234!',
        'joinDate': '2024',
        'subscriptionTier': 'GASOLINAHAN GOLD',
        'reportsCount': 87,
        'points': 4350,
        'amountSaved': 1250.0,
      },
      {
        'name': 'Juan Dela Cruz',
        'email': 'juan@gasolinahan.com',
        'password': 'Test1234!',
        'joinDate': '2025',
        'subscriptionTier': 'GASOLINAHAN FREE',
        'reportsCount': 23,
        'points': 1150,
        'amountSaved': 340.0,
      },
      {
        'name': 'Ana Reyes',
        'email': 'ana@gasolinahan.com',
        'password': 'Test1234!',
        'joinDate': '2025',
        'subscriptionTier': 'GASOLINAHAN GOLD',
        'reportsCount': 156,
        'points': 7800,
        'amountSaved': 2100.0,
      },
      {
        'name': 'Carlos Garcia',
        'email': 'carlos@gasolinahan.com',
        'password': 'Test1234!',
        'joinDate': '2026',
        'subscriptionTier': 'GASOLINAHAN FREE',
        'reportsCount': 5,
        'points': 250,
        'amountSaved': 75.0,
      },
      {
        'name': 'Test User',
        'email': 'test@gasolinahan.com',
        'password': 'Test1234!',
        'joinDate': '2026',
        'subscriptionTier': 'GASOLINAHAN FREE',
        'reportsCount': 0,
        'points': 0,
        'amountSaved': 0.0,
      },
    ];
  }

  List<Map<String, dynamic>> _getStationData() {
    final now = DateTime.now();
    return [
      // ── Metro Manila Stations ──
      {
        '_id': 'shell_edsa_guadalupe',
        'name': 'Shell EDSA Guadalupe',
        'brand': 'Shell',
        'address': 'EDSA cor. JP Rizal St, Guadalupe, Makati',
        'latitude': 14.5648,
        'longitude': 121.0453,
        'regularPrice': 64.90,
        'premiumPrice': 72.50,
        'dieselPrice': 57.85,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 1)),
        ),
      },
      {
        '_id': 'petron_c5_taguig',
        'name': 'Petron C5 Taguig',
        'brand': 'Petron',
        'address': 'C5 Road, Taguig City',
        'latitude': 14.5176,
        'longitude': 121.0509,
        'regularPrice': 64.45,
        'premiumPrice': 72.10,
        'dieselPrice': 57.50,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 3)),
        ),
      },
      {
        '_id': 'caltex_ortigas',
        'name': 'Caltex Ortigas Ave',
        'brand': 'Caltex',
        'address': 'Ortigas Ave cor. EDSA, Mandaluyong',
        'latitude': 14.5870,
        'longitude': 121.0561,
        'regularPrice': 65.10,
        'premiumPrice': 73.00,
        'dieselPrice': 58.20,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 5)),
        ),
      },
      {
        '_id': 'shell_commonwealth',
        'name': 'Shell Commonwealth',
        'brand': 'Shell',
        'address': 'Commonwealth Ave, Quezon City',
        'latitude': 14.6760,
        'longitude': 121.0770,
        'regularPrice': 64.85,
        'premiumPrice': 72.45,
        'dieselPrice': 57.80,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 2)),
        ),
      },
      {
        '_id': 'seaoil_katipunan',
        'name': 'Seaoil Katipunan',
        'brand': 'Seaoil',
        'address': 'Katipunan Ave, Quezon City',
        'latitude': 14.6308,
        'longitude': 121.0745,
        'regularPrice': 62.50,
        'premiumPrice': 70.30,
        'dieselPrice': 56.15,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 6)),
        ),
      },
      {
        '_id': 'unioil_bgc',
        'name': 'Unioil BGC',
        'brand': 'Unioil',
        'address': '26th St, Bonifacio Global City, Taguig',
        'latitude': 14.5505,
        'longitude': 121.0494,
        'regularPrice': 63.20,
        'premiumPrice': 71.00,
        'dieselPrice': 56.80,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 4)),
        ),
      },
      {
        '_id': 'petron_espana',
        'name': 'Petron Espana',
        'brand': 'Petron',
        'address': 'Espana Blvd, Sampaloc, Manila',
        'latitude': 14.6042,
        'longitude': 120.9900,
        'regularPrice': 64.60,
        'premiumPrice': 72.25,
        'dieselPrice': 57.65,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 8)),
        ),
      },
      {
        '_id': 'shell_slex_sucat',
        'name': 'Shell SLEX Sucat',
        'brand': 'Shell',
        'address': 'Dr. A. Santos Ave, Sucat, Paranaque',
        'latitude': 14.4791,
        'longitude': 121.0331,
        'regularPrice': 64.95,
        'premiumPrice': 72.55,
        'dieselPrice': 57.90,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 30)),
        ),
      },
      {
        '_id': 'caltex_makati_ave',
        'name': 'Caltex Makati Ave',
        'brand': 'Caltex',
        'address': 'Makati Ave, Makati City',
        'latitude': 14.5547,
        'longitude': 121.0244,
        'regularPrice': 65.25,
        'premiumPrice': 73.15,
        'dieselPrice': 58.35,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(days: 1)),
        ),
      },
      {
        '_id': 'seaoil_marcos_highway',
        'name': 'Seaoil Marcos Highway',
        'brand': 'Seaoil',
        'address': 'Marcos Highway, Cainta, Rizal',
        'latitude': 14.5894,
        'longitude': 121.1125,
        'regularPrice': 62.30,
        'premiumPrice': 70.10,
        'dieselPrice': 55.95,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(days: 1, hours: 3)),
        ),
      },
      {
        '_id': 'petron_nlex_valenzuela',
        'name': 'Petron NLEX Valenzuela',
        'brand': 'Petron',
        'address': 'NLEX, Karuhatan, Valenzuela City',
        'latitude': 14.6930,
        'longitude': 120.9690,
        'regularPrice': 64.50,
        'premiumPrice': 72.15,
        'dieselPrice': 57.55,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(days: 2)),
        ),
      },
      {
        '_id': 'shell_alabang_zapote',
        'name': 'Shell Alabang-Zapote',
        'brand': 'Shell',
        'address': 'Alabang-Zapote Rd, Las Pinas',
        'latitude': 14.4353,
        'longitude': 121.0072,
        'regularPrice': 64.90,
        'premiumPrice': 72.50,
        'dieselPrice': 57.85,
        'lastUpdated': Timestamp.fromDate(
          now.subtract(const Duration(hours: 12)),
        ),
      },
    ];
  }

  List<Map<String, dynamic>> _getReportData() {
    final now = DateTime.now();
    return [
      {
        'userId': 'seed_maria',
        'stationId': 'shell_edsa_guadalupe',
        'reportedRegularPrice': 64.90,
        'reportedPremiumPrice': 72.50,
        'reportedDieselPrice': 57.85,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'pointsAwarded': 50,
        'status': 'approved',
      },
      {
        'userId': 'seed_juan',
        'stationId': 'petron_c5_taguig',
        'reportedRegularPrice': 64.45,
        'reportedPremiumPrice': 72.10,
        'reportedDieselPrice': 57.50,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'pointsAwarded': 50,
        'status': 'approved',
      },
      {
        'userId': 'seed_ana',
        'stationId': 'caltex_ortigas',
        'reportedRegularPrice': 65.10,
        'reportedPremiumPrice': 73.00,
        'reportedDieselPrice': 58.20,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 5))),
        'pointsAwarded': 50,
        'status': 'approved',
      },
      {
        'userId': 'seed_maria',
        'stationId': 'seaoil_katipunan',
        'reportedRegularPrice': 62.50,
        'reportedPremiumPrice': 70.30,
        'reportedDieselPrice': 56.15,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 6))),
        'pointsAwarded': 50,
        'status': 'approved',
      },
      {
        'userId': 'seed_carlos',
        'stationId': 'shell_slex_sucat',
        'reportedRegularPrice': 64.95,
        'reportedPremiumPrice': 72.55,
        'reportedDieselPrice': 57.90,
        'timestamp': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 30)),
        ),
        'pointsAwarded': 50,
        'status': 'pending',
      },
      {
        'userId': 'seed_ana',
        'stationId': 'unioil_bgc',
        'reportedRegularPrice': 63.20,
        'reportedPremiumPrice': 71.00,
        'reportedDieselPrice': 56.80,
        'timestamp': Timestamp.fromDate(now.subtract(const Duration(hours: 4))),
        'pointsAwarded': 50,
        'status': 'approved',
      },
    ];
  }
}
