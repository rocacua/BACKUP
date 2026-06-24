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
obtener_ram_max_gb() {
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
    ram_max=$(obtener_ram_max_gb)
    pintar "Memoria RAM total del sistema: ${ram_max} MB"

    # Clasificación del hardware del usuario
    PERFIL_HARDWARE="Alto"
    if [ "$ram_max" -lt 4000 ] || [ "$libre_gb" -lt 10 ]; then
        PERFIL_HARDWARE="Bajo"
    elif [ "$ram_max" -lt 8000 ] || [ "$libre_gb" -lt 25 ]; then
        PERFIL_HARDWARE="Medio"
    fi
    pintar "Perfil de Hardware estimado: $PERFIL_HARDWARE" "alerta"
}
instalar_dependencias(){
    case $PERFIL in
        1)
            if ! command -v apache2 &>/dev/null && ! command -v httpd &>/dev/null; then
                pintar "➜ No se detectó Apache en el sistema." "alerta"
                if [ -f "$DIR_SCRIPT/installamp.sh" ]; then
                    read -p "¿Deseas lanzar installamp.sh ahora para instalar tu entorno LAMP? [S/n]: " LANZAR_LAMP
                    if [[ "$LANZAR_LAMP" =~ ^[Ss]?$ ]]; then
                        bash "$DIR_SCRIPT/installamp.sh"
                    fi
                fi
            fi
            ;;
        2)
            if ! command -v java &>/dev/null; then
                pintar "➜ Java JDK no detectado. Instalando..." "alerta"
                if [ "$OS" = "macOS" ]; then brew install openjdk
                elif [ "$OS" = "Debian-based" ]; then $SUDO apt-get update && $SUDO apt-get install -y default-jdk
                elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf install -y java-latest-openjdk-devel
                elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -S --noconfirm jdk-openjdk
                elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install java-17-openjdk-devel; fi
            fi
            pintar "✓ Java listo: $(java -version 2>&1 | head -n 1)" "exito"
            ;;
        3)
            if ! command -v dotnet &>/dev/null; then
                pintar "➜ .NET SDK no detectado. Instalando..." "alerta"
                if [ "$OS" = "macOS" ]; then brew install --cask dotnet-sdk
                elif [ "$OS" = "Debian-based" ]; then $SUDO apt-get update && $SUDO apt-get install -y dotnet-sdk-8.0
                elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf install -y dotnet-sdk-8.0
                elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -S --noconfirm dotnet-sdk
                elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install dotnet-sdk-8.0; fi
            fi
            pintar "✓ .NET SDK listo: $(dotnet --version)" "exito"
            ;;
    esac
}

