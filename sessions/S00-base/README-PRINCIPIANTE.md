# S0: Tu primera aplicación serverless en AWS (Explicado para principiantes)

**¿Nunca usaste AWS?** Esta guía te lo explica **paso a paso** sin asumir conocimientos previos.

---

## 🎯 ¿Qué vamos a hacer?

Vamos a crear una **tienda online de ropa** (TechModa) que funciona en la nube de AWS. 

**Sin necesidad de:**
- Rentar servidores
- Instalar nada en máquinas
- Pagar por tiempo inactivo

**Solo pagas** cuando alguien usa tu tienda. Es como pagar la electricidad: solo por lo que consumes.

---

## 📚 Conceptos clave (sin jerga confusa)

### 1. **Lambda** = "Tu código en la nube"

Normalmente, si quieres que funcione tu código 24/7, necesitás rentar un servidor. Con **Lambda**, AWS ejecuta tu código solo cuando llega una petición. Es como tener un mesero que aparece solo cuando alguien llama.

```
Cliente: GET /products
   ↓
AWS Lambda: "¡Alguien pidió listar productos!"
   ↓ (Leo los datos)
Respuesta: { "products": [...] }
```

### 2. **DynamoDB** = "Tu base de datos en la nube"

Es donde guardamos los productos. No necesitas administrar servidores de BD — AWS lo hace por vos.

**Piensalo así:**
- SQL tradicional: "Renté un servidor, instalé PostgreSQL, configuro backups..."
- DynamoDB: "Guardo datos, AWS se encarga del resto."

### 3. **Function URL** = "El teléfono de tu código"

Es la dirección web (URL) donde otros pueden llamar a tu Lambda.

```
Antes (complicado): https://api.ejemplo.com/products → API Gateway → Lambda
Ahora (simple):    https://xxxxxx.lambda-url.us-east-1.on.aws/products → Lambda
```

### 4. **S3 + CloudFront** = "Donde vive tu sitio web"

- **S3:** Es un armario enormee en la nube. Guardas fotos, HTML, CSS, JavaScript.
- **CloudFront:** Es una red rápida que distribuye esos archivos a usuarios de todo el mundo.

**Analogy:**
- S3 = Tu almacén central
- CloudFront = Sucursales rápidas más cerca de cada cliente

### 5. **Serverless** = "Sin preocuparse por servidores"

La palabra engaña: hay servidores, pero **AWS los administra**. Vos solo escribís código.

---

## 🚀 Arquitectura de S0 (en dibujo simple)

```
┌─────────────────────────────────────────────────────────────┐
│                        USUARIO                              │
│              (abre: https://techmoda.com)                   │
└────────────────────────────┬────────────────────────────────┘
                             │
                    HTTP GET /products
                             │
        ┌────────────────────▼─────────────────────┐
        │  CloudFront (red rápida)                 │
        │  + S3 (sitio web: HTML, CSS, JS)         │
        │                                          │
        │  Tu navegador descarga:                  │
        │  ├─ index.html                           │
        │  ├─ app.js (React)                       │
        │  └─ styles.css                           │
        └────────────────────┬────────────────────┘
                             │
              (React en el navegador dice)
              "Necesito listar productos"
                             │
           ┌─────────────────▼──────────────────┐
           │  Lambda Function URL               │
           │  (teléfono de tu código)            │
           │  https://xxxxx.lambda-url...       │
           └─────────────────┬──────────────────┘
                             │
             (Router: "¿GET? → llama listar")
                             │
           ┌─────────────────▼──────────────────┐
           │  Lambda: list-items                │
           │  (ejecuta: SELECT * FROM products) │
           └─────────────────┬──────────────────┘
                             │
           ┌─────────────────▼──────────────────┐
           │  DynamoDB                          │
           │  (base de datos)                   │
           │                                    │
           │  products = [                      │
           │    {id: "1", name: "Blusa"},       │
           │    {id: "2", name: "Jeans"}        │
           │  ]                                 │
           └─────────────────┬──────────────────┘
                             │
             (Respuesta: JSON de productos)
                             │
        Navegador recibe → React lo dibuja → ¡Ves la tienda!
```

---

## 🔐 Permisos (IAM) - Lo mínimo que necesitás saber

AWS es muy seguro: **cada función solo puede hacer lo que necesita**, nada más.

**Ejemplo:**
```yaml
Lambda "ListarProductos":
  Permiso: "Solo leer de la tabla DynamoDB"
  No puede: eliminar cosas, acceder a otras tablas, etc.

Lambda "CrearProducto":
  Permiso: "Leer y escribir en la tabla DynamoDB"
  No puede: borrar la tabla, acceder a bases de datos de otros usuarios
```

**Lo importante:** si una Lambda falla con `AccessDenied`, es porque le falta permiso. No es un error de código — es que la política de seguridad dice "no".

---

## ⚙️ Paso 1: Configuración inicial

### 1.1. Verificar que tenés AWS CLI

```bash
aws --version              # Debe responder "aws-cli/2.x.x"
aws sts get-caller-identity # Debe mostrar tu identidad en AWS
```

