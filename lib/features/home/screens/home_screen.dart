import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/network/connectivity_provider.dart';
import 'package:second_serving_frontend/features/analytics/providers/analytics_provider.dart';
import 'package:second_serving_frontend/features/home/screens/dashboard_screen.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/screens/add_item_screen.dart';
import 'package:second_serving_frontend/features/inventory/screens/inventory_screen.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';
import 'package:second_serving_frontend/features/recipes/screens/recipes_screen.dart';
import 'package:second_serving_frontend/features/profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _homeExpiringDaysWindow = 30;

  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    InventoryScreen(),
    SizedBox(),
    RecipesScreen(),
    ProfileScreen(),
  ];

  void _onTap(int index) {
    if (index == 2) {
      _showAddItemScreen();
      return;
    }
    setState(() => _currentIndex = index);
    if (index == 0) {
      context
          .read<InventoryProvider>()
          .loadExpiringItems(days: _homeExpiringDaysWindow);
      context.read<AnalyticsProvider>().loadDashboard();
      context.read<RecipeProvider>().loadSuggestions(limit: 3);
    }
    if (index == 3) {
      context.read<RecipeProvider>().loadSuggestions();
    }
  }

  Future<void> _showAddItemScreen() async {
    final inventoryProvider = context.read<InventoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );

    if (!context.mounted || created != true) {
      return;
    }

    await inventoryProvider.loadItems();
    await inventoryProvider.loadExpiringItems(days: _homeExpiringDaysWindow);

    if (context.mounted) {
      setState(() => _currentIndex = 0);
    }

    if (!context.mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Alimento agregado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, _) {
              if (connectivity.isOnline) return const SizedBox.shrink();
              return _OfflineBanner(isSyncing: connectivity.isSyncing);
            },
          ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Inicio',
                  isActive: _currentIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _NavItem(
                  icon: Icons.kitchen_outlined,
                  activeIcon: Icons.kitchen,
                  label: 'Despensa',
                  isActive: _currentIndex == 1,
                  onTap: () => _onTap(1),
                ),
                _AddButton(onTap: () => _onTap(2)),
                _NavItem(
                  icon: Icons.restaurant_menu_outlined,
                  activeIcon: Icons.restaurant_menu,
                  label: 'Recetas',
                  isActive: _currentIndex == 3,
                  onTap: () => _onTap(3),
                ),
                _NavItem(
                  icon: Icons.person_outlined,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  isActive: _currentIndex == 4,
                  onTap: () => _onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Banner que se muestra en la parte superior cuando no hay conexión.
///
/// Anti-patrones evitados:
///   - "Pantalla en blanco": los datos locales siguen visibles.
///   - "App bloqueada": las operaciones se encolan y se sincronizan al reconectar.
///   - "Spinner infinito": el banner informa el estado real sin bloquear la UI.
class _OfflineBanner extends StatelessWidget {
  final bool isSyncing;

  const _OfflineBanner({required this.isSyncing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSyncing ? Colors.orange.shade700 : Colors.grey.shade800,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSyncing ? Icons.sync : Icons.cloud_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSyncing
                      ? 'Reconectado — sincronizando cambios...'
                      : 'Sin conexión — los cambios se guardarán localmente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

