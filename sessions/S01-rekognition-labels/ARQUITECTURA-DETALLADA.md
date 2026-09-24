# S01: Arquitectura detallada (Rekognition internamente)

---

## 📐 Flujo completo: POST /analyze-image

```
┌─ USUARIO ───────────────────────────────┐
│                                         │
│ Envía:                                  │
│ POST /analyze-image                     │
│ {                                       │
│   "productId": "550e8400-...",         │
│   "imageUrl": "https://..."             │
│ }                                       │
│                                         │
└────────────────────┬────────────────────┘
                     │
                     ▼
┌─ LAMBDA: ANALYZE-IMAGE ─────────────────┐
│                                         │
│ 1. Parsear body → productId, imageUrl  │
│ 2. Validar:                             │
│    ❌ productId falta → 400             │
│    ❌ imageUrl falta → 400              │
│    ❌ imageUrl no es HTTP(S) → 400      │
│                                         │
│ 3. DynamoDB GetCommand:                │
│    ¿Existe producto con este ID?       │
│    ❌ No existe → 404                   │
│    ✅ Existe → continuar               │
│                                         │
│ 4. Rekognition DetectLabels:           │
│    Enviar imageUrl a Rekognition       │
│                                         │
└────────────────────┬────────────────────┘
                     │
      ┌──────────────┴──────────────┐
      │                             │
      ▼                             ▼
┌──────────────────┐     ┌──────────────────────┐
│  DynamoDB        │     │  Rekognition        │
│                  │     │                      │
│ GetCommand:      │     │ DetectLabels:       │
│  Key: productId  │     │  Image: { Url }     │
│ ────────────────│     │  MaxLabels: 10      │
│ ✅ Item exists  │     │  MinConfidence: 50  │
│                  │     │                      │
└──────────────────┘     └────────┬────────────┘
                                  │
                         Descarga imagen
                         Analiza internamente
                                  │
                                  ▼
                         ┌──────────────────────┐
                         │ Modelo entrenado    │
                         │ (Visión por IA)     │
                         │                      │
                         │ Detecta:             │
                         │ - Shapes (formas)    │
                         │ - Colors (colores)   │
                         │ - Objects (objetos)  │
                         │ - Text (si hay)      │
                         │                      │
                         └────────┬─────────────┘
                                  │
                                  ▼
                         Retorna Labels[]
                         {
                           Labels: [
                             { Name: "Clothing", Confidence: 99.8 },
                             { Name: "Shirt", Confidence: 97.2 },
                             ...
                           ]
                         }
```

---

## 🧠 ¿Cómo funciona Rekognition internamente?

### Paso 1: Descarga la imagen

```javascript
// AWS recibe: Image: { Url: "https://ejemplo.com/blusa.jpg" }

// Internamente AWS:
const imageBytes = await fetch("https://ejemplo.com/blusa.jpg")
                     .then(r => r.arrayBuffer());
// Ahora tiene los bytes de la imagen
```

### Paso 2: Preprocesa

```
Imagen original:  [PNG 2000x1500]
                     ↓
           Redimensiona a ~1000x750 (más rápido)
                     ↓
           Normaliza (valores 0-255 → 0-1)
                     ↓
           Extrae características
```

### Paso 3: Pasa por el modelo

```
Características →  [Modelo de IA entrenado]  →  Predicciones
                        (millones de parámetros)

Ejemplo interno (simplificado):
  - Layer 1: detecta bordes
  - Layer 2: detecta formas básicas
  - Layer 3: detecta patrones
  - Layer 4: detecta objetos (SHIRT, PANTS, etc.)
  - Layer 5: detecta atributos (COLOR, MATERIAL, etc.)
  - Output: { "Clothing": 0.998, "Shirt": 0.972, "Blue": 0.885 }
```

### Paso 4: Convierte a Labels

```javascript
// Las probabilidades internas (0-1) se multiplican por 100 y se redondean
InternalProb: 0.998  →  Confidence: 99.8%
InternalProb: 0.972  →  Confidence: 97.2%
```

### Paso 5: Filtra por MinConfidence

```javascript
MinConfidence: 50  // Solo retornar labels ≥ 50%

Labels enviadas a Lambda:
✅ 99.8% (Clothing)    ≥ 50%  → incluir
✅ 97.2% (Shirt)       ≥ 50%  → incluir
❌ 35.5% (Random)      < 50%  → excluir
```

---

## 📋 El handler línea por línea

