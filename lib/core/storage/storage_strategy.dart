/// ═══════════════════════════════════════════════════════════════════
/// ESTRATEGIA DE ALMACENAMIENTO LOCAL — Second Serving
/// ═══════════════════════════════════════════════════════════════════
///
/// Arquitectura multi-tier alineada con las mejores prácticas móviles:
///
/// ┌────────────────────────────────────────────────────────────┐
/// │  TIER 1 — SharedPreferences (Key-Value)                    │
/// │  Uso: Datos simples, configuraciones, telemetría local     │
/// │  Archivos:                                                 │
/// │    • ScanTelemetryService     → scan events                │
/// │    • ExpiryTelemetryService   → accuracy events            │
/// │    • ScreenAnalyticsService   → screen enter/exit          │
/// │    • WeatherCacheService      → clima con TTL (1h)         │
/// │  Equivalente nativo: NSUserDefaults (iOS), SharedPrefs (A) │
/// ├────────────────────────────────────────────────────────────┤
/// │  TIER 2 — SQLite via sqflite (Datos estructurados)         │
/// │  Uso: Inventario completo con relaciones y consultas       │
/// │  Archivos:                                                 │
/// │    • AppDatabase             → schema, migraciones         │
/// │    • LocalInventoryService   → CRUD + cola offline         │
/// │  Equivalente nativo: Room (Android), CoreData (iOS)        │
/// ├────────────────────────────────────────────────────────────┤
/// │  TIER 3 — flutter_secure_storage (Datos sensibles)         │
/// │  Uso: JWT token de autenticación                           │
/// │  Cifrado: AES en Android, Keychain en iOS                  │
/// │  Archivo:                                                  │
/// │    • AuthProvider            → almacena/lee token           │
/// ├────────────────────────────────────────────────────────────┤
/// │  TIER 4 — Caché temporal (Archivos transitorios)           │
/// │  Uso: Imágenes de recetas descargadas                      │
/// │  Paquete: cached_network_image                             │
/// │  Política: Auto-gestionado por el paquete (LRU + disco)   │
/// └────────────────────────────────────────────────────────────┘
///
/// Estrategia de retrieving: "Cache then network"
///   1. La UI lee del SQLite local → respuesta instantánea
///   2. En paralelo, se consulta el backend
///   3. Si la red responde, se actualiza SQLite y la UI
///   4. Si la red falla, la UI sigue mostrando datos locales
///   → Evita antipatrón: "Contenido perdido" / pantalla en blanco
///
/// Cola offline (pending_operations):
///   - Si un addItem/updateItem/etc. falla por red, se encola
///   - syncPendingOperations() reintenta cuando vuelve la conexión
///   → Evita antipatrón: "App bloqueada" / pérdida de datos
///
/// ═══════════════════════════════════════════════════════════════════
library;
