import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:second_serving_frontend/core/config/app_theme.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';
import 'package:second_serving_frontend/features/inventory/providers/inventory_provider.dart';
import 'package:second_serving_frontend/features/inventory/screens/scanned_items_review_screen.dart';
import 'package:second_serving_frontend/features/inventory/services/receipt_scanner_service.dart';
import 'package:second_serving_frontend/features/notifications/application/local_notifications_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  static final RegExp _allowedNameChars = RegExp(r"[a-zA-ZÀ-ÿ0-9'.,()/\-\s]");

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _scannerService = ReceiptScannerService();
  ItemCategory _selectedCategory = ItemCategory.fruits;
  int _quantity = 2;
  String _unit = 'Piezas';
  DateTime _purchaseDate = DateUtils.dateOnly(DateTime.now());
  DateTime _expiryDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 7)),
  );
  String _location = 'Nevera';
  bool _isScanning = false;
  bool _isSaving = false;

  final _units = ['Piezas', 'Kg', 'Litros', 'Gramos', 'Paquetes'];
  final _locations = ['Nevera', 'Congelador', 'Despensa'];

  String _normalizeWhitespaces(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _sanitizeName(String input) {
    final normalized = _normalizeWhitespaces(input);
    return normalized
        .split('')
        .where((char) => _allowedNameChars.hasMatch(char))
        .join();
  }

  DateTime _clampDate({
    required DateTime value,
    required DateTime min,
    required DateTime max,
  }) {
    if (value.isBefore(min)) {
      return min;
    }
    if (value.isAfter(max)) {
      return max;
    }
    return value;
  }

  Future<DateTime?> _showSafeDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    Future<DateTime?> openPicker({Locale? locale}) {
      return showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        locale: locale,
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
    }

    try {
      return await openPicker(locale: const Locale('es'));
    } catch (_) {
      return openPicker();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCameraScan() async {
    setState(() => _isScanning = true);

    try {
      final result = await _scannerService.scan();

      if (!mounted) return;
      setState(() => _isScanning = false);

      if (!result.success) {
        if (result.errorMessage == 'Captura cancelada') return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Error al escanear'),
            action: SnackBarAction(
              label: 'Ingreso manual',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScannedItemsReviewScreen(
            products: result.products,
            rawText: result.rawText,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickExpiryDate() async {
    final firstDate = DateUtils.dateOnly(
      _purchaseDate,
    ).add(const Duration(days: 1));
    final lastDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 365 * 2)),
    );
    final initialDate = _clampDate(
      value: DateUtils.dateOnly(_expiryDate),
      min: firstDate,
      max: lastDate,
    );

    final picked = await _showSafeDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() => _expiryDate = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _pickPurchaseDate() async {
    final firstDate = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 365 * 3)),
    );
    final lastDate = DateUtils.dateOnly(DateTime.now());
    final initialDate = _clampDate(
      value: DateUtils.dateOnly(_purchaseDate),
      min: firstDate,
      max: lastDate,
    );

    final picked = await _showSafeDatePicker(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) {
      return;
    }

    final purchaseDate = DateUtils.dateOnly(picked);
    setState(() {
      _purchaseDate = purchaseDate;
      if (!_expiryDate.isAfter(_purchaseDate)) {
        _expiryDate = _purchaseDate.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos del formulario')),
      );
      return;
    }

    if (!_expiryDate.isAfter(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha de vencimiento debe ser posterior a la de compra',
          ),
        ),
      );
      return;
    }

    final sanitizedName = _sanitizeName(_nameController.text);
    if (sanitizedName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un nombre válido para el alimento'),
        ),
      );
      return;
    }

    if (_nameController.text != sanitizedName) {
      _nameController.text = sanitizedName;
      _nameController.selection = TextSelection.collapsed(
        offset: sanitizedName.length,
      );
    }

    setState(() => _isSaving = true);

    final data = {
      'name': sanitizedName,
      'category': _selectedCategory.value,
      'quantity': _quantity,
      'unit': _unit.toLowerCase(),
      'purchase_date':
          '${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}',
      'expiry_date':
          '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
      'notes': 'Ubicación: $_location',
    };

    final success = await context.read<InventoryProvider>().addItem(data);
    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);

    if (success) {
      final DateTime today = DateUtils.dateOnly(DateTime.now());
      final int daysRemaining = _expiryDate.difference(today).inDays;

      if (daysRemaining >= 0 && daysRemaining <= 1) {
        await LocalNotificationsService.instance.showExpiringSoonNotification(
          itemName: sanitizedName,
          daysRemaining: daysRemaining,
        );

        if (!mounted) {
          return;
        }
      }

      Navigator.of(context).pop(true);
      return;
    }

    final error = context.read<InventoryProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'No se pudo guardar el alimento')),
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
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 16),
                    _buildMethodButtons(),
                    const SizedBox(height: 28),
                    _buildField('Nombre', _buildNameInput()),
                    const SizedBox(height: 20),
                    _buildField('Categoría', _buildCategoryDropdown()),
                    const SizedBox(height: 20),
                    _buildQuantityAndUnits(),
                    const SizedBox(height: 20),
                    _buildField('Fecha compra', _buildPurchaseDatePicker()),
                    const SizedBox(height: 20),
                    _buildField('Fecha vencimiento', _buildExpiryDatePicker()),
                    const SizedBox(height: 20),
                    _buildLocationChips(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
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
              child: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Agregar alimento',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodButtons() {
    return Column(
      children: [
        _isScanning
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Escaneando recibo...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : _MethodButton(
                icon: Icons.camera_alt_rounded,
                title: 'Reconocimiento por cámara',
                subtitle: 'Identifica con IA',
                filled: true,
                onTap: _handleCameraScan,
              ),
        const SizedBox(height: 10),
        _MethodButton(
          icon: Icons.edit_note_rounded,
          title: 'Ingreso manual',
          subtitle: 'Escribe los detalles',
          filled: false,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildNameInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: _nameController,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [
          LengthLimitingTextInputFormatter(60),
          FilteringTextInputFormatter.allow(_allowedNameChars),
        ],
        onChanged: (value) {
          if (value.contains('\n')) {
            _nameController.text = value.replaceAll('\n', ' ');
            _nameController.selection = TextSelection.collapsed(
              offset: _nameController.text.length,
            );
          }
        },
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'El nombre es obligatorio';
          }
          final sanitized = _sanitizeName(value);
          if (sanitized.length < 2) {
            return 'Debe tener al menos 2 caracteres';
          }
          if (!RegExp(r'[a-zA-ZÀ-ÿ0-9]').hasMatch(sanitized)) {
            return 'Usa al menos una letra o número';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: 'Aguacate',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ItemCategory>(
          value: _selectedCategory,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          items: ItemCategory.values.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text('${cat.emoji} ${cat.label}'),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCategory = v);
          },
        ),
      ),
    );
  }

  Widget _buildQuantityAndUnits() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildField('Cantidad', _buildQuantitySelector())),
        const SizedBox(width: 16),
        Expanded(child: _buildField('Unidades', _buildUnitDropdown())),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _QuantityButton(
            icon: Icons.remove,
            onTap: () {
              if (_quantity > 1) setState(() => _quantity--);
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add,
            onTap: () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _unit,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
          ),
          items: _units.map((u) {
            return DropdownMenuItem(value: u, child: Text(u));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _unit = v);
          },
        ),
      ),
    );
  }

  Widget _buildPurchaseDatePicker() {
    final formatted = DateFormat("d MMM yyyy", 'es').format(_purchaseDate);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickPurchaseDate,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatted,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryDatePicker() {
    final formatted = DateFormat("d MMM yyyy", 'es').format(_expiryDate);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _pickExpiryDate,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatted,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _locations.map((loc) {
            final selected = _location == loc;
            return ChoiceChip(
              label: Text(loc),
              selected: selected,
              onSelected: (_) => setState(() => _location = loc),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.textLight,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
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
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : const Text('Guardar en despensa'),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  const _MethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(color: AppColors.textLight.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: filled
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: filled ? Colors.white : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: filled
                        ? Colors.white.withValues(alpha: 0.75)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 50,
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