```javascript
exports.handler = async (event) => {
  // ===== SECCIÓN 1: ENTRADA =====
  
  let body;
  if (typeof event.body === 'string') {
    body = JSON.parse(event.body);  // String → Object
  } else {
    body = event.body || {};
  }
  
  // ===== SECCIÓN 2: VALIDACIÓN =====
  
  // Validación 1: productId existe y es string
  if (!body.productId) {
    return error(400, 'productId es obligatorio');
  }
  
  // Validación 2: imageUrl existe
  if (!body.imageUrl) {
    return error(400, 'imageUrl es obligatoria');
  }
  
  // Validación 3: imageUrl es string y comienza con http(s)
  if (typeof body.imageUrl !== 'string' || !body.imageUrl.startsWith('http')) {
    return error(400, 'imageUrl debe ser una URL válida (http/https)');
  }
  
  const { productId, imageUrl } = body;
  
  // ===== SECCIÓN 3: VERIFICAR PRODUCTO =====
  
  const ddbClient = new DynamoDBClient({ region: 'us-east-1' });
  const docClient = DynamoDBDocumentClient.from(ddbClient);
  
  // Comando: GetCommand busca por clave primaria (productId)
  const getCmd = new GetCommand({
    TableName: process.env.PRODUCTS_TABLE,
    Key: { productId }
  });
  
  // Ejecutar: es async, esperar
  const existingProduct = await docClient.send(getCmd);
  
  // Verificación: ¿encontró algo?
  if (!existingProduct.Item) {
    // 404 porque el producto no existe
    return error(404, `Producto ${productId} no existe`);
  }
  
  // ===== SECCIÓN 4: LLAMAR A REKOGNITION =====
  
  const rekognitionClient = new RekognitionClient({ region: 'us-east-1' });
  
  // Comando: DetectLabels
  // - Image: { Url } → AWS descarga y analiza
  // - MaxLabels: 10 → máximo 10 etiquetas
  // - MinConfidence: 50 → mínimo 50% de certeza
  const detectCmd = new DetectLabelsCommand({
    Image: { Url: imageUrl },
    MaxLabels: 10,
    MinConfidence: 50
  });
  
  // AWS hace:
  // 1. Descarga imagen desde imageUrl
  // 2. La analiza con el modelo entrenado
  // 3. Retorna Labels[]
  const rekognitionResult = await rekognitionClient.send(detectCmd);
  
  // ===== SECCIÓN 5: PROCESAR RESULTADOS =====
  
  // Convertir formato de Rekognition a nuestro formato
  const labels = (rekognitionResult.Labels || []).map((label) => ({
    name: label.Name,           // "Clothing", "Shirt", etc.
    confidence: label.Confidence // 99.8, 97.2, etc.
  }));
  
  // ===== SECCIÓN 6: GUARDAR EN DYNAMODB =====
  
  const now = new Date().toISOString();  // "2026-09-11T21:35:00.000Z"
  
  // UpdateCommand = SET algunos campos
  const updateCmd = new UpdateCommand({
    TableName: process.env.PRODUCTS_TABLE,
    Key: { productId },
    
    // UpdateExpression: qué campos cambiar
    // SET field1 = :val1, field2 = :val2
    UpdateExpression: 'SET rekognitionLabels = :labels, analyzedAt = :now, imageAnalyzed = :true',
    
    // ExpressionAttributeValues: mapeo de placeholders
    ExpressionAttributeValues: {
      ':labels': labels,
      ':now': now,
      ':true': true
    },
    
    // ReturnValues: retornar el item completo después de actualizar
    ReturnValues: 'ALL_NEW'
  });
  
  // Ejecutar update
  const updateResult = await docClient.send(updateCmd);
  
  // ===== SECCIÓN 7: RETORNAR =====
  
  return success(200, {
    productId,
    imageUrl,
    labels,                              // Las etiquetas detectadas
    totalLabelsDetected: labels.length,  // Cuántas
    analyzedAt: now,                     // Cuándo
    product: updateResult.Attributes     // El producto actualizado
  });
};
```

---

## 🔀 El flujo de datos

```
Entrada JSON:
{
  "productId": "550e8400-...",
  "imageUrl": "https://..."
}
↓
Parseado a:
{
  productId: "550e8400-...",
  imageUrl: "https://..."
}
↓
DynamoDB GetCommand:
{
  TableName: "techmoda-ai-Products",
  Key: { productId: "550e8400-..." }
}
↓
Respuesta DynamoDB:
{
  Item: {
    productId: "550e8400-...",
    name: "Blusa",
    price: 29.99,
    ...
  }
}
↓
Rekognition DetectLabelsCommand:
{
  Image: { Url: "https://..." },
  MaxLabels: 10,
  MinConfidence: 50
}
↓
Respuesta Rekognition:
{
  Labels: [
    { Name: "Clothing", Confidence: 99.8 },
    { Name: "Shirt", Confidence: 97.2 },
    ...
  ]
}
↓
Procesado a:
[
  { name: "Clothing", confidence: 99.8 },
  { name: "Shirt", confidence: 97.2 },
  ...
]
↓
DynamoDB UpdateCommand:
{
  TableName: "techmoda-ai-Products",
  Key: { productId: "550e8400-..." },
  UpdateExpression: "SET rekognitionLabels = :labels, analyzedAt = :now, imageAnalyzed = :true",
  ExpressionAttributeValues: {
    ":labels": [ { name: "Clothing", confidence: 99.8 }, ... ],
    ":now": "2026-09-11T21:35:00.000Z",
    ":true": true
  }
}
↓
Respuesta DynamoDB:
{
  Attributes: {
    productId: "550e8400-...",
    name: "Blusa",
    price: 29.99,
    rekognitionLabels: [ ... ],
    analyzedAt: "2026-09-11T21:35:00.000Z",
    imageAnalyzed: true
  }
}
↓
Respuesta Lambda:
{
  statusCode: 200,
  body: {
    productId: "550e8400-...",
    labels: [ ... ],
    product: { ... }
  }
}
```

