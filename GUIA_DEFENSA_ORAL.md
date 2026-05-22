# Guía de Defensa Oral — Second Serving (Frontend)

## Tus 2 features implementadas
1. **OCR / Escaneo de recibos por cámara** → Patrón **Facade**
2. **Recetas inteligentes (Smart Recipes)** → Patrón **Strategy**

## Patrón transversal de la app
3. **MVVM (Model-View-ViewModel)** → Arquitectura base de ambas features

---

## PATRÓN TRANSVERSAL: MVVM (Model-View-ViewModel)

### ¿Qué es MVVM?
Separa la aplicación en tres capas: el **Model** (datos y lógica de negocio), la **View** (interfaz de usuario, completamente pasiva), y el **ViewModel** (estado de la UI + lógica de presentación). La View se enlaza al ViewModel mediante un mecanismo de observación reactiva: cuando el ViewModel cambia, la View se actualiza automáticamente.

### ¿Cómo se implementa en Flutter?
Flutter no tiene LiveData ni StateFlow como Android nativo, pero el paquete `provider` + `ChangeNotifier` cumple exactamente el mismo rol:

| Concepto MVVM | Equivalente en nuestra app |
|---|---|
| **View** | Widgets (`StatefulWidget` / `StatelessWidget`) — las pantallas |
| **ViewModel** | Clases que extienden `ChangeNotifier` — los Providers |
| **Model** | Clases de datos (`RecipeSummary`, `ScannedProduct`) + Services |
| **Data Binding** | `context.watch<Provider>()` — observación reactiva |
| **Acción del usuario** | `context.read<Provider>().metodo()` — envío de intenciones |

### MVVM en la Feature OCR — Código concreto

```
┌─────────────────────────────┐
│  VIEW: AddItemScreen        │  ← Solo UI, delega acciones
│  add_item_screen.dart       │
│                             │
│  · Muestra botón "Escanear" │
│  · Llama _handleCameraScan()│
│  · Muestra SnackBar si error│
│  · NO tiene lógica de       │
│    negocio                  │
└──────────┬──────────────────┘
           │ context.read<InventoryProvider>()
           ▼
┌─────────────────────────────┐
│  VIEWMODEL: InventoryProv.  │  ← Estado + lógica de presentación
│  inventory_provider.dart    │
│                             │
│  · _items (estado)          │
│  · _isLoading (estado UI)   │
│  · _error (estado UI)       │
│  · addItem() → servicio     │
│  · loadItems() → servicio   │
│  · notifyListeners() ←──── REACTIVO: la View se entera sola
└──────────┬──────────────────┘
           │ llama al servicio
           ▼
┌─────────────────────────────┐
│  MODEL:                     │  ← Datos + acceso a datos
│  · ScannedProduct (dato)    │
│  · ScanResult (dato)        │
│  · InventoryService (repo)  │
│  · ReceiptScannerService    │
└─────────────────────────────┘
```

**En el código — View (add_item_screen.dart):**
- Línea ~24: `final _scannerService = ReceiptScannerService();` — usa la Facade, no lógica directa
- Línea ~110: `final result = await _scannerService.scan();` — delega completamente
- Nunca hace cálculos, queries, ni transforma datos. Solo renderiza y delega.

**En el código — ViewModel (inventory_provider.dart):**
- Expone `List<InventoryItem> get items` — estado observable
- Expone `bool get isLoading` — la View lo usa para mostrar/ocultar spinner
- Expone `String? get error` — la View lo usa para mostrar errores
- `addItem()` → llama al servicio, actualiza `_items`, llama `notifyListeners()`
- `loadItems()` → llama al servicio, actualiza `_items`, llama `notifyListeners()`

**En el código — Model:**
- `ScannedProduct` — clase de datos pura (name, quantity, unit, price, category)
- `InventoryService` — interfaz que abstrae el acceso a datos (backend o mock)

**¿Dónde está el data binding?**
En `scanned_items_review_screen.dart` cuando hace:
```dart
final inventory = context.read<InventoryProvider>();
await inventory.addItem(...);
await inventory.loadItems();
```
Y en cualquier pantalla que haga `context.watch<InventoryProvider>()` — esa pantalla se reconstruye automáticamente cuando el Provider llama `notifyListeners()`.

### MVVM en la Feature Recetas — Código concreto

```
┌─────────────────────────────┐
│  VIEW: RecipesScreen        │  ← Solo UI
│  recipes_screen.dart        │
│                             │
│  · context.watch<RecipeProv>│ ← DATA BINDING: observa cambios
│  · Muestra lista de recetas │
│  · Muestra chips de Strategy│
│  · Llama provider.setStrat()│ ← Envía acción al ViewModel
│  · NO ordena, NO filtra     │
└──────────┬──────────────────┘
           │ observa / envía acciones
           ▼
┌─────────────────────────────┐
│  VIEWMODEL: RecipeProvider  │  ← Estado + lógica de presentación
│  recipe_provider.dart       │
│                             │
│  · _suggestions (estado)    │
│  · _isLoading (estado UI)   │
│  · _activeStrategy (estado) │
│  · loadSuggestions() → svc  │
│  · setStrategy() → reordena │
│  · notifyListeners() ←──── REACTIVO
└──────────┬──────────────────┘
           │ llama al servicio
           ▼
┌─────────────────────────────┐
│  MODEL:                     │
│  · RecipeSummary (dato)     │
│  · RecipeDetail (dato)      │
│  · RecipeService (repo)     │
│  · RecipeSortStrategy (algo)│
└─────────────────────────────┘
```

