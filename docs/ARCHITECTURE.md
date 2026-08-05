# Arquitectura Serverless de TechModa

## Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Internet/Cliente                            │
│                       (curl, Postman, Navegador)                     │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │ Peticiones HTTPS
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Amazon API Gateway (REST API)                    │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  Endpoints:                                                     │ │
│  │  • GET  /products          → Lambda ListItems                  │ │
│  │  • POST /products          → Lambda CreateItem                 │ │
│  │  • GET  /products/{id}     → Lambda GetItem                    │ │
│  │  • PUT  /products/{id}     → Lambda UpdateItem                 │ │
│  │  • DELETE /products/{id}   → Lambda DeleteItem                 │ │
│  └────────────────────────────────────────────────────────────────┘ │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │ Invocación de Eventos
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
┌───────────────────────────┐   ┌──────────────────────────┐
│   Funciones AWS Lambda    │   │   CloudWatch & X-Ray     │
│  ┌─────────────────────┐  │   │                          │
│  │  ListItems          │──┼───│→ Logs & Trazas           │
│  │  (GET /products)    │  │   │                          │
│  └─────────────────────┘  │   └──────────────────────────┘
│  ┌─────────────────────┐  │
│  │  CreateItem         │  │
│  │  (POST /products)   │  │
│  └─────────────────────┘  │
│  ┌─────────────────────┐  │
│  │  GetItem            │  │
│  │  (GET /products/id) │  │
│  └─────────────────────┘  │
│  ┌─────────────────────┐  │
│  │  UpdateItem         │  │
│  │  (PUT /products/id) │  │
│  └─────────────────────┘  │
│  ┌─────────────────────┐  │
│  │  DeleteItem         │  │
│  │  (DELETE /prod.../id)│ │
│  └─────────────────────┘  │
└────────────┬──────────────┘
             │
             │ Operaciones SDK DynamoDB v3
             │ (Scan, PutItem, GetItem, UpdateItem, DeleteItem)
             │
             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Amazon DynamoDB                               │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  Tabla: TechModa-Products                                      │ │
│  │  Clave Primaria: productId (String)                            │ │
│  │  Modo de Facturación: PAY_PER_REQUEST                          │ │
│  │                                                                 │ │
│  │  Atributos:                                                     │ │
│  │  • productId (String) - UUID                                   │ │
│  │  • name (String)                                               │ │
│  │  • description (String)                                        │ │
│  │  • price (Number)                                              │ │
│  │  • category (String)                                           │ │
│  │  • imageUrl (String)                                           │ │
│  │  • createdAt (String) - ISO 8601                               │ │
│  │  • updatedAt (String) - ISO 8601                               │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Descripciones de Componentes

### Amazon API Gateway

**Propósito**: Sirve como punto de entrada para todas las peticiones HTTP a la API del catálogo de productos.

**Configuración**:
- **Tipo**: REST API (no HTTP API)
- **Stage**: Prod
- **Tipo de Endpoint**: Regional
- **CORS**: Habilitado para todos los endpoints
- **Integración**: Integración Proxy Lambda (pasa la petición completa a Lambda)

**Responsabilidades**:
- Enrutar peticiones a las funciones Lambda apropiadas basándose en el método HTTP y la ruta
- Manejar peticiones preflight de CORS
- Devolver respuestas Lambda a clientes con códigos de estado HTTP apropiados
- Registrar peticiones en CloudWatch

**Formato de URL Base**: `https://{api-id}.execute-api.us-east-1.amazonaws.com/Prod`

### Funciones AWS Lambda

**Propósito**: Ejecutar la lógica de negocio para cada operación CRUD.

**Configuración Común (las 5 funciones)**:
- **Runtime**: Node.js 18.x
- **Memoria**: 1024 MB
- **Timeout**: 30 segundos
- **Arquitectura**: x86_64
- **Tracing X-Ray**: Activo
- **Variables de Entorno**: `PRODUCTS_TABLE` (inyectado por SAM)

