# Proyecto: Logística de Recursos (FastAPI + Supabase + Vercel)

Este proyecto implementa un sistema simple para **gestionar recursos logísticos** (items), **eventos** (events) y **despachos/devoluciones** (dispatches) con trazabilidad básica:
- Un **item** puede salir (dispatch) para uno o varios eventos.
- Un **dispatch** puede devolverse en una fecha distinta a la de uso.
- El **estado actual** del item se guarda en la tabla de items (`current_state`), y el historial de uso se conserva en `dispatch` (+ relación a `event`).

La solución está pensada para correr como **API serverless en Vercel** y usar **Supabase (Postgres)** como base de datos.

---

## Demo en producción usando vercel:
- Demo en producción usando vercel: 

`https://operadores-armadillo-prueba.vercel.app`[Link](https://operadores-armadillo-prueba.vercel.app)

- DEMO DE PRUEBA PARA TESTEARLO "frontend basico"

`https://operadores-armadillo-prueba.vercel.a/test`[Link](https://operadores-armadillo-prueba.vercel.app/test)

- Documentación de API

`https://operadores-armadillo-prueba.vercel.a/docs`[Link](https://operadores-armadillo-prueba.vercel.app/docs)
## Arquitectura

### Componentes
- **FastAPI**: API REST.
- **Supabase Postgres**: almacenamiento y relaciones.
- **Supabase Python Client**: acceso a PostgREST desde FastAPI.
- **Vercel**: despliegue como serverless function (`api/index.py`).
- **HTML Panel (opcional)**: una página para usuarios/QA que permite ver datos (tabla/JSON) y ejecutar acciones (POST).

### Flujo de datos
1. El cliente (HTML o cualquier frontend) llama endpoints FastAPI.
2. FastAPI valida entradas mínimas y llama a Supabase:
   - `insert/select/update` en tablas
   - “joins” con PostgREST usando **select anidado** (relaciones FK)
3. La API retorna JSON al cliente.

---

## Modelo de datos (Supabase)

### Modelo de Base de datos
Hay una archivo setup.sql para formar la base de datos y un archivo para llenarlo con datos dummys

> **Importante**: el “join” se logra por relaciones FK, por ejemplo:
`resource_item.resource_type_id -> resource_type.id`

Tablas principales:

### `resource_type`
Catálogo de tipos de recurso (Radio, Cono, Chaqueta, etc.)
- `id` (PK)
- `name` (string)
- `description` (string, nullable)

### `resource_item`
Inventario de items físicos.
- `id` (PK)
- `resource_type_id` (FK -> resource_type.id)
- `code` (string; código visible tipo `RAD-001`)
- `current_state` (enum o string; recomendado: `IN_WAREHOUSE`, `CHECKED_OUT`)
- `notes` (string, nullable)
- `last_state_change_at` (timestamptz, nullable)
- `created_at` (timestamptz)

### `event`
Eventos a los que se asignan recursos.
- `id` (PK)
- `name` (string, nullable)
- `event_date` (date, requerido)
- `location` (string, requerido)
- `notes` (string, nullable)
- `created_at` (timestamptz)

### `dispatch`
Registro de salida y devolución por item.
- `id` (PK)
- `resource_item_id` (FK -> resource_item.id)
- `dispatched_at` (timestamptz, requerido)
- `dispatch_note` (string, nullable)
- `returned_at` (timestamptz, nullable)
- `return_note` (string, nullable)
- `created_at` (timestamptz)

**Regla de negocio** (aplicada en la API):
- No se permite crear un dispatch nuevo si ese item ya tiene un dispatch **abierto** (`returned_at IS NULL`).
- Al crear dispatch: el item pasa a `CHECKED_OUT`.
- Al retornar dispatch: el item vuelve a `IN_WAREHOUSE`.

### `dispatch_event`
Tabla puente (muchos-a-muchos): un dispatch puede asociarse a múltiples eventos.
- `dispatch_id` (FK -> dispatch.id)
- `event_id` (FK -> event.id)

---

## Estructura del proyecto

Ejemplo recomendado:

```text
.
├─ db-setup/
│  └─ setup.sql             # SQL para crear Base de Datis 
│  └─ dummy-info.sql        # SQL para llenar de informacion dummy para testing
├─ api/
│  └─ index.py              # entrypoint para Vercel (exporta app)
├─ app/
│  ├─ main.py  
│  ├─ index.html        # html para que funcione en vercel
│  ├─ supabase.py           # cliente supabase (get_supabase)
│  └─ routers/
│     ├─ resources.py       # /resource-types, /items (+ /items/{id})
│     ├─ events.py          # /events
│     └─ dispatch.py        # /dispatches, /dispatches/{id}/return, /items/{id}/trace
├─ index.html            # html para developer
├─ requirements.txt
└─ vercel.json
```

### `api/index.py`
Vercel necesita un archivo en `api/` que exporte `app`:

```py
from app.main import app
```

---

## Variables de entorno

Configúralas en Vercel (Project → Settings → Environment Variables) y también localmente si corres en tu máquina:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

> **Importante**: `SUPABASE_SERVICE_ROLE_KEY` solo para el backend.

---

## Ejecución local (opcional)

1) Instalar dependencias:
```bash
pip install -r requirements.txt
```

2) usar variables:
```bash
SUPABASE_URL="..."
SUPABASE_SERVICE_ROLE_KEY="..."
```

3) Ejecutar:
```bash
uvicorn app.main:app --reload
```