**En el código — View (recipes_screen.dart):**
- Línea ~29: `final provider = context.watch<RecipeProvider>();` — DATA BINDING, se suscribe a cambios
- Línea ~47: `_buildRecipeList(provider.suggestions)` — solo renderiza lo que el ViewModel le da
- El selector de estrategia solo hace `provider.setStrategy(strategy)` — delega al ViewModel
- La View **nunca** ordena recetas, nunca decide qué mostrar primero. Solo renderiza.

**En el código — ViewModel (recipe_provider.dart):**
- `_rawSuggestions` — datos crudos del backend (privados, la View no los ve)
- `_suggestions` — datos ya ordenados por la Strategy (públicos, la View los consume)
- `_activeStrategy` — estrategia actual (la View no sabe cuál es la lógica interna)
- `setStrategy()` → cambia estrategia, reordena, llama `notifyListeners()` → la View se actualiza sola
- `loadSuggestions()` → pide datos al servicio, aplica estrategia, `notifyListeners()`

**En el código — Model:**
- `RecipeSummary` — clase de datos con `fromJson()`, campos: id, name, inventoryMatches, prepTimeMinutes...
- `RecipeService` — interfaz abstracta de acceso a datos
- `RecipeSortStrategy` — algoritmos de ordenamiento (parte del Model/dominio, no de la UI)

### ¿Por qué MVVM y no MVC o MVP?

| Criterio | MVC | MVP | MVVM (el nuestro) |
|---|---|---|---|
| **¿La View conoce al Model?** | Sí (observa directamente) | No (el Presenter la actualiza) | No (solo observa al ViewModel) |
| **¿Binding reactivo?** | No | No (manual) | **Sí** — `context.watch` / `notifyListeners()` |
| **¿ViewModel conoce la View?** | N/A | Sí (tiene referencia a IView) | **No** — el Provider no importa ningún Widget |
| **¿Testeable sin UI?** | Parcial | Sí | **Sí** — el Provider se testea sin Flutter |

La clave es que `RecipeProvider` y `InventoryProvider` **nunca importan** ningún widget de Flutter UI. No saben quién los observa. Solo exponen estado y llaman `notifyListeners()`. Esto es la esencia de MVVM: el ViewModel es independiente de la View.

### Pregunta probable: ¿Cómo se ve MVVM en el registro en `main.dart`?

```dart
// main.dart líneas 154-159 — Registro de ViewModels en el árbol de widgets
MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: _authProvider),      // ViewModel Auth
    ChangeNotifierProvider.value(value: _inventoryProvider),  // ViewModel Inventario
    ChangeNotifierProvider.value(value: _recipeProvider),     // ViewModel Recetas
    ChangeNotifierProvider.value(value: _analyticsProvider),  // ViewModel Analytics
  ],
  child: MaterialApp.router(...),  // ← Todas las Views hijas pueden acceder
)
```

`MultiProvider` es el mecanismo que hace disponibles los ViewModels a todo el árbol de widgets. Cualquier View hija puede hacer `context.watch<RecipeProvider>()` para suscribirse, o `context.read<RecipeProvider>()` para enviar una acción puntual.

---

## PATRONES IMPLÍCITOS TRANSVERSALES: Singleton, DAO y DTO/VO

### Patrón Singleton — `LocalNotificationsService`

#### ¿Qué es Singleton?
Garantiza que una clase tenga **una sola instancia** en toda la app y provee un punto de acceso global a ella.

#### ¿Dónde está implementado?
En `lib/features/notifications/application/local_notifications_service.dart`:

```dart
class LocalNotificationsService {
  LocalNotificationsService._();                         // Constructor PRIVADO

  static final LocalNotificationsService instance =      // Instancia ÚNICA
      LocalNotificationsService._();
}
```

Los dos elementos clave del Singleton:
1. **Constructor privado** (`._()`) — nadie fuera de la clase puede hacer `LocalNotificationsService()`. Esto **impide** crear más de una instancia.
2. **Instancia estática final** (`instance`) — es la única instancia que existe. Todo el mundo accede a ella.

#### ¿Quién lo usa?
- `main.dart` línea 37: `await LocalNotificationsService.instance.initialize();`
- `add_item_screen.dart` línea ~287: `await LocalNotificationsService.instance.showExpiringSoonNotification(...)`
- `push_notifications_service.dart` línea 30: `LocalNotificationsService.instance`

Todas estas partes de la app usan la **misma** instancia. Si hubiera dos instancias, se crearían dos canales de notificación, se perderían listeners, etc.

#### ¿Por qué Singleton aquí?
Porque las notificaciones locales necesitan:
- Un solo canal de notificación registrado en el SO
- Un solo plugin `FlutterLocalNotificationsPlugin` inicializado
- Un solo `StreamController` para escuchar taps en las notificaciones

