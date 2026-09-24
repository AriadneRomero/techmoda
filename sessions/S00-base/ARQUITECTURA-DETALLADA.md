# S0: Arquitectura detallada (para entender CÓMO funciona)

**Lee esto después de entender los conceptos básicos.** Es la "disección" de cómo se comunican todas las partes.

---

## 📐 El flujo completo: cómo llega una petición desde el navegador hasta DynamoDB

### Escenario: Usuario hace clic en "Listar Productos"

```
┌─ FRONTEND ─────────────────────────────────────────────────────────┐
│                                                                     │
│  React component renderiza: <button>Ver productos</button>        │
│                                                                     │
│  onClick → llama fetch() a la API:                                │
│  fetch('https://xxxxx.lambda-url.us-east-1.on.aws/products')     │
│                                                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTP GET /products
                             ▼
┌─ LAMBDA: ROUTER ───────────────────────────────────────────────────┐
│ functions/router/index.js                                          │
│                                                                     │
│ exports.handler = async (event) => {                              │
│   // event es el HTTP request
│   const method = event.requestContext.http.method  // "GET"        │
│   const path = event.rawPath  // "/products"                       │
│                                                                     │
│   // El router dice: "GET + /products (sin ID) → listar"           │
│   if (method === 'GET' && path === '/products') {                 │
│     return await listItems(event)  // require('../list-items')    │
│   }                                                                │
│ }                                                                   │
│                                                                     │
│ RESPONSABILIDAD DEL ROUTER: ruteo (dispatch)                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─ LAMBDA: LIST-ITEMS ───────────────────────────────────────────────┐
│ functions/list-items/index.js                                     │
│                                                                     │
│ const doc = DynamoDBDocumentClient.from(client);                  │
│ const command = new ScanCommand({                                  │
│   TableName: process.env.PRODUCTS_TABLE  // "techmoda-ai-Products"│
│ });                                                                 │
│ const result = await doc.send(command);                           │
│                                                                     │
│ return {                                                            │
│   statusCode: 200,                                                 │
│   body: JSON.stringify({ products: result.Items })                │
│ };                                                                  │
│                                                                     │
│ RESPONSABILIDAD: lógica de negocio (listar)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │ ScanCommand
                             ▼
┌─ DYNAMODB: TABLA PRODUCTOS ────────────────────────────────────────┐
│ techmoda-ai-Products                                               │
│                                                                     │
│ Schema (Key = productId):                                          │
│ [                                                                   │
│   { productId: "1", name: "Blusa", price: 29.99, ... },           │
│   { productId: "2", name: "Jeans", price: 59.99, ... },           │
│   { productId: "3", name: "Zapatos", price: 89.99, ... }          │
│ ]                                                                   │
│                                                                     │
│ DynamoDB ejecuta SCAN (leer todos los items)                      │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Items[]
                             ▼
┌─ RESPUESTA ────────────────────────────────────────────────────────┐
│                                                                     │
│ La Lambda retorna:                                                  │
│ {                                                                   │
│   statusCode: 200,                                                │
│   body: JSON.stringify({                                          │
│     products: [                                                    │
│       { productId: "1", name: "Blusa", price: 29.99, ... },      │
│       { productId: "2", name: "Jeans", price: 59.99, ... },      │
│       { productId: "3", name: "Zapatos", price: 89.99, ... }     │
│     ]                                                              │
│   })                                                               │
│ }                                                                   │
│                                                                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │ HTTP Response 200 OK
                             ▼
┌─ NAVEGADOR ────────────────────────────────────────────────────────┐
│ React recibe la respuesta JSON                                     │
│ Lo convierte en elementos HTML                                     │
│ Lo renderiza:                                                       │
│                                                                     │
│  ┌─ Blusa ─────────────┐                                          │
│  │ Precio: $29.99      │                                          │
│  │ [Ver] [Editar]      │                                          │
│  └─────────────────────┘                                          │
│  ┌─ Jeans ─────────────┐                                          │
│  │ Precio: $59.99      │                                          │
│  │ [Ver] [Editar]      │                                          │
│  └─────────────────────┘                                          │
│                                                                     │
│ ¡El usuario VE la tienda!                                          │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Componentes: qué hace cada uno

| Componente | Tipo | Responsabilidad | Escrito en |
|---|---|---|---|
| **React UI** | Frontend | Mostrar tienda, formularios, interacción | TypeScript/React |
| **api.ts** | Frontend | Hablar con la Lambda (HTTP client) | TypeScript |
| **Router** | Lambda | Ruteo: "GET /products → listItems" | Node.js |
| **list-items** | Lambda | Lógica: "Leer todos de DynamoDB" | Node.js |
| **create-item** | Lambda | Lógica: "Validar, generar ID, guardar" | Node.js |
| **get-item** | Lambda | Lógica: "Buscar un producto por ID" | Node.js |
| **update-item** | Lambda | Lógica: "Actualizar campos del producto" | Node.js |
| **delete-item** | Lambda | Lógica: "Eliminar un producto" | Node.js |
| **DynamoDB** | BD | Persistencia: guardar/leer productos | AWS managed |
| **S3** | CDN | Almacenar HTML/CSS/JS | AWS managed |
| **CloudFront** | CDN | Distribuir S3 rápidamente | AWS managed |

---

## 🔀 Las 5 rutas CRUD

El router implementa el patrón REST clásico:

### 1. **GET /products** → Lista todos

```javascript
// Evento en HTTP:
{
  method: "GET",
  path: "/products",
  body: null
}

