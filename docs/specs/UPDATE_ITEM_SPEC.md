# Especificación de Función Lambda: UpdateItem

## Propósito

Actualizar un producto existente en el catálogo de moda TechModa usando la operación UpdateItem de DynamoDB con actualizaciones parciales y gestión automática de timestamps.

## Endpoint API

**Método**: `PUT`

**Ruta**: `/products/{id}`

**Trigger**: Evento de API Gateway REST API con parámetro de ruta y cuerpo JSON

## Esquema de Entrada

### Parámetros de Ruta

**Requerido**: `id` (productId)

**Ejemplo**: `/products/123e4567-e89b-12d3-a456-426614174000`

### Parámetros de Consulta
Ninguno

### Encabezados de Solicitud
```
Content-Type: application/json
```

### Cuerpo de Solicitud

**Actualización Parcial**: Solo incluir campos a actualizar

**Campos Actualizables**: `name`, `description`, `price`, `category`, `imageUrl`

**Campos No Actualizables**: `productId`, `createdAt` (mantenidos por el sistema)

**Ejemplo**:
```json
{
  "price": 69.99,
  "description": "Updated: Now on sale!"
}
```

**Otro Ejemplo**:
```json
{
  "name": "Vintage Denim Jacket",
  "price": 89.99,
  "category": "Vintage"
}
```

### Estructura de Evento API Gateway
```javascript
{
  "httpMethod": "PUT",
  "path": "/products/123e4567-e89b-12d3-a456-426614174000",
  "pathParameters": {
    "id": "123e4567-e89b-12d3-a456-426614174000"
  },
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"price\":69.99,\"description\":\"Updated description\"}"
}
```

## Esquema de Salida

### Respuesta Exitosa (200 OK)

**Código de Estado HTTP**: 200

**Encabezados**:
```javascript
{
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*"
}
```

**Cuerpo**:
```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Classic Denim Jacket",
  "description": "Updated: Now on sale!",
  "price": 69.99,
  "category": "Jackets",
  "imageUrl": "https://example.com/denim-jacket.jpg",
  "createdAt": "2025-10-30T12:00:00.000Z",
  "updatedAt": "2025-10-30T14:30:00.000Z"
}
```

**Nota**: `updatedAt` es más reciente que `createdAt`

### Respuestas de Error

#### 404 Not Found

**Código de Estado HTTP**: 404

**Cuerpo**:
```json
{
  "error": "Not Found",
  "message": "Product not found"
}
```

#### 400 Bad Request (Datos Inválidos)

**Código de Estado HTTP**: 400

**Cuerpo**:
```json
{
  "error": "Bad Request",
  "message": "Invalid update data"
}
```

#### 500 Internal Server Error

**Código de Estado HTTP**: 500

**Cuerpo**:
```json
{
  "error": "Internal server error",
  "message": "Failed to update product"
}
```

## Operaciones DynamoDB

### Operación 1: GetItem (Verificar Existencia)

**Propósito**: Verificar que el producto existe antes de actualizar

**Comando AWS SDK v3**: `GetCommand`

**Parámetros**:
```javascript
{
  TableName: process.env.PRODUCTS_TABLE,
  Key: {
    productId: "123e4567-e89b-12d3-a456-426614174000"
  }
}
```

### Operación 2: UpdateItem (Realizar Actualización)

**Propósito**: Actualizar atributos específicos

**Comando AWS SDK v3**: `UpdateCommand`

**Parámetros**:
```javascript
{
  TableName: process.env.PRODUCTS_TABLE,
  Key: {
    productId: "123e4567-e89b-12d3-a456-426614174000"
  },
  UpdateExpression: "SET price = :price, description = :description, updatedAt = :updatedAt",
  ExpressionAttributeValues: {
    ":price": 69.99,
    ":description": "Updated description",
    ":updatedAt": "2025-10-30T14:30:00.000Z"
  },
  ReturnValues: "ALL_NEW"
}
```

**Respuesta**:
```javascript
{
  Attributes: {
    productId: "123e4567-e89b-12d3-a456-426614174000",
    name: "Classic Denim Jacket",
    description: "Updated description",
    price: 69.99,
    // ... todos los atributos con actualizaciones aplicadas
  }
}
```

## Pasos de Implementación (Pseudocódigo)

