# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este repo

Material educativo (Bootcamp Institute / AWS re/Start, pista **AI Practitioner AIF-C01**): capstone
serverless de e-commerce ("TechModa") con base de operaciones en **S0** (CRUD de productos) y 12 sesiones
de ~1 h cada una que agregan capacidades de IA de AWS. Cada sesión (`sessions/S00..S11`) es autocontenida:
guía + Lambda Python + snippet de SAM.

La documentación está en **español** (guías, comentarios, mensajes de scripts). Mantené ese idioma al
editar guías o agregar sesiones; el código y los identificadores están en inglés.

## Comandos

### Antes del primer despliegue
```bash
# Validación de integridad (sin tocar AWS)
bash scripts/validate-all.sh --static

# Configurar samconfig.toml (una sola vez)
cp samconfig.us-east-1.example samconfig.toml
# Opcionalmente: edita stack_name si quieres otro nombre que no sea "techmoda-ai"
```

### Despliegue rápido (recomendado para desarrollo diario)
```bash
bash scripts/bootstrap.sh        # Reconstruye todo en ~2-3 min; idempotente
```

### Despliegue granular
```bash
bash scripts/build.sh            # sam build backend
bash scripts/deploy.sh           # sam deploy backend con capabilities correctas

bash scripts/build-frontend.sh   # npm install + build (genera frontend/dist/)
bash scripts/deploy-frontend.sh  # Inyecta API URL y sube a S3

bash scripts/deploy-all.sh       # Combina los tres pasos arriba
```

### Estado y observabilidad
```bash
bash scripts/status.sh           # Estado del stack, Function URLs, conteo de productos
bash scripts/logs.sh list        # Listar grupos de logs disponibles
bash scripts/logs.sh get router  # Ver logs del router
bash scripts/logs.sh get router --tail --errors  # Stream de errores
```

### Frontend (desde `frontend/`)
```bash
npm run dev                      # Vite dev server (http://localhost:5173)
npm run build                    # Construir para producción
npm run lint                     # ESLint
npm run typecheck                # TypeScript sin emitir

npm test                         # vitest en watch mode
npx vitest run                   # Una sola pasada
npx vitest run src/lib/api.test.ts    # Un archivo específico
npx vitest run -t "search test"       # Un test por nombre
npx vitest run --coverage        # Cobertura
```

### Limpieza
```bash
bash scripts/delete-all.sh       # Elimina todo el stack (pide confirmación)
bash scripts/fix-failed-delete.sh  # Si quedó en DELETE_FAILED por buckets no vacíos
```

### Validación de templates
```bash
sam validate --lint -t template.yaml        # Base (S0)
sam validate --lint -t template.sandbox.yaml  # Base + S1/S2/S3/S5
sam validate --lint -t template.full.yaml   # Base + S1–S8 (demo)
```

### Testing y validación manual
```bash
# Obtener API URL
API_URL=$(aws cloudformation describe-stacks --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)
API_URL="${API_URL%/}"

# Probar CRUD
curl -X POST $API_URL/products -H "Content-Type: application/json" \
  -d '{"name":"Test","price":10.0}'
curl $API_URL/products
curl $API_URL/products/[productId]
curl -X PUT $API_URL/products/[productId] -d '{"price":5.0}'
curl -X DELETE $API_URL/products/[productId]
```

**Nota:** Las Lambda de IA (S01–S08) cada una tiene su propia Function URL y no se validan con tests
automatizados — corre el `curl` de cada `GUIA.md` en `sessions/SXX/`.

## Arquitectura

### Stack S0 (Base - CRUD de productos)

```
┌─────────────────────────────────────────────┐
│         Frontend (React/Vite/Tailwind)      │
│      → S3 / CloudFront (opcional)           │
└──────────────────┬──────────────────────────┘
                   │ HTTP
                   ▼
┌──────────────────────────────────────────────┐
│  Lambda Router (Node.js 22.x, Function URL) │
│  • Parsea {method, path, body} del evento   │
│  • Require() de 5 handlers CRUD             │
│  • Una sola base URL → {GET|POST|PUT|DELETE}│
└──────┬──────────────┬────────┬──────────────┘
       │ require()    │        │
       ▼              ▼        ▼
   list-items  create-item  get-item  ...
   (Node 22)   (Node 22)    (Node 22)
       │         │          │
       └─────────┴──────────┘
              │
              ▼
       ┌──────────────────┐
       │     DynamoDB     │
       │   {StackName}-   │
       │   Products       │
       │ (PAY_PER_REQUEST)│
       └──────────────────┘
```

**Decisiones de diseño:**