// Handler: list-items
// Acción: ScanCommand a DynamoDB (lee TODO)
// Respuesta:
{
  statusCode: 200,
  body: {
    products: [...]  // Array de todos los productos
  }
}
```

### 2. **POST /products** → Crear uno

```javascript
// Evento:
{
  method: "POST",
  path: "/products",
  body: {
    name: "Blusa Floral",
    price: 29.99,
    description: "Blusa de algodón",
    category: "Tops",
    stock: 10
  }
}

// Handler: create-item
// Acciones:
//  1. Validar: ¿name y price están? → si no, error 400
//  2. Generar: productId = randomUUID()
//  3. Generar: createdAt = new Date().toISOString()
//  4. PutCommand a DynamoDB
// Respuesta:
{
  statusCode: 201,  // "Created"
  body: {
    product: {
      productId: "abc-123-def",
      name: "Blusa Floral",
      price: 29.99,
      createdAt: "2026-09-11T21:35:00.000Z",
      updatedAt: "2026-09-11T21:35:00.000Z",
      ...
    }
  }
}
```

### 3. **GET /products/{id}** → Obtener uno

```javascript
// Evento:
{
  method: "GET",
  path: "/products/abc-123-def",
  pathParameters: { id: "abc-123-def" }
}

// Handler: get-item
// Acción: GetCommand(productId = "abc-123-def")
// Respuesta:
{
  statusCode: 200,
  body: {
    product: { productId: "abc-123-def", ... }
  }
}
```

### 4. **PUT /products/{id}** → Actualizar

```javascript
// Evento:
{
  method: "PUT",
  path: "/products/abc-123-def",
  body: {
    price: 24.99  // Solo cambiar el precio
  }
}

// Handler: update-item
// Acciones:
//  1. GetCommand(productId) → verificar que existe
//  2. UpdateCommand: solo actualizar campos que vinieron
//  3. Actualizar: updatedAt = ahora
// Respuesta:
{
  statusCode: 200,
  body: {
    product: { productId: "...", price: 24.99, updatedAt: "...", ... }
  }
}
```

### 5. **DELETE /products/{id}** → Borrar

```javascript
// Evento:
{
  method: "DELETE",
  path: "/products/abc-123-def"
}

