import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/features/favorites/models/favorite_recipe.dart';
import 'package:second_serving_frontend/features/favorites/providers/favorites_provider.dart';
import 'package:second_serving_frontend/features/recipes/config/recipe_images.dart';
import 'package:second_serving_frontend/features/recipes/screens/recipe_detail_screen.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

/// Vista de Recetas Favoritas (Sprint 4).
///
/// - Local storage: lee 100% desde SQLite vía [FavoritesProvider] → disponible
///   sin conexión.
/// - BQ: muestra la distribución de favoritos por categoría de receta.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoritesProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis favoritas'),
      ),
      body: provider.isLoading && provider.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<FavoritesProvider>().load(),
              child: provider.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _BqInsightCard(provider: provider),
                        const SizedBox(height: 20),
                        const Text(
                          'Guardadas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...provider.favorites.map(
                          (fav) => _FavoriteCard(favorite: fav),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    // ListView para que el RefreshIndicator funcione aún estando vacío.
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(
          Icons.favorite_border,
          size: 64,
          color: AppColors.textLight.withValues(alpha: 0.6),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Aún no tienes favoritas',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Toca el corazón en una receta para\nguardarla y verla aquí sin conexión',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta que responde la BQ: distribución de favoritos por categoría.
class _BqInsightCard extends StatelessWidget {
  final FavoritesProvider provider;

  const _BqInsightCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final breakdown = provider.categoryBreakdown;
    final top = provider.topCategory;
    final total = provider.count;
    final maxValue =
        breakdown.isEmpty ? 1 : breakdown.first.value.clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '¿Qué tipo de recetas prefieres?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            top != null
                ? 'Tu categoría favorita es ${top.emoji} ${top.label} ($total guardada${total == 1 ? '' : 's'} en total)'
                : 'Guarda recetas para descubrir tu preferencia',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...breakdown.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryBar(
                category: entry.key,
                value: entry.value,
                maxValue: maxValue,
                total: total,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final RecipeCategory category;
  final int value;
  final int maxValue;
  final int total;

  const _CategoryBar({
    required this.category,
    required this.value,
    required this.maxValue,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : value / total;
    final barFraction = maxValue == 0 ? 0.0 : value / maxValue;

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            '${category.emoji} ${category.label}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 10,
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            '$value · ${(fraction * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteRecipe favorite;

  const _FavoriteCard({required this.favorite});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: favorite.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: RecipeImages.buildImage(
                      recipeName: favorite.name,
                      category: favorite.category.value,
                      height: 64,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${favorite.category.emoji} ${favorite.category.label}'
                        '${favorite.prepTimeMinutes != null ? ' · ${favorite.prepTimeMinutes} min' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar de favoritas',
                  icon: const Icon(Icons.favorite, color: AppColors.secondary),
                  onPressed: () =>
                      context.read<FavoritesProvider>().remove(favorite.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
