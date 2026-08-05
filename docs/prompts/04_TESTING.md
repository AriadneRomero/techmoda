# Plantillas de Prompts: Pruebas

Estos prompts le ayudan a probar sus endpoints de la API de TechModa usando comandos curl y a solucionar problemas de solicitudes fallidas.

## Prompt 4.1: Generar Comandos Curl para Todos los Endpoints

```
I have deployed my TechModa capstone API and need curl commands to test all 5 endpoints.

API Gateway URL: https://{api-id}.execute-api.us-east-1.amazonaws.com/Prod

Endpoints to test:
1. GET /products (list all)
2. POST /products (create new)
3. GET /products/{id} (get by id)
4. PUT /products/{id} (update)
5. DELETE /products/{id} (delete)

Please provide:
1. Curl command for each endpoint
2. Sample request bodies where applicable
3. Expected response status codes (200, 201, 404)
4. How to capture productId from create response for use in other commands
```

## Prompt 4.2: Depurar Solicitud de API Fallida

```
I'm getting an error when calling my API endpoint.

Endpoint: [GET/POST/PUT/DELETE] /products[/{id}]

Curl command:
[paste your curl command]

Error response:
[paste error response]

Please help me:
1. Interpret the error message
2. Identify likely cause (Lambda error, API Gateway config, DynamoDB permissions)
3. Suggest where to look for logs (CloudWatch Logs)
4. Provide debugging steps
```

## Instrucciones de Uso

### Flujo de Trabajo de Pruebas

Siga esta secuencia para pruebas completas:

1. **Crear Producto** → Obtener productId
2. **Listar Productos** → Verificar que el producto aparece
3. **Obtener Producto** → Recuperar por ID
4. **Actualizar Producto** → Modificar atributos
5. **Eliminar Producto** → Eliminar del catálogo

### Guardar URL de API

```bash
export API_URL="https://abc123xyz.execute-api.us-east-1.amazonaws.com/Prod"
```

### Probar Todos los Endpoints

Use prompts para generar comandos curl específicos para su API.

## Ejemplos de Escenarios de Prueba

### Escenario 1: Crear y Verificar Producto

**Prompt**:
```
I want to test creating a product and then verifying it exists.

My API URL: [your URL]

Please provide:
1. Curl command to create a product with name "Test Jacket" and price 99.99
2. Command to capture the productId from response
3. Curl command to verify product exists with GET /products
4. Curl command to retrieve specific product by ID
```

### Escenario 2: Actualizar y Verificar Cambios

**Prompt**:
```
I have created a product and want to test updating it.

Product ID: [your productId]
API URL: [your URL]

Please provide:
1. Curl command to update the price to 79.99
2. Curl command to verify the update worked
3. How to check that updatedAt timestamp changed
```

### Escenario 3: Eliminar y Verificar Eliminación

**Prompt**:
```
I want to test deleting a product and confirming it's gone.

Product ID: [your productId]
API URL: [your URL]

Please provide:
1. Curl command to delete the product
2. Curl command to verify product no longer exists (should return 404)
3. Curl command to list all products (deleted one shouldn't appear)
```

### Escenario 4: Probar Manejo de Errores

**Prompt**:
```
I want to test my API's error handling.

API URL: [your URL]

Please provide curl commands to test:
1. Creating product without required field (name)
2. Getting non-existent product (should return 404)
3. Updating non-existent product (should return 404)
4. Creating product with invalid JSON
```

## Prompts de Depuración

### 500 Internal Server Error

```
I'm getting a 500 Internal Server Error from my API.

Endpoint: [endpoint]
HTTP Method: [GET/POST/PUT/DELETE]
Curl command: [paste command]

Response:
{
  "error": "Internal server error",
  "message": "Failed to [action]"
}

Please help me:
1. Identify which Lambda function handles this endpoint
2. Show me how to check CloudWatch Logs for this function
3. What common issues cause 500 errors (DynamoDB permissions, syntax errors, etc.)
4. How to fix the issue
```

### 404 Not Found (Inesperado)

```
I'm getting a 404 Not Found but the product should exist.

Product ID: [productId]
Created with: POST /products at [timestamp]

Curl command:
curl -X GET $API_URL/products/[productId]

Response:
{
  "error": "Not Found",
  "message": "Product not found"
}

Please help me:
1. Verify the productId is correct
2. Check if product exists in DynamoDB
3. Verify GetItem function is working correctly
4. Debug why product isn't being found
```

