#!/bin/bash

# Asegurar que el script se ejecuta con los privilegios necesarios
if [ "$(uname)" != "Darwin" ] && [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo ./uninstallamp.sh)."
  exit 1
fi
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
declare -A IDES_INSTALADOS
instalado_git="n"
instalado_apache="n"
instalado_java="n"
instalado_donet="n"
instalado_ia="n"
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

detectar_ides() {
    pintar "➜ Escaneando IDEs en el sistema..." "menu"
    local ides=("intellij" "netbeans" "vscode" "vscodium" "cursor" "neovim" "eclipse" "android-studio")
    
    # Inicializar todas en "n"
    for ide in "${ides[@]}"; do IDES_INSTALADOS[$ide]="n"; done

    # Recuperar el HOME del usuario real que lanzó el sudo para buscar sus AppImages
    local user_home="${SUDO_USER:-$USER}"
    local real_home=""
    if [ "$OS" = "macOS" ]; then real_home="/Users/$user_home"; else real_home="/home/$user_home"; fi
    [ "$user_home" = "root" ] && real_home="/root"

    if [ "$OS" = "macOS" ]; then
        [ -d "/Applications/IntelliJ IDEA Community Edition.app" ] && IDES_INSTALADOS[intellij]="s"
        [ -d "/Applications/NetBeans.app" ] || [ -d "/Applications/Apache NetBeans.app" ] && IDES_INSTALADOS[netbeans]="s"
        [ -d "/Applications/Visual Studio Code.app" ] && IDES_INSTALADOS[vscode]="s"
        [ -d "/Applications/VSCodium.app" ] && IDES_INSTALADOS[vscodium]="s"
        [ -d "/Applications/Cursor.app" ] && IDES_INSTALADOS[cursor]="s"
        command -v nvim &> /dev/null && IDES_INSTALADOS[neovim]="s"
        [ -d "/Applications/Eclipse.app" ] && IDES_INSTALADOS[eclipse]="s"
        [ -d "/Applications/Android Studio.app" ] && IDES_INSTALADOS[android-studio]="s"
    else
        # LINUX: Búsqueda ultra-robusta (Comando global OR Ruta absoluta OR Paquete nativo OR Snap)
        
        # IntelliJ
        (command -v intellij-idea-community &> /dev/null || [ -d "/snap/intellij-idea-community" ]) && IDES_INSTALADOS[intellij]="s"
        
        # NetBeans
        (command -v netbeans &> /dev/null || [ -d "/snap/netbeans" ]) && IDES_INSTALADOS[netbeans]="s"
        
        # VS Code
        (command -v code &> /dev/null || [ -f "/usr/bin/code" ] || [ -d "/snap/code" ] || rpm -q code &>/dev/null || dpkg -s code &>/dev/null) && IDES_INSTALADOS[vscode]="s"
        
        # VSCodium (CORREGIDO: Ahora busca también en la ruta RPM fija y gestor de paquetes de Fedora)
        (command -v codium &> /dev/null || [ -f "/usr/bin/codium" ] || [ -d "/snap/codium" ] || rpm -q codium &>/dev/null || dpkg -s codium &>/dev/null) && IDES_INSTALADOS[vscodium]="s"
        
        # Cursor
        (command -v cursor &> /dev/null || [ -f "/usr/bin/cursor" ] || [ -f "$real_home/Applications/cursor.appimage" ]) && IDES_INSTALADOS[cursor]="s"
        
        # Neovim
        (command -v nvim &> /dev/null || [ -f "/usr/bin/nvim" ] || [ -f "/usr/local/bin/nvim" ]) && IDES_INSTALADOS[neovim]="s"
        
        # Eclipse
        (command -v eclipse &> /dev/null || [ -f "/usr/bin/eclipse" ] || [ -d "/snap/eclipse" ]) && IDES_INSTALADOS[eclipse]="s"
        
        # Android Studio
        (command -v android-studio &> /dev/null || [ -d "/snap/android-studio" ]) && IDES_INSTALADOS[android-studio]="s"
    fi
}
detectar_git() {
    if command -v git &> /dev/null; then
        instalado_git="s"
        pintar "Git detectado en el sistema." "alerta"
    fi
}
detectar_dependencias() {
    # apache java dotnet
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
}
detectar_ia_local() {
    if command -v ollama &> /dev/null || systemctl is-active ollama &> /dev/null; then
        instalado_ia="s"
        pintar "Asistente de IA Local (Ollama) detectado." "alerta"
    fi
}
detectar_node_python() {
    pintar "➜ Analizando intérpretes de lenguajes (NodeJS/Python)..." "menu"
    
    if command -v node &> /dev/null || command -v npm &> /dev/null; then
        instalado_node="s"
        pintar "Entorno de NodeJS detectado." "alerta"
    fi

    if command -v python3 &> /dev/null || command -v pip3 &> /dev/null; then
        instalado_python="s"
        pintar "Entorno de Python3 detectado." "alerta"
    fi
}

