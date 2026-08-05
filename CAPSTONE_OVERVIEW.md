# TechModa Serverless Capstone - Descripción General

## Descripción del Proyecto

El TechModa Serverless Capstone es un proyecto práctico donde construirás una API REST lista para producción para un catálogo de productos de e-commerce de moda utilizando tecnologías serverless de AWS. Este proyecto sirve como la culminación de tu bootcamp de Arquitectura Serverless de AWS, demostrando tu capacidad para diseñar, implementar, desplegar y operar aplicaciones serverless.

### Contexto de Negocio

**TechModa** es una plataforma de e-commerce de moda que necesita un sistema de gestión de catálogo de productos escalable y rentable. Tu tarea es construir una API REST serverless que permita:

- Listar todos los productos de moda en el catálogo
- Agregar nuevos productos (vestidos, chaquetas, accesorios, etc.)
- Recuperar detalles de productos individuales
- Actualizar información de productos (precios, descripciones, inventario)
- Eliminar productos descontinuados

Esta arquitectura debe ser:
- **Escalable**: Manejar tráfico variable sin intervención manual
- **Rentable**: Pagar solo por el uso real (sin costos de servidores inactivos)
- **Confiable**: Construida sobre servicios administrados de AWS con alta disponibilidad
- **Observable**: Proporcionar registro y rastreo para solución de problemas

## Objetivos de Aprendizaje

Al completar este proyecto capstone, demostrarás dominio de:

1. **Diseño de Arquitectura Serverless**
   - Diseñar sistemas orientados a eventos usando Lambda, API Gateway y DynamoDB
   - Entender cuándo usar arquitecturas serverless vs. tradicionales
   - Aplicar los principios del AWS Well-Architected Framework

2. **Implementación de API RESTful**
   - Implementar métodos HTTP apropiados (GET, POST, PUT, DELETE)
   - Devolver códigos de estado apropiados (200, 201, 404, 500)
   - Estructurar cargas JSON de solicitud/respuesta
   - Manejar CORS para compatibilidad con clientes web

3. **Infraestructura como Código (IaC)**
   - Escribir plantillas de AWS SAM para aplicaciones serverless
   - Definir recursos de forma declarativa (Lambda, API Gateway, DynamoDB)
   - Gestionar roles y permisos IAM con principio de mínimo privilegio
   - Versionar la infraestructura junto con el código de la aplicación

4. **Pruebas Manuales de API**
   - Probar endpoints usando comandos curl
   - Interpretar respuestas HTTP y solucionar fallos
   - Verificar que las operaciones CRUD funcionen correctamente
   - Validar escenarios de manejo de errores

5. **Depuración de Aplicaciones Serverless**
   - Analizar CloudWatch Logs para errores de ejecución de Lambda
   - Interpretar rastros de X-Ray para obtener información sobre el rendimiento
   - Diagnosticar problemas de permisos (roles IAM, acceso a DynamoDB)
   - Solucionar problemas de configuración de API Gateway

6. **Gestión de Costos de AWS**
   - Estimar costos para cargas de trabajo serverless
   - Entender los límites de AWS Free Tier
   - Usar facturación PAY_PER_REQUEST para DynamoDB
   - Limpiar recursos para evitar cargos innecesarios

7. **Desarrollo Acelerado por IA**
   - Usar Claude Code para generar implementaciones de funciones Lambda
   - Escribir prompts efectivos para generación de código
   - Depurar con asistencia de IA
   - Acelerar el desarrollo manteniendo la calidad del código

8. **Documentación Técnica**
   - Crear diagramas de arquitectura
   - Escribir instrucciones claras de despliegue
   - Documentar endpoints de API con ejemplos
   - Producir repositorios de GitHub con calidad de portafolio

9. **Mejores Prácticas de AWS**
   - Seguir mejores prácticas de seguridad (IAM mínimo privilegio)
   - Habilitar observabilidad (CloudWatch Logs, rastreo X-Ray)
   - Usar servicios administrados para reducir sobrecarga operacional
   - Diseñar para optimización de costos

## Stack Tecnológico

### Servicios de AWS