**Permisos IAM**:
Cada función tiene acceso de privilegio mínimo a DynamoDB:
- ListItems: `dynamodb:Scan`
- CreateItem: `dynamodb:PutItem`
- GetItem: `dynamodb:GetItem`
- UpdateItem: `dynamodb:GetItem`, `dynamodb:UpdateItem`
- DeleteItem: `dynamodb:DeleteItem`

### Amazon DynamoDB

**Propósito**: Almacén de datos NoSQL persistente para el catálogo de productos.

**Configuración de Tabla**:
- **Nombre de Tabla**: `{StackName}-Products` (ej., `techmoda-capstone-Products`)
- **Clave Primaria**: `productId` (String) - Solo clave de partición
- **Modo de Facturación**: PAY_PER_REQUEST (bajo demanda)
- **Protección de Eliminación**: Deshabilitada (para limpieza fácil)

**Diseño de Esquema**:

| Atributo | Tipo | Requerido | Descripción |
|-----------|------|----------|-------------|
| productId | String | Sí | UUID v4 generado por CreateItem |
| name | String | Sí | Nombre del producto (ej., "Chaqueta Denim Clásica") |
| description | String | No | Descripción del producto |
| price | Number | Sí | Precio en USD (ej., 79.99) |
| category | String | No | Categoría de moda (ej., "Chaquetas") |
| imageUrl | String | No | URL a imagen del producto |
| createdAt | String | Sí | Marca de tiempo ISO 8601 de creación |
| updatedAt | String | Sí | Marca de tiempo ISO 8601 de última actualización |

**¿Por qué PAY_PER_REQUEST?**
- No se necesita planificación de capacidad (no hay RCU/WCU que configurar)
- Rentable para aplicaciones de bajo volumen
- Escala automáticamente con el tráfico
- Ideal para proyectos de estudiantes y prototipos

### CloudWatch Logs

**Propósito**: Registro centralizado para ejecución de funciones Lambda.

**Grupos de Logs**:
Cada función Lambda crea automáticamente un grupo de logs:
- `/aws/lambda/{StackName}-ListItems`
- `/aws/lambda/{StackName}-CreateItem`
- `/aws/lambda/{StackName}-GetItem`
- `/aws/lambda/{StackName}-UpdateItem`
- `/aws/lambda/{StackName}-DeleteItem`

**Qué se Registra**:
- Inicio/fin de invocación de función
- Declaraciones console.log() del código
- Errores y trazas de stack
- Errores de runtime de Lambda
- Resultados de operaciones DynamoDB

**Retención**: 7 días (configurable en template SAM)

### AWS X-Ray

**Propósito**: Tracing distribuido para visualización del flujo de peticiones.

**Configuración**:
- Habilitado para API Gateway
- Habilitado para todas las funciones Lambda (vía `Tracing: Active`)
- Instrumentación automática de llamadas AWS SDK

**Detalles de Traza**:
- Latencia de invocación API Gateway → Lambda
- Desglose del tiempo de ejecución Lambda
- Duración de operación DynamoDB
- Identificación de errores
- Análisis de cold start vs. warm start

### Roles IAM

**Propósito**: Control de acceso seguro siguiendo el principio de privilegio mínimo.

**Roles de Ejecución Lambda**:
SAM crea automáticamente roles de ejecución para cada función con:
- `AWSLambdaBasicExecutionRole` (escritura CloudWatch Logs)
- `AWSXRayDaemonWriteAccess` (tracing X-Ray)
- Políticas DynamoDB personalizadas (específicas a las necesidades de la función)

**Ejemplo de Política (ListItems)**:
```yaml
Policies:
  - DynamoDBReadPolicy:
      TableName: !Ref ProductsTable
```

Esto otorga solo `dynamodb:Scan` y `dynamodb:GetItem` en la tabla específica.

## Diagramas de Flujo de Datos

### Flujo Crear Producto

```
1. Cliente envía petición POST
   └─> curl -X POST {API_URL}/products -H "Content-Type: application/json" -d '{...}'

2. API Gateway recibe petición
   └─> Valida método HTTP, encabezados
   └─> Enruta a Lambda CreateItem

3. Lambda CreateItem procesa
   └─> Analiza cuerpo JSON (JSON.parse(event.body))
   └─> Valida campos requeridos (name, price)
   └─> Genera UUID (crypto.randomUUID())
   └─> Agrega marcas de tiempo (new Date().toISOString())
   └─> Llama DynamoDB PutItem
   └─> Devuelve 201 Created con objeto producto

4. DynamoDB almacena item
   └─> Escribe en tabla TechModa-Products
   └─> Devuelve éxito

5. API Gateway envía respuesta
   └─> HTTP 201 con cuerpo JSON
   └─> Incluye encabezados CORS
```

