import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/features/analytics/providers/analytics_provider.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/context_aware_provider.dart';

class ProductDetailContextPage extends StatelessWidget {
  const ProductDetailContextPage({super.key, this.item});

  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ContextAwareProvider>(
      create: (_) => ContextAwareProvider()..loadContext(),
      child: _ProductDetailContextView(item: item),
    );
  }
}

class _ProductDetailContextView extends StatelessWidget {
  const _ProductDetailContextView({required this.item});

  final InventoryItem? item;

  Future<void> _handleConsume(BuildContext context) async {
    final selectedItem = item;
    if (selectedItem == null) return;

    final inventory = context.read<InventoryProvider>();
    final analytics = context.read<AnalyticsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final ok = await inventory.consumeItem(selectedItem.id);
    if (!context.mounted) return;

    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(inventory.error ?? 'No se pudo marcar como consumido'),
        ),
      );
      return;
    }

    unawaited(analytics.loadMonthlySavings());

    messenger.showSnackBar(
      const SnackBar(content: Text('Item marcado como consumido')),
    );
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ContextAwareProvider provider = context.watch<ContextAwareProvider>();
    final InventoryItem? selectedItem = item;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(
                onRefreshTap: () =>
                    context.read<ContextAwareProvider>().loadContext(),
              ),
              const SizedBox(height: 18),
              _ProductCard(item: selectedItem),
              const SizedBox(height: 18),
              _AlertBanner(text: provider.recommendation.alertText),
              const SizedBox(height: 18),
              _FreshnessCard(provider: provider, item: selectedItem),
              const SizedBox(height: 22),
              _TipsSection(tips: provider.recommendation.tips),
              const SizedBox(height: 26),
              _PrimaryButton(
                text: 'Ver recetas sugeridas',
                icon: Icons.restaurant,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              _SecondaryButton(
                text: 'Marcar como consumido',
                icon: Icons.check_circle,
                onTap: () => _handleConsume(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _BottomBar(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefreshTap});

  final Future<void> Function() onRefreshTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _RoundHeaderButton(
          icon: Icons.arrow_back,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Detalle del Producto',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        _RoundHeaderButton(
          icon: Icons.refresh,
          onTap: () {
            onRefreshTap();
          },
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});

  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final String productName = item?.name ?? 'Producto';
    final String productEmoji = item?.category.emoji ?? '📦';
    final String quantityText = _buildQuantityText(item);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(42),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 188,
            height: 188,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(productEmoji, style: const TextStyle(fontSize: 92)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            productName,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            quantityText,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: AppColors.primary500,
            ),
          ),
        ],
      ),
    );
  }

  static String _buildQuantityText(InventoryItem? item) {
    if (item == null) {
      return 'Sin cantidad';
    }

    final String quantity = item.quantity % 1 == 0
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(1);
    final String unit = (item.unit == null || item.unit!.trim().isEmpty)
        ? 'unidades'
        : item.unit!.trim();
    return '$quantity $unit';
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8DD8A),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFCFBE53), width: 2),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Color(0xFF905000),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF663A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshnessCard extends StatelessWidget {
  const _FreshnessCard({required this.provider, required this.item});

  final ContextAwareProvider provider;
  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final String date = item == null
        ? _formatDateSpanish(DateTime.now())
        : 'Vence el ${_formatDateSpanish(item!.expiryDate)}';
    final String weatherLabel = _buildWeatherLabel(provider);
    final String storageLabel = provider.recommendation.storageLabel;
    final double freshnessValue = _buildFreshnessValue(item);
    final String expiryText = _buildExpiryLabel(item?.daysRemaining);
    final Color expiryColor = _buildExpiryColor(item?.daysRemaining);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Frescura actual',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4E8D6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFAFCFB2)),
                ),
                child: Text(
                  '📍 $storageLabel',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(
              fontSize: 22,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: freshnessValue,
              minHeight: 18,
              backgroundColor: Colors.white,
              color: AppColors.primary200,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: expiryColor,
                  ),
                ),
              ),
              Text(
                weatherLabel,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            provider.statusMessage,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _buildWeatherLabel(ContextAwareProvider provider) {
    if (provider.weather == null) {
      return 'Consumo sugerido';
    }

    final String cacheLabel = provider.isStale
        ? ' · desactualizado'
        : provider.fromCache
        ? ' · caché'
        : '';
    final int roundedTemp = provider.weather!.temperatureCelsius.round();
    return '$roundedTemp°C · ${provider.weather!.humidity}%$cacheLabel';
  }

  static double _buildFreshnessValue(InventoryItem? item) {
    if (item == null) {
      return 0.34;
    }

    if (item.daysRemaining <= 0) {
      return 0.05;
    }

    return (item.daysRemaining / 30).clamp(0.05, 1.0);
  }

  static String _buildExpiryLabel(int? daysRemaining) {
    if (daysRemaining == null) {
      return 'Vence pronto';
    }

    if (daysRemaining < 0) {
      final int days = daysRemaining.abs();
      return days == 1 ? 'Vencido hace 1 día' : 'Vencido hace $days días';
    }

    if (daysRemaining == 0) {
      return 'Vence hoy';
    }

    if (daysRemaining == 1) {
      return 'Vence en 1 día';
    }

    return 'Vence en $daysRemaining días';
  }

  static Color _buildExpiryColor(int? daysRemaining) {
    if (daysRemaining == null) {
      return const Color(0xFFBD1D1D);
    }

    if (daysRemaining <= 0) {
      return AppColors.error;
    }

    if (daysRemaining <= 3) {
      return const Color(0xFFBD1D1D);
    }

    return AppColors.primary;
  }

  static String _formatDateSpanish(DateTime date) {
    const List<String> months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}

class _TipsSection extends StatelessWidget {
  const _TipsSection({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.lightbulb, color: AppColors.primary500, size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tips de conservación',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final String tip in tips)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.circle,
                    size: 8,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 30),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(38),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 76,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.textSecondary, size: 30),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gray50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(38),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray50,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AppColors.textSecondary, size: 28),
        ),
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar();

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  int selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: (int value) {
        setState(() {
          selectedIndex = value;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary500,
      unselectedItemColor: AppColors.gray400,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w600,
      ),
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2),
          label: 'Despensa',
        ),
        BottomNavigationBarItem(
          icon: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary500,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 34),
          ),
          label: '',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.restaurant),
          label: 'Recetas',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