eliminar_configuracion() {
    # desinstalar programas del ide y eliminar archivos innecesarios
    local target_ide="$1"
    local user_home="${SUDO_USER:-$USER}"
    local user_dir=""
    
    if [ "$OS" = "macOS" ]; then user_dir="/Users/$user_home"; else user_dir="/home/$user_home"; fi
    [ "$user_home" = "root" ] && user_dir="/root"

    pintar "➜ Purgando perfiles, caches y configuraciones de usuario para: $target_ide..." "alerta"
    
    case "$target_ide" in
        "vscode")
            rm -rf "$user_dir/.vscode" "$user_dir/.config/Code" "$user_dir/Library/Application Support/Code" 2>/dev/null ;;
        "vscodium")
            rm -rf "$user_dir/.vscode-oss" "$user_dir/.config/VSCodium" "$user_dir/Library/Application Support/VSCodium" 2>/dev/null ;;
        "cursor")
            rm -rf "$user_dir/.cursor" "$user_dir/.config/Cursor" "$user_dir/Library/Application Support/Cursor" "$user_dir/Applications/cursor.appimage" 2>/dev/null ;;
        "intellij")
            rm -rf "$user_dir/.config/JetBrains" "$user_dir/.cache/JetBrains" "$user_dir/Library/Application Support/JetBrains" 2>/dev/null ;;
        "netbeans")
            rm -rf "$user_dir/.netbeans" "$user_dir/.cache/netbeans" "$user_dir/Library/Application Support/NetBeans" 2>/dev/null ;;
        "eclipse")
            rm -rf "$user_dir/.eclipse" "$user_dir/eclipse-workspace" "$user_dir/Library/Application Support/Eclipse" 2>/dev/null ;;
        "android-studio")
            rm -rf "$user_dir/.android" "$user_dir/.AndroidStudio"* "$user_dir/Android/Sdk" "$user_dir/Library/Application Support/AndroidStudio"* 2>/dev/null 
            # Eliminar KVM si estamos en Linux
            if [ "$OS" != "macOS" ]; then
                $SUDO usermod -dG kvm,libvirt "$user_home" 2>/dev/null
            fi ;;
        "neovim")
            rm -rf "$user_dir/.config/nvim" "$user_dir/.local/share/nvim" "$user_dir/.cache/nvim" /usr/local/bin/nvim 2>/dev/null ;;
    esac

    pintar "✓ Eliminada configuración de ${target_ide}." "exito"
}
desinstalar_ide() {
    local target_ide="$1"
    [ -z "$target_ide" ] || [ "$target_ide" = "ninguno" ] && return 0

    pintar "⚙️ Desinstalando binarios del IDE: $target_ide..." "alerta"

    if [ "$OS" = "macOS" ]; then
        case "$target_ide" in
            "intellij")       brew uninstall --cask intellij-idea-community 2>/dev/null ;;
            "netbeans")       brew uninstall --cask netbeans 2>/dev/null ;;
            "vscode")         brew uninstall --cask visual-studio-code 2>/dev/null ;;
            "vscodium")       brew uninstall --cask vscodium 2>/dev/null ;;
            "cursor")         brew uninstall --cask cursor 2>/dev/null ;;
            "neovim")         brew uninstall neovim 2>/dev/null ;;
            "eclipse")        brew uninstall --cask eclipse-jee 2>/dev/null ;;
            "android-studio") brew uninstall --cask android-studio 2>/dev/null ;;
        esac
    else
        # Linux: Remoción nativa / Snap según corresponda
        if [ "$OS" = "Debian-based" ]; then
            case "$target_ide" in
                "vscode")         $SUDO apt-get purge -y code && $SUDO rm -f /etc/apt/sources.list.d/vscode.list 2>/dev/null ;;
                "vscodium")       $SUDO apt-get purge -y codium && $SUDO rm -f /etc/apt/sources.list.d/vscodium.list 2>/dev/null ;;
                "neovim")         $SUDO apt-get purge -y neovim 2>/dev/null ;;
                *)                $SUDO snap remove "$target_ide" 2>/dev/null ;;
            esac
        elif [ "$OS" = "Fedora-based" ]; then
            case "$target_ide" in
                "vscode")         $SUDO dnf remove -y code && $SUDO rm -f /etc/yum.repos.d/vscode.repo 2>/dev/null ;;
                "vscodium")       $SUDO dnf remove -y codium && $SUDO rm -f /etc/yum.repos.d/vscodium.repo 2>/dev/null ;;
                "cursor")         $SUDO dnf remove -y cursor 2>/dev/null ;;
                "neovim")         $SUDO dnf remove -y neovim 2>/dev/null ;;
                *)                $SUDO snap remove "$target_ide" 2>/dev/null ;;
            esac
        elif [ "$OS" = "SUSE-based" ]; then
            case "$target_ide" in
                "vscode")         $SUDO zypper --non-interactive remove code && $SUDO rm -f /etc/zypp/repos.d/vscode.repo 2>/dev/null ;;
                "vscodium")       $SUDO zypper --non-interactive remove codium && $SUDO rm -f /etc/zypp/repos.d/vscodium.repo 2>/dev/null ;;
                "neovim")         $SUDO zypper --non-interactive remove neovim 2>/dev/null ;;
                *)                $SUDO snap remove "$target_ide" 2>/dev/null ;;
            esac
        elif [ "$OS" = "Arch-based" ]; then
            case "$target_ide" in
                "vscode")         $SUDO pacman -Rns --noconfirm code 2>/dev/null ;;
                "vscodium")       $SUDO pacman -Rns --noconfirm vscodium-bin 2>/dev/null ;;
                "neovim")         $SUDO pacman -Rns --noconfirm neovim 2>/dev/null ;;
                "eclipse")        $SUDO pacman -Rns --noconfirm eclipse-java 2>/dev/null ;;
                "android-studio") $SUDO pacman -Rns --noconfirm android-studio 2>/dev/null ;;
                *)                $SUDO snap remove "$target_ide" 2>/dev/null ;;
            esac
        fi
    fi

    # Eliminar configuraciones residuales del usuario
    eliminar_configuracion "$target_ide"
    pintar "✓ Desinstalación de $target_ide completada." "exito"
}
desinstalar_git() {
    pintar "⚙️ Removiendo Git del sistema..." "alerta"
    if [ "$OS" = "macOS" ]; then brew uninstall git 2>/dev/null
    elif [ "$OS" = "Debian-based" ]; then $SUDO apt-get purge -y git 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf remove -y git 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive remove git 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -Rns --noconfirm git 2>/dev/null; fi

    pintar "✓ Git desinstalado correctamente." "exito"
}
desinstalar_apache() {
    # PARA DENSINSTALAR APACHE TENGO uninstallamp.sh
    pintar "➜ Delegando desinstalación de Apache en script secundario..." "alerta"
    if [ -f "$DIR_SCRIPT/uninstallamp.sh" ]; then
        chmod +x "$DIR_SCRIPT/uninstallamp.sh"
        $SUDO "$DIR_SCRIPT/uninstallamp.sh"
    else
        pintar "No se encontró el script 'uninstallamp.sh'. Saltando desinstalación de Apache." "error"
    fi
}
desinstalar_java() {
    pintar "⚙️ Removiendo paquetes de desarrollo Java (JDK)..." "alerta"
    if [ "$OS" = "macOS" ]; then 
        $SUDO rm -rf /Library/Java/JavaVirtualMachines/* 2>/dev/null
    elif [ "$OS" = "Debian-based" ]; then 
        $SUDO apt-get purge -y default-jdk default-jre openjdk-* 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then 
        $SUDO dnf remove -y java-*-openjdk* 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then
        $SUDO zypper --non-interactive remove java--openjdk 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then
        $SUDO pacman -Rns --noconfirm $(pacman -Qq | grep jdk) 2>/dev/null
    fi

    pintar "✓ Java desinstalado correctamente." "exito"
}
desinstalar_dotnet() {
    pintar "⚙️ Removiendo SDK de .NET..." "alerta"
    if [ "$OS" = "macOS" ]; then
        $SUDO rm -rf /usr/local/share/dotnet /etc/paths.d/dotnet 2>/dev/null
    elif [ "$OS" = "Debian-based" ]; then
        $SUDO apt-get purge -y dotnet-sdk-* dotnet-runtime-* 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then
        $SUDO dnf remove -y dotnet-sdk-* 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then
        $SUDO zypper --non-interactive remove dotnet-sdk-* 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then
        $SUDO pacman -Rns --noconfirm dotnet-sdk 2>/dev/null
    fi

    pintar "✓ .NET desinstalado correctamente." "exito"
}
desinstalar_ia_local() {
    pintar "⚙️ Purgando Ollama y modelos de IA locales..." "alerta"
    if [ "$OS" = "macOS" ]; then
        brew uninstall ollama 2>/dev/null
        rm -rf ~/.ollama 2>/dev/null
    else
        # Detener y deshabilitar servicios del sistema
        $SUDO systemctl stop ollama 2>/dev/null
        $SUDO systemctl disable ollama 2>/dev/null
        $SUDO rm -f /etc/systemd/system/ollama.service 2>/dev/null
        $SUDO systemctl daemon-reload
        # Eliminar binarios y usuarios del sistema
        $SUDO rm -f /usr/local/bin/ollama 2>/dev/null
        $SUDO rm -rf /usr/share/ollama 2>/dev/null
        $SUDO userdel ollama 2>/dev/null
        $SUDO groupdel ollama 2>/dev/null
        # Borrar modelos guardados en el HOME de los usuarios
        local user_home="${SUDO_USER:-$USER}"
        rm -rf "/home/$user_home/.ollama" "/root/.ollama" 2>/dev/null
    fi
    pintar "✓ Servidor Ollama purgado por completo." "exito"
}
desinstalar_node() {
    pintar "⚙️ Removiendo NodeJS, NPM y cachés globales..." "alerta"
    
    if [ "$OS" = "macOS" ]; then
        brew uninstall node 2>/dev/null
    elif [ "$OS" = "Debian-based" ]; then
        $SUDO apt-get purge -y nodejs npm 2>/dev/null
        $SUDO apt-get autoremove -y 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then
        $SUDO dnf remove -y nodejs nodejs22 nodejs22-npm 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then
        $SUDO zypper --non-interactive remove nodejs-default npm-default nodejs npm 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then
        $SUDO pacman -Rns --noconfirm nodejs npm 2>/dev/null
    fi

    # Limpieza estricta de residuos y módulos globales en el HOME del usuario
    local user_home="${SUDO_USER:-$USER}"
    local user_dir=""
    if [ "$OS" = "macOS" ]; then user_dir="/Users/$user_home"; else user_dir="/home/$user_home"; fi
    [ "$user_home" = "root" ] && user_dir="/root"

    rm -rf "$user_dir/.npm" "$user_dir/.node-gyp" "$user_dir/.config/configstore" 2>/dev/null
    $SUDO rm -rf /usr/local/lib/node_modules /usr/local/bin/node /usr/local/bin/npm 2>/dev/null
    pintar "✓ NodeJS purgado correctamente." "exito"
}
desinstalar_python() {
    pintar "⚙️ Removiendo dependencias adicionales de Python (Pip/Venv)..." "alerta"
    pintar "⚠ NOTA: No se desinstalará el binario base 'python3' para evitar romper herramientas críticas del sistema." "alerta"

    if [ "$OS" = "macOS" ]; then
        brew uninstall python-pip 2>/dev/null
    elif [ "$OS" = "Debian-based" ]; then
        $SUDO apt-get purge -y python3-pip python3-venv 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then
        $SUDO dnf remove -y python3-pip 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then
        $SUDO zypper --non-interactive remove python3-pip 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then
        $SUDO pacman -Rns --noconfirm python-pip 2>/dev/null
    fi

    # Limpieza de cachés de paquetes descargados por el usuario
    local user_home="${SUDO_USER:-$USER}"
    local user_dir=""
    if [ "$OS" = "macOS" ]; then user_dir="/Users/$user_home"; else user_dir="/home/$user_home"; fi
    [ "$user_home" = "root" ] && user_dir="/root"

    rm -rf "$user_dir/.cache/pip" "$user_dir/.local/lib/python"* 2>/dev/null
    pintar "✓ Herramientas de Python purgadas correctamente." "exito"
}


# ==========================================
# 📊 EXECUCIÓN DE ESCÁNER COLECTOR
# ==========================================
# DETECCIÓN DE S.O.
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

#OBTENER DATOS
obtener_hardware
detectar_git
detectar_dependencias
detectar_ides
detectar_node_python
detectar_ia_local

# ==========================================
# 🚀 PREGUNTAS INICIALES (MODO DESATENDIDO)
# ==========================================
echo ""
pintar "=== SELECCIONA EL IDE A DESINSTALAR ===" "menu"
# Recuperar el listado de ides instalados
echo "0) Ninguno / Saltar desinstalación de IDE"
[ "${IDES_INSTALADOS[intellij]}" = "s" ]       && echo "1) IntelliJ IDEA Community Edition"
[ "${IDES_INSTALADOS[netbeans]}" = "s" ]       && echo "2) Apache NetBeans"
[ "${IDES_INSTALADOS[eclipse]}" = "s" ]        && echo "3) Eclipse"
[ "${IDES_INSTALADOS[vscode]}" = "s" ]         && echo "4) Visual Studio Code"
[ "${IDES_INSTALADOS[vscodium]}" = "s" ]       && echo "5) VSCodium"
[ "${IDES_INSTALADOS[cursor]}" = "s" ]         && echo "6) Cursor"
[ "${IDES_INSTALADOS[neovim]}" = "s" ]         && echo "7) Neovim"
[ "${IDES_INSTALADOS[android-studio]}" = "s" ] && echo "8) Android Studio"
read -p "$(pintar "Introduce una opción [1-8] Salir=0: " "prompt" 0)" desinstala_ide

# Mapear el ID seleccionado a una cadena de texto para la función principal
IDE_A_BORRAR="ninguno"
[ "$desinstala_ide" -eq 1 ] && IDE_A_BORRAR="intellij"
[ "$desinstala_ide" -eq 2 ] && IDE_A_BORRAR="netbeans"
[ "$desinstala_ide" -eq 3 ] && IDE_A_BORRAR="eclipse"
[ "$desinstala_ide" -eq 4 ] && IDE_A_BORRAR="vscode"
[ "$desinstala_ide" -eq 5 ] && IDE_A_BORRAR="vscodium"
[ "$desinstala_ide" -eq 6 ] && IDE_A_BORRAR="cursor"
[ "$desinstala_ide" -eq 7 ] && IDE_A_BORRAR="neovim"
[ "$desinstala_ide" -eq 8 ] && IDE_A_BORRAR="android-studio"

# Capturar decisiones en cascada para no interrumpir la ejecución después
CONFIRM_GIT="n"; CONFIRM_APACHE="n"; CONFIRM_JAVA="n"; CONFIRM_DOTNET="n"; CONFIRM_IA="n"; CONFIRM_NODE="n"; CONFIRM_PYTHON="n"

if [[ "$instalado_git" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar Git? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_GIT="s"
fi
if [[ "$instalado_apache" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar Apache? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_APACHE="s"
fi
if [[ "$instalado_java" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar Java? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_JAVA="s"
fi
if [[ "$instalado_donet" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar .NET? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_DOTNET="s"
fi
if [[ "$instalado_node" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar Node? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_NODE="s"
fi
if [[ "$instalado_python" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar Python? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_PYTHON="s"
fi
if [[ "$instalado_ia" == "s" ]]; then
    read -p "$(pintar "¿Quieres desinstalar IA local (Ollama)? [s|N]: " "prompt" 0)" answer && [[ "$answer" =~ ^[Ss]$ ]] && CONFIRM_IA="s"
fi

# ==========================================
# ⚡ PASO 3: EJECUCIÓN EN LOTE (DESATENDIDO)
# ==========================================
pintar "🚀 Procesando cola de desinstalaciones sin pausas..." "menu"

[ "$IDE_A_BORRAR" != "ninguno" ] && desinstalar_ide "$IDE_A_BORRAR"
[ "$CONFIRM_GIT" = "s" ]         && desinstalar_git
[ "$CONFIRM_APACHE" = "s" ]      && desinstalar_apache
[ "$CONFIRM_JAVA" = "s" ]        && desinstalar_java
[ "$CONFIRM_DOTNET" = "s" ]      && desinstalar_dotnet
[ "$CONFIRM_NODE" = "s" ]        && desinstalar_node
[ "$CONFIRM_PYTHON" = "s" ]      && desinstalar_python
[ "$CONFIRM_IA" = "s" ]          && desinstalar_ia_local

# Cronómetro de cierre idéntico a tu instalador
SEGUNDOS_FIN=$(date +"%s")
: "${SEGUNDOS_INICIO:=$SEGUNDOS_FIN}"
DURACION=$((SEGUNDOS_FIN - SEGUNDOS_INICIO))
pintar "🎉 ¡Limpieza finalizada con éxito en ${DURACION} segundos!" "exito"