Si alguno falla → [ir a "Troubleshooting"](#troubleshooting)

### 1.2. Clonar el proyecto

```bash
git clone <URL-del-repo> techmoda-ai && cd techmoda-ai
```

### 1.3. Crear el archivo de configuración local

SAM necesita saber:
- Tu región (nosotros: `us-east-1`)
- Nombre del stack (`techmoda-ai`)
- Que puede crear roles IAM

```bash
cp samconfig.us-east-1.example samconfig.toml
```

**¿Qué es `samconfig.toml`?** Es como un "memo" donde guardás configuraciones para que no las escribas cada vez.

**NO lo commitees a Git** (está en `.gitignore`) porque contiene cosas específicas de tu cuenta.

### 1.4. Verificar antes de tocar AWS

```bash
bash scripts/validate-all.sh --static
```

Esto **sin conectar a AWS** verifica:
- ✅ JSON válido en templates
- ✅ Dependencias instaladas
- ✅ Estructura correcta

Si pasa, estás listo. Si no, te dice qué falta.

---

## 🌩️ Paso 2: Desplegar a AWS (crear el stack)

**¿Qué pasa acá?** AWS lee el `template.yaml`, ve qué recursos necesitás (Lambda, DynamoDB, S3, etc.) y los crea todos.

```bash
sam build
```

**¿Qué hace?**
- Empaqueta tu código Node.js (los handlers CRUD)
- Valida que todo esté bien
- Genera `.aws-sam/` con lo necesario

```bash
sam deploy \
  --stack-name techmoda-ai \
  --region us-east-1 \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
  --resolve-s3 \
  --no-confirm-changeset
```

**¿Qué significan esos flags?**

| Flag | Significa |
|------|-----------|
| `--stack-name techmoda-ai` | El nombre del stack (grupo de recursos) en AWS |
| `--region us-east-1` | Región: Virgina del Norte (la elegimos porque es barata) |
| `CAPABILITY_IAM` | "Voy a crear roles IAM" (permiso que SAM necesita pedir) |
| `CAPABILITY_AUTO_EXPAND` | "Voy a usar funciones avanzadas de SAM" |
| `--resolve-s3` | "Crea un bucket automático para guardar artefactos" |
| `--no-confirm-changeset` | "No me pidas confirmación cada paso" |

**¿Cuánto tarda?** ~3-5 minutos la primera vez.

**Cuando termina**, verás:
```
Stack Name:             techmoda-ai
Region:                 us-east-1
Capabilities:           [...]
Stack Status:           CREATE_COMPLETE

Outputs
─────────────────────
ApiUrl                  https://xxxxx.lambda-url.us-east-1.on.aws/
FrontendUrl             https://yyyyy.cloudfront.net
ProductsTableName       techmoda-ai-Products
```

**Copiar y guardar:**
- `ApiUrl` (te lo vas a necesitar para probar)
- `FrontendUrl` (la URL para ver la tienda)

---

## 📦 Paso 3: Cargar datos de ejemplo

Sin productos, la tienda se ve vacía. Vamos a crear 4 de ejemplo:

```bash
bash ai/seed/seed-products.sh
```

**¿Qué hizo?**
- Consultó la `ApiUrl` que acabamos de crear
- Hizo 4 POST a `/products` con ropa de ejemplo
- Los guardó en DynamoDB

**Verificar que funcionó:**
```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text)
API_URL="${API_URL%/}"  # Quita el slash final

curl "${API_URL}/products" | python3 -m json.tool
```

**Deberías ver:**
```json
{
  "products": [
    { "productId": "1", "name": "Blusa Floral", ... },
    { "productId": "2", "name": "Jeans Clásicos", ... },
    ...
  ]
}
```

---

## 🎨 Paso 4: Desplegar el frontend (la tienda visible)

Hasta ahora, solo probamos por terminal. Ahora vamos a ver la tienda en el navegador.

```bash
bash scripts/build-frontend.sh
```

Esto:
- Descarga dependencias (npm install)
- Construye el sitio React
- Genera HTML, CSS, JS optimizado

```bash
bash scripts/deploy-frontend.sh
```

Esto:
- Lee la `ApiUrl`
- La inyecta en un archivo de configuración (para que React sepa dónde está tu API)
- Sube todo a S3
- CloudFront lo distribuye (tarda 15-20 min en propagarse globalmente, pero en 30 seg ya responde)

**Abrir en el navegador:**
```
https://yyyyy.cloudfront.net/
```

**¿Ves la tienda con 4 productos?** ✅ Felicitaciones, ¡S0 funciona!

---

## 🧪 Paso 5: Probar el CRUD (crear, leer, actualizar, borrar)

Vamos a usar la API manualmente. Elige una terminal:

### Opción A: Desde Bash (terminal del IDE)

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text)
API_URL="${API_URL%/}"

# LISTAR productos
curl "${API_URL}/products"

# CREAR un producto
curl -X POST "${API_URL}/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mi Producto",
    "price": 29.99,
    "description": "Lo que vendo",
    "category": "Ropa",
    "stock": 5
  }'