### 400 Bad Request

```
I'm getting a 400 Bad Request error.

Endpoint: POST /products
Curl command: [paste command]

Response:
{
  "error": "Bad Request",
  "message": "[error message]"
}

Please help me:
1. Check if required fields are provided
2. Verify JSON syntax is correct
3. Identify which validation is failing
4. Fix the request
```

### 403 Forbidden

```
I'm getting a 403 Forbidden error.

Endpoint: [endpoint]
Error: AccessDeniedException

Please help me:
1. Check if Lambda has DynamoDB permissions
2. Verify IAM role policies in template.yaml
3. How to fix permission issues
4. Redeploy if needed
```

### Sin Respuesta / Timeout

```
My API request is timing out or returning no response.

Endpoint: [endpoint]
Curl command: [paste command]

Behavior: Request hangs for 30 seconds then times out

Please help me:
1. Check if Lambda function is timing out
2. Look for infinite loops or blocking operations
3. Check CloudWatch Logs for timeout errors
4. How to increase Lambda timeout if needed
```

## Prompts de Pruebas Avanzadas

### Probar con jq para Salida Formateada

```
I want to format my curl responses with jq for better readability.

Please show me:
1. How to pipe curl output to jq
2. Command to extract specific fields (like productId)
3. How to save response to file and parse it
```

### Probar con Alternativa a Postman

```
I prefer using a GUI tool instead of curl.

Please recommend:
1. Alternative tools to curl (Postman, Insomnia, etc.)
2. How to import my API into the tool
3. How to set up environment variables for API URL
```

### Script de Pruebas Automatizado

```
I want to create a bash script that tests all endpoints automatically.

Please provide:
1. Complete bash script that:
   - Creates a product
   - Lists all products
   - Gets product by ID
   - Updates product
   - Deletes product
2. Error checking at each step
3. Clean output showing pass/fail for each test
```

## Lista de Verificación

Después de las pruebas, verifique:

✅ **Create** (POST /products)
   - Devuelve 201 Created
   - Incluye productId en la respuesta
   - El producto tiene timestamps

✅ **List** (GET /products)
   - Devuelve 200 OK
   - Muestra todos los productos creados
   - Array vacío si no hay productos

✅ **Get** (GET /products/{id})
   - Devuelve 200 OK para producto existente
   - Devuelve 404 para producto no existente
   - La respuesta coincide con el producto creado

✅ **Update** (PUT /products/{id})
   - Devuelve 200 OK
   - Los campos actualizados cambiaron
   - El timestamp updatedAt es más reciente que createdAt
   - Devuelve 404 para producto no existente

✅ **Delete** (DELETE /products/{id})
   - Devuelve 200 OK
   - El GET subsecuente devuelve 404
   - El producto se eliminó de la lista

## Problemas Comunes y Soluciones

### Problema: Connection Refused

**Prompt**:
```
Curl is giving me "Connection refused" error.

Error: curl: (7) Failed to connect to [host] port 443: Connection refused

Please help me:
1. Verify my API Gateway URL is correct
2. Check if deployment completed successfully
3. Test connectivity to AWS
```

### Problema: JSON Malformado

**Prompt**:
```
I'm getting JSON parse errors.

My curl command:
[paste command]

Error: Invalid JSON in request body

Please help me:
1. Validate my JSON syntax
2. Check if I need to escape quotes
3. Show correct format for curl -d flag
```

### Problema: Error CORS en el Navegador

**Prompt**:
```
My API works with curl but fails in browser with CORS error.

Error: Access to fetch at '...' from origin '...' has been blocked by CORS policy

Please help me:
1. Verify CORS headers are in Lambda responses
2. Check if OPTIONS method is configured
3. Fix CORS configuration
```

## Próximos Pasos

Después de pruebas exitosas:

1. Documente los resultados de las pruebas (capturas de pantalla opcionales)
2. Verifique que los CloudWatch Logs muestren las ejecuciones
3. Revise los traces de X-Ray
4. Proceda a [Guía de Depuración](05_DEBUGGING.md) si se encuentran problemas
5. Continúe a [Prompts de Operaciones](06_OPERATIONS.md) para monitoreo
