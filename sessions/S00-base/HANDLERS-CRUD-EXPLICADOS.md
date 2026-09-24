# Handlers CRUD: Cómo implementar cada uno

**Esta guía explica cómo funciona cada handler, línea por línea.**

---

## 🎯 Estructura general de un handler

Todos los handlers siguen este patrón:

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

// Función exportada que AWS llama
exports.handler = async (event) => {
  try {
    // 1. Parsear entrada
    // 2. Validar
    // 3. Hacer operación en DynamoDB
    // 4. Retornar respuesta 200/201/400/404/500
  } catch (error) {
    return errorResponse(500, error.message);
  }
};

// Helper: responder con headers CORS
function successResponse(statusCode, payload) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(payload)
  };
}

function errorResponse(statusCode, message) {
  return successResponse(statusCode, { error: message });
}
```

---

## 1️⃣ LIST-ITEMS: `GET /products`

**Qué hace:** retorna todos los productos

**Archivo:** `functions/list-items/index.js`

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

exports.handler = async (event) => {
  try {
    // 🔧 Conectar a DynamoDB
    const client = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(client);

    // 📋 Construir comando SCAN (leer TODOS los items)
    const command = new ScanCommand({
      TableName: process.env.PRODUCTS_TABLE  // "techmoda-ai-Products"
    });

    // 🎯 Ejecutar comando
    const result = await docClient.send(command);

    // ✅ Retornar respuesta exitosa
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        products: result.Items || []  // Protección: si no hay items, []
      })
    };

  } catch (error) {
    // ❌ Error
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### Explicación línea por línea

| Código | Qué hace |
|--------|----------|
| `new DynamoDBClient()` | Crea cliente para conectar a DynamoDB |
| `DynamoDBDocumentClient.from(client)` | Crea "documento cliente" (maneja JSON automáticamente) |
| `ScanCommand({ TableName: ... })` | Comando para leer TODOS los items de la tabla |
| `docClient.send(command)` | **Ejecuta** el comando (es async) |
| `result.Items` | Array de todos los productos |
| `statusCode: 200` | HTTP "OK" (todo bien) |
| `Access-Control-Allow-Origin: '*'` | CORS: permite peticiones desde cualquier origen |

### Caso de uso

```bash
curl "https://xxxxx.lambda-url.us-east-1.on.aws/products"

Respuesta:
{
  "products": [
    { "productId": "1", "name": "Blusa", ... },
    { "productId": "2", "name": "Jeans", ... }
  ]
}
```

---

## 2️⃣ CREATE-ITEM: `POST /products`

**Qué hace:** crea un nuevo producto

**Archivo:** `functions/create-item/index.js`

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { randomUUID } = require('crypto');

exports.handler = async (event) => {
  try {
    // 1️⃣ PARSEAR el body JSON
    let body;
    if (typeof event.body === 'string') {
      body = JSON.parse(event.body);
    } else {
      body = event.body;
    }

    // 2️⃣ VALIDAR: ¿tiene name y price?
    if (!body.name || body.name.trim() === '') {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'name es obligatorio' })
      };
    }

    if (typeof body.price !== 'number' || body.price < 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'price debe ser número >= 0' })
      };
    }

    // 3️⃣ GENERAR datos
    const productId = randomUUID();  // "550e8400-e29b-41d4-a716-446655440000"
    const now = new Date().toISOString();  // "2026-09-11T21:35:00.000Z"

    const product = {
      productId,
      name: body.name.trim(),
      description: body.description || '',
      price: body.price,
      category: body.category || 'Sin categoría',
      stock: body.stock || 0,
      imageUrl: body.imageUrl || '',
      createdAt: now,
      updatedAt: now
    };

    // 4️⃣ GUARDAR en DynamoDB
    const client = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(client);

    const command = new PutCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Item: product
    });

    await docClient.send(command);

    // 5️⃣ RETORNAR: producto creado
    return {
      statusCode: 201,  // "Created"
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ product })
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### Validaciones clave

```javascript
// ¿Validar qué?
❌ Body vacío          → error 400
❌ name faltante       → error 400
❌ price no es número  → error 400
❌ price < 0           → error 400
✅ price = 0           → permitido (producto gratis)
✅ description vacío   → permitido (default: "")
✅ category faltante   → permitido (default: "Sin categoría")
```

### Caso de uso

```bash
curl -X POST "https://xxxxx.lambda-url.us-east-1.on.aws/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Blusa Floral",
    "price": 29.99,
    "description": "100% algodón",
    "category": "Tops",
    "stock": 15
  }'

