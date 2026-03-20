# Informe de Componentes Mock — Second Serving Frontend

> **Propósito:** Este documento detalla todo lo que actualmente funciona con datos mock
> en el frontend. Está pensado para que los compañeros del equipo sepan exactamente
> qué reemplazar con sus implementaciones reales del backend.

---

## 1. Configuración Central: `lib/config/api_config.dart`

Aquí se controla qué módulos usan mock y cuáles se conectan al backend real.

```dart
static const bool useMock = true;  // ← Switch global

// Controles por módulo (true = forzar mock aunque useMock sea false)
static const bool useMockAuth = true;
static const bool useMockInventory = true;
static const bool useMockRecipes = true;
static const bool useMockAnalytics = true;

static const String baseUrl = 'http://192.168.1.9:8000';
```

**Para conectar un módulo al backend real:**
1. Cambiar `useMock` a `false`
2. Cambiar el flag del módulo específico a `false`
3. Asegurar que `baseUrl` apunte al servidor correcto

---

## 2. Inyección de Servicios: `lib/main.dart`

Cada servicio se decide en `main.dart` línea 34-49:

```dart
final AuthService authService =
    (ApiConfig.useMock || ApiConfig.useMockAuth)
        ? MockAuthService()          // ← mock
        : AuthServiceImpl(apiClient); // ← real

// Igual para Inventory, Recipe, Analytics
```

Todos los servicios reales comparten el **mismo `ApiClient`**, que maneja el token JWT y los headers HTTP.

---

## 3. Archivos Mock

### 3.1 `lib/services/mock/mock_data.dart` — Datos falsos centralizados

| Dato | Descripción |
|------|-------------|
| `user` | Juan Pérez, `juan@example.com`, Bogotá, no premium |
| `inventoryItems` (8) | Leche, Pechuga de pollo, Tomates, Arroz integral, Yogur griego, Manzanas, Jugo de naranja, Galletas integrales |
| `recipeSummaries` (5) | Ensalada de aguacate, Smoothie de banano, Arroz con vegetales, Sopa de pollo, Panqueques con banano |
| `recipeDetails` (5) | Detalle completo de cada receta con ingredientes e instrucciones paso a paso |
| `recipeMatchedIngredients` | Mapa receta → ingredientes que coinciden con la despensa |
| `expiringIngredientNames` | Lista de nombres para los chips de ingredientes por vencer |
| `dashboard` | Savings (45,000 COP ahorrados), WasteSummary (18 consumidos, 4 descartados), UserSegment |
| `wasteTrends` (6) | Tendencias de desperdicio enero-marzo 2026 |
| `notificationPrefs` | 3 días antes de vencimiento, horas silenciosas 22-7, push habilitado |

### 3.2 `lib/services/mock/mock_auth_service.dart`

| Método | Qué hace en mock |
|--------|------------------|
| `login()` | Ignora credenciales, devuelve siempre `MockData.user` con token falso |
| `register()` | Crea usuario con datos del formulario, token falso |
| `logout()` | Limpia usuario en memoria |
| `getMe()` | Devuelve el usuario mock |

### 3.3 `lib/services/mock/mock_inventory_service.dart`

| Método | Qué hace en mock |
|--------|------------------|
| `getItems()` | Devuelve los 8 items estáticos, paginados en memoria |
| `getExpiringItems()` | Filtra items por `daysRemaining <= days` |
| `createItem()` | Genera ID con timestamp, agrega a la lista en memoria |
| `updateItem()` | Modifica item en la lista en memoria |
| `consumeItem()` | Cambia status a `consumed` en memoria |
| `discardItem()` | Cambia status a `discarded` o reduce cantidad en memoria |
| `deleteItem()` | Elimina de la lista en memoria |

> **Nota:** Los items creados por el escáner de recibos se guardan en esta lista en memoria y se pierden al cerrar la app.

### 3.4 `lib/services/mock/mock_recipe_service.dart`

