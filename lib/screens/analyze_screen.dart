import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/currency.dart';
import '../models/guest.dart';
import '../models/vendor.dart';
import '../providers/budget_provider.dart';
import '../providers/checklist_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/wedding_provider.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final checklist = context.watch<ChecklistProvider>();
    final budget = context.watch<BudgetProvider>();
    final guests = context.watch<GuestProvider>();
    final vendors = context.watch<VendorProvider>();
    final currencyCode = context.watch<WeddingProvider>().activeWedding?.currencyCode ?? 'INR';
    final currency = NumberFormat.currency(
      symbol: Currency.byCode(currencyCode).symbol,
      decimalDigits: 0,
    );

    final checklistTotal = checklist.completedCount + checklist.pendingCount;
    final checklistProgress = checklistTotal == 0 ? 0.0 : checklist.completedCount / checklistTotal;

    final budgetOver = budget.totalActual > budget.totalEstimated && budget.totalEstimated > 0;
    final budgetProgress = budget.totalEstimated == 0
        ? (budget.totalActual > 0 ? 1.0 : 0.0)
        : (budget.totalActual / budget.totalEstimated).clamp(0.0, 1.0);

    final attending = guests.guests.where((g) => g.rsvpFor('Wedding') == RsvpStatus.attending);
    final declined = guests.guests.where((g) => g.rsvpFor('Wedding') == RsvpStatus.declined);
    final pending = guests.guests.where((g) => g.rsvpFor('Wedding') == RsvpStatus.pending);

    final vendorTotal = vendors.vendors.length;
    final vendorReserved = vendors.countForStatus(VendorStatus.reserved);
    final vendorPending = vendors.countForStatus(VendorStatus.pending);
    final vendorRejected = vendors.countForStatus(VendorStatus.rejected);

    return Scaffold(
      appBar: AppBar(title: const Text('Analyze')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Checklist'),
          _ProgressCard(
            title: '${checklist.completedCount} of $checklistTotal tasks done',
            progress: checklistProgress,
            color: Colors.teal,
            trailing: '${(checklistProgress * 100).round()}%',
          ),
          const SizedBox(height: 24),
          _SectionHeader('Budget'),
          _ProgressCard(
            title: budgetOver
                ? 'Over budget by ${currency.format(budget.totalActual - budget.totalEstimated)}'
                : '${currency.format(budget.totalActual)} spent of ${currency.format(budget.totalEstimated)}',
            progress: budgetProgress,
            color: budgetOver ? Colors.red : Colors.indigo,
            trailing: budget.totalEstimated == 0
                ? '—'
                : '${(budget.totalActual / budget.totalEstimated * 100).round()}%',
          ),
          if (budget.overduePayments.isNotEmpty) ...[
            const SizedBox(height: 8),
            _WarningBanner(
              text:
                  '${budget.overduePayments.length} payment${budget.overduePayments.length == 1 ? '' : 's'} overdue',
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader('Guests'),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Attending',
                  value: '${attending.fold(0, (sum, g) => sum + g.totalHeadcount)}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Pending',
                  value: '${pending.fold(0, (sum, g) => sum + g.totalHeadcount)}',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Declined',
                  value: '${declined.fold(0, (sum, g) => sum + g.totalHeadcount)}',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MiniStat(
            label: 'Invitations sent',
            value: '${guests.invitationsSentCount} / ${guests.totalCount}',
            color: Colors.blueGrey,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          _SectionHeader('Vendors'),
          if (vendorTotal == 0)
            const Text('No vendors added yet.')
          else ...[
            _StatusBar(
              segments: [
                _StatusSegment('Reserved', vendorReserved, Colors.green),
                _StatusSegment('Pending', vendorPending, Colors.orange),
                _StatusSegment('Rejected', vendorRejected, Colors.red),
              ],
              total: vendorTotal,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _LegendDot(label: 'Reserved ($vendorReserved)', color: Colors.green),
                _LegendDot(label: 'Pending ($vendorPending)', color: Colors.orange),
                _LegendDot(label: 'Rejected ($vendorRejected)', color: Colors.red),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double progress;
  final Color color;
  final String trailing;

  const _ProgressCard({
    required this.title,
    required this.progress,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text(trailing, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: fullWidth
          ? Row(
              children: [
                Text(value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: color)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
    );
  }
}

class _StatusSegment {
  final String label;
  final int count;
  final Color color;
  const _StatusSegment(this.label, this.count, this.color);
}

class _StatusBar extends StatelessWidget {
  final List<_StatusSegment> segments;
  final int total;

  const _StatusBar({required this.segments, required this.total});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final segment in segments.where((s) => s.count > 0))
              Expanded(
                flex: segment.count,
                child: Container(color: segment.color),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
