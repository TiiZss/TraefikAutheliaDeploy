#!/bin/bash

# ==========================================
# INSTALADOR AUTOMÁTICO DE TRAEFIK + AUTHELIA
# ==========================================


# Forzar codificación UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Robustez: Detener ante errores
set -euo pipefail

# Versiones
# Versiones
TRAEFIK_VERSION="v3"
AUTHELIA_VERSION="4.36.1"
COMPOSE_VERSION="v2.29.0"


# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para generar secretos aleatorios
generate_secret() {
    # Disable pipefail to avoid SIGPIPE error when head closes stream while tr is writing
    set +o pipefail
    LC_ALL=C tr -cd 'a-z0-9' < /dev/urandom | head -c 32
    set -o pipefail
}


# Sanitizar inputs para evitar comillas dobles (si se pasaron vía export)
if [ -n "${TRAEFIK_HOST:-}" ]; then TRAEFIK_HOST=$(echo "$TRAEFIK_HOST" | tr -d '"'"'"); fi
if [ -n "${AUTH_HOST:-}" ]; then AUTH_HOST=$(echo "$AUTH_HOST" | tr -d '"'"'"); fi
if [ -n "${ACME_EMAIL:-}" ]; then ACME_EMAIL=$(echo "$ACME_EMAIL" | tr -d '"'"'"); fi
if [ -n "${DASH_USER:-}" ]; then DASH_USER=$(echo "$DASH_USER" | tr -d '"'"'"); fi
if [ -n "${DASH_PASS:-}" ]; then DASH_PASS=$(echo "$DASH_PASS" | tr -d '"'"'"); fi
if [ -n "${INPUT_ROOT_DOMAIN:-}" ]; then INPUT_ROOT_DOMAIN=$(echo "$INPUT_ROOT_DOMAIN" | tr -d '"'"'"); fi

echo -e "${BLUE}=== Iniciando Instalador de Traefik v3 + Authelia ===${NC}"

# ==========================================
# 1. VERIFICACIONES PREVIAS Y ACTUALIZACIÓN
# ==========================================
echo -e "\n${GREEN}[Paso 1/7] Actualizando sistema y verificando requisitos...${NC}"

# Actualizar sistema operativo
echo "Actualizando índices de paquetes (apt update)..."
apt-get update -qq
echo "Actualizando paquetes instalados (apt upgrade)..."
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Verificar puertos 80/443
echo "Verificando puertos..."
if command -v netstat >/dev/null; then
    if netstat -tuln | grep -E ':80 |:443 ' >/dev/null; then
        echo -e "${YELLOW}ADVERTENCIA: Los puertos 80 o 443 parecen estar en uso.${NC}"
        echo -e "${YELLOW}Esto podría causar conflictos con Traefik.${NC}"
        read -p "¿Deseas continuar de todos modos? (s/n): " -r
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then exit 1; fi
    fi
fi


# Verificar Docker
# Verificar Docker
if ! [ -x "$(command -v docker)" ]; then
  echo -e "${YELLOW}Docker no está instalado. Instalando automáticamente...${NC}"
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm get-docker.sh
  
  # Verificar de nuevo
  if ! [ -x "$(command -v docker)" ]; then
      echo -e "${RED}Error: Falló la instalación automática de Docker.${NC}"
      exit 1
  fi
  echo -e "${GREEN}Docker instalado correctamente.${NC}"
fi

# Descargar Docker Compose V2 localmente para asegurar compatibilidad


# ==========================================
# 2. RECOPILACIÓN DE DATOS
# ==========================================
echo -e "\n${GREEN}[Paso 2/7] Configuración del Entorno${NC}"
echo -e "${YELLOW}Nota: Necesitarás dos subdominios apuntando a este servidor (ej. monitor.tuweb.com y auth.tuweb.com)${NC}"

# Bucle para validar emails y dominios vacíos
while [[ -z "$TRAEFIK_HOST" ]]; do
    read -p "Dominio para el Dashboard (ej. monitor.midominio.com): " TRAEFIK_HOST
