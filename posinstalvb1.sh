#!/bin/bash

# Asegurar que se tienen privilegios elevados si es necesario
SUDO=$(command -v sudo)

# 1. Detectar el Sistema Operativo e ID_LIKE
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ALL_IDS="${ID} ${ID_LIKE}"
    ALL_IDS="${ALL_IDS,,}"
    OS_ID="${ID,,}"
else
    echo "❌ No se pudo detectar la distribución (falta /etc/os-release)."
    exit 1
fi

echo "🔍 Detectado sistema: $NAME ($OS_ID)"

# 2. Instalación según la distribución (Método Recomendado/Nativo)
if [[ "$ALL_IDS" =~ "ubuntu" || "$ALL_IDS" =~ "debian" || "$ALL_IDS" =~ "linuxmint" ]]; then
    echo "📦 Instalando Guest Additions vía APT..."
    $SUDO apt-get update
    # En Debian/Ubuntu se necesitan las utilidades y el módulo X11 si hay entorno gráfico
    $SUDO apt-get install -y virtualbox-guest-utils virtualbox-guest-x11

elif [[ "$ALL_IDS" =~ "arch" ]]; then
    echo "📦 Instalando Guest Additions vía PACMAN..."
    $SUDO pacman -Sy --noconfirm --needed virtualbox-guest-utils

elif [[ "$ALL_IDS" =~ "fedora" || "$ALL_IDS" =~ "rhel" || "$ALL_IDS" =~ "centos" ]]; then
    echo "📦 Instalando Guest Additions vía DNF..."
    # Fedora suele incluirlos por defecto, pero asegura su instalación completa
    $SUDO dnf install -y virtualbox-guest-additions

elif [[ "$ALL_IDS" =~ "suse" || "$ALL_IDS" =~ "opensuse" ]]; then
    echo "📦 Instalando Guest Additions vía ZYPPER..."
    $SUDO zypper install -y virtualbox-guest-tools virtualbox-guest-x11

else
    echo "⚠️ Distribución no soportada automáticamente por repositorios."
    echo "Se recomienda montar el CD de VirtualBox e instalar manualmente."
    exit 1
fi

# 3. Acciones Post-Instalación Críticas (Permisos de Carpetas Compartidas y Servicios)
echo "⚙️  Configurando entorno y permisos..."

# Añadir al usuario actual al grupo de carpetas compartidas para evitar el "Permiso denegado"
if getent group vboxsf > /dev/null; then
    $SUDO usermod -aG vboxsf "$USER"
    echo "✅ Usuario '$USER' añadido al grupo 'vboxsf' (Carpetas compartidas)."
fi

# Habilitar e iniciar el servicio en sistemas con systemd (Arch, Fedora, openSUSE lo requieren explícitamente)
if command -v systemctl &> /dev/null; then
    if systemctl list-unit-files | grep -q vboxservice; then
        $SUDO systemctl enable --now vboxservice.service
        echo "✅ Servicio 'vboxservice' activado e iniciado."
    fi
fi

echo ""
echo "🎉 ¡Instalación completada con éxito!"
echo "⚠️  IMPORTANTE: Debes reiniciar la máquina virtual para aplicar los cambios de resolución y permisos."
read -p "¿Quieres reiniciar el sistema ahora? (s/n): " RESP
if [[ "$RESP" =~ ^[Ss]$ ]]; then
    $SUDO reboot
fi
