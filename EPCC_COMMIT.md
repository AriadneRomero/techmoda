# Commit: hacer seguible el capstone tras el refactor de IAM

**Rama**: `feat/migrate-region-us-east-1` · **Estado**: commiteado + PR abierto

---

## 1. Qué pasó

El repo tenía un refactor grande **sin commitear**: LabRole → `Policies:` de mínimo privilegio por
función, contrato de datos a camelCase, `docs/IAM.md`, `scripts/validate-all.sh`, devcontainer. Ese
refactor cambió la **premisa** del proyecto (ahora requiere una cuenta con `iam:CreateRole`; ya no hay
"Pista B" bloqueada) pero dejó toda la **prosa** describiendo el mundo anterior.

Consecuencia concreta, verificada archivo por archivo: **un estudiante no podía seguir los pasos.**

| # | Qué encontraba el estudiante | Dónde |
|---|---|---|
| P0-1 | "Pegá el recurso, **incluye `Role: !Ref LabRoleArn`**" — línea que ya no existe en el snippet | 8 `GUIA.md` |
| P0-2 | Prerequisito "cuenta sandbox re/Start, autenticado como `LabRole`" → ese deploy **falla** (`iam:CreateRole` denegado) y revierte el stack | `S00-base/GUIA.md` |
| P0-3 | Dos model IDs de Bedrock, **los dos rotos**: `anthropic.claude-haiku-4-5` (alias de la Claude API, que `bedrock-runtime` rechaza) y `anthropic.claude-3-haiku-20240307-v1:0` (retirado el 2026-04-19) | `template.full.yaml`, snippets S06/S08, 2 `app.py` |
| P1-4 | El doc citado como autoridad desde 40 archivos afirmaba lo contrario de `docs/IAM.md` | `docs/SANDBOX-COMPAT.md` |
| P1-5 | 5 guías abrían con "**NO corre en el sandbox**" mientras `CLAUDE.md` decía "las 12 corren" | `sessions/README.md`, `SESSION-PLAN.md`, 5 `GUIA.md` |
| P1-6 | `deploy-all.sh` **imprimía** "Function URLs + LabRole"; `samconfig.*.example` ofrecía un `LabRoleArn=` que ya no es parámetro de ningún template; `enable-bedrock-logging.sh` tenía un **default funcional** apuntando al LabRole | scripts y config |
| P1-7 | `CLAUDE.md` se contradecía: §Arquitectura decía "SAM crea los roles", §Despliegue decía "`CAPABILITY_IAM` … aunque no se creen roles" | `CLAUDE.md` |
| P2-8 | `validate-all.sh` daba **verde** con ~130 menciones de `LabRole` vivas en 39 archivos | `scripts/validate-all.sh` |

**Por qué los gates no lo detectaron**: el linter validaba lo que el refactor **tocó**, no lo que el
refactor **invalidó**. Todo lo roto estaba en prosa, y la prosa no tenía check.

---

## 2. Qué se arregló

**Model IDs (P0-3)** — unificados en `anthropic.claude-haiku-4-5-20251001-v1:0` en los 5 lugares que
tienen que coincidir. Verificado contra la doc oficial de modelos: estas Lambdas usan la integración
**legacy** de Bedrock (`boto3` `bedrock-runtime`, `converse()`/`invoke_model()`), que exige el ID
**versionado**; el alias de la Claude API no sirve ahí. Opus 5 / Sonnet 5 tampoco: en Bedrock se sirven
por el endpoint Messages-API, no por `bedrock-runtime`.

**`docs/SANDBOX-COMPAT.md` reescrito (P1-4)** — se **mantuvo el path** a propósito: con 40 referentes,
borrarlo rompía más de lo que arreglaba. Ahora conserva lo que sigue siendo cierto (por qué no hay API
Gateway, el router, el patrón de recurso, el gotcha de `Decimal`), delega los permisos a `docs/IAM.md`,
y guarda la matriz IAM empírica del sandbox como **§3 Nota histórica** — es material didáctico honesto:
explica de dónde vino el diseño.

**Prerequisito explícito (P0-2)** — `S00-base/GUIA.md`, `README.md`, `QUICKSTART.md` y `CLAUDE.md`
ahora piden una cuenta con `iam:CreateRole`, **con el síntoma exacto** si no lo tiene
(`is not authorized to perform: iam:CreateRole` + rollback) y la aclaración de que es la cuenta, no el
template.

**Se retiró la estructura de dos pistas (P1-5)** — `sessions/README.md` reescrito (tabla de 12 sesiones
con "Requiere" en vez de "Pista"), `SESSION-PLAN.md` re-planificado a 6 días todos hands-on, y los 5
encabezados "NO corre en el sandbox" reemplazados por lo que de verdad hace falta: **Bedrock → Model
access**, que es un setting **por región** y es el primer sospechoso de un `AccessDeniedException`.

