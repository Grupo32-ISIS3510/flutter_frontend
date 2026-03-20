# Guía de Autenticación — AuthProvider y JWT

## Arquitectura general

```
┌─────────────────────────────────────────────────────────┐
│                      main.dart                          │
│                                                         │
│  ApiClient (instancia única) ◄── token compartido       │
│      │                                                  │
│      ├── AuthServiceImpl(apiClient)                     │
│      ├── InventoryServiceImpl(apiClient)                │
│      ├── RecipeServiceImpl(apiClient)                   │
│      └── AnalyticsServiceImpl(apiClient)                │
│                                                         │
│  AuthProvider(authService, apiClient)                    │
│      │                                                  │
│      ├── Guarda el JWT en FlutterSecureStorage          │
│      ├── Inyecta el JWT en ApiClient.setToken()         │
│      └── Notifica cambios al router (refreshListenable) │
└─────────────────────────────────────────────────────────┘
```

La clave es que **todos los servicios comparten la misma instancia de `ApiClient`**. Cuando `AuthProvider` obtiene un JWT (login, registro o restauración desde storage), lo inyecta en `ApiClient` con `setToken()`. A partir de ahí, **todas** las peticiones HTTP de cualquier servicio incluyen el header `Authorization: Bearer <token>` automáticamente.

---

## Flujo del token paso a paso

### 1. Inicio de la app (restauración de sesión)

```
SplashScreen.initState()
  └── AuthProvider.checkAuth()
        ├── Lee token de FlutterSecureStorage
        ├── Si existe → apiClient.setToken(token) + authService.getMe()
        │     └── Si getMe() funciona → estado = authenticated
        │     └── Si getMe() falla (401) → limpia token de storage y ApiClient
        └── Si no existe → estado = unauthenticated
```

### 2. Login

```
LoginScreen → AuthProvider.login(email, password)
  └── AuthServiceImpl.login()
        ├── POST /api/v1/auth/login
        ├── Recibe { access_token, user }
        └── apiClient.setToken(accessToken) ← el token queda en ApiClient
  └── AuthProvider guarda el token en FlutterSecureStorage
  └── estado = authenticated → notifyListeners()
  └── GoRouter detecta el cambio → redirige a /home
```

### 3. Registro

Mismo flujo que login, pero con `POST /api/v1/auth/register`.

### 4. Peticiones autenticadas (automático)

Una vez que el token está en `ApiClient`, **no necesitas hacer nada más**. Todos los servicios que usan ese `ApiClient` ya envían el header automáticamente:

```dart
// Dentro de ApiClient
Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  if (_token != null) 'Authorization': 'Bearer $_token',
};
```

Ejemplo: cuando `InventoryProvider` llama a `loadExpiringItems()`, internamente hace:

```dart
final response = await _client.get('/api/v1/inventory/expiring', ...);
// _client es el mismo ApiClient → ya tiene el token → envía el Bearer header
```

### 5. Logout

```
AuthProvider.logout()
  ├── POST /api/v1/auth/logout (notifica al backend)
  ├── apiClient.setToken(null) ← limpia el header
  ├── FlutterSecureStorage.delete('auth_token')
  └── estado = unauthenticated → GoRouter redirige a /login
```

---

## Cómo usar AuthProvider en las vistas

### Leer datos del usuario autenticado

```dart
// Lectura reactiva (se reconstruye si cambia)
final auth = context.watch<AuthProvider>();
final userName = auth.user?.fullName ?? 'Usuario';
final isLoggedIn = auth.isAuthenticated;

// Lectura puntual (no se reconstruye)
final auth = context.read<AuthProvider>();
```

### Ejemplo: mostrar nombre en un header

```dart
Widget build(BuildContext context) {
  final auth = context.watch<AuthProvider>();
  final name = auth.user?.fullName.split(' ').first ?? 'Usuario';

  return Text('Hola, $name');
}
```

### Ejemplo: botón de logout

```dart
IconButton(
  icon: const Icon(Icons.logout),
  onPressed: () => context.read<AuthProvider>().logout(),
)
```

### Ejemplo: pantalla que necesita datos autenticados

