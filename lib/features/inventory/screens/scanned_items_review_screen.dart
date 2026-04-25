import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/services/receipt_scanner_service.dart';
import 'package:second_serving_frontend/core/network/api_client.dart';
import 'package:second_serving_frontend/features/inventory/services/expiry_telemetry_service.dart';
import 'package:second_serving_frontend/features/inventory/services/screen_analytics_service.dart';
import 'package:second_serving_frontend/features/recipes/providers/recipe_provider.dart';

class ScannedItemsReviewScreen extends StatefulWidget {
  final List<ScannedProduct> products;
  final String? rawText;

  const ScannedItemsReviewScreen({
    super.key,
    required this.products,
    this.rawText,
  });

  @override
  State<ScannedItemsReviewScreen> createState() =>
      _ScannedItemsReviewScreenState();
}

class _ScannedItemsReviewScreenState extends State<ScannedItemsReviewScreen> {
  late List<ScannedProduct> _products;
  bool _isSaving = false;
  late final ExpiryTelemetryService _expiryTelemetry;
  late final ScreenAnalyticsService _screenAnalytics;
  bool _exitRecorded = false;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _products = widget.products;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_servicesInitialized) {
      _servicesInitialized = true;
      final apiClient = context.read<ApiClient>();
      _expiryTelemetry = ExpiryTelemetryService(apiClient: apiClient);
      _screenAnalytics = ScreenAnalyticsService(apiClient: apiClient);
      _screenAnalytics.recordEnter('scanned_review');
    }
  }

  void _recordExitOnce(String reason) {
    if (_exitRecorded) return;
    _exitRecorded = true;
    _screenAnalytics.recordExit('scanned_review', reason);
  }

  @override
  void dispose() {
    _recordExitOnce('back');
    super.dispose();
  }

  int get _selectedCount => _products.where((p) => p.selected).length;

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy', 'es').format(d);

  Future<void> _saveAll() async {
    final selected = _products.where((p) => p.selected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un producto')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final inventory = context.read<InventoryProvider>();
    final recipes = context.read<RecipeProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    int syncedCount = 0;
    int queuedCount = 0;
    final now = DateTime.now();
    final purchaseDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final defaultExpiry = now.add(const Duration(days: 7));

    for (final product in selected) {
      final expiry = product.expiryDate ?? defaultExpiry;
      final expiryStr =
          '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';

      final data = {
        'name': product.name,
        'category': product.category.value,
        'quantity': product.quantity,
        'unit': product.unit,
        if (product.price != null) 'unit_price': product.price,
        'purchase_date': purchaseDate,
        'expiry_date': expiryStr,
      };
      final result = await inventory.addItem(data);
      if (result == 'synced') syncedCount++;
      if (result == 'queued') queuedCount++;

      _expiryTelemetry.recordAccuracy(
        category: product.category.value,
        ocrDetectedDate: product.expiryDateFromOcr,
        ocrDate: product.expiryDateFromOcr ? product.expiryDate : null,
        userConfirmedDate: expiry,
      );
    }

    if (mounted) {
      await inventory.loadItems();
      await inventory.loadExpiringItems(days: 30);
      if (!mounted) return;

      recipes.loadSuggestions();
      setState(() => _isSaving = false);

      final total = syncedCount + queuedCount;
      final String message;
      final Color bgColor;

      if (queuedCount == 0) {
        message =
            '$total producto${total == 1 ? '' : 's'} agregado${total == 1 ? '' : 's'}';
        bgColor = AppColors.success;
      } else if (syncedCount == 0) {
        message =
            '$total producto${total == 1 ? '' : 's'} guardado${total == 1 ? '' : 's'} localmente — se sincronizará${total == 1 ? '' : 'n'} con conexión';
        bgColor = Colors.orange;
      } else {
        message =
            '$syncedCount sincronizado${syncedCount == 1 ? '' : 's'}, $queuedCount pendiente${queuedCount == 1 ? '' : 's'} de sincronizar';
        bgColor = Colors.orange;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: bgColor),
      );
      _recordExitOnce('completed');
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _editProduct(int index) {
    final product = _products[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProductSheet(
        product: product,
        onSave: (edited) {
          setState(() => _products[index] = edited);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _recordExitOnce('back');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSummaryBar(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, i) => _ProductCard(
                    product: _products[i],
                    formatDate: _formatDate,
                    onToggle: () {
                      setState(
                        () => _products[i].selected = !_products[i].selected,
                      );
                    },
                    onEdit: () => _editProduct(i),
                    onDelete: () {
                      setState(() => _products.removeAt(i));
                    },
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.textLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Productos detectados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (widget.rawText != null)
            IconButton(
              icon: const Icon(
                Icons.article_outlined,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _showRawText(),
              tooltip: 'Ver texto detectado',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final withDate = _products.where((p) => p.expiryDate != null).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_products.length} encontrado${_products.length == 1 ? '' : 's'} · $_selectedCount seleccionado${_selectedCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (withDate > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Vencimiento estimado por categoría — puedes editar cada fecha',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Guardar $_selectedCount producto${_selectedCount == 1 ? '' : 's'} en despensa',
                  ),
          ),
        ),
      ),
    );
  }

  void _showRawText() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Texto detectado'),
        content: SingleChildScrollView(
          child: Text(
            widget.rawText ?? '',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ScannedProduct product;
  final String Function(DateTime) formatDate;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.formatDate,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.selected ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: product.selected
              ? BorderSide(color: AppColors.primary.withValues(alpha: 0.3))
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: product.selected
                          ? AppColors.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: product.selected
                            ? AppColors.primary
                            : AppColors.textLight,
                        width: 2,
                      ),
                    ),
                    child: product.selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  product.category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.quantity % 1 == 0 ? product.quantity.toInt() : product.quantity} ${product.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (product.expiryDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.expiryDateFromOcr
                              ? 'Vence: ${formatDate(product.expiryDate!)}'
                              : 'Vence: ${formatDate(product.expiryDate!)} (estimada)',
                          style: TextStyle(
                            fontSize: 11,
                            color: product.expiryDateFromOcr
                                ? AppColors.primary
                                : Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (product.price != null)
                  Text(
                    '\$${product.price!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProductSheet extends StatefulWidget {
  final ScannedProduct product;
  final ValueChanged<ScannedProduct> onSave;

  const _EditProductSheet({required this.product, required this.onSave});

  @override
  State<_EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends State<_EditProductSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late ItemCategory _category;
  late String _unit;
  late DateTime? _expiryDate;
  late bool _originalFromOcr;

  final _units = ['unidades', 'kg', 'gramos', 'litros', 'ml', 'paquetes'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _qtyCtrl = TextEditingController(
      text: widget.product.quantity % 1 == 0
          ? widget.product.quantity.toInt().toString()
          : widget.product.quantity.toString(),
    );
    _priceCtrl = TextEditingController(
      text: widget.product.price?.toStringAsFixed(0) ?? '',
    );
    _category = widget.product.category;
    _unit = widget.product.unit;
    if (!_units.contains(_unit)) _unit = 'unidades';
    _expiryDate = widget.product.expiryDate;
    _originalFromOcr = widget.product.expiryDateFromOcr;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _save() {
    final edited = ScannedProduct(
      name: _nameCtrl.text.trim(),
      quantity: double.tryParse(_qtyCtrl.text) ?? 1,
      unit: _unit,
      price: double.tryParse(_priceCtrl.text),
      category: _category,
      selected: widget.product.selected,
      expiryDate: _expiryDate,
      expiryDateFromOcr: _originalFromOcr,
    );
    widget.onSave(edited);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Editar producto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                  items: _units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _unit = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio (COP)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ItemCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: ItemCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.emoji} ${c.label}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickExpiryDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fecha de vencimiento',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              child: Text(
                _expiryDate != null
                    ? '${DateFormat('d MMM yyyy', 'es').format(_expiryDate!)}${_originalFromOcr ? '' : ' (estimada)'}'
                    : 'No detectada — toca para asignar',
                style: TextStyle(
                  color: _expiryDate != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar cambios'),
            ),
          ),
        ],
      ),
    );
  }
}