Si se crearan múltiples instancias, habría duplicación de canales, listeners perdidos, y notificaciones que no se capturan. Singleton garantiza consistencia.

#### Relación con mis features
Cuando el usuario escanea un recibo y guarda un producto que vence hoy o mañana, `AddItemScreen` llama `LocalNotificationsService.instance.showExpiringSoonNotification()`. Usa el Singleton para enviar la alerta inmediata. Es parte directa del flujo del OCR.

---

### Patrón DAO (Data Access Object) — Los servicios abstractos

#### ¿Qué es DAO?
Abstrae el acceso a la fuente de datos detrás de una interfaz. La capa de negocio solo conoce la interfaz, sin saber si detrás hay una API REST, una base de datos local, o datos en memoria.

#### ¿Dónde está implementado?
En cada módulo de la app:

**Feature Recetas** — `lib/features/recipes/services/recipe_service.dart`:
```dart
abstract class RecipeService {
  Future<List<RecipeSummary>> getSuggestions({int limit = 10});
  Future<RecipeListResponse> getRecipes({int skip = 0, int limit = 20});
  Future<RecipeDetail> getRecipeDetail(String id);
  Future<void> interact(String id, String action);
}
```

**Feature Inventario (OCR)** — `lib/features/inventory/services/inventory_service.dart`:
```dart
abstract class InventoryService {
  Future<InventoryListResponse> getItems({int skip = 0, int limit = 20});
  Future<List<InventoryItem>> getExpiringItems({int days = 3});
  Future<InventoryItem> createItem(Map<String, dynamic> data);
  Future<InventoryItem> updateItem(String id, Map<String, dynamic> data);
  Future<InventoryItem> consumeItem(String id);
  Future<InventoryItem> discardItem(String id, {required String reason, double? quantity});
  Future<void> deleteItem(String id);
}
```

**Feature Auth** — `lib/features/auth/services/auth_service.dart`:
```dart
abstract class AuthService {
  Future<AuthResponse> register({...});
  Future<AuthResponse> login({...});
  Future<User> getMe();
  Future<void> logout();
}
```

#### ¿Cómo se mapea al diagrama DAO de la clase?

```
RecipeProvider (lógica)  →  [RecipeService interface]  →  RecipeServiceImpl (API real)
                                      (DAO)

InventoryProvider        →  [InventoryService interface] → InventoryServiceImpl (API real)
                                      (DAO)
```

El Provider (ViewModel) **nunca** sabe si los datos vienen de una API, de una BD local, o de memoria. Solo llama métodos de la interfaz: `_service.getSuggestions()`, `_service.createItem()`.

#### ¿Cómo se decide la implementación concreta?
En `main.dart` (líneas 91-108), en el **Composition Root**:
```dart
final RecipeService recipeService =
    (ApiConfig.useMock || ApiConfig.useMockRecipes)
    ? MockRecipeService()               // Implementación A
    : RecipeServiceWithFallback(         // Implementación B (con fallback)
        RecipeServiceImpl(_apiClient),
        MockRecipeService(),
      );
```

Se inyecta la implementación concreta al crear el Provider. El Provider solo recibe `RecipeService` (la interfaz abstracta).

#### ¿Por qué DAO?
- **Desacoplamiento**: `RecipeProvider` no importa `http`, ni `ApiClient`, ni sabe de URLs. Solo conoce la interfaz.
- **Intercambiabilidad**: Se puede cambiar de backend sin tocar el Provider ni las pantallas.
- **Testeabilidad**: Para testear el Provider, se puede pasar un servicio falso que implementa la misma interfaz.

#### Relación con mis features
- En OCR: después de escanear productos, `ScannedItemsReviewScreen` llama `inventoryProvider.addItem()` → el Provider llama `_service.createItem()` → eso va a `InventoryServiceImpl` que hace `POST /api/v1/inventory`. La pantalla no sabe que es un POST HTTP.
- En Recetas: `RecipeProvider.loadSuggestions()` llama `_service.getSuggestions()` → eso va a `RecipeServiceImpl` que hace `GET /api/v1/recipes/suggestions`. El Provider no sabe que es un GET HTTP.

---

### Patrón DTO / VO (Data Transfer Object / Value Object) — Los modelos

#### ¿Qué es DTO/VO?
Objetos simples cuyo único propósito es **transportar datos entre capas** de la aplicación. No contienen lógica de negocio. Un VO (Value Object) es inmutable y su identidad se define por sus valores, no por referencia.

#### ¿Dónde está implementado?

**En Feature OCR:**

`ScannedProduct` — DTO mutable que viaja del parser a la pantalla de revisión:
```dart
class ScannedProduct {
  String name;          // mutable: el usuario puede editar
  double quantity;
  String unit;
  double? price;
  ItemCategory category;
  bool selected;
}
```

`ScanResult` — VO inmutable que encapsula el resultado del pipeline:
```dart
class ScanResult {
  final bool success;                    // final = inmutable
  final List<ScannedProduct> products;
  final String? rawText;
  final String? errorMessage;
}
```

