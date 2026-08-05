#!/bin/bash
#
# Delete ALL script for TechModa Serverless Capstone
# This script deletes the entire CloudFormation stack (Backend + Frontend)
#

set -e

echo "=========================================="
echo "  TechModa - Eliminar Recursos"
echo "=========================================="
echo ""

# Get stack name from samconfig.toml or use default
STACK_NAME="techmoda-capstone"
if [ -f "samconfig.toml" ]; then
    STACK_NAME=$(grep 'stack_name' samconfig.toml | cut -d'"' -f2 || echo "techmoda-capstone")
fi

# Check if stack exists
echo "🔍 Verificando si el stack existe..."
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" &>/dev/null; then
    echo "❌ El stack '$STACK_NAME' no existe o ya fue eliminado."
    exit 0
fi

echo "📋 Stack encontrado: $STACK_NAME"
echo ""
echo "⚠️  ADVERTENCIA: Esta acción eliminará:"
echo "   • API Gateway y todos los endpoints"
echo "   • 5 Funciones Lambda"
echo "   • Tabla DynamoDB con todos los productos"
echo "   • Bucket S3 del frontend"
echo "   • Distribución CloudFront"
echo "   • Todos los roles y políticas IAM"
echo ""
echo "💡 Esta operación es IRREVERSIBLE"
echo ""

read -p "¿Estás seguro de eliminar todos los recursos? (escribe 'si' para confirmar): " CONFIRM

if [ "$CONFIRM" = "si" ] || [ "$CONFIRM" = "SI" ] || [ "$CONFIRM" = "yes" ]; then
    echo ""

    # Step 1: Empty S3 buckets first
    echo "📦 Paso 1/2: Vaciando buckets S3..."
    echo "-------------------------------------------"

    # Get Frontend Bucket Name
    FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
        --output text 2>/dev/null || echo "")

    if [ -n "$FRONTEND_BUCKET" ] && [ "$FRONTEND_BUCKET" != "None" ]; then
        echo "🗑️  Vaciando bucket del frontend: $FRONTEND_BUCKET"
        aws s3 rm s3://$FRONTEND_BUCKET/ --recursive 2>/dev/null || echo "   ⚠️  Bucket ya estaba vacío o no existe"
    fi

    # Get SAM deployment bucket (artifacts)
    SAM_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query 'Stacks[0].Outputs[?contains(OutputKey, `Bucket`)].OutputValue' \
        --output text 2>/dev/null | awk '{print $1}' || echo "")

    # Also try to get deployment bucket from stack resources
    DEPLOYMENT_BUCKETS=$(aws cloudformation list-stack-resources \
        --stack-name "$STACK_NAME" \
        --query 'StackResourceSummaries[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
        --output text 2>/dev/null || echo "")

    for BUCKET in $DEPLOYMENT_BUCKETS; do
        if [ -n "$BUCKET" ] && [ "$BUCKET" != "$FRONTEND_BUCKET" ]; then
            echo "🗑️  Vaciando bucket: $BUCKET"
            aws s3 rm s3://$BUCKET/ --recursive 2>/dev/null || echo "   ⚠️  Bucket ya estaba vacío o no existe"
        fi
    done

    echo "✅ Buckets vaciados"
    echo ""

    # Step 2: Delete the stack
    echo "🗑️  Paso 2/2: Eliminando stack..."
    echo "-------------------------------------------"
    sam delete --stack-name "$STACK_NAME" --no-prompts

    echo ""
    echo "=========================================="
    echo "  ✅ ¡RECURSOS ELIMINADOS EXITOSAMENTE!"
    echo "=========================================="
    echo ""
    echo "💰 Tus recursos de AWS han sido eliminados."
    echo "   No se generarán más cargos."
    echo ""
    echo "📝 Próximos pasos:"
    echo "   • Puedes volver a desplegar cuando quieras con:"
    echo "     ./scripts/deploy-all.sh"
    echo "=========================================="
else
    echo ""
    echo "❌ Eliminación cancelada. No se eliminaron recursos."
    exit 1
fi
