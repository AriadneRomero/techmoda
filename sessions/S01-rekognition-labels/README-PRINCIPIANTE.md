# S01: Rekognition (Detectar qué hay en una foto)

**Duración:** ~60 min | **Servicio de IA:** AWS Rekognition | **Dominio AIF-C01:** D1 (ML/AI)

> ✅ Prerequisito: S0 (CRUD) desplegado y funcionando.

---

## 🎯 ¿Qué vamos a hacer?

Vamos a agregar a la tienda **la capacidad de analizar fotos de ropa** automáticamente.

**Por ejemplo:**
- Un empleado sube una foto de una blusa
- La IA la analiza y dice: "Veo Clothing, Shirt, Blue, Textile, Fabric"
- Esos datos se guardan automáticamente en el producto
- Luego podemos usar esos datos para búsquedas

---

## 🧠 ¿Qué es Rekognition?

Rekognition es **un servicio de AWS que "ve"** imágenes como lo haría un humano.

**¿Cómo funciona?**

```
Tu foto  →  AWS Rekognition  →  Lista de cosas que ve
              (máquina entrenada)

Entrada:  https://ejemplo.com/blusa.jpg
Salida:   [
            { "name": "Clothing", "confidence": 99.8 },
            { "name": "Shirt", "confidence": 97.2 },
            { "name": "Apparel", "confidence": 96.1 },
            { "name": "Blue", "confidence": 88.5 }
          ]
```

**"Confidence"** = qué tan seguro está (0-100%).
- 99.8% = casi seguro que es ropa
- 50% = algo inseguro
- Nosotros ignoramos las menores a 50%

---

## 🏗️ Arquitectura S01

```
┌─ FRONTEND ──────────────────────────────┐
│                                          │
│  Usuario sube foto de un producto      │
│  (o proporciona URL de foto)            │
│                                          │
└──────────────┬───────────────────────────┘
               │ POST /analyze-image
               │ { productId, imageUrl }
               ▼
┌─ LAMBDA: ANALYZE-IMAGE (S01) ───────────┐
│                                          │
│  1. Obtener: productId, imageUrl        │
│  2. Verificar: ¿existe el producto?     │
│  3. Llamar: Rekognition (analizar foto) │
│  4. Guardar: etiquetas en DynamoDB      │
│  5. Retornar: lista de etiquetas        │
│                                          │
│  Políticas IAM:                          │
│  - DynamoDB: leer/escribir productos    │
│  - Rekognition: DetectLabels            │
│                                          │
└──────────────┬───────────────────────────┘
               │ DetectLabels(imageUrl)
               ▼
┌─ REKOGNITION ────────────────────────────┐
│                                          │
│  Descarga imagen desde imageUrl         │
│  La analiza (modelo de IA entrenado)    │
│  Retorna: Labels[] con Name + Confidence│
│                                          │
└──────────────┬───────────────────────────┘
               │
               ▼ UPDATE productos
┌─ DYNAMODB ────────────────────────────────┐
│                                          │
│  {                                       │
│    productId: "550e8400-...",           │
│    name: "Blusa",                        │
│    rekognitionLabels: [                  │
│      { name: "Clothing", confidence: 99},
│      { name: "Shirt", confidence: 97 }, │
│      { name: "Blue", confidence: 88 }   │
│    ],                                    │
│    analyzedAt: "2026-09-11T..."         │
│  }                                       │
│                                          │
└─────────────────────────────────────────┘
```

---

## 🧪 ¿Cómo funciona Rekognition en la práctica?

### Paso 1: Preparar imagen

Rekognition puede analizar:
- ✅ URLs públicas: `https://ejemplo.com/foto.jpg`
- ✅ Imágenes en S3: `s3://mi-bucket/foto.jpg`
- ✅ Base64 encoded bytes (menos común)

**Para S01, usamos URLs públicas** (más simple).

### Paso 2: Llamar a Rekognition

En la Lambda:
```javascript
const rekognitionClient = new RekognitionClient({ region: 'us-east-1' });

const command = new DetectLabelsCommand({
  Image: { Url: 'https://ejemplo.com/blusa.jpg' },
  MaxLabels: 10,      // Máximo 10 etiquetas
  MinConfidence: 50   // Ignorar menores a 50%
});

const result = await rekognitionClient.send(command);
// result.Labels = [
//   { Name: "Clothing", Confidence: 99.8 },
//   { Name: "Shirt", Confidence: 97.2 },
//   ...
// ]
```

### Paso 3: Guardar en DynamoDB

```javascript
const updateCmd = new UpdateCommand({
  TableName: process.env.PRODUCTS_TABLE,
  Key: { productId },
  UpdateExpression: 'SET rekognitionLabels = :labels, analyzedAt = :now',
  ExpressionAttributeValues: {
    ':labels': labels,  // Array de etiquetas
    ':now': new Date().toISOString()
  }
});

await docClient.send(updateCmd);
```

