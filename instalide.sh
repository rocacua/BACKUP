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
                    read -p "$(pintar "¿Deseas lanzar installamp.sh ahora para instalar tu entorno LAMP? [S/n]: " "prompt" 0)" LANZAR_LAMP
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
                #elif [ "$OS" = "Debian-based" ]; then $SUDO apt-get update && $SUDO apt-get install -y dotnet-sdk-8.0
                elif [ "$OS" = "Debian-based" ]; then
                    # Solución específica para Debian 13 Testing (Trixie)
                    if lsb_release -c 2>/dev/null | grep -q "trixie" || grep -q "trixie" /etc/os-release; then
                        pintar "➜ Detectado Debian 13 (Trixie). Usando instalador oficial de Microsoft..." "alerta"
                        asegurar_curl  # <- Se instala solo aquí si es necesario
                        # Crear el directorio con sudo antes de instalar
                        $SUDO mkdir -p /usr/share/dotnet
                        # Descarga y ejecuta el script oficial de binarios de Microsoft
                        curl -sSL https://dot.net/v1/dotnet-install.sh | $SUDO bash /dev/stdin --channel 8.0 --install-dir /usr/share/dotnet
                        # Enlace simbólico global para que 'dotnet' funcione en cualquier terminal
                        $SUDO ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet
                    else
                        $SUDO apt-get update && $SUDO apt-get install -y dotnet-sdk-8.0
                    fi
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
        #sudo zypper --non-interactive addrepo --refresh "https://opensuse.org${suse_ver}/" snappy 2>/dev/null
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
asegurar_curl() {
    if ! command -v curl &>/dev/null; then
        pintar "➜ Esta acción requiere 'curl'. Instalando dependencia..." "alerta"
        if [ "$OS" = "macOS" ]; then brew install curl
        elif [ "$OS" = "Debian-based" ]; then $SUDO apt-get update && $SUDO apt-get install -y curl
        elif [ "$OS" = "Fedora-based" ]; then $SUDO dnf install -y curl
        elif [ "$OS" = "Arch-based" ]; then $SUDO pacman -S --noconfirm curl
        elif [ "$OS" = "SUSE-based" ]; then $SUDO zypper --non-interactive install curl; fi
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
            eclipse)
                intentar_instalacion "brew install --cask eclipse-jee" "eclipse"
                COMANDO_ARRANQUE="open -a Eclipse" ;;
            android-studio)
                intentar_instalacion "brew install --cask android-studio" "android-studio"
                COMANDO_ARRANQUE="open -a 'Android Studio'" ;;
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
                    intentar_instalacion "zypper --non-interactive install netbeans" "netbeans --classic"
                    [ "$COMANDO_ARRANQUE" != "snap run netbeans" ] && COMANDO_ARRANQUE="netbeans"
                elif [ "$OS" = "Debian-based" ]; then
                    intentar_instalacion "apt-get install -y netbeans" "netbeans --classic"
                    [ "$COMANDO_ARRANQUE" != "snap run netbeans" ] && COMANDO_ARRANQUE="netbeans"
                else
                    instalar_via_snap "netbeans --classic"
                    COMANDO_ARRANQUE="snap run netbeans"  
                fi ;;
            vscode)
                if [ "$OS" = "Debian-based" ]; then
                    pintar "➜ Configurando repositorio oficial de Microsoft en Debian/Ubuntu..." "alerta"
                    $SUDO apt-get update && $SUDO apt-get install -y wget gpg
                    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | $SUDO tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
                    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list > /dev/null
                    $SUDO apt-get update
                    intentar_instalacion "apt-get install -y code" "code"
                    [ "$COMANDO_ARRANQUE" != "snap run code" ] && COMANDO_ARRANQUE="code"
                elif [ "$OS" = "Fedora-based" ]; then
                    pintar "➜ Configurando repositorio oficial de Microsoft en Fedora..." "alerta"
                    $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
                    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | $SUDO tee /etc/yum.repos.d/vscode.repo > /dev/null
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
                if [ "$OS" = "Debian-based" ]; then
                    pintar "➜ Configurando repositorio oficial de VSCodium en Debian/Ubuntu..." "alerta"
                    $SUDO apt-get update && $SUDO apt-get install -y wget gpg
                    # Descarga de clave y configuración oficial del repositorio de PaulCarroty (CDN de VSCodium)
                    wget -qO- https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg | gpg --dearmor | $SUDO tee /usr/share/keyrings/vscodium-archive-keyring.gpg > /dev/null
                    echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" | $SUDO tee /etc/apt/sources.list.d/vscodium.list > /dev/null
                    $SUDO apt-get update
                    intentar_instalacion "apt-get install -y codium" "codium"
                    [ "$COMANDO_ARRANQUE" != "snap run codium" ] && COMANDO_ARRANQUE="codium"
                elif [ "$OS" = "Fedora-based" ]; then
                    pintar "➜ Configurando repositorio oficial de VSCodium en Fedora..." "alerta"
                    $SUDO rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
                    echo -e "[vscodium]\nname=VSCodium\nbaseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/\nenabled=1\ngpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg" | $SUDO tee /etc/yum.repos.d/vscodium.repo > /dev/null
                    intentar_instalacion "dnf install -y codium" "codium"
                    [ "$COMANDO_ARRANQUE" != "snap run codium" ] && COMANDO_ARRANQUE="codium"
                elif [ "$OS" = "SUSE-based" ]; then
                    pintar "➜ Configurando repositorio oficial de VSCodium en openSUSE..." "alerta"
                    $SUDO rpm --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg
                    echo -e "[vscodium]\nname=VSCodium\nbaseurl=https://paulcarroty.gitlab.io/vscodium-deb-rpm-repo/rpms/\nenabled=1\ngpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg" | $SUDO tee /etc/zypp/repos.d/vscodium.repo > /dev/null
                    $SUDO zypper --gpg-auto-import-keys refresh
                    intentar_instalacion "zypper --non-interactive install codium" "codium"
                    [ "$COMANDO_ARRANQUE" != "snap run codium" ] && COMANDO_ARRANQUE="codium"
                else
                    # Fallback universal para otros sistemas usando confinamiento clásico para evitar problemas con compiladores
                    instalar_via_snap "codium --classic"
                    COMANDO_ARRANQUE="snap run codium"  
                fi 
                ;;
            cursor)
                # Invocar la función antes de empezar las descargas de Cursor
                asegurar_curl
                # MODIFICACIÓN DINÁMICA DE URLS SEGÚN LA DISTRIBUCIÓN (¡Aporte excelente!)
                if [ "$OS" = "Debian-based" ]; then
                    # Esperar y liberar de forma inteligente el candado de apt
                    if $SUDO fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
                        pintar "➜ Detectado gestor de paquetes ocupado. Intentando liberar..." "alerta"
                        # Forzar la terminación de cualquier proceso apt/dpkg colgado en segundo plano
                        $SUDO killall apt apt-get dpkg 2>/dev/null
                        sleep 2
                        # Eliminar los archivos de bloqueo residuales si persisten
                        $SUDO rm -f /var/lib/dpkg/lock-frontend
                        $SUDO rm -f /var/lib/apt/lists/lock
                        $SUDO rm -f /var/cache/apt/archives/lock
                        # Reparar posibles instalaciones interrumpidas
                        DEBIAN_FRONTEND=noninteractive $SUDO dpkg --configure -a
                    fi
                    pintar "➜ Descargando paquete oficial .deb de Cursor..." "alerta"
                    #curl -L "https://api2.cursor.sh/updates/download/golden/linux-x64-deb/cursor/3.8" -o "$HOME/Applications/cursor.appimage"      
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}-deb/cursor/latest" -o /tmp/cursor.deb
                    #$SUDO apt-get update && $SUDO apt-get install -y /tmp/cursor.deb
                    # Definimos la interfaz como no interactiva y aceptamos el repositorio de forma automática
                    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" /tmp/cursor.deb
                    rm -f /tmp/cursor.deb
                    # Al ser nativo .deb, el comando global instalado en el sistema es 'cursor'
                    COMANDO_ARRANQUE="cursor"
                elif [ "$OS" = "Fedora-based" ]; then
                    pintar "➜ Descargando paquete oficial .rpm de Cursor..." "alerta"
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}-rpm/cursor/latest" -o /tmp/cursor.rpm
                    $SUDO dnf install -y /tmp/cursor.rpm
                    rm -f /tmp/cursor.rpm
                    # Al ser nativo .rpm, el comando global instalado en el sistema es 'cursor'
                    COMANDO_ARRANQUE="cursor"
                else
                    # Para Arch, SUSE u otros, descargamos el AppImage limpio usando la URL directa
                    pintar "➜ Descargando Cursor oficial en formato AppImage..." "alerta"
                    mkdir -p "$HOME/Applications"
                    curl -L "https://api2.cursor.sh/updates/download/golden/linux-${ARCH}/cursor/latest" -o "$HOME/Applications/cursor.appimage"
                    chmod +x "$HOME/Applications/cursor.appimage"
                    pintar "✓ Cursor AppImage listo en $HOME/Applications/cursor.appimage" "exito"
                    # Solo en este caso el comando de arranque apunta a la ruta local del AppImage
                    COMANDO_ARRANQUE="$HOME/Applications/cursor.appimage"
                fi
                ;;
            neovim) 
