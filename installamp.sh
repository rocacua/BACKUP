#!/bin/bash
SEGUNDOS_INICIO=$(date +"%s")
HORA_INICIO_HUMANA=$(date +%H:%M:%S)
# ==========================================
# 📋 CONFIGURACIÓN DEL LOG AUTOMÁTICO
# ==========================================
# Definimos dónde se guardará el reporte (en el home del usuario ejecutor)
declare -r DIR_SCRIPT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
fecha=$(date +%Y-%m-%d_%H-%M-%S)

# 1. Definir la ruta de la CARPETA de logs y el ARCHIVO de log correctamente
LOG_DIR="$DIR_SCRIPT/logs"
LOG_FILE="$LOG_DIR/instalacion_lamp-${fecha}.log"

# 2. Intentar crear la carpeta de logs si no existe
if [[ ! -d "$LOG_DIR" ]]; then
    # El comando mkdir heredará los permisos de sudo si se ejecuta con él
    mkdir -p "$LOG_DIR" 2>/dev/null
fi

# 3. COMPROBACIÓN CRÍTICA: ¿El script puede escribir en esa carpeta?
if [[ ! -w "$LOG_DIR" ]]; then
    echo "⚠️ Advertencia: No hay permisos de escritura en $LOG_DIR"
    echo "📂 El historial se guardará temporalmente en tu carpeta personal (/home/${USER})."
    
    # Redirección de emergencia a una ruta donde el usuario SIEMPRE tiene permisos
    echo "📂 El historial se guardará temporalmente en tu carpeta personal ($HOME)."
    LOG_DIR="$HOME"
    LOG_FILE="$LOG_DIR/instalacion_lamp-${fecha}.log"
    
    # Intentar asegurar que exista (por si acaso)
    mkdir -p "$LOG_DIR" 2>/dev/null
fi


# 4. Magia de Bash: Duplica la salida de pantalla y la envía al archivo en tiempo real
# 🟢 PASO 1: Guardar la salida (1) y el error (2) originales de la terminal en los canales 3 y 4
exec 3>&1 4>&2
# Activar el log global a través de tee
exec > >(tee -i "$LOG_FILE") 2>&1


echo "📝 Grabando registro en: $LOG_FILE"

# Definir variables de color
ROJO=$'\e[31m'
VERDE=$'\e[32m'
AZUL=$'\e[34m'
CIAN=$'\e[36m'
AMARILLO=$'\e[33m'
MAGENTA=$'\033[0;35m'  	# Magenta / Morado normal
NC=$'\e[0m' # Restablecer color
# Versiones en negrita (opcional, para mayor claridad)
ROJO_B=$'\e[1;31m'
VERDE_B=$'\e[1;32m'
CIAN_B=$'\e[1;36m'
AMARILLO_B=$'\e[1;33m'
MAGENTA_B=$'\033[1;35m'	# Magenta en negrita (resalta más para preguntas)

# ini pintar
pintar() {
	local texto="$1"
	local tipo="${2:-normal}"
	local salto="${3:-1}"
	local color=""
	local etiqueta=""

	# 1. Seleccionar color y etiqueta según el tipo
	case "$tipo" in
    	"error")    color="$ROJO";      etiqueta="[ERROR] " ;;
    	"exito")    color="$VERDE";     etiqueta="[OK] " ;;
    	"alerta")   color="$AMARILLO";  etiqueta="[ALERTA] " ;;
    	"menu")	    color="$CIAN_B";    etiqueta="[MENU] " ;;
    	"prompt")   color="$MAGENTA_B"; etiqueta="[PREGUNTA] " ;;
    	*)          color="$NC";        etiqueta="" ;;
	esac

	# 2. Guardar silenciosamente en el log con su marca de tiempo
	#local marca_tiempo="[$(date --iso-8601=seconds)]"
	#echo "$marca_tiempo ${etiqueta}${texto}" >> "$logfile"

	# 3. Enviar el texto con color a la pantalla
    if [[ $salto -eq 0 ]]; then
        # Usamos printf en vez de echo para que funcione correctamente dentro de $(...)
        printf '%b' "${color}${etiqueta}${texto}${NC}"
    else
        if [ "$tipo" = "error" ]; then
            echo -e "${color}${etiqueta}${texto}${NC}" >&2  # Envia al canal de errores
        else
            echo -e "${color}${etiqueta}${texto}${NC}"  	# Envia al canal normal
        fi
    fi
}
# fin pintar


pintar "##################################################INI##################################################"
pintar "Instalación de un entorno LAMP: $HORA_INICIO_HUMANA"
pintar "##################################################INI##################################################"