Ahora el producto tiene un nuevo campo: `rekognitionLabels`.

---

## 📁 Archivos de S01

```
sessions/S01-rekognition-labels/
├── functions/
│   └── analyze-image/
│       ├── index.js              ← Lambda handler (lee esta guía después)
│       └── package.json          ← Dependencias
├── template-snippet.yaml         ← Copiar/pegar a template.full.yaml
├── README-PRINCIPIANTE.md        ← Esta guía
└── ARQUITECTURA-DETALLADA.md     ← Para profundizar (próximamente)
```

---

## 🚀 Instalación (paso a paso)

### Paso 1: Verificar que S0 está funcionando

```bash
cd /workshop/capstone/techmoda-ai-capstone

# Verificar que el stack S0 existe
aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query 'Stacks[0].StackStatus'

# Debería responder: CREATE_COMPLETE or UPDATE_COMPLETE
```

Si no existe, despliega S0 primero (ver `sessions/S00-base/README-PRINCIPIANTE.md`).

### Paso 2: Verificar que Rekognition está habilitado

En la **consola de AWS**:
1. Vá a **Rekognition** (servicio)
2. Lado izquierdo: **Permissions**
3. Verifica que el modelo está habilitado (debería decir "Enabled" en verde)

> ⚠️ Si no está habilitado:
> 1. Click en "Enable"
> 2. AWS te muestra una confirmación
> 3. Espera 1-2 minutos

### Paso 3: Agregar S01 al template

Abre `template.full.yaml` y busca la sección `Resources:`.

Antes del cierre `Resources:` (última llave `}`), agrega el contenido de `template-snippet.yaml`.

**Estructura:**
```yaml
Resources:
  ProductsTable: ...
  RouterFunction: ...
  FrontendBucket: ...
  # ← AGREGAR AQUÍ: AnalyzeImageFunction (del snippet)
  
Outputs:
  ApiUrl: ...
  FrontendUrl: ...
  # ← AGREGAR AQUÍ: AnalyzeImageUrl (del snippet)
```

### Paso 4: Deploy

```bash
# Validar
sam validate --lint -t template.full.yaml

# Construir
sam build -t template.full.yaml

# Desplegar
sam deploy -t template.full.yaml \
  --stack-name techmoda-ai \
  --region us-east-1 \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-s3 \
  --no-confirm-changeset
```

**Toma ~5 minutos** (más que S0 porque está creando nuevos roles IAM).

Cuando termina, deberías ver:
```
Outputs
────────────────────
ApiUrl                 https://xxxxx.lambda-url.us-east-1.on.aws/
AnalyzeImageUrl        https://yyyyy.lambda-url.us-east-1.on.aws/
FrontendUrl            https://zzzzz.cloudfront.net
```

**Copiar y guardar:** `AnalyzeImageUrl`

---

## 🧪 Probar S01

### Test 1: Verificar que la Lambda está arriba

```bash
ANALYZE_URL=$(aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='AnalyzeImageUrl'].OutputValue" \
  --output text)

ANALYZE_URL="${ANALYZE_URL%/}"  # Quita slash final

# Debería responder: 405 Method Not Allowed (porque GET no está permitido)
curl "$ANALYZE_URL"
```

### Test 2: Analizar una imagen real

Primero, créate un producto con una URL de imagen pública:

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text)

API_URL="${API_URL%/}"

# Crear un producto con imagen
RESPONSE=$(curl -s -X POST "$API_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Blusa",
    "price": 29.99,
    "imageUrl": "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&q=80"
  }')

echo "$RESPONSE" | python3 -m json.tool

# Guardar el productId
PRODUCT_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['product']['productId'])")

echo "Producto creado: $PRODUCT_ID"
```

Ahora, **analizar la imagen**:

```bash
ANALYZE_URL=$(aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='AnalyzeImageUrl'].OutputValue" \
  --output text)

ANALYZE_URL="${ANALYZE_URL%/}"

curl -X POST "$ANALYZE_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"productId\": \"$PRODUCT_ID\",
    \"imageUrl\": \"https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&q=80\"
  }" | python3 -m json.tool