Respuesta: 201 Created
{
  "product": {
    "productId": "550e8400-...",
    "name": "Blusa Floral",
    "price": 29.99,
    "createdAt": "2026-09-11T21:35:00.000Z",
    ...
  }
}
```

---

## 3️⃣ GET-ITEM: `GET /products/{id}`

**Qué hace:** obtiene un producto por ID

**Archivo:** `functions/get-item/index.js`

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand } = require('@aws-sdk/lib-dynamodb');

exports.handler = async (event) => {
  try {
    // 1️⃣ OBTENER el ID del path
    const productId = event.pathParameters?.id;

    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Falta el ID en el path' })
      };
    }

    // 2️⃣ CONECTAR a DynamoDB
    const client = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(client);

    // 3️⃣ BUSCAR por ID
    const command = new GetCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId }  // productId es la clave primaria
    });

    const result = await docClient.send(command);

    // 4️⃣ ¿Encontró el producto?
    if (!result.Item) {
      return {
        statusCode: 404,  // "Not Found"
        body: JSON.stringify({ error: `Producto ${productId} no existe` })
      };
    }

    // 5️⃣ RETORNAR el producto
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ product: result.Item })
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### Flujo de decisión

```
¿El ID existe?
  ❌ → error 400 ("Falta el ID")
  ✅ → Buscar en DynamoDB
       ¿Encontró?
         ❌ → error 404 ("No existe")
         ✅ → retornar producto
```

### Caso de uso

```bash
# GET un producto existente
curl "https://xxxxx.lambda-url.us-east-1.on.aws/products/550e8400-..."

Respuesta: 200
{
  "product": { "productId": "550e8400-...", ... }
}

# GET un producto que NO existe
curl "https://xxxxx.lambda-url.us-east-1.on.aws/products/inexistente"

Respuesta: 404
{
  "error": "Producto inexistente no existe"
}
```

---

## 4️⃣ UPDATE-ITEM: `PUT /products/{id}`

**Qué hace:** actualiza algunos campos del producto

**Archivo:** `functions/update-item/index.js`

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');

exports.handler = async (event) => {
  try {
    // 1️⃣ OBTENER el ID
    const productId = event.pathParameters?.id;
    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Falta el ID en el path' })
      };
    }

    // 2️⃣ PARSEAR el body con actualizaciones
    let updates;
    if (typeof event.body === 'string') {
      updates = JSON.parse(event.body);
    } else {
      updates = event.body;
    }

    // 3️⃣ CONECTAR a DynamoDB
    const client = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(client);

    // 4️⃣ VERIFICAR que el producto existe
    const getCmd = new GetCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId }
    });
    const existing = await docClient.send(getCmd);

    if (!existing.Item) {
      return {
        statusCode: 404,
        body: JSON.stringify({ error: `Producto ${productId} no existe` })
      };
    }

    // 5️⃣ CONSTRUIR UpdateCommand
    // DynamoDB UpdateCommand usa expresiones como:
    // "SET price = :price, updatedAt = :now"
    let updateExpression = 'SET updatedAt = :now';
    const expressionAttributeValues = {
      ':now': new Date().toISOString()
    };

    // Agregar campos que vienen en el body
    if (updates.name) {
      updateExpression += ', #name = :name';
      expressionAttributeValues[':name'] = updates.name;
    }
    if (typeof updates.price === 'number') {
      updateExpression += ', price = :price';
      expressionAttributeValues[':price'] = updates.price;
    }
    if (updates.description) {
      updateExpression += ', description = :desc';
      expressionAttributeValues[':desc'] = updates.description;
    }
    if (updates.stock !== undefined) {
      updateExpression += ', stock = :stock';
      expressionAttributeValues[':stock'] = updates.stock;
    }

    // 6️⃣ EJECUTAR update
    const updateCmd = new UpdateCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId },
      UpdateExpression: updateExpression,
      ExpressionAttributeValues: expressionAttributeValues,
      ReturnValues: 'ALL_NEW'  // Retornar el item actualizado
    });

    const result = await docClient.send(updateCmd);

    // 7️⃣ RETORNAR el producto actualizado
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ product: result.Attributes })
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### Entender UpdateExpression

```javascript
// UpdateExpression es como SQL UPDATE:
"SET price = :price, description = :desc, updatedAt = :now"
//  ↓           ↓               ↓                    ↓
//  SET field = value_placeholder

