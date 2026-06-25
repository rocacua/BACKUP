#!/bin/bash
SEGUNDOS_INICIO=$(date +"%s")
HORA_INICIO_HUMANA=$(date +%H:%M:%S)

# ==========================================
# 📋 CONFIGURACIÓN DEL LOG AUTOMÁTICO
# ==========================================
declare -r DIR_SCRIPT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
fecha=$(date +%Y-%m-%d_%H-%M-%S)

LOG_DIR="$DIR_SCRIPT/logs"
LOG_FILE="$LOG_DIR/instalador_ide-${fecha}.log"

if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null
fi

if [[ ! -w "$LOG_DIR" ]]; then
    LOG_DIR="$HOME"
    LOG_FILE="$LOG_DIR/instalador_ide-${fecha}.log"
    mkdir -p "$LOG_DIR" 2>/dev/null
fi

# Duplicar salida a la pantalla y al archivo log
exec 3>&1 4>&2
exec > >(tee -i "$LOG_FILE") 2>&1
echo "📝 Grabando registro en: $LOG_FILE"

# Colores ANSI
ROJO=$'\e[31m'
VERDE=$'\e[32m'
AZUL=$'\e[34m'
CIAN=$'\e[36m'
AMARILLO=$'\e[33m'
MAGENTA=$'\033[0;35m'
NC=$'\e[0m'
ROJO_B=$'\e[1;31m'
VERDE_B=$'\e[1;32m'
CIAN_B=$'\e[1;36m'
AMARILLO_B=$'\e[1;33m'
MAGENTA_B=$'\033[1;35m'

# Variables globales para almacenar el estado detectado
declare -A ENTORNOS_INSTALABLES
instalado_git="n"
instalado_apache="n"
instalado_java="n"
instalado_donet="n"
instalado_node="n"
instalado_python="n"


# ==========================================
# 🛠️ FUNCIONES AUXILIARES
# ==========================================
pintar() {
    local texto="$1"
    local tipo="${2:-normal}"
    local salto="${3:-1}"
    local color=""
    local etiqueta=""

    case "$tipo" in
        "error")    color="$ROJO";      etiqueta="[ERROR] " ;;
        "exito")    color="$VERDE";     etiqueta="[OK] " ;;
        "alerta")   color="$AMARILLO";  etiqueta="[ALERTA] " ;;
        "menu")     color="$CIAN_B";    etiqueta="[MENU] " ;;
        "prompt")   color="$MAGENTA_B"; etiqueta="[PREGUNTA] " ;;
        *)          color="$NC";        etiqueta="" ;;
    esac

    if [[ $salto -eq 0 ]]; then
        printf '%b' "${color}${etiqueta}${texto}${NC}"
    else
        if [ "$tipo" = "error" ]; then
            echo -e "${color}${etiqueta}${texto}${NC}" >&2
        else
            echo -e "${color}${etiqueta}${texto}${NC}"
        fi
    fi
}

obtener_espacio_libre_gb() {
    local ruta="$1"
    if command -v df &> /dev/null; then
        df --output=avail -BG "$ruta" | tail -n 1 | tr -d '[:space:]' | tr -d 'G'
    else
        echo "20" # Valor seguro de contingencia si falla df
    fi
}
obtener_ram_max_mb() {
    if [ "$(uname)" = "Darwin" ]; then
        local ram_bytes=$(sysctl -n hw.memsize)
        echo $((ram_bytes / 1024 / 1024))
    else
        echo $(free -m | grep Mem | awk '{print $2}')
    fi
}
obtener_hardware() {
    # CORRECCIÓN: Llamada correcta a la función usando sustitución de comandos $()
    libre_gb=$(obtener_espacio_libre_gb "$HOME")
    pintar "Espacio libre en Home: ${libre_gb} GB"

    # Mapeo de RAM compatible con Linux y macOS de forma nativa
    ram_max=$(obtener_ram_max_mb)
    pintar "Memoria RAM total del sistema: ${ram_max} MB"

    # Clasificación del hardware del usuario
    PERFIL_HARDWARE="Alto"
    if [ "$ram_max" -lt 4000 ] || [ "$libre_gb" -lt 10 ]; then
        PERFIL_HARDWARE="Bajo"
    elif [ "$ram_max" -lt 8000 ] || [ "$libre_gb" -lt 25 ]; then
        PERFIL_HARDWARE="Medio"
    fi
    pintar "Perfil de Hardware estimado: $PERFIL_HARDWARE" "alerta"
    APTO_IA_LOCAL="NO"
    if [ "$ram_max" -ge 8000 ]; then
        APTO_IA_LOCAL="SI" # Recomendado 8GB+
    elif [ "$ram_max" -ge 4000 ]; then
        APTO_IA_LOCAL="MINIMO" # 4GB-8GB con cautela
    fi
    pintar "Hardware apto para instalar IA local: $APTO_IA_LOCAL" "alerta"
}

instalar_via_snap() {
    local snap_pkg="$1"

    # 1. Si snap ya está instalado, procedemos directo
    if command -v snap &> /dev/null; then 
        sudo snap install "$snap_pkg" --classic
        return 0
    fi

    # 2. Si no está instalado, procedemos a configurarlo e instalarlo según el S.O.
    pintar "📦 El motor de Snaps no está disponible. Instalándolo en caliente..." "alerta"
    
    if [ "$OS" = "Debian-based" ]; then
        sudo apt-get update && sudo apt-get install -y snapd
        sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null

    elif [ "$OS" = "Fedora-based" ]; then
        sudo dnf install -y snapd
        sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null

    elif [ "$OS" = "SUSE-based" ]; then
        # openSUSE requiere añadir su repositorio oficial adaptándose dinámicamente a tu versión actual
        local suse_ver="${VERSION_ID:-15.6}"
        #sudo zypper --non-interactive addrepo --refresh "https://opensuse.org{suse_ver}/" snappy 2>/dev/null
        sudo zypper --non-interactive addrepo --refresh "https://download.opensuse.org/repositories/system:/snappy/openSUSE_Leap_${suse_ver}" snappy 2>/dev/null
        sudo zypper --gpg-auto-import-keys refresh
        sudo zypper --non-interactive install snapd
        sudo systemctl enable --now snapd snapd.apparmor

    else
        pintar "❌ Snap no está disponible ni se puede auto-instalar de forma segura en: $OS." "error"
        pintar "Por favor, instale '$snap_pkg' manualmente a través de sus canales nativos." "alerta"
        exit 1
    fi

    # Dar 3 segundos para que los sockets del demonio recién instalado inicien en el procesador
    sleep 3

    # 3. Intentar instalar el paquete ahora que el motor Snap está activo
    pintar "➜ Instalando $snap_pkg de forma universal a través de Snap..." "menu"
    sudo snap install "$snap_pkg" --classic
    
    if [ $? -ne 0 ]; then
        pintar "❌ Error crítico: No se pudo instalar '$snap_pkg' incluso utilizando la contingencia de Snap." "error"
        exit 1
    fi
}
intentar_instalacion() {
    local cmd_nativo="$1"
    local snap_pkg="$2"
    
    # 1. Ejecutar de forma explícita usando sudo para asegurar privilegios
    sudo $cmd_nativo
    
    # 2. Capturar el código de retorno. Si falla, llamamos a nuestro rescatador modular
    if [ $? -ne 0 ]; then
        pintar "⚠️ La instalación nativa falló o el repositorio no respondió. Recurriendo a Snap..." "alerta"
        
        # Delegar el control por completo en la función anterior
        instalar_via_snap "$snap_pkg"
        
        # Si la función anterior no abortó el script, significa que tuvo éxito vía Snap
        COMANDO_ARRANQUE="snap run $snap_pkg"
    fi
}