---

## 🐛 Manejo de errores

```javascript
// Si algo falla, capturamos en catch
try {
  // ... todo el código
} catch (err) {
  // Diferentes tipos de error:
  
  if (err.name === 'InvalidParameterException') {
    // Razón: URL inválida, imagen corrupta, etc.
    return error(400, `Imagen inválida: ${err.message}`);
  }
  
  if (err.name === 'InvalidImageFormatException') {
    // Razón: No es JPG ni PNG
    return error(400, 'Formato inválido (solo JPG, PNG)');
  }
  
  if (err.name === 'ImageTooLargeException') {
    // Razón: > 15 MB
    return error(400, 'Imagen muy grande (máx 15MB)');
  }
  
  if (err.name === 'AccessDeniedException') {
    // Razón: Falta permiso IAM
    return error(403, 'Permiso denegado (revisar IAM)');
  }
  
  // Error genérico
  return error(500, `Error: ${err.message}`);
}
```

---

## ⏱️ Latencia (cuánto tarda)

```
T=0ms:    Usuario envía POST /analyze-image
T=50ms:   Llega a Lambda
T=60ms:   Lambda valida entrada
T=70ms:   Lambda hace GetCommand a DynamoDB
T=80ms:   DynamoDB responde (producto existe)
T=90ms:   Lambda envía imagen a Rekognition
T=100ms:  Rekognition comienza a procesar...
T=500ms:  Rekognition termina análisis (puede variar mucho)
T=520ms:  Lambda recibe resultados
T=530ms:  Lambda actualiza DynamoDB
T=540ms:  DynamoDB confirma
T=550ms:  Lambda retorna respuesta
T=600ms:  Usuario recibe respuesta

LATENCIA TOTAL: ~600ms (puede ser 200ms-2s según tamaño imagen)
```

---

## 💰 Costo detallado

**Rekognition DetectLabels:** $0.001 por imagen

**Ejemplo: tienda con 1.000 productos**
```
Caso 1: Analizar cada producto una vez
  1.000 imágenes × $0.001 = $1

Caso 2: Usuarios analizan imágenes nuevas (50/día)
  50/día × 30 días × $0.001 = $1.50/mes

Caso 3: Escala (10.000 análisis/día)
  10.000 × 30 × $0.001 = $300/mes

Comparación: Si hicieras esto con un empleado
  - Empleado: ~$2.000-3.000/mes
  - Rekognition: $300/mes (10x más barato)
```

---

## 🔐 Permisos IAM: qué permite cada uno

### DynamoDBCrudPolicy

```
Permite acciones:
  ✅ dynamodb:GetItem     → GetCommand
  ✅ dynamodb:PutItem     → no lo usamos aquí
  ✅ dynamodb:UpdateItem  → UpdateCommand
  ✅ dynamodb:DeleteItem  → no lo usamos aquí
  ✅ dynamodb:Query       → no lo usamos aquí
  ✅ dynamodb:Scan        → no lo usamos aquí

Solo en recurso:
  ✅ arn:aws:dynamodb:us-east-1:ACCOUNT:table/techmoda-ai-Products

Deniega:
  ❌ Acceso a otras tablas
  ❌ Acceso a otros servicios
```

### RekognitionLabelsPolicy

```
Permite acciones:
  ✅ rekognition:DetectLabels

Solo DetectLabels, NO:
  ❌ DetectFaces
  ❌ DetectModerationLabels
  ❌ RecognizeCelebrities
  ❌ Otros servicios de Rekognition
```

---

## 🎓 Conceptos clave

| Concepto | Explicación |
|----------|------------|
| **DetectLabels** | API de Rekognition que retorna objetos detectados |
| **Confidence** | Qué tan seguro está el modelo (0-100%) |
| **MaxLabels** | Límite de etiquetas a retornar |
| **MinConfidence** | Filtro: solo retornar etiquetas ≥ este valor |
| **UpdateCommand** | Modificar campos de un item en DynamoDB |
| **UpdateExpression** | Qué campos cambiar (sintaxis especial) |
| **ExpressionAttributeValues** | Valores para los placeholders del UpdateExpression |
| **ReturnValues** | Retornar el item antes o después de actualizar |

---

## 🔗 Siguientes sesiones

**S02 (Comprehend):** Análisis de **texto**
- Entrada: descripción del producto
- Salida: sentimiento (positivo/negativo/neutral)

**S03 (Translate):** Traducción de **texto**
- Entrada: descripción en español
- Salida: descripción en 50 idiomas

Todas usan el mismo patrón:
1. Validar entrada
2. Verificar que el producto existe
3. Llamar al servicio de IA
4. Guardar resultados en DynamoDB
5. Retornar respuesta
