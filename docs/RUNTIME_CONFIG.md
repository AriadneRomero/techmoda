# Runtime Configuration - Inyección de Variables de Entorno

## 📋 Resumen

Este documento explica el sistema de inyección runtime de configuración del frontend, que permite configurar la URL del API Gateway en tiempo de despliegue sin necesidad de reconstruir el bundle de React.

## 🎯 Problema Resuelto

**Antes:**
- El placeholder `https://your-api-id.execute-api.us-east-1.amazonaws.com/Prod` causaba `net::ERR_NAME_NOT_RESOLVED`
- Cambiar la URL requería rebuild del frontend (lento, costoso)
- Método de `sed` sobre archivos JS compilados era frágil y dependiente del OS

**Ahora:**
- ✅ URL del API se configura en **runtime** sin rebuild
- ✅ Un solo build puede usarse en múltiples entornos
- ✅ Mayor flexibilidad en CI/CD
- ✅ Método robusto e independiente de minificación

## 🔧 Arquitectura

### Flujo de Datos

```
1. Build Time (npm run build)
   ├── Vite compila el bundle
   ├── env-config.js.template → copiado a dist/
   └── Bundle contiene código que lee window.__ENV

2. Deploy Time (scripts/deploy-frontend.sh)
   ├── inject-env.sh ejecutado
   ├── %%VITE_API_URL%% → reemplazado con URL real
   └── env-config.js generado en dist/

3. Runtime (navegador del usuario)
   ├── index.html carga env-config.js
   ├── window.__ENV.VITE_API_URL definido
   ├── Bundle principal carga
   └── api.ts lee window.__ENV (prioridad #1)
```

### Prioridad de Configuración

```javascript
const API_URL =
  window.__ENV?.VITE_API_URL ||           // 1. Runtime (producción)
  import.meta.env.VITE_API_URL ||         // 2. Build-time (desarrollo)
  'https://your-api-id...';               // 3. Fallback
```

## 📁 Archivos Clave

### 1. `frontend/public/env-config.js.template`

Template que contiene el token de reemplazo:

```javascript
window.__ENV = {
  VITE_API_URL: '%%VITE_API_URL%%'
};
```

**Importante:**
- El token `%%VITE_API_URL%%` debe ser exacto
- No minificar este archivo
- Mantener en control de versiones

### 2. `frontend/public/env-config.js`

Versión de desarrollo (commited a git):

```javascript
window.__ENV = {
  VITE_API_URL: undefined  // Fallback a .env en dev
};
```

### 3. `frontend/dist/env-config.js`

Generado en producción (NO en git):

```javascript
window.__ENV = {
  VITE_API_URL: 'https://abc123.execute-api.us-east-1.amazonaws.com/Prod'
};
```

### 4. `frontend/index.html`

Carga env-config.js antes del bundle:

```html
<body>
  <div id="root"></div>
  <!-- Runtime config PRIMERO -->
  <script src="/env-config.js"></script>
  <!-- Bundle principal DESPUÉS -->
  <script type="module" src="/src/main.tsx"></script>
</body>
```

**Orden crítico:** env-config.js debe cargarse antes del bundle para que `window.__ENV` esté disponible.

### 5. `frontend/src/lib/api.ts`

Lee la configuración runtime:

```typescript
declare global {
  interface Window {
    __ENV?: {
      VITE_API_URL?: string;
    };
  }
}

const API_URL =
  window.__ENV?.VITE_API_URL ||
  import.meta.env.VITE_API_URL ||
  'https://your-api-id.execute-api.us-east-1.amazonaws.com/Prod';
```

### 6. `scripts/inject-env.sh`

Script que realiza el reemplazo:

```bash
./scripts/inject-env.sh \
  --api-url "https://abc123.execute-api.us-east-1.amazonaws.com/Prod" \
  --dist-dir "frontend/dist"
```

**Qué hace:**
1. Valida parámetros requeridos
2. Verifica que dist/ existe
3. Lee env-config.js.template
4. Reemplaza %%VITE_API_URL%% con valor real usando `sed`
5. Genera env-config.js en dist/