detectar_dependencias() {
    pintar "➜ Analizando dependencias globales de desarrollo..." "menu"
    
    # HTTPD / Apache
    if [ "$OS" = "macOS" ]; then
        command -v httpd &> /dev/null && instalado_apache="s"
    else
        (command -v apache2 &> /dev/null || command -v httpd &> /dev/null) && instalado_apache="s"
    fi
    [ "$instalado_apache" = "s" ] && pintar "Servidor Apache detectado." "alerta"

    # Java JDK
    if command -v java &> /dev/null || [ -n "$JAVA_HOME" ]; then
        instalado_java="s"
        pintar "Entorno de Java (JDK) detectado." "alerta"
    fi

    # .NET Framework / Core
    if command -v dotnet &> /dev/null; then
        instalado_donet="s"
        pintar "Ecosistema .NET SDK detectado." "alerta"
    fi

    # Git
    if command -v git &> /dev/null; then
        instalado_git="s"
        pintar "Git detectado en el sistema." "alerta"
    fi

    # Node
    if command -v node &> /dev/null || command -v npm &> /dev/null; then
        instalado_node="s"
        pintar "Entorno de NodeJS detectado." "alerta"
    fi

    # Python
    if command -v python3 &> /dev/null || command -v pip3 &> /dev/null; then
        instalado_python="s"
        pintar "Entorno de Python3 detectado." "alerta"
    fi

    # PHP CLI (Añadir al final de la función detectar_dependencias)
    if command -v php &> /dev/null; then
        instalado_php_cli="s"
        pintar "Intérprete de PHP detectado." "alerta"
    else
        instalado_php_cli="n"
        pintar "❌ PHP no está instalado en el sistema. Los entornos PHP fallarán." "error"
        # Contingencia opcional: Autoinstalar si estamos en Fedora/Debian
        if [ "$OS" = "Fedora-based" ]; then
            pintar "➜ Instalando PHP y extensiones críticas para Fedora..." "menu"
            $SUDO $INSTALL_CMD php php-cli php-mysqlnd php-gd php-xml php-mbstring php-json -y
        elif [ "$OS" = "Debian-based" ]; then
            pintar "➜ Instalando PHP y extensiones críticas para Debian/Ubuntu..." "menu"
            $SUDO apt-get update && $SUDO apt-get install -y php-cli php-mysql php-gd php-xml php-mbstring
        fi
    fi

}

aconsejar_cms() {
    local sugerencia=""
    local motivo=""

    # Lógica de recomendación cruzando Hardware + Entornos viables
    if [ "$PERFIL_HARDWARE" = "Bajo" ]; then
        if [ "$instalado_apache" = "s" ]; then
            sugerencia="CodeIgniter o WordPress"
            motivo="Tu hardware es limitado. CodeIgniter es extremadamente ligero y WordPress funciona bien en entornos de bajos recursos sin compilaciones pesadas."
        else
            sugerencia="Python (Flask / Scripts nativos)"
            motivo="No detectamos Apache. Python te permitirá levantar servidores mínimos de desarrollo sin penalizar la memoria RAM ni el disco."
        fi
    else
        # Perfil Medio / Alto: Recomendaciones según dependencias detectadas
        if [ "$instalado_node" = "s" ] && [ "$instalado_apache" = "s" ]; then
            sugerencia="Laravel (con React/Vite) o Symfony"
            motivo="Dispones de hardware excelente. Laravel o Symfony te darán una estructura empresarial robusta respaldada por la potencia de NodeJS en el frontend."
        elif [ "$instalado_node" = "s" ]; then
            sugerencia="Node.js (Express) + React"
            motivo="Tienes un entorno idóneo para desarrollo JavaScript Fullstack moderno, aprovechando al máximo tu CPU y RAM libres."
        elif [ "$instalado_apache" = "s" ]; then
            sugerencia="Laravel o WordPress Avanzado"
            motivo="Tu servidor Apache te permite ejecutar de forma óptima los frameworks PHP más potentes del mercado con total fluidez."
        else
            sugerencia="Python / Entorno Dockerizado"
            motivo="Cuentas con buen hardware, pero faltan servidores nativos. Te sugerimos frameworks potentes como Django o dar el salto a contenedores."
        fi
    fi

    echo "------------------------------------------------------------------------------"
    pintar "💡 RECOMENDACIÓN INTELIGENTE:" "exito"
    echo "Basado en tu hardware ($PERFIL_HARDWARE) y tus entornos activos, te aconsejamos usar: $sugerencia"
    echo "Motivo: $motivo"
    echo "------------------------------------------------------------------------------"
}
detectar_entornos_instalables() {
    local entornos_apache=("wordpress" "laminas" "codeigniter" "laravel" "symfony")
    if [[ "$instalado_apache" == "s" ]]; then
        for ide in "${entornos_apache[@]}"; do ENTORNOS_INSTALABLES[$ide]="s"; done
    else
        for ide in "${entornos_apache[@]}"; do ENTORNOS_INSTALABLES[$ide]="n"; done
    fi
    local entornos_node=("react" "node")
    if [[ "$instalado_node" == "s" ]]; then
        for ide in "${entornos_node[@]}"; do ENTORNOS_INSTALABLES[$ide]="s"; done
    else
        for ide in "${entornos_node[@]}"; do ENTORNOS_INSTALABLES[$ide]="n"; done
    fi
    local entornos_python=("python")
    if [[ "$instalado_python" == "s" ]]; then
        for ide in "${entornos_python[@]}"; do ENTORNOS_INSTALABLES[$ide]="s"; done
    else
        for ide in "${entornos_python[@]}"; do ENTORNOS_INSTALABLES[$ide]="n"; done
    fi
}
listar_entornos_instalables() {
    local entornos_id=("wordpress" "laminas" "codeigniter" "laravel" "symfony" "react" "node" "python")
    local entornos_txt=("WordPress" "Láminas" "CodeIgniter" "Laravel" "Symfony" "React JS" "Node JS" "Python")
    for i in "${!entornos_id[@]}"; do
        local id_entorno="${entornos_id[$i]}"
        if [ "${ENTORNOS_INSTALABLES[$id_entorno]}" = "s" ]; then
            echo "$((i+1))) ${entornos_txt[$i]}"
        fi
    done
}
selecciona_entorno() {
    crear_web="n"
    [ "$crear_web_n" -eq 1 ] && crear_web="wordpress"
    [ "$crear_web_n" -eq 2 ] && crear_web="laminas"
    [ "$crear_web_n" -eq 3 ] && crear_web="codeigniter"
    [ "$crear_web_n" -eq 4 ] && crear_web="laravel"
    [ "$crear_web_n" -eq 5 ] && crear_web="symfony"
    [ "$crear_web_n" -eq 6 ] && crear_web="react"
    [ "$crear_web_n" -eq 7 ] && crear_web="node"
    [ "$crear_web_n" -eq 8 ] && crear_web="python"
}

