import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/config/app_theme.dart';
import 'package:second_serving_frontend/models/enums.dart';
import 'package:second_serving_frontend/providers/inventory_provider.dart';
import 'package:second_serving_frontend/services/receipt_scanner_service.dart';

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

  @override
  void initState() {
    super.initState();
    _products = widget.products;
  }

  int get _selectedCount => _products.where((p) => p.selected).length;

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
    int savedCount = 0;
    final now = DateTime.now();
    final purchaseDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final expiryDate = now.add(const Duration(days: 7));
    final expiryStr =
        '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';

    for (final product in selected) {
      final data = {
        'name': product.name,
        'category': product.category.value,
        'quantity': product.quantity,
        'unit': product.unit,
        if (product.price != null) 'unit_price': product.price,
        'purchase_date': purchaseDate,
        'expiry_date': expiryStr,
      };
      final ok = await inventory.addItem(data);
      if (ok) savedCount++;
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount producto${savedCount == 1 ? '' : 's'} agregado${savedCount == 1 ? '' : 's'}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSummaryBar(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _products.length,
                itemBuilder: (context, i) => _ProductCard(
                  product: _products[i],
                  onToggle: () {
                    setState(() => _products[i].selected = !_products[i].selected);
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
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
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
              icon: const Icon(Icons.article_outlined, color: AppColors.textSecondary),
              onPressed: () => _showRawText(),
              tooltip: 'Ver texto detectado',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text('Guardar $_selectedCount producto${_selectedCount == 1 ? '' : 's'} en despensa'),
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
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
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
                  child: const Icon(Icons.close, size: 18, color: AppColors.textLight),
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

  final _units = ['unidades', 'kg', 'gramos', 'litros', 'ml', 'paquetes'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product.name);
    _qtyCtrl = TextEditingController(
        text: widget.product.quantity % 1 == 0
            ? widget.product.quantity.toInt().toString()
            : widget.product.quantity.toString());
    _priceCtrl = TextEditingController(
        text: widget.product.price?.toStringAsFixed(0) ?? '');
    _category = widget.product.category;
    _unit = widget.product.unit;
    if (!_units.contains(_unit)) _unit = 'unidades';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.onSave(ScannedProduct(
      name: _nameCtrl.text.trim(),
      quantity: double.tryParse(_qtyCtrl.text) ?? 1,
      unit: _unit,
      price: double.tryParse(_priceCtrl.text),
      category: _category,
      selected: widget.product.selected,
    ));
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
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text('${c.emoji} ${c.label}')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
            ],
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