# COPIAR el productId de la respuesta (p. ej. "abc-123")

# OBTENER un producto
curl "${API_URL}/products/abc-123"

# ACTUALIZAR
curl -X PUT "${API_URL}/products/abc-123" \
  -H "Content-Type: application/json" \
  -d '{"price": 19.99}'

# ELIMINAR
curl -X DELETE "${API_URL}/products/abc-123"
```

### Opción B: Desde la UI (más fácil)

Simplemente abre el navegador, ve a tu `FrontendUrl` y:
- Hacé clic en "Agregar Producto"
- Llena el formulario
- Hacé clic en "Guardar"

Ver que aparece en la lista → ✅ CRUD funciona.

---

## 🧠 ¿Qué pasó realmente?

Cuando hiciste tu primer POST:

```
1. Tu navegador (React) manda:
   POST /products
   Body: { "name": "...", "price": 29.99 }

2. Llega a Lambda Function URL

3. Router (functions/router/index.js) parsea:
   - Método: POST
   - Path: /products (sin ID)
   - Body: el JSON

4. Router decide: "POST a /products → crea-item"

5. Lambda create-item:
   - Valida que name y price sean válidos
   - Genera un ID único (UUID)
   - Genera timestamps (createdAt, updatedAt)
   - Llama: PutCommand a DynamoDB

6. DynamoDB: Guarda el item

7. Respuesta: { "statusCode": 201, "body": { product } }

8. React ve el 201 → recarga la lista → ve el nuevo producto
```

---

## 💡 Conceptos clave revisados

| Concepto | Lo que hace |
|----------|-----------|
| **Lambda** | Ejecuta tu código solo cuando hay petición |
| **DynamoDB** | Guardia productos (base de datos) |
| **Function URL** | El teléfono de tu Lambda |
| **S3** | Almacena HTML/CSS/JS del frontend |
| **CloudFront** | Lo distribuye rápido globalmente |
| **Router** | Despacha peticiones: GET → listar, POST → crear, etc. |
| **IAM Policies** | Permisos: qué puede hacer cada Lambda |
| **Stack** | Grupo de recursos que AWS maneja junto |

---

## 🐛 Troubleshooting

### "aws: command not found"

**Problema:** AWS CLI no está instalado o no está en el PATH.

**Solución:**
```bash
# Verifica dónde está AWS
which aws

# Si no responde, instálalo
# En macOS: brew install awscli
# En Linux: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

### "Unable to locate credentials"

**Problema:** AWS CLI no sabe quién sos.

**Solución:**
```bash
aws configure
# Te pide:
# - Access Key ID (pídele a tu instructor)
# - Secret Access Key
# - Default region: us-east-1
# - Default output: json
```

### "is not authorized to perform: iam:CreateRole"

**Problema:** Tu cuenta de AWS no permite crear roles.

**Situación típica:** Estás usando el `LabRole` de AWS re/Start que tiene permisos limitados.

**Solución:** Contactá a tu instructor. Necesitás una cuenta con permisos plenos.

### "Stack with id techmoda-ai does not exist"

**Problema:** El stack no fue creado o fue eliminado.

**Solución:**
```bash
# Verifica qué stacks existen
aws cloudformation list-stacks --region us-east-1 \
  --query 'StackSummaries[?StackStatus!=`DELETE_COMPLETE`].StackName'

# Si techmoda-ai no aparece, redeploy:
bash scripts/deploy.sh
```

### "curl: (7) Failed to connect to..."

**Problema:** La API URL es incorrecta o está incompleta.

**Solución:**
```bash
# Verifica que tengas la URL correcta
aws cloudformation describe-stacks --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue"

# Debería ser: https://xxxxx.lambda-url.us-east-1.on.aws/
# Si dice "None" → el stack no existe
```

### "FrontendUrl muestra "Access Denied""

**Problema:** El bucket S3 no fue subido o falta configuración de CloudFront.

**Solución:**
```bash
# Redeploy el frontend
bash scripts/build-frontend.sh
bash scripts/deploy-frontend.sh

# Espera 2-3 minutos antes de abrir de nuevo
```

---

## 📚 Siguiente paso

¡Felicitaciones! Terminaste S0.

**Lo que aprendiste:**
- ✅ Qué es Lambda (código serverless)
- ✅ Qué es DynamoDB (BD sin administración)
- ✅ Qué es una Function URL (teléfono del código)
- ✅ Qué es S3 + CloudFront (sitio web rápido)
- ✅ Cómo desplegar un stack
- ✅ Cómo hacer CRUD (Create, Read, Update, Delete)

**Siguiente:** Ir a [S01 - Rekognition (detectar objetos en fotos)](../S01-rekognition-labels/README-PRINCIPIANTE.md)

---

## 🧹 Limpiar (cuando termines TODO el capstone)

**NO hagas esto ahora** — las próximas sesiones usan este stack.

```bash
# SOLO al final del capstone:
bash scripts/delete-all.sh
# Te pide confirmación "si"
```

---

**¿Preguntas?** Revisa `CLAUDE.md` en la raíz del proyecto para debugging avanzado.