`InventoryItem` — VO inmutable que representa un producto en la despensa:
```dart
class InventoryItem {
  final String id;
  final String name;
  final ItemCategory category;
  final double quantity;
  final DateTime expiryDate;
  final int daysRemaining;     // calculado por el backend
  // ... todos final (inmutable)

  factory InventoryItem.fromJson(Map<String, dynamic> json) { ... }
}
```

**En Feature Recetas:**

`RecipeSummary` — VO inmutable que viaja del backend a la UI:
```dart
class RecipeSummary {
  final String id;
  final String name;
  final RecipeCategory category;
  final int? prepTimeMinutes;
  final int inventoryMatches;    // clave para Strategy
  // ... todos final

  factory RecipeSummary.fromJson(Map<String, dynamic> json) { ... }
}
```

`RecipeDetail` — VO inmutable con el detalle completo:
```dart
class RecipeDetail {
  final String id;
  final String instructions;
  final List<RecipeIngredient> ingredients;
  // ... todos final

  factory RecipeDetail.fromJson(Map<String, dynamic> json) { ... }
}
```

#### ¿Cómo viajan los datos entre capas?

```
Backend (JSON)
    ↓  fromJson()
RecipeSummary (DTO/VO)     ← Capa Model
    ↓  pasado al Provider
RecipeProvider              ← Capa ViewModel
    ↓  expuesto via getter
RecipesScreen               ← Capa View (renderiza el dato)
```

Cada capa recibe y pasa el **mismo objeto inmutable**. No se transforma, no se clona, no se modifica. Solo se transporta. Eso es la esencia de un DTO.

#### ¿Por qué DTO/VO?
- **Contratos claros**: Cada campo está tipado. Si el backend manda un `category` como String, `fromJson()` lo convierte a `RecipeCategory` (enum). La View nunca recibe datos crudos.
- **Inmutabilidad**: Campos `final` = nadie puede corromper el dato accidentalmente después de crearlo.
- **Desacoplamiento**: Si el backend cambia el nombre de un campo JSON, solo se modifica `fromJson()`. Ni el Provider ni la View se tocan.

#### Relación con mis features
- En OCR: `ReceiptParserService.parse()` devuelve `List<ScannedProduct>` (DTO). El `ScanResult` (VO) envuelve esa lista + el texto crudo + el estado de éxito/fallo. Todo eso viaja desde el Subsistema C hasta `AddItemScreen` sin transformación.
- En Recetas: El backend devuelve JSON, `RecipeSummary.fromJson()` lo convierte en un VO tipado, el Provider lo recibe, la Strategy lo ordena (sin modificarlo, crea una nueva lista), y la View lo renderiza.

---

## PARTE 1: FEATURE OCR — Patrón Facade

### ¿Qué es el patrón Facade?
Una clase que provee una interfaz simplificada a un subsistema complejo. El cliente solo interactúa con la fachada, nunca con los subsistemas directamente.

### ¿Dónde está implementado?

```
AddItemScreen  →  ReceiptScannerService (FACADE)
                       ↓           ↓            ↓
                CameraService  TextRecognitionService  ReceiptParserService
                (Subsistema A)    (Subsistema B)         (Subsistema C)
```

### Archivos y qué hace cada uno

#### 1. `lib/features/inventory/services/camera_service.dart` — Subsistema A
- **Qué hace**: Maneja permisos de cámara y captura de foto.
- **Dependencias**: `image_picker`, `permission_handler`
- **Métodos**:
  - `requestPermission()` → pide permiso de cámara al SO con `Permission.camera.request()`
  - `takePhoto()` → abre la cámara con `ImagePicker().pickImage()`, devuelve un `File` o `null` si cancela

#### 2. `lib/features/inventory/services/text_recognition_service.dart` — Subsistema B
- **Qué hace**: Reconocimiento óptico de caracteres (OCR) on-device.
- **Dependencias**: `google_mlkit_text_recognition`
- **Método**:
  - `extractText(File image)` → crea un `InputImage`, lo procesa con `TextRecognizer(script: latin)`, devuelve el texto crudo o `null`
- **Dato clave**: El procesamiento es **on-device** (no se envía la imagen a ningún servidor). Esto es importante por privacidad.

#### 3. `lib/features/inventory/services/receipt_parser_service.dart` — Subsistema C
- **Qué hace**: Transforma texto crudo en una lista de productos estructurados.
- **Método principal**: `parse(String rawText)`
- **Lógica interna**:
  - `_isNoiseLine()` → filtra líneas irrelevantes (totales, fechas, NIT, encabezados del recibo) usando una lista de 30+ palabras clave
  - `_parseLine()` → para cada línea útil:
    - Extrae el **precio** con regex `\$?\s*([\d.,]+)\s*$` (número al final de la línea)
    - Extrae la **cantidad y unidad** con 3 regex diferentes (`x5`, `2kg`, `3 unidades`)
    - Limpia el **nombre** del producto (quita símbolos, capitaliza)
  - `_guessCategory()` → clasifica automáticamente el producto (lácteos, carnes, frutas, etc.) usando keywords
  - `_normalizeUnit()` → normaliza unidades (`gr` → `gramos`, `lt` → `litros`)

