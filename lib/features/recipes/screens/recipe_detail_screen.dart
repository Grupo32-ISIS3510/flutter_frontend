import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/features/favorites/models/favorite_recipe.dart';
import 'package:second_serving_frontend/features/favorites/providers/favorites_provider.dart';
import 'package:second_serving_frontend/features/recipes/config/recipe_images.dart';
import 'package:second_serving_frontend/features/recipes/models/recipe.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _isCooking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RecipeProvider>();
      provider.loadRecipeDetail(widget.recipeId);
      provider.markAsViewed(widget.recipeId);
      context.read<FavoritesProvider>().load();
    });
  }

  Future<void> _handleCook(RecipeDetail recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cocinar esta receta?'),
        content: const Text(
          'Los ingredientes que tengas en tu despensa se marcarán como consumidos automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cocinar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCooking = true);

    final recipeProvider = context.read<RecipeProvider>();
    final inventoryProvider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    await recipeProvider.markAsCooked(widget.recipeId);

    // Cargar inventario completo para asegurar que tengamos todos los items
    await inventoryProvider.loadItems(limit: 100);

    if (!mounted) return;

    // Cruzar ingredientes de la receta con items activos del inventario por nombre
    final ingredientNames = recipe.ingredients
        .map((i) => i.ingredientName.toLowerCase().trim())
        .toSet();

    final matchingItems = inventoryProvider.items
        .where((item) =>
            item.isActive &&
            ingredientNames.any((name) =>
                item.name.toLowerCase().trim().contains(name) ||
                name.contains(item.name.toLowerCase().trim())))
        .toList();

    for (final item in matchingItems) {
      await inventoryProvider.consumeItem(item.id);
    }

    if (mounted) {
      setState(() => _isCooking = false);
      final consumed = matchingItems.length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            consumed > 0
                ? '¡${recipe.name} cocinada! $consumed ingrediente${consumed == 1 ? '' : 's'} consumido${consumed == 1 ? '' : 's'}.'
                : '¡${recipe.name} cocinada! No se encontraron ingredientes en tu despensa.',
          ),
          backgroundColor: consumed > 0 ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeProvider>();
    final recipe = provider.selectedRecipe;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: provider.isLoading || recipe == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildImageHeader(recipe),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitle(recipe),
                        const SizedBox(height: 16),
                        _buildMetaRow(recipe),
                        const SizedBox(height: 24),
                        _buildIngredientsSection(recipe),
                        const SizedBox(height: 24),
                        _buildInstructionsSection(recipe),
                        const SizedBox(height: 32),
                        _buildCookButton(recipe),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildImageHeader(RecipeDetail recipe) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      actions: [_buildFavoriteToggle(recipe)],
      flexibleSpace: FlexibleSpaceBar(
        background: RecipeImages.buildImage(
          recipeName: recipe.name,
          category: recipe.category.value,
          height: 220,
        ),
      ),
    );
  }

  Widget _buildFavoriteToggle(RecipeDetail recipe) {
    final favorites = context.watch<FavoritesProvider>();
    final isFav = favorites.isFavorite(recipe.id);

    return GestureDetector(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final nowFav = await context
            .read<FavoritesProvider>()
            .toggle(FavoriteRecipe.fromDetail(recipe));
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              nowFav
                  ? '${recipe.name} guardada en favoritas'
                  : '${recipe.name} eliminada de favoritas',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? AppColors.secondary : Colors.white,
        ),
      ),
    );
  }

  Widget _buildTitle(RecipeDetail recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (recipe.description != null) ...[
          const SizedBox(height: 6),
          Text(
            recipe.description!,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(RecipeDetail recipe) {
    return Row(
      children: [
        _MetaChip(
          icon: Icons.timer_outlined,
          label: '${recipe.prepTimeMinutes ?? '?'} min',
        ),
        const SizedBox(width: 12),
        _MetaChip(
          icon: Icons.people_outlined,
          label: '${recipe.servings} porciones',
        ),
        const SizedBox(width: 12),
        _MetaChip(
          icon: Icons.check_circle_outline,
          label: '${recipe.inventoryMatches} en stock',
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(RecipeDetail recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredientes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: recipe.ingredients.asMap().entries.map((entry) {
              final i = entry.key;
              final ing = entry.value;
              final isLast = i == recipe.ingredients.length - 1;
              final qtyText = ing.quantity != null
                  ? '${ing.quantity!.toStringAsFixed(ing.quantity! == ing.quantity!.roundToDouble() ? 0 : 1)} ${ing.unit ?? ''}'
                  : ing.unit ?? '';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: AppColors.textLight.withValues(alpha: 0.3),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        ing.ingredientName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      qtyText.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSection(RecipeDetail recipe) {
    final steps = recipe.instructions
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preparación',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final stepNum = entry.key + 1;
          final text = entry.value.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$stepNum',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCookButton(RecipeDetail recipe) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isCooking ? null : () => _handleCook(recipe),
        icon: _isCooking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.restaurant),
        label: Text(_isCooking ? 'Cocinando...' : 'Cocinar esta receta'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
