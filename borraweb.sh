#!/bin/bash
# ==========================================
# 📋 REVERSIÓN Y LIMPIEZA DE ENTORNOS WEB
# ==========================================

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
MAGENTA_B=$'\033[1;35m'

pintar() {
    local texto="$1"
    local tipo="${2:-normal}"
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
    echo -e "${color}${etiqueta}${texto}${NC}"
}

# 1. DETECTAR ENTORNO DE OPERACIÓN
if [ "$(uname)" == "Darwin" ]; then
    OS="macOS"
    SUDO=""
    APACHE_CONF_DIR="/usr/local/etc/httpd/extra"
    RESTART_CMD="sudo apachectl restart"
else
    if [ ! -f /etc/os-release ]; then
        pintar "No se pudo detectar el S.O." "error"
        exit 1
    fi
    . /etc/os-release
    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}"
    SUDO="sudo"

    if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
        OS="Debian-based"
        APACHE_CONF_DIR="/etc/apache2/sites-available"
        RESTART_CMD="sudo systemctl restart apache2"
    elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
        OS="Fedora-based"
        APACHE_CONF_DIR="/etc/httpd/conf.d"
        RESTART_CMD="sudo systemctl restart httpd"
    elif [[ "$ALL_IDS" =~ "arch" || "$ALL_IDS" =~ "manjaro" || "$ALL_IDS" =~ "endeavouros" ]]; then
        OS="Arch-based"
        APACHE_CONF_DIR="/etc/httpd/conf/extra"
        RESTART_CMD="sudo systemctl restart httpd"
    elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
        OS="SUSE-based"
        APACHE_CONF_DIR="/etc/apache2/vhosts.d"
        RESTART_CMD="sudo systemctl restart apache2"
    else
        pintar "S.O. no soportado para auto-limpieza." "error"
        exit 1
    fi
fi

if [ ! -d "$APACHE_CONF_DIR" ]; then
    pintar "No se encontró el directorio de configuración de Apache ($APACHE_CONF_DIR)." "error"
    exit 1
fi

# Variables globales para almacenar los datos mapeados
declare -A SITIOS_VHOST
declare -a LISTA_SITIOS
contador=1