1. **Sin API Gateway → Lambda Function URLs directas.** Más simple, menos recursos, menos costo. El router
   multiplexea un CRUD completo en una sola Lambda, con 5 handlers reutilizables que viven en
   `functions/{list|create|get|update|delete}-item/index.js`.

2. **IAM de mínimo privilegio por función** ([@doc:IAM.md](docs/IAM.md)). Cada Lambda declara
   sus propias `Policies:` (DynamoDB, S3, Bedrock, servicios de IA). SAM le crea su rol automático
   — **no hay rol preexistente ni account ID hardcodeado**. Regla: `Policies: [...]` ✅, nunca
   `Role: preexistente` con `Policies:` juntos (SAM ignora las policies en silencio).

3. **Infraestructura como código con SAM.** Cada recurso está en YAML; todo despliega con
   `sam build && sam deploy --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND`. No hay
   clics en consola, no hay secretos hardcodeados.

### El Router: dispatcher HTTP multipropósito

El archivo [`functions/router/index.js`](functions/router/index.js):
- Se empaqueta con `CodeUri: functions/` (todo el árbol bajo) + `Handler: router/index.handler`
- Parsea el evento v2.0 de Function URL: `requestContext.http.{method}`, `rawPath`, `body` base64
- Reconstruye `pathParameters.id` del path y despacha a handlers
- Los 5 handlers (`../create-item`, `../list-items`, etc.) son archivos separados, `require()`bles

Ventaja: una sola URL para CRUD, reutilización de código sin duplication, y fácil de extender con
nuevos métodos HTTP.

### Tres templates: elegí según el caso

| Template | Stack S0 | IA (S1–S8) | CloudFront | Cuándo |
|---|---|---|---|---|
| `template.yaml` | ✅ | ❌ | ✅ | Ruta progresiva (añadís S1–S8 con snippets) |
| `template.sandbox.yaml` | ✅ | ✅ (parcial: S1,S2,S3,S5) | ❌ | `bootstrap.sh` (rápido para dev) |
| `template.full.yaml` | ✅ | ✅ (todas S1–S8) | ✅ | Demo final o revisión completa |

Para usar otro template en `sam build` / `sam deploy`, pasá `-t template.XXX.yaml` en **ambos**
comandos.

## Despliegue

**Región:** `us-east-1` | **Stack name:** `techmoda-ai` (editable en `samconfig.toml`)

Requiere una cuenta donde puedas **crear roles IAM** (`iam:CreateRole`): el stack crea uno de mínimo
privilegio por Lambda. Verificá primero que estás autenticado:

```bash
aws sts get-caller-identity
bash scripts/validate-all.sh --static  # Chequeos offline antes de tocar AWS
```

### Primer despliegue

```bash
cp samconfig.us-east-1.example samconfig.toml   # Una sola vez (en .gitignore)
bash scripts/deploy-all.sh                      # Backend + frontend juntos (~3-5 min + 15-20 para CloudFront)
```

O componentes individuales:
- `bash scripts/build.sh && bash scripts/deploy.sh` (backend)
- `bash scripts/build-frontend.sh && bash scripts/deploy-frontend.sh` (frontend)

### Flags de SAM: las capabilities no son opcionales

Los dos flags que SAM requiere son:
- `CAPABILITY_AUTO_EXPAND`: por el `Transform: AWS::Serverless-2016-10-31` en el template
- `CAPABILITY_IAM`: porque el stack **crea roles** (uno por Lambda). No es "permitir cambios a roles
  existentes" — es autorizar a CloudFormation a **crear nuevos roles**.

Si ves `is not authorized to perform: iam:CreateRole` → el problema es **la cuenta de AWS**, no el
template ni el código. Leé `docs/SANDBOX-COMPAT.md` si estás en un sandbox de AWS re/Start.

### Elección de template

El mismo `samconfig.toml` se usa para los tres templates. Especificá `-t` en **ambos** comandos:

```bash
sam build -t template.sandbox.yaml
sam deploy -t template.sandbox.yaml --stack-name techmoda-ai
```

Si no pasás `-t`, SAM busca `template.yaml` (base S0 solamente).

### Frontend: inyección de URL en runtime

`scripts/deploy-frontend.sh`:
1. Lee `ApiUrl` y `FrontendBucketName` del stack
2. Genera `frontend/dist/env-config.js` (configuración en **runtime**, no hardcodeada)
3. Hace `aws s3 sync --delete` a S3

Requiere que el backend ya esté desplegado y que exista `frontend/dist/` (corre `npm run build` antes).

Para desarrollo local contra un backend ya desplegado:
```bash
cp frontend/.env.example frontend/.env
# Pegá la salida ApiUrl del stack en VITE_API_URL
npm run dev
```