done

while [[ -z "$AUTH_HOST" ]]; do
    read -p "Dominio para Authelia (ej. auth.midominio.com): " AUTH_HOST
done

# Extraer el dominio raíz (simple, asume estructura sub.dominio.com o sub.sub.dominio.com)
# Esto es para configurar la cookie de sesión en .dominio.com
if [[ -z "$INPUT_ROOT_DOMAIN" ]]; then
    ROOT_DOMAIN=$(echo "$TRAEFIK_HOST" | awk -F. '{print $(NF-1)"."$NF}')
    read -p "Dominio raíz para las cookies (detectado: $ROOT_DOMAIN) [Enter para aceptar]: " INPUT_ROOT_DOMAIN
    if [[ ! -z "$INPUT_ROOT_DOMAIN" ]]; then
        ROOT_DOMAIN="$INPUT_ROOT_DOMAIN"
    fi
else
    ROOT_DOMAIN="$INPUT_ROOT_DOMAIN"
fi

while [[ -z "$ACME_EMAIL" ]]; do
    read -p "Email para certificados SSL (LetsEncrypt): " ACME_EMAIL
done

while [[ -z "$DASH_USER" ]]; do
    read -p "Usuario administrador (ej. admin): " DASH_USER
done

while [[ -z "$DASH_PASS" ]]; do
    read -s -p "Contraseña administrador: " DASH_PASS
    echo ""
done

# ==========================================
# 3. PREPARACIÓN DEL SISTEMA
# ==========================================
echo -e "\n${GREEN}[Paso 3/7] Preparando directorios y backups${NC}"

# Crear estructura de directorios
mkdir -p traefik/authelia

cd traefik || exit

# Instalar Docker Compose V2 Plugin
echo "Instalando Docker Compose V2 Plugin..."
mkdir -p ~/.docker/cli-plugins/
if [ ! -f "$HOME/.docker/cli-plugins/docker-compose" ]; then
    curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
fi
COMPOSE_CMD="$HOME/.docker/cli-plugins/docker-compose"
echo -e "Usando: ${GREEN}Docker Compose V2 (Plugin Binary)${NC}"

# Backup con rotación
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
for file in ".env" "docker-compose.yml" "authelia/configuration.yml" "authelia/users_database.yml"; do
    if [ -f "$file" ]; then
        echo -e "${YELLOW}Respaldando $file a $file.bak_$TIMESTAMP${NC}"
        cp "$file" "$file.bak_$TIMESTAMP"
        
        # Mantener solo los últimos 3 backups
        ls -t "$file.bak_"* 2>/dev/null | tail -n +4 | xargs -r rm --
    fi
done

# Crear acme.json con permisos seguros
if [ ! -f acme.json ]; then
    touch acme.json
    chmod 600 acme.json
    echo "Archivo acme.json creado (permisos 600)."
else
    echo "Archivo acme.json ya existe."
fi

# Crear red Docker
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy

# ==========================================
# 4. GENERACIÓN DE SECRETOS Y HASHES
# ==========================================
echo -e "\n${GREEN}[Paso 4/7] Generando criptografía${NC}"

# Generar secretos para Authelia
JWT_SECRET=$(generate_secret)
SESSION_SECRET=$(generate_secret)
STORAGE_PASSWORD=$(generate_secret)
ENCRYPTION_KEY=$(generate_secret)
echo "Secretos de sesión/storage generados aleatoriamente."

# Generar Hash de contraseña para Authelia (Argon2id)
echo "Generando hash seguro (Argon2) para el usuario..."
echo "Descargando imagen de Authelia (puede tardar unos segundos)..."
docker pull "authelia/authelia:${AUTHELIA_VERSION}"

# Ejecutar generación de hash capturando todo el output
# Usamos '|| true' para evitar que set -e detenga el script si docker devuelve error (ej. warnings)
echo "Ejecutando contenedor..."
RAW_OUTPUT=$(docker run --rm "authelia/authelia:${AUTHELIA_VERSION}" authelia hash-password "$DASH_PASS" 2>&1 || true)