# 2. FUNCIÓN DE ESCANEO (CORREGIDO: Ahora el uso de 'local' es válido)
ejecutar_escaneo() {
    pintar "🔍 Escaneando configuraciones de Apache..." "menu"
    
    for archivo in "$APACHE_CONF_DIR"/*.conf; do
        [ -e "$archivo" ] || continue
        
        local dominio=$(grep -i "ServerName" "$archivo" | awk '{print $2}' | head -n 1 | tr -d '[:space:]')
        local ruta=$(grep -i "DocumentRoot" "$archivo" | awk '{print $2}' | head -n 1 | tr -d '"' | tr -d "'" | tr -d '[:space:]')
        
        if [ ! -z "$dominio" ]; then
            SITIOS_VHOST["$contador,dominio"]="$dominio"
            SITIOS_VHOST["$contador,ruta"]="$ruta"
            SITIOS_VHOST["$contador,conf"]="$archivo"
            LISTA_SITIOS+=("$contador")
            ((contador++))
        fi
    done
}

# Ejecutar el análisis mapeado
ejecutar_escaneo

if [ ${#LISTA_SITIOS[@]} -eq 0 ]; then
    pintar "No se detectó ningún VirtualHost local activo en $APACHE_CONF_DIR." "alerta"
    exit 0
fi

# 3. MOSTRAR MENÚ DE SELECCIÓN
pintar "=== SELECCIONA EL SITIO WEB A ELIMINAR ===" "menu"
echo "0) Cancelar / Salir"
for i in "${LISTA_SITIOS[@]}"; do
    echo "$i) ${SITIOS_VHOST["$i,dominio"]} [${SITIOS_VHOST["$i,ruta"]}]"
done

echo ""
read -p "$(printf "${MAGENTA_B}[PREGUNTA] Elige el número del sitio a BORRAR: ${NC}")" seleccion

if [[ "$seleccion" == "0" || -z "$seleccion" || ! "$seleccion" =~ ^[0-9]+$ || $seleccion -ge $contador ]]; then
    pintar "Operación cancelada." "alerta"
    exit 0
fi

DOMINIO_BORRAR="${SITIOS_VHOST["$seleccion,dominio"]}"
RUTA_BORRAR="${SITIOS_VHOST["$seleccion,ruta"]}"
CONF_BORRAR="${SITIOS_VHOST["$seleccion,conf"]}"

# 4. CONFIRMACIÓN ABSOLUTA (Peligro)
echo ""
pintar "⚠️ ¡ALERTA CRÍTICA!" "error"
pintar "Vas a eliminar permanentemente:" "error"
echo "   - Archivo de configuración: $CONF_BORRAR"
echo "   - Entrada en /etc/hosts:    $DOMINIO_BORRAR"
echo "   - Directorio del proyecto:  $RUTA_BORRAR"
echo ""
read -p "$(printf "${ROJO_B}[PELIGRO] ¿Estás completamente seguro? Escribe 'SI' para continuar: ${NC}")" confirmacion

if [ "$confirmacion" != "SI" ]; then
    pintar "Abortando borrado por seguridad." "alerta"
    exit 0
fi

# 5. INTENTAR ELIMINAR LA BASE DE DATOS ASOCIADA
pintar "➜ Buscando credenciales de Base de Datos para auto-borrado..." "menu"
DB_NAME=""

# Si es WordPress, leemos wp-config.php si existe
if [ -f "$RUTA_BORRAR/wp-config.php" ]; then
    DB_NAME=$(grep "DB_NAME" "$RUTA_BORRAR/wp-config.php" | cut -d"'" -f4 2>/dev/null)
    [ -z "$DB_NAME" ] && DB_NAME=$(grep "DB_NAME" "$RUTA_BORRAR/wp-config.php" | cut -d'"' -f4 2>/dev/null)
# Si es de Composer (Laravel/CodeIgniter/Symfony), leemos el archivo .env
elif [ -f "$RUTA_BORRAR/.env" ]; then
    DB_NAME=$(grep "^DB_DATABASE=" "$RUTA_BORRAR/.env" | cut -d'=' -f2 | tr -d '"' | tr -d "'" 2>/dev/null)
fi

if [ ! -z "$DB_NAME" ] && command -v mysql &> /dev/null; then
    echo ""
    pintar "Detectada base de datos potencial: '$DB_NAME'" "alerta"
    read -p "$(printf "${MAGENTA_B}[PREGUNTA] ¿Quieres intentar borrar la BD '$DB_NAME' en MySQL? (s/n): ${NC}")" borrar_db
    if [[ "$borrar_db" == "s" || "$borrar_db" == "S" ]]; then
        read -p "$(printf "${MAGENTA_B}Usuario MySQL [root]: ${NC}")" db_user
        db_user="${db_user:-root}"
        echo -n "$(printf "${MAGENTA_B}Contraseña MySQL (oculta): ${NC}")"
        read -s db_pass
        echo ""
        
        mysql -h localhost -u "$db_user" -p"$db_pass" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;" 2>/dev/null
        if [ $? -eq 0 ]; then
            pintar "Base de datos '$DB_NAME' eliminada con éxito." "exito"
        else
            pintar "No se pudo eliminar la BD (verifica usuario/password)." "error"
        fi
    fi
fi

# 6. PROCEDER CON EL BORRADO DEL SISTEMA DE ARCHIVOS Y CONFIGURACIÓN
echo ""
pintar "➜ Eliminando configuración del VirtualHost..." "menu"
if [ "$OS" = "Debian-based" ] && command -v a2dissite &> /dev/null; then
    $SUDO a2dissite "$(basename "$CONF_BORRAR")" &>/dev/null
fi
$SUDO rm -f "$CONF_BORRAR"

pintar "➜ Removiendo el dominio de /etc/hosts..." "menu"
$SUDO sed -i "/$DOMINIO_BORRAR/d" /etc/hosts

pintar "➜ Eliminando archivos físicos del sitio web..." "menu"
RAIZ_PROYECTO="$RUTA_BORRAR"
if [[ "$RUTA_BORRAR" == */public || "$RUTA_BORRAR" == */dist ]]; then
    RAIZ_PROYECTO=$(dirname "$RUTA_BORRAR")
fi

if [ -d "$RAIZ_PROYECTO" ] && [[ "$RAIZ_PROYECTO" != "$HOME" && "$RAIZ_PROYECTO" != "/" ]]; then
    $SUDO rm -rf "$RAIZ_PROYECTO"
    pintar "Directorio del proyecto eliminado con éxito." "exito"
else
    pintar "Evitado borrado recursivo por ruta raíz inválida o protegida." "alerta"
fi

pintar "➜ Aplicando cambios en el servidor web..." "menu"
$RESTART_CMD &>/dev/null

pintar "🎉 El entorno local para '$DOMINIO_BORRAR' ha sido revertido por completo." "exito"
