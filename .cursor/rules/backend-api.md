# Second Serving — Contrato Completo del Backend API

> **Copia este archivo en tu proyecto frontend como `.cursor/rules/backend-api.md`**
> para que Cursor conozca todo sobre el backend al desarrollar el frontend.

## Información General

- **Nombre:** Second Serving
- **Propósito:** Backend para app móvil de reducción de desperdicio alimentario
- **Framework:** FastAPI 0.111 (Python)
- **Base de datos:** PostgreSQL 15
- **Autenticación:** JWT Bearer Token (HS256, expiración configurable, default 60 min)
- **Base URL:** `http://localhost:8000` (desarrollo) / IP de EC2 (producción)
- **Docs interactivos:** `GET /docs` (Swagger UI), `GET /redoc` (ReDoc)
- **Moneda:** Pesos colombianos (COP)

---

## Formato de Respuestas

### Respuesta exitosa (algunos endpoints)
```json
{ "status": "success", "data": { ... }, "error": null }
```

### Respuesta de error estándar
```json
{
  "status": 400,
  "code": "ERROR_CODE",
  "message": "Descripción del error en español",
  "details": null,
  "timestamp": "2026-03-16T10:00:00+00:00"
}
```

### Error de validación (422)
```json
{
  "status": 422,
  "code": "VALIDATION_ERROR",
  "message": "Los datos enviados contienen errores de validación.",
  "details": [
    { "field": "email", "message": "value is not a valid email address" }
  ],
  "timestamp": "2026-03-16T10:00:00+00:00"
}
```

### Códigos de error conocidos
| Código | HTTP | Significado |
|--------|------|-------------|
| `UNAUTHORIZED` | 401 | Token faltante o inválido |
| `TOKEN_INVALID` | 401 | Token JWT expirado o corrupto |
| `VALIDATION_ERROR` | 422 | Datos de entrada inválidos |
| `NOT_FOUND` | 404 | Recurso no encontrado |
| `ITEM_NOT_FOUND` | 404 | Producto no existe en el inventario del usuario |
| `ITEM_NOT_ACTIVE` | 409 | Ítem ya fue consumido o descartado |
| `QUANTITY_EXCEEDS_STOCK` | 400 | Cantidad a descartar supera el stock disponible |
| `EMAIL_ALREADY_REGISTERED` | 409 | Email ya tiene una cuenta registrada |
| `INTERNAL_ERROR` | 500 | Error interno del servidor |

---

## Autenticación

Todos los endpoints (excepto register, login, health y seed de recetas) requieren:
```
Authorization: Bearer <jwt_token>
```

El token se obtiene en register o login. Es stateless (sin blacklist en servidor). Al hacer logout, el cliente simplemente descarta el token localmente.

---

## Endpoints API

### Health Check

#### `GET /api/v1/health`
**Auth:** No
```json
// Response 200
{ "status": "ok", "environment": "development", "app": "Second Serving" }
```

---

### Autenticación — `/api/v1/auth`

#### `POST /api/v1/auth/register`
**Auth:** No
```json
// Request body
{
  "email": "juan@example.com",       // EmailStr, requerido
  "full_name": "Juan Pérez",         // string, requerido
  "password": "SecurePass123!",       // string, requerido
  "location": "Bogotá, Colombia"     // string, opcional
}

// Response 201
{
  "access_token": "eyJhbGci...",
  "token_type": "bearer",
  "user": {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",  // UUID
    "email": "juan@example.com",
    "full_name": "Juan Pérez",
    "is_premium": false,
    "location": "Bogotá, Colombia",
    "created_at": "2026-03-16T10:00:00"
  }
}
```

#### `POST /api/v1/auth/login`
**Auth:** No
```json
// Request body
{
  "email": "juan@example.com",       // EmailStr, requerido
  "password": "SecurePass123!"        // string, requerido
}

// Response 200 — mismo formato que register (TokenResponse)
// Error 401 — "Email o contraseña incorrectos"
```

#### `POST /api/v1/auth/logout`
**Auth:** Sí
```json
// Response 200
{ "status": "success", "message": "Sesión cerrada correctamente" }
```

#### `GET /api/v1/auth/me`
**Auth:** Sí
```json
// Response 200 — UserResponse
{
  "id": "UUID",
  "email": "string",
  "full_name": "string",
  "is_premium": false,
  "location": "string | null",
  "created_at": "datetime"
}
```

---

### Inventario — `/api/v1/inventory`