## 🚀 Uso

### Desarrollo Local

```bash
cd frontend
cp .env.example .env
# Editar .env con tu API URL
npm install
npm run dev
```

La app usa `import.meta.env.VITE_API_URL` del archivo `.env`.

### Despliegue a Producción

```bash
# Opción 1: Script todo-en-uno
./scripts/deploy-all.sh

# Opción 2: Paso a paso
./scripts/build-frontend.sh
./scripts/deploy-frontend.sh
```

`deploy-frontend.sh` ejecuta automáticamente `inject-env.sh`.

### Manual (para testing)

```bash
# 1. Build
cd frontend
npm run build
cd ..

# 2. Inyectar configuración
./scripts/inject-env.sh \
  --api-url "https://abc123.execute-api.us-east-1.amazonaws.com/Prod"

# 3. Verificar
cat frontend/dist/env-config.js

# 4. Desplegar
aws s3 sync frontend/dist/ s3://your-bucket/
```

## ✅ Verificación

### En el Navegador (DevTools)

Abre DevTools > Console:

```javascript
// 1. Verificar que window.__ENV existe
console.log(window.__ENV);
// Output: { VITE_API_URL: "https://abc123..." }

// 2. Verificar que no es undefined
console.log(window.__ENV?.VITE_API_URL);
// Output: "https://abc123.execute-api.us-east-1.amazonaws.com/Prod"

// 3. Revisar llamadas de red
// Network tab > filtrar por "products"
// Domain debería ser: abc123.execute-api.us-east-1.amazonaws.com
```

### En el Servidor

```bash
# Descargar env-config.js del sitio desplegado
curl https://your-cloudfront-url.cloudfront.net/env-config.js

# Debería mostrar:
# window.__ENV = {
#   VITE_API_URL: 'https://abc123.execute-api.us-east-1.amazonaws.com/Prod'
# };
```

## 🐛 Troubleshooting

### Error: `net::ERR_NAME_NOT_RESOLVED`

**Causa:** La URL del API sigue siendo el placeholder.

**Solución:**
```bash
# 1. Verificar en el navegador
console.log(window.__ENV);
// Si es undefined o contiene placeholder → problema de inyección

# 2. Verificar archivo en S3
aws s3 cp s3://your-bucket/env-config.js -

# 3. Re-inyectar y re-desplegar
./scripts/inject-env.sh --api-url "https://..."
aws s3 sync frontend/dist/ s3://your-bucket/

# 4. Invalidar CloudFront
aws cloudfront create-invalidation \
  --distribution-id YOUR_DIST_ID \
  --paths "/env-config.js" "/index.html"
```

### Error: `env-config.js` no se carga (404)

**Causa:** Archivo no existe en dist/ o no se subió a S3.

**Solución:**
```bash
# 1. Verificar que existe localmente
ls -la frontend/dist/env-config.js

# 2. Si no existe, ejecutar inject-env.sh
./scripts/inject-env.sh --api-url "https://..."

# 3. Re-subir a S3
aws s3 cp frontend/dist/env-config.js s3://your-bucket/
```

### Error: Token `%%VITE_API_URL%%` visible en producción

**Causa:** inject-env.sh no se ejecutó o falló.

**Solución:**
```bash
# Verificar que template existe
cat frontend/public/env-config.js.template

# Ejecutar manualmente con debug
bash -x ./scripts/inject-env.sh --api-url "https://..."

# Verificar output
cat frontend/dist/env-config.js
```

### Cache de CloudFront

**Problema:** Cambios no se ven inmediatamente.

**Solución:**
```bash
# Invalidar cache
DIST_ID=$(aws cloudformation describe-stacks \
  --stack-name techmoda-capstone \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
  --output text)

aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/*"

# O solo invalidar archivos específicos
aws cloudfront create-invalidation \
  --distribution-id $DIST_ID \
  --paths "/env-config.js" "/index.html"
```

## 🔒 Seguridad

### ¿Es seguro exponer la URL del API?

