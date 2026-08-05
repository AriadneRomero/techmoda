# Plantillas de Prompts: Configuración del Entorno

Estos prompts le ayudan a instalar y configurar las herramientas necesarias para desplegar su API serverless de TechModa.

## Prompt 1.1: Instalación de AWS CLI (macOS)

```
I need to install AWS CLI v2 on macOS to deploy serverless applications.

Requirements:
- Latest AWS CLI v2
- Installation via official installer (not Homebrew)
- Verification steps to confirm installation

Please provide:
1. Download command or URL for official AWS CLI v2 installer for macOS
2. Installation steps
3. Verification command to check version
4. Basic configuration command for AWS credentials
```

## Prompt 1.2: Instalación de AWS CLI (Windows)

```
I need to install AWS CLI v2 on Windows 10/11 to deploy serverless applications.

Requirements:
- Latest AWS CLI v2
- Installation via MSI installer
- Verification steps

Please provide:
1. Download URL for AWS CLI v2 Windows installer
2. Installation steps
3. Verification command in PowerShell/CMD
4. Configuration command for AWS credentials
```

## Prompt 1.3: Instalación de AWS CLI (Linux)

```
I need to install AWS CLI v2 on Linux to deploy serverless applications.

My Linux distribution: [Ubuntu/Debian/Amazon Linux/etc]

Requirements:
- Latest AWS CLI v2
- Installation via official method
- Verification steps

Please provide:
1. Commands to download and install AWS CLI v2 on my distribution
2. Installation steps
3. Verification command to check version
4. Configuration command for AWS credentials
```

## Prompt 1.4: Instalación de AWS SAM CLI

```
I have AWS CLI v2 installed and need to install AWS SAM CLI to deploy serverless applications.

Environment: [macOS/Windows/Linux]

Requirements:
- Latest SAM CLI version
- Integration with existing AWS CLI credentials
- Verification of installation

Please provide:
1. Installation command for my OS
2. Verification command (sam --version)
3. Quick test command to validate SAM is working
```

## Prompt 1.5: Configurar Credenciales de AWS

```
I need to configure AWS credentials for the AAD Bootcamp to deploy serverless applications in us-east-1.

I have:
- AWS Access Key ID
- AWS Secret Access Key

Please provide:
1. Command to configure AWS credentials (aws configure)
2. Prompts I'll see and what to enter
3. How to verify credentials are working (aws sts get-caller-identity)
4. Recommended default region (us-east-1) and output format (json)
```

## Resultados Esperados

Después de completar la configuración del entorno:

✅ AWS CLI v2 instalado y accesible mediante `aws --version`
✅ SAM CLI instalado y accesible mediante `sam --version`
✅ Credenciales de AWS configuradas en `~/.aws/credentials`
✅ Región predeterminada configurada en `us-east-1`
✅ Puede ejecutar exitosamente `aws sts get-caller-identity` para verificar las credenciales

## Prompts de Solución de Problemas

### Si AWS CLI No Se Encuentra

```
I installed AWS CLI but the command 'aws' is not found in my terminal.

My operating system: [macOS/Windows/Linux]

Installation method I used: [describe]

Error message: [paste error]

Please help me:
1. Check if AWS CLI is actually installed
2. Add AWS CLI to my PATH
3. Verify the installation worked
```

### Si SAM CLI No Se Encuentra

```
I installed SAM CLI but the command 'sam' is not found in my terminal.

My operating system: [macOS/Windows/Linux]

Installation method I used: [describe]

AWS CLI version: [output of aws --version]

Please help me:
1. Check if SAM CLI is installed correctly
2. Add SAM CLI to my PATH
3. Verify SAM CLI can find AWS credentials
```

### Si las Credenciales son Inválidas

```
I configured AWS credentials but I'm getting authentication errors.

Error message:
[paste error from aws sts get-caller-identity or sam deploy]

Please help me:
1. Verify my credentials file format is correct
2. Check if my Access Key ID and Secret Access Key are valid
3. Confirm I'm using the right AWS profile
4. Test connectivity to AWS
```

## Próximos Pasos

Una vez completada la configuración del entorno, proceda a:
- [Prompts de Implementación de Lambda](02_LAMBDA_IMPLEMENTATION.md)
- [Especificaciones de Funciones](../specs/)