# ==========================================
# DETECCIÓN DE S.O. Y MAPEO DE PAQUETES
# ==========================================
if [ "$(uname)" == "Darwin" ]; then
    OS="macOS"
    INSTALL_CMD="brew install"
    SUDO=""
    UPDATE_CMD="brew update && brew upgrade"
    APACHE_S="httpd"
    # Mapeo unificado para Mac
    DB_PKGS="mysql"
    PHP_PKGS="php imagemagick" # Brew incluye fpm y extensiones dentro de php
    FZ_PKG="" # Filezilla en mac requiere brew install --cask, lo manejamos aparte
    PMA_PKG="phpmyadmin"  
    APACHE_USER="_www"
    WEB_ROOT="/Users/${USER}/workspace" # En Mac la ruta es /Users/
    WEB_ROOT_DEFAULT="/opt/homebrew/var/www"  
else
    #. /etc/os-release
    #case "$ID" in
    #    linuxmint|ubuntu|debian)
    # 1. Leer el archivo os-release de manera estándar
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "Error: No se pudo encontrar /etc/os-release."
        exit 1
    fi
    
    # 2. Unificar ID e ID_LIKE en una sola cadena en minúsculas para buscar fácilmente
    # Unificar y pasar a minúsculas usando expansión nativa de Bash (sin tuberías)
    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}" # Esto convierte todo el texto a minúsculas al instante

    # 3. Clasificación inteligente por patrones en lugar de coincidencia exacta
    if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
            OS="Debian-based"
            INSTALL_CMD="apt-get install -y"
            SUDO="sudo"
            UPDATE_CMD="apt-get update && apt-get upgrade -y"
            APACHE_S="apache2"
            DB_PKGS="mysql-server mysql-client"
            PHP_PKGS="php php-cli php-common php-fpm php-mysql php-zip php-gd php-mbstring php-curl php-xml php-bcmath imagemagick php-imagick"
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="www-data"
            WEB_ROOT="/home/${USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
        #    ;;
        #fedora|rhel|centos)
    elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
            OS="Fedora-based"
            INSTALL_CMD="dnf install -y"
            SUDO="sudo"
            UPDATE_CMD="dnf upgrade -y"
            APACHE_S="httpd"
            DB_PKGS="mariadb-server" # En Fedora 'mariadb-server' arrastra las herramientas de cliente automáticamente
            PHP_PKGS="php-cli php-fpm php-mysqlnd php-zip php-gd php-mbstring php-curl php-xml php-bcmath imagemagick php-pecl-imagick"
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="apache"
            WEB_ROOT="/home/${USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
        #    ;;
        #arch|manjaro)
    elif [[ "$ALL_IDS" =~ "arch" || "$ALL_IDS" =~ "manjaro" || "$ALL_IDS" =~ "endeavouros" ]]; then
            OS="Arch-based"
            INSTALL_CMD="pacman -S --noconfirm"
            SUDO="sudo"
            UPDATE_CMD="pacman -Syu --noconfirm"
            APACHE_S="httpd"
            DB_PKGS="mariadb mariadb-clients"
            PHP_PKGS="php php-fpm php-gd imagemagick php-imagick" # Arch mete el resto (zip, curl, xml, mbstring) en el núcleo de php
            FZ_PKG="filezilla"
            PMA_PKG="phpmyadmin"
            APACHE_USER="http"
            WEB_ROOT="/home/${USER}/workspace"
            WEB_ROOT_DEFAULT="/srv/http"
        #    ;;
        #opensuse*|suse)
    elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
            OS="SUSE-based"
            INSTALL_CMD="zypper --non-interactive install"
            SUDO="sudo"
            UPDATE_CMD="zypper --non-interactive update"
            APACHE_S="apache2"
            DB_PKGS="mariadb mariadb-client"
            #PHP_PKGS="php8 php8-fpm php8-mysql php8-zip php8-gd php8-mbstring php8-curl php8-xml php8-bcmath ImageMagick php8-imagick"
            PHP_PKGS="apache2-mod_php8 php8 php8-mysql php8-gd php8-mbstring php8-xml php8-zip php8-openssl php8-curl"
            FZ_PKG="filezilla"
            PMA_PKG="phpMyAdmin"
            APACHE_USER="wwwrun"
            WEB_ROOT="/home/${USER}/workspace"
            WEB_ROOT_DEFAULT="/var/www/html"
        #    ;;
        #*)
    else
            echo "Sistema operativo no compatible o no detectado en: $ALL_IDS."
            exit 1
        #    ;;
    #esac
    fi
fi
pintar "OS: $OS"

# === 1. PREGUNTAS INICIALES (Interactivas) ===
# Pregunta 1: Usuario MySQL
echo -ne "$(pintar "¿Desea crear un nuevo usuario de MySQL? [S|n]: " "prompt" 0)"
read -r responder_nuevo_mysql