No necesitas pasar el token manualmente. Solo usa el provider del módulo correspondiente:

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Estos providers usan el ApiClient compartido,
    // que ya tiene el JWT inyectado.
    context.read<InventoryProvider>().loadExpiringItems(days: 5);
    context.read<AnalyticsProvider>().loadDashboard();
  });
}
```

---

## Protección de rutas con GoRouter

El router usa `AuthProvider` como `refreshListenable` para reaccionar a cambios de autenticación:

```dart
GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,  // escucha notifyListeners()
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute = location == '/login' || location == '/register';

      // No autenticado intentando acceder a ruta protegida → /login
      if (!isAuthenticated && !isAuthRoute && !isSplash) return '/login';

      // Autenticado intentando acceder a login/register → /home
      if (isAuthenticated && (isAuthRoute || isSplash)) return '/home';

      return null; // sin redirección
    },
    routes: [ ... ],
  );
}
```

Esto significa que:
- Si el token expira y `checkAuth()` cambia el estado a `unauthenticated`, el router automáticamente redirige a `/login`.
- Si un usuario autenticado intenta navegar a `/login`, el router lo lleva a `/home`.

---

## Persistencia del token

| Evento | Acción sobre el token |
|---|---|
| Login exitoso | Se guarda en `FlutterSecureStorage` y en `ApiClient` |
| Registro exitoso | Se guarda en `FlutterSecureStorage` y en `ApiClient` |
| App se abre | `checkAuth()` lee de `FlutterSecureStorage` y restaura en `ApiClient` |
| Token inválido (401 en getMe) | Se borra de `FlutterSecureStorage` y de `ApiClient` |
| Logout | Se borra de `FlutterSecureStorage` y de `ApiClient` |
| App se cierra | El token **persiste** en `FlutterSecureStorage` |

---

## Patrón de arquitectura: Feature-Based Structure

El proyecto sigue una **arquitectura basada en features** (módulos por dominio). En lugar de agrupar archivos por tipo (`screens/`, `services/`, `models/` en la raíz), cada funcionalidad del negocio es una carpeta independiente con su propia estructura interna.

### ¿Por qué este patrón?

| Beneficio | Descripción |
|---|---|
| **Cohesión** | Todo lo relacionado a un dominio (auth, inventory, recipes...) vive junto. No necesitas saltar entre carpetas lejanas para entender un módulo. |
| **Escalabilidad** | Agregar un nuevo feature (ej. `notifications/`) es crear una carpeta con su estructura interna, sin tocar las demás. |
| **Independencia** | Cada feature puede evolucionar por separado. Si `recipes` cambia de API, solo tocas `features/recipes/`. |
| **Navegabilidad** | Con solo ver `lib/features/` sabes qué dominios existen en la app. |

### Las 3 capas del proyecto

```
lib/
├── core/        → Infraestructura compartida (red, config, routing)
├── features/    → Módulos de negocio (auth, inventory, recipes...)
├── shared/      → Modelos y servicios transversales
└── main.dart    → Punto de entrada y wiring de dependencias
```

**`core/`** — Código de infraestructura que no pertenece a ningún feature específico. Aquí viven el cliente HTTP, la configuración de URLs, el tema visual y el router.

**`features/`** — Cada subdirectorio es un dominio de negocio. Internamente cada feature sigue la misma estructura de 4 subcarpetas:

| Subcarpeta | Responsabilidad |
|---|---|
| `models/` | Clases de datos (DTOs, entidades). Solo datos, sin lógica de UI ni red. |
| `services/` | Comunicación con el backend (API calls). Contiene la interfaz abstracta + implementación real + mock. |
| `providers/` | Estado reactivo (`ChangeNotifier`). Conecta servicios con la UI. Es lo que los widgets consumen. |
| `screens/` | Widgets de pantalla completa. Usan `context.watch/read` para acceder a los providers. |

**`shared/`** — Enums, modelos y servicios que son utilizados por múltiples features (ej. `ItemCategory`, `ItemStatus`).

### Convención dentro de cada feature

```
features/inventory/
├── models/
│   └── inventory_item.dart       ← InventoryItem, InventoryListResponse
├── services/
│   ├── inventory_service.dart    ← abstract InventoryService + InventoryServiceImpl
│   └── mock_inventory_service.dart
├── providers/
│   └── inventory_provider.dart   ← InventoryProvider extends ChangeNotifier
└── screens/
    ├── inventory_screen.dart     ← pantalla principal del inventario
    ├── add_item_screen.dart      ← formulario para agregar item
    └── scanned_items_review_screen.dart
