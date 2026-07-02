#!/bin/bash

# Asegurar que el script se ejecuta con los privilegios necesarios
if [ "$(uname)" != "Darwin" ] && [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./uninstallamp.sh)."
  exit 1
fi

# ==============================================================================
# DETECCIÓN DE SITEMA OPERATIVO (IDÉNTICA AL INSTALADOR)
# ==============================================================================
REAL_USER=${SUDO_USER:-$USER}
if [ "$(uname)" == "Darwin" ]; then
    OS="macOS"
    INSTALL_CMD="brew install"
    SUDO=""
    UPDATE_CMD="brew update && brew upgrade"
    APACHE_S="httpd"
    # Mapeo unificado para Mac
    DB_PKGS="mysql"
    DB_SERVICE="mysql"
    PHP_PKGS="php imagemagick" 
    FZ_PKG="" 
    PMA_PKG="phpmyadmin"  
    APACHE_USER="_www"
    WEB_ROOT="/Users/${REAL_USER}/workspace" 
    WEB_ROOT_DEFAULT="/opt/homebrew/var/www"  
    REMOVE_CMD="brew uninstall"
else
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "Error: No se pudo encontrar /etc/os-release."
        exit 1
    fi
    
    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}" 
    OS_ID="${ID,,}"

    if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
            OS="Debian-based"
            INSTALL_CMD="apt-get install -y"
            SUDO="sudo"
            UPDATE_CMD="apt-get update && apt-get upgrade -y"
            APACHE_S="apache2"
            # Corrección de nombres de paquetes y servicios según el OS_ID en minúsculas
            if [[ "$OS_ID" == "debian" ]]; then
                DB_PKGS="mariadb-server mariadb-client"
                DB_SERVICE="mariadb"
            else
                DB_PKGS="mysql-server mysql-client"
                DB_SERVICE="mysql"
            fi
            PHP_PKGS="php php-cli php-common php-fpm php-mysql php-zip php-gd php-mbstring php-curl php-xml php-bcmath imagemagick php-imagick php-json php-mysqlnd"
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="www-data"
            WEB_ROOT="/home/${REAL_USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
            REMOVE_CMD="apt-get purge -y" # Purge elimina configuraciones en Debian
    elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
            OS="Fedora-based"
            INSTALL_CMD="dnf install -y"
            SUDO="sudo"
            UPDATE_CMD="dnf upgrade -y"
            APACHE_S="httpd"
            DB_PKGS="mariadb-server" 
            DB_SERVICE="mariadb"
            PHP_PKGS="php php-cli php-fpm php-mysqlnd php-zip php-gd php-mbstring php-curl php-xml php-json php-bcmath imagemagick php-pecl-imagick"
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="apache"
            WEB_ROOT="/home/${REAL_USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
            REMOVE_CMD="dnf remove -y"
    elif [[ "$ALL_IDS" =~ "arch" || "$ALL_IDS" =~ "manjaro" || "$ALL_IDS" =~ "endeavouros" ]]; then
            OS="Arch-based"
            INSTALL_CMD="pacman -S --noconfirm"
            SUDO="sudo"
            UPDATE_CMD="pacman -Syu --noconfirm"
            APACHE_S="httpd"
            DB_PKGS="mariadb mariadb-clients"
            DB_SERVICE="mariadb"
            PHP_PKGS="php php-fpm php-gd imagemagick php-imagick" 
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="http"
            WEB_ROOT="/home/${REAL_USER}/workspace"
            WEB_ROOT_DEFAULT="/srv/http"
            REMOVE_CMD="pacman -Rns --noconfirm" # Elimina paquetes y dependencias no usadas
    elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
            OS="SUSE-based"
            INSTALL_CMD="zypper --non-interactive install"
            SUDO="sudo"
            UPDATE_CMD="zypper --non-interactive update"
            APACHE_S="apache2"
            DB_PKGS="mariadb mariadb-client"
            DB_SERVICE="mariadb"
            PHP_PKGS="php8 php8-fpm php8-mysql php8-zip php8-gd php8-mbstring php8-curl php8-xml php8-bcmath ImageMagick php8-imagick"
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="wwwrun"
            WEB_ROOT="/home/${REAL_USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
            REMOVE_CMD="zypper --non-interactive remove"
    else
            echo "Sistema operativo no compatible o no detectado en: $ALL_IDS."
            exit 1
    fi