| Servicio | Propósito | Configuración |
|---------|---------|---------------|
| **AWS Lambda** | Capa de cómputo para lógica de negocio | Runtime Node.js 18.x, 1024 MB memoria, 30s timeout |
| **API Gateway** | Frontend de API REST | Endpoint regional, CORS habilitado, stage Prod |
| **DynamoDB** | Base de datos NoSQL | Facturación PAY_PER_REQUEST, diseño de tabla única |
| **CloudWatch** | Registro centralizado | Grupos de logs automáticos para cada función Lambda |
| **X-Ray** | Rastreo distribuido | Habilitado para API Gateway y todas las funciones Lambda |
| **IAM** | Seguridad y permisos | Roles de mínimo privilegio administrados por SAM |
| **CloudFormation** | Despliegue de infraestructura | Via abstracción de AWS SAM |

### Herramientas de Desarrollo

- **AWS SAM CLI**: Construir y desplegar aplicaciones serverless
- **AWS CLI v2**: Interactuar con servicios de AWS desde línea de comandos
- **Node.js 18.x**: Runtime de Lambda y desarrollo local
- **Git**: Control de versiones para código e infraestructura
- **Claude Code**: Desarrollo y depuración asistidos por IA
- **curl**: Pruebas manuales de API

### Programación

- **Lenguaje**: JavaScript (Node.js 18.x)
- **AWS SDK**: @aws-sdk/client-dynamodb y @aws-sdk/lib-dynamodb (v3)
- **Formato de Respuesta**: JSON con encabezados HTTP apropiados
- **Manejo de Errores**: Bloques try/catch con respuestas de error elegantes

## Descripción General de Arquitectura

```
Internet
   │
   ▼
┌──────────────────────────────────────────────────────────────┐
│  API Gateway (REST API)                                       │
│  - /products (GET, POST)                                      │
│  - /products/{id} (GET, PUT, DELETE)                          │
└───────────────┬──────────────────────────────────────────────┘
                │
        ┌───────┴───────┐
        │   Lambda      │
        │  Invocaciones │
        └───────┬───────┘
                │
    ┌───────────┴───────────┐
    │                       │
┌───▼───┐  ┌───▼───┐   ┌───▼───┐  ┌───▼───┐   ┌───▼───┐
│ List  │  │Create │   │  Get  │  │Update │   │Delete │
│ Items │  │ Item  │   │ Item  │  │ Item  │   │ Item  │
└───┬───┘  └───┬───┘   └───┬───┘  └───┬───┘   └───┬───┘
    │          │           │          │           │
    └──────────┴───────────┴──────────┴───────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │   DynamoDB     │
                  │ Tabla Products │
                  └────────────────┘
```