if [[ "$responder_nuevo_mysql" =~ ^[Ss]$ ]] || [[ -z "$responder_nuevo_mysql" ]]; then
    echo -ne "$(pintar "Introduce el nombre del usuario [admin]: " "prompt" 0)"
    read -r DB_USER
    DB_USER=${DB_USER:-"admin"}
    #[ -z "$DB_USER" ] && DB_USER="admin"

    echo -ne "$(pintar "Introduce la contraseña [admin]: " "prompt" 0)"
    read -r -s DB_PASS   # -s para que no se vea la contraseña al teclear
    echo ""
    DB_PASS=${DB_PASS:-"admin"}
    #[ -z "$DB_PASS" ] && DB_PASS="admin"
fi

# Pregunta 2: ¿Instalar Filezilla?
echo -ne "$(pintar "¿Desea Instalar Filezilla? [S|n]: " "prompt" 0)"
read -r instalar_filezilla


# === 2. EJECUCIÓN DESATENDIDA (A partir de aquí, el usuario puede irse a tomar un café) ===
# [Detección de SO] -> [Instalación de paquetes] -> [Configuración]


# ==========================================
# CONFIGURACIÓN DESATENDIDA DE PHPMYADMIN (Debian/Mint)
# ==========================================
if [ "$OS" == "Debian-based" ]; then
    echo "phpmyadmin phpmyadmin/reconfigure-webconfig select apache2" | $SUDO debconf-set-selections
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean false" | $SUDO debconf-set-selections
    export DEBIAN_FRONTEND=noninteractive
fi

pintar "#######################################################################################################"

# ==========================================
# FLUJO DE TRABAJO (Sin interactividad a partir de aquí)
# ==========================================
pintar "1. Actualizando el sistema..." "menu"
$SUDO sh -c "$UPDATE_CMD"

pintar "2. Instalando Base de Datos ($DB_PKGS)..." "menu"
$SUDO $INSTALL_CMD $DB_PKGS

pintar "3. Instalando Servidor Web Apache ($APACHE_S)..." "menu"
if [ "$OS" == "macOS" ] || [ "$OS" == "Fedora-based" ]; then
    $SUDO $INSTALL_CMD httpd
else
    # En Debian/Mint es apache2, en openSUSE es apache2
    $SUDO $INSTALL_CMD apache2 2>/dev/null || $SUDO $INSTALL_CMD apache
fi

pintar "4. Instalando PHP y extensiones..." "menu"
$SUDO $INSTALL_CMD $PHP_PKGS

pintar "Activando mod_rewrite en Apache..." "menu"
case "$OS" in
    "Debian-based")
        # Método nativo de Debian/Mint
        $SUDO a2enmod rewrite > /dev/null
        ;;
    "Fedora-based")
        # En Fedora viene activado por defecto. 
        # Si quisieras asegurar que no esté comentado en httpd.conf:
        $SUDO sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/httpd/conf/httpd.conf 2>/dev/null || true
        ;;
    "Arch-based")
        # En Arch viene desactivado por defecto en httpd.conf. Lo descomentamos:
        $SUDO sed -i 's/#LoadModule rewrite_module modules\/mod_rewrite.so/LoadModule rewrite_module modules\/mod_rewrite.so/g' /etc/httpd/conf/httpd.conf
        ;;
    "SUSE-based")
        # openSUSE usa su propia herramienta nativa 'a2enmod' (comparte nombre pero sintaxis interna estricta)
        # o puedes editar el archivo /etc/sysconfig/apache2 añadiendo "rewrite" a APACHE_MODULES.
        # El método directo por configuración:
        $SUDO sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/g' /etc/apache2/httpd.conf 2>/dev/null || true
        ;;
    "macOS")
        # En el Apache de Homebrew viene desactivado por defecto. Lo descomentamos:
        sed -i '' 's/#LoadModule rewrite_module modules\/mod_rewrite.so/LoadModule rewrite_module modules\/mod_rewrite.so/g' /opt/homebrew/etc/httpd/httpd.conf
        ;;
esac

pintar "5. Instalando PhpMyAdmin..." "menu"
$SUDO $INSTALL_CMD $PMA_PKG

pintar "Configurando phpMyAdmin con Apache..." "menu"

case "$OS" in
    "Debian-based")
        # Ya lo hace apt automáticamente, solo nos aseguramos de reiniciar
        $SUDO systemctl reload apache2
        ;;

    "Fedora-based")
        # Fedora instala phpmyadmin en /usr/share/phpMyAdmin y crea un archivo en /etc/httpd/conf.d/phpMyAdmin.conf
        # Por defecto viene restringido a localhost. Lo hacemos accesible eliminando las restricciones de IP.
        $SUDO sed -i 's/Require local/Require all granted/g' /etc/httpd/conf.d/phpMyAdmin.conf 2>/dev/null || true
        $SUDO systemctl reload httpd
        ;;
        
    "Arch-based")
        # Arch lo instala en /usr/share/webapps/phpMyAdmin. Creamos un archivo de configuración para Apache.
        ARCH_PMA_CONF="/etc/httpd/conf/extra/httpd-phpmyadmin.conf"
        echo "Alias /phpmyadmin \"/usr/share/webapps/phpMyAdmin\"
