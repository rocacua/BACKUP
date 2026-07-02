#!/bin/bash

# Asegurar privilegios elevados
SUDO=$(command -v sudo)

# 1. Detectar el Sistema Operativo e ID_LIKE
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}"
else
    echo "❌ No se pudo detectar la distribución."
    exit 1
fi

echo "🧹 Iniciando limpieza del sistema en: $NAME..."

# ==========================================
# 2. LIMPIEZA SEGÚN LA DISTRIBUCIÓN
# ==========================================
if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
    echo "🧼 Limpiando paquetes con APT..."
    $SUDO apt-get autoremove --purge -y
    $SUDO apt-get clean
    $SUDO rm -rf /var/lib/apt/lists/* # Opcional: descarga las listas para ahorrar más espacio

elif [[ "$ALL_IDS" =~ "arch" ]]; then
    echo "🧼 Limpiando paquetes con PACMAN..."
    # Elimina todos los paquetes huérfanos
    if pacman -Qdt &>/dev/null; then
        $SUDO pacman -Rns $(pacman -Qdtq) --noconfirm
    fi
    $SUDO pacman -Scc --noconfirm # Limpia la caché completa de descargas

elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
    echo "🧼 Limpiando paquetes con DNF..."
    $SUDO dnf autoremove -y
    $SUDO dnf clean all

elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
    echo "🧼 Limpiando paquetes con ZYPPER..."
    $SUDO zypper clean -a
fi

# ==========================================
# 3. LIMPIEZA GENÉRICA DE ESPACIO Y LOGS
# ==========================================
echo "🧹 Vaciando logs antiguos y cachés del sistema..."
$SUDO rm -rf /var/cache/* 2>/dev/null || true
$SUDO rm -rf /home/*/.cache/* 2>/dev/null || true

# Rotar y vaciar logs de Systemd para que la instantánea ocupe menos megabytes
if command -v journalctl &> /dev/null; then
    $SUDO journalctl --vacuum-time=1d &>/dev/null || true
fi

# ==========================================
# 4. RESTABLECER RESOLUCIÓN DE LA PANTALLA
# ==========================================
echo "Configurando resolución de pantalla a 1280x800..."
TARGET_RES="1280x800"

# Detectar el servidor gráfico actual (Wayland o X11)
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    # Intento para entornos GNOME modernos (Ubuntu, Debian, Fedora con Wayland)
    if command -v gnome-randr &> /dev/null; then
        gnome-randr --res $TARGET_RES
    # Intento para entornos KDE modernos con Wayland
    elif command -v kscreen-doctor &> /dev/null; then
        kscreen-doctor output.requested.mode.$TARGET_RES
    else
        echo "⚠️  Wayland detectado. Si la resolución no cambió, ajústala manualmente en Configuración > Pantalla."
        exit 1
    fi
else
    # Servidor X11 / Xorg (Linux Mint, escritorios XFCE, Mate, Cinnamon, etc.)
    if command -v xrandr &> /dev/null; then
        # Obtener el nombre de la pantalla conectada dinámicamente
        SCREEN=$(xrandr | grep " connected" | awk '{print $1}' | head -n 1)

        # CORRECCIÓN DE SINTAXIS: Usamos ! -z en lugar de -not -z
        if [ ! -z "$SCREEN" ]; then
            xrandr --output "$SCREEN" --mode $TARGET_RES
        else
            # Si falla la autodetección en VirtualBox, forzamos el nombre estándar de la VM
            xrandr --output "Virtual1" --mode $TARGET_RES 2>/dev/null || \
            xrandr --output "VGA-1" --mode $TARGET_RES 2>/dev/null
        fi
    else
        echo "⚠️  No se encontró xrandr. Por favor, cambia la resolución manualmente."
        exit 1
    fi
fi

# ==========================================
# 5. APAGADO LIMPIO E INMEDIATO
# ==========================================
echo "🛑 Apagando el sistema de forma limpia en 5 segundos..."
echo "Cuando la máquina se apague por completo, ya puedes tomar tu instantánea en VirtualBox."
sleep 5

$SUDO poweroff