Para documentación detallada de arquitectura, consulta [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Requisitos de Entrega

### Entregables Requeridos

Para completar este capstone, debes entregar:

1. **URL del Repositorio GitHub** que contenga:
   - Plantilla SAM completa y funcional (template.yaml)
   - Las 5 funciones Lambda completamente implementadas
   - README.md con diagrama de arquitectura e instrucciones de despliegue
   - Documentación de ejemplos de prueba curl

### El Repositorio Debe Incluir

✅ **template.yaml** - Plantilla SAM válida con todos los recursos
✅ **functions/** - Las 5 funciones Lambda con implementaciones funcionales
✅ **README.md** - Descripción general del proyecto, diagrama de arquitectura, pasos de despliegue
✅ **Ejemplos de prueba curl** - Documentados en README o guía de pruebas separada
✅ **Historial git limpio** - Mensajes de commit significativos

### Opcional (Recomendado)

- Capturas de pantalla de pruebas de API exitosas
- Diagrama de arquitectura generado con diagrams.py o draw.io
- Evidencia del uso de Claude Code (prompts utilizados, mensajes de commit)
- Cálculos de estimación de costos
- Capturas de pantalla de rastros de X-Ray

### Fecha Límite de Entrega

Consulta a tu instructor de bootcamp para la fecha límite específica. Típicamente:
- **Tiempo en clase**: Sesión 10 (2 horas)
- **Tiempo de tarea**: 2-4 horas adicionales
- **Entrega final**: Fin del período de evaluación de Sesión 10

## Rúbrica de Evaluación

Tu capstone será evaluado en tres dimensiones que totalizan **60% de tu calificación general del bootcamp**.

### Excelencia Técnica (30%)

| Criterio | Puntos | Descripción |
|-----------|--------|-------------|
| Las 5 operaciones CRUD funcionales | 10% | List, Create, Get, Update, Delete funcionan correctamente |
| Manejo apropiado de errores | 5% | Bloques try/catch, códigos de estado apropiados (404, 500) |
| Calidad y legibilidad del código | 5% | Código limpio, comentarios, formato consistente |
| Corrección de plantilla SAM | 5% | YAML válido, todos los recursos definidos, desplegable |
| Mejores prácticas de AWS | 5% | IAM mínimo privilegio, X-Ray habilitado, variables de entorno |

### Documentación (15%)

| Criterio | Puntos | Descripción |
|-----------|--------|-------------|
| Completitud del README | 5% | Descripción general, arquitectura, pasos de despliegue, ejemplos de prueba |
| Diagrama de arquitectura | 5% | Representación visual clara de componentes del sistema |
| Ejemplos de prueba | 5% | Comandos curl documentados para todos los endpoints |

### Relevancia de Negocio (15%)

| Criterio | Puntos | Descripción |
|-----------|--------|-------------|
| Resuelve problema de catálogo de moda | 7% | Implementa gestión de catálogo de productos apropiadamente |
| Elecciones tecnológicas apropiadas | 5% | Usa arquitectura serverless efectivamente |
| Conciencia de costos | 3% | Demuestra comprensión de precios de AWS, limpieza |

### Puntuación Total del Capstone: 60%

## Estrategia de Implementación

### Enfoque de Desarrollo Guiado por Especificaciones

Este capstone utiliza **desarrollo guiado por especificaciones** para minimizar la incertidumbre. Cada función Lambda tiene una especificación detallada en `docs/specs/` que incluye:

- Propósito y endpoint de API
- Esquemas de entrada/salida con ejemplos JSON
- Escenarios de error y códigos de estado
- Operaciones de DynamoDB requeridas
- Orientación de implementación paso a paso
- Comandos curl de prueba
- Sugerencias de prompts para Claude Code

**Sigue este flujo de trabajo:**

1. **Lee la especificación** - Entiende los requisitos antes de codificar
2. **Usa prompts de IA** - Aprovecha Claude Code con plantillas proporcionadas
3. **Implementa incrementalmente** - Construye una función a la vez
4. **Prueba inmediatamente** - Despliega y verifica que cada función funcione
5. **Depura con logs** - Usa CloudWatch Logs para solución de problemas

### Orden de Implementación Recomendado

1. **CreateItem** - Comienza aquí para poblar la base de datos
2. **ListItems** - Verifica que los elementos fueron creados
3. **GetItem** - Prueba recuperación de elementos individuales
4. **UpdateItem** - Modifica elementos existentes
5. **DeleteItem** - Limpia datos de prueba

## Estimación de Costos

### Costos Esperados de AWS

Este proyecto capstone debería costar **menos de $1 USD** para todo el período de desarrollo y pruebas.

| Servicio | Estimación de Costo | Notas |
|---------|---------------|-------|
| DynamoDB | $0.00 - $0.10 | PAY_PER_REQUEST, operaciones mínimas, Free Tier |
| Lambda | $0.00 - $0.20 | Primeras 1M solicitudes gratis, ~100 invocaciones |
| API Gateway | $0.00 - $0.50 | Primeras 1M solicitudes $3.50/millón, ~50 solicitudes |
| CloudWatch Logs | $0.00 - $0.10 | Ingesta mínima de logs, Free Tier |
| X-Ray | $0.00 - $0.10 | Primeros 100k rastros gratis |

**Total**: Menos de $1.00 USD

### Mitigación de Costos

- ✅ Usa AWS Free Tier (todos los estudiantes deberían mantenerse dentro de los límites)
- ✅ Minimiza las pruebas a solo verificación necesaria
- ✅ Elimina el stack inmediatamente después de la demostración
- ✅ Monitorea el Panel de Facturación de AWS durante el desarrollo

**IMPORTANTE**: Ejecuta `./scripts/delete.sh` después de entregar para evitar cargos continuos.

Para desglose detallado de costos, consulta [docs/COST_AND_CLEANUP.md](docs/COST_AND_CLEANUP.md).

## Orientación de Cronograma

### Sesión 10 (2 horas en clase)

| Tiempo | Actividad |
|------|----------|
| 0-15 min | Introducción, revisión de requisitos, clonar repositorio |
| 15-30 min | Revisar plantilla SAM, entender arquitectura |
| 30-90 min | Implementar funciones Lambda usando prompts de Claude Code |
| 90-110 min | Desplegar y probar con comandos curl |
| 110-120 min | Solución de problemas, Q&A, planificación de limpieza |

### Tarea (2-4 horas)

- Completar las implementaciones restantes de funciones Lambda
- Pulir documentación (README, diagrama de arquitectura)
- Pruebas exhaustivas de todas las operaciones CRUD
- Recopilación de evidencia de capturas de pantalla (opcional)
- Verificación final de despliegue
- Entregar URL del repositorio GitHub

## Criterios de Éxito

Tu capstone es exitoso cuando:

✅ Las 5 operaciones CRUD funcionan correctamente
✅ La API devuelve códigos de estado HTTP apropiados
✅ DynamoDB almacena y recupera productos con precisión
✅ La plantilla SAM se despliega sin errores
✅ CloudWatch Logs muestra ejecuciones de funciones
✅ Los rastros de X-Ray muestran flujos de solicitud
✅ El costo se mantiene bajo $1 USD
✅ El repositorio de GitHub tiene calidad de portafolio
✅ La documentación está completa y profesional

## Obtener Ayuda

### Recursos Disponibles

1. **Especificaciones de Funciones** - `docs/specs/` para requisitos detallados
2. **Plantillas de Prompts** - `docs/prompts/` para asistencia de Claude Code
3. **Guía de Pruebas** - `docs/TESTING_GUIDE.md` para ejemplos curl
4. **Guía de Depuración** - `docs/prompts/05_DEBUGGING.md` para solución de problemas
5. **Soporte del Instructor** - Haz preguntas durante la Sesión 10
6. **CloudWatch Logs** - Primer lugar para buscar errores
7. **Documentación de AWS** - Guías oficiales para Lambda, DynamoDB, API Gateway

### Desafíos Comunes

| Desafío | Solución |
|-----------|----------|
| Errores de función Lambda | Verifica CloudWatch Logs para trazas de pila |
| Permiso denegado de DynamoDB | Verifica políticas IAM de plantilla SAM |
| Errores 404 de API Gateway | Confirma que las rutas de endpoint coinciden con la plantilla |
| Fallos de despliegue | Revisa eventos de CloudFormation en consola |
| Errores de timeout | Aumenta el timeout de Lambda u optimiza el código |

## Valor para el Portafolio

Este capstone proporciona evidencia tangible de tu experiencia serverless:

- **Repositorio de GitHub** demostrando código con calidad de producción
- **Diagrama de arquitectura** mostrando habilidades de diseño de sistemas
- **API REST funcional** con operaciones CRUD completas
- **Documentación** destacando habilidades de comunicación
- **Experiencia con AWS** valorada por empleadores en el mercado tecnológico de Colombia

Agrega este proyecto a tu:
- Perfil de LinkedIn (sección de proyectos)
- Currículum (proyectos o habilidades técnicas)
- Sitio web de portafolio (estudio de caso)
- Entrevistas de trabajo (discusión técnica)

---

## Próximos Pasos

1. Lee este documento completo cuidadosamente
2. Revisa la guía de inicio rápido [README.md](README.md)
3. Estudia las especificaciones de funciones en `docs/specs/`
4. Comienza a implementar con `docs/prompts/02_LAMBDA_IMPLEMENTATION.md`
5. Prueba frecuentemente usando `docs/TESTING_GUIDE.md`
6. Entrega tu URL de repositorio GitHub cuando esté completo

**¡Buena suerte construyendo tu API serverless de TechModa!** 🚀