# Extraer el hash buscando el patrón de Argon2
AUTHELIA_HASH=$(echo "$RAW_OUTPUT" | grep -o '\$argon2id.*' | head -n 1 | tr -d '\r')

# Verificar si se obtuvo el hash
if [ -z "$AUTHELIA_HASH" ]; then
     echo -e "${RED}Error: No se pudo generar el hash de Authelia.${NC}"
     echo "Output recibido del contenedor:"
     echo "$RAW_OUTPUT"
     exit 1
fi

echo "Hash generado correctamente."

# ==========================================
# 5. CONFIGURACIÓN DE AUTHELIA
# ==========================================
echo -e "\n${GREEN}[Paso 5/7] Configurando Authelia${NC}"

# Generar users_database.yml
cat <<EOF > authelia/users_database.yml
users:
  ${DASH_USER}:
    displayname: "Administrador"
    password: "${AUTHELIA_HASH}"
    email: "${ACME_EMAIL}"
    groups:
      - admins
EOF

# Generar configuration.yml
cat <<EOF > authelia/configuration.yml
###############################################################
#                   Authelia Configuration                    #
###############################################################

theme: light

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

totp:
  issuer: authelia.com

authentication_backend:
  file:
    path: /config/users_database.yml

access_control:
  default_policy: deny
  rules:
    # Permitir que Authelia se sirva a sí mismo (reset pass, verify, etc)
    - domain: "${AUTH_HOST}"
      policy: bypass
    
    # Proteger el Dashboard de Traefik y cualquier otro servicio
    - domain: "${TRAEFIK_HOST}"
      policy: two_factor
    
    # Regla comodín para administradores (opcional)
    - domain: "*.${ROOT_DOMAIN}"
      subject: "group:admins"
      policy: two_factor

session:
  name: authelia_session
  secret: "${SESSION_SECRET}"
  expiration: 3600 # 1 hora
  inactivity: 300  # 5 minutos
  domain: "${ROOT_DOMAIN}"  # Importante: el dominio raíz para compartir cookie
  same_site: lax

regulation:
  max_retries: 3
  find_time: 120
  ban_time: 300

storage:
  local:
    path: /config/db.sqlite3
  encryption_key: "${ENCRYPTION_KEY}"

notifier:
  filesystem:
    filename: /config/notification.txt
EOF

# Ajustar permisos para evitar errores si el contenedor corre como no-root
chmod 644 authelia/users_database.yml
chmod 644 authelia/configuration.yml
touch authelia/notification.txt
chmod 666 authelia/notification.txt
# Permitir que Authelia cree la DB (SQLite) y escriba logs/notificaciones
# Eliminamos DB antigua si existe por si acaso está corrupta o con permisos root
rm -f authelia/db.sqlite3
# Asignamos propietario 1000:1000 (usuario default de Authelia)
chown -R 1000:1000 authelia || chmod -R 777 authelia

echo "Configuración de Authelia generada."

# ==========================================
# 6. GENERACIÓN DE ARCHIVOS DE ENTORNO
# ==========================================
echo -e "\n${GREEN}[Paso 6/7] Creando .env y docker-compose.yml${NC}"

# Crear .env
cat <<EOF > .env
# --- Traefik Settings ---
TRAEFIK_DASHBOARD_HOST=${TRAEFIK_HOST}
ACME_EMAIL=${ACME_EMAIL}
DOCKER_API_VERSION=1.44


# --- Authelia Settings ---
AUTH_HOST=${AUTH_HOST}
AUTHELIA_JWT_SECRET=${JWT_SECRET}
AUTHELIA_SESSION_SECRET=${SESSION_SECRET}
AUTHELIA_STORAGE_PASSWORD=${STORAGE_PASSWORD}
EOF

