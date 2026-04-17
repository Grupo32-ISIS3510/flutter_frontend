import 'package:flutter/material.dart';
import 'package:second_serving_frontend/features/inventory/models/inventory_item.dart';
import 'package:second_serving_frontend/features/inventory/services/inventory_service.dart';

// ChangeNotifier = igual que en AuthProvider: mantiene listeners y dispara
// rebuilds en la UI cuando notifyListeners() es llamado.
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service;     // Inyectado vía Provider en main.dart

  // Dos listas separadas: la principal (paginada) y la corta (próximos a vencer).
  // Permite renderizar la sección "Por vencer pronto" sin filtrar localmente.
  List<InventoryItem> _items = [];
  List<InventoryItem> _expiringItems = [];
  int _total = 0;                      // Total backend (puede ser > items.length por paginación)
  bool _isLoading = false;
  String? _error;

  InventoryProvider(this._service);

  // Getters de solo lectura. Las listas se exponen pero NO deberían mutarse
  // desde fuera (idealmente serían UnmodifiableListView, pero el código asume disciplina).
  List<InventoryItem> get items => _items;
  List<InventoryItem> get expiringItems => _expiringItems;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // skip/limit = paginación REST estándar. Útil para listas largas.
  Future<void> loadItems({int skip = 0, int limit = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();                 // Disparo 1: UI muestra spinner

    try {
      final response = await _service.getItems(skip: skip, limit: limit);
      _items = response.items;
      _total = response.total;
    } catch (e) {
      _error = e.toString();
    }

    // FUERA del try/catch: garantiza que isLoading se apague siempre.
    // Otra opción idiomática: try { ... } finally { ... }.
    _isLoading = false;
    notifyListeners();                 // Disparo 2: UI ve datos o error
  }

  // Carga separada del endpoint /inventory/expiring (no es un filtro local).
  // El backend hace el cálculo de "días" considerando su zona horaria oficial.
  Future<void> loadExpiringItems({int days = 3}) async {
    try {
      _expiringItems = await _service.getExpiringItems(days: days);
      // debugPrint > print: en producción se compila como no-op y respeta
      // el rate-limiting de logcat (Android descarta líneas si llegan muy rápido).
      debugPrint('[InventoryProvider] expiringItems loaded: ${_expiringItems.length}');
      notifyListeners();
    } catch (e, st) {                  // Captura también el stack trace
      _error = e.toString();
      debugPrint('[InventoryProvider] loadExpiringItems ERROR: $e');
      debugPrint('[InventoryProvider] stackTrace: $st');
      notifyListeners();
    }
  }

  // OPTIMIZACIÓN: tras crear, en vez de recargar toda la lista del backend,
  // insertamos el item devuelto al PRINCIPIO. Más rápido, menos red.
  // Trade-off: si el backend ordenara distinto, perderíamos consistencia.
  Future<bool> addItem(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final item = await _service.createItem(data);
      _items.insert(0, item);          // Update local optimista
      _total++;                        // Mantener contador en sync
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // PATRÓN UPDATE LOCAL: encontrar índice + reemplazar.
  // indexWhere devuelve -1 si no existe → guarda contra inconsistencias.
  Future<bool> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateItem(id, data);
      final idx = _items.indexWhere((i) => i.id == id);
      if (idx != -1) _items[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Consumir = el usuario se lo comió. Lo quitamos de la lista activa.
  // El backend lo conserva para analytics (segmentación de hábitos).
  Future<bool> consumeItem(String id) async {
    try {
      await _service.consumeItem(id);
      _items.removeWhere((i) => i.id == id);    // Remove local
      _total--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Descartar = se botó. Más complejo que consume porque acepta cantidad parcial.
  // Si se descartó TODO el item, lo quitamos. Si solo parcial, actualizamos.
  Future<bool> discardItem(String id,
      {required String reason, double? quantity}) async {
    try {
      final updated =
          await _service.discardItem(id, reason: reason, quantity: quantity);
      // Backend devuelve el item con su nuevo status (active si quedó cantidad,
      // discarded si se botó todo).
      if (updated.status.value == 'discarded') {
        _items.removeWhere((i) => i.id == id);
        _total--;
      } else {
        final idx = _items.indexWhere((i) => i.id == id);
        if (idx != -1) _items[idx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Borrar definitivo (sin trace en analytics). Mismo patrón que consume.
  Future<bool> deleteItem(String id) async {
    try {
      await _service.deleteItem(id);
      _items.removeWhere((i) => i.id == id);
      _total--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