// ExpressionAttributeValues mapea placeholders:
{
  ':price': 19.99,
  ':desc': 'Nueva descripción',
  ':now': '2026-09-11T21:35:00.000Z'
}
```

### Caso de uso

```bash
# Actualizar solo el precio
curl -X PUT "https://xxxxx.lambda-url.us-east-1.on.aws/products/550e8400-..." \
  -H "Content-Type: application/json" \
  -d '{ "price": 24.99 }'

Respuesta: 200
{
  "product": {
    "productId": "550e8400-...",
    "name": "Blusa Floral",
    "price": 24.99,          ← Cambió
    "updatedAt": "2026-09-11T21:36:00.000Z",  ← Se actualizó timestamp
    ...
  }
}
```

---

## 5️⃣ DELETE-ITEM: `DELETE /products/{id}`

**Qué hace:** elimina un producto

**Archivo:** `functions/delete-item/index.js`

```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, DeleteCommand } = require('@aws-sdk/lib-dynamodb');

exports.handler = async (event) => {
  try {
    // 1️⃣ OBTENER el ID
    const productId = event.pathParameters?.id;
    if (!productId) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Falta el ID en el path' })
      };
    }

    // 2️⃣ CONECTAR a DynamoDB
    const client = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(client);

    // 3️⃣ ELIMINAR
    const command = new DeleteCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId }
    });

    await docClient.send(command);

    // 4️⃣ RETORNAR: sin body (fue eliminado)
    return {
      statusCode: 204,  // "No Content"
      headers: { 'Content-Type': 'application/json' }
      // Sin body
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

### Nota importante

```javascript
// DeleteCommand no verifica si existe
// DynamoDB permite eliminar algo que no existe (operación idempotente)
// Resultado:
//   DELETE producto_existente    → 204 No Content (ok)
//   DELETE producto_inexistente  → 204 No Content (también ok)
```

### Caso de uso

```bash
curl -X DELETE "https://xxxxx.lambda-url.us-east-1.on.aws/products/550e8400-..."

Respuesta: 204 No Content
(Sin body, sin confirmación)
```

---

## 📊 Tabla comparativa: status codes

| Código | Significado | Cuándo |
|--------|-----------|--------|
| **200** | OK | GET exitoso, resultado ok |
| **201** | Created | POST exitoso, recurso creado |
| **204** | No Content | DELETE exitoso, sin body |
| **400** | Bad Request | Entrada inválida (falta campo, tipo incorrecto) |
| **404** | Not Found | Recurso no existe (GET /id inexistente) |
| **500** | Internal Server Error | Error no previsto (excepción, bug) |

---

## 🔗 Siguientes pasos

En **S01 (Rekognition)**, crearemos una nueva Lambda similar que:

```javascript
// S01: analyze-image
exports.handler = async (event) => {
  // 1. Obtener imageUrl del body
  // 2. Llamar a AWS Rekognition (en lugar de DynamoDB)
  // 3. Rekognition retorna: { Labels: [{ Name: "shirt", Confidence: 99 }] }
  // 4. Guardar resultados en DynamoDB
  // 5. Retornar análisis
}
```

El patrón será el mismo: validar → procesar → retornar.
