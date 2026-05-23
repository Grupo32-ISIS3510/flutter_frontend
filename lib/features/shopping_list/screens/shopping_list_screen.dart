import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';
import 'package:second_serving_frontend/features/recipes/services/recipe_service.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/shopping_list/models/shopping_item.dart';
import 'package:second_serving_frontend/features/shopping_list/providers/shopping_list_provider.dart';
import 'package:second_serving_frontend/features/shopping_list/services/shopping_suggestions_service.dart';
import 'package:second_serving_frontend/features/shopping_list/screens/add_shopping_item_sheet.dart';
import 'package:second_serving_frontend/features/analytics/services/feature_usage_telemetry_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context
          .read<FeatureUsageTelemetryService>()
          .recordFeatureUse(FeatureIds.shoppingList);
      final provider = context.read<ShoppingListProvider>();
      await provider.load();
      await _refreshSuggestions();
    });
  }

  Future<void> _refreshSuggestions() async {
    final shopping = context.read<ShoppingListProvider>();
    final inventory = context.read<InventoryProvider>();
    final recipes = context.read<RecipeProvider>();
    final recipeService = context.read<RecipeService>();

    if (inventory.items.isEmpty) {
      await inventory.loadItems();
    }
    if (recipes.suggestions.isEmpty) {
      await recipes.loadSuggestions(limit: 5);
    }

    final details = <RecipeDetail>[];
    for (final r in recipes.suggestions.take(3)) {
      try {
        final detail = await recipeService.getRecipeDetail(r.id);
        details.add(detail);
      } catch (_) {}
    }

    if (!mounted) return;
    shopping.refreshSuggestions(
      activeInventory: inventory.items,
      recentlyConsumed: const [],
      nearbyRecipes: details,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingListProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          if (provider.purchasedItems.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar comprados',
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () async {
                final ok = await _confirmClear(context);
                if (ok == true) {
                  await provider.clearPurchased();
                }
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        onPressed: () => showAddShoppingItemSheet(context),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.load();
          await _refreshSuggestions();
        },
        child: provider.isLoading && provider.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _SummaryHeader(provider: provider),
                  const SizedBox(height: 16),
                  if (provider.suggestions.isNotEmpty) ...[
                    _SuggestionsSection(suggestions: provider.suggestions),
                    const SizedBox(height: 20),
                  ],
                  _PendingSection(items: provider.pendingItems),
                  if (provider.purchasedItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _PurchasedSection(items: provider.purchasedItems),
                  ],
                  if (provider.items.isEmpty &&
                      provider.suggestions.isEmpty &&
                      !provider.isLoading)
                    const _EmptyState(),
                ],
              ),
      ),
    );
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar comprados'),
        content: const Text(
            '¿Quitar de la lista todos los items que ya marcaste como comprados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final ShoppingListProvider provider;
  const _SummaryHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final pending = provider.pendingCount;
    final total = provider.totalCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pending por comprar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$total items en total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  final List<ShoppingSuggestion> suggestions;
  const _SuggestionsSection({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShoppingListProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.lightbulb_outline, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              'Sugerencias para ti',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...suggestions.take(5).map(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textLight.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Text(s.category.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.reason,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.textLight),
                      onPressed: () => provider.dismissSuggestion(s),
                    ),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => provider.addFromSuggestion(s),
                        child: const Text('Agregar',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _PendingSection extends StatelessWidget {
  final List<ShoppingItem> items;
  const _PendingSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Por comprar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _ShoppingItemTile(item: item)),
      ],
    );
  }
}

class _PurchasedSection extends StatelessWidget {
  final List<ShoppingItem> items;
  const _PurchasedSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comprados (${items.length})',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _ShoppingItemTile(item: item)),
      ],
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  const _ShoppingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShoppingListProvider>();
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => provider.remove(item.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: GestureDetector(
            onTap: () => provider.togglePurchased(item.id),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.purchased ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: item.purchased
                      ? AppColors.primary
                      : AppColors.textLight,
                  width: 2,
                ),
              ),
              child: item.purchased
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: item.purchased
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: item.purchased
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${_formatQty(item.quantity)} ${item.unit ?? "unidades"} · ${item.category.label}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: Text(
            item.category.emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }

  String _formatQty(double q) {
    if (q == q.toInt()) return q.toInt().toString();
    return q.toStringAsFixed(1);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          const Text(
            'Tu lista está vacía',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca "Agregar" para empezar',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }
}