---

## Deploy en Vercel (resumen)

1) Añadir `vercel.json`:
```json
{
  "version": 2,
  "builds": [{ "src": "api/index.py", "use": "@vercel/python" }],
  "routes": [{ "src": "/(.*)", "dest": "api/index.py" }]
}
```

2) Subir repo a GitHub → Importar en Vercel.
3) Configurar env vars.
4) Deploy.
5) Probar:
- `/docs` (Swagger)
- `/events`, `/items`, `/dispatches`

---

## Endpoints (API)

### Recursos (Resource Types + Items)

#### `GET /resource-types`
Lista tipos de recursos.

**Respuesta**: array de objetos `resource_type`.

---

#### `POST /resource-types`
Crea un tipo de recurso.

**Body (JSON)**
- `name` (string, requerido)
- `description` (string, opcional)

**Respuesta**: objeto creado.

---

#### `GET /items`
Lista items.

**Query params**
- `state` (string, opcional): `IN_WAREHOUSE` o `CHECKED_OUT`

**Respuesta**: array de `resource_item`.

---

#### `POST /items`
Crea un item.

**Body (JSON)**
- `resource_type_id` (number, requerido)
- `code` (string, requerido)
- `notes` (string, opcional)

**Respuesta**: objeto creado.

---

#### `GET /items/{item_id}`
Devuelve un item con el **objeto anidado** del tipo (relación FK).

**Path params**
- `item_id` (number)

**Respuesta (ejemplo)**
```json
{
  "id": 1,
  "code": "RAD-001",
  "current_state": "IN_WAREHOUSE",
  "notes": "Motorola canal 1",
  "resource_type": { "id": 1, "name": "Radio", "description": "..." }
}
```

> Nota: el “join” se hace con **select anidado** en PostgREST, no con SQL JOIN directo en el cliente Python.

---

### Eventos (Events)

#### `GET /events`
Lista eventos (ordenados por fecha).

**Respuesta**: array de `event`.

---

#### `POST /events`
Crea un evento.

**Body (JSON)**
- `name` (string, opcional)
- `event_date` (string, requerido, formato `YYYY-MM-DD`)
- `location` (string, requerido)
- `notes` (string, opcional)

**Respuesta**: objeto creado.

---

### Dispatches (salida / devolución)

#### `GET /dispatches`
Lista dispatches. Cada dispatch incluye `events` como lista anidada.

**Query params**
- `open_only` (boolean/string): `true` para solo abiertos (`returned_at IS NULL`)