#                if [ "$OS" = "Debian-based" ]; then
#                    pintar "➜ Descargando última versión estable de Neovim (AppImage oficial)..." "alerta"
#                    # Se descarga el binario precompilado oficial de GitHub para evitar paquetes APT obsoletos
#                    $SUDO wget -qO /usr/local/bin/nvim https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage 2>/dev/null
#                    if [ $? -eq 0 ] && [ -s /usr/local/bin/nvim ]; then
#                        # Hacer el archivo ejecutable de forma directa
#                        $SUDO chmod +x /usr/local/bin/nvim
#                        # Guardar el comando de arranque e informar del éxito
#                        COMANDO_ARRANQUE="nvim"
#                        pintar "✓ Neovim AppImage instalado con éxito en /usr/local/bin/nvim" "exito"
#                    else
#                        # Si falla la descarga, borramos el rastro y saltamos al gestor de paquetes nativo
#                        $SUDO rm -f /usr/local/bin/nvim
#                        pintar "⚠ Falló la descarga del AppImage. Instalando vía gestor de paquetes nativo..." "alerta"
#                        
#                        #intentar_instalacion "apt-get install -y neovim" "neovim"
#                        intentar_instalacion "apt-get install -y --no-install-recommends neovim" "neovim"
#                        [ "$COMANDO_ARRANQUE" != "snap run neovim" ] && COMANDO_ARRANQUE="nvim"
#                    fi
#                else
#                    # Fedora, Arch y SUSE sí mantienen versiones de Neovim muy actualizadas en sus repos nativos
#                    intentar_instalacion "$INSTALL_CMD neovim" "neovim"
#                    [ "$COMANDO_ARRANQUE" != "snap run neovim" ] && COMANDO_ARRANQUE="nvim"
#                fi
#                ;;
                # Si es Debian o openSUSE, usamos AppImage para evitar paquetes corruptos o bloqueos de dependencias
                if [ "$OS" = "Debian-based" ] || [ -f /usr/bin/zypper ]; then
                    pintar "➜ Descargando última versión estable de Neovim (AppImage oficial)..." "alerta"
                    # Descarga directa del binario precompilado oficial de GitHub
                    $SUDO wget -qO /usr/local/bin/nvim https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage 2>/dev/null
                    
                    if [ $? -eq 0 ] && [ -s /usr/local/bin/nvim ]; then
                        $SUDO chmod +x /usr/local/bin/nvim
                        COMANDO_ARRANQUE="nvim"
                        # ENLACE SIMBÓLICO DE SALVAGUARDA: 
                        # Si existía un binario roto o el sistema busca en /usr/bin, lo redirigimos al AppImage
                        $SUDO ln -sf /usr/local/bin/nvim /usr/bin/nvim 2>/dev/null
                        pintar "✓ Neovim AppImage instalado con éxito en /usr/local/bin/nvim" "exito"
                    else
                        $SUDO rm -f /usr/local/bin/nvim
                        pintar "⚠ Falló la descarga del AppImage. Intentando instalación nativa..." "alerta"
                        
                        if [ -f /usr/bin/zypper ]; then
                            intentar_instalacion "zypper in -y neovim" "neovim"
                        else
                            intentar_instalacion "apt-get install -y --no-install-recommends neovim" "neovim"
                        fi
                        [ "$COMANDO_ARRANQUE" != "snap run neovim" ] && COMANDO_ARRANQUE="nvim"
                    fi
                else
                    # Fedora y Arch mantienen versiones muy actualizadas y limpias en sus repos nativos
                    local CMD_FINAL=""
                    if [ -f /usr/bin/dnf ]; then
                        CMD_FINAL="dnf install -y --setopt=install_weak_deps=False neovim"
                    else
                        CMD_FINAL="$INSTALL_CMD neovim"
                    fi

                    intentar_instalacion "$CMD_FINAL" "neovim"
                    [ "$COMANDO_ARRANQUE" != "snap run neovim" ] && COMANDO_ARRANQUE="nvim"
                fi
                ;;

            eclipse)
                if [ "$OS" = "Debian-based" ] || [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ]; then
                    pintar "➜ Instalando Eclipse de forma universal vía Snap..." "alerta"
                    # Eclipse requiere confinamiento clásico para poder compilar y leer proyectos del disco duro
                    instalar_via_snap "eclipse --classic"
                    COMANDO_ARRANQUE="snap run eclipse"
                elif [ "$OS" = "Arch-based" ]; then
                    # Arch Linux mantiene Eclipse actualizado de forma nativa en sus repositorios principales
                    pintar "➜ Instalando Eclipse nativo en Arch Linux..." "alerta"
                    intentar_instalacion "pacman -S --noconfirm eclipse-java" "eclipse"
                    COMANDO_ARRANQUE="eclipse"
                else
                    pintar "⚠ Sistema operativo no compatible para la instalación automática de Eclipse." "error"
                fi
                ;;
            android-studio)
                if [ "$OS" = "Debian-based" ] || [ "$OS" = "Fedora-based" ] || [ "$OS" = "SUSE-based" ]; then
                    pintar "➜ Instalando Android Studio de forma universal vía Snap..." "alerta"
                    # Requiere --classic para poder interactuar con los dispositivos USB conectados (teléfonos reales)
                    instalar_via_snap "android-studio --classic"
                    COMANDO_ARRANQUE="snap run android-studio"
                elif [ "$OS" = "Arch-based" ]; then
                    pintar "➜ Instalando Android Studio desde el repositorio nativo en Arch Linux..." "alerta"
                    # Arch sí lo empaqueta de forma comunitaria excelente
                    intentar_instalacion "pacman -S --noconfirm android-studio" "android-studio"
                    COMANDO_ARRANQUE="android-studio"
                else
                    pintar "⚠ Sistema operativo no compatible para la instalación de Android Studio." "error"
                fi
                ;;


        esac
    fi
}


