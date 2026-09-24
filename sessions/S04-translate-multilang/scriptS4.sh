#!/bin/bash

# Obtener URL de S04 (Translate)
URL=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='TranslateCatalogUrl'].OutputValue" --output text)

# Obtener API URL para listar productos
API=$(aws cloudformation describe-stacks --stack-name techmoda-ai-selena-romero \
  --region us-east-1 \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text)

# Listar todos los productos
echo "📋 Obteniendo lista de productos..."
PRODUCTS=$(curl -s "${API%/}/products" | python3 -c "import sys, json; products = json.load(sys.stdin)['products']; print('\n'.join([p['productId'] for p in products]))")

# Para cada producto, llamar a Translate S04
echo "🌐 Traduciendo todos los productos..."
for PRODUCT_ID in $PRODUCTS; do
    echo "  Procesando: $PRODUCT_ID"
    
    # Traducir al inglés
    RESULT=$(curl -s -X POST "${URL%/}/products/$PRODUCT_ID/translate" \
      -H "Content-Type: application/json" \
      -d '{"target":"en"}')
    
    # Extraer información de la traducción
    TARGET=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('target', 'UNKNOWN'))")
    NAME=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('translation', {}).get('name', 'ERROR'))" 2>/dev/null || echo "ERROR")
    DESC=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); desc = data.get('translation', {}).get('description', 'ERROR'); print(desc[:50] + '...' if len(desc) > 50 else desc)" 2>/dev/null || echo "ERROR")
    
    echo "    ✅ Traducción a $TARGET:"
    echo "       Nombre: $NAME"
    echo "       Descripción: $DESC"
done

echo ""
echo "✅ ¡Listo! Todos los productos han sido traducidos a inglés"