```

El flujo de datos siempre es: **Screen → Provider → Service → ApiClient → Backend**

```
┌──────────┐    watch/read    ┌──────────┐    await    ┌──────────┐    HTTP    ┌───────────┐
│  Screen  │ ──────────────► │ Provider │ ─────────► │ Service  │ ────────► │ ApiClient │
│  (UI)    │ ◄────────────── │ (State)  │ ◄───────── │ (API)    │ ◄──────── │ (Network) │
└──────────┘  notifyListeners └──────────┘   return    └──────────┘  response  └───────────┘
```

---

## Estructura completa del proyecto

```
lib/
│
├── main.dart                                # Punto de entrada: crea ApiClient,
│                                            # servicios, providers y el router.
│
├── core/                                    # ── INFRAESTRUCTURA ──
│   ├── config/
│   │   ├── api_config.dart                  # URLs de endpoints, flags mock/real,
│   │   │                                    # timeout, baseUrl
│   │   ├── app_theme.dart                   # Colores (AppColors), tema Material
│   │   └── format_helpers.dart              # Formateo de moneda, fechas, etc.
│   │
│   ├── network/
│   │   └── api_client.dart                  # Cliente HTTP único. Mantiene el JWT
│   │                                        # y lo envía en cada request.
│   │
│   └── router/
│       └── router.dart                      # GoRouter con redirect guards de auth
│                                            # y refreshListenable al AuthProvider.
│
├── features/                                # ── MÓDULOS DE NEGOCIO ──
│   │
│   ├── auth/                                # Autenticación y sesión
│   │   ├── models/
│   │   │   └── user.dart                    # User, AuthResponse
│   │   ├── providers/
│   │   │   └── auth_provider.dart           # Estado de auth, JWT, FlutterSecureStorage
│   │   ├── services/
│   │   │   ├── auth_service.dart            # Interface + AuthServiceImpl (login, register, getMe)
│   │   │   └── mock_auth_service.dart       # Mock para desarrollo sin backend
│   │   └── screens/
│   │       ├── splash_screen.dart           # Pantalla inicial, restaura sesión
│   │       ├── login_screen.dart            # Formulario de login
│   │       └── register_screen.dart         # Formulario de registro
│   │
│   ├── home/                                # Dashboard principal
│   │   └── screens/
│   │       ├── home_screen.dart             # Bottom navigation bar + tabs
│   │       └── dashboard_screen.dart        # Vista "Inicio": Comer Primero,
│   │                                        # estadísticas, plan del día
│   │
│   ├── inventory/                           # Gestión de inventario
│   │   ├── models/
│   │   │   └── inventory_item.dart          # InventoryItem, InventoryListResponse
│   │   ├── providers/
│   │   │   └── inventory_provider.dart      # CRUD de items, items por vencer
│   │   ├── services/
│   │   │   ├── inventory_service.dart       # Interface + InventoryServiceImpl
│   │   │   ├── mock_inventory_service.dart  # Mock para desarrollo sin backend
│   │   │   └── receipt_scanner_service.dart  # Escaneo de recibos
│   │   └── screens/
│   │       ├── inventory_screen.dart        # Lista de items del inventario
│   │       ├── add_item_screen.dart         # Formulario para agregar item
│   │       └── scanned_items_review_screen.dart  # Revisión de items escaneados
│   │
│   ├── recipes/                             # Recetas sugeridas
│   │   ├── config/
│   │   │   └── recipe_images.dart           # URLs de imágenes de recetas
│   │   ├── models/
│   │   │   └── recipe.dart                  # Recipe, RecipeSummary
│   │   ├── providers/
│   │   │   └── recipe_provider.dart         # Sugerencias, detalle, interacciones
│   │   ├── services/
│   │   │   ├── recipe_service.dart          # Interface + RecipeServiceImpl
│   │   │   └── mock_recipe_service.dart     # Mock para desarrollo sin backend
│   │   └── screens/
│   │       ├── recipes_screen.dart          # Lista de recetas
│   │       └── recipe_detail_screen.dart    # Detalle de una receta
│   │
│   ├── analytics/                           # Estadísticas y ahorro
│   │   ├── models/
│   │   │   └── analytics.dart              # Savings, WasteStats, Dashboard
│   │   ├── providers/
│   │   │   └── analytics_provider.dart     # Dashboard, savings, waste
│   │   ├── services/
│   │   │   ├── analytics_service.dart      # Interface + AnalyticsServiceImpl
│   │   │   └── mock_analytics_service.dart # Mock para desarrollo sin backend
│   │   └── screens/
│   │       └── analytics_screen.dart       # Vista de estadísticas
│   │
│   └── profile/                            # Perfil del usuario
│       └── screens/
│           └── profile_screen.dart         # Vista de perfil y configuración
│
└── shared/                                  # ── CÓDIGO TRANSVERSAL ──
    ├── models/
    │   ├── enums.dart                       # ItemCategory, ItemStatus,
    │   │                                    # RecipeCategory, DiscardReason, etc.
    │   └── notification_preferences.dart    # Preferencias de notificaciones
    └── services/
        ├── mock_data.dart                   # Datos de prueba compartidos
        ├── notification_service.dart        # Interface de notificaciones
        └── mock_notification_service.dart   # Mock de notificaciones
```

---

## Cómo agregar un nuevo feature

1. Crea la carpeta `lib/features/<nombre>/` con las subcarpetas necesarias:

```
lib/features/shopping/
├── models/
│   └── shopping_list.dart
├── services/
│   ├── shopping_service.dart
│   └── mock_shopping_service.dart
├── providers/
│   └── shopping_provider.dart
└── screens/
    └── shopping_screen.dart
```

2. Agrega los endpoints en `core/config/api_config.dart`.

3. Registra el provider en `main.dart` dentro del `MultiProvider`:

```dart
ChangeNotifierProvider(create: (_) => ShoppingProvider(shoppingService)),
```

4. Agrega la ruta en `core/router/router.dart` si el feature tiene pantalla propia.

El `ApiClient` compartido ya inyecta el JWT en todas las peticiones — no necesitas pasar el token al nuevo servicio.

---

## Resumen

1. **No pases el JWT manualmente** a cada servicio o vista. El `ApiClient` compartido lo maneja.
2. **Usa `context.watch<AuthProvider>()`** para reaccionar a cambios de auth en la UI.
3. **Usa `context.read<AuthProvider>()`** para acciones puntuales (login, logout).
4. **Las rutas se protegen solas** gracias al `redirect` del `GoRouter` + `refreshListenable`.
5. **El token persiste** entre cierres de app gracias a `FlutterSecureStorage`.