# Crear docker-compose.yml
cat <<EOF > docker-compose.yml
services:
  traefik:
    image: "traefik:${TRAEFIK_VERSION}"
    container_name: "traefik"
    restart: always
    security_opt:
      - no-new-privileges:true
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      # Redirección HTTP -> HTTPS Global
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      # Certificados
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.myresolver.acme.email=\${ACME_EMAIL}"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "./acme.json:/letsencrypt/acme.json"
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    networks:
      - proxy
    env_file:
      - .env
    labels:
      - "traefik.enable=true"
      # Router Dashboard
      - "traefik.http.routers.dashboard.rule=Host(\`\${TRAEFIK_DASHBOARD_HOST}\`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=myresolver"
      # Middleware Chain: Authelia -> Headers
      - "traefik.http.routers.dashboard.middlewares=authelia,security-headers"
      
      # Middleware: Authelia ForwardAuth
      - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://\${AUTH_HOST}/"
      - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"

      # Middleware: Security Headers
      - "traefik.http.middlewares.security-headers.headers.sslredirect=true"
      - "traefik.http.middlewares.security-headers.headers.stsseconds=31536000"
      - "traefik.http.middlewares.security-headers.headers.browserxssfilter=true"
      - "traefik.http.middlewares.security-headers.headers.contenttypenosniff=true"
      - "traefik.http.middlewares.security-headers.headers.framedeny=true"

  authelia:
    image: "authelia/authelia:${AUTHELIA_VERSION}"
    container_name: authelia
    restart: always
    volumes:
      - ./authelia:/config
    networks:
      - proxy
    env_file:
      - .env
    expose:
      - 9091
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host(\`\${AUTH_HOST}\`)"
      - "traefik.http.routers.authelia.entrypoints=websecure"
      - "traefik.http.routers.authelia.tls.certresolver=myresolver"
      - "traefik.http.routers.authelia.middlewares=security-headers"

networks:
  proxy:
    external: true
EOF

# Corregir permisos de Authelia (UID 1000)
echo "Ajustando permisos de Authelia..."
chown -R 1000:1000 authelia

# ==========================================
# 7. VERIFICACIÓN SSL Y DESPLIEGUE FINAL
# ==========================================
echo -e "\n${GREEN}[Paso 7/7] Verificando estado SSL y Desplegando...${NC}"

# Check SSL
if [ -f acme.json ] && [ -s acme.json ]; then
    echo "Analizando certificados existentes en acme.json..."
    if grep -q "${TRAEFIK_HOST}" acme.json; then
         echo -e "${GREEN}✔ Certificado encontrado para ${TRAEFIK_HOST}${NC}"
    else
         echo -e "${YELLOW}⚠ Certificado para ${TRAEFIK_HOST} NO encontrado.${NC}"
         echo "Traefik intentará generarlo automáticamente vía Let's Encrypt."
    fi
    
    if grep -q "${AUTH_HOST}" acme.json; then
         echo -e "${GREEN}✔ Certificado encontrado para ${AUTH_HOST}${NC}"
    else
         echo -e "${YELLOW}⚠ Certificado para ${AUTH_HOST} NO encontrado.${NC}"
         echo "Traefik intentará generarlo automáticamente vía Let's Encrypt."
    fi
else
    echo "Archivo acme.json vacío o inexistente. Se generarán nuevos certificados."
fi

$COMPOSE_CMD up -d

echo -e "\n${BLUE}==============================================${NC}"
echo -e "${GREEN}¡INSTALACIÓN COMPLETADA!${NC}"
echo -e "${BLUE}==============================================${NC}"
echo -e "1. Dashboard de Traefik: https://${TRAEFIK_HOST}"
echo -e "2. Panel de Autenticación: https://${AUTH_HOST}"
echo -e ""
echo -e "Usuario: ${DASH_USER}"
echo -e "Contraseña: (la que introdujiste)"
echo -e ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo -e "Para el primer inicio de sesión, Authelia te pedirá configurar 2FA (TOTP)."
echo -e "Las notificaciones de registro (emails) se guardan localmente en:"
echo -e "$(pwd)/authelia/notification.txt"
echo -e "Consulta ese archivo para ver el enlace de verificación de tu usuario."