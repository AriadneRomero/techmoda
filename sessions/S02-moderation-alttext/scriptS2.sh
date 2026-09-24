#!/bin/bash

# Obtener URL de S02
URL=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ModerateImageUrl'].OutputValue" --output text)

# Obtener API URL para listar productos
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)

# Listar todos los productos
echo "📋 Obteniendo lista de productos..."
PRODUCTS=$(curl -s "${API}products" | python3 -c "import sys, json; products = json.load(sys.stdin)['products']; print('\n'.join([p['productId'] for p in products]))")

# Para cada producto, llamar a Rekognition S02 (Moderación)
echo "🔍 Aplicando Rekognition a cada producto..."
for PRODUCT_ID in $PRODUCTS; do
    echo "  Procesando: $PRODUCT_ID"
    RESULT=$(curl -s -X POST "${URL%/}/products/$PRODUCT_ID/moderate")
    
    # Extraer campos correctos de S02
    STATUS=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('moderationStatus', 'UNKNOWN'))")
    FLAGS=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); flags = data.get('moderationFlags', []); print(', '.join(flags) if flags else 'Ninguno')" 2>/dev/null || echo "ERROR")
    
    echo "    🔐 Estado: $STATUS | Flags: $FLAGS"
done

echo "✅ ¡Listo! Todos los productos fueron moderados"