### Flujo Listar Productos

```
1. Cliente envía petición GET
   └─> curl -X GET {API_URL}/products

2. API Gateway recibe petición
   └─> Enruta a Lambda ListItems

3. Lambda ListItems procesa
   └─> Llama DynamoDB Scan (sin filtros)
   └─> Recibe todos los items
   └─> Devuelve 200 OK con array de productos

4. DynamoDB devuelve items
   └─> Escanea tabla completa
   └─> Devuelve array Items

5. API Gateway envía respuesta
   └─> HTTP 200 con array JSON
```

### Flujo Obtener Producto

```
1. Cliente envía petición GET con ID
   └─> curl -X GET {API_URL}/products/{productId}

2. API Gateway recibe petición
   └─> Extrae parámetro de ruta {id}
   └─> Enruta a Lambda GetItem

3. Lambda GetItem procesa
   └─> Extrae productId de event.pathParameters.id
   └─> Llama DynamoDB GetItem con Key: {productId}
   └─> Si encontrado: devuelve 200 con producto
   └─> Si no encontrado: devuelve 404

4. DynamoDB recupera item
   └─> Búsqueda directa por clave (rápido)
   └─> Devuelve Item o null

5. API Gateway envía respuesta
   └─> HTTP 200 (encontrado) o 404 (no encontrado)
```

### Flujo Actualizar Producto

```
1. Cliente envía petición PUT con ID y cuerpo
   └─> curl -X PUT {API_URL}/products/{productId} -H "Content-Type: application/json" -d '{...}'

2. API Gateway recibe petición
   └─> Extrae parámetro de ruta {id}
   └─> Enruta a Lambda UpdateItem

3. Lambda UpdateItem procesa
   └─> Extrae productId de parámetros de ruta
   └─> Analiza campos de actualización del cuerpo
   └─> Llama DynamoDB GetItem (verificar existencia)
   └─> Si no existe: devuelve 404
   └─> Actualiza marca de tiempo (updatedAt)
   └─> Llama DynamoDB UpdateItem
   └─> Devuelve 200 con producto actualizado

4. DynamoDB actualiza item
   └─> Modifica atributos especificados
   └─> Devuelve item actualizado

5. API Gateway envía respuesta
   └─> HTTP 200 (actualizado) o 404 (no encontrado)
```

### Flujo Eliminar Producto

```
1. Cliente envía petición DELETE con ID
   └─> curl -X DELETE {API_URL}/products/{productId}

2. API Gateway recibe petición
   └─> Extrae parámetro de ruta {id}
   └─> Enruta a Lambda DeleteItem

3. Lambda DeleteItem procesa
   └─> Extrae productId de parámetros de ruta
   └─> Llama DynamoDB DeleteItem
   └─> Devuelve 200 con mensaje de éxito

4. DynamoDB elimina item
   └─> Remueve item por clave primaria
   └─> Tiene éxito incluso si el item no existe (idempotente)

5. API Gateway envía respuesta
   └─> HTTP 200 con confirmación de eliminación
```

## Especificaciones de Endpoints API

### URL Base

```
https://{api-id}.execute-api.us-east-1.amazonaws.com/Prod
```

Reemplace `{api-id}` con su ID real de API Gateway de la salida de deployment.

### Resumen de Endpoints

| Método | Endpoint | Función | Propósito |
|--------|----------|----------|---------|
| GET | /products | ListItems | Listar todos los productos |
| POST | /products | CreateItem | Crear nuevo producto |
| GET | /products/{id} | GetItem | Obtener producto por ID |
| PUT | /products/{id} | UpdateItem | Actualizar producto |
| DELETE | /products/{id} | DeleteItem | Eliminar producto |

### 1. Listar Productos