**Respuesta**: array de dispatches, cada uno con:
- `id`, `resource_item_id`, `dispatched_at`, `dispatch_note`, `returned_at`, `return_note`, `events[]`

---

#### `POST /dispatches`
Crea un dispatch para un item.

**Body (JSON)**
- `resource_item_id` (number, requerido)
- `event_ids` (array<number>, opcional)
- `dispatched_at` (string ISO, opcional; si no se envía, usa UTC “now”)
- `dispatch_note` (string, opcional)

**Reglas**
- Si el item ya tiene un dispatch abierto → `409 Conflict`.
- Actualiza el item a `CHECKED_OUT`.

**Respuesta**: dispatch creado con `events[]` anidados.

---

#### `POST /dispatches/{dispatch_id}/return`
Marca el dispatch como devuelto.

**Path params**
- `dispatch_id` (number)

**Body (JSON)**
- `returned_at` (string ISO, opcional; si no se envía, usa UTC “now”)
- `return_note` (string, opcional)

**Reglas**
- Si el dispatch ya estaba devuelto → `409 Conflict`.
- Actualiza el item a `IN_WAREHOUSE`.

**Respuesta**: dispatch actualizado con `events[]`.

---

### Trazabilidad

#### `GET /items/{item_id}/trace`
Devuelve la trazabilidad del item:
- Estado actual
- Dispatch abierto (si existe)
- Último dispatch
- Historial completo (`dispatches[]`) con `events[]`

**Path params**
- `item_id` (number)

**Respuesta (estructura)**
```json
{
  "resource_item_id": 1,
  "code": "RAD-001",
  "current_state": "CHECKED_OUT",
  "open_dispatch_id": 15,
  "last_dispatch": { ... },
  "dispatches": [{ ... }, { ... }]
}
```

---

## UI (panel HTML) — opcional

Se incluyó una página HTML que permite:
- Cambiar entre **Items / Events / Dispatches**
- Hacer **GET** y ver resultados en **Tabla** o **JSON**
- Hacer **POST**: crear item, crear event, crear dispatch, retornar dispatch
- Copiar IDs haciendo click en las celdas

### Servir el HTML desde la API (mismo dominio)
Si quieres servirlo desde FastAPI, una opción típica es:
- Guardar el HTML en `public/panel.html`
- Exponerlo como estático o devolverlo con `HTMLResponse`

(Esto depende de cómo tengas montado tu proyecto en Vercel; si ya lo estás sirviendo desde `api/`, entonces el fetch funciona “same origin”.)

---

## Notas de implementación y decisiones

- **Estado actual en `resource_item`**: permite consultar rápidamente el estado sin calcularlo desde el historial.
- **Historial en `dispatch`**: conserva trazabilidad de uso y devolución.
- **Relación a eventos** (`dispatch_event`) permite:
  - Un item despachado para varios eventos (p.ej. festival día 1 y día 2).
- **Try/except por router**: cada endpoint devuelve errores consistentes:
  - `400` para validación/errores de supabase
  - `404` para recursos inexistentes
  - `409` para conflictos (ej: dispatch ya abierto)
  - `500` para errores inesperados

---

## Pruebas rápidas (ejemplos)

1) Cargar items:
- `GET /items`

2) Crear un dispatch:
```json
POST /dispatches
{
  "resource_item_id": 1,
  "event_ids": [2,3],
  "dispatch_note": "Salida para evento"
}
```

3) Retornar dispatch:
```json
POST /dispatches/10/return
{
  "return_note": "OK"
}
```

4) Ver trazabilidad:
- `GET /items/1/trace`

---

## Checklist de producción (recomendado)
- Activar RLS y políticas si vas a exponer endpoints públicamente.
- Añadir autenticación (JWT / API key).
- Añadir validación más estricta (pydantic) si el sistema crece.
- Manejo de paginación para listas grandes.
- Índices (por ejemplo `dispatch(resource_item_id, returned_at)`).
