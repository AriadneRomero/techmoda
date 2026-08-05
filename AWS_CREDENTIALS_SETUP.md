# Configuración de Credenciales AWS para GitHub Codespaces

Esta guía explica cómo configurar las credenciales de AWS para el proyecto TechModa Serverless Capstone al utilizar GitHub Codespaces.

## Prerrequisitos

Antes de comenzar, necesita:
- AWS Access Key ID
- AWS Secret Access Key
- AWS Region (por ejemplo, `us-east-1`)

Si no tiene estas credenciales, solicítelas a su instructor del bootcamp o administrador de la cuenta de AWS.

---

## Método 1: Configurar Secrets del Repositorio (Recomendado)

### Paso 1: Navegar a la Configuración del Repositorio

1. Vaya a su repositorio en GitHub: `https://github.com/YOUR_USERNAME/techmoda-serverless-capstone-starter`
2. Haga clic en la pestaña **Settings** (requiere acceso de administrador del repositorio)
3. En la barra lateral izquierda, expanda **Secrets and variables**
4. Haga clic en **Codespaces**

### Paso 2: Agregar Credenciales de AWS como Secrets

Agregue los siguientes tres secrets:

#### Secret 1: AWS_ACCESS_KEY_ID

1. Haga clic en **New repository secret**
2. **Name**: `AWS_ACCESS_KEY_ID`
3. **Value**: Su AWS Access Key ID (por ejemplo, `AKIAIOSFODNN7EXAMPLE`)
4. Haga clic en **Add secret**

#### Secret 2: AWS_SECRET_ACCESS_KEY

1. Haga clic en **New repository secret**
2. **Name**: `AWS_SECRET_ACCESS_KEY`
3. **Value**: Su AWS Secret Access Key (por ejemplo, `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
4. Haga clic en **Add secret**

#### Secret 3: AWS_DEFAULT_REGION

1. Haga clic en **New repository secret**
2. **Name**: `AWS_DEFAULT_REGION`
3. **Value**: Su región preferida de AWS (por ejemplo, `us-east-1`)
4. Haga clic en **Add secret**

### Paso 3: Aplicar Cambios a su Codespace

**IMPORTANTE**: Después de agregar o modificar secrets, debe reiniciar su Codespace:

1. **Si el Codespace está ejecutándose**:
   - Haga clic en el nombre del Codespace en la parte inferior izquierda de VS Code
   - Seleccione **Stop Current Codespace**
   - Espere a que se detenga completamente
   - Vuelva a abrir el Codespace desde GitHub

2. **Si está creando un nuevo Codespace**:
   - Los secrets estarán disponibles automáticamente

**Nota**: Simplemente recargar la ventana NO es suficiente. Debe detener y reiniciar completamente el Codespace para que los nuevos secrets se carguen.

### Paso 4: Verificar la Configuración de Secrets

Después de reiniciar su Codespace, verifique que los secrets se hayan cargado:

```bash
# Verificar si las variables de entorno están configuradas
echo $AWS_ACCESS_KEY_ID
echo $AWS_DEFAULT_REGION

# Verificar que las credenciales de AWS funcionen
aws sts get-caller-identity
```

**Salida esperada:**

```json
{
    "UserId": "AIDAI...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

Si ve un error como "Unable to locate credentials", los secrets no se cargaron. Asegúrese de haber **detenido y reiniciado** el Codespace (no solo recargado).

---

## Método 2: Configuración Manual con AWS CLI (Alternativo)

Si prefiere no usar secrets de GitHub o necesita credenciales temporales:

### Paso 1: Abrir Terminal de Codespace

```bash
aws configure
```

### Paso 2: Ingresar Credenciales

```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

### Paso 3: Verificar Configuración

```bash
aws sts get-caller-identity
```

**Nota**: Las credenciales configuradas manualmente se almacenan en `~/.aws/credentials`. Estas persistirán mientras su Codespace exista, pero se perderán si el Codespace se elimina o reconstruye.

---

## Probar Acceso a AWS

Después de configurar las credenciales con cualquiera de los métodos, pruebe su acceso a AWS:

```bash
# Verificar identidad
aws sts get-caller-identity

# Probar acceso a DynamoDB
aws dynamodb list-tables

# Verificar región actual
aws configure get region

# Listar buckets de S3 (si tiene permiso)
aws s3 ls
```

Si todos los comandos funcionan sin errores, sus credenciales de AWS están configuradas correctamente.

---

## Mejores Prácticas de Seguridad

### ✅ SÍ HACER

- **Usar credenciales de usuario IAM** con permisos limitados (no cuenta root)
- **Rotar las claves de acceso regularmente** (se recomienda cada 90 días)
- **Eliminar secrets** después del bootcamp si usa credenciales temporales
- **Mantener las credenciales privadas** - nunca las comparta con nadie
- **Usar secrets del repositorio** para proyectos del bootcamp
- **Eliminar su stack de CloudFormation** después de las pruebas para evitar cargos

### ❌ NO HACER

- **Nunca hacer commit de credenciales de AWS en Git** (ya está protegido por .gitignore)
- **Nunca compartir sus claves de acceso** con otros estudiantes
- **Nunca usar credenciales de cuenta root** para desarrollo
- **Nunca publicar credenciales** en Slack, Discord o foros públicos
- **Nunca dejar credenciales** en comentarios de código o documentación
- **Nunca hacer captura de pantalla** ni compartir su AWS_SECRET_ACCESS_KEY

### Permisos IAM Recomendados

Su usuario de AWS debe tener los siguientes permisos para este capstone:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "lambda:*",
        "apigateway:*",
        "dynamodb:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRole",
        "iam:PassRole",
        "logs:*",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Nota**: Su instructor del bootcamp puede haber configurado ya los permisos apropiados. Contáctelo si encuentra errores de permisos.

---

## Problemas Comunes

### Problema: "Unable to locate credentials"

**Solución**: No reinició su Codespace después de agregar los secrets
1. Detenga su Codespace completamente
2. Vuelva a abrirlo desde GitHub
3. Verifique con `aws sts get-caller-identity`

### Problema: "An error occurred (UnauthorizedOperation)"

**Solución**: Permisos IAM insuficientes
- Contacte a su instructor del bootcamp
- Verifique que está usando la cuenta de AWS correcta

### Problema: Los secrets no funcionan después del reinicio

**Solución**: Verifique los nombres de los secrets (sensibles a mayúsculas)
- Deben ser exactamente: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
- Elimine y vuelva a crear si es necesario

---

## Siguientes Pasos

Una vez que las credenciales estén configuradas y verificadas:

1. ✅ Pruebe con `aws sts get-caller-identity`
2. ✅ Revise el [README.md](README.md) para la guía de implementación
3. ✅ Comience a implementar las funciones Lambda
4. ✅ Despliegue con `./scripts/deploy.sh`
5. ✅ Pruebe su API con comandos curl

**Recuerde**: Elimine su stack de CloudFormation después de completar el capstone para evitar cargos de AWS:

```bash
./scripts/delete.sh
```
