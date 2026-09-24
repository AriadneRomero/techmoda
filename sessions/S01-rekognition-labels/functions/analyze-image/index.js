/**
 * REKOGNITION ANALYZER LAMBDA (S01)
 *
 * Qué hace:
 *   Recibe una URL de imagen (de un producto) y detecta objetos/etiquetas
 *   usando AWS Rekognition. Guarda los resultados en DynamoDB.
 *
 * Endpoint: POST /analyze-image (su propia Function URL)
 *
 * Entrada esperada:
 *   {
 *     "productId": "550e8400-...",
 *     "imageUrl": "https://ejemplo.com/imagen.jpg"
 *   }
 *
 * Salida:
 *   {
 *     "productId": "550e8400-...",
 *     "labels": [
 *       { "name": "Clothing", "confidence": 99.5 },
 *       { "name": "Shirt", "confidence": 97.2 },
 *       { "name": "Blue", "confidence": 85.3 }
 *     ],
 *     "imageUrl": "https://..."
 *   }
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { RekognitionClient, DetectLabelsCommand } = require('@aws-sdk/client-rekognition');
const { Decimal } = require('@aws-sdk/util-dynamodb');

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

function success(statusCode, payload) {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify(payload),
  };
}

function error(statusCode, message) {
  return success(statusCode, { error: message });
}

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event));

  try {
    // ===================================================================
    // 1. PARSEAR el body
    // ===================================================================
    let body;
    if (typeof event.body === 'string') {
      body = JSON.parse(event.body);
    } else {
      body = event.body || {};
    }

    // ===================================================================
    // 2. VALIDAR entrada
    // ===================================================================
    if (!body.productId) {
      return error(400, 'productId es obligatorio');
    }

    if (!body.imageUrl) {
      return error(400, 'imageUrl es obligatoria');
    }

    if (typeof body.imageUrl !== 'string' || !body.imageUrl.startsWith('http')) {
      return error(400, 'imageUrl debe ser una URL válida (http/https)');
    }

    const { productId, imageUrl } = body;

    // ===================================================================
    // 3. CONECTAR a DynamoDB (para verificar que el producto existe)
    // ===================================================================
    const ddbClient = new DynamoDBClient({ region: 'us-east-1' });
    const docClient = DynamoDBDocumentClient.from(ddbClient);

    const getCmd = new GetCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId },
    });

    const existingProduct = await docClient.send(getCmd);

    if (!existingProduct.Item) {
      return error(404, `Producto ${productId} no existe`);
    }

    // ===================================================================
    // 4. LLAMAR A REKOGNITION: DetectLabels
    // ===================================================================
    console.log(`Analizando imagen de ${productId}: ${imageUrl}`);

    const rekognitionClient = new RekognitionClient({ region: 'us-east-1' });

    const detectCmd = new DetectLabelsCommand({
      Image: {
        Url: imageUrl,  // Rekognition descarga la imagen desde esta URL
      },
      MaxLabels: 10,  // Máximo 10 etiquetas
      MinConfidence: 50,  // Mínimo 50% de confianza
    });

    const rekognitionResult = await rekognitionClient.send(detectCmd);

    console.log('Rekognition result:', JSON.stringify(rekognitionResult));

    // ===================================================================
    // 5. PROCESAR resultados de Rekognition
    // ===================================================================
    const labels = (rekognitionResult.Labels || []).map((label) => ({
      name: label.Name,
      confidence: label.Confidence,
    }));

    console.log(`Detectadas ${labels.length} etiquetas`);

    // ===================================================================
    // 6. GUARDAR resultados en DynamoDB (actualizar el producto)
    // ===================================================================
    const now = new Date().toISOString();

    const updateCmd = new UpdateCommand({
      TableName: process.env.PRODUCTS_TABLE,
      Key: { productId },
      UpdateExpression: 'SET rekognitionLabels = :labels, analyzedAt = :now, imageAnalyzed = :true',
      ExpressionAttributeValues: {
        ':labels': labels,
        ':now': now,
        ':true': true,
      },
      ReturnValues: 'ALL_NEW',
    });

    const updateResult = await docClient.send(updateCmd);

    // ===================================================================
    // 7. RETORNAR resultado exitoso
    // ===================================================================
    return success(200, {
      productId,
      imageUrl,
      labels,
      totalLabelsDetected: labels.length,
      analyzedAt: now,
      product: updateResult.Attributes,
    });

  } catch (err) {
    console.error('Error:', err);

    // Manejo de errores específicos
    if (err.name === 'InvalidParameterException') {
      return error(400, `Imagen inválida o URL no accesible: ${err.message}`);
    }

    if (err.name === 'InvalidImageFormatException') {
      return error(400, 'La imagen no está en un formato válido (JPG, PNG)');
    }

    if (err.name === 'ImageTooLargeException') {
      return error(400, 'La imagen es muy grande (máximo 15MB)');
    }

    if (err.name === 'AccessDeniedException') {
      return error(403, 'Permiso denegado para acceder a Rekognition o DynamoDB');
    }

    return error(500, `Error interno: ${err.message}`);
  }
};
