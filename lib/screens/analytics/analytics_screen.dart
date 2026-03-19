import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/config/app_theme.dart';
import 'package:second_serving_frontend/config/format_helpers.dart';
import 'package:second_serving_frontend/providers/analytics_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AnalyticsProvider>().loadDashboard();
      context.read<AnalyticsProvider>().loadWasteTrends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalyticsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Análisis')),
      body: provider.isLoading && provider.dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadDashboard();
                await provider.loadWasteTrends();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.savings != null) ...[
                    _SavingsCard(
                      saved: provider.savings!.savedCop,
                      wasted: provider.savings!.wastedCop,
                      period: provider.savings!.period,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (provider.wasteSummary != null) ...[
                    _SummaryCard(
                      consumed: provider.wasteSummary!.totalConsumed,
                      discarded: provider.wasteSummary!.totalDiscarded,
                      streak: provider.wasteSummary!.noWasteStreakDays,
                      mostWasted: provider.wasteSummary!.mostDiscardedItem,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (provider.segment != null)
                    _SegmentCard(
                      segment: provider.segment!.segment,
                      recipesCooked: provider.segment!.recipesCookedLast30Days,
                    ),
                ],
              ),
            ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final double saved;
  final double wasted;
  final String period;

  const _SavingsCard({
    required this.saved,
    required this.wasted,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final total = saved + wasted;
    final pct = total > 0 ? (saved / total * 100) : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ahorro del mes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: 'Ahorrado',
                    value: FormatHelpers.currency(saved),
                    color: AppColors.success,
                    icon: Icons.savings_outlined,
                  ),
                ),
                Container(width: 1, height: 50, color: AppColors.textLight),
                Expanded(
                  child: _StatColumn(
                    label: 'Desperdiciado',
                    value: FormatHelpers.currency(wasted),
                    color: AppColors.error,
                    icon: Icons.delete_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: AppColors.error.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${pct.toStringAsFixed(0)}% aprovechado',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int consumed;
  final int discarded;
  final int streak;
  final String? mostWasted;

  const _SummaryCard({
    required this.consumed,
    required this.discarded,
    required this.streak,
    this.mostWasted,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _SummaryRow(
                icon: Icons.check_circle,
                color: AppColors.success,
                label: 'Consumidos',
                value: '$consumed'),
            _SummaryRow(
                icon: Icons.cancel,
                color: AppColors.error,
                label: 'Descartados',
                value: '$discarded'),
            _SummaryRow(
                icon: Icons.local_fire_department,
                color: AppColors.secondary,
                label: 'Racha sin desperdiciar',
                value: '$streak días'),
            if (mostWasted != null)
              _SummaryRow(
                  icon: Icons.warning_amber,
                  color: AppColors.warning,
                  label: 'Más desperdiciado',
                  value: mostWasted!),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  final String segment;
  final int recipesCooked;

  const _SegmentCard({
    required this.segment,
    required this.recipesCooked,
  });

  String get _segmentLabel {
    switch (segment) {
      case 'proactive':
        return 'Proactivo';
      case 'passive':
        return 'Pasivo';
      default:
        return 'Neutral';
    }
  }

  Color get _segmentColor {
    switch (segment) {
      case 'proactive':
        return AppColors.success;
      case 'passive':
        return AppColors.error;
      default:
        return AppColors.secondary;
    }
  }

  IconData get _segmentIcon {
    switch (segment) {
      case 'proactive':
        return Icons.star;
      case 'passive':
        return Icons.bedtime;
      default:
        return Icons.balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _segmentColor.withValues(alpha: 0.15),
              child: Icon(_segmentIcon, color: _segmentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu perfil: $_segmentLabel',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: _segmentColor)),
                  const SizedBox(height: 4),
                  Text('$recipesCooked recetas cocinadas este mes',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