#### 4. `lib/features/inventory/services/receipt_scanner_service.dart` — LA FACADE
- **Qué hace**: Orquesta los 3 subsistemas en un solo método `scan()`.
- **Constructor**: Recibe los 3 subsistemas por inyección (con defaults).
  ```dart
  ReceiptScannerService({
    CameraService? camera,
    TextRecognitionService? ocr,
    ReceiptParserService? parser,
  })
  ```
- **Método `scan()`**: Pipeline de 4 pasos:
  1. `_camera.requestPermission()` → ¿tiene permiso? Si no → `ScanResult.failure('Permiso denegado')`
  2. `_camera.takePhoto()` → ¿tomó foto? Si no → `ScanResult.failure('Captura cancelada')`
  3. `_ocr.extractText(photo)` → ¿detectó texto? Si no → `ScanResult.failure('No se detectó texto')`
  4. `_parser.parse(rawText)` → ¿encontró productos? Si no → `ScanResult.failure('No se encontraron productos')`
  5. Si todo OK → `ScanResult.ok(products, rawText)`

- **Modelos de datos**:
  - `ScannedProduct` — producto individual con name, quantity, unit, price, category
  - `ScanResult` — resultado del pipeline con success/failure, lista de productos, texto crudo

#### 5. `lib/features/inventory/screens/add_item_screen.dart` — EL CLIENTE
- **Línea clave**: `final _scannerService = ReceiptScannerService();` (línea ~24)
- **Método `_handleCameraScan()`** (línea ~105): 
  - Solo llama `_scannerService.scan()` — NO conoce CameraService, ni ML Kit, ni el parser
  - Si éxito → navega a `ScannedItemsReviewScreen` con los productos
  - Si fallo → muestra SnackBar con el error
  - También registra telemetría (éxito/fallo) via `ScanTelemetryService`

#### 6. `lib/features/inventory/screens/scanned_items_review_screen.dart` — Pantalla de revisión
- Recibe `List<ScannedProduct>` y `rawText` del scan
- El usuario puede: seleccionar/deseleccionar productos, editar nombre/cantidad/categoría, eliminar
- Al guardar (`_saveAll`): llama `inventoryProvider.addItem()` por cada producto seleccionado, luego refresca inventario y recetas

### ¿Por qué Facade?
- **Sin Facade**: `AddItemScreen` tendría que importar `image_picker`, `permission_handler`, `google_mlkit`, hacer los 4 pasos manualmente, manejar errores de cada paso. La pantalla se llenaría de lógica que no le corresponde.
- **Con Facade**: `AddItemScreen` solo hace `_scannerService.scan()` y recibe un `ScanResult`. No sabe qué librería OCR se usa ni cómo se parsea el recibo. Si mañana cambiamos de Google ML Kit a otra librería, solo se modifica `TextRecognitionService` y nada más cambia.

---

## PARTE 2: FEATURE RECETAS — Patrón Strategy

### ¿Qué es el patrón Strategy?
Define una familia de algoritmos intercambiables encapsulados en clases separadas. El contexto delega la ejecución a la estrategia activa, que puede cambiarse en tiempo de ejecución sin modificar el contexto.

### ¿Dónde está implementado?

```
RecipesScreen (UI) ←observa→ RecipeProvider (CONTEXT)
                                    ↓ usa
                         RecipeSortStrategy (INTERFAZ)
                         ↙        ↓          ↘
              SortByIngredient  SortByQuick  SortByExpiring
              Match             Prep         Soon
```

### Archivos y qué hace cada uno

#### 1. `lib/features/recipes/strategies/recipe_sort_strategy.dart` — Interfaz + Estrategias

**Interfaz abstracta**:
```dart
abstract class RecipeSortStrategy {
  String get label;    // Nombre para mostrar en la UI
  String get icon;     // Emoji para el chip
  List<RecipeSummary> sort(List<RecipeSummary> recipes);
}
```

**3 estrategias concretas**:

| Estrategia | Criterio | Lógica |
|---|---|---|
| `SortByIngredientMatch` | Más ingredientes coinciden con la despensa | Ordena por `inventoryMatches` descendente |
| `SortByQuickPrep` | Más rápidas de preparar | Ordena por `prepTimeMinutes` ascendente (null = 999) |
| `SortByExpiringSoon` | Combina urgencia + coincidencia | Score = `inventoryMatches * 10 - prepTimeMinutes` |

#### 2. `lib/features/recipes/providers/recipe_provider.dart` — EL CONTEXT

- **Atributo**: `RecipeSortStrategy _activeStrategy` — la estrategia actual
- **Lista**: `availableStrategies` — las 3 estrategias instanciadas
- **Método `setStrategy()`**: Cambia la estrategia y reordena SIN llamar al backend:
  ```dart
  void setStrategy(RecipeSortStrategy strategy) {
    _activeStrategy = strategy;
    _suggestions = _activeStrategy.sort(_rawSuggestions);
    notifyListeners();
  }
  ```
