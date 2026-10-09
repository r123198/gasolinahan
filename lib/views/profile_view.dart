import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/firebase_service.dart';
import '../models/station_model.dart';
import '../models/report_model.dart';
import '../components/app_circle_button.dart';
import '../components/app_section_header.dart';
import '../components/app_stat_card.dart';
import '../components/app_list_tile.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_nav_bar.dart';
import '../ui/adaptive/app_page_route.dart';
import '../ui/adaptive/app_platform.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_text_button.dart';
import '../ui/adaptive/app_toast.dart';
import 'plus_view.dart';
import 'notifications_settings_view.dart';
import 'privacy_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final FirebaseService _firebase = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  List<String> _favoriteIds = [];
  List<StationModel> _favoriteStations = [];
  List<ReportModel> _recentReports = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return;

    await auth.refreshUser();

    final favIds = await _firebase.getFavoriteStationIds(user.id);
    final favStations = await _firebase.getStationsByIds(favIds);
    final reports = await _firebase.getUserReports(user.id, limit: 5);

    if (mounted) {
      setState(() {
        _favoriteIds = favIds;
        _favoriteStations = favStations;
        _recentReports = reports;
        _isLoadingData = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final source = await showAppActionSheet<ImageSource>(
      context: context,
      actions: const [
        AppSheetAction(
          label: 'Take a Photo',
          value: ImageSource.camera,
          icon: Icons.camera_alt_rounded,
        ),
        AppSheetAction(
          label: 'Choose from Gallery',
          value: ImageSource.gallery,
          icon: Icons.photo_library_rounded,
        ),
      ],
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    if (mounted) {
      await context.read<AuthViewModel>().updateProfileImage(picked.path);
    }
  }

  void _showSheet({required WidgetBuilder builder}) {
    if (isCupertino(context)) {
      showAppSheet(
        context: context,
        isScrollControlled: true,
        builder: builder,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: builder,
    );
  }

  void _showAddFavoriteModal() async {
    final stations = await _firebase.getNearbyStations();
    if (!mounted) return;

    final alreadyFav = Set<String>.from(_favoriteIds);
    final available = stations
        .where((s) => !alreadyFav.contains(s.id))
        .toList();

    if (available.isEmpty) {
      showAppToast(context, 'No more stations available to add.');
      return;
    }

    _showSheet(
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Add Favorite Station',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: available.length,
                itemBuilder: (ctx, i) {
                  final station = available[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: brandAccent(
                        station.brand,
                      ).withValues(alpha: 0.15),
                      child: Text(
                        station.brand.isNotEmpty
                            ? station.brand[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: brandAccent(station.brand),
                        ),
                      ),
                    ),
                    title: Text(
                      station.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      station.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      formatPhp(station.regularPrice),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () async {
                      final user = context.read<AuthViewModel>().currentUser;
                      if (user == null) return;
                      await _firebase.addFavoriteStation(user.id, station.id);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      _loadData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllFavorites() {
    if (_favoriteStations.isEmpty) {
      showAppToast(context, 'No favorite stations yet. Tap + to add some!');
      return;
    }

    _showSheet(
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Favorite Stations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _favoriteStations.length,
                itemBuilder: (ctx, i) {
                  final station = _favoriteStations[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: brandAccent(
                        station.brand,
                      ).withValues(alpha: 0.15),
                      child: Text(
                        station.brand.isNotEmpty
                            ? station.brand[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: brandAccent(station.brand),
                        ),
                      ),
                    ),
                    title: Text(
                      station.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      station.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: AppIconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () async {
                        final user = context.read<AuthViewModel>().currentUser;
                        if (user == null) return;
                        await _firebase.removeFavoriteStation(
                          user.id,
                          station.id,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        _loadData();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullHistory() {
    if (_recentReports.isEmpty) {
      showAppToast(context, 'No report history yet. Start reporting prices!');
      return;
    }

    _showSheet(
      builder: (ctx) => FutureBuilder<List<ReportModel>>(
        future: _firebase.getUserReports(
          context.read<AuthViewModel>().currentUser!.id,
          limit: 100,
        ),
        builder: (ctx, snap) {
          final reports = snap.data ?? _recentReports;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (ctx, scrollController) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Report History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: reports.length,
                    itemBuilder: (ctx, i) {
                      final r = reports[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF22C55E,
                          ).withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            color: Color(0xFF22C55E),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          'Station ${r.stationId.substring(0, r.stationId.length > 8 ? 8 : r.stationId.length)}...',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Regular: ${formatPhp(r.reportedRegularPrice)} '
                          '| ${formatRelativeTime(r.timestamp)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${r.pointsAwarded}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'pts',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: isCupertino(context)
          ? AppNavBar(
              title: 'GASOLINAHAN',
              leading: AppCircleButton(
                icon: Icons.arrow_back,
                iconSize: 20,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : AppBar(
              backgroundColor: const Color(0xFFF3F4F6).withValues(alpha: 0.95),
              elevation: 0,
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: AppCircleButton(
                  icon: Icons.arrow_back,
                  iconSize: 20,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: const Text(
                'GASOLINAHAN',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
      body: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
          if (_isLoadingData) {
            return const Center(child: AppSpinner());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
            child: Column(
              children: [
                _buildProfileHeader(authViewModel),
                const SizedBox(height: 32),
                _buildFavoritesSection(),
                const SizedBox(height: 32),
                _buildRecentActivitySection(),
                const SizedBox(height: 32),
                _buildSettingsSection(context, authViewModel),
                const SizedBox(height: 24),
                const Text(
                  'Gasolinahan v2.4.1 (204)',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(AuthViewModel authViewModel) {
    final user = authViewModel.currentUser;
    final userName = user?.name ?? 'User';
    final tier = user?.subscriptionTier ?? 'GASOLINAHAN FREE';
    final joinDate = user?.joinDate ?? '';
    final reports = user?.reportsCount ?? 0;
    final points = user?.points ?? 0;
    final saved = user?.amountSaved ?? 0.0;
    final imageUrl = user?.profileImageUrl ?? '';

    return Column(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                  image: imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          userName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tier,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (joinDate.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                'Joined $joinDate',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppStatCard(value: '$reports', label: 'REPORTS'),
            const SizedBox(width: 16),
            AppStatCard(
              value: points >= 1000
                  ? '${(points / 1000).toStringAsFixed(1)}k'
                  : '$points',
              label: 'POINTS',
            ),
            const SizedBox(width: 16),
            AppStatCard(value: '₱${saved.toStringAsFixed(0)}', label: 'SAVED'),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoritesSection() {
    return Column(
      children: [
        AppSectionHeader(
          title: 'Favorite Stations',
          actionLabel: 'VIEW ALL',
          onAction: _showAllFavorites,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              ..._favoriteStations.map(
                (station) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildFavoriteCard(station),
                ),
              ),
              GestureDetector(
                onTap: _showAddFavoriteModal,
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.black),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ADD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteCard(StationModel station) {
    final accent = brandAccent(station.brand);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    station.brand.isNotEmpty
                        ? station.brand[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const Icon(Icons.favorite, color: Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            station.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            station.address,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REGULAR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              Text(
                formatPhp(station.regularPrice),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (_recentReports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No reports yet. Start reporting prices to earn points!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                ..._recentReports.map(
                  (r) => AppListTile(
                    icon: Icons.local_gas_station,
                    title:
                        'Station ${r.stationId.substring(0, r.stationId.length > 8 ? 8 : r.stationId.length)}...',
                    subtitle:
                        'Regular: ${formatPhp(r.reportedRegularPrice)} | ${formatRelativeTime(r.timestamp)}',
                    trailing: _buildPointsTrailing('+${r.pointsAwarded}'),
                  ),
                ),
              const Divider(height: 1),
              AppTextButton(
                onPressed: _showFullHistory,
                child: const Text(
                  'VIEW FULL HISTORY',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsTrailing(String points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          points,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const Text('pts', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSettingsSection(
    BuildContext context,
    AuthViewModel authViewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Settings'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  appRoute(context, (_) => const PlusView()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GASOLINAHAN PLUS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Manage subscription',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AppListTile(
                icon: Icons.notifications,
                title: 'Notifications',
                onTap: () => Navigator.push(
                  context,
                  appRoute(context, (_) => const NotificationsSettingsView()),
                ),
              ),
              AppListTile(
                icon: Icons.security,
                title: 'Privacy & Security',
                onTap: () => Navigator.push(
                  context,
                  appRoute(context, (_) => const PrivacyView()),
                ),
              ),
              const SizedBox(height: 8),
              AppListTile(
                icon: Icons.logout,
                title: 'Log Out',
                isDestructive: true,
                onTap: () async {
                  await authViewModel.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
