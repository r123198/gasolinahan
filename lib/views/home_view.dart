import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_empty_state.dart';
import '../components/app_primary_button.dart';
import '../components/insights_card.dart';
import '../components/station_tracker_card.dart';
import '../ui/adaptive/app_spinner.dart';
import '../ui/tracker_format.dart';
import '../viewmodels/fill_up_viewmodel.dart';
import 'fill_up_form_sheet.dart';
import 'station_history_sheet.dart';

/// Home tab: the user's gas tracker — one row card per station they have
/// filled up at, with spend and distance totals.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FillUpViewModel>(
      builder: (context, vm, _) {
        final summaries = vm.summaries;
        return RefreshIndicator(
          onRefresh: vm.load,
          color: const Color(0xFF111827),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(vm: vm)),
              if (vm.fillUps.isNotEmpty)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(child: InsightsCard()),
                ),
              if (vm.isLoading && summaries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: AppSpinner(strokeWidth: 2)),
                )
              else if (vm.errorMessage != null && summaries.isEmpty)
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
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppPrimaryButton(label: 'Try again', onPressed: vm.load),
                        ],
                      ),
                    ),
                  ),
                )
              else if (summaries.isEmpty)
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
                    itemCount: summaries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => StationTrackerCard(
                      summary: summaries[i],
                      onTap: () => showStationHistory(context, summaries[i]),
                    ),
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
    final totals = vm.totals;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gas Tracker',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => showFillUpForm(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Fill-up'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
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
              color: Color(0xFF64748B),
            ),
          ),
          if (totals.fillUps > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _Total(label: 'Spent', value: formatPesos(totals.totalSpent)),
                  _Total(label: 'Distance', value: formatKm(totals.totalKm)),
                  _Total(
                    label: 'Per km',
                    value: formatCostPerKm(totals.costPerKm),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String value;
  const _Total({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