```

**Respuesta esperada:**
```json
{
  "productId": "550e8400-...",
  "labels": [
    { "name": "Clothing", "confidence": 99.8 },
    { "name": "Shirt", "confidence": 97.2 },
    { "name": "Apparel", "confidence": 96.1 },
    ...
  ],
  "analyzedAt": "2026-09-11T21:35:00.000Z"
}
```

### Test 3: Verificar que se guardó en DynamoDB

```bash
# Obtener el producto (deberías ver rekognitionLabels)
curl -s "$API_URL/products/$PRODUCT_ID" | python3 -m json.tool
```

Deberías ver:
```json
{
  "product": {
    "productId": "550e8400-...",
    "name": "Test Blusa",
    "rekognitionLabels": [
      { "name": "Clothing", "confidence": 99.8 },
      ...
    ],
    "analyzedAt": "2026-09-11T..."
  }
}
```

---

## ⚠️ Errores comunes

### Error: "InvalidParameterException: Invalid image URL"

**Problema:** La URL de la imagen no es accesible desde AWS.

**Solución:** Asegúrate de:
- ✅ La URL comienza con `http://` o `https://`
- ✅ La imagen es pública (no detrás de login)
- ✅ Formato válido: JPG, PNG

**Prueba con estas URLs públicas:**
```
https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&q=80
https://images.unsplash.com/photo-1551028719-00167b16ebc5?w=500&q=80
```

### Error: "ImageTooLargeException"

**Problema:** Imagen mayor a 15 MB.

**Solución:** Usa URLs con `?w=500&q=80` para reducir tamaño.

### Error: "AccessDeniedException"

**Problema:** Falta permiso para Rekognition.

**Solución:**
1. Verifica que `Rekognition` esté habilitado en consola (Permissions)
2. Verifica que la Lambda tiene la policy `RekognitionLabelsPolicy: {}`
3. Redeploy

### "productId no existe"

**Problema:** El producto que intentas analizar no existe.

**Solución:** Crea un producto primero (POST /products), luego analiza su imagen.

---

## 📊 Entender la respuesta de Rekognition

```json
{
  "labels": [
    {
      "name": "Clothing",
      "confidence": 99.8    ← Certeza (0-100%)
    },
    {
      "name": "Shirt",
      "confidence": 97.2
    },
    {
      "name": "Apparel",
      "confidence": 96.1
    },
    {
      "name": "Fabric",
      "confidence": 91.7
    },
    {
      "name": "Blue",
      "confidence": 88.5
    }
  ]
}
```

**Qué significa:**
- **Clothing (99.8%):** Casi seguro que es ropa
- **Shirt (97.2%):** Muy seguro que es una camisa
- **Blue (88.5%):** Bastante seguro que tiene azul

**Casos de uso:**
- Búsqueda: "muéstrame ropa azul" → filtrar por labels con "Blue"
- Validación: "esto debería ser ropa, ¿Rekognition lo dice?" → si no tiene "Clothing", es sospechoso
- Categorización automática: "¿es ropa, zapatos, accesorios?" → mirar labels

---

## 💸 Costo

**Rekognition:** $0.001 por imagen analizad (con DetectLabels)

**Ejemplo:**
- 1.000 imágenes/mes = $1
- 100.000 imágenes/mes = $100

Es barato si tienes poco tráfico; empieza a ser caro en escala.

---

## 🔐 Permisos IAM (S01)

La Lambda `AnalyzeImageFunction` tiene dos policies:

```yaml
Policies:
  # 1. DynamoDB CRUD Policy (leer y actualizar productos)
  - DynamoDBCrudPolicy:
      TableName: !Ref ProductsTable
  
  # 2. Rekognition Labels Policy (solo DetectLabels, nada más)
  - RekognitionLabelsPolicy: {}
```

**Significa:**
- ✅ Puede leer/escribir en la tabla ProductsTable
- ✅ Puede llamar a Rekognition DetectLabels
- ❌ No puede acceder a otras tablas
- ❌ No puede llamar a otros servicios de AWS

---

## 🎓 Lo que aprendiste de S01

✅ **IA "pre-entrenada":** Rekognition ya sabe detectar objetos, no necesitas entrenarla

✅ **Confianza (Confidence):** Los modelos no son 100% seguros, indican su certeza

✅ **Integración con BD:** Guardas resultados de IA en DynamoDB para consultas futuras

✅ **Permisos por servicio:** Cada Lambda solo puede usar los servicios que necesita

✅ **Manejo de errores:** URLs rotas, imágenes inválidas, etc. se manejan gracefully

---

## 📖 Leer después

Para profundizar:
- [ARQUITECTURA-DETALLADA.md](ARQUITECTURA-DETALLADA.md) (cómo funciona internamente)
- AWS docs: https://docs.aws.amazon.com/rekognition/latest/dg/labels.html

---

## 🔗 Siguiente paso

En **S02 (Comprehend)**, analizaremos **texto** en lugar de imágenes:
- Entrada: descripción de un producto (texto)
- Salida: sentimiento ("positivo", "negativo", "neutral")

La arquitectura será muy parecida a S01, solo que el servicio de IA será diferente (Comprehend en lugar de Rekognition).

---

**¿Preguntas?** Vuelve a leer [README-PRINCIPIANTE.md](../S00-base/README-PRINCIPIANTE.md) de S0 para refrescar conceptos fundamentales.