### Verificación rápida

```bash
bash scripts/status.sh                      # Estado del stack + URLs
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai --query \
  "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)
API="${API%/}"                              # Quita slash final
curl "${API}/products" | jq .              # Listar productos
```

Nota: `ApiUrl` termina en `/` y **no** lleva `/Prod` (es una Function URL, no API Gateway).

### FinOps: limpieza y reconstrucción

```bash
bash scripts/bootstrap.sh                   # Reconstruye todo en 2-3 min; idempotente
bash scripts/delete-all.sh                  # Elimina stack (pide confirmación "si")
bash scripts/fix-failed-delete.sh           # Si quedó en DELETE_FAILED por buckets S3
```

Regla: ningún recurso queda encendido entre sesiones más de lo necesario. Cada `GUIA.md` de sesión
trae su cleanup específico; detalles en `docs/COST_AND_CLEANUP.md`.

## Las 12 sesiones: estructura y requisitos

Cada sesión en `sessions/SXX-nombre-sesion/` es **autocontenida**: guía markdown + Lambda(s) + snippet
de SAM. Son acumulativas: S01 presupone S00 desplegada, S02 presupone S00+S01, etc.

**Stack S0 (base):** CRUD en Node.js 22.x. `template.yaml` solo S0; perfecto para empezar.

**Stacks S1–S8 (IA, cada uno es una Lambda Python 3.12 con su propia Function URL):**
- S01: Rekognition (detecta labels, moderación de contenido)
- S02: Comprehend (sentiment analysis)
- S03: Translate (traducción de descripciones)
- S04: Polly + S3 (síntesis de voz)
- S05: Transcribe (transcripción de audio a texto)
- S06–S09: Bedrock (LLM classification, chat, embeddings — requiere Model Access habilitado en consola)

Con roles de mínimo privilegio y una cuenta con `iam:CreateRole`, **todas las 12 sesiones son
ejecutables** — no hay una "Pista B" para demostrar. Unica excepción: S06–S09 necesitan que
**Bedrock → Model access** esté habilitado en la consola para la región del deploy (es un setting
**por región**). Si dan `AccessDeniedException`, habilítalo primero en consola; no es un error de
IAM.

## Trabajar con sesiones de IA (S01–S08)

Cada sesión está en `sessions/SXX-nombre-sesion/`:
```
sessions/S06-bedrock-classification/
├── GUIA.md                 # Guía interactiva (qué + por qué + cómo)
├── template-snippet.yaml   # Snippet de SAM para copiar/pegar a template.full.yaml
├── functions/
│   ├── classify-product/
│   │   ├── app.py         # Handler (Entry point)
│   │   ├── requirements.txt
│   │   └── package.json (metadata)
│   └── (posibles otras lambdas de sesión)
├── tests/
│   └── test_classify_product.py
├── curl-examples.sh        # Tests manuales con curl
└── cleanup.sh              # Scripts de cleanup específicos
```

**Checklist para agregar una sesión (read [`docs/IAM.md`](docs/IAM.md) primero):**

1. **Policies:** Acotadas (por tabla, por bucket, por ARN de modelo, o por acción). **No `Role:` junto
   a `Policies:`** (SAM ignora Policies en silencio).
2. **HTTP:** `FunctionUrlConfig: AuthType: NONE` con CORS; nunca `Events: Type: Api` ni
   `AWS::Serverless::Api`.
3. **Parámetros:** Sacá del evento con `event['rawPath']`, `event['queryStringParameters']`,
   `event['body']` (no existe `pathParameters` en Function URLs).
4. **Outputs:** `!GetAtt MiFuncionUrl.FunctionUrl` (SAM crea automáticamente `MiFuncionUrl` como recurso).
5. **Cleanup:** Cada `GUIA.md` cierra con costo estimado (verificá contra precios oficiales AWS) y
   bloque de cleanup para borrar recursos específicos (ej: reconocimiento de caras en Rekognition).

## Estructura de directorios: qué está dónde

```
techmoda-ai-capstone/
├── functions/                   # CRUD base (S0, Node.js 22.x)
│   ├── router/                 # Multiplexor HTTP → 5 handlers
│   ├── list-items/ create-item/ get-item/ update-item/ delete-item/
│
├── frontend/                    # React/Vite/Tailwind
│   ├── src/lib/api.ts          # Cliente HTTP (fetch a la API)
│   ├── package.json            # npm: dev, build, test, lint, typecheck
│
├── sessions/                    # S01–S08 (IA, cada una autocontenida)
│   ├── S01-rekognition/
│   ├── S06-bedrock-classification/
│   └── (GUIA.md + app.py + template-snippet.yaml + tests)
│
├── docs/
│   ├── IAM.md                  # Leer ANTES de agregar funciones
│   ├── ARCHITECTURE.md
│   ├── COST_AND_CLEANUP.md
│   └── SANDBOX-COMPAT.md
│
├── template.yaml               # SAM S0
├── template.sandbox.yaml       # SAM S0 + S1/S2/S3/S5 (rápido)
├── template.full.yaml          # SAM S0 + S1–S8 (demo)
│
└── scripts/                    # bootstrap.sh, deploy.sh, status.sh, logs.sh, etc.
```