# ==========================================
# 🗄️ CONFIGURACIÓN DE BASE DE DATOS
# ==========================================
pedir_datos_bd() {
    pintar "=== CONFIGURACIÓN DE LA BASE DE DATOS ===" "menu"
    
    read -p "$(pintar "Host de la Base de Datos [localhost]: " "prompt" 0)" db_host
    db_host="${db_host:-localhost}"
    
    read -p "$(pintar "Nombre de la Base de Datos [${crear_web}]: " "prompt" 0)" db_name
    db_name="${db_name:-$crear_web}"
    
    read -p "$(pintar "Usuario de la Base de Datos [root]: " "prompt" 0)" db_user
    db_user="${db_user:-root}"
    
    # Para contraseñas, usamos -s para que no se vea textualmente en la terminal (seguridad)
    echo -n "$(pintar "Contraseña de la Base de Datos (oculta): " "prompt" 0)"
    read -s db_pass
    echo "" # Salto de línea necesario tras usar read -s
}

configurar_vhost_apache() {
    # 1. Mapear el dominio local en /etc/hosts
    # Extraemos el host limpio de la URL (ej: de 'http://wordpress.test' saca 'wordpress.test')
    local dominio_limpio=$(echo "$url_web" | sed -e 's/http:\/\///g' -e 's/https:\/\///g' -e 's/\/.*//g')
    
    pintar "➜ Configurando el dominio local en /etc/hosts..." "menu"
    if grep -q "$dominio_limpio" /etc/hosts; then
        pintar "El dominio $dominio_limpio ya estaba registrado en /etc/hosts." "alerta"
    else
        echo "127.0.0.1   $dominio_limpio" | $SUDO tee -a /etc/hosts > /dev/null
        pintar "Dominio $dominio_limpio enlazado correctamente a 127.0.0.1" "exito"
    fi

    # 2. CONFIGURACIÓN DINÁMICA DE VHOST Y PERMISOS SEGÚN S.O.
    pintar "➜ Detectando usuario del servidor web y rutas de Apache..." "menu"
    local web_user=""
    local apache_conf_dir=""
    local restart_cmd=""

    case "$OS" in
        "Debian-based")
            web_user="www-data"
            apache_conf_dir="/etc/apache2/sites-available"
            restart_cmd="sudo systemctl restart apache2"
            ;;
        "Fedora-based"|"SUSE-based")
            web_user="apache"
            apache_conf_dir="/etc/httpd/conf.d"
            restart_cmd="sudo systemctl restart httpd"
            ;;
        "macOS")
            web_user="_www"
            apache_conf_dir="/usr/local/etc/httpd/extra" # O /opt/homebrew si usan MAMP/Brew
            restart_cmd="sudo apachectl restart"
            ;;
    esac

    # Aplicar permisos correctos para desarrollo web local seguro
    if [ ! -z "$web_user" ]; then
        pintar "➜ Ajustando permisos del directorio para el servidor web ($web_user)..." "menu"
        # Asignar grupo del servidor web y permisos de escritura mutuos
        $SUDO chown -R $REAL_USER:$web_user "$path_web"
        find "$path_web" -type d -exec chmod 775 {} \;
        find "$path_web" -type f -exec chmod 664 {} \;
        # wp-config.php un poco más protegido
        [ -f "$path_web/wp-config.php" ] && chmod 660 "$path_web/wp-config.php" 2>/dev/null
    fi

        # Crear y activar el VirtualHost si la ruta de configuración existe
    if [ -d "$apache_conf_dir" ]; then
        pintar "➜ Creando archivo VirtualHost de Apache..." "menu"
        local vhost_file="$apache_conf_dir/${dominio_limpio}.conf"
        
        # DEFINICIÓN DINÁMICA DE LOGS SEGÚN EL S.O.
        local log_dir="/var/log/httpd" # Por defecto en Fedora/RHEL
        if [[ "$OS" = "Debian-based" || "$OS" = "SUSE-based" ]]; then
            log_dir="/var/log/apache2"
        elif [ "$OS" = "macOS" ]; then
            log_dir="/usr/local/var/log/httpd"
        fi

        # Aseguramos que la carpeta de logs exista por si acaso
        $SUDO mkdir -p "$log_dir" 2>/dev/null
        
        # Plantilla corregida sin variables vacías de entorno
        $SUDO tee "$vhost_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $dominio_limpio
    DocumentRoot "$path_web"
    <Directory "$path_web">
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog $log_dir/${dominio_limpio}-error.log
    CustomLog $log_dir/${dominio_limpio}-access.log combined
</VirtualHost>
EOF


        # Habilitar el sitio específicamente en distribuciones tipo Debian/Ubuntu
        if [ "$OS" = "Debian-based" ] && command -v a2ensite &> /dev/null; then
            $SUDO a2ensite "${dominio_limpio}.conf" > /dev/null
            $SUDO a2enmod rewrite > /dev/null
        fi

        # Reiniciar Apache para aplicar cambios
        pintar "➜ Reiniciando el servidor Apache para aplicar el VHost..." "menu"
        # Reiniciar Apache para aplicar cambios (Aseguramos que esté activo y habilitado)
        pintar "➜ Asegurando que el servidor Apache esté activo..." "menu"
        if [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ]; then
            $SUDO systemctl enable --now httpd
            $SUDO systemctl restart httpd
            
            # PARCHE FIREWALL: Abrir puerto 80 de forma permanente en Fedora si firewalld está activo
            if command -v firewall-cmd &> /dev/null; then
                $SUDO firewall-cmd --permanent --add-service=http &>/dev/null
                $SUDO firewall-cmd --reload &>/dev/null
            fi

            # PARCHE SELINUX: Permitir a Apache leer/escribir en tu directorio del HOME
            if command -v chcon &> /dev/null; then
                pintar "➜ Ajustando políticas de SELinux para la ruta del proyecto..." "menu"
                $SUDO chcon -R -t httpd_sys_rw_content_t "$path_web" 2>/dev/null
                # Permitir a Apache navegar a través de las carpetas padre del HOME
                $SUDO setsebool -P httpd_enable_homedirs 1 2>/dev/null
                # Permitir que Apache se conecte a bases de datos (Crucial para Fedora/RHEL)
                #$SUDO setsebool -P httpd_can_network_connect_db 1 2>/dev/null
                # PARCHE CRÍTICO PARA FRAMEWORKS (Laravel/Symfony): Permitir a Apache usar el directorio /tmp del sistema
                if [ "$OS" = "Fedora-based" ] && command -v setsebool &> /dev/null; then
                    $SUDO setsebool -P httpd_tmp_exec 1 2>/dev/null
                    $SUDO setsebool -P httpd_enable_homedirs 1 2>/dev/null
                fi
            fi
        else
            $restart_cmd &> /dev/null
        fi
        pintar "VirtualHost configurado y Apache reiniciado." "exito"

        pintar "VirtualHost configurado y Apache reiniciado." "exito"
    else
        pintar "No se encontró el directorio de configuración de Apache ($apache_conf_dir). El VHost debe crearse manualmente." "alerta"
    fi
}

# ==========================================
# 🏗️ GENERADORES DE ENTORNOS ESPECÍFICOS
# ==========================================

