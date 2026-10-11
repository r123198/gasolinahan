import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_empty_state.dart';
import '../components/app_logo.dart';
import '../components/app_primary_button.dart';
import '../components/insights_card.dart';
import '../components/tracker_summary_card.dart';
import '../components/fill_up_log_card.dart';
import '../models/fill_up_model.dart';
import '../models/station_summary.dart';
import '../ui/adaptive/app_dialog.dart';
import '../ui/adaptive/app_toast.dart';
import '../ui/adaptive/app_spinner.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import '../ui/adaptive/app_page_route.dart';
import 'analytics_view.dart';
import 'fill_up_form_sheet.dart';
import 'station_history_sheet.dart';
import '../ui/app_theme.dart';

/// Tracker tab: spend totals, fuel insights and the fill-up log, newest
/// first.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _onAction(
    BuildContext context,
    FillUpViewModel vm,
    FillUp fillUp,
    FillUpAction action,
  ) async {
    switch (action) {
      case FillUpAction.edit:
        await showFillUpForm(context, editing: fillUp);
      case FillUpAction.delete:
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: 'Delete this fill-up?',
          message:
              'It will be removed from your totals, along with its photos.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (!confirmed) return;
        await vm.remove(fillUp);
        final error = vm.errorMessage;
        if (error != null && context.mounted) showAppToast(context, error);
    }
  }

  void _openStation(BuildContext context, FillUpViewModel vm, FillUp fillUp) {
    final key = StationSummary.keyOf(fillUp);
    final summary = vm.summaries.where((s) => s.key == key).firstOrNull;
    if (summary != null) showStationHistory(context, summary);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FillUpViewModel>(
      builder: (context, vm, _) {
        final entries = vm.log.entries;
        return RefreshIndicator(
          onRefresh: vm.load,
          color: AppColors.ink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(vm: vm)),
              if (vm.fillUps.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(child: InsightsCard()),
                ),
              if (vm.isLoading && entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppSpinner(strokeWidth: 2)),
                )
              else if (vm.errorMessage != null && entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            vm.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(
                            label: 'Try again',
                            onPressed: vm.load,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppEmptyState(
                      icon: Icons.local_gas_station_outlined,
                      title: 'No fill-ups yet',
                      subtitle:
                          'Log your first fill-up to start tracking what you spend and how far you go.',
                      actionLabel: 'Log a fill-up',
                      onAction: () => showFillUpForm(context),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  sliver: SliverList.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final fillUp = entries[i].fillUp;
                      return FillUpLogCard(
                        key: ValueKey(fillUp.id),
                        entry: entries[i],
                        onAction: (a) => _onAction(context, vm, fillUp, a),
                        onStationTap: () => _openStation(context, vm, fillUp),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final FillUpViewModel vm;
  const _Header({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(size: 32),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Gas Tracker',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => showFillUpForm(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Fill-up'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Where you filled up, what it cost, how far you went',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          if (vm.fillUps.isNotEmpty) ...[
            const SizedBox(height: 16),
            TrackerSummaryCard(
              log: vm.log,
              totals: vm.totals,
              now: DateTime.now(),
              onOpenAnalytics: () => Navigator.push(
                context,
                appRoute(context, (_) => const AnalyticsView()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
