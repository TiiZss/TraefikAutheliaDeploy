# 🛡️ Despliegue Automático: Traefik v3 + Authelia

<div align="center">

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-%2329313D.svg?style=for-the-badge&logo=traefik&logoColor=white)
![Authelia](https://img.shields.io/badge/Authelia-%2321287F.svg?style=for-the-badge&logo=authelia&logoColor=white)
![Bash](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/TiiZss/TraefikAutheliaDeploy)](https://github.com/TiiZss/TraefikAutheliaDeploy/issues)
[![GitHub stars](https://img.shields.io/github/stars/TiiZss/TraefikAutheliaDeploy)](https://github.com/TiiZss/TraefikAutheliaDeploy/stargazers)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FP-yellow.svg)](https://www.buymeacoffee.com/TiiZss)

> [!TIP]
> **New in v3**: This updated version supports Docker Engine v27+, Traefik v3 (latest), and includes robust permission handling for Authelia on strict environments.

</div>

Esta herramienta automatiza el despliegue de un **Proxy Inverso Seguro** utilizando **Traefik v3** y **Authelia**. Proporciona una capa de seguridad robusta (2FA, SSO) para todos tus servicios Docker con una configuración mínima.

---

## 🚀 Características

| Característica | Descripción |
| :--- | :--- |
| **Autenticación Moderna** | Reemplaza Basic Auth con un portal de login moderno y seguro. |
| **Seguridad Avanzada** | Autenticación de Dos Factores (**2FA**), protección contra fuerza bruta y bloqueo de intentos fallidos. |
| **Single Sign-On (SSO)** | Inicia sesión una vez y accede a todos tus subdominios protegidos. |
| **SSL Automático** | Gestión de certificados Let's Encrypt para HTTPS en todos los servicios. |
| **Despliegue Fácil** | Scripts para instalación local (`instalar_traefik.sh`) y remota (`deploy.sh`). |
| **Backups** | Copia de seguridad automática de configuración (rotación de últimos 3). |

## 📋 Requisitos Previos

*   **Servidor Linux**: Ubuntu/Debian recomendado (o WSL en Windows).
*   **Docker & Docker Compose**: El script intentará instalarlos si no existen (plugin version).
*   **Dominios**: Necesitas al menos dos subdominios apuntando a tu servidor:
    *   `monitor.midominio.com` (para el Dashboard de Traefik)
    *   `auth.midominio.com` (para el Portal de Login)
*   **Puertos Libres**: El servidor debe tener los puertos `80` y `443` disponibles (el script lo verificará).

## 🛠️ Instalación

### Opción A: Instalación Local o Interactiva
Si ya estás dentro del servidor SSH:

```bash
chmod +x instalar_traefik.sh
./instalar_traefik.sh
```
El asistente te pedirá paso a paso los dominios, email y credenciales.

### Opción B: Despliegue Remoto (`deploy.sh`)
Para desplegar desde tu máquina local a un servidor remoto **sin entrar por SSH manualmente**.

1.  Copia y configura el archivo de entorno:
    ```bash
    cp .env.example .env
    nano .env  # Define IP, Usuario, Dominios, etc.
    ```
2.  Ejecuta el despliegue:
    ```bash
    bash deploy.sh
    ```
    *Nota: Si tienes claves SSH configuradas, no necesitas definir contraseña. Si no, necesitarás `sshpass`.*

## 📂 Estructura Generada

El script crea una carpeta `traefik/` con todo lo necesario:

```text
traefik/
├── .env                     # Secretos de Authelia y Traefik
├── docker-compose.yml       # Definición de servicios
├── acme.json                # Almacén de certificados SSL
└── authelia/                # Configuración persistente de Authelia
    ├── configuration.yml    # Reglas y políticas de acceso
    ├── users_database.yml   # Base de datos de usuarios (Hashes Argon2)
    └── notification.txt     # Buzón local para tokens 2FA (simulación de email)
```
*Los backups anteriores se rotan automáticamente (mantiene los 3 más recientes).*

## 🔐 Primer Inicio de Sesión (Importante)

1.  Accede a `https://monitor.midominio.com`.
2.  Serás redirigido al portal de **Authelia**.
3.  Ingresa tus credenciales de administrador.
4.  **Registro 2FA**: Authelia te pedirá registrar un dispositivo.
    *   Haz clic en "Register".
    *   **Recupera el token** del archivo local en el servidor:
        ```bash
        cat traefik/authelia/notification.txt
        ```
    *   Usa el enlace proporcionado para escanear el QR con Google Authenticator o Authy.

## 🛡️ Cómo Proteger Nuevos Contenedores

Para añadir autenticación a cualquier otro contenedor Docker, simplemente añade estas `labels` en tu `docker-compose.yml`:

```yaml
services:
  mi-app:
    image: nginx
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.midominio.com`)"
      - "traefik.http.routers.app.entrypoints=websecure"
      - "traefik.http.routers.app.tls.certresolver=myresolver"
      # LA LÍNEA MÁGICA:
      - "traefik.http.routers.app.middlewares=authelia,security-headers"
```

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Sigue estos pasos:

1.  🍴 **Fork** el repositorio.
2.  🌿 **Crea una rama** (`git checkout -b feature/NuevaMejora`).
3.  💾 **Commit** tus cambios (`git commit -m 'Añadir nueva funcionalidad'`).
4.  📤 **Push** a la rama (`git push origin feature/NuevaMejora`).
5.  🔄 Abre un **Pull Request**.

## 📈 Estadísticas del Proyecto

*   🎯 **Versión**: 2.0 (Authelia Edition)
*   🐚 **Stack**: Bash, Docker, Traefik v3, Authelia
*   📦 **Componentes**: Redis, Whoami, Argon2id
*   📄 **Licencia**: GPL v3.0

## 👨‍💻 Autor y Soporte

Desarrollado por **[TiiZss](https://github.com/TiiZss)**.

Si este proyecto te ha ahorrado tiempo o te ha servido de ayuda, ¡aprecio mucho tu apoyo!

<a href="https://www.buymeacoffee.com/TiiZss" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

---
*Recuerda dar una ⭐ estrella al repositorio si te ha gustado.*
