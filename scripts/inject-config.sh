#!/bin/bash
# Inyecta la configuración de la API en el index.html DESPUÉS del build de Vite

API_URL="${1:-https://your-function-url-id.lambda-url.us-east-1.on.aws/}"
HTML_FILE="${2:-frontend/dist/index.html}"

# Quitar slash final de la API URL
API_URL="${API_URL%/}"

# Crear el script inline
CONFIG_SCRIPT="    <script>
      window.__ENV__ = {
        VITE_API_URL: '$API_URL'
      };
      console.log('✓ Config cargado:', window.__ENV__);
    </script>"

# Inyectar el script en el <head> ANTES del primer <script type="module">
sed -i "/<script type=\"module\"/i $CONFIG_SCRIPT" "$HTML_FILE"

echo "✓ Configuración inyectada en $HTML_FILE"
echo "  API URL: $API_URL"
