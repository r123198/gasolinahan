import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_empty_state.dart';
import '../models/report_model.dart';
import '../services/firebase_service.dart';
import '../ui/adaptive/app_sheet.dart';
import '../ui/adaptive/app_spinner.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'profile_view.dart';

const _historyLimit = 100;

/// Every price report the signed-in user has submitted, newest first.
Future<void> showReportHistorySheet(BuildContext context) {
  final userId = context.read<AuthViewModel>().currentUser?.id;
  if (userId == null) return Future.value();
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportHistory(userId: userId),
  );
}

class _ReportHistory extends StatefulWidget {
  final String userId;

  const _ReportHistory({required this.userId});

  @override
  State<_ReportHistory> createState() => _ReportHistoryState();
}

class _ReportHistoryState extends State<_ReportHistory> {
  late Future<List<ReportModel>> _reports = _load();

  Future<List<ReportModel>> _load() =>
      FirebaseService().getUserReports(widget.userId, limit: _historyLimit);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(
                  'Report history',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ReportModel>>(
              future: _reports,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppSpinner(strokeWidth: 2));
                }
                if (snap.hasError) {
                  return AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load your reports",
                    subtitle: 'Check your connection and try again.',
                    actionLabel: 'Try again',
                    onAction: () => setState(() => _reports = _load()),
                  );
                }
                final reports = snap.data ?? const [];
                if (reports.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No reports yet',
                    subtitle: 'Reports you submit will show up here.',
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: reports.length,
                  itemBuilder: (_, i) => ReportTile(report: reports[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