```
1. Inicializar cliente DynamoDB
   - Importar DynamoDBClient desde @aws-sdk/client-dynamodb
   - Importar DynamoDBDocumentClient, GetCommand, UpdateCommand desde @aws-sdk/lib-dynamodb
   - Crear y envolver cliente

2. Definir función handler de Lambda
   - Función async: exports.handler = async (event)

3. Extraer productId de parámetros de ruta
   - const productId = event.pathParameters.id

4. Parsear cuerpo de solicitud
   - Usar try/catch para JSON.parse(event.body)
   - Si falla el parseo, retornar 400 Bad Request

5. Verificar si el producto existe
   - Ejecutar GetItem con productId
   - Si Item es undefined, retornar 404 Not Found

6. Construir UpdateExpression dinámicamente
   - Iterar sobre campos de actualización (price, name, description, category, imageUrl)
   - Construir cláusula SET: "SET price = :price, name = :name, ..."
   - Agregar updatedAt a la expresión
   - Construir objeto ExpressionAttributeValues

7. Ejecutar operación UpdateItem
   - Usar try/catch para manejo de errores
   - Enviar UpdateCommand a DynamoDB
   - Configurar ReturnValues: "ALL_NEW" para obtener item actualizado
   - Extraer Attributes de la respuesta

8. Manejar caso exitoso
   - Retornar respuesta API Gateway:
     * statusCode: 200
     * headers: Content-Type y CORS
     * body: JSON.stringify(Attributes)

9. Manejar casos de error
   - 404 si el producto no se encuentra en paso 5
   - 400 si no se proporcionan campos de actualización válidos
   - 500 para errores de DynamoDB
   - Registrar errores en CloudWatch
```

## Comando Curl de Prueba

### Actualizar Precio y Descripción

```bash
curl -X PUT $API_URL/products/{PRODUCT_ID} \
  -H "Content-Type: application/json" \
  -d '{
    "price": 69.99,
    "description": "Updated: Timeless denim jacket now on sale!"
  }'
```

### Actualizar Múltiples Campos

```bash
curl -X PUT $API_URL/products/{PRODUCT_ID} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Vintage Denim Jacket",
    "price": 89.99,
    "category": "Vintage",
    "description": "Rare vintage find"
  }'
```

### Actualizar Un Solo Campo

```bash
curl -X PUT $API_URL/products/{PRODUCT_ID} \
  -H "Content-Type: application/json" \
  -d '{
    "price": 59.99
  }'
```

### Probar 404 Not Found

```bash
curl -X PUT $API_URL/products/nonexistent-id \
  -H "Content-Type: application/json" \
  -d '{"price": 99.99}'
```

**Esperado**: 404 Not Found

### Flujo de Prueba Completo

```bash
# 1. Crear producto
RESPONSE=$(curl -s -X POST $API_URL/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Product", "price": 100.00}')

# 2. Extraer productId
PRODUCT_ID=$(echo $RESPONSE | jq -r '.productId')
echo "Created product: $PRODUCT_ID"

# 3. Actualizar producto
curl -X PUT $API_URL/products/$PRODUCT_ID \
  -H "Content-Type: application/json" \
  -d '{"price": 79.99, "description": "Updated"}' | jq .

# 4. Verificar actualización
curl -X GET $API_URL/products/$PRODUCT_ID | jq .
```

### Respuesta Exitosa Esperada

```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Classic Denim Jacket",
  "description": "Updated: Timeless denim jacket now on sale!",
  "price": 69.99,
  "category": "Jackets",
  "imageUrl": "https://example.com/denim-jacket.jpg",
  "createdAt": "2025-10-30T12:00:00.000Z",
  "updatedAt": "2025-10-30T14:30:00.000Z"
}
```

**Verificar**: `updatedAt` es más reciente que `createdAt`

## Prompt para Claude Code

```
Necesito implementar una función Lambda en Node.js 18.x que actualice un producto existente en DynamoDB.

Requisitos:
- Nombre de función: UpdateItem
- Runtime: Node.js 18.x
- Trigger: API Gateway (PUT /products/{id} con cuerpo JSON)
- Parámetro de ruta: id (productId)
- Base de datos: Tabla DynamoDB (nombre de variable de entorno PRODUCTS_TABLE)
- Verificar si el producto existe antes de actualizar
- Actualizar solo campos proporcionados (actualización parcial)
- Actualizar timestamp: updatedAt (formato ISO 8601)
- Respuesta: Producto actualizado con HTTP 200
- Respuesta: Error con HTTP 404 si el producto no se encuentra
- Manejo de errores: 500 para errores de DynamoDB
- CORS: Incluir encabezado Access-Control-Allow-Origin: *

Cuerpo JSON de entrada (parcial):
{
  "price": 69.99,
  "description": "Descripción actualizada"
}

Por favor genera:
1. Archivo index.js completo con exports.handler
2. Extraer productId desde parámetros de ruta
3. Parsear campos de actualización desde el cuerpo
4. Verificar que el producto existe (GetItem primero)
5. Actualizar timestamp
6. UpdateItem de DynamoDB con AWS SDK v3
7. Retornar 404 si no se encuentra
8. Formato de respuesta API Gateway
```

