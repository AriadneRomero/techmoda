# Quick Start Guide - TechModa Serverless Capstone

Esta guía te ayudará a desplegar y probar el proyecto en 10 minutos.

## Opción 1: Usar el Código Pre-implementado (Recomendado para empezar)

Las funciones Lambda ya están implementadas y listas para usar. Solo necesitas desplegar.

### Paso 1: Construir el proyecto

```bash
./scripts/build.sh
```

### Paso 2: Desplegar a AWS

```bash
./scripts/deploy.sh
```

Cuando te pregunte, usa estos valores:
```
Stack Name: tu-nombre-apellido
AWS Region: us-east-1
Confirm changes: y
Allow SAM CLI IAM role creation: y
Disable rollback: y
[5x] Function has no authentication: y
Save arguments: y
```

### Paso 3: Obtener tu API URL

Después del despliegue, verás:
```
Outputs
ApiUrl    https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/Prod
```

**Copia esa URL** y guárdala.

### Paso 4: Probar el API

```bash
# Configura tu API URL
export API_URL="https://tu-api-url.execute-api.us-east-1.amazonaws.com/Prod"

# Crear un producto
curl -X POST $API_URL/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Chaqueta Denim Clásica",
    "description": "Chaqueta azul atemporal",
    "price": 79.99,
    "category": "Ropa",
    "imageUrl": "https://example.com/jacket.jpg"
  }'

# Listar todos los productos
curl $API_URL/products

# Obtener un producto específico (usa el productId del paso anterior)
curl $API_URL/products/[productId]

# Actualizar un producto
curl -X PUT $API_URL/products/[productId] \
  -H "Content-Type: application/json" \
  -d '{
    "price": 69.99
  }'

# Eliminar un producto
curl -X DELETE $API_URL/products/[productId]
```

### Paso 5: Desplegar el Frontend (Opcional)

```bash
# Construir el frontend
./scripts/build-frontend.sh

# Desplegar a S3 + CloudFront
./scripts/deploy-frontend.sh
```

El script mostrará la URL de CloudFront. **Espera 15-20 minutos** para que CloudFront se despliegue completamente.

### Paso 6: Limpiar Recursos

**IMPORTANTE**: Cuando termines, elimina el stack para evitar cargos:

```bash
./scripts/delete.sh
```

---

## Opción 2: Implementar tú Mismo con IA

Si quieres implementar las funciones Lambda tú mismo usando prompts de IA:

### Paso 1: "Vaciar" las funciones (opcional)

Las funciones ya están implementadas. Si quieres empezar desde cero, reemplaza el contenido de cada archivo en `functions/*/index.js` con el código placeholder original.

### Paso 2: Leer la especificación

Para cada función, lee su especificación en `docs/specs/`:
- `LIST_ITEMS_SPEC.md`
- `CREATE_ITEM_SPEC.md`
- `GET_ITEM_SPEC.md`
- `UPDATE_ITEM_SPEC.md`
- `DELETE_ITEM_SPEC.md`

### Paso 3: Usar los prompts de IA

Abre `docs/prompts/02_LAMBDA_IMPLEMENTATION.md` y copia el prompt para cada función.

Por ejemplo, para **CreateItem**:

```
Necesito implementar una función Lambda en Node.js 18.x que cree productos en DynamoDB.

Requisitos:
- Tabla DynamoDB: usar variable de entorno PRODUCTS_TABLE
- Validar que name y price sean obligatorios
- Generar productId con randomUUID() de crypto
- Generar timestamps: createdAt y updatedAt (ISO 8601)
- Usar @aws-sdk/client-dynamodb y @aws-sdk/lib-dynamodb (v3)
- Retornar status 201 con el producto creado
- Manejar errores con status 400 (validación) y 500 (servidor)
- Incluir headers CORS: 'Access-Control-Allow-Origin': '*'

Campos del producto:
{
  "productId": "UUID",
  "name": "string (requerido)",
  "description": "string",
  "price": "number (requerido)",
  "category": "string",
  "imageUrl": "string",
  "createdAt": "ISO timestamp",
  "updatedAt": "ISO timestamp"
}

Por favor genera el código completo con require() de Node.js.
```

Pega este prompt en Claude Code o ChatGPT y copia la implementación generada.

### Paso 4: Desplegar y probar

Sigue los pasos de la Opción 1 desde el Paso 1.

---

## Troubleshooting

### Error: "Unable to locate credentials"

**Solución**: Configura tus credenciales de AWS:
```bash
aws configure
```

O si usas Codespaces, ver [AWS_CREDENTIALS_SETUP.md](AWS_CREDENTIALS_SETUP.md).

### Error: "AccessDenied" al desplegar

**Solución**: Tu usuario IAM necesita permisos. Contacta al instructor.

### Las funciones retornan 501

**Solución**: Las funciones no están implementadas. Usa la Opción 1 (código pre-implementado) o implementa usando la Opción 2.

### El frontend muestra "Error al cargar productos"

**Soluciones**:
1. Verifica que el backend esté desplegado
2. Verifica que `deploy-frontend.sh` haya reemplazado la API URL
3. Espera 15-20 minutos si acabas de desplegar CloudFront
4. Revisa CloudWatch Logs de las funciones Lambda

---

## Próximos Pasos

1. ✅ **Lee** [CAPSTONE_OVERVIEW.md](CAPSTONE_OVERVIEW.md) para entender el proyecto completo
2. ✅ **Revisa** las especificaciones en `docs/specs/` para entender cada función
3. ✅ **Explora** los prompts en `docs/prompts/` para ver cómo usar IA efectivamente
4. ✅ **Personaliza** el frontend o las funciones según tus necesidades
5. ✅ **Documenta** tu proceso en el README de tu fork
6. ✅ **Comparte** tu repositorio como evidencia de tu proyecto capstone

---

## Estructura del Proyecto

```
techmoda-serverless-capstone-starter/
├── functions/                   # 5 funciones Lambda (implementadas)
│   ├── list-items/             # GET /products
│   ├── create-item/            # POST /products
│   ├── get-item/               # GET /products/{id}
│   ├── update-item/            # PUT /products/{id}
│   └── delete-item/            # DELETE /products/{id}
├── frontend/                    # React app (opcional)
├── docs/
│   ├── specs/                  # Especificaciones detalladas
│   └── prompts/                # Prompts para IA
├── scripts/
│   ├── build.sh                # Construir backend
│   ├── deploy.sh               # Desplegar backend
│   ├── build-frontend.sh       # Construir frontend
│   ├── deploy-frontend.sh      # Desplegar frontend
│   └── delete.sh               # Eliminar todo
├── template.yaml               # SAM template (infraestructura)
├── QUICKSTART.md               # Esta guía
└── README.md                   # Documentación completa
```

---

## Recursos Adicionales

- **AWS SAM Docs**: https://docs.aws.amazon.com/serverless-application-model/
- **DynamoDB Developer Guide**: https://docs.aws.amazon.com/dynamodb/
- **API Gateway REST API**: https://docs.aws.amazon.com/apigateway/

---

**¡Éxito con tu proyecto capstone!** 🚀