fi

echo "=============================================================================="
echo " INICIANDO DESINSTALACIÓN EN: $OS"
echo "=============================================================================="

# 1. Detener y deshabilitar servicios del sistema (Excepto en macOS)
echo " Deteniendo servicios..."
if [ "$OS" = "macOS" ]; then
    brew services stop $APACHE_S 2>/dev/null
    brew services stop $DB_SERVICE 2>/dev/null
else
    $SUDO systemctl stop $APACHE_S 2>/dev/null
    $SUDO systemctl stop mysql 2>/dev/null
    $SUDO systemctl stop mariadb 2>/dev/null
    $SUDO systemctl stop php-fpm 2>/dev/null
    # Matar procesos huérfanos de MySQL que puedan bloquear carpetas
    $SUDO killall -9 mysqld mariadbd 2>/dev/null || true
fi

# 2. Desinstalar exactamente los mismos paquetes que se instalaron
echo " Eliminando paquetes de software..."
if [ "$OS" = "macOS" ]; then
    $REMOVE_CMD $APACHE_S $DB_PKGS $PHP_PKGS $PMA_PKG 2>/dev/null
    # Eliminar Filezilla si se instaló mediante cask
    brew uninstall --cask filezilla 2>/dev/null
else
    # $SUDO $REMOVE_CMD $APACHE_S $DB_PKGS $PHP_PKGS $FZ_PKG $PMA_PKG 2>/dev/null
    # # Limpieza de dependencias huérfanas
    # if [ "$OS" = "Debian-based" ]; then
    #     $SUDO apt-get autoremove -y 2>/dev/null
    # elif [ "$OS" = "Fedora-based" ]; then
    #     $SUDO dnf autoremove -y 2>/dev/null
    # fi
    # 🚨 Modificación Crítica para Debian-based: añade dbconfig-common y dbconfig-mysql al purgar
    if [ "$OS" = "Debian-based" ]; then
        #$SUDO $REMOVE_CMD $APACHE_S $DB_PKGS $PHP_PKGS $FZ_PKG $PMA_PKG dbconfig-common dbconfig-mysql 2>/dev/null
        DEBIAN_FRONTEND=noninteractive $SUDO $REMOVE_CMD $APACHE_S $DB_PKGS $PHP_PKGS $FZ_PKG $PMA_PKG dbconfig-common dbconfig-mysql -y -q
        $SUDO apt-get autoremove --purge -y 2>/dev/null
        $SUDO apt-get clean 2>/dev/null
    else
        $SUDO $REMOVE_CMD $APACHE_S $DB_PKGS $PHP_PKGS $FZ_PKG $PMA_PKG 2>/dev/null
        if [ "$OS" = "Fedora-based" ]; then
            $SUDO dnf autoremove -y 2>/dev/null
        fi
    fi
fi

# 3. Limpieza de red (/etc/hosts)
echo " Removiendo configuraciones de red..."
if [ "$OS" = "macOS" ]; then
    sudo sed -i '' '/127.0.0.1 prueba.test/d' /etc/hosts 2>/dev/null
else
    $SUDO sed -i '/127.0.0.1 prueba.test/d' /etc/hosts 2>/dev/null
fi

# 🚀 Obtener el usuario real en entorno SUDO para evitar rutas vacías
#REAL_USER=${SUDO_USER:-$USER}
#WEB_ROOT="/home/${REAL_USER}/workspace"

# 4. Eliminar directorios del VirtualHost y espacio de trabajo de prueba
echo " Limpiando directorios de archivos web..."
if [ -d "${WEB_ROOT}/prueba" ]; then
    # Se usa sudo si es Linux para evitar problemas de permisos con archivos creados por el servidor web
    $SUDO rm -rf "${WEB_ROOT}/prueba"
fi

