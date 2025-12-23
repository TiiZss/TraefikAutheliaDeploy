# Guía de Instalación: Traefik v3 + Authelia

<div align="center">

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-%2329313D.svg?style=for-the-badge&logo=traefik&logoColor=white)
![Authelia](https://img.shields.io/badge/Authelia-%2321287F.svg?style=for-the-badge&logo=authelia&logoColor=white)
![Bash](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub issues](https://img.shields.io/github/issues/TiiZss/TraefikAutheliaDeploy)](https://github.com/TiiZss/TraefikAutheliaDeploy/issues)
[![GitHub stars](https://img.shields.io/github/stars/TiiZss/TraefikAutheliaDeploy)](https://github.com/TiiZss/TraefikAutheliaDeploy/stargazers)
[![GitHub last commit](https://img.shields.io/github/last-commit/TiiZss/TraefikAutheliaDeploy)](https://github.com/TiiZss/TraefikAutheliaDeploy/commits/main)

</div>

Este documento detalla las mejoras de seguridad y la integración de **Authelia** en el script de instalación automática `instalar_traefik.sh`.

## Diferencias Clave
| Característica | Antes (Basic Auth) | Ahora (Authelia) |
| :--- | :--- | :--- |
| **Login** | Popup básico del navegador | Interfaz web moderna |
| **Seguridad** | Contraseña simple | **2FA (TOTP)**, bloqueo fuerza bruta |
| **Gestión** | Hash manual en archivo | Base de datos de usuarios (SQLite) + Cookies seguras |
| **Alcance** | Solo credenciales básicas | **SSO** (Single Sign-On) para múltiples servicios |

## Estructura de Archivos Generada
El script ahora crea una estructura más completa para gestionar la configuración de Authelia por separado.
```text
traefik/
├── .env                     # Secretos (Authelia requiere varios tokens)
├── docker-compose.yml       # Servicios: Traefik + Authelia
├── acme.json                # Certificados SSL
└── authelia/                # [NUEVO] Carpeta de configuración
    ├── configuration.yml    # Reglas de acceso y config del servidor
    ├── users_database.yml   # Usuarios y hashes de contraseña
    └── notification.txt     # [IMPORTANTE] Aquí llegan los emails simulados
```

## Flujo de Verificación (Paso a Paso)

1.  **Ejecución**:
    Correr el script `./instalar_traefik.sh`. Te pedirá dos dominios (Dashboard y Auth).

2.  **Validación de Despliegue**:
    ```bash
    docker compose ps
    ```
    Debes ver dos contenedores: `traefik` y `authelia` en estado `Up`.

3.  **Primer Inicio de Sesión (Registro 2FA)**:
    *   Entra a tu dashboard (ej. `monitor.misitio.com`).
    *   Serás redirigido automáticamente a `auth.misitio.com`.
    *   Loguéate con el usuario y la contraseña que definiste.
    *   **Authelia te pedirá registrar tu dispositivo 2FA**.
    *   Haz clic en "Register". Authelia te dirá ser ha enviado un email.
    *   **Truco**: Como no hemos configurado SMTP real, el email está en un archivo local.
        ```bash
        cat traefik/authelia/notification.txt
        ```
    *   Copia el enlace que aparece en ese archivo y ábrelo en tu navegador para completar el registro (escanea el QR con Google Authenticator/Authy).

4.  **Panel de Traefik**:
    Una vez autenticado, verás el dashboard de Traefik. ¡Estás dentro!

## Solución de Problemas
*   **Error 502/504 en el Auth**: Authelia tarda unos segundos en arrancar (generando claves RSA). Espera 30 segundos.
*   **Hash Incorrecto**: El script usa un contenedor Docker para generar hashes Argon2 compatibles. Si cambiase la versión de Authelia drásticamente, podría requerir ajustes.

## Despliegue Remoto (`deploy.sh`)

Se ha creado un script `deploy.sh` que automatiza la instalación en el servidor remoto.

### Requisitos
1.  **Entorno Unix/Linux**: WSL o Git Bash en Windows.
2.  **`sshpass`**: Necesario para el login automático con contraseña.

### Uso Seguro (Variables de Entorno)
1.  Copia el archivo de ejemplo:
    ```bash
    cp .env.example .env
    ```
2.  Edita `.env` con la IP de tu servidor y tus credenciales.
3.  Ejecuta el script de despliegue:
    ```bash
    bash deploy.sh
    ```
    *El script leerá automáticamente las variables del archivo `.env`.*

El script copiará el instalador, detendrá contenedores conflictivos en el puerto 80/443 y ejecutará la instalación de forma desatendida.

## Cómo añadir una nueva aplicación

Para proteger una nueva aplicación con Authelia, simplemente añádela a tu `docker-compose.yml` (o crea uno nuevo en la misma red `proxy`) con las siguientes etiquetas (labels).

### Ejemplo: Whoami (App de prueba)

```yaml
services:
  whoami:
    image: traefik/whoami
    container_name: whoami
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      # Configuración del Router
      - "traefik.http.routers.whoami.rule=Host(`whoami.tu-dominio.com`)"
      - "traefik.http.routers.whoami.entrypoints=websecure"
      - "traefik.http.routers.whoami.tls.certresolver=myresolver"
      
      # [IMPORTANTE] Protección con Authelia
      - "traefik.http.routers.whoami.middlewares=authelia,security-headers"
```

### Puntos Clave
1.  **Red**: La aplicación debe estar en la red `proxy` para que Traefik la vea.
2.  **Middlewares**: La línea `middlewares=authelia,security-headers` es la que activa la protección.
    *   `authelia`: Redirige al login si no estás autenticado.
    *   `security-headers`: Añade cabeceras de seguridad extra.

---

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Por favor:

1.  🍴 **Fork** el repositorio.
2.  🌿 **Crea una rama** para tu feature (`git checkout -b feature/AmazingFeature`).
3.  💾 **Commit** tus cambios (`git commit -m 'Add some AmazingFeature'`).
4.  📤 **Push** a la rama (`git push origin feature/AmazingFeature`).
5.  🔄 Abre un **Pull Request**.

## 📄 Licencia

Este proyecto está licenciado bajo la **Licencia GPL v3.0** - ver el archivo [LICENSE](LICENSE) para más detalles.

## 👨‍💻 Autor

**TiiZss** - [GitHub Profile](https://github.com/TiiZss)

## 🙏 Agradecimientos

*   Comunidad de **Traefik** y **Authelia** por su excelente documentación.
*   Contribuidores y usuarios del proyecto que reportan issues y mejoras.

## 📈 Estadísticas del Proyecto

*   🎯 **Versión Actual**: 2.0 (Authelia Edition)
*   🐚 **Stack**: Bash, Docker, Docker Compose
*   📦 **Contenedores**: Traefik v3, Authelia, Redis, Whoami
*   🌟 **Características**: Autenticación 2FA, SSO, Certificados Wildcard, Cabeceras de Seguridad
*   📄 **Archivos Generados**: Estructura automática de carpetas y configuración YAML
*   🛠️ **Scripts de Instalación**: Despliegue local y remoto automatizado

---

*   ⭐ **Si este proyecto te ha sido útil, no olvides darle una estrella en GitHub!**

