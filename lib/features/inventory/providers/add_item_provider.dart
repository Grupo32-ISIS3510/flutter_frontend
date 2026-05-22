import 'package:flutter/material.dart';
import 'package:second_serving_frontend/shared/models/enums.dart';

class AddItemProvider extends ChangeNotifier {
  static final RegExp _allowedNameChars = RegExp(r"[a-zA-ZÀ-ÿ0-9'.,()/\-\s]");

  ItemCategory _category = ItemCategory.fruits;
  int _quantity = 2;
  String _unit = 'Unidades';
  DateTime _purchaseDate = DateUtils.dateOnly(DateTime.now());
  DateTime _expiryDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 7)),
  );
  String _location = 'Nevera';
  bool _isSaving = false;
  String? _error;

  ItemCategory get category => _category;
  int get quantity => _quantity;
  String get unit => _unit;
  DateTime get purchaseDate => _purchaseDate;
  DateTime get expiryDate => _expiryDate;
  String get location => _location;
  bool get isSaving => _isSaving;
  String? get error => _error;

  final List<String> units = const [
    'Unidades',
    'Kg',
    'Litros',
    'Gramos',
    'Paquetes',
  ];
  final List<String> locations = const ['Nevera', 'Congelador', 'Despensa'];

  void setCategory(ItemCategory value) {
    _category = value;
    notifyListeners();
  }

  void incrementQuantity() {
    _quantity++;
    notifyListeners();
  }

  void decrementQuantity() {
    if (_quantity > 1) {
      _quantity--;
      notifyListeners();
    }
  }

  void setUnit(String value) {
    _unit = value;
    notifyListeners();
  }

  void setPurchaseDate(DateTime value) {
    _purchaseDate = DateUtils.dateOnly(value);
    if (!_expiryDate.isAfter(_purchaseDate)) {
      _expiryDate = _purchaseDate.add(const Duration(days: 1));
    }
    notifyListeners();
  }

  void setExpiryDate(DateTime value) {
    _expiryDate = DateUtils.dateOnly(value);
    notifyListeners();
  }

  void setLocation(String value) {
    _location = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void setError(String? message) {
    _error = message;
    notifyListeners();
  }

  String normalizeWhitespaces(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String sanitizeName(String input) {
    final normalized = normalizeWhitespaces(input);
    return normalized
        .split('')
        .where((char) => _allowedNameChars.hasMatch(char))
        .join();
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio';
    }
    final sanitized = sanitizeName(value);
    if (sanitized.length < 2) {
      return 'Debe tener al menos 2 caracteres';
    }
    if (!RegExp(r'[a-zA-ZÀ-ÿ0-9]').hasMatch(sanitized)) {
      return 'Usa al menos una letra o número';
    }
    return null;
  }

  bool areDatesValid() {
    return _expiryDate.isAfter(_purchaseDate);
  }

  Map<String, dynamic> buildPayload(String sanitizedName, {double? unitPrice}) {
    return {
      'name': sanitizedName,
      'category': _category.value,
      'quantity': _quantity,
      'unit': _unit.toLowerCase(),
      if (unitPrice != null) 'unit_price': unitPrice,
      'purchase_date':
          '${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}',
      'expiry_date':
          '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
      'notes': 'Ubicación: $_location',
    };
  }

  int daysRemainingFromToday() {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    return _expiryDate.difference(today).inDays;
  }

  void reset() {
    _category = ItemCategory.fruits;
    _quantity = 2;
    _unit = 'Unidades';
    _purchaseDate = DateUtils.dateOnly(DateTime.now());
    _expiryDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 7)),
    );
    _location = 'Nevera';
    _isSaving = false;
    _error = null;
    notifyListeners();
  }
}
