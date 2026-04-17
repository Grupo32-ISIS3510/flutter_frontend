import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/core/config/format_helpers.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/screens/add_item_screen.dart';

// StatefulWidget porque necesitamos hook initState() para disparar la carga
// inicial de datos (los Stateless no tienen ciclo de vida).
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    // PATRÓN CLAVE: addPostFrameCallback para cargar datos al entrar.
    //
    // ❌ Si llamas provider.loadItems() directo aquí, el provider hace
    //    notifyListeners() durante el primer build → Flutter lanza:
    //    "setState() or markNeedsBuild() called during build".
    //
    // ✅ addPostFrameCallback agenda el callback DESPUÉS de pintar el primer
    //    frame. Para entonces ya es seguro mutar estado y notificar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;       // Defensa: el widget pudo desmontarse
      context.read<InventoryProvider>().loadItems();
      context.read<InventoryProvider>().loadExpiringItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch = me suscribo. Cuando el provider notifique, este build re-corre.
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
      // RENDERIZADO CONDICIONAL INTELIGENTE:
      // Solo muestra spinner full-screen en la PRIMERA carga (sin items todavía).
      // En refrescos posteriores conserva la lista visible y basta el spinner
      // del pull-to-refresh. Mejora UX: nunca pantalla blanca tras tener datos.
      body: provider.isLoading && provider.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          // RefreshIndicator = pull-to-refresh nativo (Material en Android,
          // Cupertino en iOS). Requiere child scrollable y onRefresh: Future.
          : RefreshIndicator(
              onRefresh: () async {
                await provider.loadItems();
                await provider.loadExpiringItems();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // SECCIÓN 1: solo aparece si hay items próximos a vencer.
                  // Spread + collection-if combina lista de widgets condicionalmente.
                  if (provider.expiringItems.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Por vencer pronto',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.expiringSoon,        // naranja de alerta
                      count: provider.expiringItems.length,
                    ),
                    const SizedBox(height: 8),
                    // .map() + spread genera N cards a partir de la lista.
                    ...provider.expiringItems.map(
                      (item) => _InventoryItemCard(item: item),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // SECCIÓN 2: siempre presente, lista completa.
                  _SectionHeader(
                    title: 'Todos los productos',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.primary,
                    count: provider.total,
                  ),
                  const SizedBox(height: 8),
                  // EMPTY STATE: cuando no hay datos, mostrar feedback claro
                  // en vez de una zona en blanco que confunde al usuario.
                  if (provider.items.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: AppColors.textLight,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No hay productos en tu inventario',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...provider.items.map(
                      (item) => _InventoryItemCard(item: item),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // PATRÓN CRÍTICO de async-safety con BuildContext:
          // Capturamos provider y messenger ANTES del await. Si los buscáramos
          // después del await, el context podría ser inválido.
          final inventoryProvider = context.read<InventoryProvider>();
          final messenger = ScaffoldMessenger.of(context);

          // Navigator.push<bool>() es TIPADO: la pantalla destino puede
          // devolver un valor con Navigator.pop(context, true).
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddItemScreen()),
          );

          // context.mounted = igual que `mounted` pero como propiedad de context.
          // Si el usuario salió de la pantalla, abortamos.
          if (!context.mounted || created != true) {
            return;
          }

          // Recargar para sincronizar con backend (días restantes, ordenamiento).
          await inventoryProvider.loadItems();
          await inventoryProvider.loadExpiringItems();

          if (!context.mounted) {
            return;
          }

          // Usar el messenger CAPTURADO arriba (no ScaffoldMessenger.of(context)
          // de nuevo, porque ese context podría haber cambiado).
          messenger.showSnackBar(
            const SnackBar(content: Text('Alimento agregado correctamente')),
          );
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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// StatelessWidget porque toda la información viene del item recibido.
// Sin estado interno = más rápido, predecible, y fácil de testear.
class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;

  const _InventoryItemCard({required this.item});

  // Getter privado que encapsula la decisión de color según el estado del item.
  // Centralizar esta lógica aquí permite cambiar la regla en UN solo lugar.
  // Las propiedades isExpired/isExpiringSoon viven en el modelo (dominio rico).
  Color get _statusColor {
    if (item.isExpired) return AppColors.expired;            // rojo
    if (item.isExpiringSoon) return AppColors.expiringSoon;  // naranja
    return AppColors.fresh;                                  // verde
  }

  @override
  Widget build(BuildContext context) {
    // Card aplica elevation, borde redondeado y color de superficie del tema.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // ListTile sigue Material Design Guidelines automáticamente:
      // alturas mínimas (56/72dp), padding correcto, ripple en onTap.
      // Equivale a inflar un layout list_item.xml en Android nativo.
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          // Tinte sutil del 15% del color de status (acento periférico).
          backgroundColor: _statusColor.withValues(alpha: 0.15),
          child: Text(
            item.category.emoji,        // emoji viene del enum ItemCategory
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        // ACCESIBILIDAD: triple codificación visual de urgencia:
        //   1. Tinte del avatar (sutil, periférico)
        //   2. Color del texto del subtitle (legible, directo)
        //   3. Texto en sí ("Vence mañana") → semántico, no depende solo de color.
        // Nunca codifiques info crítica solo con color (daltonismo).
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cantidad humanizada: "2" → "2 L", "1.5" → "1.5 kg".
            Text(FormatHelpers.quantity(item.quantity, item.unit)),
            Text(
              // Días restantes en lenguaje natural: "Vence mañana", "Vencido hace 3 días".
              FormatHelpers.daysRemaining(item.daysRemaining),
              style: TextStyle(
                color: _statusColor,                 // ← color = código visual del estado
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Slot trailing: precio si existe, null si no (ListTile acepta null y omite).
        trailing: item.unitPrice != null
            ? Text(
                FormatHelpers.currency(item.totalValue),
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : null,
        onTap: () {
          // extra: pasa el objeto completo a la siguiente ruta sin serializar.
          // GoRouter soporta payloads tipados además de los path/query params.
          context.push('/context-aware', extra: item);
        },
      ),
    );
  }
}