| Método | Qué hace en mock |
|--------|------------------|
| `getSuggestions()` | Devuelve las 5 recetas estáticas |
| `getRecipes()` | Igual, con paginación |
| `getRecipeDetail(id)` | Busca en `MockData.recipeDetails[id]` |
| `interact()` | No hace nada (solo delay) |

### 3.5 `lib/services/mock/mock_analytics_service.dart`

| Método | Qué hace en mock |
|--------|------------------|
| `getDashboard()` | Devuelve siempre `MockData.dashboard` |
| `getSavings()` | Devuelve savings estáticos |
| `getWasteTrends()` | Devuelve 6 tendencias estáticas |
| `getSummary()` | Devuelve waste summary estático |
| `getSegment()` | Devuelve segmento `neutral` |

### 3.6 `lib/services/mock/mock_notification_service.dart`

- **Existe pero NO está inyectado** en `main.dart` ni en ningún provider.
- Habría que crear un `NotificationProvider` e inyectarlo si se necesita.

---

## 4. Pantalla de Login: `lib/screens/auth/login_screen.dart`

**Estado actual:** Los botones Login y Sign-up simplemente navegan a `/home` con `context.go('/home')`.

**No usa `AuthProvider`.** No envía credenciales al backend.

**Para conectar con auth real:**
1. Importar `provider` y `AuthProvider`
2. En el botón Login, llamar `context.read<AuthProvider>().login(email, password)`
3. Si éxito → `context.go('/home')`, si falla → mostrar error
4. Igual para Sign-up con `register()`
5. El `AuthProvider` ya tiene toda la lógica implementada (guardar token en SecureStorage, setear en ApiClient)

---

## 5. Splash Screen: `lib/screens/splash/splash_screen.dart`

**Estado actual:** Siempre navega a `/login` después de 3 segundos.

**Para conectar con auth real:** Debería llamar `AuthProvider.checkAuth()` para ver si hay token guardado y navegar directo a `/home` si ya está autenticado.

---

## 6. Servicios Reales (ya implementados, solo falta activarlos)

### `lib/services/auth_service.dart` — AuthServiceImpl

| Método | Endpoint | HTTP |
|--------|----------|------|
| `register()` | `POST /api/v1/auth/register` | `{email, full_name, password, ?location}` |
| `login()` | `POST /api/v1/auth/login` | `{email, password}` |
| `logout()` | `POST /api/v1/auth/logout` | — |
| `getMe()` | `GET /api/v1/auth/me` | — |

> Login y register automáticamente llaman `_client.setToken()` con el JWT recibido.

### `lib/services/inventory_service.dart` — InventoryServiceImpl

| Método | Endpoint | HTTP |
|--------|----------|------|
| `getItems()` | `GET /api/v1/inventory?skip=&limit=` | — |
| `getExpiringItems()` | `GET /api/v1/inventory/expiring?days=` | — |
| `createItem()` | `POST /api/v1/inventory` | `{name, category, quantity, unit, unit_price, purchase_date, expiry_date}` |
| `updateItem()` | `PUT /api/v1/inventory/{id}` | Campos parciales |
| `consumeItem()` | `PATCH /api/v1/inventory/{id}/consume` | — |
| `discardItem()` | `PATCH /api/v1/inventory/{id}/discard` | `{reason, ?quantity}` |
| `deleteItem()` | `DELETE /api/v1/inventory/{id}` | — |

### `lib/services/recipe_service.dart` — RecipeServiceImpl

| Método | Endpoint | HTTP |
|--------|----------|------|
| `getSuggestions()` | `GET /api/v1/recipes/suggestions?limit=` | — |
| `getRecipes()` | `GET /api/v1/recipes/?skip=&limit=` | — |
| `getRecipeDetail()` | `GET /api/v1/recipes/{id}` | — |
| `interact()` | `POST /api/v1/recipes/{id}/interact` | `{action: "cooked"\|"viewed"}` |

### `lib/services/analytics_service.dart` — AnalyticsServiceImpl

