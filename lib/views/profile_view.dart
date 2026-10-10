import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../components/app_list_tile.dart';
import '../components/app_section_header.dart';
import '../components/app_stat_card.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_page_route.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/app_format.dart';
import '../ui/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'account_sheets.dart';
import 'notifications_settings_view.dart';
import 'plus_view.dart';
import 'privacy_view.dart';
import 'report_history_sheet.dart';

const _recentReportLimit = 3;

/// Account tab: who you are, what you've contributed, and account settings.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final FirebaseService _firebase = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  List<ReportModel> _recentReports = [];
  bool _isLoadingReports = true;
  String? _reportsError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return;
    setState(() {
      _isLoadingReports = true;
      _reportsError = null;
    });
    try {
      await auth.refreshUser();
      final reports = await _firebase.getUserReports(
        user.id,
        limit: _recentReportLimit,
      );
      if (!mounted) return;
      setState(() => _recentReports = reports);
    } on Exception catch (e) {
      debugPrint('Profile load failed: $e');
      if (!mounted) return;
      setState(() => _reportsError = "Couldn't load your reports.");
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _pickProfileImage() async {
    final source = await showAppActionSheet<ImageSource>(
      context: context,
      title: 'Profile photo',
      actions: const [
        AppSheetAction(
          label: 'Take a photo',
          value: ImageSource.camera,
          icon: Icons.photo_camera_outlined,
        ),
        AppSheetAction(
          label: 'Choose from gallery',
          value: ImageSource.gallery,
          icon: Icons.photo_library_outlined,
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
    if (picked == null || !mounted) return;
    final auth = context.read<AuthViewModel>();
    await auth.updateProfileImage(picked.path);
    if (!mounted) return;
    final error = auth.errorMessage;
    showAppToast(context, error ?? 'Profile photo updated');
    auth.clearError();
  }

  Future<void> _logOut() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Log out?',
      message: "You'll need your email and password to sign back in.",
      confirmLabel: 'Log out',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthViewModel>().signOut();
    if (!mounted) return;
    // Clear the whole stack so Back can't return to signed-in screens.
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _push(Widget page) =>
      Navigator.push(context, appRoute(context, (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.ink,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          _ProfileCard(user: user, onEditPhoto: _pickProfileImage),
          const SizedBox(height: 12),
          _StatsRow(user: user),
          const SizedBox(height: 28),
          AppSectionHeader(
            title: 'Recent reports',
            actionLabel: _recentReports.isEmpty ? null : 'See all',
            onAction: () => showReportHistorySheet(context),
          ),
          const SizedBox(height: 8),
          _Card(child: _buildRecentReports()),
          const SizedBox(height: 28),
          const AppSectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: [
                AppListTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  subtitle: user?.name,
                  onTap: () => showEditNameSheet(context),
                ),
                AppListTile(
                  icon: Icons.mail_outline,
                  title: 'Email',
                  subtitle: user?.email,
                  trailing: const SizedBox.shrink(),
                ),
                AppListTile(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  onTap: () => showChangePasswordSheet(context),
                ),
                AppListTile(
                  icon: Icons.photo_camera_outlined,
                  title: 'Profile photo',
                  onTap: _pickProfileImage,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const AppSectionHeader(title: 'Settings'),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              children: [
                AppListTile(
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  onTap: () => _push(const NotificationsSettingsView()),
                ),
                AppListTile(
                  icon: Icons.shield_outlined,
                  title: 'Privacy & security',
                  onTap: () => _push(const PrivacyView()),
                ),
                AppListTile(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Gasolinahan Plus',
                  subtitle: user?.subscriptionTier,
                  onTap: () => _push(const PlusView()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _Card(
            child: AppListTile(
              icon: Icons.logout,
              title: 'Log out',
              isDestructive: true,
              onTap: _logOut,
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Gasolinahan v1.0.0',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    if (_isLoadingReports && _recentReports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: AppSpinner(strokeWidth: 2)),
      );
    }
    if (_reportsError != null) {
      return AppListTile(
        icon: Icons.refresh,
        title: _reportsError!,
        subtitle: 'Tap to try again',
        onTap: _loadData,
      );
    }
    if (_recentReports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No reports yet. Snap a price board from the Prices tab to earn '
          'points.',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      children: [for (final r in _recentReports) ReportTile(report: r)],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onEditPhoto;

  const _ProfileCard({required this.user, required this.onEditPhoto});

  @override
  Widget build(BuildContext context) {
    final imageUrl = user?.profileImageUrl ?? '';
    final joinDate = user?.joinDate ?? '';
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Change profile photo',
              child: AppTappable(
                onTap: onEditPhoto,
                borderRadius: BorderRadius.circular(36),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.surfaceMuted,
                      foregroundImage: imageUrl.isEmpty
                          ? null
                          : NetworkImage(imageUrl),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Guest',
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (joinDate.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Member since $joinDate',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final UserModel? user;

  const _StatsRow({required this.user});

  static String _compact(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    final saved = user?.amountSaved ?? 0.0;
    return Row(
      children: [
        AppStatCard(value: _compact(user?.reportsCount ?? 0), label: 'Reports'),
        const SizedBox(width: 12),
        AppStatCard(value: _compact(user?.points ?? 0), label: 'Points'),
        const SizedBox(width: 12),
        AppStatCard(value: '₱${saved.toStringAsFixed(0)}', label: 'Saved'),
      ],
    );
  }
}

/// One submitted price report with the points it earned.
class ReportTile extends StatelessWidget {
  final ReportModel report;

  const ReportTile({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final id = report.stationId;
    final shortId = id.length > 8 ? '${id.substring(0, 8)}…' : id;
    return AppListTile(
      icon: Icons.local_gas_station_outlined,
      title: 'Station $shortId',
      subtitle:
          'Regular ${formatPhp(report.reportedRegularPrice)} · '
          '${formatRelativeTime(report.timestamp)}',
      trailing: Text(
        '+${report.pointsAwarded} pts',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.goStrong,
        ),
      ),
    );
  }
}