// Handler: delete-item
// Acción: DeleteCommand(productId = "abc-123-def")
// Respuesta:
{
  statusCode: 204  // "No Content"
  // Sin body (fue eliminado)
}
```

---

## 💾 DynamoDB: estructura de la tabla

**Nombre:** `{StackName}-Products` = `techmoda-ai-Products`

**Clave primaria:** `productId` (string, único)

**Atributos típicos:**

```json
{
  "productId": "550e8400-e29b-41d4-a716-446655440000",  // UUID
  "name": "Blusa Floral",
  "description": "Blusa 100% algodón",
  "price": 29.99,
  "category": "Tops",
  "stock": 15,
  "imageUrl": "https://ejemplo.com/imagen.jpg",
  "createdAt": "2026-09-11T21:35:00.000Z",
  "updatedAt": "2026-09-11T21:35:00.000Z"
}
```

**Configuración:**
- **BillingMode:** `PAY_PER_REQUEST` (pagas por cada lectura/escritura, no por capacidad)
- **No hay índices secundarios** (no necesitamos buscar por nombre o categoría)
- **No hay TTL** (los productos no expiran)

---

## 🔐 Permisos IAM (quién puede qué)

### RouterFunction (la Lambda de ruteo)

```yaml
Policies:
  - DynamoDBCrudPolicy:
      TableName: techmoda-ai-Products
```

**Significa:**
```
Acción permitida: dynamodb:GetItem, PutItem, UpdateItem, DeleteItem, Scan, Query
Recurso permitido: arn:aws:dynamodb:us-east-1:ACCOUNT:table/techmoda-ai-Products
Otros servicios: DENEGADO (no puede S3, no puede Lambda, no puede nada más)
```

**Ventaja:** si haceamos que la Lambda sea hackeada, el atacante solo puede tocar esa tabla.

---

## 📊 Flujo de eventos en el evento de Lambda

AWS Lambda recibe un "evento" cuando se invoca. Para **Function URLs**, el evento es:

```javascript
{
  "version": "2.0",  // Payload format version
  "routeKey": "$default",
  "rawPath": "/products",
  "rawQueryString": "",
  "headers": {
    "accept": "*/*",
    "content-type": "application/json",
    "host": "xxxxx.lambda-url.us-east-1.on.aws",
    "user-agent": "curl/7.64.1",
    "x-amzn-trace-id": "..."
  },
  "requestContext": {
    "http": {
      "method": "GET",
      "path": "/products",
      "protocol": "HTTP/1.1",
      "sourceIp": "203.0.113.10",
      "userAgent": "curl/7.64.1"
    },
    "timeEpoch": 1694379300000,
    "domainName": "xxxxx.lambda-url.us-east-1.on.aws",
    "accountId": "281248178297",
    "stage": "$default",
    "requestId": "..."
  },
  "body": null,
  "isBase64Encoded": false
}
```

**El router lo normaliza para que los handlers CRUD vean:**

```javascript
{
  method: "GET",           // event.requestContext.http.method
  path: "/products",       // event.rawPath
  body: null,
  pathParameters: null     // { id } si había /products/{id}
}
```

---

## 🔀 ¿Por qué un Router en vez de 5 Lambdas separadas?

### Opción A: Router único (lo que usamos)

```
Function URL → Lambda Router → Despacha a 5 handlers
                (en el mismo paquete)
```

**Ventajas:**
- Una sola Function URL (URL más simple para el frontend)
- Comparte environment variables
- Cero latencia de comunicación entre componentes

**Desventajas:**
- Un poco más código en el router

### Opción B: 5 Lambdas + API Gateway

```
API Gateway → 5 Lambdas separadas
```

**Ventajas:**
- Cada función es independiente
- Fácil de deployar/actualizar una función

**Desventajas:**
- Más complejo de entender
- API Gateway = más costo
- 5 URLs en lugar de 1

**Elegimos A porque es más educativo y más barato.**

---

## 🧪 Ejemplo completo: crear un producto desde cero

### 1. Usuario llena formulario y hace clic en "Guardar"

```
Formulario: {
  name: "Camiseta Negra",
  price: 19.99,
  description: "100% algodón, unisex",
  category: "Tops",
  stock: 20
}

