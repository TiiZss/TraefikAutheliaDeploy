#!/bin/bash

# ==========================================
# SCRIPT DE DESPLIEGUE REMOTO
# ==========================================


# Forzar codificación UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Cargar variables de entorno desde .env si existe
if [ -f .env ]; then
    echo "Cargando variables desde .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Configuración del Servidor Remoto (Con valores por defecto o vacíos)
REMOTE_IP="${DEPLOY_IP:-}"
REMOTE_USER="${DEPLOY_USER:-root}"
REMOTE_PASS="${DEPLOY_PASS:-}"

# Verificación de variables obligatorias
MISSING_VARS=0
for var in REMOTE_IP REMOTE_PASS TRAEFIK_HOST AUTH_HOST ACME_EMAIL DASH_USER DASH_PASS; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: La variable de entorno $var no está definida.${NC}"
        MISSING_VARS=1
    fi
done

if [ $MISSING_VARS -eq 1 ]; then
    echo -e "${YELLOW}Por favor, define las variables en un archivo .env o expórtalas en tu shell.${NC}"
    echo "Ejemplo de .env:"
    echo "DEPLOY_IP=x.x.x.x"
    echo "DEPLOY_PASS=tu_password"
    echo "TRAEFIK_HOST=monitor.tudominio.com"
    echo "..."
    exit 1
fi

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Iniciando Despliegue a ${REMOTE_IP} ===${NC}"

# 1. Verificar sshpass (necesario para pasar contraseña por script)
if ! command -v sshpass &> /dev/null; then
    echo -e "${RED}Error: sshpass no está instalado.${NC}"
    echo "Instálalo con: sudo apt install sshpass (o usa Git Bash en Windows con sshpass)"
    exit 1
fi

# 2. Aceptar fingerprint del servidor automáticamente (evita prompt yes/no)
echo "Aceptando fingerprint del servidor..."
mkdir -p ~/.ssh
ssh-keyscan -H $REMOTE_IP >> ~/.ssh/known_hosts 2>/dev/null

# 3. Copiar script de instalación
echo "Copiando instalador al servidor..."
sshpass -p "$REMOTE_PASS" scp -o StrictHostKeyChecking=no instalar_traefik.sh $REMOTE_USER@$REMOTE_IP:/root/instalar_traefik.sh

# 4. Ejecutar instalación remotamente
echo "Ejecutando instalación en remoto..."
echo "Nota: Se intentará detener contenedores que ocupen el puerto 80/443."

# Comando remoto:
# 1. Dar permisos de ejecución
# 2. Detener contenedor proxy existente (si existe) para liberar puertos 80/443
# 3. Ejecutar script en modo no interactivo (pasando variables)
REMOTE_CMD="
    # Corregir finales de línea (CRLF -> LF) por si se copió desde Windows
    sed -i 's/\r$//' /root/instalar_traefik.sh;
    chmod +x /root/instalar_traefik.sh;
    
    # Detener servicios conflictivos si existen
    if docker ps -a | grep -q ':80->'; then
        echo 'Detectado servicio en puerto 80. Deteniendo contenedores conflictivos...';
        # Busca contenedores escuchando en puerto 80 y los para
        docker stop \$(docker ps -q --filter 'publish=80') 2>/dev/null || true
    fi
    
    # Ejecutar instalador
    export TRAEFIK_HOST='$TRAEFIK_HOST'
    export AUTH_HOST='$AUTH_HOST'
    export ACME_EMAIL='$ACME_EMAIL'
    export DASH_USER='$DASH_USER'
    export DASH_PASS='$DASH_PASS'
    export INPUT_ROOT_DOMAIN='tiizss.com' # Forzar dominio raíz
    
    # Ejecutar con 'yes' para aceptar prompts automáticos si quedase alguno
    /root/instalar_traefik.sh
"

sshpass -p "$REMOTE_PASS" ssh -o StrictHostKeyChecking=no $REMOTE_USER@$REMOTE_IP "$REMOTE_CMD"

echo -e "${GREEN}=== Despliegue Finalizado ===${NC}"