instalar_via_snap() {
    if command -v snap &> /dev/null; then $SUDO snap install "$1" --classic
    elif [ "$OS" = "Debian-based" ]; then
        $SUDO apt-get update && $SUDO apt-get install -y snapd && $SUDO ln -s /var/lib/snapd/snap /snap 2>/dev/null
        $SUDO snap install "$1" --classic
    else pintar "Snap no disponible. Instale '$1' manualmente." "error"; exit 1; fi
}
ejecutar_instalacion_ide() {
    pintar "➜ Instalando $IDE_NAME mediante canales oficiales..." "menu"
    
    # 1. Detectar dinámicamente la arquitectura de CPU del equipo actual
    local ARCH="x64"
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        ARCH="arm64"
    fi

    # 2. Flujo de instalación para macOS (Lógica Brew Cask aislada)
    if [ "$OS" = "macOS" ]; then
        case $IDE_NAME in
            intellij) brew install --cask intellij-idea-community ;;
            netbeans) brew install --cask netbeans ;;
            vscode)   brew install --cask visual-studio-code ;;
            vscodium) brew install --cask vscodium ;;
            cursor)   brew install --cask cursor ;;
            neovim)   brew install neovim ;;
        esac
    else
        # 3. Flujo de instalación para Linux
        case $IDE_NAME in
            intellij) instalar_via_snap "intellij-idea-community" ;;
            netbeans) instalar_via_snap "netbeans" ;;
            vscode)
                if [[ "$OS" =~ "Debian" || "$OS" =~ "Fedora" ]]; then 
                    instalar_via_snap "code"
                elif [ "$OS" = "Arch-based" ]; then 
                    $SUDO pacman -S --noconfirm code
                fi ;;
            vscodium) 
                instalar_via_snap "codium" ;;
            
            cursor)
                # MODIFICACIÓN DINÁMICA DE URLS SEGÚN LA DISTRIBUCIÓN (¡Aporte excelente!)
                if [ "$OS" = "Debian-based" ]; then
                    pintar "➜ Descargando paquete oficial .deb de Cursor..." "alerta"
                    #curl -L "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/3.8" -o "$HOME/Applications/cursor.appimage"      
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}-deb/cursor/latest" -o /tmp/cursor.deb
                    $SUDO apt-get update && $SUDO apt-get install -y /tmp/cursor.deb
                    rm -f /tmp/cursor.deb
                elif [ "$OS" = "Fedora-based" ]; then
                    pintar "➜ Descargando paquete oficial .rpm de Cursor..." "alerta"
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}-rpm/cursor/latest" -o /tmp/cursor.rpm
                    $SUDO dnf install -y /tmp/cursor.rpm
                    rm -f /tmp/cursor.rpm
                else
                    # Para Arch, SUSE u otros, descargamos el AppImage limpio usando la URL directa
                    pintar "➜ Descargando Cursor oficial en formato AppImage..." "alerta"
                    mkdir -p "$HOME/Applications"
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}/cursor/latest" -o "$HOME/Applications/cursor.appimage"
                    chmod +x "$HOME/Applications/cursor.appimage"
                    pintar "✓ Cursor AppImage listo en $HOME/Applications/cursor.appimage" "exito"
                fi
                ;;
                
            neovim) 
                $SUDO $INSTALL_CMD neovim ;;
        esac
    fi
}


configurar_plugins_ide() {
    if [ "$IDE_NAME" = "vscode" ] || [ "$IDE_NAME" = "vscodium" ]; then
        BIN_CMD="code"; [ "$IDE_NAME" = "vscodium" ] && BIN_CMD="codium"

        if command -v $BIN_CMD &> /dev/null; then
            pintar "➜ Inyectando plugins del perfil elegido en el editor..." "menu"
            $BIN_CMD --install-extension Codeium.codeium >/dev/null # IA Base Gratuita

            case $PERFIL in
                1)  $BIN_CMD --install-extension xdebug.php-debug >/dev/null
                    $BIN_CMD --install-extension bmewburn.vscode-next-php-intelophense >/dev/null
                    $BIN_CMD --install-extension dbaeumer.vscode-eslint >/dev/null
                    $BIN_CMD --install-extension esbenp.prettier-vscode >/dev/null ;;
                2)  $BIN_CMD --install-extension vscjava.vscode-java-pack >/dev/null ;;
                3)  $BIN_CMD --install-extension ms-dotnettools.csdevkit >/dev/null ;;
                4)  $BIN_CMD --install-extension timonwong.shellcheck >/dev/null
                    $BIN_CMD --install-extension mads-hartmann.bash-checker >/dev/null ;;
            esac
            pintar "✓ Plugins inyectados correctamente." "exito"
        fi
    fi
}

instalar_git() {
    if ! command -v git &>/dev/null; then
        pintar "Git no está instalado. Procediendo con la instalación automática..." "alerta"
        if [ "$OS" = "macOS" ]; then
            brew install git
        else
            # Usamos los comandos dinámicos que detectaste en la cabecera
            $SUDO $UPDATE_CMD > /dev/null 2>&1
            if [ "$OS" = "Debian-based" ]; then $SUDO apt-get install -y git
            elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf install -y git
            elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -S --noconfirm git
            elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install git; fi
        fi
        pintar "Git se ha instalado correctamente: $(git --version)" "exito"
    else
        pintar "Git ya está disponible en el sistema ($(git --version))." "exito"
    fi
}

