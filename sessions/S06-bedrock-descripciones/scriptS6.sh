#!/bin/bash

# ============================================================================
# S06 · Generar descripción de un producto (simple)
# ============================================================================
# Uso:
#   bash scriptS6.sh
#   → Muestra lista de productos
#   → Ingresa el ID del producto
#   → Genera la descripción automáticamente
#
# Configuración (edita acá si quieres cambiar):
#   TONE: tono de la descripción
#   SAVE: guardar en DynamoDB (true/false)
# ============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# CONFIGURACIÓN (EDITA AQUÍ)
# ============================================================================

# Tonos sugeridos:
#   • elegante y aspiracional (default)
#   • divertido y juvenil
#   • minimalista y sofisticado
#   • urbano y desenfadado
#   • exclusivo y premium
#   • casual y relajado

STACK_NAME="techmoda-ai-selena-romero"
REGION="${AWS_REGION:-us-east-1}"
TONE="elegante y aspiracional"
SAVE="true"
MAX_TOKENS="33"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}S06 · Generar Descripción con Amazon Bedrock${NC}"
echo -e "${BLUE}Stack: $STACK_NAME | Region: $REGION | Tono: $TONE${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# ============================================================================
# PASO 1: Obtener URLs
# ============================================================================

echo -e "${YELLOW}📍 Obteniendo URLs del stack...${NC}"

DESCRIBE_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='GenerateDescriptionUrl'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$DESCRIBE_URL" ] || [ "$DESCRIBE_URL" == "None" ]; then
  echo -e "${RED}Error: No se encontro GenerateDescriptionUrl${NC}"
  exit 1
fi

API=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
  --output text 2>/dev/null)

if [ -z "$API" ] || [ "$API" == "None" ]; then
  echo -e "${RED}Error: No se encontro ApiUrl${NC}"
  exit 1
fi

API="${API%/}"
DESCRIBE_URL="${DESCRIBE_URL%/}"

echo -e "${GREEN}OK${NC}"
echo ""

# ============================================================================
# PASO 2: Listar productos
# ============================================================================

echo -e "${YELLOW}📋 Productos disponibles:${NC}"
echo ""

PRODUCTS=$(curl -s "${API}/products" \
  | python3 -c "import sys, json; products = json.load(sys.stdin).get('products', []); [print(f\"{p['productId']}  {p.get('name', 'N/A')}\") for p in products]" 2>/dev/null)

if [ -z "$PRODUCTS" ]; then
  echo -e "${RED}No se encontraron productos${NC}"
  exit 1
fi

echo "$PRODUCTS"
echo ""

# ============================================================================
# PASO 3: Pedir ID del producto
# ============================================================================

printf "${CYAN}ID del producto: ${NC}"
read PRODUCT_ID

if [ -z "$PRODUCT_ID" ]; then
  echo -e "${RED}Debes ingresar un ID${NC}"
  exit 1
fi

echo ""
echo -e "${YELLOW}Generando descripcion...${NC}"
echo ""

# ============================================================================
# PASO 4: Generar descripción
# ============================================================================

RESULT=$(curl -s -X POST "${DESCRIBE_URL}/products/${PRODUCT_ID}/describe" \
  -H "Content-Type: application/json" \
  -d "{\"tone\":\"${TONE}\",\"save\":${SAVE}}" 2>/dev/null)

ERROR=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('error', ''))" 2>/dev/null || echo "")

if [ ! -z "$ERROR" ]; then
  echo -e "${RED}Error: $ERROR${NC}"
  exit 1
fi

# Extraer datos
DESCRIPTION=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('description', 'ERROR'))" 2>/dev/null || echo "ERROR")
INPUT_TOKENS=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('usage', {}).get('inputTokens', 0))" 2>/dev/null || echo "0")
OUTPUT_TOKENS=$(echo "$RESULT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('usage', {}).get('outputTokens', 0))" 2>/dev/null || echo "0")

# ============================================================================
# PASO 5: Mostrar resultado
# ============================================================================

echo -e "${GREEN}✅ Listo!${NC}"
echo ""
echo -e "${CYAN}ID:${NC} $PRODUCT_ID"
echo -e "${CYAN}Tono:${NC} $TONE"
echo -e "${CYAN}Guardada:${NC} $SAVE"
echo -e "${CYAN}Tokens:${NC} $INPUT_TOKENS + $OUTPUT_TOKENS = $((INPUT_TOKENS + OUTPUT_TOKENS))"
echo ""
echo -e "${CYAN}Descripcion:${NC}"
echo "$DESCRIPTION"
echo ""
