import 'dart:collection';

/// Caché LRU (Least Recently Used) en memoria, O(1) en lectura y escritura.
///
/// Estructura: se apoya en un [LinkedHashMap], que conserva el orden de
/// inserción de las claves. La invariante es que la PRIMERA clave del mapa es
/// la menos recientemente usada y la ÚLTIMA es la más reciente.
///
/// Parámetros de implementación:
///   * [maxSize]: capacidad máxima de entradas. Al superarse, se evicta la
///     entrada menos recientemente usada (`_store.keys.first`).
///
/// Decisiones:
///   * En [get], si la clave existe se elimina y se vuelve a insertar para
///     moverla al final (marcarla como "recién usada").
///   * En [put], si la clave ya existía se elimina primero (para reordenar);
///     luego se inserta al final y, si se excede [maxSize], se evicta la
///     cabeza del mapa.
class LruCache<K, V> {
  LruCache({this.maxSize = 20}) : assert(maxSize > 0);

  final int maxSize;
  final LinkedHashMap<K, V> _store = LinkedHashMap<K, V>();

  int get length => _store.length;

  V? get(K key) {
    if (!_store.containsKey(key)) {
      return null;
    }
    // Marcar como más reciente: remover y reinsertar al final.
    final V value = _store.remove(key) as V;
    _store[key] = value;
    return value;
  }

  void put(K key, V value) {
    // Si ya existía, removerla para que vuelva a insertarse al final.
    _store.remove(key);
    _store[key] = value;
    // Evicción del menos recientemente usado si superamos la capacidad.
    if (_store.length > maxSize) {
      _store.remove(_store.keys.first);
    }
  }

  bool containsKey(K key) => _store.containsKey(key);

  void clear() => _store.clear();
}
