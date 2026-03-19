import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/config/app_theme.dart';
import 'package:second_serving_frontend/config/format_helpers.dart';
import 'package:second_serving_frontend/providers/inventory_provider.dart';
import 'package:second_serving_frontend/models/inventory_item.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InventoryProvider>().loadItems();
      context.read<InventoryProvider>().loadExpiringItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Inventario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: provider.isLoading && provider.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadItems();
                await provider.loadExpiringItems();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.expiringItems.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Por vencer pronto',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.expiringSoon,
                      count: provider.expiringItems.length,
                    ),
                    const SizedBox(height: 8),
                    ...provider.expiringItems
                        .map((item) => _InventoryItemCard(item: item)),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: 'Todos los productos',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    count: provider.total,
                  ),
                  const SizedBox(height: 8),
                  if (provider.items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 64, color: AppColors.textLight),
                            SizedBox(height: 16),
                            Text('No hay productos en tu inventario',
                                style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...provider.items
                        .map((item) => _InventoryItemCard(item: item)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: navegar a pantalla de agregar producto
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const _InventoryItemCard({required this.item});

  Color get _statusColor {
    if (item.isExpired) return AppColors.expired;
    if (item.isExpiringSoon) return AppColors.expiringSoon;
    return AppColors.fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor.withValues(alpha: 0.15),
          child: Text(item.category.emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(FormatHelpers.quantity(item.quantity, item.unit)),
            Text(
              FormatHelpers.daysRemaining(item.daysRemaining),
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        trailing: item.unitPrice != null
            ? Text(
                FormatHelpers.currency(item.totalValue),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
        onTap: () {
          // TODO: navegar a detalle del producto
        },
      ),
    );
  }
}