**Endpoint**: `GET /products`

**Petición**:
- Sin parámetros de ruta
- Sin parámetros de consulta
- Sin cuerpo de petición

**Respuesta de Éxito (200 OK)**:
```json
{
  "products": [
    {
      "productId": "123e4567-e89b-12d3-a456-426614174000",
      "name": "Chaqueta Denim Clásica",
      "description": "Chaqueta denim atemporal para todas las estaciones",
      "price": 79.99,
      "category": "Chaquetas",
      "imageUrl": "https://example.com/jacket.jpg",
      "createdAt": "2025-10-30T12:00:00Z",
      "updatedAt": "2025-10-30T12:00:00Z"
    }
  ]
}
```

**Respuesta de Error (500 Internal Server Error)**:
```json
{
  "error": "Internal server error",
  "message": "Failed to retrieve products"
}
```

### 2. Crear Producto

**Endpoint**: `POST /products`

**Encabezados de Petición**:
```
Content-Type: application/json
```

**Cuerpo de Petición**:
```json
{
  "name": "Chaqueta Denim Clásica",
  "description": "Chaqueta denim atemporal para todas las estaciones",
  "price": 79.99,
  "category": "Chaquetas",
  "imageUrl": "https://example.com/jacket.jpg"
}
```

**Campos Requeridos**: `name`, `price`

**Respuesta de Éxito (201 Created)**:
```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Chaqueta Denim Clásica",
  "description": "Chaqueta denim atemporal para todas las estaciones",
  "price": 79.99,
  "category": "Chaquetas",
  "imageUrl": "https://example.com/jacket.jpg",
  "createdAt": "2025-10-30T12:00:00Z",
  "updatedAt": "2025-10-30T12:00:00Z"
}
```

**Respuestas de Error**:

400 Bad Request (faltan campos requeridos):
```json
{
  "error": "Bad Request",
  "message": "Missing required field: name"
}
```

500 Internal Server Error:
```json
{
  "error": "Internal server error",
  "message": "Failed to create product"
}
```

### 3. Obtener Producto

**Endpoint**: `GET /products/{id}`

**Parámetros de Ruta**:
- `id`: UUID del producto (productId)

**Respuesta de Éxito (200 OK)**:
```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Chaqueta Denim Clásica",
  "description": "Chaqueta denim atemporal para todas las estaciones",
  "price": 79.99,
  "category": "Chaquetas",
  "imageUrl": "https://example.com/jacket.jpg",
  "createdAt": "2025-10-30T12:00:00Z",
  "updatedAt": "2025-10-30T12:00:00Z"
}
```

**Respuestas de Error**:

404 Not Found:
```json
{
  "error": "Not Found",
  "message": "Product not found"
}
```

500 Internal Server Error:
```json
{
  "error": "Internal server error",
  "message": "Failed to retrieve product"
}
```

### 4. Actualizar Producto

**Endpoint**: `PUT /products/{id}`

**Parámetros de Ruta**:
- `id`: UUID del producto (productId)

**Encabezados de Petición**:
```
Content-Type: application/json
```

**Cuerpo de Petición** (actualización parcial):
```json
{
  "price": 69.99,
  "description": "Descripción actualizada con precio de oferta"
}
```

**Respuesta de Éxito (200 OK)**:
```json
{
  "productId": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Chaqueta Denim Clásica",
  "description": "Descripción actualizada con precio de oferta",
  "price": 69.99,
  "category": "Chaquetas",
  "imageUrl": "https://example.com/jacket.jpg",
  "createdAt": "2025-10-30T12:00:00Z",
  "updatedAt": "2025-10-30T14:30:00Z"
}
```

**Respuestas de Error**:

404 Not Found:
```json
{
  "error": "Not Found",
  "message": "Product not found"
}
```

400 Bad Request:
```json
{
  "error": "Bad Request",
  "message": "Invalid update data"
}
```

500 Internal Server Error:
```json
{
  "error": "Internal server error",
  "message": "Failed to update product"
}
```

### 5. Eliminar Producto

**Endpoint**: `DELETE /products/{id}`

**Parámetros de Ruta**:
- `id`: UUID del producto (productId)

