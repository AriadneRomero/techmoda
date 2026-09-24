#!/bin/bash

# Script S5: Generar audio en español para TODOS los productos con Amazon Polly

# Obtener URL de S05 (Polly)
POLLY_URL=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='SynthesizeVoiceUrl'].OutputValue" --output text)

# Obtener API URL para listar productos
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)

# Validar que las URLs se obtuvieron correctamente
if [ -z "$POLLY_URL" ] || [ -z "$API" ]; then
  echo "❌ Error: No se pudieron obtener las URLs del stack"
  echo "   Verifica que el stack 'techmoda-ai-selena-romero' existe"
  exit 1
fi

# Quitar slash final
POLLY_URL="${POLLY_URL%/}"
API="${API%/}"

echo "🎵 S05: Generando audio con Amazon Polly (Español)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Listar todos los productos
echo "📋 Obteniendo lista de productos..."
PRODUCTS=$(curl -s "${API}/products" | python3 -c "import sys, json; products = json.load(sys.stdin).get('products', []); print('\n'.join([p['productId'] for p in products]))" 2>/dev/null)

if [ -z "$PRODUCTS" ]; then
  echo "❌ No hay productos disponibles"
  exit 1
fi

TOTAL=$(echo "$PRODUCTS" | wc -l)
echo "✅ Se encontraron $TOTAL productos"
echo ""

# Para cada producto, generar audio en español
echo "🎤 Generando audio para cada producto en español..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONTADOR=0
EXITOSOS=0
ERRORES=0

for PRODUCT_ID in $PRODUCTS; do
    CONTADOR=$((CONTADOR + 1))
    echo ""
    echo "[$CONTADOR/$TOTAL] Procesando: $PRODUCT_ID"

    # Llamar a Polly para generar audio en español
    RESULT=$(curl -s -X POST "${POLLY_URL}/products/${PRODUCT_ID}/voice" \
      -H "Content-Type: application/json" \
      -d '{"lang":"es"}')

    # Verificar si fue exitoso
    if echo "$RESULT" | python3 -c "import sys, json; json.load(sys.stdin)" 2>/dev/null; then
      # Extraer información de la respuesta de Polly
      PRODUCT_ID_RESP=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('productId', 'UNKNOWN'))")
      LANG=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('lang', 'UNKNOWN'))")
      VOICE=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('voice', 'UNKNOWN'))")
      AUDIO_URL=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('audioUrl', '')[:80] + '...')")
      EXPIRES_IN=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('expiresIn', '0'))")

      echo "    ✅ Audio generado exitosamente:"
      echo "       • Idioma: $LANG"
      echo "       • Voz neuronal: $VOICE"
      echo "       • Válido por: $EXPIRES_IN segundos (1 hora)"
      echo "       • URL: $AUDIO_URL"

      EXITOSOS=$((EXITOSOS + 1))
    else
      # Hubo error
      ERROR_MSG=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('error', 'Error desconocido'))" 2>/dev/null || echo "Error al parsear JSON")

      echo "    ❌ Error: $ERROR_MSG"
      ERRORES=$((ERRORES + 1))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMEN FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Total procesados: $CONTADOR"
echo "   ✅ Exitosos: $EXITOSOS"
echo "   ❌ Errores: $ERRORES"
echo ""

if [ $EXITOSOS -eq $TOTAL ]; then
  echo "🎉 ¡Listo! Todos los productos tienen audio en español"
  exit 0
else
  echo "⚠️  Se completó con algunos errores. Revisa los productos fallidos."
  exit 1
fi