<Directory \"/usr/share/webapps/phpMyAdmin\">
    DirectoryIndex index.php
    AllowOverride All
    Options FollowSymlinks
    Require all granted
</Directory>" | $SUDO tee "$ARCH_PMA_CONF" > /dev/null

        # Incluir esta configuración en el httpd.conf principal si no está ya incluido
        if ! grep -q "httpd-phpmyadmin.conf" /etc/httpd/conf/httpd.conf; then
            echo "Include $ARCH_PMA_CONF" | $SUDO tee -a /etc/httpd/conf/httpd.conf > /dev/null
        fi
        $SUDO systemctl restart httpd
        ;;
        
    "SUSE-based")
        # openSUSE lo instala en /usr/share/phpMyAdmin. Creamos el archivo de configuración.
        SUSE_PMA_CONF="/etc/apache2/conf.d/phpmyadmin.conf"
        echo "Alias /phpmyadmin \"/usr/share/phpMyAdmin\"
<Directory \"/usr/share/phpMyAdmin\">
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
</Directory>" | $SUDO tee "$SUSE_PMA_CONF" > /dev/null
        $SUDO systemctl restart apache2
        ;;
        
    "macOS")
        # Homebrew instala phpmyadmin en /opt/homebrew/share/phpmyadmin.
        # Lo enlazamos creando un Alias en el archivo de configuración de VHosts o Httpd.
        MAC_PMA_CONF="/opt/homebrew/etc/httpd/extra/httpd-phpmyadmin.conf"
        echo "Alias /phpmyadmin \"/opt/homebrew/share/phpmyadmin\"
<Directory \"/opt/homebrew/share/phpmyadmin\">
    DirectoryIndex index.php
    AllowOverride All
    Require all granted
</Directory>" | $SUDO tee "$MAC_PMA_CONF" > /dev/null

        if ! grep -q "httpd-phpmyadmin.conf" /opt/homebrew/etc/httpd/httpd.conf; then
            echo "Include $MAC_PMA_CONF" | $SUDO tee -a /opt/homebrew/etc/httpd/httpd.conf > /dev/null
        fi
        brew services restart httpd
        ;;
esac

pintar "phpMyAdmin enlazado correctamente. Accesible en http://localhost/phpmyadmin" "exito"


pintar "6. Instalando Filezilla..." "menu"
if [[ "$instalar_filezilla" =~ ^[nN]$ ]]; then
    pintar "Ha decidido no instalar FileZilla" "alerta"
else
    if [ "$OS" == "macOS" ]; then
        brew install --cask filezilla
    fi
    # Si es Linux y la variable FZ_PKG no está vacía, se instala
    if [ "$OS" != "macOS" ] && [ -n "$FZ_PKG" ]; then
        $SUDO $INSTALL_CMD $FZ_PKG
    fi
fi

pintar "7. Activando e iniciando servicios..." "menu"
if [ "$OS" == "macOS" ]; then
    brew services start $APACHE_S
    brew services start mysql
else
    # Inicialización especial para MariaDB en Arch Linux (requerido antes de arrancar)
    if [ "$OS" == "Arch-based" ]; then
        $SUDO mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql > /dev/null
    fi
    $SUDO systemctl enable --now $APACHE_S
    # 🛡️ Mapeo de seguridad para evitar fallos de servicio en Fedora/Arch/Suse
    if [ "$OS" == "Debian-based" ]; then SYS_MYSQL="mysql"; else SYS_MYSQL="mariadb"; fi
    $SUDO systemctl enable --now $SYS_MYSQL # Usa 'mysql' o 'mariadb' según corresponda
fi

pintar "Configurando permisos del espacio de trabajo..." "menu"
# 1. Crear el directorio workspace si no existe
#mkdir -p "$WEB_ROOT/prueba"
mkdir -p "$WEB_ROOT"

# 2. Añadir el usuario de Apache al grupo del usuario actual (Excepción para macOS)
if [ "$OS" == "macOS" ]; then
    # En macOS se usa dseditgroup para gestionar grupos del sistema
    $SUDO dseditgroup -o edit -a "$APACHE_USER" -t user "$USER"
    $SUDO chmod 750 "/Users/${USER}"
else
    # En Linux usamos el clásico usermod
    $SUDO usermod -aG "$USER" "$APACHE_USER"
    $SUDO chmod 750 "/home/${USER}"
fi

$SUDO chmod 755 "$WEB_ROOT"
#$SUDO chmod -R 755 "$WEB_ROOT/prueba"

