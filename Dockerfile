# ─────────────────────────────────────────────
# STAGE 1 — Build
# Usamos la imagen oficial de Maven con JDK 17
# para compilar y empaquetar el proyecto.
# ─────────────────────────────────────────────
FROM maven:3.9.6-eclipse-temurin-17 AS builder

WORKDIR /build

# Copiamos sólo el pom.xml primero para aprovechar la caché
# de capas de Docker: si las dependencias no cambian,
# esta capa no se reconstruye.
COPY Springboot-API-REST/pom.xml .
RUN mvn dependency:go-offline -q

# Copiamos el resto del código fuente
COPY Springboot-API-REST/src ./src

# Compilamos y empaquetamos, saltando tests
# (los tests se corren en CI, no en la imagen de producción)
RUN mvn package -DskipTests -q

# ─────────────────────────────────────────────
# STAGE 2 — Runtime
# Imagen mínima JRE 17 (sin Maven ni compilador)
# reduce la superficie de ataque y el tamaño final.
# ─────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine

# Mínimo privilegio: creamos un usuario sin privilegios
# para ejecutar la aplicación (nunca como root).
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiamos SOLO el JAR compilado desde el stage anterior
COPY --from=builder /build/target/*.jar app.jar

# Cambiamos al usuario sin privilegios
USER appuser

# Exponemos el puerto por defecto de Spring Boot (8080)
EXPOSE 8080

# Variables de entorno con valores por defecto (se sobreescriben en compose/EC2)
ENV DB_ENDPOINT=localhost \
    DB_PORT=3306 \
    DB_NAME=ventas_db \
    DB_USERNAME=root \
    DB_PASSWORD=changeme

# Punto de entrada: ejecutamos el JAR
ENTRYPOINT ["java", "-jar", "app.jar"]