**Respuesta de Éxito (200 OK)**:
```json
{
  "message": "Product deleted successfully",
  "productId": "123e4567-e89b-12d3-a456-426614174000"
}
```

**Respuestas de Error**:

404 Not Found (si se implementa verificación de existencia):
```json
{
  "error": "Not Found",
  "message": "Product not found"
}
```

500 Internal Server Error:
```json
{
  "error": "Internal server error",
  "message": "Failed to delete product"
}
```

## Operaciones DynamoDB

### Scan (ListItems)

**Operación**: Recupera todos los items de la tabla

**Ejemplo de Código**:
```javascript
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const result = await docClient.send(new ScanCommand({
  TableName: process.env.PRODUCTS_TABLE
}));

const products = result.Items;
```

**Nota de Rendimiento**: Scan lee la tabla completa, no es adecuado para conjuntos de datos grandes. Aceptable para el alcance del capstone.

### PutItem (CreateItem)

**Operación**: Crea nuevo item en la tabla

**Ejemplo de Código**:
```javascript
const { PutCommand } = require('@aws-sdk/lib-dynamodb');

const product = {
  productId: crypto.randomUUID(),
  name: 'Chaqueta Denim Clásica',
  price: 79.99,
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString()
};

await docClient.send(new PutCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Item: product
}));
```

### GetItem (GetItem)

**Operación**: Recupera un solo item por clave primaria

**Ejemplo de Código**:
```javascript
const { GetCommand } = require('@aws-sdk/lib-dynamodb');

const result = await docClient.send(new GetCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Key: {
    productId: 'uuid-aqui'
  }
}));

const product = result.Item; // null si no se encuentra
```

### UpdateItem (UpdateItem)

**Operación**: Modifica atributos de item existente

**Ejemplo de Código**:
```javascript
const { UpdateCommand } = require('@aws-sdk/lib-dynamodb');

const result = await docClient.send(new UpdateCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Key: {
    productId: 'uuid-aqui'
  },
  UpdateExpression: 'SET price = :price, updatedAt = :updatedAt',
  ExpressionAttributeValues: {
    ':price': 69.99,
    ':updatedAt': new Date().toISOString()
  },
  ReturnValues: 'ALL_NEW'
}));

const updatedProduct = result.Attributes;
```

### DeleteItem (DeleteItem)

**Operación**: Remueve item de la tabla

**Ejemplo de Código**:
```javascript
const { DeleteCommand } = require('@aws-sdk/lib-dynamodb');

await docClient.send(new DeleteCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Key: {
    productId: 'uuid-aqui'
  }
}));
```

**Nota**: DeleteItem tiene éxito incluso si el item no existe (operación idempotente).

## Observabilidad

### Análisis de CloudWatch Logs

**Cómo Ver Logs**:
1. Consola AWS → CloudWatch → Grupos de logs
2. Seleccionar `/aws/lambda/{StackName}-{FunctionName}`
3. Ver streams de logs (uno por ejecución Lambda)

**Qué Buscar**:
- Líneas START/END/REPORT (información de runtime Lambda)
- Salida console.log() de su código
- Mensajes ERROR con trazas de stack
- Estadísticas de duración y uso de memoria

**Ejemplo de Entrada de Log**:
```
START RequestId: abc-123 Version: $LATEST
2025-10-30T12:00:00.000Z  abc-123  INFO  Received event: {...}
2025-10-30T12:00:00.100Z  abc-123  ERROR  DynamoDB error: AccessDeniedException
END RequestId: abc-123
REPORT RequestId: abc-123  Duration: 150.00 ms  Billed Duration: 150 ms  Memory Size: 1024 MB  Max Memory Used: 85 MB
```

### Trazas X-Ray

**Cómo Ver Trazas**:
1. Consola AWS → X-Ray → Traces
2. Filtrar por rango de tiempo (últimos 5 minutos)
3. Hacer clic en traza individual para ver detalles

**Mapa de Servicios**:
Muestra representación visual de:
- Cadena de llamadas API Gateway → Lambda → DynamoDB
- Latencia para cada segmento
- Tasas de error
- Indicadores de cold start

