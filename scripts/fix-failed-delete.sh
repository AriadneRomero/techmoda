#!/bin/bash
#
# Fix Failed Delete - Recovery script for TechModa
# Use this script when delete-all.sh failed due to non-empty S3 buckets
#

set -e

echo "=========================================="
echo "  TechModa - Recuperación de Eliminación"
echo "=========================================="
echo ""

# Get stack name from samconfig.toml or use default
STACK_NAME="techmoda-capstone"
if [ -f "samconfig.toml" ]; then
    STACK_NAME=$(grep 'stack_name' samconfig.toml | cut -d'"' -f2 || echo "techmoda-capstone")
fi

echo "🔧 Intentando recuperar del error DELETE_FAILED"
echo "Stack: $STACK_NAME"
echo ""

# Check if stack exists and is in DELETE_FAILED state
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" = "NOT_FOUND" ]; then
    echo "✅ El stack no existe. Ya fue eliminado exitosamente."
    exit 0
fi

echo "📊 Estado actual del stack: $STACK_STATUS"
echo ""

if [ "$STACK_STATUS" != "DELETE_FAILED" ]; then
    echo "⚠️  El stack no está en estado DELETE_FAILED"
    echo "   Estado actual: $STACK_STATUS"
    echo ""
    echo "💡 Si quieres eliminar el stack, ejecuta:"
    echo "   ./scripts/delete-all.sh"
    exit 0
fi

echo "🔍 Paso 1: Identificando buckets S3 problemáticos..."
echo "-------------------------------------------"

# Get all S3 buckets from the stack
DEPLOYMENT_BUCKETS=$(aws cloudformation list-stack-resources \
    --stack-name "$STACK_NAME" \
    --query 'StackResourceSummaries[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId' \
    --output text 2>/dev/null || echo "")

if [ -z "$DEPLOYMENT_BUCKETS" ]; then
    echo "⚠️  No se encontraron buckets S3 en el stack"
else
    echo "📦 Buckets encontrados:"
    for BUCKET in $DEPLOYMENT_BUCKETS; do
        echo "   • $BUCKET"
    done
fi

echo ""
echo "🗑️  Paso 2: Vaciando buckets S3..."
echo "-------------------------------------------"

for BUCKET in $DEPLOYMENT_BUCKETS; do
    if [ -n "$BUCKET" ]; then
        echo "🧹 Vaciando: $BUCKET"

        # Count objects
        OBJECT_COUNT=$(aws s3 ls s3://$BUCKET --recursive 2>/dev/null | wc -l || echo "0")

        if [ "$OBJECT_COUNT" -gt 0 ]; then
            echo "   Eliminando $OBJECT_COUNT objetos..."
            aws s3 rm s3://$BUCKET/ --recursive
            echo "   ✅ Bucket vaciado"
        else
            echo "   ℹ️  Bucket ya está vacío"
        fi
    fi
done

echo ""
echo "🔄 Paso 3: Reintentando eliminación del stack..."
echo "-------------------------------------------"

# Continue the deletion
aws cloudformation delete-stack --stack-name "$STACK_NAME"

echo "⏳ Esperando a que el stack se elimine..."
echo "   (Esto puede tardar 2-3 minutos)"
echo ""

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" 2>/dev/null && DELETE_SUCCESS=true || DELETE_SUCCESS=false

echo ""

if [ "$DELETE_SUCCESS" = "true" ]; then
    echo "=========================================="
    echo "  ✅ ¡RECUPERACIÓN EXITOSA!"
    echo "=========================================="
    echo ""
    echo "💰 El stack fue eliminado correctamente."
    echo "   No se generarán más cargos."
    echo ""
else
    echo "=========================================="
    echo "  ❌ Error en la Eliminación"
    echo "=========================================="
    echo ""
    echo "⚠️  El stack todavía no pudo ser eliminado."
    echo ""
    echo "📝 Acciones sugeridas:"
    echo "   1. Revisa la consola de CloudFormation en AWS"
    echo "   2. Verifica que todos los buckets estén vacíos"
    echo "   3. Intenta eliminar manualmente desde la consola"
    echo ""
    echo "🔗 Consola de CloudFormation:"
    AWS_REGION=$(aws configure get region || echo "us-east-1")
    echo "   https://console.aws.amazon.com/cloudformation/home?region=$AWS_REGION"
    echo ""
fi