**Archivos clave:**
- `docs/IAM.md`: antes de agregar cualquier Lambda
- `template.yaml`: punto de entrada SAM
- `functions/router/index.js`: dispatch CRUD HTTP
- `SESSION-PLAN.md`: cómo planificar trabajo multi-sesión

## Debugging y troubleshooting

### Errores de permiso (IAM)
```bash
# Ver errores de autorización en CloudWatch
bash scripts/logs.sh get router --errors --since 1h

# Errores comunes:
# 1. AccessDeniedException en Bedrock → falta habilitar Model Access en consola (region-specific)
# 2. is not authorized to perform: iam:CreateRole → problema de cuenta, no del template
# 3. DynamoDB AccessDenied → revisar Policies en template: tabla debe estar en ARN
```

### Errores en handler Node.js / Python
```bash
# Stream logs en tiempo real del router
bash scripts/logs.sh get router --tail

# Logs de una sesión de IA específica
bash scripts/logs.sh get classify-product --tail --errors

# Ver detalles del stack si falló
aws cloudformation describe-stacks --stack-name techmoda-ai --query 'Stacks[0].StackStatusReason'
```

### Validar CRUD después de desplegar
```bash
# Obtener API URL
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)
API="${API%/}"

# Probar cada operación
curl -X POST $API/products -H "Content-Type: application/json" -d '{"name":"Test","price":10}'
curl $API/products
```

### Deploy o SAM build fallando
```bash
# Limpiar artefactos y reintentar
rm -rf .aws-sam/
sam build -t template.yaml
sam deploy -t template.yaml --stack-name techmoda-ai \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND
```

### Frontend no conecta con API
1. Verifica que el backend esté desplegado: `bash scripts/status.sh`
2. Verifica que `frontend/dist/env-config.js` tenga la URL correcta
3. Espera 15-20 min si acabas de desplegar CloudFront (mientras tanto la API responde por curl)
4. Revisa CORS en el router: debe tener `'Access-Control-Allow-Origin': '*'`

### DynamoDB y tipos de datos
**DynamoDB no acepta `float`** en el SDK de boto3. Si una Lambda de IA quiere guardar un score de
Rekognition o Comprehend, convertilo a `Decimal(str(value))` antes del `update_item`, o crashea con
`TypeError: Float types are not supported`. Pasó primero en S01 (Rekognition `Confidence`).

### Runtimes y versiones
- **CRUD (Node.js):** `nodejs22.x` (18.x está deprecada)
- **IA (Python):** `python3.12` con `boto3`

### Model IDs de Bedrock
- Los IDs **deben ser versionados** (`anthropic.claude-haiku-4-5-20251001-v1:0`), no aliases
  (`claude-haiku-4-5` a secas). El `bedrock-runtime` legacy lo rechaza.
- Los IDs viven en **cinco lugares** que tienen que estar sincronizados:
  - `template.full.yaml` (variable de entorno)
  - `sessions/S06*/template-snippet.yaml` (variable de entorno)
  - `sessions/S08*/template-snippet.yaml`
  - Defaults en cada `app.py` de sesión
  
  `validate-all.sh` chequea divergencias automáticamente.

- Con **perfiles de inferencia cross-region** (AWS india, etc.), el ID lleva prefijo `us.` y hay que
  permitir ARN `inference-profile/*` además de `foundation-model/*` en la política IAM (ver
  `docs/IAM.md`).

- Si una demo da 404 / "model not found", **revisá el ID antes de debuggear otra cosa**.

### Estructura de sesiones
`_response()` helper y funciones de extracción de `id` están **deliberadamente duplicados** en los 9
handlers de IA y entre sesiones. Cada sesión tiene que poder leerse aislada sin depender de imports
cross-session. No los factorices a un directorio `ai/shared/` — rompe la independencia didáctica.

### Router Node.js
El router `functions/router/index.js` es el único lugar donde `require('../list-items')` ocurre. Es
la única Lambda que se empaqueta con el árbol entero de `functions/`. Las demás lambdas de IA (S01–S08)
se empaquetan cada una de su `sessions/SXX/` por separado.