#### `GET /api/v1/inventory`
**Auth:** Sí | **Query params:** `skip` (int, default 0), `limit` (int, 1-100, default 20)
```json
// Response 200
{
  "items": [
    {
      "id": "UUID",
      "name": "Leche entera",
      "category": "dairy",            // dairy|fruits|vegetables|meat|grains|beverages|snacks|other
      "quantity": "2.00",             // Decimal como string
      "unit": "litros",              // kg|units|liters|etc
      "unit_price": "3500.00",       // Decimal como string (COP)
      "purchase_date": "2026-03-16", // date YYYY-MM-DD
      "expiry_date": "2026-03-21",   // date YYYY-MM-DD
      "status": "active",            // active|consumed|discarded
      "days_remaining": 5,           // int, calculado por el servidor
      "notes": "string | null",
      "created_at": "2026-03-16T10:00:00"
    }
  ],
  "total": 1
}
```

#### `GET /api/v1/inventory/expiring`
**Auth:** Sí | **Query params:** `days` (int, 1-30, default 3)
```json
// Response 200 — lista de ItemResponse (mismo schema que arriba, sin wrapper)
```

#### `POST /api/v1/inventory`
**Auth:** Sí
```json
// Request body
{
  "name": "Leche entera",           // string, requerido, no vacío
  "category": "dairy",              // string, opcional
  "quantity": 2,                    // Decimal, default 1, debe ser > 0
  "unit": "litros",                // string, opcional
  "unit_price": 3500,              // Decimal, opcional, >= 0
  "purchase_date": "2026-03-16",   // date, requerido
  "expiry_date": "2026-03-21",     // date, requerido, debe ser > purchase_date
  "notes": "opcional"              // string, opcional
}

// Response 201 — ItemResponse
// Error 422 — si expiry_date <= purchase_date o quantity <= 0
```

#### `PUT /api/v1/inventory/{item_id}`
**Auth:** Sí | **Path:** `item_id` (UUID)
```json
// Request body (todos opcionales, solo se actualizan los enviados)
{
  "name": "string",
  "category": "string",
  "quantity": 1.5,           // Decimal > 0
  "unit": "string",
  "unit_price": 3200,       // Decimal >= 0
  "expiry_date": "date",
  "notes": "string"
}

// Response 200 — ItemResponse
// Error 404 — ITEM_NOT_FOUND
```

#### `PATCH /api/v1/inventory/{item_id}/consume`
**Auth:** Sí | **Path:** `item_id` (UUID)
```json
// Sin body requerido
// Response 200 — ItemResponse con status: "consumed"
// Error 404 — ITEM_NOT_FOUND
// Error 409 — ITEM_NOT_ACTIVE (ya consumido/descartado)
```

#### `PATCH /api/v1/inventory/{item_id}/discard`
**Auth:** Sí | **Path:** `item_id` (UUID)
```json
// Request body
{
  "reason": "expired",    // "expired"|"over_purchase"|"bad_storage"|"other", requerido
  "quantity": 0.5         // Decimal > 0, opcional (null = descartar todo)
}

// Response 200 — ItemResponse
//   Si descarte parcial: status sigue "active", quantity reducida
//   Si descarte total: status pasa a "discarded"
// Error 400 — QUANTITY_EXCEEDS_STOCK
// Error 409 — ITEM_NOT_ACTIVE
```

#### `DELETE /api/v1/inventory/{item_id}`
**Auth:** Sí | **Path:** `item_id` (UUID)
```
// Response 204 No Content (sin body)
// Error 404 — ITEM_NOT_FOUND
```

---

### Recetas — `/api/v1/recipes`

#### `GET /api/v1/recipes/suggestions`
**Auth:** Sí | **Query params:** `limit` (int, 1-50, default 10)

Algoritmo: prioriza recetas cuyos ingredientes coincidan con ítems del inventario próximos a vencer (days_remaining <= 5). Ordenado por mayor cantidad de coincidencias.

```json
// Response 200 — lista de RecipeSummaryResponse
[
  {
    "id": "UUID",
    "name": "Sopa de pollo",
    "description": "string | null",
    "category": "lunch",           // breakfast|lunch|dinner|snack
    "prep_time_minutes": 45,       // int | null
    "servings": 4,
    "image_url": "string | null",
    "inventory_matches": 3         // cuántos ingredientes tiene el usuario en stock
  }
]
```

#### `POST /api/v1/recipes/seed`
**Auth:** No (admin endpoint)
```json
// Response 201
{ "status": "success", "message": "15 recetas insertadas correctamente." }
// o si ya existían:
{ "status": "success", "message": "Las recetas ya estaban cargadas." }
```

