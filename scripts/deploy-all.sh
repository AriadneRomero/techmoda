#!/bin/bash
#
# Deploy ALL script for TechModa Serverless Capstone
# This script deploys both backend (Lambda + API Gateway + DynamoDB) and frontend (React app to S3/CloudFront)
#

set -e

echo "=========================================="
echo "  TechModa - Despliegue Completo"
echo "=========================================="
echo ""

# Get stack name from samconfig.toml or use default
STACK_NAME="techmoda-capstone"
if [ -f "samconfig.toml" ]; then
    STACK_NAME=$(grep 'stack_name' samconfig.toml | cut -d'"' -f2 || echo "techmoda-capstone")
fi

echo "📦 Paso 1/4: Construyendo Backend..."
echo "-------------------------------------------"
sam build
echo "✅ Backend construido exitosamente"
echo ""

echo "🚀 Paso 2/4: Desplegando Backend..."
echo "-------------------------------------------"
# Check if samconfig.toml exists
if [ ! -f "samconfig.toml" ]; then
    echo "⚠️  Primera vez desplegando. Se te harán algunas preguntas..."
    echo ""
    sam deploy --guided
else
    echo "📝 Usando configuración existente en samconfig.toml"
    sam deploy
fi
echo "✅ Backend desplegado exitosamente"
echo ""

# Get API URL for display later
API_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text 2>/dev/null || echo "")

echo "🎨 Paso 3/4: Construyendo Frontend..."
echo "-------------------------------------------"
cd frontend
if [ ! -d "node_modules" ]; then
    echo "📥 Instalando dependencias..."
    npm install
fi
echo "🔨 Compilando aplicación React..."
npm run build
cd ..
echo "✅ Frontend construido exitosamente"
echo ""

echo "☁️  Paso 4/4: Desplegando Frontend a S3..."
echo "-------------------------------------------"
./scripts/deploy-frontend.sh
echo ""

echo "=========================================="
echo "  ✅ ¡DESPLIEGUE COMPLETO EXITOSO!"
echo "=========================================="
echo ""
echo "📋 URLs de tu aplicación:"
echo "-------------------------------------------"
if [ -n "$API_URL" ]; then
    echo "🔗 API Backend:"
    echo "   $API_URL"
fi
echo ""
echo "🌐 Frontend Web:"
CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendUrl`].OutputValue' \
    --output text 2>/dev/null || echo "")
if [ -n "$CLOUDFRONT_URL" ]; then
    echo "   $CLOUDFRONT_URL"
    echo ""
    echo "⏱️  Nota: CloudFront puede tardar 15-20 minutos en estar"
    echo "   completamente disponible después del primer despliegue."
fi
echo ""
echo "📝 Próximos pasos:"
echo "   1. Prueba tu API con curl (ver docs/TESTING_GUIDE.md)"
echo "   2. Abre el frontend en tu navegador"
echo "   3. Cuando termines, ejecuta: ./scripts/delete-all.sh"
echo "=========================================="