crear_wordpress() {
    # Solicitamos datos mínimos para el administrador de la web
    echo ""
    pintar "=== CONFIGURACIÓN DEL ADMINISTRADOR DE WORDPRESS ===" "menu"
    read -p "$(pintar "Email del administrador [admin@${crear_web}.test]: " "prompt" 0)" wp_email
    wp_email="${wp_email:-admin@${crear_web}.test}"
    
    read -p "$(pintar "Usuario administrador [admin]: " "prompt" 0)" wp_user
    wp_user="${wp_user:-admin}"
    
    echo -n "$(pintar "Contraseña del administrador (oculta): " "prompt" 0)"
    read -s wp_pass
    echo ""
    wp_pass="${wp_pass:-AdminPassword123!}"

    wp() {
        php -d memory_limit=-1 /usr/local/bin/wp "$@"
    }

    pintar "⚙️ Iniciando el despliegue automatizado de WordPress..." "menu"

    # 1. Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    cd "$path_web" || exit 1

    # 2. Instalar WP-CLI localmente si no existe (método seguro y rápido)
    if [ ! -f "/usr/local/bin/wp" ]; then
        pintar "➜ Descargando WP-CLI para la automatización..." "menu"
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 2>/dev/null
        chmod +x wp-cli.phar
        $SUDO mv wp-cli.phar /usr/local/bin/wp
    fi

    # 3. Descargar la última versión de WordPress en castellano
    pintar "➜ Descargando la última versión de WordPress (ES)..." "menu"
    wp core download --locale=es_ES --allow-root

    # 4. Generar el archivo wp-config.php de forma automática
    pintar "➜ Configurando el archivo wp-config.php..." "menu"
    wp config create \
        --dbname="$db_name" \
        --dbuser="$db_user" \
        --dbpass="$db_pass" \
        --dbhost="$db_host" \
        --dbcharset="utf8mb4" \
        --allow-root

    # 5. Intentar crear la base de datos automáticamente si no existe
    pintar "➜ Comprobando / Creando la base de datos en MySQL..." "menu"
    wp db create --allow-root 2>/dev/null
    if [ $? -eq 0 ]; then
        pintar "Base de datos '$db_name' creada o verificada con éxito." "exito"
    else
        pintar "Nota: No se pudo crear la BD automáticamente (quizás ya existía o requiere permisos superiores)." "alerta"
    fi

    # 6. Ejecutar la instalación silenciosa de WordPress
    
    pintar "➜ Instalando y activando el core de WordPress..." "menu"
    wp core install \
        --url="$url_web" \
        --title="Sitio ${crear_web^^}" \
        --admin_user="$wp_user" \
        --admin_password="$wp_pass" \
        --admin_email="$wp_email" \
        --skip-email \
        --allow-root

    # 7. CONFIGURACIÓN DINÁMICA DE VHOST Y PERMISOS SEGÚN S.O.
    configurar_vhost_apache
    # Aplicar permisos correctos para desarrollo web local seguro
    # if [ ! -z "$web_user" ]; then
    #     pintar "➜ Ajustando permisos de ($path_web/wp-config.php)..." "menu"
    #     # wp-config.php un poco más protegido
    #     chmod 660 "$path_web/wp-config.php" 2>/dev/null
    # fi
    url_admin="${url_web}/wp-admin"

    # 8. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡WORDPRESS INSTALADO CORRECTAMENTE SIN NAVEGADOR!" "exito"
    echo "Ruta física:  $path_web"
    echo "URL local:     $url_web"
    echo "Panel Admin:   $url_admin"
    echo "Usuario WP:    $wp_user"
    echo "Contraseña WP: (La que has introducido)"
    echo "------------------------------------------------------------------------------"
}


crear_laminas() {
    pintar "⚙️ Iniciando el despliegue automatizado de Laminas Project (Zend)..." "menu"

    # 1. Verificar o instalar Composer localmente si no existe (Mismo motor seguro de Laravel)
    if ! command -v composer &> /dev/null; then
        if [ ! -f "/usr/local/bin/composer" ]; then
            pintar "➜ Composer no detectado. Instalando Composer de forma local..." "menu"
            curl -sS https://getcomposer.org/installer | php 2>/dev/null
            chmod +x composer.phar
            $SUDO mv composer.phar /usr/local/bin/composer
        fi
    fi

    # 2. Preparar directorios. El esqueleto requiere que Composer cree la carpeta desde cero.
    local path_padre=$(dirname "$path_web")
    local nombre_carpeta=$(basename "$path_web")
    cd "$path_padre" || exit 1

    pintar "➜ Descargando esqueleto MVC de Laminas vía Composer (esto puede tardar)..." "menu"
    # Añadimos --ignore-platform-reqs para saltar el bloqueo de PHP 8.5 en Fedora 44
    composer create-project laminas/laminas-mvc-skeleton "$nombre_carpeta" --no-interaction --ignore-platform-reqs

    # Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }

    # 3. Configurar la conexión a la Base de Datos
    # Laminas almacena su configuración de base de datos local en config/autoload/local.php o de forma global
    pintar "➜ Generando archivo de configuración local para la Base de Datos..." "menu"
    local db_config_file="config/autoload/local.php"
    
    # Creamos un archivo de configuración PHP nativo inyectando tus variables del inicio
    cat <<EOF > "$db_config_file"
<?php
return [
    'db' => [
        'driver' => 'Pdo_Mysql',
        'hostname' => '$db_host',
        'database' => '$db_name',
        'username' => '$db_user',
        'password' => '$db_pass',
        'driver_options' => [
            PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES \'UTF8\''
        ],
    ],
];
EOF

    # 4. Intentar crear la base de datos en MySQL
    pintar "➜ Creando la base de datos en MySQL si no existe..." "menu"
    php -r "
    try {
        \$pdo = new PDO('mysql:host=$db_host', '$db_user', '$db_pass');
        \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');
        echo 'Base de datos verificada/creada correctamente.\n';
    } catch (PDOException \$e) {
        echo 'Aviso: No se pudo auto-crear la base de datos: ' . \$e->getMessage() . '\n';
    }
    "

    # 5. TRUCO DE ENRUTAMIENTO PARA EL VHOST
    # Al igual que Laravel, Laminas sirve desde /public. Apuntamos Apache temporalmente allí.
    local original_path_web="$path_web"
    path_web="${original_path_web}/public"

    # Llamamos a tu función modular reutilizable
    configurar_vhost_apache

    # Restauramos la variable original para mantener limpio el script
    path_web="$original_path_web"

    # 6. Asegurar permisos en las carpetas de caché/escritura de Laminas (data/cache)
    pintar "➜ Asegurando permisos de escritura en el directorio data/..." "menu"
    local web_user="www-data"
    [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ] && web_user="apache"
    [ "$OS" = "macOS" ] && web_user="_www"

    if [ -d "data" ]; then
        $SUDO chgrp -R $web_user data 2>/dev/null
        $SUDO chmod -R ug+rwx data 2>/dev/null
    fi

    # 7. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡LAMINAS PROJECT INSTALADO Y CONFIGURADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Base de Datos:  $db_name"
    echo "Config BD en:   $db_config_file"
    echo "VirtualHost:    Configurado apuntando a /public"
    echo "------------------------------------------------------------------------------"
}