# 3. Forzar a que tu usuario siga siendo el dueño absoluto de los archivos
#$SUDO chown -R "${USER}:" "$WEB_ROOT" # El ":" al final de USER asigna automáticamente su grupo principal

# Corrección de políticas de seguridad para Fedora (SELinux)
if [ "$OS" == "Fedora-based" ]; then
    $SUDO setsebool -P httpd_enable_homedirs 1 2>/dev/null || true
    $SUDO chcon -R -t httpd_sys_content_t "$WEB_ROOT" 2>/dev/null || true
fi

DB_NAME="prueba_db" # Definimos el nombre para el entorno de test
# Creación desatendida del usuario MySQL
if [[ "$responder_nuevo_mysql" =~ ^[Ss]$ ]] || [[ -z "$responder_nuevo_mysql" ]]; then
    pintar "Creando usuario de MySQL: $DB_USER..." "menu"
    
    # Consulta SQL adaptable que crea el usuario y la base de datos de prueba
    MYSQL_QL="CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'; 
              GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;
              CREATE DATABASE IF NOT EXISTS $DB_NAME;
              GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
              USE $DB_NAME;
              CREATE TABLE IF NOT EXISTS mensajes (id INT AUTO_INCREMENT PRIMARY KEY, texto VARCHAR(255) NOT NULL);
              INSERT INTO mensajes (texto) SELECT '¡Conexión a MySQL exitosa desde PHP PDO!' WHERE NOT EXISTS (SELECT 1 FROM mensajes); 
              FLUSH PRIVILEGES;"
    
    if [ "$OS" == "macOS" ]; then
        mysql -u root -e "$MYSQL_QL"
    else
        $SUDO mysql -u root -e "$MYSQL_QL"
    fi
    pintar "Usuario MySQL '$DB_USER' creado correctamente." "exito"
else
    # 🛡️ PROTECCIÓN MULTIPLATAFORMA PARA LA EXTRACCIÓN DE CLAVES
    if [ "$OS" == "Debian-based" ]; then
        CONFIG_FILE="/etc/phpmyadmin/config-db.php"
        PMA_USER=$($SUDO grep "\$dbuser=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")
        PMA_FILE_PASS=$($SUDO grep "\$dbpass=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")
        DB_USER="$PMA_USER"
        DB_PASS="$PMA_FILE_PASS"
        
        # 🔑 SOLUCIÓN PARA DEBIAN: Le damos permiso al usuario extraído sobre la DB de pruebas
        MYSQL_QL="CREATE DATABASE IF NOT EXISTS $DB_NAME;
                  GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
                  USE $DB_NAME;
                  CREATE TABLE IF NOT EXISTS mensajes (id INT AUTO_INCREMENT PRIMARY KEY, texto VARCHAR(255) NOT NULL);
                  INSERT INTO mensajes (texto) SELECT '¡Conexión a MySQL exitosa desde PHP PDO!' WHERE NOT EXISTS (SELECT 1 FROM mensajes); 
                  FLUSH PRIVILEGES;"
    else
        # En Fedora, Arch, Suse y Mac, entramos como root (que tiene control total)
        DB_USER="root"
        DB_PASS=""

        # 🚀 CREAR USUARIO PRIMERO Y LUEGO OTORGAR PRIVILEGE (Obligatorio en MariaDB moderna)
        $SUDO mysql -u root -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
        $SUDO mysql -u root -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
        $SUDO mysql -u root -e "FLUSH PRIVILEGES;"

        MYSQL_QL="CREATE DATABASE IF NOT EXISTS $DB_NAME;
                  USE $DB_NAME;
                  CREATE TABLE IF NOT EXISTS mensajes (id INT AUTO_INCREMENT PRIMARY KEY, texto VARCHAR(255) NOT NULL);
                  INSERT INTO mensajes (texto) SELECT '¡Conexión a MySQL exitosa desde PHP PDO!' WHERE NOT EXISTS (SELECT 1 FROM mensajes); 
                  FLUSH PRIVILEGES;"
    fi
    
    pintar "No ha creado nuevo usuario. Se usarán las credenciales por defecto ($DB_USER)." "alerta"
    
    if [ "$OS" == "macOS" ]; then
        mysql -u root -e "$MYSQL_QL"
    else
        $SUDO mysql -u root -e "$MYSQL_QL"
    fi
    pintar "Base de datos y tabla '$DB_NAME' creadas correctamente." "exito"
fi

DIR_PRUEBA="$WEB_ROOT/prueba"
if [ -d "$DIR_PRUEBA" ]; then
    pintar "Ya existe $DIR_PRUEBA, no lo creamos." "alerta"