# ==========================================
# 🚀 INICIO DEL SCRIPT
# ==========================================
pintar "##################################################INI##################################################"
pintar "Asistente Inteligente de Selección e Instalación de IDEs: $HORA_INICIO_HUMANA"
pintar "##################################################INI##################################################"

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

    if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
            OS="Debian-based"
            INSTALL_CMD="apt-get install -y"
            SUDO="sudo"
            UPDATE_CMD="apt-get update"
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

# ==========================================
# 📊 RECOPILACIÓN DE HARDWARE (Telemetría)
# ==========================================
obtener_hardware

# ==========================================
# 📦 VALIDACIÓN E INSTALACIÓN DE GIT
# ==========================================
instalar_git


# ==========================================
# 🧠 SELECCIÓN DEL PERFIL DE USO
# ==========================================
echo ""
pintar "=== SELECCIONA TU PERFIL DE DESARROLLO ===" "menu"
echo "1) Desarrollo Web (PHP, JS, Laravel, React, Python)"
echo "2) Desarrollo Java Profesional (Java SE/EE, Spring Boot)"
echo "3) Ecosistema Microsoft .NET (C#, Web APIs)"
echo "4) SysAdmin / Automatización (Bash scripting, Terminal)"
read -p "Introduce una opción [1-4]: " PERFIL

# ==========================================
# 🛠️ GESTIÓN DE DEPENDENCIAS POR PERFIL
# ==========================================
instalar_dependencias

# ==========================================
# 🛠️ SELECCIÓN INTERACTIVA E INSTALACIÓN DEL IDE
# ==========================================
echo ""
pintar "=== SELECCIONA EL IDE A INSTALAR ===" "menu"
if [ "$PERFIL" -eq 2 ]; then
    echo "1) IntelliJ IDEA Community Edition"
    echo "2) Apache NetBeans"
    echo "3) Visual Studio Code"
else
    echo "1) Visual Studio Code (Oficial)"
    echo "2) VSCodium (Código abierto sin telemetría)"
    echo "3) Cursor (IDE enfocado a IA)"
    echo "4) Neovim (Terminal ligero)"
fi
echo "5) Salir"
read -p "Elige una opción [1-5]: " SELECCION

IDE_NAME="salir"
if [ "$PERFIL" -eq 2 ]; then
    [ "$SELECCION" -eq 1 ] && IDE_NAME="intellij"
    [ "$SELECCION" -eq 2 ] && IDE_NAME="netbeans"
    [ "$SELECCION" -eq 3 ] && IDE_NAME="vscode"
else
    [ "$SELECCION" -eq 1 ] && IDE_NAME="vscode"
    [ "$SELECCION" -eq 2 ] && IDE_NAME="vscodium"
    [ "$SELECCION" -eq 3 ] && IDE_NAME="cursor"
    [ "$SELECCION" -eq 4 ] && IDE_NAME="neovim"
fi
if [ "$IDE_NAME" = "salir" ]; then exit 0; fi

ejecutar_instalacion_ide


# ==========================================
# ⚙️ CONFIGURACIÓN DE EXTENSIONES POST-INSTALACIÓN
# ==========================================
if [ "$OS" != "macOS" ] && [[ "$PERFIL" -eq 1 || "$PERFIL" -eq 4 ]]; then
    pintar "➜ Configurando dependencias de intérpretes (NodeJS/Python)..." "alerta"
    if [ "$OS" = "Debian-based" ]; then $SUDO apt-get install -y nodejs npm python3-pip python3-venv 2>/dev/null
    elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf install -y nodejs python3-pip 2>/dev/null
    elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -S --noconfirm nodejs npm python-pip 2>/dev/null
    elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install nodejs npm python3-pip 2>/dev/null; fi
fi

configurar_plugins_ide

SEGUNDOS_FIN=$(date +"%s")
DURACION=$((SEGUNDOS_FIN - SEGUNDOS_INICIO))
pintar "🎉 ¡Entorno configurado con éxito en ${DURACION} segundos!" "exito"