**Detalles de Traza**:
- Duración total de petición
- Tiempo gastado en cada servicio
- Rendimiento de consulta DynamoDB
- Ubicaciones de errores

## Consideraciones de Seguridad

### Privilegio Mínimo IAM

Cada función Lambda tiene solo los permisos que necesita:
- Sin ARNs de recursos comodín (`*`)
- Sin acceso de administrador
- Políticas específicas a la tabla
- Permisos específicos a la operación

### Configuración CORS

API Gateway permite peticiones de origen cruzado para compatibilidad del navegador:
- `Access-Control-Allow-Origin: *`
- `Access-Control-Allow-Headers: Content-Type`
- `Access-Control-Allow-Methods: GET,POST,PUT,DELETE,OPTIONS`

**Nota de Producción**: En aplicaciones reales, restringa `Allow-Origin` a dominios específicos.

### Autenticación API

**No Implementado** (fuera del alcance del capstone):
- Sin API keys
- Sin AWS Signature Version 4
- Sin user pools de Cognito
- API pública para propósitos de demostración

**Requisito de Producción**: Siempre agregue autenticación a APIs de producción.

## Características de Rendimiento

### Latencia Esperada

| Operación | Cold Start | Warm Start |
|-----------|------------|------------|
| Listar Productos | 800-1200ms | 100-200ms |
| Crear Producto | 800-1200ms | 150-250ms |
| Obtener Producto | 800-1200ms | 50-100ms |
| Actualizar Producto | 800-1200ms | 150-250ms |
| Eliminar Producto | 800-1200ms | 100-150ms |

**Cold Start**: Primera invocación después de deployment o período inactivo
**Warm Start**: Invocaciones subsecuentes dentro de ~15 minutos

### Escalabilidad

- **Lambda**: Escalado automático hasta el límite de concurrencia de cuenta (predeterminado 1000)
- **API Gateway**: Maneja 10,000 peticiones por segundo por defecto
- **DynamoDB**: El modo PAY_PER_REQUEST escala automáticamente para manejar tráfico

### Límites de Throughput

Para proyectos capstone de estudiantes, estos límites no son preocupación:
- Lambda: 1000 ejecuciones concurrentes
- API Gateway: 10,000 RPS por región
- DynamoDB: Sin límites de throughput en modo PAY_PER_REQUEST

## Decisiones de Arquitectura

### ¿Por qué Serverless?

✅ **Rentable**: Pague solo por uso real
✅ **Sin gestión de servidores**: AWS maneja escalado, parches, disponibilidad
✅ **Deployment rápido**: Deploy de cambios en minutos
✅ **Auto-escalado**: Maneja picos de tráfico automáticamente
✅ **Valor de portafolio**: Patrón de arquitectura moderno y en demanda

### ¿Por qué Node.js?

✅ **Familiaridad con JavaScript**: Lenguaje más accesible para estudiantes de bootcamp
✅ **AWS SDK v3**: Soporte de primera clase para DynamoDB
✅ **Cold starts rápidos**: Runtime más ligero que Java o .NET
✅ **Nativo JSON**: Ajuste natural para desarrollo de API REST

### ¿Por qué DynamoDB?

✅ **Completamente gestionado**: Sin administración de base de datos
✅ **Integración serverless**: Construido para casos de uso Lambda
✅ **PAY_PER_REQUEST**: No se necesita planificación de capacidad
✅ **Diseño de tabla única**: Esquema simple para alcance del capstone

### ¿Por qué SAM sobre Serverless Framework?

✅ **Nativo AWS**: Herramientas oficiales de AWS
✅ **Integración CloudFormation**: Misma sintaxis que estándar IaC
✅ **Free tier**: Sin costos de servicio externo
✅ **Testing local**: Comandos `sam local` para desarrollo

## Próximos Pasos

1. Revisar [Especificaciones de Función Lambda](specs/) para detalles de implementación
2. Estudiar [Guía de Testing](TESTING_GUIDE.md) para ejemplos curl
3. Consultar [Costo y Limpieza](COST_AND_CLEANUP.md) para detalles de precios AWS
4. Usar [Plantillas de Prompts](prompts/) para desarrollo asistido por IA