else
    pintar "7. Configurando Host de prueba (prueba.test)..." "menu"
    
    # Definir rutas según S.O.
    case "$OS" in
        "macOS")        CONF_DIR="/opt/homebrew/etc/httpd/extra" ;;
        "Arch-based")   CONF_DIR="/etc/httpd/conf/extra" ;;
        "Fedora-based") CONF_DIR="/etc/httpd/conf.d" ;;
        "SUSE-based") CONF_DIR="/etc/apache2/vhosts.d" ;;
        *)              CONF_DIR="/etc/apache2/sites-available" ;;
    esac

    # Crear directorio del proyecto de prueba
    $SUDO mkdir -p "$DIR_PRUEBA"
    
    # Configuración del VHost estándar con permisos explícitos de directorio heredados
    if [ "$OS" = "SUSE-based" ]; then
        VHOST_CONF="<VirtualHost *:80>
        ServerName prueba.test
        DocumentRoot \"$DIR_PRUEBA\"
        <Directory \"$DIR_PRUEBA\">
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>"
    else
        VHOST_CONF="<VirtualHost *:80>
        ServerName prueba.test
        DocumentRoot \"$DIR_PRUEBA\"
        <Directory \"$DIR_PRUEBA\">
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>
    </VirtualHost>"
    fi

    # Guardar configuración y activarla de forma automatizada
    if [ "$OS" == "Debian-based" ]; then
        echo "$VHOST_CONF" | $SUDO tee "$CONF_DIR/prueba.conf" > /dev/null
        $SUDO a2ensite prueba.conf > /dev/null
        $SUDO systemctl reload apache2
    elif [ "$OS" == "Fedora-based" ] || [ "$OS" == "SUSE-based" ]; then
        echo "$VHOST_CONF" | $SUDO tee "$CONF_DIR/prueba.conf" > /dev/null
        $SUDO systemctl reload $APACHE_S
    else
        # 🚀 MEJORA ABSOLUTA PARA ARCH Y MAC:
        # Si es Arch, vaciamos el archivo de ejemplos dummy.conf para evitar que bloquee el puerto 80 con un 403
        if [ "$OS" == "Arch-based" ]; then
            echo -e "$VHOST_CONF" | $SUDO tee "$CONF_DIR/httpd-vhosts.conf" > /dev/null
            CONF_MASTER="/etc/httpd/conf/httpd.conf"
            
            # Activación de Virtual Hosts nativos y proxies
            $SUDO sed -i 's|#Include conf/extra/httpd-vhosts.conf|Include conf/extra/httpd-vhosts.conf|g' "$CONF_MASTER"
            $SUDO sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' "$CONF_MASTER"
            $SUDO sed -i 's|#LoadModule proxy_module modules/mod_proxy.so|LoadModule proxy_module modules/mod_proxy.so|g' "$CONF_MASTER"
            $SUDO sed -i 's|#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|g' "$CONF_MASTER"
            
            # Limpiar rastro de inserciones previas
            $SUDO sed -i '/proxy:fcgi/d' "$CONF_MASTER"
            $SUDO sed -i '/proxy:unix/d' "$CONF_MASTER"
            $SUDO sed -i '/<FilesMatch/d' "$CONF_MASTER"
            $SUDO sed -i '/<\/FilesMatch>/d' "$CONF_MASTER"

            # 🚀 INYECCIÓN MODERNA CORREGIDA PARA ARCH (Uso de socket Unix local)
            echo -e "\n<FilesMatch \\.php$>\n    SetHandler \"proxy:unix:/run/php-fpm/php-fpm.sock|fcgi://localhost\"\n</FilesMatch>" | $SUDO tee -a "$CONF_MASTER" > /dev/null

            # Parche de seguridad para el Home en Systemd
            $SUDO mkdir -p /etc/systemd/system/httpd.service.d
            echo -e "[Service]\nProtectHome=false" | $SUDO tee /etc/systemd/system/httpd.service.d/override.conf > /dev/null
            
            # Recargar y arrancar los dos servicios en paralelo
            $SUDO systemctl daemon-reload
            $SUDO systemctl enable --now php-fpm

            # 🚀 PARCHE DE COMPATIBILIDAD PHP DRIVER PARA ARCH:
            # Habilitar la extensión PDO MySQL dentro del archivo maestro php.ini
            $SUDO sed -i 's/;extension=pdo_mysql/extension=pdo_mysql/g' /etc/php/php.ini
            
            # Recargar el motor para aplicar los drivers cargados
            $SUDO systemctl restart php-fpm >/dev/null 2>&1
        else
            # Para macOS mantenemos la inserción al final estándar
            if ! grep -q "prueba.test" "$CONF_DIR/httpd-vhosts.conf" 2>/dev/null; then
                echo -e "\n$VHOST_CONF" | $SUDO tee -a "$CONF_DIR/httpd-vhosts.conf" > /dev/null
            fi
        fi
        [ "$OS" == "macOS" ] && brew services restart $APACHE_S || $SUDO systemctl restart $APACHE_S
    fi

    # Añadir de forma desatendida al archivo hosts local para que resuelva el dominio
    if ! grep -q "prueba.test" /etc/hosts; then
        echo "127.0.0.1  prueba.test" | $SUDO tee -a /etc/hosts > /dev/null
    fi

    # generar phpinfo()
    echo "<?php echo '<h1>¡LAMP Multiplataforma Funciona!</h1>'; phpinfo(); ?>" | $SUDO tee "$DIR_PRUEBA/info.php" > /dev/null

    # Comprobación de interacción con base de datos

    
    # Añadir el código HTML y PHP al archivo de forma limpia
    $SUDO tee "$DIR_PRUEBA/index.php" > /dev/null << EOF