configurar_plugins_ide() {
    # 1. Bloque unificado para editores basados en el motor de VS Code (Code, Codium, Cursor)
    if [ "$IDE_NAME" = "vscode" ] || [ "$IDE_NAME" = "vscodium" ] || [ "$IDE_NAME" = "cursor" ]; then
        
        # Mapeo por defecto de comandos binarios
        BIN_CMD="code"
        [ "$IDE_NAME" = "vscodium" ] && BIN_CMD="codium"
        
        if [ "$IDE_NAME" = "cursor" ]; then
            # Buscar el comando de consola de Cursor en las rutas habituales del sistema
            if command -v cursor &> /dev/null; then
                BIN_CMD="cursor"
            elif [ -f "/usr/local/bin/cursor" ]; then
                BIN_CMD="/usr/local/bin/cursor"
            elif [ "$OS" = "macOS" ] && [ -f "/Applications/Cursor.app/Contents/Resources/app/bin/code" ]; then
                # Truco de Mac: Acceder al binario interno de la app aunque no esté en el PATH
                BIN_CMD="/Applications/Cursor.app/Contents/Resources/app/bin/code"
            else
                BIN_CMD=""
            fi
        fi

         # CORRECCIÓN: Validar de forma inteligente si es un comando del PATH o una ruta ejecutable directa
        IS_VALID=0
        if [ -n "$BIN_CMD" ]; then
            if [[ "$BIN_CMD" == /* ]]; then
                # Si empieza por /, es una ruta absoluta: verificamos si existe y es ejecutable
                [ -x "$BIN_CMD" ] && IS_VALID=1
            else
                # Si es un comando simple, usamos command -v de forma segura
                command -v "$BIN_CMD" &> /dev/null && IS_VALID=1
            fi
        fi

        # Si encontramos una vía de comunicación con la CLI del IDE elegido
        if [ "$IS_VALID" -eq 1 ]; then
            pintar "➜ Inyectando plugins del perfil elegido en $IDE_NAME..." "menu"
            
            if [ "$IA_LOCAL_INSTALADA" = "SI" ]; then
                [ "$IDE_NAME" != "cursor" ] && $BIN_CMD --install-extension Continue.continue >/dev/null
            else
                # Solo instalamos Codeium si NO es Cursor (Cursor ya trae su propia IA integrada de fábrica)
                [ "$IDE_NAME" != "cursor" ] && $BIN_CMD --install-extension Codeium.codeium >/dev/null
            fi
            
            case $PERFIL in
                1)  $BIN_CMD --install-extension xdebug.php-debug >/dev/null 2>&1
                    # if [ "$IDE_NAME" = "vscode" ]
                    #     $BIN_CMD --install-extension bmewburn.vscode-langserver-php >/dev/null
                    # else
                    #     $BIN_CMD --install-extension bmewburn.vscode-intelephense-client >/dev/null
                    # fi
                    $BIN_CMD --install-extension bmewburn.vscode-intelephense-client >/dev/null 2>&1
                    $BIN_CMD --install-extension dbaeumer.vscode-eslint >/dev/null 2>&1
                    $BIN_CMD --install-extension esbenp.prettier-vscode >/dev/null 2>&1 ;;
                2)  $BIN_CMD --install-extension vscjava.vscode-java-pack >/dev/null 2>&1 ;;
                3)  $BIN_CMD --install-extension ms-dotnettools.csharp >/dev/null 2>&1 ;;
                    #$BIN_CMD --install-extension ms-dotnettools.csdevkit >/dev/null ;;                    
                4)  $BIN_CMD --install-extension timonwong.shellcheck >/dev/null 2>&1
                    $BIN_CMD --install-extension mads-hartmann.bash-checker >/dev/null 2>&1 ;;
            esac
            pintar "✓ Plugins inyectados correctamente en $IDE_NAME." "exito"
        else
            if [ "$IDE_NAME" = "cursor" ]; then
                pintar "⚠ No se pudo inyectar las extensiones de forma automática en Cursor." "alerta"
                pintar "➜ Abre Cursor, pulsa Ctrl+Shift+P, ejecuta 'Install cursor command' y relanza el script." "info"
            fi
        fi
    elif [ "$IDE_NAME" = "android-studio" ]; then
        # Filtrar para que la configuración de KVM solo se ejecute en Linux
        if [ "$OS" != "macOS" ]; then
             pintar "➜ Configurando aceleración por hardware (KVM) para el emulador de Android..." "alerta"
                    
            # 1. Instalar los paquetes de virtualización según la distribución
            if [ "$OS" = "Debian-based" ]; then
                $SUDO apt-get update && $SUDO apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
            elif [ "$OS" = "Fedora-based" ]; then
                $SUDO dnf install -y qemu-kvm libvirt virt-install
            elif [ "$OS" = "SUSE-based" ]; then
                $SUDO zypper --non-interactive install qemu-kvm libvirt
            elif [ "$OS" = "Arch-based" ]; then
                $SUDO pacman -S --noconfirm qemu-desktop libvirt
            fi

            # 2. Habilitar y arrancar el servicio de virtualización de inmediato
            $SUDO systemctl enable --now libvirtd 2>/dev/null

            # 3. Añadir el usuario actual al grupo kvm y libvirt para que tenga permisos sin ser root
            # Usamos USER_REAL o el usuario actual si no se ejecuta bajo sudo directo
            USUARIO_ACTUAL="${SUDO_USER:-$USER}"
            
            $SUDO usermod -aG kvm "$USUARIO_ACTUAL" 2>/dev/null
            $SUDO usermod -aG libvirt "$USUARIO_ACTUAL" 2>/dev/null

            pintar "✓ Dependencias de hardware configuradas." "exito"
            pintar "⚠ NOTA: Para que el emulador funcione, es posible que debas reiniciar tu sesión de usuario." "alerta"
        fi
    fi
}

instalar_git() {
    if ! command -v git &>/dev/null; then
        pintar "Git no está instalado. Es aconsejable para compartir archivos." "alerta"
        echo -ne "$(pintar "¿Desea instalar Git? [S|n]: " "prompt" 0)"
        read -r instala_git
        instala_git=${instala_git:-"s"}
        if [[ "$instala_git" =~ ^[Ss]$ ]] || [[ -z "$instala_git" ]]; then
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
            pintar "No se instalará Git" "alerta"
        fi
    else
        pintar "Git ya está disponible en el sistema ($(git --version))." "exito"
    fi
}

instalar_ia_local() {
    [ "$APTO_IA_LOCAL" = "NO" ] && return 0
    [[ "$IDE_NAME" != "vscode" && "$IDE_NAME" != "vscodium" ]] && return 0
    if [[ "$APTO_IA_LOCAL" == "MINIMO" ]]; then
        pintar "Tu equipo puede ir lento si instalas IA" "alerta"
    else
        pintar "Tu equipo debería ir ligero aun que instales IA, si no abres muchos procesos." "alerta"
    fi
    echo ""
    pintar "=== CONFIGURACIÓN DE IA EN LOCAL ===" "menu"
    read -p "$(pintar "¿Instalar asistente IA local (Ollama+Qwen)?: [s/N]: " "prompt" 0)" RESPUESTA_IA
    if [[ "$RESPUESTA_IA" =~ ^[Ss]$ ]]; then
        asegurar_curl  # <- Asegura curl justo antes del script de Ollama
        curl -fsSL https://ollama.com/install.sh | sh
        if command -v ollama &>/dev/null; then
            ollama run qwen2.5-coder:1.5b --nowait >/dev/null 2>&1 &
            IA_LOCAL_INSTALADA="SI"
            pintar "✓ IA instalándose. Usa 'Continue' en el IDE." "exito"
        fi
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
read -p "$(pintar "Introduce una opción [1-4]: " "prompt" 0)" PERFIL

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
    echo "1) IntelliJ IDEA Community Edition (El rey de Java: autocompletado inteligente y moderno)"
    echo "2) Apache NetBeans (Clásico y robusto: integración oficial excelente con Maven/Gradle)"
    echo "3) Eclipse (Veterano y ultrapotente: ideal para proyectos grandes y entornos empresariales)"
    echo "4) Visual Studio Code (Ligero y modular: requiere extensiones de Java para brillar)"
    echo "5) Android Studio (El entorno oficial de Google para crear aplicaciones Android móviles)"
else
    echo "1) Visual Studio Code (Oficial)"
    echo "2) VSCodium (Código abierto sin telemetría)"
    echo "3) Cursor (IDE enfocado a IA)"
    echo "4) Neovim (Terminal ligero)"
fi
echo "0) Salir"
read -p "$(pintar "Elige una opción [0-5]: " "prompt" 0)" SELECCION

IDE_NAME="salir"
if [ "$PERFIL" -eq 2 ]; then
    [ "$SELECCION" -eq 1 ] && IDE_NAME="intellij"
    [ "$SELECCION" -eq 2 ] && IDE_NAME="netbeans"
    [ "$SELECCION" -eq 3 ] && IDE_NAME="eclipse"
    [ "$SELECCION" -eq 4 ] && IDE_NAME="vscode"
    [ "$SELECCION" -eq 5 ] && IDE_NAME="android-studio"
else
    [ "$SELECCION" -eq 1 ] && IDE_NAME="vscode"
    [ "$SELECCION" -eq 2 ] && IDE_NAME="vscodium"
    [ "$SELECCION" -eq 3 ] && IDE_NAME="cursor"
    [ "$SELECCION" -eq 4 ] && IDE_NAME="neovim"
fi
if [ "$IDE_NAME" = "salir" ]; then exit 0; fi

# 1. Ejecutar instalación de IA si procede
instalar_ia_local

# 2. Instalar el entorno de desarrollo elegido
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
# Recordatorio dinámico si instalaron Ollama
if [ "$IA_LOCAL_INSTALADA" = "SI" ]; then
    pintar "🤖 IA LOCAL ACTIVA: Al abrir tu editor, verás la pestaña 'Continue'." "info"
    echo "  El modelo Qwen2.5-Coder se está descargando en segundo plano."
fi
echo "------------------------------------------------------------------------------"