# Eliminar el directorio padre workspace sólo si ha quedado completamente vacío
if [ -d "$WEB_ROOT" ] && [ -z "$(ls -A "$WEB_ROOT" 2>/dev/null)" ]; then
    rmdir "$WEB_ROOT" 2>/dev/null
fi

# 🔧 RESTAURACIÓN EXCLUSIVA PARA openSUSE (SUSE-based)
if [ -f /etc/apache2/httpd.conf ]; then
    # 1. Eliminar el archivo VirtualHost de SUSE
    $SUDO rm -f /etc/apache2/vhosts.d/prueba.conf 2>/dev/null
    
    # 2. 🌟 Eliminar la anulación de aislamiento ProtectHome de Systemd
    $SUDO rm -rf /etc/systemd/system/apache2.service.d 2>/dev/null
    $SUDO systemctl daemon-reload

    # 3. Revertir la directiva 'Require all granted' del archivo global para mantener el sistema seguro
    $SUDO sed -i '/Require all granted/d' /etc/apache2/httpd.conf 2>/dev/null
    
    # 4. Apagar el flag global de SELinux si se desea dejar el sistema original
    if command -v setsebool >/dev/null 2>&1; then
        $SUDO setsebool -P httpd_enable_homedirs off 2>/dev/null
    fi
    
    # 4. Reiniciar el servicio limpio
    $SUDO systemctl restart apache2 2>/dev/null
fi

# 5. Pregunta crítica: ¿Eliminar los directorios de datos de las bases de datos?
echo "------------------------------------------------------------------------------"
# read -p "¿Deseas borrar permanentemente los directorios de datos y configuraciones de MySQL/MariaDB? [s/N]: " RESPUESTA
# if [[ "$RESPUESTA" =~ ^[Ss]$ ]]; then
#     echo " Borrando datos residuales de las bases de datos..."
#     if [ "$OS" = "macOS" ]; then
#         rm -rf /opt/homebrew/var/mysql 2>/dev/null
#         rm -rf /usr/local/var/mysql 2>/dev/null
#     else
#         $SUDO rm -rf /var/lib/mysql 2>/dev/null
#         $SUDO rm -rf /etc/mysql /etc/my.cnf /etc/my.cnf.d /etc/httpd /etc/apache2 2>/dev/null
#     fi
# else
#     echo " Se han conservado los directorios de datos de la base de datos."
# fi
# 5. 🚨 BORRADO AUTOMÁTICO DE DATOS (Sin interactividad para facilitar pruebas de clonación)
echo " Borrando datos residuales y archivos de configuración antiguos..."
if [ "$OS" = "macOS" ]; then
    rm -rf /opt/homebrew/var/mysql /usr/local/var/mysql 2>/dev/null
    rm -rf /opt/homebrew/etc/httpd /opt/homebrew/etc/php 2>/dev/null
else
    # Limpieza exhaustiva de datos del motor y sockets bloqueantes
    $SUDO rm -rf /var/lib/mysql /var/lib/mysql-files /var/log/mysql /var/log/mariadb 2>/dev/null
    
    # # Limpieza total de rutas de configuración huérfanas en el sistema
    # $SUDO rm -rf /etc/mysql /etc/my.cnf /etc/my.cnf.d /etc/phpmyadmin /etc/dbconfig-common 2>/dev/null
    
    # # Solo eliminar configuraciones globales de servidores si no hay más desarrollos
    # if [ "$OS" = "Debian-based" ] || [ "$OS" = "SUSE-based" ]; then
    #     $SUDO rm -rf /etc/apache2 2>/dev/null
    # else
    #     $SUDO rm -rf /etc/httpd 2>/dev/null
    # fi
    
    #  MANTÉN SOLO ESTO (Es seguro y no rompe reinstalaciones):
    $SUDO rm -rf /var/lib/mysql /var/lib/mysql-files /var/log/mysql /var/log/mariadb 2>/dev/null
fi

echo "=============================================================================="
#echo " ¡El sistema ha sido revertido en base a tu configuración de instalación!"
echo " ✅ DESINSTALACIÓN COMPLETADA CON ÉXITO"
echo "=============================================================================="
