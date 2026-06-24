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
            # Comprobar si responde el puerto 80 local usando herramientas nativas de red
            local apache_activo=0
            if command -v ss &>/dev/null; then
                ss -tlnp | grep -q ':80 ' && apache_activo=1
            elif command -v netstat &>/dev/null; then
                netstat -tln | grep -q ':80 ' && apache_activo=1
            elif command -v lsof &>/dev/null; then
                lsof -i :80 -sTCP:LISTEN -t &>/dev/null && apache_activo=1
            fi

            if [ "$apache_activo" -eq 0 ]; then
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

aconsejar_ide() {
    local sugerencia=""
    local motivo=""

    # Lógica de recomendación cruzando Hardware + Perfil de uso
    if [ "$PERFIL_HARDWARE" = "Bajo" ]; then
        if [ "$PERFIL" -eq 2 ]; then
            sugerencia="Apache NetBeans"
            motivo="Tu equipo tiene recursos limitados. NetBeans es un IDE clásico de Java que consume significativamente menos memoria RAM que IntelliJ IDEA."
        else
            sugerencia="VSCodium o Neovim"
            motivo="Para entornos de bajos recursos, VSCodium prescinde de procesos pesados de telemetría. Si tus recursos son críticamente bajos, Neovim es la opción más fluida."
        fi
    else
        case $PERFIL in
            1)
                sugerencia="Visual Studio Code o Cursor"
                motivo="Cuentas con buen hardware. VS Code es el estándar para desarrollo Web, pero si buscas potenciar tu flujo con Inteligencia Artificial nativa, Cursor es el líder actual."
                ;;
            2)
                sugerencia="IntelliJ IDEA Community"
                motivo="Tienes recursos suficientes. IntelliJ es el rey indiscutible para Java profesional gracias a su motor avanzado de refactorización y autocompletado."
                ;;
            3)
                sugerencia="Visual Studio Code"
                motivo="Para desarrollo .NET en entornos multiplataforma, la combinación de VS Code junto al C# Dev Kit ofrece la experiencia más completa y ligera."
                ;;
            4)
                sugerencia="Visual Studio Code o Neovim"
                motivo="Para scripts y automatizaciones, VS Code con linters te avisará de errores antes de ejecutar. Si trabajas mucho por SSH en servidores, prioriza Neovim."
                ;;
        esac
    fi

    echo "------------------------------------------------------------------------------"
    pintar "💡 RECOMENDACIÓN INTELIGENTE:" "exito"
    echo "Basado en tu hardware ($PERFIL_HARDWARE) y tu perfil seleccionado, te aconsejamos usar: $sugerencia"
    echo "Motivo: $motivo"
    echo "------------------------------------------------------------------------------"
}


