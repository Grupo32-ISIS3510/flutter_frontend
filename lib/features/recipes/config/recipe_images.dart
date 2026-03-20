import 'package:flutter/material.dart';

class RecipeImageData {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  const RecipeImageData({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });
}

class RecipeImages {
  static const Map<String, RecipeImageData> _byKeyword = {
    'ensalada': RecipeImageData(
      icon: Icons.eco, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF4CAF50)),
    'aguacate': RecipeImageData(
      icon: Icons.eco, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF66BB6A)),
    'smoothie': RecipeImageData(
      icon: Icons.local_cafe, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF9800)),
    'banano': RecipeImageData(
      icon: Icons.breakfast_dining, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFFFC107)),
    'panqueque': RecipeImageData(
      icon: Icons.breakfast_dining, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFFFB74D)),
    'arroz': RecipeImageData(
      icon: Icons.rice_bowl, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF8F00)),
    'sopa': RecipeImageData(
      icon: Icons.soup_kitchen, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF42A5F5)),
    'pollo': RecipeImageData(
      icon: Icons.set_meal, backgroundColor: Color(0xFFFCE4EC), iconColor: Color(0xFFEF5350)),
    'pasta': RecipeImageData(
      icon: Icons.dinner_dining, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF7043)),
    'huevo': RecipeImageData(
      icon: Icons.egg, backgroundColor: Color(0xFFFFFDE7), iconColor: Color(0xFFFDD835)),
    'pescado': RecipeImageData(
      icon: Icons.set_meal, backgroundColor: Color(0xFFE0F7FA), iconColor: Color(0xFF26C6DA)),
    'carne': RecipeImageData(
      icon: Icons.restaurant, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFE53935)),
    'tomate': RecipeImageData(
      icon: Icons.local_grocery_store, backgroundColor: Color(0xFFFFEBEE), iconColor: Color(0xFFEF5350)),
    'pizza': RecipeImageData(
      icon: Icons.local_pizza, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF9800)),
    'sandwich': RecipeImageData(
      icon: Icons.lunch_dining, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFFFB300)),
    'yogur': RecipeImageData(
      icon: Icons.local_cafe, backgroundColor: Color(0xFFF3E5F5), iconColor: Color(0xFFAB47BC)),
    'leche': RecipeImageData(
      icon: Icons.local_cafe, backgroundColor: Color(0xFFE3F2FD), iconColor: Color(0xFF64B5F6)),
    'galleta': RecipeImageData(
      icon: Icons.cookie, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFD4A056)),
    'tortilla': RecipeImageData(
      icon: Icons.lunch_dining, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFFFB74D)),
    'taco': RecipeImageData(
      icon: Icons.lunch_dining, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF9800)),
    'vegetales': RecipeImageData(
      icon: Icons.grass, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF66BB6A)),
  };

  static const Map<String, RecipeImageData> _byCategory = {
    'breakfast': RecipeImageData(
      icon: Icons.free_breakfast, backgroundColor: Color(0xFFFFF8E1), iconColor: Color(0xFFFFB74D)),
    'lunch': RecipeImageData(
      icon: Icons.restaurant, backgroundColor: Color(0xFFE8F5E9), iconColor: Color(0xFF4CAF50)),
    'dinner': RecipeImageData(
      icon: Icons.dinner_dining, backgroundColor: Color(0xFFE8EAF6), iconColor: Color(0xFF7986CB)),
    'snack': RecipeImageData(
      icon: Icons.cookie, backgroundColor: Color(0xFFFFF3E0), iconColor: Color(0xFFFF8A65)),
  };

  static const RecipeImageData _fallback = RecipeImageData(
    icon: Icons.restaurant_menu, backgroundColor: Color(0xFFF5F5F5), iconColor: Color(0xFF9E9E9E));

  static RecipeImageData getImageData({
    required String recipeName,
    required String category,
  }) {
    final nameLower = recipeName.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (nameLower.contains(entry.key)) return entry.value;
    }
    return _byCategory[category] ?? _fallback;
  }

  /// Builds the visual widget for a recipe image placeholder.
  static Widget buildImage({
    String? imageUrl,
    required String recipeName,
    required String category,
    double height = 180,
  }) {
    final data = getImageData(recipeName: recipeName, category: category);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.backgroundColor,
            data.iconColor.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(data.icon, size: 140, color: data.iconColor.withValues(alpha: 0.12)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(data.icon, size: 48, color: data.iconColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