- **En `loadSuggestions()`**: Después de obtener las recetas del servicio, aplica la estrategia activa:
  ```dart
  _rawSuggestions = await _service.getSuggestions(limit: limit);
  _suggestions = _activeStrategy.sort(_rawSuggestions);
  ```
- También es **Observer** (via `ChangeNotifier`): los widgets que hacen `context.watch<RecipeProvider>()` se re-renderizan automáticamente cuando cambia el estado.

#### 3. `lib/features/recipes/screens/recipes_screen.dart` — LA UI

- **Selector de estrategia** (`_buildStrategySelector`): Muestra 3 chips ("🥕 Más ingredientes", "⚡ Más rápidas", "⏰ Por vencer"). Al tocar uno, llama `provider.setStrategy(strategy)` y la lista se reordena inmediatamente.
- **Lista de recetas** (`_buildRecipeList`): Muestra `provider.suggestions` que ya viene ordenada según la estrategia activa.
- **`_RecipeCard`**: Cada tarjeta muestra imagen (placeholder local), nombre, tiempo de prep, coincidencias de ingredientes, y botón "Ver receta".

#### 4. `lib/features/recipes/models/recipe.dart` — Modelos de datos

- **`RecipeSummary`**: Lo que usa Strategy para ordenar. Campos clave:
  - `inventoryMatches` — cuántos ingredientes del inventario usa esta receta
  - `prepTimeMinutes` — tiempo de preparación
  - `category` — tipo de receta (desayuno, almuerzo, etc.)
- **`RecipeDetail`**: Detalle completo con `instructions`, `ingredients`, etc.
- Ambos tienen `fromJson()` para deserializar respuestas del backend.

#### 5. `lib/features/recipes/services/recipe_service.dart` — Servicio

- Interfaz abstracta `RecipeService` con métodos: `getSuggestions`, `getRecipes`, `getRecipeDetail`, `interact`
- `RecipeServiceImpl` → llama al backend real vía `ApiClient`
- `RecipeServiceWithFallback` → intenta backend real, si falla usa datos de respaldo

### ¿Por qué Strategy?
- **Sin Strategy**: Si quisieras cambiar el orden de las recetas tendrías un `if/else` o `switch` gigante dentro del Provider con toda la lógica mezclada. Cada nuevo criterio de orden requeriría modificar esa función.
- **Con Strategy**: Cada algoritmo de ordenamiento está encapsulado en su propia clase. Para agregar un nuevo criterio (ej: "Por calorías") solo creas `SortByCalories implements RecipeSortStrategy` y la agregas a `availableStrategies`. No modificas nada existente. Esto respeta el **principio Open/Closed**.

---

## PARTE 3: FLUJO COMPLETO DE DATOS

### ¿Cómo se conectan las features entre sí?

```
1. Usuario escanea recibo (OCR Feature)
   AddItemScreen → ReceiptScannerService.scan()
                      → CameraService.takePhoto()
                      → TextRecognitionService.extractText()
                      → ReceiptParserService.parse()
                   ← ScanResult con List<ScannedProduct>

2. Usuario revisa y guarda productos
   ScannedItemsReviewScreen → InventoryProvider.addItem() por cada producto
                            → InventoryProvider.loadItems()
                            → RecipeProvider.loadSuggestions()  ← CONEXIÓN

3. Recetas se actualizan automáticamente
   RecipeProvider.loadSuggestions()
     → RecipeService.getSuggestions()  (backend busca recetas según inventario)
     → _activeStrategy.sort(recetas)   (Strategy reordena según criterio)
     → notifyListeners()               (Observer notifica a RecipesScreen)

4. RecipesScreen se re-renderiza con las recetas nuevas, ordenadas
```

### ¿Dónde vive cada cosa? (main.dart)

En `main.dart` (líneas 86-118) está la **composición** de toda la app:
- Se crea `ApiClient` (cliente HTTP centralizado)
- Se crean los servicios (Auth, Inventory, Recipe, Analytics)
- Se inyectan en los Providers
- Los Providers se registran en `MultiProvider` (líneas 154-159) para que toda la app los acceda via `context.read<>()` o `context.watch<>()`

---

## PARTE 4: PREGUNTAS PROBABLES DEL PROFESOR

### Sobre Facade (OCR)

**P: ¿Por qué elegiste Facade?**
R: Porque el escaneo de recibos involucra 3 subsistemas complejos (cámara, OCR, parsing) que no deberían estar acoplados a la pantalla. La Facade oculta esa complejidad: la pantalla solo llama `scan()` y recibe un resultado estructurado.

**P: ¿Qué pasa si falla la cámara?**
R: El pipeline se detiene en el primer error. Si la cámara no tiene permiso, devuelve `ScanResult.failure('Permiso de cámara denegado')`. Si el usuario cancela la foto, devuelve `'Captura cancelada'`. Nunca se llega al OCR si no hay foto.

**P: ¿Cómo funciona el OCR?**
R: Google ML Kit Text Recognition procesa la imagen **on-device** (sin enviar datos a la nube). Recibe un `InputImage.fromFile()` y devuelve un `RecognizedText` con todo el texto detectado. Usamos `TextRecognitionScript.latin` porque los recibos están en español.