#### `GET /api/v1/recipes/`
**Auth:** Sí | **Query params:** `skip` (int, default 0), `limit` (int, 1-100, default 20)
```json
// Response 200
{
  "items": [ /* lista de RecipeSummaryResponse */ ],
  "total": 15
}
```

#### `GET /api/v1/recipes/{recipe_id}`
**Auth:** Sí | **Path:** `recipe_id` (UUID)
```json
// Response 200 — RecipeDetailResponse
{
  "id": "UUID",
  "name": "Sopa de pollo",
  "description": "string | null",
  "instructions": "1. Hervir el pollo... 2. Agregar...",
  "prep_time_minutes": 45,
  "servings": 4,
  "category": "lunch",
  "image_url": "string | null",
  "ingredients": [
    {
      "id": "UUID",
      "ingredient_name": "pollo",
      "quantity": "500.00",       // Decimal | null
      "unit": "g"                 // string | null
    }
  ],
  "inventory_matches": 3,
  "created_at": "datetime"
}
```

#### `POST /api/v1/recipes/{recipe_id}/interact`
**Auth:** Sí | **Path:** `recipe_id` (UUID)
```json
// Request body
{ "action": "viewed" }   // "viewed" o "cooked"

// Response 201
{ "status": "success", "message": "Interacción 'viewed' registrada." }
```

**IMPORTANTE:** Cuando `action = "cooked"`, el backend automáticamente marca como "consumed" todos los ítems activos del inventario del usuario cuyos nombres coincidan con los ingredientes de la receta (matching por substring bidireccional).

---

### Notificaciones — `/api/v1/notifications`

#### `POST /api/v1/notifications/device`
**Auth:** Sí
```json
// Request body
{
  "fcm_token": "string",         // token FCM del dispositivo
  "platform": "android_flutter"  // "android_kotlin"|"android_flutter"|"ios_flutter"
}

// Response 201
{ "status": "success", "message": "Dispositivo registrado correctamente" }
```

#### `GET /api/v1/notifications/preferences`
**Auth:** Sí
```json
// Response 200 — crea con defaults si no existen
{
  "days_before_expiry": 3,      // int
  "quiet_hours_start": 22,     // int 0-23 | null
  "quiet_hours_end": 7,        // int 0-23 | null
  "push_enabled": true          // bool
}
```

#### `PUT /api/v1/notifications/preferences`
**Auth:** Sí
```json
// Request body (todos opcionales)
{
  "days_before_expiry": 5,       // int
  "quiet_hours_start": 23,      // int 0-23
  "quiet_hours_end": 8,         // int 0-23
  "push_enabled": true           // bool
}

// Response 200 — NotificationPreferenceResponse completo
```

---

### Analytics — `/api/v1/analytics`

#### `GET /api/v1/analytics/savings`
**Auth:** Sí | **Query params:** `month` (1-12, default actual), `year` (>= 2020, default actual)
```json
// Response 200
{
  "saved_cop": "21000.00",    // Decimal: valor de ítems consumidos con <= 3 días antes de vencer
  "wasted_cop": "7500.00",   // Decimal: valor de ítems descartados
  "period": "2026-03"         // formato YYYY-MM
}
```

#### `GET /api/v1/analytics/waste`
**Auth:** Sí | **Query params:** `months` (1-12, default 3)
```json
// Response 200 — lista de WasteTrendItem
[
  {
    "month": "2026-01",           // formato YYYY-MM
    "category": "dairy",          // string | null
    "items_discarded": 2,         // int
    "value_lost_cop": "8500.00"   // Decimal
  }
]
```

#### `GET /api/v1/analytics/summary`
**Auth:** Sí
```json
// Response 200
{
  "total_consumed": 12,                    // int
  "total_discarded": 3,                    // int
  "most_wasted_category": "dairy",         // string | null
  "most_discarded_item": "Yogur",          // string | null
  "no_waste_streak_days": 5                // int: días seguidos sin descartar
}
```

#### `GET /api/v1/analytics/segment`
**Auth:** Sí
```json
// Response 200
{
  "segment": "neutral",                     // "proactive"|"neutral"|"passive"
  "recipes_cooked_last_30_days": 2,         // int
  "open_rate": 0.0                          // float
}
```

**Criterios de segmentación:**
| Segmento | Criterio |
|----------|----------|
| `proactive` | open_rate >= 0.6 Y recipes_cooked >= 3 |
| `passive` | open_rate < 0.2 Y recipes_cooked = 0 |
| `neutral` | resto de casos |

#### `GET /api/v1/analytics/dashboard`
**Auth:** Sí | **Query params:** `month` (1-12), `year` (>= 2020)

