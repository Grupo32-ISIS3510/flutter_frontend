import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/config/format_helpers.dart';
import 'package:second_serving_frontend/core/network/connectivity_provider.dart';
import 'package:second_serving_frontend/features/analytics/providers/savings_detail_provider.dart';

/// Pantalla de detalle de ahorro vs. desperdicio (BQ T2.4).
///
/// Se abre al tocar la tarjeta "Ahorrado este mes" del dashboard.
class SavingsDetailScreen extends StatefulWidget {
  const SavingsDetailScreen({super.key});

  @override
  State<SavingsDetailScreen> createState() => _SavingsDetailScreenState();
}

class _SavingsDetailScreenState extends State<SavingsDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavingsDetailProvider>().load(months: 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Detalle de ahorro',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isOnline) const _OfflineNotice(),
            Expanded(
              child: Consumer<SavingsDetailProvider>(
                builder: (context, provider, _) {
                  switch (provider.status) {
                    case SavingsDetailStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case SavingsDetailStatus.error:
                      return _ErrorView(
                        message: provider.errorMessage ??
                            'Ocurrió un error al cargar los datos.',
                        onRetry: () => provider.load(months: 3),
                      );
                    case SavingsDetailStatus.success:
                      return _SuccessView(provider: provider);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF424242),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Sin conexión — mostrando datos guardados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final SavingsDetailProvider provider;

  const _SuccessView({required this.provider});

  static const Color _lossOrange = Color(0xFFEE7B30);
  static const Color _lossRed = Color(0xFFD64C3F);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => provider.load(months: 3),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _buildThisMonthCard(),
          const SizedBox(height: 16),
          _buildTrendCard(),
          const SizedBox(height: 16),
          _buildCategoryCard(),
          const SizedBox(height: 16),
          _buildExplanationCard(),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _cardHeader({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildThisMonthCard() {
    final savings = provider.savings;
    final saved = savings?.savedCop ?? 0;
    final wasted = savings?.wastedCop ?? 0;

    return _card(
      child: Row(
        children: [
          Expanded(
            child: _metric(
              label: 'AHORRADO',
              value: FormatHelpers.currency(saved),
              color: AppColors.fresh,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          Expanded(
            child: _metric(
              label: 'PERDIDO',
              value: FormatHelpers.currency(wasted),
              color: _lossRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard() {
    final months = provider.wasteByMonth;
    final maxLoss = months
        .map((m) => m.valueLostCop)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            emoji: '📉',
            title: 'Valor perdido — últimos 3 meses',
            subtitle:
                'Cada barra es el total mensual de valor perdido por alimentos descartados.',
          ),
          if (months.isEmpty)
            const Text(
              'Aún no hay datos de desperdicio para este periodo.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < months.length; i++) ...[
              _barRow(
                label: _prettyMonth(months[i].month),
                value: months[i].valueLostCop,
                maxValue: maxLoss,
                barColor: _lossOrange,
              ),
              if (i < months.length - 1) const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    final categories = provider.topCategoriesByLoss(top: 3);
    final maxLoss = categories
        .map((c) => c.valueLostCop)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            emoji: '🥕',
            title: 'Categorías con mayor oportunidad',
            subtitle:
                'Top 3 categorías con mayor valor perdido acumulado en los últimos 3 meses. Reducir el waste en estas categorías es donde más impacto vas a ver.',
          ),
          if (categories.isEmpty)
            const Text(
              'Aún no hay desglose por categoría.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            for (var i = 0; i < categories.length; i++) ...[
              _barRow(
                label: categories[i].category,
                value: categories[i].valueLostCop,
                maxValue: maxLoss,
                barColor: _lossRed,
                leading: _rankBadge(i + 1),
              ),
              if (i < categories.length - 1) const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _rankBadge(int rank) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFEFE8D8),
        shape: BoxShape.circle,
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _barRow({
    required String label,
    required double value,
    required double maxValue,
    required Color barColor,
    Widget? leading,
  }) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              FormatHelpers.currency(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _lossRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 7,
          ),
        ),
      ],
    );

    if (leading == null) return textBlock;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(child: textBlock),
      ],
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cómo se calculan estos valores?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El backend agrega los eventos de consumo y descarte por mes y por '
            'categoría de alimento. El total mensual es la suma de los items '
            'descartados durante ese período.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _prettyMonth(String month) {
    // El backend suele enviar "YYYY-MM"; lo formateamos a "MMM yyyy" en es.
    try {
      final parts = month.split('-');
      if (parts.length >= 2) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        final label = DateFormat('MMM yyyy', 'es').format(date);
        return label[0].toUpperCase() + label.substring(1);
      }
    } catch (_) {}
    return month;
  }
}