crear_codeigniter() {
    pintar "⚙️ Iniciando el despliegue automatizado de CodeIgniter 4..." "menu"

    # 1. Verificar o instalar Composer localmente si no existe
    if ! command -v composer &> /dev/null; then
        if [ ! -f "/usr/local/bin/composer" ]; then
            pintar "➜ Composer no detectado. Instalando Composer de forma local..." "menu"
            curl -sS https://getcomposer.org/installer | php 2>/dev/null
            chmod +x composer.phar
            $SUDO mv composer.phar /usr/local/bin/composer
        fi
    fi

    # 2. Descargar el esqueleto oficial. Composer debe gestionar la creación del directorio.
    local path_padre=$(dirname "$path_web")
    local nombre_carpeta=$(basename "$path_web")
    cd "$path_padre" || exit 1

    pintar "➜ Creando proyecto CodeIgniter 4 vía Composer..." "menu"
    composer create-project codeigniter4/appstarter "$nombre_carpeta" --no-interaction --ignore-platform-reqs

    # Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }

    # 3. Configurar el archivo de entorno .env
    pintar "➜ Configurando el archivo .env de CodeIgniter..." "menu"
    if [ -f "env" ]; then
        # Copiar la plantilla por defecto al archivo de entorno activo
        cp env .env
        
        # Activar el modo desarrollo para ver errores detallados localmente
        sed -i "s/# CI_ENVIRONMENT = production/CI_ENVIRONMENT = development/g" .env
        
        # Configurar la URL local obligatoria
        sed -i "s|# app.baseURL = 'http://localhost:8080/'|app.baseURL = '$url_web/'|g" .env
        
        # Configurar las credenciales de la Base de Datos
        sed -i "s/# database.default.hostname = localhost/database.default.hostname = $db_host/g" .env
        sed -i "s/# database.default.database = ci4/database.default.database = $db_name/g" .env
        sed -i "s/# database.default.username = root/database.default.username = $db_user/g" .env
        sed -i "s/# database.default.password = root/database.default.password = $db_pass/g" .env
        sed -i "s/# database.default.DBDriver = MySQLi/database.default.DBDriver = MySQLi/g" .env
    fi

    # 4. Intentar crear la base de datos en MySQL
    pintar "➜ Creando la base de datos en MySQL si no existe..." "menu"
    php -r "
    try {
        \$pdo = new PDO('mysql:host=$db_host', '$db_user', '$db_pass');
        \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');
        echo 'Base de datos verificada/creada correctamente.\n';
    } catch (PDOException \$e) {
        echo 'Aviso: No se pudo auto-crear la base de datos: ' . \$e->getMessage() . '\n';
    }
    "

    # 5. TRUCO DE ENRUTAMIENTO PARA EL VHOST
    # CodeIgniter sirve desde /public. Apuntamos Apache temporalmente a esa ruta.
    local original_path_web="$path_web"
    path_web="${original_path_web}/public"

    # Llamamos a tu función modular reutilizable
    configurar_vhost_apache

    # Restauramos la variable original para mantener la coherencia del script
    path_web="$original_path_web"

    # 6. Asegurar permisos de escritura en las carpetas de almacenamiento interno (writable)
    pintar "➜ Asegurando permisos de escritura y contextos SELinux en writable/..." "menu"
    local web_user="www-data"
    [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ] && web_user="apache"
    [ "$OS" = "macOS" ] && web_user="_www"

    if [ -d "writable" ]; then
        # Permisos nativos del sistema de archivos
        $SUDO chown -R $REAL_USER:$web_user writable
        $SUDO chmod -R ug+rwx writable
        
        # PARCHE CRÍTICO SELINUX PARA SECCIONES ESCRITURABLES EN FEDORA
        if [ "$OS" = "Fedora-based" ] && command -v chcon &> /dev/null; then
            $SUDO chcon -R -t httpd_sys_rw_content_t writable 2>/dev/null
        fi
    fi

    # 7. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡CODEIGNITER 4 INSTALADO Y CONFIGURADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Base de Datos:  $db_name"
    echo "Modo entorno:   Development (Errores activos)"
    echo "VirtualHost:    Configurado apuntando a /public"
    echo "------------------------------------------------------------------------------"
}


crear_laravel() {
    pintar "⚙️ Iniciando el despliegue automatizado de Laravel..." "menu"

    # 1. Verificar o instalar Composer localmente si no existe
    if ! command -v composer &> /dev/null; then
        if [ ! -f "/usr/local/bin/composer" ]; then
            pintar "➜ Composer no detectado. Instalando Composer de forma local..." "menu"
            curl -sS https://getcomposer.org/installer | php 2>/dev/null
            chmod +x composer.phar
            $SUDO mv composer.phar /usr/local/bin/composer
        fi
    fi

    # 2. El directorio debe estar vacío o no existir para que Composer cree el proyecto
    # Si tu script ya creó la carpeta vacía con mkdir, Composer puede protestar en algunas versiones.
    # Por seguridad, nos aseguramos de que composer maneje la creación.
    local path_padre=$(dirname "$path_web")
    local nombre_carpeta=$(basename "$path_web")
    cd "$path_padre" || exit 1

    pintar "➜ Creando esqueleto de Laravel vía Composer (esto puede tardar)..." "menu"
    composer create-project laravel/laravel "$nombre_carpeta" --no-interaction --no-scripts --ignore-platform-reqs

    # Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }

    # 3. Configurar las variables de entorno en el archivo .env
    pintar "➜ Configurando variables de base de datos en el archivo .env..." "menu"
    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
        cp .env.example .env
    fi
    if [ -f ".env" ]; then
        # Reemplazar los valores por defecto usando sed de forma segura
        sed -i "s/DB_CONNECTION=.*/DB_CONNECTION=mysql/g" .env
        sed -i "s/DB_HOST=.*/DB_HOST=$db_host/g" .env
        sed -i "s/DB_PORT=.*/DB_PORT=3306/g" .env
        sed -i "s/DB_DATABASE=.*/DB_DATABASE=$db_name/g" .env
        sed -i "s/DB_USERNAME=.*/DB_USERNAME=$db_user/g" .env
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$db_pass/g" .env
        
        # Ajustar la URL local en el .env
        sed -i "s|APP_URL=.*|APP_URL=$url_web|g" .env
    fi
    
    # 4. Forzar la generación de la clave única de encriptación de Laravel
    php artisan key:generate --ansi
    # 5. Intentar crear la base de datos (Usando un script PHP rápido in-situ)
    pintar "➜ Creando la base de datos en MySQL si no existe..." "menu"
    php -r "
    try {
        \$pdo = new PDO('mysql:host=$db_host', '$db_user', '$db_pass');
        \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');
        echo 'Base de datos verificada/creada correctamente.\n';
    } catch (PDOException \$e) {
        echo 'Aviso: No se pudo auto-crear la base de datos: ' . \$e->getMessage() . '\n';
    }
    "

    # 6. Ejecutar migraciones iniciales de Laravel
    pintar "➜ Ejecutando migraciones base de Laravel..." "menu"
    php artisan migrate --force

    # 7. TRUCO DE ENRUTAMIENTO PARA EL VHOST
    # Laravel sirve su web desde /public. Modificamos temporalmente el path para tu función modular.
    local original_path_web="$path_web"
    path_web="${original_path_web}/public"

    # Llamamos a tu función modular reutilizable
    configurar_vhost_apache

    # Restauramos la variable original para que el resumen final sea correcto
    path_web="$original_path_web"

    # 8. Asegurar permisos específicos del motor de plantillas y caché de Laravel
    pintar "➜ Asegurando permisos de escritura en Storage y Bootstrap/Cache..." "menu"
    local web_user="www-data"
    [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ] && web_user="apache"
    [ "$OS" = "macOS" ] && web_user="_www"

    $SUDO chgrp -R $web_user storage bootstrap/cache 2>/dev/null
    $SUDO chmod -R ug+rwx storage bootstrap/cache 2>/dev/null

    # 8. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡LARAVEL INSTALADO Y CONFIGURADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Base de Datos:  $db_name"
    echo "VirtualHost:    Configurado apuntando a /public"
    echo "------------------------------------------------------------------------------"
}