| Método | Endpoint | HTTP |
|--------|----------|------|
| `getDashboard()` | `GET /api/v1/analytics/dashboard?month=&year=` | — |
| `getSavings()` | `GET /api/v1/analytics/savings?month=&year=` | — |
| `getWasteTrends()` | `GET /api/v1/analytics/waste?months=` | — |
| `getSummary()` | `GET /api/v1/analytics/summary` | — |
| `getSegment()` | `GET /api/v1/analytics/segment` | — |

---

## 7. Providers (no necesitan cambios)

Los providers son agnósticos — no les importa si el servicio es mock o real:

| Provider | Archivo | Servicio |
|----------|---------|----------|
| `AuthProvider` | `lib/providers/auth_provider.dart` | `AuthService` |
| `InventoryProvider` | `lib/providers/inventory_provider.dart` | `InventoryService` |
| `RecipeProvider` | `lib/providers/recipe_provider.dart` | `RecipeService` |
| `AnalyticsProvider` | `lib/providers/analytics_provider.dart` | `AnalyticsService` |

---

## 8. Dependencias relevantes (`pubspec.yaml`)

| Paquete | Versión | Uso |
|---------|---------|-----|
| `http` | ^1.4.0 | Cliente HTTP para API real |
| `provider` | ^6.1.5 | State management / inyección |
| `go_router` | ^15.1.2 | Navegación |
| `flutter_secure_storage` | ^9.2.4 | Almacenar token JWT |
| `google_fonts` | ^6.2.1 | Tipografías Montserrat/Roboto |
| `image_picker` | ^1.2.1 | Captura de foto (OCR) |
| `google_mlkit_text_recognition` | ^0.15.1 | OCR local |
| `permission_handler` | ^12.0.1 | Permisos de cámara |
| `cached_network_image` | ^3.4.1 | Caché de imágenes |
| `fl_chart` | ^0.70.2 | Gráficos (disponible, no usado aún) |
| `intl` | ^0.20.2 | Formateo de fechas en español |

---

## 9. Checklist para Integración

### Auth (compañero de autenticación)
- [ ] Implementar `POST /api/v1/auth/register`
- [ ] Implementar `POST /api/v1/auth/login` (devolver `{access_token, token_type, user}`)
- [ ] Implementar `POST /api/v1/auth/logout`
- [ ] Implementar `GET /api/v1/auth/me`
- [ ] En el frontend: modificar `login_screen.dart` para usar `AuthProvider` en vez de `context.go('/home')`
- [ ] Cambiar `useMockAuth = false` en `api_config.dart`

### Inventario (compañero de despensa)
- [ ] Implementar `POST /api/v1/inventory` (crear item)
- [ ] Implementar `GET /api/v1/inventory` (listar items)
- [ ] Implementar `GET /api/v1/inventory/expiring` (items por vencer)
- [ ] Implementar `PATCH /api/v1/inventory/{id}/consume`
- [ ] Implementar `PATCH /api/v1/inventory/{id}/discard`
- [ ] Cambiar `useMockInventory = false` en `api_config.dart`

### Recetas (compañero de recetas)
- [ ] Implementar `POST /api/v1/recipes/seed` (cargar recetas)
- [ ] Implementar `GET /api/v1/recipes/suggestions` (sugerencias con scoring)
- [ ] Implementar `GET /api/v1/recipes/{id}` (detalle)
- [ ] Implementar `POST /api/v1/recipes/{id}/interact` (cocinar)
- [ ] Cambiar `useMockRecipes = false` en `api_config.dart`

### Analytics (compañero de analytics)
- [ ] Implementar `GET /api/v1/analytics/dashboard`
- [ ] Implementar `GET /api/v1/analytics/savings`
- [ ] Implementar `GET /api/v1/analytics/waste`
- [ ] Cambiar `useMockAnalytics = false` en `api_config.dart`

### Paso final
- [ ] Cambiar `useMock = false` en `api_config.dart`
- [ ] Confirmar que `baseUrl` apunta al servidor correcto
- [ ] Verificar que todos los endpoints devuelven los JSON en el formato esperado por los modelos en `lib/models/`