**`enable-bedrock-logging.sh`** — el default que apuntaba al LabRole se cambió por: detectar un rol de
entrega propio, y si no existe, **imprimir los comandos para crearlo** (con el permiso acotado al
prefijo del log group, no a `*`). Crear ese rol a mano es on-topic para S10, que es la sesión de
gobernanza.

**Las 8 guías de sesión** ahora describen lo que el snippet trae de verdad, y aprovechan el cambio para
enseñar: S07-búsqueda y S08 llevan `DynamoDBReadPolicy` **y no `Crud`** porque sólo consultan — la
diferencia entre "acotado" y "acotado de verdad".

---

## 3. El arreglo que evita la repetición (P2-8)

`validate-all.sh` §6 pasó de 3 checks a 8. Los seis nuevos, **cada uno probado inyectando la violación
y confirmando que falla**:

| Check | Detecta |
|---|---|
| `Role:` en templates | El error que anula `Policies:` **en silencio** (deploy OK, permiso ausente) |
| `Action: servicio:*` | Comodines de servicio. Ignora el `bedrock:*` de los **ARN** (comodín de región, legítimo) |
| `LabRole` en docs | Prosa que promete el modelo IAM viejo. Con allowlist para las menciones históricas |
| Model ID único | Los 5 lugares divergiendo entre sí |
| Model ID versionado | El alias de la Claude API donde hace falta el de `bedrock-runtime` |
| Scripts citados existen | Docs que mandan a correr un `scripts/*.sh` inexistente |

El check de docs es el que cierra el hueco de fondo: **la coherencia entre código y prosa ahora es un
gate**, no un acto de disciplina.

---

## 4. Validación

| Gate | Resultado |
|---|---|
| `bash scripts/validate-all.sh --static` | ✅ **30 OK / 0 fallos** (era 25 OK con 130 menciones stale sin detectar) |
| `sam validate --lint` ×3 templates | ✅ |
| Splice de los 8 snippets en `template.yaml` + lint | ✅ (reproduce el paso del estudiante) |
| `sam build -t template.sandbox.yaml` / `-t template.full.yaml` | ✅ / ✅ |
| `npm run lint` / `typecheck` / `vitest run` | ✅ · ✅ · ✅ **117 tests** |
| Los 6 checks nuevos, con la violación inyectada | ✅ los 6 fallan como deben |

⚠️ **Límite honesto de este pase: no se probó nada contra AWS.** No hay credenciales en este entorno
(`Partial credentials found in env, missing: AWS_SECRET_ACCESS_KEY`). Las secciones 7–10 de
`validate-all.sh` — CRUD E2E y las 9 features de IA — **no corrieron**.

Eso deja **una afirmación central del refactor sin verificar**: que los roles que SAM genera alcancen
en runtime. Las verificaciones de servicios de IA que registra `sessions/README.md` (2026-06-18) se
hicieron cuando las Lambdas usaban un rol compartido y amplio; con roles acotados, un permiso de menos
aparece **recién en la primera invocación**. Los candidatos más probables: `s3:GetObject` de S01/S02
cuando `imageUrl` es `s3://`, el `S3CrudPolicy` del bucket de audio en S05, y el ARN
`inference-profile/*` de Bedrock si se usa un ID con prefijo `us.`.

Está anotado como tal en `sessions/README.md` y en `EPCC_EXPLORE.md`, y el comando que lo cierra es
uno: `bash scripts/validate-all.sh` (modo completo) contra un stack desplegado.

---

## 5. Cierre

**Commits** (dos, por tema):

| Commit | Alcance |
|---|---|
| `refactor(iam)!` | Roles de mínimo privilegio por función, contrato camelCase, `stock` persistido, model IDs de Bedrock, devcontainer, `docs/IAM.md`, `scripts/validate-all.sh` |
| `docs` | Alineación de las 39 fuentes de prosa + los 6 checks nuevos del linter |

**Breaking change**: el proyecto **ya no despliega en el sandbox AWS re/Start** (el `LabRole` deniega
`iam:CreateRole`). Es el precio deliberado del mínimo privilegio, y está documentado en
`docs/SANDBOX-COMPAT.md` §2–§3 en vez de quedar como sorpresa en el primer deploy. La variante con
LabRole vive en el historial de git.

**Siguiente acción**: correr `bash scripts/validate-all.sh` (modo completo) con credenciales, contra un
stack desplegado en una cuenta con `iam:CreateRole` y Bedrock Model access habilitado.