React → fetch('https://xxxxx.lambda-url.us-east-1.on.aws/products', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(...)
})
```

### 2. Event entra al Router

```javascript
{
  method: "POST",
  path: "/products",
  body: "{ name: ..., price: ..., ... }",
  pathParameters: null
}
```

### 3. Router despacha a create-item

```javascript
// functions/create-item/index.js
exports.handler = async (event) => {
  let body = JSON.parse(event.body);

  // Validar
  if (!body.name || !body.price) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "name y price requeridos" })
    };
  }

  // Generar datos
  const productId = randomUUID();
  const now = new Date().toISOString();

  const product = {
    productId,
    name: body.name,
    price: body.price,
    description: body.description || "",
    category: body.category || "Sin categoría",
    stock: body.stock || 0,
    imageUrl: body.imageUrl || "",
    createdAt: now,
    updatedAt: now
  };

  // Guardar en DynamoDB
  const client = new DynamoDBClient({ region: "us-east-1" });
  const docClient = DynamoDBDocumentClient.from(client);

  await docClient.send(new PutCommand({
    TableName: process.env.PRODUCTS_TABLE,
    Item: product
  }));

  return {
    statusCode: 201,
    headers: CORS_HEADERS,
    body: JSON.stringify({ product })
  };
};
```

### 4. DynamoDB guarda

```
INSERT INTO products VALUES (
  productId = "550e8400-e29b-41d4-a716-446655440000",
  name = "Camiseta Negra",
  price = 19.99,
  ...
)
```

### 5. Respuesta al cliente

```javascript
{
  statusCode: 201,
  body: {
    product: {
      productId: "550e8400-e29b-41d4-a716-446655440000",
      name: "Camiseta Negra",
      price: 19.99,
      createdAt: "2026-09-11T21:35:00.000Z",
      updatedAt: "2026-09-11T21:35:00.000Z",
      ...
    }
  }
}
```

### 6. React recibe y actualiza la UI

```
Estado de React:
  products: [
    { productId: "550e8400-...", name: "Camiseta Negra", ... },
    ... (otros productos)
  ]

UI se redibuja → ¡Ves la camiseta nueva en la lista!
```

---

## 🚀 Cuándo termina la petición (de principio a fin)

```
t=0ms:    Usuario hace clic
t=50ms:   React hace fetch()
t=150ms:  Petición llega a Function URL
t=160ms:  Router ejecuta (Node.js arranca, require() de handlers)
t=170ms:  create-item ejecuta (validate, generar datos)
t=180ms:  DynamoDB recibe PutCommand
t=185ms:  DynamoDB confirma
t=190ms:  create-item retorna respuesta
t=200ms:  Respuesta llega al navegador
t=210ms:  React actualiza estado
t=220ms:  UI se redibuja

LATENCIA TOTAL: ~200-250ms
```

**¿Qué pasa si no hay tráfico?** Todo duerme. AWS no te cobra. Cuando entra una petición, Lambda "despierta" (cold start ~500ms la primera vez después de horas).

---

## 📈 Escalabilidad: ¿qué pasa si 1.000 usuarios al mismo tiempo?

```
AWS ve 1.000 peticiones en /products
┓
┃ → Lambda crea 1.000 ejecuciones concurrentes (cada una en su contenedor)
┃ → Todas leen de DynamoDB al mismo tiempo
┃ → DynamoDB (on-demand) provisiona automáticamente la capacidad
┃ → Todas responden en ~200ms
┗

Costo:
- 1.000 × 200ms = 200.000 ms = 200 segundos de Lambda
- Lambda tier gratuito: 1 millón de segundos/mes
- 200s = 0.0002 millones = ✅ Entra en free tier

DynamoDB:
- 1.000 lecturas concurrentes
- Facturación: $1.25 por millón de lecturas
- 1.000 lecturas = 0.001 millones = $0.00125
```

---

## 🎓 Lo que aprendiste de S0

✅ **Servicio administrado (Lambda):** tu código, sin administrar servidores

✅ **Costo por uso (DynamoDB on-demand):** pagas solo por lo que consumes

✅ **Elasticidad:** crece automáticamente a 1.000 usuarios

✅ **Seguridad mínima:** cada Lambda solo ve su tabla

✅ **RESTful API:** patrones GET/POST/PUT/DELETE en URLs

✅ **Event-driven:** el código reacciona a peticiones HTTP

---

## 🔗 Siguiente paso

En **S01**, agregaremos una nueva Lambda que llama a **Rekognition** (servicio de IA de AWS que detecta objetos en imágenes). La arquitectura será muy parecida, solo que:

```
Router → list-items (S0)
      ↓
      → create-item (S0)
      ↓
      ...
      ↓
      → analyze-image (S1 NUEVO!)
         └→ Rekognition
```

Cada Lambda va a tener su propia Function URL, su propio rol IAM, y se deployará por separado.
