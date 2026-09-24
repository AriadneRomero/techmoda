#!/bin/bash

# Obtener URL de S01
URL=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='EnrichLabelsUrl'].OutputValue" --output text)

# Obtener API URL para listar productos
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)

# Listar todos los productos
echo "📋 Obteniendo lista de productos..."
PRODUCTS=$(curl -s "${API}products" | python3 -c "import sys, json; products = json.load(sys.stdin)['products']; print('\n'.join([p['productId'] for p in products]))")

# Para cada producto, llamar a Rekognition
echo "🔍 Aplicando Rekognition a cada producto..."
for PRODUCT_ID in $PRODUCTS; do
    echo "  Procesando: $PRODUCT_ID"
    RESULT=$(curl -s -X POST "${URL}products/$PRODUCT_ID/labels")
    LABELS=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(', '.join([l['name'] for l in data.get('labels', [])]))")
    echo "    ✓ Etiquetas: $LABELS"
done

echo "✅ ¡Listo! Todos los productos fueron etiquetados"