<?php
\$host = 'localhost';
\$db = '${DB_NAME}';
\$user = '${DB_USER}';
\$pass = '${DB_PASS}';

try {
    \$dsn = "mysql:host=\$host;dbname=\$db;charset=utf8mb4";
    \$options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];
    \$pdo = new PDO(\$dsn, \$user, \$pass, \$options);

    // Consultar el mensaje en la base de datos
    \$stmt = \$pdo->query('SELECT texto FROM mensajes LIMIT 1');
    \$fila = \$stmt->fetch();
    \$mensaje = \$fila ? \$fila['texto'] : 'No se encontraron mensajes.';
} catch (\PDOException \$e) {
    \$mensaje = "Error de conexión: " . \$e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entorno de Desarrollo - Prueba</title>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f4f4f9; margin: 0; }
        .card { background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }
        h1 { color: #333; }
        p { color: #666; font-size: 1.2rem; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Resultado del Test</h1>
        <p><?php echo htmlspecialchars(\$mensaje); ?></p>
    </div>
</body>
</html>
EOF
    # 🚀 CORRECCIÓN DE USUARIO: Obtener de forma segura el usuario real que lanzó el script
    REAL_USER=${SUDO_USER:-$USER}

    # Aplicar propiedad según la distribución para garantizar el código 200 OK
    if [ "$OS" = "SUSE-based" ]; then
        # 1. Forzar permisos de paso unix tradicionales
        $SUDO chmod 755 "/home/${REAL_USER}"
        $SUDO chmod 755 "$WEB_ROOT"
        $SUDO chmod -R 755 "$DIR_PRUEBA"
        $SUDO chown -R "${REAL_USER}:${APACHE_USER}" "$DIR_PRUEBA"

        # 2. 🛡️ PARCHE SELINUX (Exclusivo openSUSE Leap 16+)
        # Permitir globalmente a Apache leer contenidos en los directorios "home"
        if command -v setsebool >/dev/null 2>&1; then
            $SUDO setsebool -P httpd_enable_homedirs on 2>/dev/null
            
            # Asignar el contexto de seguridad web correcto de manera recursiva a tu carpeta de desarrollo
            $SUDO chcon -R -t httpd_user_content_t "$DIR_PRUEBA" 2>/dev/null
        fi
        
        # Activar el uso de PHP y el módulo de reescritura en la carga de Apache
        $SUDO a2enmod php8 2>/dev/null
        $SUDO a2enmod rewrite 2>/dev/null
        
        # Permitir el paso de Apache al directorio /home en la configuración global
        $SUDO sed -i 's/<Directory \/>/& \n    Require all granted/' /etc/apache2/httpd.conf 2>/dev/null

        # 3. Mover el VHost a la ubicación nativa de SUSE
        # Asegúrate de que el script cree el vhost en vhosts.d/ en lugar de conf.d/ o sites-available/
        $SUDO mkdir -p /etc/apache2/vhosts.d
        echo "$VHOST_CONF" | $SUDO tee /etc/apache2/vhosts.d/prueba.conf > /dev/null
        
        # Reiniciar Apache para asimilar el contexto de SELinux
        $SUDO systemctl restart apache2
    else
        # Forzar el permiso de paso (+x) en las carpetas superiores para evitar el bloqueo del servicio Apache
        $SUDO chmod 755 "/home/${REAL_USER}" 2>/dev/null
        $SUDO chmod 755 "$WEB_ROOT" 2>/dev/null
        # Asegurar lectura completa al directorio del proyecto de pruebas
        $SUDO chmod -R 755 "$DIR_PRUEBA"
        $SUDO chown -R "${REAL_USER}:" "$DIR_PRUEBA"
    fi

    pintar "Host de prueba configurado en http://prueba.test" "exito"

fi

# ==============================================================================
# 🏁 SECCIÓN FINAL: REINICIO DE COMPROBACIÓN, LIMPIEZA Y CÁLCULO DE TIEMPOS
# ==============================================================================

pintar "Aplicando reinicio de seguridad a los servicios..." "menu"

# Reinicio final automatizado según el Sistema Operativo
if [ "$OS" == "macOS" ]; then
    brew services restart $APACHE_S > /dev/null 2>&1
    brew services restart mysql > /dev/null 2>&1
else
    $SUDO systemctl restart $APACHE_S > /dev/null 2>&1
    if [ "$OS" == "Debian-based" ]; then SYS_MYSQL="mysql"; else SYS_MYSQL="mariadb"; fi
    $SUDO systemctl restart $SYS_MYSQL > /dev/null 2>&1
fi

# ==============================================================================
# 🔍 COMPROBACIÓN AUTOMÁTICA DE CONECTIVIDAD
# ==============================================================================
pintar " Verificando conectividad del host de prueba y la base de datos..." " menu"

sleep 2
TEST_URL="http://prueba.test"
CODIGO_HTTP=0
RESPUESTA_HTTP=""

if command -v curl >/dev/null 2>&1; then
    # Prueba utilizando curl
    RESPUESTA_HTTP=$(curl -s -L --connect-timeout 5 "$TEST_URL")
    CODIGO_HTTP=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TEST_URL")

elif command -v wget >/dev/null 2>&1; then
    # Prueba utilizando wget (guarda la salida en una variable y captura el código)
    RESPUESTA_HTTP=$(wget -qO- --timeout=5 "$TEST_URL" 2>/dev/null)
    # Wget no extrae el código HTTP fácilmente, lo simulamos validando si la respuesta tiene contenido
    if [ -n "$RESPUESTA_HTTP" ]; then CODIGO_HTTP=200; fi

else
    pintar " No se pudo realizar la prueba automática (ni curl ni wget están instalados)." "alerta"
fi

# Validar los resultados si alguna de las herramientas funcionó
if [ "$CODIGO_HTTP" -eq 200 ]; then
    if [[ "$RESPUESTA_HTTP" =~ "Conexión a MySQL exitosa" ]]; then
        pintar " ¡Test de conectividad superado con éxito!" " exito"
    else
        pintar " Servidor web activo, pero hay un problema de conexión con MySQL." "error"
    fi
elif [ "$CODIGO_HTTP" -ne 0 ]; then
    pintar " Error de conexión al host de prueba (Código HTTP: $CODIGO_HTTP)." "error"
fi


# ⏱️ CÁLCULO DEL TIEMPO TOTAL TRANSCURRIDO
# Tomamos los segundos acumulados en la variable interna $SECONDS
#tiempo_total=$SECONDS
SEGUNDOS_FIN=$(date +"%s")
tiempo_total=$((SEGUNDOS_FIN - SEGUNDOS_INICIO))

horas=$((tiempo_total / 3600))
minutos=$(( (tiempo_total % 3600) / 60 ))
segundos=$((tiempo_total % 60))

# Formatear el mensaje de tiempo de ejecución
if [ $horas -gt 0 ]; then
    texto_tiempo="${horas}h ${minutos}m ${segundos}s"
elif [ $minutos -gt 0 ]; then
    texto_tiempo="${minutos}m ${segundos}s"
else
    texto_tiempo="${segundos}s"
fi


# 🎉 MENSAJE FINAL DE ÉXITO ESTILO ORIGINAL
echo ""
pintar "=========================================================================" "exito"
pintar "       ¡ENHORABUENA! INSTALACIÓN DEL ENTORNO LAMP FINALIZADA             " "exito"
pintar "=========================================================================" "exito"
echo ""
pintar "⏱️  Tiempo total de instalación desatendida: $texto_tiempo" "exito"
pintar "📝 El registro completo se ha guardado en: $LOG_FILE" "exito"
echo ""
pintar "🌐 Entornos web listos para su uso:" "menu"
pintar "   - Servidor de pruebas: http://prueba.test" "menu"
pintar "   - Administrador de DB: http://localhost/phpmyadmin" "menu"
echo ""
if [[ "$responder_nuevo_mysql" =~ ^[Ss]$ ]] || [[ -z "$responder_nuevo_mysql" ]]; then
    pintar "🐬 Credenciales MySQL creadas:" "alerta"
    pintar "   - Base de datos: $DB_NAME" "alerta"
    pintar "   - Usuario:       $DB_USER" "alerta"
    pintar "   - Contraseña:    (La que has introducido al principio)" "alerta"
else
    pintar "🐬 Credenciales MySQL por defecto:" "alerta"
    pintar "   - Usuario:       $DB_USER" "alerta"
    if [ "$OS" == "Debian-based" ]; then
        pintar "   - Contraseña:    (Extraída automáticamente de phpMyAdmin)" "alerta"
    else
        pintar "   - Contraseña:    (Sin contraseña por defecto en el sistema)" "alerta"
    fi
fi
echo ""
pintar "🚀 Todo listo. Ya puedes empezar a desarrollar." "exito"
echo ""

pintar "#######################################################################################################"

# Restaurar los canales de salida estándar originales (cerrando el volcado directo de tee)
exec 1>&3 2>&4
