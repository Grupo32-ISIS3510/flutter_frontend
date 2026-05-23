import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/config/format_helpers.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/analytics/providers/analytics_provider.dart';
import 'package:second_serving_frontend/features/analytics/screens/savings_detail_screen.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/auth/providers/auth_provider.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';
import 'package:second_serving_frontend/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:second_serving_frontend/features/shopping_list/screens/shopping_list_screen.dart';
import 'package:second_serving_frontend/features/analytics/services/feature_usage_telemetry_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _expiringDaysWindow = 30;

  ItemCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context
          .read<FeatureUsageTelemetryService>()
          .recordFeatureUse(FeatureIds.analytics);
      final analytics = context.read<AnalyticsProvider>();
      analytics.loadDashboard();
      analytics.loadMonthlySavings();
      context
          .read<InventoryProvider>()
          .loadExpiringItems(days: _expiringDaysWindow);
      context.read<RecipeProvider>().loadSuggestions(limit: 3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<AnalyticsProvider>();
    final inventory = context.watch<InventoryProvider>();
    final recipes = context.watch<RecipeProvider>();
    final now = DateTime.now();
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.fullName.split(' ').first ?? 'Usuario';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final analyticsP = context.read<AnalyticsProvider>();
            final inventoryP = context.read<InventoryProvider>();
            final recipeP = context.read<RecipeProvider>();
            await Future.wait([
              analyticsP.loadDashboard(),
              analyticsP.loadMonthlySavings(),
              inventoryP.loadExpiringItems(days: _expiringDaysWindow),
              recipeP.loadSuggestions(limit: 3),
            ]);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildHeader(context, userName, now),
              const SizedBox(height: 20),
              _buildStatsCard(analytics),
              const SizedBox(height: 16),
              const _ShoppingListShortcut(),
              const SizedBox(height: 24),
              _buildEatFirstSection(inventory.expiringItems, inventory.error),
              const SizedBox(height: 24),
              _buildTodayPlanSection(context, now, recipes.suggestions),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, DateTime now) {
    final dateStr = DateFormat("EEEE, d 'de' MMMM", 'es').format(now);
    final capitalDate = dateStr[0].toUpperCase() + dateStr.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hola, $name 👋',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          capitalDate,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(AnalyticsProvider analytics) {
    final saved = analytics.savings?.savedCop ?? 0;

    // Micro-optimización (PPoF #4 — overdraw):
    // Material con elevation usa shadows nativos del compositor (baratos)
    // en lugar de boxShadow con blur (saveLayer + blur en GPU, costoso).
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SavingsDetailScreen()),
          );
        },
        child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'AHORRADO ESTE MES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${FormatHelpers.currency(saved)} COP',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'CO₂ EVITADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1.2 kg CO₂',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  static const _filterCategories = <ItemCategory?>[
    null,
    ItemCategory.meat,
    ItemCategory.dairy,
    ItemCategory.vegetables,
    ItemCategory.fruits,
  ];

  static const _filterLabels = <ItemCategory?, String>{
    null: 'Todos',
    ItemCategory.meat: 'Carnes',
    ItemCategory.dairy: 'Lácteos',
    ItemCategory.vegetables: 'Verduras',
    ItemCategory.fruits: 'Frutas',
  };

  Widget _buildEatFirstSection(List<InventoryItem> expiringItems, String? error) {
    final filtered = _selectedCategory == null
        ? expiringItems
        : expiringItems
            .where((i) => i.category == _selectedCategory)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Comer Primero',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Text('🔥', style: TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filterCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = _filterCategories[i];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(_filterLabels[cat]!),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _selectedCategory = cat),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                ),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (error != null && expiringItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 36, color: Colors.red.shade400),
                const SizedBox(height: 8),
                Text(
                  'Error al cargar items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                ),
              ],
            ),
          )
        else if (expiringItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 40, color: AppColors.textLight),
                const SizedBox(height: 12),
                Text(
                  '¡Aún no tienes nada,\nregistra tus compras!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No hay items de esta categoría',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 150,
            // Capamos el carrusel a 10 cards para evitar materializar todas
            // las cards en memoria con inventarios grandes.
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(filtered.length, 10),
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _ExpiringItemCard(item: filtered[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayPlanSection(
      BuildContext context, DateTime now, List<RecipeSummary> suggestions) {
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final recipe = suggestions.isNotEmpty ? suggestions.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plan de hoy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final isToday = days[i].day == now.day &&
                days[i].month == now.month &&
                days[i].year == now.year;
            return Column(
              children: [
                Text(
                  dayLabels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${days[i].day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 16),
        if (recipe != null)
          // Micro-optimización (PPoF #4 — overdraw):
          // Material + elevation reemplaza el Container con boxShadow blur
          // para evitar un saveLayer adicional en el GPU.
          Material(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.prepTimeMinutes ?? '?'} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            ),
          )
        else
          // Micro-optimización (PPoF #4 — overdraw):
          // Material reemplaza el Container con BoxDecoration redundante.
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No hay plan para hoy',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpiringItemCard extends StatelessWidget {
  final InventoryItem item;

  const _ExpiringItemCard({required this.item});

  Color get _statusColor {
    if (item.daysRemaining <= 1) return AppColors.expired;
    if (item.daysRemaining <= 3) return AppColors.expiringSoon;
    return AppColors.fresh;
  }

  double get _progressValue {
    if (item.daysRemaining <= 0) return 0.0;
    return (item.daysRemaining / 7).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final expiryText = FormatHelpers.daysRemaining(item.daysRemaining);

    // Micro-optimización (PPoF #4 — overdraw):
    // Aislar cada card en su propio RepaintBoundary evita que repintar
    // un item del carrusel obligue al GPU a repintar los demás.
    // Combinado con Material + elevation (en lugar de boxShadow con blur)
    // reduce drásticamente el costo de paint en el frame.
    return RepaintBoundary(
      child: SizedBox(
        width: 120,
        child: Column(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          child: Text(
                            expiryText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _statusColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListShortcut extends StatelessWidget {
  const _ShoppingListShortcut();

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<ShoppingListProvider>().pendingCount;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_basket_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lista de compras',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending == 0
                          ? 'Sin pendientes — toca para revisar'
                          : '$pending pendiente${pending == 1 ? '' : 's'} por comprar',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pending',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