**P: ¿Cómo sabes qué línea del recibo es un producto y cuál es ruido?**
R: `ReceiptParserService._isNoiseLine()` tiene una lista de 30+ palabras clave de ruido (total, subtotal, IVA, fecha, cajero, etc.). Si la línea contiene alguna, se descarta. También descarta líneas que son solo números/símbolos.

**P: ¿Cómo se extrae el precio?**
R: Con regex `\$?\s*([\d.,]+)\s*$` que busca un número al final de la línea (con o sin $). Solo acepta valores >= 100 (para evitar confundir cantidades con precios en pesos colombianos).

**P: ¿Cómo clasifica la categoría automáticamente?**
R: `_guessCategory()` tiene un mapa de categoría → lista de keywords. Si el nombre del producto contiene "leche" o "queso" → dairy. Si contiene "pollo" o "carne" → meat. Etc. Si no matchea nada → other.

**P: ¿Qué ventaja tiene Facade sobre meter todo en una clase?**
R: Si mañana cambio de Google ML Kit a otra librería de OCR, solo modifico `TextRecognitionService`. Si necesito agregar galería de fotos además de cámara, solo modifico `CameraService`. La fachada y la pantalla no cambian. Cada subsistema se puede testear y modificar de forma independiente.

### Sobre Strategy (Recetas)

**P: ¿Por qué elegiste Strategy?**
R: Porque necesitábamos múltiples criterios de ordenamiento de recetas y el usuario puede cambiar entre ellos en tiempo real. Strategy permite encapsular cada algoritmo en su propia clase y swappearlos sin modificar el Provider.

**P: ¿Cómo cambia de estrategia el usuario?**
R: En la pantalla de recetas hay 3 chips (Más ingredientes, Más rápidas, Por vencer). Al tocar uno, se llama `provider.setStrategy(strategy)`. El Provider reordena la lista con la nueva estrategia y llama `notifyListeners()`. La UI se actualiza automáticamente.

**P: ¿Vuelve a llamar al backend al cambiar estrategia?**
R: No. Las recetas ya están en memoria (`_rawSuggestions`). `setStrategy()` solo reordena la lista localmente. Esto es más rápido y no gasta datos ni llamadas al servidor.

**P: ¿Cómo sabe la app qué recetas sugerir basándose en la despensa?**
R: El backend tiene un endpoint `GET /api/v1/recipes/suggestions` que recibe el token del usuario. El backend cruza los ingredientes del inventario del usuario con los ingredientes de las recetas y devuelve las que más coincidencias tienen en el campo `inventory_matches`.

**P: ¿Cómo agregarías un nuevo criterio de ordenamiento?**
R: Creo una nueva clase que implemente `RecipeSortStrategy`, por ejemplo `SortByCalories`, y la agrego a la lista `availableStrategies` en el Provider. No toco nada más. Esto es el principio Open/Closed: abierto a extensión, cerrado a modificación.

**P: ¿Qué relación hay entre el OCR y las recetas?**
R: Cuando el usuario escanea un recibo y guarda los productos, `ScannedItemsReviewScreen._saveAll()` llama `recipeProvider.loadSuggestions()` para refrescar las recetas. Así las nuevas sugerencias ya reflejan los productos recién agregados a la despensa.

### Sobre MVVM (Arquitectura transversal)

**P: ¿Qué patrón arquitectónico usa tu app?**
R: MVVM. Las pantallas (View) solo renderizan UI y delegan acciones. Los Providers (ViewModel) manejan el estado y la lógica de presentación con `ChangeNotifier`. Los Models son las clases de datos y los servicios. El binding reactivo lo da `context.watch<>()` que hace que la View se actualice sola cuando el ViewModel cambia.

**P: ¿Dónde está el ViewModel del OCR?**
R: `InventoryProvider`. Expone `items`, `isLoading`, `error`. Cuando `AddItemScreen` guarda productos escaneados, llama `inventoryProvider.addItem()` y luego `loadItems()`. El Provider actualiza su estado interno y llama `notifyListeners()`. Cualquier pantalla que observe ese Provider se actualiza automáticamente.

**P: ¿Dónde está el ViewModel de Recetas?**
R: `RecipeProvider`. Expone `suggestions`, `isLoading`, `activeStrategy`. `RecipesScreen` hace `context.watch<RecipeProvider>()` para suscribirse. Cuando el usuario cambia de estrategia, el Provider reordena y llama `notifyListeners()`, y la lista se refresca sola sin que la View haga nada.

**P: ¿Por qué MVVM y no MVC?**
R: Porque en MVC la Vista y el Controlador están acoplados, y no hay binding reactivo. En MVVM, el Provider (ViewModel) no conoce ni importa ningún widget. Solo expone estado y notifica cambios. Esto lo hace más testeable y desacoplado. Además, Flutter con Provider implementa naturalmente el patrón de observación reactiva que MVVM requiere.

**P: ¿El Provider conoce a la pantalla?**
R: No. `RecipeProvider` nunca importa `RecipesScreen`. No sabe quién lo observa. Solo llama `notifyListeners()` y el framework se encarga de notificar a todos los widgets suscritos. Esto es la separación clave de MVVM.

