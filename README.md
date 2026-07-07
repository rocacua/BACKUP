# BACKUP & Development Environment Automation

Este repositorio contiene un conjunto de scripts en **Bash** y **Batch (Windows)** diseñados para automatizar la preparación de entornos de desarrollo locales y gestionar copias de seguridad de forma eficiente. 

Mientras que la herramienta principal se centra en los respaldos de datos, el resto de utilidades facilitan el despliegue rápido de servidores y herramientas de desarrollo para empezar a trabajar desde cero.

---

## 🚀 Compatibilidad de Entornos

Las herramientas de este repositorio han sido probadas y validadas en los siguientes sistemas operativos:

* **Linux:** Debian, Ubuntu, LinuxMint, EndeavourOS, Fedora y OpenSUSE.
* **Windows:** Windows 11 (para los archivos `.bat`).

---

## 🛠️ Descripción de los Componentes

### 📦 Gestión de Backups (Herramienta Principal)

*   **`backupR.sh`**: El script central del repositorio. Permite sincronizar directorios locales y remotos utilizando `rsync` y `rclone`. Su menú interactivo ofrece las siguientes opciones:
    1. **Crear/Actualizar respaldo**: Sincroniza tus datos de origen a destino de forma segura.
    2. **Restaurar respaldo**: Recupera tus datos desde una copia previamente realizada.
    3. **Crear claves SSH públicas/privadas**: Automatiza los accesos remotos sin contraseñas.
    4. **Vincular cuenta de Google Drive**: Configura respaldos directos en la nube.
*   **`exclude_list.txt`**: Archivo de configuración para omitir carpetas y archivos pesados o temporales durante las copias.

### 🖥️ Panel de Control

*   **`panel.sh`**: Centraliza la ejecución de los scripts de Bash más importantes de este repositorio a través de un menú interactivo en la terminal.

### 🌐 Automatización del Entorno de Desarrollo (Linux)

Utilidades pensadas para levantar un entorno listo para programar de forma modular:

*   **`instalide.sh`**: Instala entornos de desarrollo (IDEs) organizados por perfiles profesionales:
    *   **Desarrollo Web** *(PHP, JS, Laravel, React, Python)*: Visual Studio Code, VSCodium, Cursor, Neovim.
    *   **Desarrollo Java Profesional** *(Java SE/EE, Spring Boot)*: IntelliJ IDEA Community Edition, Apache NetBeans, Eclipse, Visual Studio Code, Android Studio.
    *   **Ecosistema Microsoft .NET** *(C#, Web APIs)*: Visual Studio Code, VSCodium, Cursor, Neovim.
    *   **SysAdmin / Automatización** *(Bash scripting, Terminal)*: Visual Studio Code, VSCodium, Cursor, Neovim.
*   **`creaweb.sh`**: Configura rápidamente la estructura inicial y el entorno local en Apache para los siguientes frameworks y tecnologías:
    1. WordPress
    2. Láminas
    3. CodeIgniter
    4. Laravel
    5. Symfony
    6. React JS
    7. Node JS (Express)
    8. Python
*   **`installamp.sh` / `installamp-mint.sh`**: Automatizan la instalación y configuración del stack LAMP (Linux, Apache, MySQL/MariaDB, PHP).
*   **`uninstallamp.sh`**: Elimina de forma limpia el stack LAMP del sistema.
*   **`uninstalide.sh`**: Desinstala las IDEs configuradas previamente.
*   **`borraweb.sh`**: Elimina por completo un sitio web local creado con el script.

### 💻 Automatización del Entorno (Windows)

Scripts que ofrecen funcionalidades análogas a las herramientas de Linux para entornos de trabajo en Windows 11:

*   **`backupR_windows.bat`**: Adaptación del script de copias de seguridad para la consola de comandos de Windows.
    1. **Realizar Copia de Seguridad Personalizada** (Origen y Destino)
    2. **Copia de Seguridad Completa del Entorno Web** (XAMPP/htdocs + DBs)
    3. **REPARAR: Error MySQL "shutdown unexpectedly"** (Corrupción de datos)
    4. **REPARAR: Error de Sesión PHP** ("No disponible temporalmente")
    5. **RESTAURAR: Recuperar copia de seguridad completa** (htdocs + DBs)
    6. **Mostrar información del Sistema de Archivos y Almacenamiento**
*   **`installamp-win.bat`**: Automatiza el despliegue de herramientas de servidor web en Windows `XAMPP`.
*   **`instalide-win.bat`**: Instala de forma desatendida las IDEs de desarrollo seleccionadas.
    1. **Desarrollo Web**: Visual Studio Code, VSCodium, Cursor AI Editor
    2. **Desarrollo Java**: IntelliJ IDEA Community, Apache NetBeans, Visual Studio Code
    3. **Ecosistema Microsoft .NET**: Visual Studio Community, Visual Studio Code, JetBrains Rider
    4. **SysAdmin / Automatizacion**: Visual Studio Code, Notepad++
*   **`creaweb-win.bat`**: Configura rápidamente nuevos entornos virtuales o rutas web locales en Windows.
    1. WP 
    2. Laminas
    3. CI4
    4. Laravel
    5. Symfony
    6. React
    7. Node
    8. Python

### 🧪 Scripts de Pruebas y Post-Instalación
Scripts de aprovisionamiento optimizados para ejecutar tras la instalación limpia de un sistema operativo dentro de una máquina virtual (VirtualBox).
*   **`posinstalvb1.sh`**: Ejecutar tras la instalación del SO, para instalar las Guest Additions, dado que aun no se puede copiar entre anfitrión y huesped se recomienda pasarlo a partir de una carpeta `compartir` en el anfitrión montandola del siguiente modo:
[Ctrl + Alt + T]
```bash
# 1. Crear una carpeta temporal en tu usuario
mkdir -p ~/vbox_temp
# 2. Montar la carpeta compartida (usa el "Nombre de la carpeta" del Paso 1)
sudo mount -t vboxsf compartir ~/vbox_temp 2>/dev/null || sudo mount compartir ~/vbox_temp
# 3. Entrar a la carpeta temporal
cd ~/vbox_temp
# 4. Copiar tu instalador al equipo e iniciarlo
cp posinstalvb1.sh ~/ && cd ~/ && chmod +x posinstalvb1.sh
./posinstalvb1.sh
```
*   **`posinstalvb2.sh`**: Se puede ejecutar tras `./posinstalvb1.sh` para limpiar el sistema y apagarlo asegurando que el disco virtual pese lo menos posible antes de tomar una instantanea inicial para poder volver atrás si sale mal alguna prueba. Se puede ejecutar de la siguente forma dado que el script anterior ya debe montar automáticamente la carpeta `compartir` (`Automontar` y `Hacer permanente` devió configurarse anteriormente en VirtualBox):
[Ctrl + Alt + T]
```bash
cp /media/sf_compartir/posinstalvb2.sh .
./posinstalvb2.sh
```
*   **`cp_pruebas_VB.sh`**: Script auxiliar para copiar y verificar datos dentro de los entornos de prueba virtualizados.
[Ctrl + Alt + T]
```bash
cp /media/sf_compartir/cp_pruebas_VB.sh .
./cp_pruebas_VB.sh
cd ~/BACKUP
./panel.sh
```

---

## ⚙️ Requisitos Previos

Para exprimir al máximo estos scripts, asegúrate de contar con las siguientes herramientas instaladas en tu sistema Linux:

*   `rsync` (Versión >= 3.1)
*   `ssh` (Cliente y `openssh-server` en la máquina destino si realizas backups remotos)
*   `rclone` (Opcional, para sincronización con servicios en la nube)
*   Permisos de `sudo` (Para los scripts de instalación de paquetes y gestión web)

---

## 📖 Ejemplos de Uso Rápido

### Modo Interactivo (Menú guiado)
Para lanzar la interfaz principal que conecta las herramientas, ejecuta:
```bash
./panel.sh
```
Para gestionar tus copias de seguridad de forma manual y asistida, simplemente ejecuta:
```bash
./backupR.sh
```

### Modo No Interactivo (Automatización / Cron)
Ideal para programar copias de seguridad en el sistema sin intervención humana. 

* **Simulación (Dry-Run):** Verifica qué archivos se copiarían sin realizar cambios reales.
  ```bash
  ./backupR.sh --non-interactive --src /ruta/origen --dst user@host:/ruta/destino --dry-run
  ```
* **Ejecución Real:**
  ```bash
  ./backupR.sh --non-interactive --src /ruta/origen --dst user@host:/ruta/destino
  ```
#### Requisitos para ejecución no interactiva
* Configura autenticación por clave SSH sin contraseña (o usar `ssh-agent`):
  ```bash
  ssh-keygen -t ed25519
  ssh-copy-id user@host
  ```
* Si la copia requiere privilegios remotos, considera configurar `sudo` sin contraseña con cuidado.

#### Comportamiento técnico clave
* `--rsync-path`: se usa para ejecutar `mkdir -p` en el host remoto en la misma conexión SSH que `rsync`, evitando errores al crear rutas anidadas.
* Evitamos ejecutar utilidades locales (`df`, `du`, `realpath`) sobre cadenas que identifican remotos; el script detecta remotos y cambia las comprobaciones.
* Si el destino es `remote:subpath` y `rclone` está instalado, el script puede optar por `rclone` como alternativa cuando rsync/SSH no aplican.

#### Logs
* Los logs se escriben en `logs/BACKUP-YYYY-MM-DD_HH-MM-SS.log`.
* En `--dry-run` verás el comando completo (incluyendo `--rsync-path`) y la lista simulada de archivos.

#### Errores comunes y soluciones
* Permission denied (`publickey,password`): falta de clave pública. Genera e instala una llave con `ssh-copy-id`.
* `rsync`: [Receiver] `mkdir "..." failed: No such file or directory:` el script añade `--rsync-path`; si ves rutas duplicadas, normaliza la variable `--dst` y evita `//` dobles.
* `df`/`du` fallando en remotos: indica que el script intentó medir espacio sobre un remote; usa `--dry-run` y revisa `get_rsync_opts()`.
#### Integración en cron (ejemplo)
Configura autenticación sin contraseña y prueba primero con `--dry-run`.
  ```bash
# Backup diario a las 03:00 (ajusta rutas y usuario)
0 3 * * * /ruta/a/directorio/backupR.sh --non-interactive --src /origen --dst user@host:/destino >> /ruta/a/directorio/logs/cron-backup-$(date +\%F).log 2>&1
  ```

---

## 📝 Buenas Prácticas

1. **Prueba antes de ejecutar:** Utiliza siempre el flag `--dry-run` antes de automatizar una tarea de backup en producción.
2. **Acceso sin contraseñas:** Configura claves SSH basadas en certificados (`ssh-copy-id`) para permitir que los scripts remotos se ejecuten en segundo plano sin pedir credenciales.
3. **Personaliza tus filtros:** Edita el archivo `exclude_list.txt` para evitar copiar gigabytes de datos innecesarios (como las carpetas `node_modules` o archivos `.log`).