Endpoint optimizado que combina savings + summary + segment en un solo request. **Recomendado para pantalla de inicio.**

```json
// Response 200
{
  "savings": { /* SavingsResponse */ },
  "waste_summary": { /* WasteSummaryResponse */ },
  "segment": { /* UserSegmentResponse */ }
}
```

---

### Sincronización Offline — `/api/v1/sync`

#### `POST /api/v1/sync/push`
**Auth:** Sí
```json
// Request body
{
  "changes": [
    {
      "entity_type": "inventory_item",          // actualmente solo "inventory_item"
      "entity_id": "UUID",                      // UUID del objeto
      "operation": "create",                    // "create"|"update"|"delete"
      "payload": { /* snapshot del objeto */ }, // dict con los campos
      "client_timestamp": "2026-03-16T09:30:00Z"  // ISO 8601
    }
  ]
}

// Response 200
{
  "processed": ["UUID", "UUID"],     // lista de entity_ids aplicados exitosamente
  "conflicts": ["UUID"],             // lista de entity_ids con conflicto (last-write-wins)
  "server_timestamp": "2026-03-16T10:05:00"
}
```

#### `GET /api/v1/sync/pull`
**Auth:** Sí | **Query params:** `since` (datetime ISO 8601, requerido)
```json
// Response 200
{
  "changes": [
    {
      "entity_type": "inventory_item",
      "entity_id": "UUID",
      "operation": "create",
      "payload": { /* snapshot */ },
      "client_timestamp": "datetime"
    }
  ],
  "server_timestamp": "2026-03-16T10:05:00",
  "has_more": false              // para paginación futura
}
```

**Flujo de sincronización recomendado:**
1. Al abrir la app: `GET /pull?since=<last_sync_timestamp>`
2. Aplicar cambios del servidor localmente
3. Si hay cambios locales pendientes: `POST /push`
4. Guardar `server_timestamp` de la respuesta como nuevo `last_sync_timestamp`
5. Primera sync usar: `since=1970-01-01T00:00:00Z`

---

## Tipos de Datos Importantes

| Campo | Tipo en backend | Cómo llega al frontend |
|-------|----------------|----------------------|
| IDs | UUID v4 | string `"a1b2c3d4-e5f6-..."` |
| Decimales (quantity, price) | Decimal(10,2) | string `"3500.00"` |
| Fechas | date | string `"2026-03-16"` (YYYY-MM-DD) |
| DateTimes | datetime | string `"2026-03-16T10:00:00"` (ISO 8601) |
| Booleanos | bool | `true` / `false` |

## Categorías de Inventario
`dairy` | `fruits` | `vegetables` | `meat` | `grains` | `beverages` | `snacks` | `other`

## Categorías de Recetas
`breakfast` | `lunch` | `dinner` | `snack`

## Plataformas de Dispositivo
`android_kotlin` | `android_flutter` | `ios_flutter`

## Razones de Descarte
`expired` | `over_purchase` | `bad_storage` | `other`

## Status de Inventario
`active` | `consumed` | `discarded`

## Acciones de Interacción con Recetas
`viewed` | `cooked`

## Operaciones de Sync
`create` | `update` | `delete`

## Segmentos de Usuario
`proactive` | `neutral` | `passive`

---

## Funcionalidades No Implementadas Aún (preparadas)

- **Cloudinary** — Variables de entorno listas para subida de imágenes, sin código activo
- **Google Cloud Vision** — Dependencia instalada para OCR de recibos, sin código activo
- **Email** — No hay envío de correos electrónicos
- **Blacklist de JWT** — Logout es puramente client-side

---

## Scheduler Automático

El backend ejecuta automáticamente cada hora una tarea que:
1. Busca ítems próximos a vencer de todos los usuarios
2. Respeta las preferencias de notificación (días antes, horario de no molestar)
3. Envía push notifications vía FCM a los dispositivos registrados

---

## Notas para el Frontend

1. **Siempre enviar** `Content-Type: application/json` en requests con body
2. **Siempre enviar** `Authorization: Bearer <token>` en endpoints protegidos
3. Los **Decimals** llegan como **strings** — parsearlos en el frontend
4. El endpoint `GET /analytics/dashboard` combina 3 llamadas en 1 — usarlo para la pantalla principal
5. Al recibir 401, redirigir al login (token expirado)
6. Las fechas de inventario son **date** (sin hora), los timestamps son **datetime** (con hora)
7. El `days_remaining` es calculado por el servidor — no calcularlo en el frontend
8. Al hacer "cooked" en una receta, refrescar el inventario porque ítems pueden haberse consumido automáticamente