**Sí**, por las siguientes razones:

1. **URL pública:** La URL de API Gateway es pública de todas formas (necesaria para que el navegador la llame)
2. **No contiene credenciales:** La URL no incluye API keys ni tokens de autenticación
3. **CORS configurado:** API Gateway controla qué dominios pueden hacer requests
4. **Sin secretos:** `env-config.js` solo contiene la URL, no secretos

### Qué NO incluir en `window.__ENV`

❌ **NO** incluir:
- API keys
- Tokens de autenticación
- Secretos de AWS
- Credenciales de bases de datos
- Cualquier información sensible

✅ **Sí** incluir:
- URL del API (pública)
- Region de AWS (pública)
- IDs de recursos públicos
- Feature flags públicos

### CSP (Content Security Policy)

Si tu sitio usa CSP strict, podrías necesitar permitir scripts inline:

```html
<meta http-equiv="Content-Security-Policy"
      content="script-src 'self' 'unsafe-inline';">
```

**Alternativa más segura:** Usar hash específico:

```bash
# Calcular hash del script
echo -n "window.__ENV={VITE_API_URL:'...'}" | \
  openssl dgst -sha256 -binary | \
  openssl base64

# Usar en CSP
script-src 'self' 'sha256-HASH_AQUI';
```

## 📊 Casos de Uso

### Multi-entorno (Dev, Staging, Prod)

```bash
# Development
./scripts/inject-env.sh \
  --api-url "https://dev-api.execute-api.us-east-1.amazonaws.com/Prod"

# Staging
./scripts/inject-env.sh \
  --api-url "https://staging-api.execute-api.us-east-1.amazonaws.com/Prod"

# Production
./scripts/inject-env.sh \
  --api-url "https://prod-api.execute-api.us-east-1.amazonaws.com/Prod"
```

**Ventaja:** El mismo bundle (`dist/`) puede usarse en todos los entornos, solo cambiando `env-config.js`.

### CI/CD Pipeline

```yaml
# .github/workflows/deploy.yml
- name: Build Frontend
  run: npm run build
  working-directory: frontend

- name: Inject Runtime Config
  run: |
    ./scripts/inject-env.sh \
      --api-url "${{ secrets.API_URL }}" \
      --dist-dir frontend/dist

- name: Deploy to S3
  run: aws s3 sync frontend/dist/ s3://${{ secrets.S3_BUCKET }}/
```

### Docker/Nginx

```dockerfile
# Dockerfile
FROM nginx:alpine
COPY frontend/dist /usr/share/nginx/html
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
```

```bash
# docker-entrypoint.sh
#!/bin/sh
sed "s|%%VITE_API_URL%%|${API_URL}|g" \
  /usr/share/nginx/html/env-config.js.template > \
  /usr/share/nginx/html/env-config.js

exec nginx -g 'daemon off;'
```

```bash
# Ejecutar
docker run -e API_URL="https://..." -p 80:80 my-frontend
```

## 🎓 Mejores Prácticas

1. **Nunca committear `dist/env-config.js`** - Debe generarse en cada despliegue
2. **Mantener template simple** - Solo variables esenciales
3. **Validar en CI/CD** - Verificar que token fue reemplazado
4. **Invalidar cache** - Especialmente para `env-config.js` e `index.html`
5. **Logging en desarrollo** - Ayuda a debug (ver `api.ts`)
6. **Documentar nuevas variables** - Actualizar este doc si añades más config

## 📚 Referencias

- [12 Factor App - Config](https://12factor.net/config)
- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [React Runtime Config](https://www.freecodecamp.org/news/how-to-implement-runtime-environment-variables-with-create-react-app-docker-and-nginx-7f9d42a91d70/)

## ⏱️ Tiempo Estimado

- **Setup inicial:** 10-15 minutos
- **Integración en pipeline:** 5-10 minutos
- **Testing y verificación:** 5-10 minutos
- **Total:** 20-35 minutos

---

**Última actualización:** 2024-11-09
**Versión:** 1.0