crear_symfony() {
    pintar "⚙️ Iniciando el despliegue automatizado de Symfony..." "menu"

    # 1. Verificar o instalar Composer localmente si no existe
    if ! command -v composer &> /dev/null; then
        if [ ! -f "/usr/local/bin/composer" ]; then
            pintar "➜ Composer no detectado. Instalando Composer de forma local..." "menu"
            curl -sS https://getcomposer.org/installer | php 2>/dev/null
            chmod +x composer.phar
            $SUDO mv composer.phar /usr/local/bin/composer
        fi
    fi

    # 2. Descargar la estructura web base. Composer debe inicializar el directorio limpio.
    local path_padre=$(dirname "$path_web")
    local nombre_carpeta=$(basename "$path_web")
    cd "$path_padre" || exit 1

    pintar "➜ Creando proyecto Symfony (Web App Starter) vía Composer (esto puede tardar)..." "menu"
    # symfony/skeleton + webapp-pack crea el entorno estándar completo para desarrollo web tradicional
    composer create-project symfony/skeleton "$nombre_carpeta" --no-interaction --ignore-platform-reqs
    
    # Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }
    composer require webapp --no-interaction --quiet

    # 3. Configurar la cadena de conexión de la Base de Datos en el archivo .env
    pintar "➜ Configurando variables de entorno en el archivo .env..." "menu"
    if [ -f ".env" ]; then
        # Escapamos los caracteres del password por si contiene elementos especiales que rompan la URL
        local db_pass_escaped=$(echo "$db_pass" | sed 's/[&/]/\\&/g')
        
        # Construimos la URL de conexión estándar para Doctrine ORM (MySQL)
        local database_url="DATABASE_URL=\"mysql://$db_user:$db_pass_escaped@$db_host:3306/$db_name?serverVersion=8.0.0\&charset=utf8mb4\""
        
        # Comentamos la línea por defecto y añadimos la nuestra al final del archivo
        sed -i 's/^DATABASE_URL=/# DATABASE_URL=/g' .env
        echo "$database_url" >> .env
    fi

    # 4. Intentar crear la base de datos en MySQL
    pintar "➜ Creando la base de datos en MySQL si no existe..." "menu"
    php -r "
    try {
        \$pdo = new PDO('mysql:host=$db_host', '$db_user', '$db_pass');
        \$pdo->exec('CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');
        echo 'Base de datos verificada/creada correctamente.\n';
    } catch (PDOException \$e) {
        echo 'Aviso: No se pudo auto-crear la base de datos: ' . \$e->getMessage() . '\n';
    }
    "

    # 5. TRUCO DE ENRUTAMIENTO PARA EL VHOST
    # Symfony sirve el tráfico desde /public. Apuntamos Apache temporalmente a esa ruta.
    local original_path_web="$path_web"
    path_web="${original_path_web}/public"

    # Llamamos a tu función modular reutilizable
    configurar_vhost_apache

    # Restauramos la variable original para mantener la coherencia
    path_web="$original_path_web"

    # 6. Permisos específicos para las carpetas de caché y logs de Symfony
    pintar "➜ Asegurando permisos de escritura en var/cache y var/log..." "menu"
    local web_user="www-data"
    [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ] && web_user="apache"
    [ "$OS" = "macOS" ] && web_user="_www"

    if [ -d "var" ]; then
        $SUDO chgrp -R $web_user var 2>/dev/null
        $SUDO chmod -R ug+rwx var 2>/dev/null
    fi

    # 7. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡SYMFONY INSTALADO Y CONFIGURADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Base de Datos:  $db_name"
    echo "VirtualHost:    Configurado apuntando a /public"
    echo "------------------------------------------------------------------------------"
}

crear_react() {
    pintar "⚙️ Iniciando el despliegue automatizado de React JS (Vite)..." "menu"

    # 1. Asegurar que npm y node funcionan (Tu script ya los validó en la telemetría)
    if ! command -v npm &> /dev/null; then
        pintar "❌ Error crítico: npm no está disponible en el entorno." "error"
        exit 1
    fi

    # 2. El directorio debe ser gestionado por Vite para crear el esqueleto limpio
    local path_padre=$(dirname "$path_web")
    local nombre_carpeta=$(basename "$path_web")
    cd "$path_padre" || exit 1

    pintar "➜ Creando estructura base de React + Vite (JavaScript)..." "menu"
    # --yes evita preguntas interactivas; --template react fuerza el entorno React estándar
    npm create vite@latest "$nombre_carpeta" -- --template react --yes

    # Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }

    # 3. Instalar las dependencias iniciales del package.json
    pintar "➜ Instalando dependencias de Node de forma silenciosa (esto puede tardar)..." "menu"
    npm install --silent

    # 4. Compilar la aplicación por primera vez para generar la carpeta /dist
    pintar "➜ Ejecutando la primera compilación de producción con Vite..." "menu"
    npm run build --silent

    # 5. TRUCO DE ENRUTAMIENTO PARA EL VHOST
    # React compilado genera los archivos estáticos en /dist. Apuntamos Apache allí.
    local original_path_web="$path_web"
    path_web="${original_path_web}/dist"

    # Llamamos a tu función modular reutilizable para enlazar el dominio .test
    configurar_vhost_apache

    # Restauramos la variable original para el resumen
    path_web="$original_path_web"

    # 6. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡REACT JS CON VITE INSTALADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Entorno de des: Ejecuta 'npm run dev' dentro de la ruta para iniciar Vite"
    echo "VirtualHost:    Configurado apuntando a /dist (Producción estática)"
    echo "------------------------------------------------------------------------------"
}


crear_node() {
    pintar "⚙️ Iniciando el despliegue automatizado de Node.js (Express)..." "menu"

    # 1. Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }


    # 2. Inicializar package.json de forma automatizada y silenciosa
    pintar "➜ Inicializando package.json..." "menu"
    npm init -y --silent

    # 3. Configurar el proyecto para usar ES Modules nativos e instalar Express
    pintar "➜ Configurando dependencias del proyecto (Express)..." "menu"
    
    # Añadimos "type": "module" de forma segura usando node in-situ
    node -e "
    const fs = require('fs');
    const pkg = JSON.parse(fs.readFileSync('package.json'));
    pkg.type = 'module';
    pkg.main = 'app.js';
    pkg.scripts = { start: 'node app.js' };
    fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
    "
    
    # Instalar Express
    npm install express --silent

    # 4. Generar el archivo de entrada de la aplicación (app.js) en el puerto 3000
    pintar "➜ Creando archivo base de la aplicación (app.js)..." "menu"
    cat <<EOF > app.js
import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
    res.json({
        status: "success",
        message: "¡Entorno base de Node.js + Express funcionando correctamente!",
        timestamp: new Date()
    });
});

