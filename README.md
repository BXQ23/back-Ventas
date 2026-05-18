# Back Ventas — Springboot API REST

Microservicio de gestión de **ventas** para Innovatech Chile.  
Spring Boot 3.4.4 · Java 17 · MySQL 8 · Docker · GitHub Actions CI/CD

---

## Tabla de contenidos

1. [Descripción del servicio](#descripción-del-servicio)
2. [Requisitos previos](#requisitos-previos)
3. [Variables de entorno](#variables-de-entorno)
4. [Ejecutar con Docker Compose](#ejecutar-con-docker-compose)
5. [Endpoints disponibles](#endpoints-disponibles)
6. [Dockerfile (multi-stage)](#dockerfile-multi-stage)
7. [Pipeline CI/CD](#pipeline-cicd)
8. [Secrets de GitHub Actions](#secrets-de-github-actions)
9. [Persistencia de datos](#persistencia-de-datos)

---

## Descripción del servicio

Expone una API REST para crear, listar, actualizar y eliminar **ventas**.  
Se conecta a una base de datos MySQL cuya URL, nombre y credenciales se inyectan mediante variables de entorno (no hay credenciales en el código).

**Puerto:** `8080`  
**Base path:** `/api/v1/ventas`  
**Swagger UI:** `http://<HOST>:8080/swagger-ui.html`

---

## Requisitos previos

| Herramienta | Versión mínima |
|---|---|
| Docker | 24.x |
| Docker Compose | 2.x (`docker compose`) |
| Git | 2.x |

---

## Variables de entorno

| Variable | Descripción | Ejemplo |
|---|---|---|
| `DB_ENDPOINT` | Hostname del servidor MySQL | `mysql` (nombre del servicio en compose) |
| `DB_PORT` | Puerto MySQL | `3306` |
| `DB_NAME` | Nombre de la base de datos | `ventas_db` |
| `DB_USERNAME` | Usuario MySQL | `root` |
| `DB_PASSWORD` | Contraseña MySQL | `*****` |
| `MYSQL_ROOT_PASSWORD` | Contraseña root para el contenedor MySQL | `*****` |
| `DOCKERHUB_USERNAME` | Tu usuario de Docker Hub | `miusuario` |

Copia `.env.example` a `.env` y rellena los valores:

```bash
cp .env.example .env
# editar .env con tus valores reales
```

> ⚠️ **Nunca commitees el archivo `.env`** con credenciales reales. Está en `.gitignore`.

---

## Ejecutar con Docker Compose

```bash
# 1. Clonar el repositorio
git clone https://github.com/TU_USUARIO/back-ventas.git
cd back-ventas

# 2. Configurar variables de entorno
cp .env.example .env
# Editar .env con los valores reales

# 3. Levantar el stack completo (MySQL + back-ventas + back-despachos)
docker compose up -d

# 4. Ver logs
docker compose logs -f back-ventas

# 5. Verificar que el servicio responde
curl http://localhost:8080/api/v1/ventas

# 6. Detener
docker compose down
```

Para reiniciar solo el servicio de ventas sin afectar la base de datos:

```bash
docker compose up -d --no-deps back-ventas
```

---

## Endpoints disponibles

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/api/v1/ventas` | Listar todas las ventas |
| `GET` | `/api/v1/ventas/{id}` | Obtener venta por ID |
| `POST` | `/api/v1/ventas` | Crear nueva venta |
| `PUT` | `/api/v1/ventas/{id}` | Actualizar venta |
| `DELETE` | `/api/v1/ventas/{id}` | Eliminar venta |

Documentación interactiva completa en: `http://<HOST>:8080/swagger-ui.html`

---

## Dockerfile (multi-stage)

El `Dockerfile` usa **dos stages** para optimizar la imagen final:

```
Stage 1 (builder)  →  maven:3.9.6-eclipse-temurin-17
  - Instala dependencias Maven
  - Compila y empaqueta el JAR

Stage 2 (runtime)  →  eclipse-temurin:17-jre-alpine (~85 MB)
  - Solo contiene el JRE (sin Maven ni compilador)
  - Corre con usuario sin privilegios (appuser)
  - Superficie de ataque mínima
```

**Buenas prácticas aplicadas:**
- `maven dependency:go-offline` antes de copiar el código → caché de capas eficiente
- `-DskipTests` en el build de producción (los tests corren en CI)
- Usuario no root (`appuser`) → principio de mínimo privilegio
- Imagen base Alpine → imagen final ~120 MB vs ~500 MB con imagen completa

---

## Pipeline CI/CD

El archivo `.github/workflows/ci-cd.yml` define el pipeline:

```
Push a rama deploy
        │
        ▼
┌─────────────────────┐
│  JOB 1: build-push  │
│  1. Checkout código │
│  2. Login DockerHub │
│  3. docker buildx   │
│  4. Push :latest    │
│     y :sha-XXXXXX   │
└──────────┬──────────┘
           │ (si exitoso)
           ▼
┌─────────────────────┐
│  JOB 2: deploy      │
│  1. SSH → EC2       │
│  2. docker pull     │
│  3. compose up -d   │
│  4. image prune     │
└─────────────────────┘
```

**Trigger:** Solo se activa con `git push origin deploy`

---

## Secrets de GitHub Actions

Configurar en **Settings → Secrets and variables → Actions** del repositorio:

| Secret | Descripción |
|---|---|
| `DOCKERHUB_USERNAME` | Usuario de Docker Hub |
| `DOCKERHUB_TOKEN` | Token de acceso Docker Hub (no la contraseña) |
| `EC2_BACKEND_HOST` | IP pública del EC2 backend |
| `EC2_USERNAME` | Usuario SSH del EC2 (ej: `ec2-user` o `ubuntu`) |
| `EC2_SSH_KEY` | Contenido completo de la clave privada `.pem` |

---

## Persistencia de datos

La base de datos MySQL usa un **named volume** (`mysql_data`):

```yaml
volumes:
  mysql_data:
    driver: local
```

**¿Por qué named volume y no bind mount?**

| Criterio | Named volume ✅ | Bind mount ❌ |
|---|---|---|
| Portabilidad | Gestionado por Docker, no depende del path del host | Requiere que el path exista en el host |
| Seguridad | Docker gestiona permisos | Puede exponer directorios del host |
| Backup | `docker run --rm -v mysql_data:/data ...` | Depende del path del host |
| EC2 | Funciona en cualquier instancia sin configuración extra | Requiere crear el directorio manualmente |

Los datos persisten aunque se ejecute `docker compose down`. Solo se eliminan con `docker compose down -v`.

---

## Estructura del repositorio

```
back-ventas/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # Pipeline CI/CD
├── Springboot-API-REST/
│   ├── src/                   # Código fuente Java
│   ├── pom.xml                # Dependencias Maven
│   └── ...
├── Dockerfile                 # Multi-stage build
├── docker-compose.yml         # Stack completo (MySQL + backends)
├── .env.example               # Plantilla de variables de entorno
├── .gitignore
└── README.md
```