# ==============================================================================
# 📦 INSTALADOR UNIVERSAL SNAP CON AUTO-CONFIGURACIÓN EN CALIENTE
# ==============================================================================
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
        sudo zypper --non-interactive addrepo --refresh "https://opensuse.org{suse_ver}/" snappy 2>/dev/null
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
# ==============================================================================
# 🔄 FUNCIÓN PUENTE: INTENTO NATIVO CON DELEGACIÓN DE CONCEPTO
# ==============================================================================
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
            intellij) 
                brew install --cask intellij-idea-community
                COMANDO_ARRANQUE="open -a 'IntelliJ IDEA Community Edition'" ;;
            netbeans) 
                brew install --cask netbeans
                COMANDO_ARRANQUE="open -a 'NetBeans'" ;;
            vscode)   
                brew install --cask visual-studio-code
                COMANDO_ARRANQUE="open -a 'Visual Studio Code'" ;;
            vscodium) 
                brew install --cask vscodium
                COMANDO_ARRANQUE="open -a 'VSCodium'" ;;
            cursor)   
                brew install --cask cursor
                COMANDO_ARRANQUE="open -a 'Cursor'" ;;
            neovim)   
                brew install neovim
                COMANDO_ARRANQUE="nvim" ;;
        esac
    else
        # 3. Flujo de instalación para Linux
        case $IDE_NAME in
            intellij) 
                if [ "$OS" = "SUSE-based" ]; then
                    intentar_instalacion "zypper --non-interactive install intellij-idea-community" "intellij-idea-community"
                    [ "$COMANDO_ARRANQUE" != "snap run intellij-idea-community" ] && COMANDO_ARRANQUE="intellij-idea-community"
                else
                    instalar_via_snap "intellij-idea-community"
                    COMANDO_ARRANQUE="snap run intellij-idea-community"
                fi ;;
            netbeans) 
                if [ "$OS" = "SUSE-based" ]; then
                    intentar_instalacion "zypper --non-interactive install netbeans" "netbeans"
                    [ "$COMANDO_ARRANQUE" != "snap run netbeans" ] && COMANDO_ARRANQUE="netbeans"
                elif [ "$OS" = "Debian-based" ]; then
                    intentar_instalacion "apt-get install -y netbeans" "netbeans"
                    [ "$COMANDO_ARRANQUE" != "snap run netbeans" ] && COMANDO_ARRANQUE="netbeans"
                else
                    instalar_via_snap "netbeans"
                    COMANDO_ARRANQUE="snap run netbeans"  
                fi ;;
            vscode)
                if [ "$OS" = "Debian-based" ]; then
                    pintar "➜ Configurando repositorio oficial de Microsoft en Debian/Ubuntu..." "alerta"
                    $SUDO apt-get update && $SUDO apt-get install -y wget gpg
                    wget -qO- https://microsoft.com | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
                    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://microsoft.com stable main" | $SUDO tee /etc/apt/sources.list.dir/vscode.list > /dev/null
                    $SUDO apt-get update
                    intentar_instalacion "apt-get install -y code" "code"
                    [ "$COMANDO_ARRANQUE" != "snap run code" ] && COMANDO_ARRANQUE="code"
                elif [ "$OS" = "Fedora-based" ]; then
                    pintar "➜ Configurando repositorio oficial de Microsoft en Fedora..." "alerta"
                    $SUDO rpm --import https://microsoft.com
                    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://microsoft.com\nenabled=1\ngpgcheck=1\ngpgkey=https://microsoft.com" | $SUDO tee /etc/yum.repos.d/vscode.repo > /dev/null
                    intentar_instalacion "dnf install -y code" "code"
                    [ "$COMANDO_ARRANQUE" != "snap run code" ] && COMANDO_ARRANQUE="code"
                elif [ "$OS" = "Arch-based" ]; then
                    # Arch Linux incluye el binario libre 'code' en su repositorio oficial extra de la comunidad
                    $SUDO pacman -S --noconfirm code
                    COMANDO_ARRANQUE="code"
                elif [ "$OS" = "SUSE-based" ]; then
                    pintar "➜ Configurando repositorio oficial de Microsoft en openSUSE..." "alerta"
                    $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
                    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | $SUDO tee /etc/zypp/repos.d/vscode.repo > /dev/null
                    $SUDO zypper --gpg-auto-import-keys refresh
                    #$SUDO zypper --non-interactive install code
                    intentar_instalacion "zypper --non-interactive install code" "code"
                    [ "$COMANDO_ARRANQUE" != "snap run code" ] && COMANDO_ARRANQUE="code"
                fi ;;
            vscodium) 
                instalar_via_snap "codium"
                COMANDO_ARRANQUE="snap run codium"  ;;
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
                COMANDO_ARRANQUE="$HOME/Applications/cursor.appimage" ;;
            neovim) 
                $SUDO $INSTALL_CMD neovim 
                COMANDO_ARRANQUE="nvim" ;;
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

# ==============================================================================
# 🧠 NUEVO: CONSEJO AUTOMÁTICO ANTES DE LA ELECCIÓN
# ==============================================================================
aconsejar_ide

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
    #elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install nodejs npm python3-pip 2>/dev/null; fi
    # Cambia esto en el bloque de SUSE-based:
    elif [ "$OS" = "SUSE-based" ]; then 
        # Usamos 'nodejs-default' y 'npm-default' para que openSUSE mapee automáticamente la versión LTS activa
        $SUDO zypper --non-interactive install nodejs-default npm-default python3-pip 2>/dev/null
    fi
fi

configurar_plugins_ide

SEGUNDOS_FIN=$(date +"%s")
DURACION=$((SEGUNDOS_FIN - SEGUNDOS_INICIO))
pintar "🎉 ¡Entorno configurado con éxito en ${DURACION} segundos!" "exito"

echo "------------------------------------------------------------------------------"
pintar "🚀 CÓMO ARRANCAR TU NUEVO IDE:" "menu"
if [ -n "$COMANDO_ARRANQUE" ]; then
    echo "• Para iniciar el entorno inmediatamente desde esta terminal, ejecuta:"
    pintar "  $COMANDO_ARRANQUE" "exito"
fi
echo "• Si prefieres el modo gráfico, cierra sesión (Log out) y vuelve a entrar"
echo "  para que tu escritorio indexe el nuevo acceso directo en la tecla Windows."
echo "------------------------------------------------------------------------------"