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
# exec 3>&1 4>&2
# exec > >(tee -i "$LOG_FILE") 2>&1
# echo "📝 Grabando registro en: $LOG_FILE"

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

while true; do
    # ==========================================
    # 🛠️ SELECCIÓN DE HERRAMIENTA
    # ==========================================
    echo ""
    pintar "=== SELECCIONA HERRAMIENTA A EJECUTAR ===" "menu"
    echo "1) BACKUP (Realiza backups sencillos o de todo un entorno LAMP con su configuración)"
    echo "2) INSTALAR LAMP (Instala todo lo necesario para desarrollar con PHP y MySQL)"
    echo "3) DESINSTALAR LAMP (Para dejar el entorno limpio, cuidado si ya tienes algo configurado anteriormente)"
    echo "4) INSTALAR IDE (Ayuda a elejir el IDE más adecuado segun tu hardware y necesidades)"
    echo "5) DESINSTALAR IDE (Para dejar el entorno limpio, cuidado si ya tienes algo configurado anteriormente)"
    echo "6) CREAR WEB (Crea una web básica desde el framework que selecciones)"
    echo "7) BORRAR WEB (Para dejar el entorno limpio, cuidado si ya tienes algo configurado anteriormente)"
    echo "0) Salir del programa"
    read -p "$(pintar "Introduce una opción [1-7 Salir=0]: " "prompt" 0)" SELECCION

    # === PASO 1: VALIDAR LA SALIDA DIRECTA POR NÚMERO ===
    if [[ "$SELECCION" == "0" || -z "$SELECCION" ]]; then
        echo ""
        pintar "👋 ¡Saliendo del Panel Central! Que tengas un gran día." "exito"
        break # ROMPE EL BUCLE PRINCIPAL Y SE CIERRA DE VERDAD
    fi

    # === PASO 2: MAPEAR LAS HERRAMIENTAS REALES ===
    OPCION=""
    OPCION="salir"
    [ "$SELECCION" -eq 1 ] && OPCION="backupR"
    [ "$SELECCION" -eq 2 ] && OPCION="installamp"
    [ "$SELECCION" -eq 3 ] && OPCION="uninstallamp"
    [ "$SELECCION" -eq 4 ] && OPCION="instalide"
    [ "$SELECCION" -eq 5 ] && OPCION="uninstalide"
    [ "$SELECCION" -eq 6 ] && OPCION="creaweb"
    [ "$SELECCION" -eq 7 ] && OPCION="borraweb"

    # === PASO 3: VALIDACIÓN DE SEGURIDAD SI INTRODUCE OTRO NÚMERO ===
    if [ -z "$OPCION" ]; then
        pintar "Opción no válida. Inténtalo de nuevo." "error"
        echo ""
        read -p "$(pintar "Presiona [ENTER] para continuar..." "prompt" 0)" pausa
        continue # Salta el resto del bucle y vuelve a pintar el menú principal
    fi

    # === PASO 4: LANZAR LA HERRAMIENTA SELECCIONADA ===
    if [ -f "$DIR_SCRIPT/${OPCION}.sh" ]; then
        read -p "$(pintar "¿Deseas lanzar ${OPCION}.sh ahora? [S/n]: " "prompt" 0)" LANZAR
        LANZAR="${LANZAR:-S}" # Si pulsa ENTER directamente, asume que SÍ
        if [[ "$LANZAR" =~ ^[Ss]?$ ]]; then
            # 🔍 DETECCIÓN INTELIGENTE DE REQUISITO ROOT
            # Busca si el script exige que el invocador sea root (if ... -ne 0)
            if grep -qE "EUID.*-ne.*0|UID.*-ne.*0" "$DIR_SCRIPT/${OPCION}.sh"; then
                pintar "🔑 Ejecutando con sudo..." "alerta"
                sudo bash "$DIR_SCRIPT/${OPCION}.sh"
            else
                # Si el script gestiona sudo internamente, se ejecuta normal
                bash "$DIR_SCRIPT/${OPCION}.sh"
            fi
        fi
    else
        pintar "No se ha encontrado el archivo ${OPCION}.sh por favor, revise $DIR_SCRIPT" "error"
        pintar "Recuerde que puede descargar los archivos de https://github.com/rocacua/BACKUP" "alerta"
    fi

    # Pausa de cortesía para que el usuario pueda leer los mensajes finales antes de refrescar el menú
    echo ""
    read -p "$(pintar "Presiona [ENTER] para volver al Menú Central..." "prompt" 0)" pausa
done