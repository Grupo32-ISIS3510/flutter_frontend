/// ═══════════════════════════════════════════════════════════════════
/// ESTRATEGIA DE CONECTIVIDAD EVENTUAL — Second Serving
/// ═══════════════════════════════════════════════════════════════════
///
/// Objetivo: que la app funcione de forma transparente sin importar
/// si el dispositivo tiene conexión a internet o no.
///
/// ┌──────────────────────────────────────────────────────────────┐
/// │  CAPA 1 — Detección de conectividad                         │
/// │  Paquete: connectivity_plus                                  │
/// │  Clase:   ConnectivityService  (Singleton)                   │
/// │  Emite:   Stream reactivo on cada cambio wifi/mobile/ethernet │
/// ├──────────────────────────────────────────────────────────────┤
/// │  CAPA 2 — ViewModel reactivo                                 │
/// │  Clase:   ConnectivityProvider  (ChangeNotifier / MVVM)      │
/// │  Rol:     Escucha el stream. Al pasar offline→online:        │
/// │           1. syncPendingOperations()  (cola FIFO de SQLite)  │
/// │           2. flush telemetría (scan, expiry, screen events)  │
/// │           3. recarga inventario para datos frescos            │
/// │  Expone:  isOnline, isSyncing para la UI                    │
/// ├──────────────────────────────────────────────────────────────┤
/// │  CAPA 3 — UI informativa                                     │
/// │  Widget:  _OfflineBanner (HomeScreen)                        │
/// │  - Offline:  fondo gris "Sin conexión — cambios se guardan"  │
/// │  - Syncing:  fondo naranja "Reconectado — sincronizando..."  │
/// │  - Online:   banner desaparece (SizedBox.shrink)             │
/// └──────────────────────────────────────────────────────────────┘
///
/// Anti-patrones evitados:
///   ✗ "Pantalla en blanco" → datos locales siempre visibles
///   ✗ "App bloqueada"      → operaciones se encolan en SQLite
///   ✗ "Spinner infinito"   → banner informa, no bloquea
///   ✗ "Pérdida de datos"   → pending_operations persiste entre reinicios
///   ✗ "Error críptico"     → mensaje humano en el banner
///
/// Flujo completo:
///   1. Usuario sin red agrega un alimento
///   2. addItem() falla en red → se encola en pending_operations
///   3. Banner muestra "Sin conexión — cambios se guardarán localmente"
///   4. Red regresa → ConnectivityProvider detecta online
///   5. syncPendingOperations() reintenta el create → éxito
///   6. Banner cambia a "Reconectado — sincronizando..." → desaparece
///   7. Inventario se recarga con datos frescos del backend
///
/// ═══════════════════════════════════════════════════════════════════
library;