## Notas de Implementación

### UpdateExpression Dinámico

Construye UpdateExpression basado en campos proporcionados:

```javascript
const updateFields = [];
const expressionAttributeValues = {};

if (body.name) {
  updateFields.push('name = :name');
  expressionAttributeValues[':name'] = body.name;
}

if (body.price !== undefined) {
  updateFields.push('price = :price');
  expressionAttributeValues[':price'] = body.price;
}

if (body.description) {
  updateFields.push('description = :description');
  expressionAttributeValues[':description'] = body.description;
}

// Siempre actualizar timestamp
updateFields.push('updatedAt = :updatedAt');
expressionAttributeValues[':updatedAt'] = new Date().toISOString();

const updateExpression = 'SET ' + updateFields.join(', ');
```

### ReturnValues: ALL_NEW

Solicita a DynamoDB que retorne el item actualizado:

```javascript
const result = await docClient.send(new UpdateCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Key: { productId },
  UpdateExpression: updateExpression,
  ExpressionAttributeValues: expressionAttributeValues,
  ReturnValues: 'ALL_NEW'
}));

const updatedProduct = result.Attributes;
```

**Alternativa**: `ReturnValues: 'UPDATED_NEW'` retorna solo atributos modificados (no recomendado para este caso de uso).

### Prevenir Actualizaciones de productId

NO permitir actualizar la clave primaria:

```javascript
// Eliminar productId del cuerpo de actualización si está presente
delete body.productId;
delete body.createdAt; // También proteger createdAt
```

### Gestión de Timestamps

- **createdAt**: Nunca se actualiza (solo se establece en creación)
- **updatedAt**: Se actualiza en cada modificación

## Errores Comunes y Soluciones

### Error: "ValidationException: Invalid UpdateExpression"

**Causa**: Error de sintaxis en UpdateExpression

**Solución**: Asegura formato apropiado:
```javascript
"SET price = :price, name = :name"
```

No:
```javascript
"SET price = 69.99" // Incorrecto: no se pueden usar valores literales
```

### Error: "Product not found" (pero el producto existe)

**Causa**: Verificación GetItem no implementada apropiadamente

**Solución**: Verifica que GetItem retorna Item antes de proceder a UpdateItem

### Error: "Cannot read property 'Attributes' of undefined"

**Causa**: UpdateItem falló o no retornó Attributes

**Solución**: Verifica que `ReturnValues: 'ALL_NEW'` esté configurado y la operación haya tenido éxito

### Error: "ExpressionAttributeValues contains invalid key"

**Causa**: Nombres de atributos comienzan con `:` pero los nombres proporcionados no

**Solución**: Usa prefijo `:` en ExpressionAttributeValues:
```javascript
{
  ':price': 69.99,  // Correcto
  'price': 69.99    // Incorrecto
}
```

## Criterios de Validación

Tu función UpdateItem está correctamente implementada cuando:

✅ PUT /products/{id} con datos válidos retorna 200 OK
✅ La respuesta contiene producto actualizado con nuevos valores
✅ El timestamp `updatedAt` es más reciente que `createdAt`
✅ Los campos no modificados permanecen iguales
✅ Las actualizaciones parciales funcionan (se puede actualizar solo un campo)
✅ PUT a ID no existente retorna 404 Not Found
✅ Subsecuente GET verifica que las actualizaciones persistieron
✅ CloudWatch Logs muestra operaciones GetItem y UpdateItem
✅ La traza X-Ray muestra dos segmentos de DynamoDB
✅ Los encabezados CORS están presentes en todas las respuestas

## Próximos Pasos

Después de implementar UpdateItem:

1. Desplegar con `sam build && sam deploy`
2. Crear un producto con POST /products
3. Guardar el productId
4. Actualizar con PUT /products/{id}
5. Verificar que la respuesta muestra valores actualizados
6. Hacer GET del producto para confirmar persistencia
7. Probar actualizar ID no existente (verificar 404)
8. Revisar CloudWatch Logs
9. Proceder a implementar la función DeleteItem