**P: ¿Cómo se inyectan las dependencias?**
R: Inyección manual en `main.dart`. Se crean los servicios, se pasan a los Providers (ViewModels), y los Providers se registran en `MultiProvider`. Esto es el **Composition Root** de la app. Cualquier widget hijo puede acceder al ViewModel con `context.read<>()` o `context.watch<>()`.

### Sobre Singleton

**P: ¿Dónde usas Singleton?**
R: `LocalNotificationsService`. Tiene constructor privado (`._()`) y una instancia estática final (`instance`). Toda la app accede a la misma instancia para enviar notificaciones locales. Si hubiera múltiples instancias, se duplicarían canales de notificación y se perderían listeners.

**P: ¿Por qué Singleton y no simplemente pasar la instancia por constructor?**
R: Porque las notificaciones locales son un recurso del sistema operativo. Solo puede haber un plugin inicializado y un canal registrado. Singleton garantiza eso a nivel de código. Además, se usa desde muchas partes (main, pantalla de añadir item, servicio de push) y pasarla por constructor a todas sería innecesariamente complejo.

**P: ¿Cuál es la diferencia entre `static final instance` y una variable global?**
R: Con Singleton, el constructor es privado — nadie puede crear otra instancia accidentalmente. Una variable global no tiene esa protección. Además, la instancia se crea de forma lazy (al primer acceso) o al inicio controlado, y encapsula su estado internamente.

### Sobre DAO

**P: ¿Dónde usas DAO?**
R: En todos los servicios. `RecipeService`, `InventoryService`, `AuthService` son interfaces abstractas que definen operaciones de datos sin exponer la fuente. El Provider solo conoce la interfaz, nunca la implementación concreta.

**P: ¿Qué ventaja tiene usar una interfaz abstracta para los servicios?**
R: Desacoplamiento. `RecipeProvider` no sabe si los datos vienen de una API REST, una base de datos local, o un archivo JSON. Solo llama `_service.getSuggestions()`. Si mañana cambio el backend de REST a GraphQL, solo creo una nueva implementación de `RecipeService`. Ni el Provider ni las pantallas se tocan.

**P: ¿Dónde se decide qué implementación usar?**
R: En `main.dart`, el Composition Root. Ahí se instancia `RecipeServiceImpl(apiClient)` o una alternativa, y se inyecta al Provider por constructor. El Provider recibe `RecipeService` (la interfaz), nunca la clase concreta.

### Sobre DTO / VO

**P: ¿Qué son los modelos como RecipeSummary e InventoryItem?**
R: Son DTOs/Value Objects. Transportan datos entre capas sin lógica de negocio. Todos sus campos son `final` (inmutables). Tienen un factory `fromJson()` para deserializar la respuesta del backend en un objeto tipado de Dart.

**P: ¿Por qué fromJson() y no parsear el JSON directamente en el Provider?**
R: Porque el DTO encapsula la transformación. Si el backend cambia el nombre de un campo (ej: `prep_time` a `preparation_minutes`), solo modifico `fromJson()` en el modelo. El Provider y la View no cambian. Además, `fromJson()` convierte tipos: `category` llega como String del JSON y se convierte a `RecipeCategory` (enum tipado).

**P: ¿Cuál es la diferencia entre DTO y VO?**
R: El VO es inmutable y se compara por valor. En nuestro código, `RecipeSummary`, `RecipeDetail`, `InventoryItem` son VOs (todos sus campos son `final`). `ScannedProduct` es más un DTO porque es mutable: el usuario puede editarlo en la pantalla de revisión antes de guardarlo.

### Sobre otros temas

**P: ¿Cómo se registra si un escaneo falló?**
R: `ScanTelemetryService` registra cada escaneo (éxito o fallo) con timestamp, razón de fallo, duración y productos detectados. Se guarda localmente en `SharedPreferences` y se intenta enviar al backend vía `POST /api/v1/telemetry/scan-events`.

---

## RESUMEN DE PATRONES — Tabla rápida para memorizar

| # | Patrón | Tipo | Archivo clave | En una frase |
|---|---|---|---|---|
| 1 | **MVVM** | Arquitectura UI | Providers + Screens | View observa ViewModel via `context.watch`, ViewModel no conoce la View |
| 2 | **Facade** | GoF Estructural | `receipt_scanner_service.dart` | `scan()` oculta 3 subsistemas (cámara, OCR, parser) |
| 3 | **Strategy** | GoF Comportamiento | `recipe_sort_strategy.dart` | 3 algoritmos de orden intercambiables en runtime |
| 4 | **Singleton** | GoF Creacional | `local_notifications_service.dart` | Constructor privado + `instance` estática = una sola instancia |
| 5 | **DAO** | Acceso a Datos | `recipe_service.dart`, `inventory_service.dart` | Interfaz abstracta que oculta si es API, BD o memoria |
| 6 | **DTO/VO** | Acceso a Datos | `recipe.dart`, `inventory_item.dart` | Objetos inmutables con `fromJson()` que transportan datos entre capas |