app.listen(PORT, () => {
    console.log(\`Servidor backend corriendo localmente en http://localhost:\${PORT}\`);
});
EOF

    # 5. CONFIGURACIÓN DEL VHOST COMO PROXY INVERSO
    # Extraemos el host limpio de la URL
    local dominio_limpio=$(echo "$url_web" | sed -e 's/http:\/\///g' -e 's/https:\/\///g' -e 's/\/.*//g')
    
    # Registramos el dominio en /etc/hosts utilizando tus variables globales
    if ! grep -q "$dominio_limpio" /etc/hosts; then
        echo "127.0.0.1   $dominio_limpio" | $SUDO tee -a /etc/hosts > /dev/null
    fi

    # Detectamos la ruta de Apache según tu sistema
    local apache_conf_dir=""
    local restart_cmd=""
    case "$OS" in
        "Debian-based")
            apache_conf_dir="/etc/apache2/sites-available"
            restart_cmd="sudo systemctl restart apache2"
            ;;
        "Fedora-based"|"SUSE-based")
            apache_conf_dir="/etc/httpd/conf.d"
            restart_cmd="sudo systemctl restart httpd"
            ;;
        "macOS")
            apache_conf_dir="/usr/local/etc/httpd/extra"
            restart_cmd="sudo apachectl restart"
            ;;
    esac

    # Generamos un VirtualHost específico de tipo Proxy si el directorio existe
    if [ -d "$apache_conf_dir" ]; then
        pintar "➜ Configurando Apache como Proxy Inverso hacia el puerto 3000..." "menu"
        local vhost_file="$apache_conf_dir/${dominio_limpio}.conf"
        
        $SUDO tee "$vhost_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $dominio_limpio

    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/

    ErrorLog \${APACHE_LOG_DIR}/$dominio_limpio-error.log
    CustomLog \${APACHE_LOG_DIR}/$dominio_limpio-access.log combined
</VirtualHost>
EOF

        # Si estás en Debian/Ubuntu, activamos los módulos necesarios para que funcione el proxy
        if [ "$OS" = "Debian-based" ]; then
            $SUDO a2enmod proxy > /dev/null 2>&1
            $SUDO a2enmod proxy_http > /dev/null 2>&1
            if command -v a2ensite &> /dev/null; then
                $SUDO a2ensite "${dominio_limpio}.conf" > /dev/null
            fi
        fi

        $restart_cmd &> /dev/null
    fi

    # 6. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡ENTORNO DE NODE.JS DESPLEGADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Puerto local:   Puerto 3000"
    echo "Modo de uso:    Ejecuta 'npm start' en la carpeta para levantar el servidor."
    echo "VirtualHost:    Apache actúa como Proxy Inverso ($url_web -> localhost:3000)"
    echo "------------------------------------------------------------------------------"
}

crear_python() {
    pintar "⚙️ Iniciando el despliegue automatizado de Python (Flask)..." "menu"

    # 1. Asegurar la existencia del directorio limpio
    mkdir -p "$path_web"
    # Si por algún motivo la carpeta no existe, abortamos limpiamente en lugar de tirar errores en cascada
    cd "$path_web" || { pintar "❌ Error grave: No se pudo acceder al directorio del proyecto: $path_web" "error"; exit 1; }

    # 2. Detectar el comando correcto de Python 3 según el sistema
    local py_cmd="python3"
    if ! command -v python3 &> /dev/null; then
        if command -v python &> /dev/null; then
            py_cmd="python"
        else
            pintar "❌ Error crítico: No se encontró un intérprete de Python en el sistema." "error"
            exit 1
        fi
    fi

    # 3. Crear el entorno virtual (venv) para aislar las dependencias
    pintar "➜ Creando entorno virtual de Python (.venv)..." "menu"
    $py_cmd -m venv .venv
    if [ $? -ne 0 ]; then
        pintar "❌ Error: No se pudo crear el entorno virtual. Asegúrate de tener instalado python3-venv." "error"
        exit 1
    fi

    # 4. Instalar Flask dentro del entorno virtual recién creado
    pintar "➜ Instalar Flask de forma aislada en el entorno..." "menu"
    ./.venv/bin/pip install --upgrade pip --quiet
    ./.venv/bin/pip install Flask --quiet

    # 5. Generar el archivo de entrada de la aplicación web (app.py)
    pintar "➜ Creando archivo base de la aplicación (app.py)..." "menu"
    cat <<EOF > app.py
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "status": "success",
        "message": "¡Entorno base de Python + Flask funcionando correctamente!",
        "framework": "Flask"
    })

if __name__ == '__main__':
    # Correr en todas las interfaces locales en el puerto estándar 5000
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

    # 6. CONFIGURACIÓN DEL VHOST COMO PROXY INVERSO
    # Extraemos el host limpio de la URL
    local dominio_limpio=$(echo "$url_web" | sed -e 's/http:\/\///g' -e 's/https:\/\///g' -e 's/\/.*//g')
    
    # Registramos el dominio en /etc/hosts usando tus variables de cabecera
    if ! grep -q "$dominio_limpio" /etc/hosts; then
        echo "127.0.0.1   $dominio_limpio" | $SUDO tee -a /etc/hosts > /dev/null
    fi

    # Detectamos la ruta de Apache según tu sistema
    local apache_conf_dir=""
    local restart_cmd=""
    case "$OS" in
        "Debian-based")
            apache_conf_dir="/etc/apache2/sites-available"
            restart_cmd="sudo systemctl restart apache2"
            ;;
        "Fedora-based"|"SUSE-based")
            apache_conf_dir="/etc/httpd/conf.d"
            restart_cmd="sudo systemctl restart httpd"
            ;;
        "macOS")
            apache_conf_dir="/usr/local/etc/httpd/extra"
            restart_cmd="sudo apachectl restart"
            ;;
    esac

    # Generamos el VirtualHost Proxy si el directorio de Apache existe
    if [ -d "$apache_conf_dir" ]; then
        pintar "➜ Configurando Apache como Proxy Inverso hacia el puerto 5000..." "menu"
        local vhost_file="$apache_conf_dir/${dominio_limpio}.conf"
        
        $SUDO tee "$vhost_file" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $dominio_limpio

    ProxyPreserveHost On
    ProxyPass / http://localhost:5000/
    ProxyPassReverse / http://localhost:5000/

    ErrorLog \${APACHE_LOG_DIR}/$dominio_limpio-error.log
    CustomLog \${APACHE_LOG_DIR}/$dominio_limpio-access.log combined
</VirtualHost>
EOF

        # Si estás en Debian/Ubuntu, activar módulos de proxy de Apache si no lo están
        if [ "$OS" = "Debian-based" ]; then
            $SUDO a2enmod proxy > /dev/null 2>&1
            $SUDO a2enmod proxy_http > /dev/null 2>&1
            if command -v a2ensite &> /dev/null; then
                $SUDO a2ensite "${dominio_limpio}.conf" > /dev/null
            fi
        fi

        $restart_cmd &> /dev/null
    fi

    # 7. Resumen final
    echo "------------------------------------------------------------------------------"
    pintar "🎉 ¡ENTORNO DE PYTHON + FLASK DESPLEGADO CON ÉXITO!" "exito"
    echo "Ruta física:   $path_web"
    echo "URL local:      $url_web"
    echo "Puerto local:   Puerto 5000"
    echo "Entorno virt:   Activado y aislado en .venv/"
    echo "Modo de uso:    Activa con 'source .venv/bin/activate' y ejecuta 'python app.py'"
    echo "VirtualHost:    Apache actúa como Proxy Inverso ($url_web -> localhost:5000)"
    echo "------------------------------------------------------------------------------"
}

# ==========================================
# 🎛️ ORQUESTADOR PRINCIPAL DE INSTALACIÓN
# ==========================================
orquestar_creacion_web() {
    pintar "🚀 Iniciando la creación del entorno para: ${crear_web^^}" "menu"

    # 1. Evaluar si el entorno requiere Base de Datos
    case "$crear_web" in
        "wordpress"|"laravel"|"symfony"|"codeigniter"|"laminas")
            pedir_datos_bd
            ;;
        *)
            pintar "ℹ️ El entorno seleccionado ($crear_web) no requiere base de datos relacional por defecto." "alerta"
            ;;
    esac

    # 2. Redirigir a la función específica según el CMS/Framework seleccionado
    case "$crear_web" in
        "wordpress")   crear_wordpress ;;
        "laminas")     crear_laminas ;;
        "codeigniter") crear_codeigniter ;;
        "laravel")     crear_laravel ;;
        "symfony")     crear_symfony ;;
        "react")       crear_react ;;
        "node")        crear_node ;;
        "python")      crear_python ;;
        *)
            pintar "❌ Error interno: Entorno '$crear_web' desconocido." "error"
            exit 1
            ;;
    esac

    # 3. Determinar URL de administración si aplica
    url_admin=""
    case "$crear_web" in
        "wordpress")   url_admin="${url_web}/wp-admin" ;;
        "laravel")     url_admin="${url_web}/admin (Si instalas Filament/Nova)" ;;
        "symfony")     url_admin="${url_web}/admin (Requiere EasyAdmin Bundle)" ;;
        *)             url_admin="" ;; #No aplica / Frontend puro
    esac

}




# ==========================================
# 🚀 INICIO DEL SCRIPT
# ==========================================
pintar "##################################################INI##################################################"
pintar "Asistente Inteligente de Selección e Instalación de IDEs: $HORA_INICIO_HUMANA"
pintar "##################################################INI##################################################"

# DETECCIÓN DE S.O.
REAL_USER=${SUDO_USER:-$USER}
if [ "$(uname)" == "Darwin" ]; then
    OS="macOS"
    INSTALL_CMD="brew install"
    SUDO=""
    UPDATE_CMD="brew update && brew upgrade"
else
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        echo "Error: No se pudo encontrar /etc/os-release."
        exit 1
    fi

    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}"
    DISTRO_PRETY="${PRETTY_NAME}"
    DISTRO_VERSION="${VERSION_ID}"

    if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
            OS="Debian-based"
            INSTALL_CMD="apt-get install -y"
            SUDO="sudo"
            UPDATE_CMD="apt-get update"
            if [ -f /etc/debian_version ]; then
                VERSION_BASE_DEBIAN=$(cat /etc/debian_version)
            fi
            # Truco infalible: usar lsb_release con parámetros específicos del upstream (la base)
            if command -v lsb_release >/dev/null 2>&1; then
                # Esto te devolverá "22.04", "24.04", etc., incluso ejecutándose dentro de Linux Mint o Pop!_OS
                VERSION_BASE_UBUNTU=$(lsb_release -u -r 2>/dev/null | awk '{print $2}')
            fi
    elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
            OS="Fedora-based"
            INSTALL_CMD="dnf install -y"
            SUDO="sudo"
            UPDATE_CMD="dnf check-update"
    elif [[ "$ALL_IDS" =~ "arch" || "$ALL_IDS" =~ "manjaro" || "$ALL_IDS" =~ "endeavouros" ]]; then
            OS="Arch-based"
            INSTALL_CMD="pacman -S --noconfirm"
            SUDO="sudo"
            UPDATE_CMD="pacman -Sy"
    elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
            OS="SUSE-based"
            INSTALL_CMD="zypper --non-interactive install"
            SUDO="sudo"
            UPDATE_CMD="zypper refresh"
    else
            echo "Sistema operativo no compatible o no detectado en: $ALL_IDS."
            exit 1
    fi
fi
pintar "OS Detectado: $OS" "exito"
pintar "Distro: $DISTRO_PRETY" "exito"
if [[ ! -z "$VERSION_BASE_DEBIAN" ]]; then
    pintar "Basado en Debian: $VERSION_BASE_DEBIAN" "exito"
fi
if [[ ! -z "$VERSION_BASE_UBUNTU" ]]; then
    pintar "Basado en Ubuntu: $VERSION_BASE_UBUNTU" "exito"
fi

# ==========================================
# 📊 RECOPILACIÓN DE HARDWARE (Telemetría)
# ==========================================
obtener_hardware
detectar_dependencias
detectar_entornos_instalables
aconsejar_cms
# ==========================================
# 🚀 PREGUNTAS INICIALES (MODO DESATENDIDO)
# ==========================================
echo ""
pintar "=== SELECCIONA EL ENTORNO A CREAR ===" "menu"
# Recuperar el listado de ides instalados
echo "0) Ninguno / Salir"
listar_entornos_instalables
read -p "$(pintar "Introduce una opción [1-8] Salir=0: " "prompt" 0)" crear_web_n
# CORREGIDO: Salida inmediata si introduce 0 o valores vacíos
if [[ "$crear_web_n" == "0" || -z "$crear_web_n" ]]; then
    pintar "Saliendo del asistente..." "alerta"
    exit 0
fi
selecciona_entorno
if [[ "$crear_web" == "n" ]]; then 
    pintar "Selección no válida o entorno no soportado por dependencias actuales. Adiós." "error"
    exit 1 
fi
# Asignación de valores por defecto dinámicos si el usuario pulsa Intro
read -p "$(pintar "Nombre de tu sitio [$crear_web]: " "prompt" 0)" nombre_web
nombre_web="${nombre_web:-$crear_web}"

read -p "$(pintar "URL de tu sitio [http://${crear_web}.test]: " "prompt" 0)" url_web
url_web="${url_web:-http://${crear_web}.test}"

read -p "$(pintar "Ruta a tu sitio [${HOME}/workspace/${crear_web}]: " "prompt" 0)" path_web
path_web="${path_web:-${HOME}/workspace/${crear_web}}"

# '-d' para detectar directorios reales ya existentes y evitar sobreescritura accidental
while [ -d "$path_web" ]; do
    pintar "El directorio elegido ya existe ($path_web)." "error"
    read -p "$(pintar "Por favor, seleccione una ruta que NO exista: " "prompt" 0)" path_web
    # Si lo deja vacío en el bucle, reasignar para evitar bucle roto
    path_web="${path_web:-${HOME}/workspace/${nombre_web}_nuevo}"
done

# Lanzar el proceso de creación estructurado
orquestar_creacion_web

# Comprobación final
sleep 2
TEST_URL="$url_web"
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
    # Si es WordPress, realizamos la auditoría estricta de base de datos que programaste
    if [ "$crear_web" = "wordpress" ]; then
        if [[ "$RESPUESTA_HTTP" =~ "Conexión a MySQL exitosa" || "$RESPUESTA_HTTP" =~ "<!DOCTYPE html>" ]]; then
            pintar " ¡Test de conectividad y WordPress superados con éxito!" "exito"
        else
            pintar " Servidor web activo, pero hay un problema de conexión con MySQL." "error"
        fi
    else
        # Para frameworks en blanco (CI4, Laravel, etc.), recibir un 200 OK significa éxito total del VHost
        pintar " ¡Test de conectividad superado! El servidor web responde correctamente (200 OK)." "exito"
    fi
elif [ "$CODIGO_HTTP" -ne 0 ]; then
    pintar " Error de conexión al host de prueba (Código HTTP: $CODIGO_HTTP)." "error"
fi


SEGUNDOS_FIN=$(date +"%s")
TIEMPO_TOTAL=$((SEGUNDOS_FIN - SEGUNDOS_INICIO))
echo ""
pintar "🎉 ¡Entorno instalado con éxito en ${TIEMPO_TOTAL} segundos!" "exito"


