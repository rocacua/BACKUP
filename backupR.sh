#!/usr/bin/env bash
set -euo pipefail
 # !/bin/bash
start_time_total=`date +"%T"`
start_time=`date +"%T"`
date
echo "##################################################INI##################################################"
clear
# ==============================
#CONSTANTES
# ==============================
declare -r DIR_ACTUAL=$(pwd)
declare -r DIR_SCRIPT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
declare -r DIR_USUARIO=$(eval echo ~$USER)
declare -r EQUIPO=$(hostname)
declare -r USUARIO="$USER"
declare -r FECHA=$(date +%Y-%m-%d)

# ==============================
#Variables globales
# ==============================
opcion=-1 # opción inicializada a -1
opcion2=-1
opcion3=-1
nom_origen=""
dirorigen=$DIR_USUARIO
dirdestino=$DIR_SCRIPT
dirsincompatibles=0
formato_origen=""
formato_destino=""
espacio_origen_bytes=0
espacio_destino_bytes=0
espacio_origen=""
espacio_destino=""
sinespacio=0
formatoinadecuado=0
permisosincorrectos=0
superuser='n'
confirmacion='n'
fecha=$(date +%Y-%m-%d_%H-%M-%S)
logfile="$DIR_SCRIPT/logs/BACKUP-${fecha}.log"
prueba_rsync=""
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


# ==============================
# UTILIDADES
# ==============================
# ini log
log(){
	#printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*" | tee -a "$logfile";
	# 1. Crea el mensaje con la fecha y hora
	#local mensaje="[$(date --iso-8601=seconds)] $*"
	# 2. Lo muestra en pantalla tal cual (con colores)
	#echo -e "$mensaje"
	# 3. Borra los códigos de color y lo guarda en el archivo
	#echo -e "$mensaje" | sed 's/\x1b\[[0-9;]*m//g' >> "$logfile"
	# 1. Recibir los datos de la función
	# 1. Averiguar cuántos argumentos pasaron al comando
	local num_args=$#
	local tipo="normal"
	local texto=""

	# 2. Si hay más de un argumento, comprobamos si el último es un tipo válido
	if [ $num_args -gt 1 ]; then
    	# Tomamos el último argumento de la lista
    	local ultimo_arg="${!num_args}"
    	if [[ "$ultimo_arg" =~ ^(error|exito|alerta|menu|prompt)$ ]]; then
        	tipo="$ultimo_arg"
        	# Quitamos el último argumento para que no se sume al texto
        	set -- "${@:1:$((num_args - 1))}"
    	fi
	fi

	# 3. Ahora $* contiene todas las cadenas de texto juntas
	texto="$*"

	# 4. Seleccionar el color y la etiqueta
	local color=""
	local etiqueta=""
	case "$tipo" in
    	"error")  color="$ROJO"; 	etiqueta="[ERROR] " ;;
    	"exito")  color="$VERDE";	etiqueta="[OK] " ;;
    	"alerta") color="$AMARILLO"; etiqueta="[ALERTA] " ;;
    	"menu")   color="$CIAN_B";   etiqueta="[MENU] " ;;
    	"prompt")   color="$MAGENTA_B";   etiqueta="[PREGUNTA] " ;;
    	*)    	color="$NC";   	etiqueta="" ;;
	esac

	# 5. Crear mensajes y guardar/mostrar
	local marca_tiempo="[$(date --iso-8601=seconds)]"
    
	if [ "$tipo" = "error" ]; then
    	echo -e "${color}${etiqueta}${texto}${NC}" >&2  # Envia al canal de errores
	else
    	echo -e "${color}${etiqueta}${texto}${NC}"  	# Envia al canal normal
	fi
	echo "$marca_tiempo ${etiqueta}${texto}" >> "$logfile"
}
# fin log
# ==============================
# ini pintar
pintar() {
	local texto="$1"
	local tipo="${2:-normal}"
	local color=""
	local etiqueta=""

	# 1. Seleccionar color y etiqueta según el tipo
	case "$tipo" in
    	"error")   color="$ROJO"; 	etiqueta="[ERROR] " ;;
    	"exito")   color="$VERDE";	etiqueta="[OK] " ;;
    	"alerta")  color="$AMARILLO"; etiqueta="[ALERTA] " ;; # Cambiado a PREGUNTA para el log
    	"menu")	color="$CIAN_B";   etiqueta="[MENU] " ;;
    	"prompt")   color="$MAGENTA_B";   etiqueta="[PREGUNTA] " ;;
    	*)     	color="$NC";   	etiqueta="" ;;
	esac

	# 2. Guardar silenciosamente en el log con su marca de tiempo
	local marca_tiempo="[$(date --iso-8601=seconds)]"
	echo "$marca_tiempo ${etiqueta}${texto}" >> "$logfile"

	# 3. Enviar el texto con color a la pantalla
	# Usamos printf en vez de echo para que funcione correctamente dentro de $(...)
	printf '%b' "${color}${texto}${NC}"
}
# fin pintar
# ==============================
# ini reiniciar_variables
reiniciar_variables() {
	opcion=-1 # opción inicializada a -1
	opcion2=-1
	opcion3=-1
	nom_origen=""
	dirorigen=$DIR_USUARIO
	dirdestino=$DIR_SCRIPT
	dirsincompatibles=0
	formato_origen=""
	formato_destino=""
	espacio_origen_bytes=0
	espacio_destino_bytes=0
	espacio_origen=""
	espacio_destino=""
	sinespacio=0
	formatoinadecuado=0
	permisosincorrectos=0
	superuser='n'
	confirmacion='n'
	fecha=$(date +%Y-%m-%d_%H-%M-%S)
	logfile="$DIR_SCRIPT/logs/BACKUP-${fecha}.log"
	#prueba_rsync=""
}
# fin reiniciar_variables
# ==============================
# ini terminar_con_error
# --- 1. FUNCIÓN CENTRALIZADA DE LIMPIEZA Y SALIDA ---
terminar_con_error() {
	local mensaje="${1:-"Se ha producido un error crítico inesperado."}"
	local codigo_salida="${2:-1}"

	echo "" >&2
	log "[ERROR CRÍTICO]: $mensaje" "error"
    
	# === LÓGICA DE LIMPIEZA GENERAL ===
	log "[*] Ejecutando limpieza antes de salir..."
	# Ejemplo: rm -rf "$DIR_TEMPORAL"
	reiniciar_variables
    
	log "[-] Script abortado correctamente."
	if [[ -t 0 ]]; then
    	read -p "$(pintar "Pulse una tecla para salir..." "prompt")"
	fi
	exit "$codigo_salida"
}
# --- 2. REGISTRAR UN TRAP DE EMERGENCIA (OPCIONAL PERO RECOMENDADO) ---
# Si cualquier comando imprevisto falla y activa el 'set -e', este trap
# interceptará el fallo y llamará a nuestra función en lugar de morir abruptamente.
trap 'terminar_con_error "El script falló inesperadamente en la línea $LINENO." $?' ERR
# fin terminar_con_error
# ==============================
# ini validar_herramientas
validar_herramientas() {
	#Detecta plataforma
	osname=$(uname -s)
	log "Plataforma $osname"
	case "$osname" in
	Linux)   is_linux=1 ;;
	Darwin)  is_darwin=1 ;;
	FreeBSD) is_bsd=1 ;;
	*)   	is_other=1 ;;
	esac
	#Validar herramientas
	command -v rsync >/dev/null || { log "rsync no instalado" "error"; terminar_con_error; }
	#command -v mysql >/dev/null || { echo -e "${ROJO}mysql no instalado${NC}"; terminar_con_error; }
	#command -v mysqldump >/dev/null || { echo -e "${ROJO}mysqldump no instalado${NC}"; terminar_con_error; }
	#command -v du >/dev/null || { echo -e "${ROJO}du no instalado${NC}"; terminar_con_error; }
	#command -v df >/dev/null || { echo -e "${ROJO}df no instalado${NC}"; terminar_con_error; }
}
# fin validar_herramientas
# ==============================
# ini set_logfile
set_logfile() {
	local nom="${1:-"BACKUP"}"
	local dir="${2:-"$DIR_SCRIPT"}"
	fecha=$(date +%Y-%m-%d_%H-%M-%S)
	logfile="${dir}/logs/${nom}-${fecha}.log"
	#mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
    
	if [[ ! -d "$logfile" ]]; then
    	mkdir -p "$(dirname "$logfile")" || { log "Error creando log"; return 1; }
	fi
	log "[REGISTRO]: $logfile [$fecha]"
}
set_logfile "BACKUP"
# fin set_logfile
# ==============================
# ini garantizar_sudo
# FUNCIÓN: Asegura que el acceso sudo esté activo sin pedir contraseñas duplicadas
garantizar_sudo() {
	# Verificar si ya tenemos permisos sudo activos en esta sesión
	if sudo -n true 2>/dev/null; then
    	# El ticket está activo, extendemos su duración por si acaso y salimos de la función
    	sudo -v
    	return 0
	else
    	if [[ -t 0 ]]; then
        	# Si llegamos aquí, el ticket expiró o no existe. Solicitamos la contraseña.
        	log "[!] Se requieren privilegios de administrador para continuar." "alerta"
        	echo -ne "$(pintar "Introduce la contraseña de sudo: " "prompt")"
        	read -s MI_PASSWORD
        	echo "" # Salto de línea

        	# Validar la contraseña introducida
        	if ! echo "$MI_PASSWORD" | sudo -S -v &> /dev/null; then
            	log "[-] Error: Contraseña incorrecta o permisos insuficientes." "error"
            	unset MI_PASSWORD
            	#exit 1
            	terminar_con_error
        	fi

        	# Destruir la variable inmediatamente tras validar con éxito
        	unset MI_PASSWORD
        	log "[+] Acceso concedido." "exito"
    	else
        	log "[-] Error: Necesario sudo pero no hay TTY (modo no interactivo)${NC}" "error"
        	terminar_con_error "sudo requerido en modo no interactivo" 2
    	fi    

	fi
}
# fin garantizar_sudo
# ==============================
# --- FUNCIONES DE COMPROBACIÓN Y REEMPLAZO ---
# ini parsear_ruta_remota
# Función auxiliar para separar el host y la ruta remota
# Transforma "user@ip:/path" en "user@ip" y "/path"
parsear_ruta_remota() {
	local entrada="$1"
	host_remoto="${entrada%%:*}"
	ruta_remota="${entrada#*:}"
}
# fin obtener_tipo_fs
# ==============================
# ini obtener_tipo_fs
# Obtener el tipo de sistema de archivos (Reemplaza a: df -T / df -TBG)
obtener_tipo_fs() {
    local ruta="$1"
    local resultado=""

    if is_remote_url "$ruta"; then
        parsear_ruta_remota "$ruta"
        # Evaluamos la disponibilidad y el resultado en un solo bloque seguro
        if ssh -q "$host_remoto" "command -v df" &> /dev/null; then
            # Si df falla o no encuentra la ruta, el operador || asegura un string y salida 0
            resultado=$(ssh "$host_remoto" "df -T '$ruta_remota' 2>/dev/null" | awk 'NR==2 {print $2}')
        fi
        
        if [ -z "$resultado" ] && ssh -q "$host_remoto" "command -v findmnt" &> /dev/null; then
            resultado=$(ssh "$host_remoto" "findmnt -n -o FSTYPE --target '$ruta_remota' 2>/dev/null")
        fi
        
        if [ -z "$resultado" ] && ssh -q "$host_remoto" "command -v stat" &> /dev/null; then
            resultado=$(ssh "$host_remoto" "stat -f -c '%T' '$ruta_remota' 2>/dev/null")
        fi

        # Si todo lo anterior falló o devolvió vacío, asignamos "unknown" de forma segura
        echo "${resultado:-unknown}"
    else
        if command -v df &> /dev/null; then
            resultado=$(df -T "$ruta" 2>/dev/null | awk 'NR==2 {print $2}')
        fi
        
        if [ -z "$resultado" ] && command -v findmnt &> /dev/null; then
            resultado=$(findmnt -n -o FSTYPE --target "$ruta" 2>/dev/null)
        fi
        
        if [ -z "$resultado" ] && command -v stat &> /dev/null; then
            resultado=$(stat -f -c '%T' "$ruta" 2>/dev/null)
        fi
        
        echo "${resultado:-unknown}"
    fi
    return 0 # Fuerza a la función a terminar siempre con éxito
}
# fin obtener_tipo_fs
# ==============================
# ini obtener_espacio_libre_bytes
# Obtener el espacio disponible en bytes (Reemplaza a: df --output=avail -B1)
obtener_espacio_libre_bytes() {
    local ruta="$1"
    local tamano=""

    if is_remote_url "$ruta"; then
        parsear_ruta_remota "$ruta"
        if ssh -q "$host_remoto" "command -v du" &> /dev/null; then
            # Captura el tamaño. Si du falla, awk imprimirá 0 gracias al +0
            tamano=$(ssh "$host_remoto" "du -sb '$ruta_remota' 2>/dev/null" | awk '{print $1 + 0}')
        elif ssh -q "$host_remoto" "command -v find && command -v stat" &> /dev/null; then
            tamano=$(ssh "$host_remoto" "find '$ruta_remota' -type f -exec stat -c '%s' {} + 2>/dev/null" | awk '{s+=$1} END {print s+0}')
        fi
        
        echo "${tamano:-0}"
    else
        if command -v du &> /dev/null; then
            tamano=$(du -sb "$ruta" 2>/dev/null | awk '{print $1 + 0}')
        elif command -v find &> /dev/null && command -v stat &> /dev/null; then
            tamano=$(find "$ruta" -type f -exec stat -c '%s' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')
        fi
        
        echo "${tamano:-0}"
    fi
    return 0 # Fuerza a la función a terminar siempre con éxito
}
# fin obtener_espacio_libre_bytes
# ==============================
# ini obtener_espacio_libre_gb
# Obtener el espacio disponible en Gigabytes (Reemplaza a: df --output=avail -BG)
obtener_espacio_libre_gb() {
	local ruta="$1"
	if command -v df &> /dev/null; then
    	df --output=avail -BG "$ruta" | tail -n 1 | tr -d '[:space:]' | tr -d 'G'
	else
    	# Si no hay df, calculamos los GB desde los bytes obtenidos con stat
    	local bytes
    	bytes=$(obtener_espacio_libre_bytes "$ruta")
    	awk -v b="$bytes" 'BEGIN {printf "%d", b / 1073741824}'
	fi
}
# fin obtener_espacio_libre_gb
# ==============================
# ini obtener_tamano_dir_bytes
# Obtener tamaño de un directorio en bytes (Reemplaza a: du -sb)
obtener_tamano_dir_bytes() {
	local ruta="$1"
	#log "Obteniendo el tamaño de $ruta"
	if is_remote_url "$ruta"; then
    	parsear_ruta_remota "$ruta"
    	if ssh -q "$host_remoto" "command -v du" &> /dev/null; then
        	ssh "$host_remoto" "du -sb '$ruta_remota' 2>/dev/null" | awk '{print $1}'
    	elif ssh -q "$host_remoto" "command -v find && command -v stat" &> /dev/null; then
        	ssh "$host_remoto" "find '$ruta_remota' -type f -exec stat -c '%s' {} + 2>/dev/null" | awk '{s+=$1} END {print s+0}'
    	else
        	echo "0"
    	fi
	else
    	if command -v du &> /dev/null; then
        	du -sb "$ruta" 2>/dev/null | awk '{print $1}'
    	elif command -v find &> /dev/null && command -v stat &> /dev/null; then
        	# Suma el tamaño de todos los archivos dentro del directorio
        	find "$ruta" -type f -exec stat -c '%s' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}'
    	else
        	echo "0"
    	fi
	fi
}
# fin obtener_tamano_dir_bytes
# ==============================
# ini obtener_tamano_multiples_dir_gb
# Obtener tamaño total de múltiples rutas en Gigabytes (Reemplaza a: du -csBG ... | awk '/total/')
obtener_tamano_multiples_dir_gb() {
	if command -v du &> /dev/null; then
    	# 1. Creamos un array para guardar solo las rutas que sí existen
    	local rutas_validas=()
    	for ruta in "$@"; do
        	if [ -e "$ruta" ]; then
            	rutas_validas+=("$ruta")
        	fi
    	done

    	# 2. Si hay rutas válidas, ejecutamos du. Si no, devolvemos 0.
    	if [ ${#rutas_validas[@]} -gt 0 ]; then
        	(du -csBG "${rutas_validas[@]}" 2>/dev/null || true) | awk '/total/ {print $1}' | tr -d 'G'
    	else
        	echo "0"
    	fi
	else
    	# Alternativa sumando bytes individuales de cada ruta dada
    	local total_bytes=0
    	for ruta in "$@"; do
        	if [ -e "$ruta" ]; then
            	local b
            	b=$(obtener_tamano_dir_bytes "$ruta")
            	total_bytes=$((total_bytes + b))
        	fi
    	done
    	awk -v b="$total_bytes" 'BEGIN {printf "%d", b / 1073741824}'
	fi
}
# fin obtener_tamano_multiples_dir_gb
# ==============================
# ini mostrar_info_fs
# Mostrar info general del sistema de archivos (Reemplaza a: df -TBG "$DIR" | tee -a)
mostrar_info_fs() {
	local ruta="$1"
	local log="$2"
	if command -v df &> /dev/null; then
    	df -TBG "$ruta" | tee -a "$log"
	elif command -v findmnt &> /dev/null; then
    	echo -e "\n[INFO FS via findmnt]" | tee -a "$log"
    	findmnt -o SOURCE,FSTYPE,SIZE,USED,AVAIL,USE%,TARGET --target "$ruta" | tee -a "$log"
	else
    	echo -e "\n[INFO FS] Tipo: $(obtener_tipo_fs "$ruta") | Libre: $(obtener_espacio_libre_gb "$ruta")GB" | tee -a "$log"
	fi
}
# fin mostrar_info_fs
# ==============================
# ini mostrar_tamano_dir_log
# Mostrar tamaño de un directorio en GB en el log (Reemplaza a: sudo du -s -BG)
mostrar_tamano_dir_log() {
	local ruta="$1"
	local log="$2"
	if command -v du &> /dev/null; then
    	sudo du -s -BG "$ruta" 2>&1 | tee -a "$log"
	else
    	local gb
    	gb=$(obtener_tamano_multiples_dir_gb "$ruta")
    	echo "${gb}G	$ruta" | tee -a "$log"
	fi
}
# fin mostrar_tamano_dir_log
# ==============================
# ini get_rsync_opts
get_rsync_opts() {
	local src=$1
	local dst=$2
	local outvar=$3

	# Si origen o destino son remotos, elegir opciones conservadoras sin intentar df/realpath
	if is_remote_url "$src" || is_remote_url "$dst"; then
    	eval "$outvar=( -aHv --delete --numeric-ids --progress )"
    	return 0
	fi

	local src_fs dst_fs

	# src_fs=$(df -TBG "$src" | awk 'NR==2 {print $2}')
	# dst_fs=$(df -TBG "$dst" | awk 'NR==2 {print $2}')
	src_fs=$(obtener_tipo_fs "$src")
	dst_fs=$(obtener_tipo_fs "$dst")

	if is_posix_fs "$src_fs" && is_posix_fs "$dst_fs"; then
    	#eval "$outvar=( -aAXvh --delete --numeric-ids --progress )"
    	modarr=( -aAXvh --delete --numeric-ids --progress )
	else
    	#eval "$outvar=( -aHv --delete --numeric-ids --progress --no-perms --no-owner --no-group --chmod=ugo=rwX )"
    	modarr=( -aHv --delete --numeric-ids --progress --no-perms --no-owner --no-group --chmod=ugo=rwX )
	fi
}
# fin get_rsync_opts
# ==============================
# ini is_posix_fs
# helpers
is_posix_fs() {
	case "$1" in
    	ext2|ext3|ext4|xfs|btrfs|f2fs|zfs|jfs) return 0 ;;
    	*) return 1 ;;
	esac
}
# fin is_posix_fs
# ==============================
# ini is_lamp_backup
is_lamp_backup() {
	local base
	base=$(basename "$1")
	[[ "$base" == LAMP || "$base" == LAMP-* ]]
}
# fin is_lamp_backup
# ==============================
# ini expand_path
# Expande ~ y canonicaliza rutas locales; deja intactas las URLs/remotas (añadido soporte rclone-style)
expand_path() {
	local p="${1:-}"
	[[ -z "$p" ]] && printf '%s\n' "$p" && return 0
	# expandir tilde
	p="${p/#\~/$HOME}"
	# detectar URL (scheme://) o scp-like (user@host:/path) o UNC (//) o rclone-style (name:subpath)
	if [[ "$p" =~ :// ]] || [[ "$p" =~ ^[^/]+@[^:]+: ]] || [[ "$p" =~ ^// ]] || [[ "$p" =~ ^[A-Za-z0-9._-]+:.+ ]]; then
    	printf '%s\n' "$p"
	else
    	# usar realpath -m para no fallar si no existe; si no existe realpath -m, intenta realpath y cae al original
    	if realpath -m "$p" >/dev/null 2>&1; then
        	realpath -m "$p"
    	else
        	realpath "$p" 2>/dev/null || printf '%s\n' "$p"
    	fi
	fi
}
# fin expand_path
# ==============================
# ini is_remote_url
# Devuelve 0 si la ruta es remota/URL (http(s)://, scp-like, UNC, o rclone remote:subpath)
is_remote_url() {
	local u="${1:-}"
	[[ -z "$u" ]] && return 1
	if [[ "$u" =~ :// ]] || [[ "$u" =~ ^[^/]+@[^:]+: ]] || [[ "$u" =~ ^// ]] || [[ "$u" =~ ^[A-Za-z0-9._-]+:.+ ]]; then
    	return 0
	fi
	return 1
}
# fin is_remote_url
# ==============================
# ini sanitizar_nombre_directorio
sanitizar_nombre_directorio() {
	local entrada="$1"
	local limpio
    
	# 1. Traducir caracteres específicos de forma manual (Ñ, ñ, Ç, ç)
	limpio=$(echo "$entrada" | tr 'ÑñÇç' 'NnCc')
    
	# 2. Eliminar acentos y diéresis de forma automática convirtiendo a ASCII plano
	#	//TRANSLIT le dice a iconv que busque el carácter más parecido (ej: á -> a)
	limpio=$(echo "$limpio" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || echo "$limpio")
    
	# 3. Eliminar caracteres que SÍ son ilegales o peligrosos para las rutas
	#	(Como /, \, *, ?, ", ', <, >, |, :, y espacios), reemplazándolos por guiones bajos
	limpio=$(echo "$limpio" | sed 's/[^a-zA-Z0-9_-]/_/g')
    
	# 4. Limpieza estética: colapsar múltiples guiones bajos seguidos en uno solo
	limpio=$(echo "$limpio" | sed 's/__*/_/g')
    
	# 5. Quitar guiones bajos sueltos en los extremos
	limpio=${limpio#_}
	limpio=${limpio%_}
    
	# 6. Quitar guiones medios sueltos en los extremos (todos los que haya)
	limpio=$(echo "$limpio" | sed -e 's/^-*//' -e 's/-*$//')
    
	# Si la cadena queda vacía por seguridad, asignamos un nombre por defecto
	if [[ -z "$limpio" ]]; then
    	limpio="desconocido"
	fi
    
	echo "$limpio"
}
#Creo las variables por defecto para directorios
equipo_sin_usuario="${EQUIPO//$USUARIO/}"
equipo_limpio=$(sanitizar_nombre_directorio "$equipo_sin_usuario")
usuario_limpio=$(sanitizar_nombre_directorio "$USUARIO")
nom_pcu="${equipo_limpio:0:20}-${usuario_limpio:0:20}"
# fin sanitizar_nombre_directorio
# ==============================
# ini explicar_error_rsync
explicar_error_rsync() {
	local rc="$1"
	local mensaje=""

	case "$rc" in
    	0)  mensaje="Sincronización completada con éxito." ;;
    	1)  mensaje="Error de sintaxis o uso incorrecto de los comandos." ;;
    	2)  mensaje="Incompatibilidad de protocolo entre las versiones de rsync." ;;
    	3)  mensaje="Error al seleccionar los archivos o directorios de origen/destino (¿Ruta inexistente?)." ;;
    	4)  mensaje="Acción solicitada no soportada (por ejemplo, archivos de 64-bits en plataformas de 32-bits)." ;;
    	5)  mensaje="Error al iniciar el protocolo cliente-servidor nativo de rsync." ;;
    	6)  mensaje="El demonio (daemon) de rsync no pudo escribir o añadir datos al archivo log." ;;
    	10) mensaje="Error grave en la entrada/salida de sockets (caída de red o problema SSH)." ;;
    	11) mensaje="Error grave de entrada/salida (I/O) en el sistema de archivos del disco." ;;
    	12) mensaje="Error en el flujo de datos del protocolo de comunicación de rsync." ;;
    	13) mensaje="Error con los diagnósticos internos del programa." ;;
    	14) mensaje="Error en el código de comunicación entre procesos (IPC)." ;;
    	20) mensaje="La transferencia fue interrumpida de forma manual (Señal SIGUSR1 o Ctrl+C)." ;;
    	21) mensaje="Error devuelto por una llamada interna del sistema operativo (waitpid)." ;;
    	22) mensaje="Error al asignar búferes de memoria RAM en el sistema." ;;
    	23) mensaje="Transferencia parcial debido a errores. Algunos archivos no pudieron copiarse (Revisa permisos de lectura/escritura)." ;;
    	24) mensaje="Transferencia parcial porque algunos archivos desaparecieron mientras se leían (Común en logs cambiantes)." ;;
    	25) mensaje="El límite establecido por '--max-delete' detuvo los borrados del destino." ;;
    	30) mensaje="Tiempo de espera agotado (Timeout) en el envío o recepción de datos." ;;
    	35) mensaje="Tiempo de espera agotado esperando la conexión con el demonio rsync." ;;
    	127) mensaje="El comando rsync no está instalado en el sistema o no se encuentra en el PATH." ;;
    	*)  mensaje="Código de error desconocido o fallo no documentado por rsync." ;;
	esac

	# Imprimir la alerta con color y guardarla en el log
	if [ "$rc" -eq 0 ]; then
    	log "$mensaje" "exito"
	else
    	log "[ERROR - Código $rc]: $mensaje" "error"
	fi
}
# fin explicar_error_rsync
# ==============================
# ini cambiar_propietario_contenido
cambiar_propietario_contenido() {
	local directorio="$1"
	local usuario_grupo="$2"
	#echo "directorio=$directorio ; usuario_grupo=$usuario_grupo" | tee -a "$logfile"
    
	# Guardar estado actual de nullglob y activarlo localmente
	local nullglob_status
	nullglob_status=$(shopt -p nullglob || true)
	shopt -s nullglob

	# Capturar los archivos en un array seguro
	local archivos=("$directorio"/*)
   	 
	# Restaurar el estado original de nullglob inmediatamente
	eval "$nullglob_status"

	# Si el array tiene elementos, ejecutamos el chown de forma segura
	if [ ${#archivos[@]} -gt 0 ]; then
    	#echo "CMD: chown -vR $usuario_grupo ${archivos[@]}" | tee -a "$logfile"
    	sudo chown -vR "$usuario_grupo" "${archivos[@]}" 2>&1 | tee -a "$logfile"
    	# Capturamos el PIPESTATUS del chown (no del tee)
    	return ${PIPESTATUS[0]}
	fi

	# Si está vacío, salimos con éxito silencioso (evita fallos)
	return 0
}
# fin cambiar_propietario_contenido
# ==============================
# ini descargar_strato
descargar_sftp() {
	# local usuario_host="52094416.es.strato-hosting.eu@ssh.strato.com"
	# local ruta_remota="/mail/" # El punto indica la raíz del hosting, o pon '/public_html' si existe
	# local ruta_local="/home/ricardo/Documentos/P/"
    local dirorig="${1:-}"
    local dirdest="${2:-}"
    local simula="${3:-0}"
    local ruta_local=""
    local cmd=""
    local archivo_errores="/tmp/sftp_err_$$.log"
	local es_subida=0
	local sftp_batch="/tmp/sftp_batch_$$"

    # Forzar a 0 si simula viene vacío por error de llamada
    if [[ -z "$simula" ]]; then simula=0; fi

    # --- CASO 1: AMBOS REMOTOS (Efecto Puente) ---
    if is_remote_url "$dirorig" && is_remote_url "$dirdest"; then
        log "Ambas rutas son remotas. Usando modo puente local..." "alerta"
        # 1. Crear una carpeta temporal en tu Ubuntu para el puente
        local puente_local="/tmp/sftp_puente_$$"
        # 2. Descargar del primer remoto al puente local
        log "Paso 1/2: Descargando origen al puente local..."
        if ! descargar_sftp "$dirorig" "$puente_local" "0"; then
            log "Fallo en el paso 1 del puente (descarga)." "error"
            return 1
        fi
        # 3. Subir del puente local al segundo remoto
        log "Paso 2/2: Subiendo puente local al destino remoto..."
        if ! descargar_sftp "$puente_local" "$dirdest" "0"; then
            log "Fallo en el paso 2 del puente (subida)." "error"
            rm -rf "$puente_local"
            return 1
        fi
        # 4. Limpiar la carpeta puente
        rm -rf "$puente_local"
        return 0
    fi
    # --- CASO 2 y 3: DETECTAR QUIÉN ES REMOTO ---
    if is_remote_url "$dirorig"; then 
        parsear_ruta_remota "$dirorig"
        ruta_local="$dirdest"
        cmd="get -pr *"
		es_subida=0
    else
        parsear_ruta_remota "$dirdest"
        ruta_local="$dirorig"
        cmd="put -pr *"
		es_subida=1
    fi
	local usuario_host="$host_remoto"
	local r_remota="$ruta_remota"
	if [ "$simula" -eq 1 ]; then
		cmd="exit"
	fi

    log "dirorig=$dirorig"
    log "dirdest=$dirdest"
    log "ruta_local=$ruta_local"
    log "usuario_host=$usuario_host"
    log "ruta_remota=$r_remota"

	# Si es descarga, preparamos la carpeta local
    if [ "$es_subida" -eq 0 ] && [ ! -d "$ruta_local" ]; then
	    mkdir -p "$ruta_local"
    fi
	#log "Iniciando descarga segura vía SFTP..." "alerta"

# 	# Conectamos por SFTP y le pasamos los comandos de descarga automática
# 	sftp -o BatchMode=no -b - "$usuario_host" <<EOF
#     	cd "$ruta_remota"
#     	lcd "$ruta_local"
#     	$cmd
#     	bye
# EOF
# 	if [ $? -eq 0 ]; then
#     	#log "Descarga de Strato completada con éxito." "exito"
#         return 0
# 	else
#     	#log "Error al descargar desde el servidor de Strato." "error"
#         return 1
# 	fi

    # --- EJECUCIÓN CON RECOLECCIÓN DE ERRORES ---
    # Redirigimos los fallos (2>) al archivo temporal.
#     sftp -o BatchMode=no -b - "$usuario_host" 2>"$archivo_errores" <<EOF
#         cd "$r_remota"
#         lcd "$ruta_local"
#         $cmd
#         bye
# EOF
#     if [ $? -eq 0 ]; then
	# Limpieza previa del archivo batch por seguridad
    rm -f "$sftp_batch"
# --- LIMPIEZA DE RUTAS PARA STRATO (FORZAR RELATIVAS) ---
    # Eliminamos barras duplicadas y CUALQUIER barra al principio para que sea relativa
    local ruta_limpia=$(echo "$r_remota" | sed 's/\/\//\//g' | sed 's/^\/\+//' | sed 's/\/$//')

    if [ "$es_subida" -eq 1 ] && [ "$simula" -eq 0 ]; then
        log "Iniciando subida segura vía SFTP (Creando estructura remota)..." "alerta"
        
        # En lugar de adivinar si existen, generamos una secuencia de cd alternado con mkdir.
        # SFTPBatch ejecutará secuencialmente. Ponemos '-' antes de mkdir para que si falla porque existe,
        # SFTP no detenga el lote y continúe con el script.

		# Estructura recursiva estática sin movernos del directorio inicial
        local ruta_acumulada=""

		# Guardar IFS actual para restaurarlo después
        local old_ifs="$IFS"
        IFS='/' read -r -a carpetas <<< "$ruta_limpia"
		IFS="$old_ifs"
        for carpeta in "${carpetas[@]}"; do
            if [ -n "$carpeta" ]; then
                if [ -z "$ruta_acumulada" ]; then
                    ruta_acumulada="$carpeta"
                else
                    ruta_acumulada="$ruta_acumulada/$carpeta"
                fi
                # Intenta crear la ruta exacta acumulada desde la raíz.
                # Si ya existe, el '-' ignora el fallo y continúa de forma segura.
                echo "-mkdir \"$ruta_acumulada\"" >> "$sftp_batch"
            fi
        done
    else
        if [ "$simula" -eq 1 ]; then
            log "Validando conectividad del directorio remoto vía SFTP..." "info"
        else
            log "Iniciando descarga segura vía SFTP..." "alerta"
        fi
    fi

    # Añadir comandos de transferencia estándar al lote
    echo "cd \"$ruta_limpia\"" >> "$sftp_batch"
    echo "lcd \"$ruta_local\"" >> "$sftp_batch"
    echo "$cmd" >> "$sftp_batch"
    echo "bye" >> "$sftp_batch"

    # --- EJECUCIÓN CON CONTROL DE ERRORES ---
    sftp -o BatchMode=no -b "$sftp_batch" "$usuario_host" 2>"$archivo_errores"
    local sftp_rc=$?

    rm -f "$sftp_batch"

    if [ $sftp_rc -eq 0 ]; then
        rm -f "$archivo_errores"
        return 0
    else
        # Si falla, leemos el archivo de errores y lo metemos en tu log general
        log "Fallo en la operación SFTP ($cmd)." "error"
        if [ -s "$archivo_errores" ]; then
            log "Detalle del error devuelto por el servidor:" "error"
            while IFS= read -r linea; do
                # Filtrar mensajes comunes que no representan fallos reales de la copia
                if [[ "$linea" != *"Failure"* ]] && [[ "$linea" != *"Permission denied"* || "$es_subida" -eq 0 ]]; then
                    log "  -> $linea" "error"
                fi
            done < "$archivo_errores"
        else
            log "El servidor no devolvió un mensaje de error específico (posible fallo de conexión/credenciales)." "error"
        fi
        rm -f "$archivo_errores"
        return 1
    fi

}
# fin descargar_strato
# ==============================
# ini check_remote_capabilities
check_remote_capabilities() {
    local remote_url="$1"
    
    # Si no es remoto, no aplica esta lógica
    if ! is_remote_url "$remote_url"; then
        return 0
    fi

    # Extraer el host (ej: usuario@ssh.strato.com)
    local host_ssh="${remote_url%%:*}"
    
    # Intentamos ejecutar un comando rápido y seguro (uname) con un timeout corto
    if ssh -o ConnectTimeout=5 -o BatchMode=no "$host_ssh" "uname" >/dev/null 2>&1; then
        # El servidor permite ejecución de comandos SSH estándar
        return 0
    else
        # Servidor capado (Strato o similar) o sin acceso SSH directo
        return 1
    fi
}
# fin check_remote_capabilities
# ==============================
# ini do_rsync
do_rsync() {
	# echo "DEBUG: A punto de llamar a do_rsync con src='$backup_src' dst='$restore_dest'" | tee -a "$logfile"
	# echo "DEBUG: env prueba_rsync='$prueba_rsync'" | tee -a "$logfile"
	# set -x  # opcional, activa traza bash (quita después)

	local use_sudo=${1:-}
	shift 2>/dev/null || true
	local src=${1:-}
	shift 2>/dev/null || true
	local dst=${1:-}
	shift 2>/dev/null || true
	local label=${1:-"rsync"}
	shift 2>/dev/null || true
	local logpath="${1:-}"
	shift 2>/dev/null || true
	# Si no se pasó un logfile, usar la variable global $logfile establecida por set_logfile
	if [[ -z "$logpath" ]]; then
    	logpath="$logfile"
	fi

	# parámetros opcionales: nombre del array de opciones rsync, nombre del array exclude, password
	local modarr_name=${1:-}
	local modexclude_name=${2:-}
	local password=${3:-}

	if [[ -z "$modarr_name" ]]; then
    	get_rsync_opts "$src" "$dst" modarr
    	modarr_name=modarr
	fi

	if [[ -z "$modexclude_name" ]]; then
    	modexclude_name=modexclude_empty
    	modexclude_empty=()
	fi

	local modarr_ref
	local modexclude_ref
	eval "modarr_ref=( \"\${${modarr_name}[@]}\" )"
	eval "modexclude_ref=( \"\${${modexclude_name}[@]}\" )"

	if [[ -z "$prueba_rsync" ]]; then
    	echo -e "${AMARILLO} A continuación se pregunta si estas haciendo pruebas. Si respondes 'S' no se copiarán los archivos y solo realizará una simulación, esta configuración durará mientras se ejecute el programa, para cambiarla tienes que salir del programa y volver a ejecutarlo. ${NC}"
    	read -rp "${MAGENTA_B}Estas haciendo pruebas? [N/s]: ${NC}" prueba_rsync
    	prueba_rsync=${prueba_rsync:-n}
	fi
	# si son pruebas incluimos el modificador --dry-run para que simule y no haga cambios.
	if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then
    	modarr_ref+=(--dry-run)
	fi

	local rsync_rc=0
	local start_ts=$(date +%s)
	local start_time=$(date '+%F %T')

	src="${src%/}/"
	dst="${dst%/}/"

	log "INICIO DE OPERACIÓN ($label): $start_time"
	#echo "COMANDO: $( [[ "$use_sudo" =~ ^(yes|sudo)$ ]] && printf 'sudo ' )rsync ${modarr_ref[*]} ${modexclude_ref[*]} '$src' '$dst'" | tee -a "$logfile"
	# limpiar dobles slashes y normalizar dst antes de parsear
	dst="${dst%/}"
	dst="${dst//\/\//\/}"

	# si dst es scp-like, construir --rsync-path sobre la ruta completa que queremos crear
	if [[ "$dst" =~ ^([^@]+@[^:]+):(.+)$ ]]; then
    	remote_host="${BASH_REMATCH[1]}"
    	remote_path="${BASH_REMATCH[2]}"
    	remote_path="${remote_path%/}"
    	# crear la ruta completa remota (no sólo el padre)
    	modarr_ref+=( "--rsync-path=$(printf "mkdir -p %q && rsync" "$remote_path")" )
	fi

	# ahora (re)construir el comando final para que incluya la opción añadida
	if [[ "$use_sudo" = "sudo" ]]; then
    	cmd=( sudo rsync )
	else
    	cmd=( rsync )
	fi
	cmd+=( "${modarr_ref[@]}" "${modexclude_ref[@]}" "$src" "$dst" )

	#echo "COMANDO: ${cmd[@]}" | tee -a "$logpath"
	# local cmd=()
	# if [[ "$use_sudo" = "sudo" ]]; then
	# 	cmd=( sudo rsync )
	# else
	# 	cmd=( rsync )
	# fi
	# cmd+=( "${modarr_ref[@]}" "${modexclude_ref[@]}" "$src" "$dst" )

	# echo "COMANDO: ${cmd[@]}" | tee -a "$logfile"


	if [[ "$use_sudo" = "sudo" && -n "$password" ]]; then
    	# echo "$password" | "${cmd[@]}" 2>&1 | tee -a "$logfile"
    	# rsync_rc=${PIPESTATUS[1]}
    	garantizar_sudo
    	# "${cmd[@]}" 2>&1 | tee -a "$logfile" && true
    	# rsync_rc=${PIPESTATUS[0]} # PIPESTATUS[0] ahora es de 'sudo' (que envuelve a rsync)
	#else
    	# "${cmd[@]}" 2>&1 | tee -a "$logfile" && true
    	# rsync_rc=${PIPESTATUS[0]}
	fi

	# detectar si alguno es URL con scheme no-ssh
	if is_remote_url "$src" || is_remote_url "$dst"; then
    	# preferir rsync (ssh/scp) cuando el formato es user@host:/path o rsync://
    	if [[ "$src" =~ ^[^/]+@[^:]+: ]] || [[ "$dst" =~ ^[^/]+@[^:]+: ]] || [[ "$src" =~ ^rsync:// ]] || [[ "$dst" =~ ^rsync:// ]]; then
        	log "Probando conectividad rsync con el servidor remoto..." "alerta"
        	
        	# Verificación silenciosa no destructiva para validar si el rsync del servidor responde
        	if rsync --dry-run "$src" "$dst" >/dev/null 2>&1; then
				echo "COMANDO: ${cmd[@]}" | tee -a "$logpath"
				# usar rsync (como ahora)
				"${cmd[@]}" 2>&1 | tee -a "$logpath" && true
				rsync_rc=${PIPESTATUS[0]}
			else
            	log "rsync está capado o inaccesible en el servidor (Común en Strato). Transfiriendo vía SFTP..." "alerta"
            	
            	# Convertir boleano de pruebas al formato requerido por descargar_sftp (0 o 1)
            	local simula_sftp=0
            	if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then simula_sftp=1; fi
            	
            	descargar_sftp "$src" "$dst" "$simula_sftp"
            	rsync_rc=$?
            	if [[ $rsync_rc -eq 0 ]]; then
                	log "Se consiguió descargar exitosamente mediante el fallback SFTP." "exito"
            	else
                	log "Error crítico: Tampoco se pudo transferir por SFTP." "error"
            	fi
        	fi
    	else
        	#Detectar si el origen es Google drive
        	# 1. Extraer el nombre del remoto (todo lo que está antes de los dos puntos)
        	remoto_nombre="${src%%:*}"
        	# 2. Inicializar la variable de modificadores vacía
        	modificadores_drive=""
        	# 3. Validar: ¿Tiene formato de rclone (alfanumérico) y NO es una ruta SSH (sin @)?
        	if [[ "$remoto_nombre" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ "$remoto_nombre" != *.* ]]; then

            	# 4. Preguntar a rclone qué tipo de almacenamiento es ese remoto
            	# rclone listremotes --long devuelve líneas como: "drivero: drive" o "mi_dropbox: dropbox"
            	tipo_remoto=$(rclone listremotes --long 2>/dev/null | awk -v rem="${remoto_nombre}:" '$1 == rem {print $2}')

            	# 5. Si el tipo devuelto por rclone es exactamente "drive", aplicamos los modificadores
            	if [ "$tipo_remoto" = "drive" ]; then
                	modificadores_drive="--drive-export-formats=docx,xlsx,pptx"
            	fi
        	fi
        	echo "COMANDO: rclone copy $src $dst --progress --transfers=4 --log-file=$logpath $modificadores_drive" | tee -a "$logpath"
        	# fallback: usar rclone (instalar rclone previamente)
        	# rclone acepta ftp,sftp,http,webdav,s3,swift,smb,...
        	# ejemplo: rclone copy SRC DST --progress
        	if command -v rclone >/dev/null 2>&1; then
            	rclone copy "$src" "$dst" --progress --transfers=4 --log-file="$logpath" $modificadores_drive || rc=$?
        	else
                #log "[ERROR] Ruta remota no soportada y rclone no instalado"
            	#rc=1
                #Si tampoco es capaz de descargar con rclone lo intentamos por sftp
                log "La ruta no es accesible desde rsync ni rclone, probamos por SFTP."
                descargar_sftp "$src" "$dst"
                rc=$?
                if [[ $rc -eq 0 ]]; then
                    log "Se consiguió descargar mediante SFTP" "exito"
                else
                    log "No se consiguió copiar con rsync, rclone ni SFTP, ruta inaccesible." "error"
                fi

        	fi
    	fi
	else
    	# local-to-local: usar rsync como ahora
    	"${cmd[@]}" 2>&1 | tee -a "$logpath" && true
    	rsync_rc=${PIPESTATUS[0]}
	fi

	local end_ts=$(date +%s)
	local end_time=$(date '+%F %T')
	local elapsed=$((end_ts - start_ts))
	local elapsed_fmt=$(date -u -d "@$elapsed" +%H:%M:%S)

	echo "FIN: $end_time" | tee -a "$logpath"
	echo "DURACIÓN: $elapsed_fmt" | tee -a "$logpath"
	echo "HORA INICIO: $start_time" | tee -a "$logpath"
	echo "HORA FIN: $end_time" | tee -a "$logpath"
	echo "" | tee -a "$logpath"

	if [[ $rsync_rc -eq 0 ]]; then
    	log "[$label] Copia completada." "exito"
	else
    	log "[$label] rsync devolvió $rsync_rc." "error"
    	explicar_error_rsync "$rsync_rc"
	fi

	# set +x  # desactivar traza (si la activaste)
	# echo "DEBUG: do_rsync returned rc=$?" | tee -a "$logfile"

	return $rsync_rc
}
# fin do_rsync
# ==============================
# ini crear_claves_ssh_automatico
crear_claves_ssh_automatico() {
    log "==============================" "menu"
    log "CONFIGURACIÓN DE CLAVES SSH AUTOMÁTICA" "menu"
    log "==============================" "menu"

    local user_host=""
    read -rp "$(pintar "Ingrese el usuario y host remoto (ej: usuario@ssh.strato.com): " "prompt")" user_host

    # Validar formato simple (debe contener un carácter @)
    if [[ -z "$user_host" || "$user_host" != *@* ]]; then
        log "Formato inválido. Debe ser usuario@servidor" "error"
        return 1
    fi

    local key_file="$HOME/.ssh/id_rsa"
    local pub_key_file="${key_file}.pub"

    # 1. Generar claves locales si no existen (Universal para cualquier distro)
    if [ ! -f "$key_file" ]; then
        log "Generando pareja de claves SSH RSA de 4096 bits localmente..." "info"
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -q
        log "Claves creadas correctamente en tu máquina local." "exito"
    else
        log "Se detectó una clave SSH existente en tu máquina local." "info"
    fi

    # Archivos temporales de trabajo local
    local sftp_batch="/tmp/sftp_keys_$$"
    local archivo_errores="/tmp/sftp_keys_err_$$"
    local local_auth_keys="/tmp/local_auth_keys_$$"
    
    rm -f "$sftp_batch" "$archivo_errores" "$local_auth_keys"
    touch "$local_auth_keys"

    log "Nota: A continuación se te pedirá la contraseña para sincronizar las llaves por SFTP." "alerta"

    # 2. Paso 1: Asegurar carpeta remota .ssh e intentar descargar authorized_keys si ya existía
    echo "-mkdir .ssh" >> "$sftp_batch"
    echo "chmod 700 .ssh" >> "$sftp_batch"
    echo "cd .ssh" >> "$sftp_batch"
    echo "-get authorized_keys \"$local_auth_keys\"" >> "$sftp_batch"
    echo "bye" >> "$sftp_batch"

    sftp -o BatchMode=no -b "$sftp_batch" "$user_host" >/dev/null 2>"$archivo_errores"
    rm -f "$sftp_batch"

    # 3. Paso 2: Adjuntar localmente tu clave pública al archivo descargado de forma limpia
    # Asegura un salto de línea y concatena el texto
    echo "" >> "$local_auth_keys"
    cat "$pub_key_file" >> "$local_auth_keys"
    # Eliminar líneas vacías duplicadas para mantener el archivo limpio
    sed -i '/^$/d' "$local_auth_keys"

    # 4. Paso 3: Subir el archivo authorized_keys definitivo y dar permisos
    rm -f "$sftp_batch"
    echo "cd .ssh" >> "$sftp_batch"
    echo "put \"$local_auth_keys\" authorized_keys" >> "$sftp_batch"
    echo "chmod 600 authorized_keys" >> "$sftp_batch"
    echo "bye" >> "$sftp_batch"

    sftp -o BatchMode=no -b "$sftp_batch" "$user_host" >/dev/null 2>"$archivo_errores"
    
    local sftp_rc=$?
    rm -f "$sftp_batch" "$local_auth_keys"

    if [ $sftp_rc -eq 0 ]; then
        rm -f "$archivo_errores"
        log "======================================================" "exito"
        log "[OK] ¡Proceso completado con éxito!" "exito"
        log "El servidor remoto ya confía en tu máquina virtual." "exito"
        log "A partir de ahora, el script NO te pedirá más contraseñas." "exito"
        log "======================================================" "exito"
        return 0
    else
        log "Error al subir la configuración de llaves definitiva por SFTP." "error"
        if [ -s "$archivo_errores" ]; then
            while IFS= read -r linea; do
                log "  -> $linea" "error"
            done < "$archivo_errores"
        fi
        rm -f "$archivo_errores"
        return 1
    fi
}
# fin crear_claves_ssh_automatico
# ==============================
# ini configurar_google_drive_rclone
configurar_google_drive_rclone() {
    log "==============================" "menu"
    log "CONFIGURACIÓN AUTOMÁTICA DE GOOGLE DRIVE (RCLONE)" "menu"
    log "==============================" "menu"

    # 1. Verificar si rclone está instalado en la distribución
    if ! command -v rclone >/dev/null 2>&1; then
        log "[ALERTA] 'rclone' no está instalado en este sistema." "alerta"
        log "Intentando instalar rclone de forma automática..." "info"
        
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y rclone
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y rclone
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm rclone
        else
            log "No se pudo detectar el gestor de paquetes. Por favor, instala rclone manualmente." "error"
            return 1
        fi
    fi

    local nombre_remoto=""
    read -rp "Introduce un nombre para identificar esta cuenta Drive (ej: mi_drive): " nombre_remoto

    if [[ -z "$nombre_remoto" || ! "$nombre_remoto" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log "Nombre de remoto inválido. Usa solo letras, números, guiones o guiones bajos." "error"
        return 1
    fi

    if rclone listremotes 2>/dev/null | grep -q "^${nombre_remoto}:"; then
        log "Ya existe un almacenamiento configurado con el nombre '${nombre_remoto}'." "alerta"
        read -rp "¿Deseas sobrescribirlo? (s/N): " renombrar
        if [[ ! "$renombrar" =~ ^[sS]$ ]]; then
            return 0
        fi
        # Eliminar el remoto existente para poder reconfigurarlo limpiamente
        rclone config delete "$nombre_remoto" >/dev/null 2>&1
    fi

    log "Iniciando el asistente interactivo de Google Drive para entornos sin navegador..." "info"
    log "=========================================================================" "alerta"
    log "INSTRUCCIONES:" "alerta"
    log "1. El asistente interactivo te hará varias preguntas breves." "alerta"
    log "2. Pulsa [ENTER] (dejar en blanco) en 'client_id' y 'client_secret'." "alerta"
    log "3. Selecciona la opción '1' (Acceso completo / Full access al Drive)." "alerta"
    log "4. Deja vacíos 'root_folder_id' y 'service_account_file' (pulsa ENTER)." "alerta"
    log "5. En 'Edit advanced config' responde 'n' (No)." "alerta"
    log "6. MUY IMPORTANTE: Cuando pregunte 'Use web browser to automatically authenticate...'" "alerta"
    log "   RESPONDE 'n' (No). Esto te generará el enlace web para copiar y pegar." "alerta"
    log "=========================================================================" "alerta"
    
    # 2. Lanzamos el asistente de configuración interactivo enfocado únicamente en el nuevo remoto
    # Esto garantiza compatibilidad absoluta con cualquier versión antigua o moderna de rclone
    rclone config passwordless "$nombre_remoto" drive 2>/dev/null || rclone config edit

    # Si la distro no soporta atajos avanzados, usamos la llamada guiada tradicional asistida:
    if ! rclone listremotes 2>/dev/null | grep -q "^${nombre_remoto}:"; then
        # El comando 'rclone config' tradicional es universal y no falla nunca
        log "Abriendo el menú de rclone. Sigue los pasos indicados en las instrucciones de arriba." "info"
        rclone config
    fi

    # 3. Validar si la configuración se guardó correctamente tras la interacción del usuario
    if rclone listremotes 2>/dev/null | grep -q "^${nombre_remoto}:"; then
        log "======================================================" "exito"
        log "[OK] ¡Google Drive configurado con éxito!" "exito"
        log "Ya puedes usar la ruta '${nombre_remoto}:' como origen o destino." "exito"
        log "El script de backup lo detectará y usará automáticamente por rclone." "exito"
        log "======================================================" "exito"
        
        log "Intentando listar directorios raíz de tu Drive para verificar la conexión:" "info"
        rclone lsf --max-depth 1 "${nombre_remoto}:" 2>/dev/null || log "Nota: No se encontraron archivos o el Drive está vacío, pero la conexión es correcta." "alerta"
        return 0
    else
        log "Hubo un error o se canceló el proceso de vinculación con Google Drive." "error"
        return 1
    fi
}
# fin configurar_google_drive_rclone
# ==============================
# ini modo no interactivo
# --------------------------
# CLI / Modo no interactivo
# --------------------------
show_help() {
  cat <<EOF
Usage: $0 [--non-interactive|-n] --src|-s SRC --dst|-d DST [--dry-run|-r] [--help|-h]

  --non-interactive, -n	Ejecuta sin interacción (útil para cron)
  --src, -s SRC        	Ruta origen (local, user@host:/path o rclone:remote:path)
  --dst, -d DST        	Ruta destino (local o user@host:/path)
  --dry-run, -r        	Simular la copia (rsync --dry-run)
  --help, -h           	Mostrar esta ayuda
EOF
}

# Valores por defecto
NON_INTERACTIVE=0
DRY_RUN=0
SRC=""
DST=""

# Parseo simple de longopts (no requiere getopt)
while [[ $# -gt 0 ]]; do
  case "$1" in
	--non-interactive|-n) NON_INTERACTIVE=1; shift ;;
	--src|-s) SRC="$2"; shift 2 ;;
	--dst|-d) DST="$2"; shift 2 ;;
	--dry-run|-r) DRY_RUN=1; shift ;;
	--help|-h) show_help; exit 0 ;;
	--) shift; break ;;
	*) break ;;
  esac
done

# Función que ejecuta el backup sin interacción, construyendo el rsync y llamando a do_rsync.
run_non_interactive() {
  if [[ -z "$SRC" || -z "$DST" ]]; then
	err "Modo no interactivo requiere --src y --dst"; return 2
  fi

  # Expandir orígenes locales; dejar remotos rclone/scp tal cual
  ORIG_EXP=$(expand_path "$SRC")
  if is_remote_url "$DST"; then
	DST_EXP="$DST"
  else
	DST_EXP=$(expand_path "$DST")
  fi

  # Normalizar paths
  ORIG="${ORIG_EXP%/}/"
  # construir nombres seguros
  nom_pc_seguro=$(sanitizar_nombre_directorio "$nom_pcu")
  # nombre del respaldo: usar basename del origen si no hay nom_origen
  tmpbase=$(basename "${ORIG_EXP%/}")
  nom_or_seguro=$(sanitizar_nombre_directorio "${nom_origen:-$tmpbase}")
  DEST="${DST_EXP%/}/$nom_pc_seguro/$nom_or_seguro/"
  # Si destino es local, crear la ruta completa (evita errores de df/du sobre path inexistente)
  if ! is_remote_url "$DST_EXP"; then
	mkdir -p "$DEST" || { err "No se pudo crear destino local $DEST"; return 1; }
  fi

  # preparar exclusiones (igual que en respaldo)
  if [ -f "$DIR_SCRIPT/exclude_list.txt" ]; then
	nic_modexclude=( --exclude-from "$DIR_SCRIPT/exclude_list.txt" )
  else
	nic_modexclude=( --exclude '.*' --exclude '.cache/google-chrome' --exclude '.config/google-chrome' --exclude 'VirtualBox VMs/' )
  fi

  # preparar opciones rsync usando get_rsync_opts
  get_rsync_opts "$ORIG" "$DEST" nic_modarr
  # get_rsync_opts dejó el array en named var nic_modarr (por convención)
  eval "nic_modarr=( \"\${nic_modarr[@]}\" )"

  # añadir dry-run si lo piden
  if [[ $DRY_RUN -eq 1 ]]; then
	nic_modarr+=(--dry-run)
  fi

  # añadir --rsync-path si destino es scp-like (crear ruta remota)
  if [[ "$DEST" =~ ^([^@]+@[^:]+):(.+)$ ]]; then
	remote_path="${BASH_REMATCH[2]%/}"
	nic_modarr+=( "--rsync-path=$(printf "mkdir -p %q && rsync" "$remote_path")" )
  fi

  # preparar logfile específico para esta ejecución
  lnfecha=$(date +%Y-%m-%d_%H-%M-%S)
  nic_log="$DIR_SCRIPT/logs/BACKUP-noninteractive-$lnfecha.log"
  mkdir -p "$(dirname "$nic_log")" 2>/dev/null || true

  # Llamada a do_rsync usando nombres de arrays (do_rsync soporta nombres)
  do_rsync "" "$ORIG" "$DEST" "non-interactive" "$nic_log" nic_modarr nic_modexclude
  return $?
}

# Si estamos en modo no interactivo, ejecutar y salir
if [[ $NON_INTERACTIVE -eq 1 ]]; then
  run_non_interactive
  rc=$?
  if [[ $rc -ne 0 ]]; then
	err "Ejecución no interactiva falló con código $rc"
  fi
  exit $rc
fi
# fin modo no interactivo
# ==============================
# ini pruebas
pruebas(){
	#descargar_sftp "52094416.es.strato-hosting.eu@ssh.strato.com:/mail/" "/home/ricardo/Documentos/P/"
    echo ""
	#restore_lamp#
	# local backup_src="/media/ricardo/WDESBAC12TB/BACKUP/$nom_pcu/LAMP" #"/home/$USER"
	# local target_zend="/var/lib/ZendFramework/"
	# local zend_src
	# zend_src=$(find "$backup_src" -maxdepth 1 -type d -name 'ZendFramework*' | sort | head -n 1)
	# echo "zend_src=$zend_src"
	# if [[ -n "$zend_src" ]]; then
	# 	log "Crear backup por si algo falla" "alerta"
	# 	log "mv ${target_zend} ${target_zend}_error_backup"
	# 	#mv "${target_zend}" "${target_zend}_error_backup"
	# 	#sudo mv /var/lib/ZendFramework /var/lib/ZendFramework_error_backup

	# 	#Añadir / al final de $zend_src para que sincronice el directorio y no acave en /var/lib/ZendFramework/ZendFramework
	# 	zend_src+="/"
	# 	log "Restaurando ZendFramework desde $zend_src a $target_zend"
	# 	log "sudo" "rsync -aHv" "$zend_src" "$target_zend" "ZendFramework" "$logfile"
	# 	#sudo rsync -aHv --delete "$zend_src"/ "$target_zend" 2>&1 | tee -a "$logfile" || rc=1
	# 	#do_rsync "sudo" "$zend_src" "$target_zend" "ZendFramework" "$logfile" #modarr modexarr "$MI_PASSWORD"
	# 	#rc=$?
	# else
	# 	log "No existe backup de ZendFramework en $backup_src" "error"
	# 	rc=1
	# fi


	# local backup_src="/media/ricardo/WDESBAC12TB/BACKUP/$nom_pcu/LAMP" #"/home/$USER"
	# local target_filezilla="$DIR_USUARIO/.config/filezilla/"
	# local target_sites="/etc/apache2/sites-available/"
	# local target_sql="/home/sql/"
	# local target_zend="/var/lib/ZendFramework/"
	# local target_daw="/home/$USER/Documentos/DAW2/"
	# local target_workspace="$DIR_USUARIO/workspace/"
	# restore_path() {
	# 	local src="$1"
	# 	local dst="$2"
	# 	local label="$3"

	# 	if [[ -d "$src" && -n "$(find "$src" -mindepth 1 | head -n 1)" ]]; then
	#     	src+="/"
	#     	log "Restaurando $label desde $src a $dst"
	#     	if [[ "$dst" == "$target_filezilla" || "$dst" == "$target_sites" || "$dst" == "$target_sql" || "$dst" == "$target_zend" ]]; then
	#         	#sudo rsync -aHv --delete "$src"/ "$dst" 2>&1 | tee -a "$logfile" || rc=1
	#         	sup="sudo"
	#     	else
	#         	#rsync -aHv --delete "$src"/ "$dst" 2>&1 | tee -a "$logfile" || rc=1
	#         	sup=""
	#     	fi
	#     	log "$sup" "rsync -aHv" "$src" "$dst" "$label" "$logfile"
	#     	#do_rsync "$sup" "$src" "$dst" "$label" "$logfile" #modarr modexarr "$MI_PASSWORD"
	#     	rc=$?
	# 	else
	#     	log "No existe o está vacío el directorio de backup $label: $src" "error"
	#     	rc=1
	# 	fi
	# }

	# restore_path "$backup_src/filezilla" "$target_filezilla" "FileZilla"
	# restore_path "$backup_src/sites-available" "$target_sites" "Apache sites-available"
	# restore_path "$backup_src/sql" "$target_sql" "SQL dumps"
	# restore_path "$backup_src/DAW2" "$target_daw" "DAW2"
	# restore_path "$backup_src/workspace" "$target_workspace" "Workspace"
}
# ==============================

# ==============================
# MENUS
# ==============================
#ini menú
menu(){
	clear
	pruebas
	validar_herramientas
	log "==============================" "menu"
	log "Inicio: $start_time" "menu"
	log "Hola $USER, veo que estás en $DIR_ACTUAL." "menu"
	log "Bienbenid@s a nuestro Script de BACKUP." "menu"
	log "Selecciona una opción:" "menu"
	log "==============================" "menu"
	log "1. Crear/Actualizar respaldo" "menu"
	log "2. Restaurar respaldo" "menu"
	log "3. Crear claves SSH públicas/privadas (Automatizar accesos)" "menu"
	log "4. Vincular cuenta de Google Drive (Respaldos en la nube)" "menu"
    log "0. SALIR" "menu"
	#read -p "Opción: ${NC}" opcion #leer por terminal la opción
	echo -e -n "$(pintar "Opción [1,2,0]: " "prompt")"
	read -r opcion
}
# fin menú
# ==============================
# ini menú origen
menu_origen(){
	clear
	log "==============================" "menu"
	log "BACKUP: Crear/Actualizar respaldo" "menu"
	log "==============================" "menu"
	log "¿De qué quieres hacer el respaldo?" "menu"
	log "1. Directorio actual: $DIR_ACTUAL" "menu"
	log "2. Directorio del script: $DIR_SCRIPT" "menu"
	log "3. Directorio del usuario: $DIR_USUARIO" "menu"
	log "4. Escribir ruta de directorio" "menu"
	log "5. Sistema LAMP (Directorio /workspace, Bases de datos MySQL, Configuración de Apache, Filezilla y ZendFramework)" "menu"
	log "0. VOLVER" "menu"
	#read -p "Opción [3 por defecto]: " opcion2
	echo -e -n "$(pintar "Opción [3 por defecto]: " "prompt")"
	read -r opcion2
	opcion2=${opcion2:-3}
}
# fin menú origen
# ==============================
#ini menú destino
menu_destino(){
	log "==============================" "menu"
	log "BACKUP: Crear/Actualizar respaldo" "menu"
	log "==============================" "menu"
	log "¿Donde guardar el respaldo?" "menu"
	log "1. Directorio actual: $DIR_ACTUAL" "menu"
	log "2. Directorio del script: $DIR_SCRIPT" "menu"
	log "3. Directorio del usuario: $DIR_USUARIO" "menu"
	log "4. Escribir ruta de directorio" "menu"
	log "0. VOLVER"
	#read -p "Opción [2 por defecto]: " opcion3
	echo -e -n "$(pintar "Opción [2 por defecto]: " "prompt")"
	read -r opcion3
	opcion3=${opcion3:-2}
}
# fin menú destino
# ==============================

# ==============================
# ACCIONES
# ==============================
# ini bucle respaldo
bucle_respaldo(){
	while [[ "$opcion3" != "0" ]]
	do
    	#invocamos el menú de selección de destino
    	menu_destino
    	norespaldar=0
    	case $opcion3 in
        	1)
            	dirdestino=$DIR_ACTUAL
            	;;
        	2)
            	dirdestino=$DIR_SCRIPT
            	;;
        	3)
            	dirdestino=$DIR_USUARIO
            	;;
        	4)
            	read -rp "$(pintar "Ingrese la ruta del directorio de destino: " "prompt")" dirdestino
            	dirdestino=$(expand_path "$dirdestino")
            	;;
        	0)
            	log "Opción 0. Volver al menú principal"
            	break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
            	;;
        	*)
            	log "Opción no válida"
            	;;
    	esac
    	if [[ $norespaldar -eq 1 ]]; then
        	log "No se realizará el respaldo debido a errores de espacio, formato o permisos." "error"
        	#break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
    	else
        	comprobaciones
        	respaldo
        	rc=$?
        	if [[ $rc -eq 0 ]]; then
            	#read -p "Pulse una tecla para volver al menú principal..."
            	break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
        	fi
    	fi
	done
	read -p "$(pintar "Pulse una tecla para continuar..." "prompt")"
}
# fin bucle respaldo
# ==============================
# ini comprobaciones de espacio y formato de partición
comprobaciones(){
	log "==============================" "menu"
	log "Respaldo en directorio actual" "menu"
	log "==============================" "menu"
	#Revisar si el dirdestino es un directorio válido
	local retorna=0
	if [ "$opcion2" = "1" ]; then
    	log "Respaldo del directorio actual"
    	diro=$(basename "$DIR_ACTUAL")
    	clean_dir="${diro%/}"
    	nom_origen="${clean_dir##*/}"
	elif [ "$opcion2" = "2" ]; then
    	log "Respaldo del directorio del script"
    	diro=$(basename "$DIR_SCRIPT")
    	clean_dir="${diro%/}"
    	nom_origen="${clean_dir##*/}"
	elif [ "$opcion2" = "3" ]; then
    	log "Respaldo del directorio del usuario"
    	nom_origen="$USUARIO"
	elif [ "$opcion2" = "4" ]; then
    	log "Respaldo de un directorio especificado por el usuario"
    	diro=$(basename "$dirorigen")
    	clean_dir="${diro%/}"
    	if is_remote_url "$dirorigen"; then
        	parsear_ruta_remota "$dirorigen"
        	log "host_remoto=$host_remoto"
        	nom_host=$(sanitizar_nombre_directorio "$host_remoto")
        	log "nom_host=$nom_host"
        	nom_host_recortado="${nom_host:${#nom_host}<20?0:${#nom_host}-20}"
        	log "nom_host_recortado=$nom_host_recortado"
        	nom_origen="${nom_host_recortado}-${clean_dir##*/}"
        	#nom_origen="${nom_host: -20}-${clean_dir##*/}"
        	log "nom_origen=$nom_origen"
    	else
        	nom_origen="${clean_dir##*/}"
    	fi
	elif [ "$opcion2" = "5" ]; then
    	log "Respaldo del sistema LAMP (Directorio /workspace, Bases de datos MySQL, Configuración de Apache, Filezilla y ZendFramework)"
    	nom_origen="LAMP"
	else
    	log "Opción de origen no válida"
    	nom_origen="Respaldo"
	fi
	log "Nombre del respaldo: $nom_origen"
	log "Directorio de origen: $dirorigen"
	log "Directorio de destino: $dirdestino"

	if is_remote_url "$dirdestino"; then
    	#echo -e "${ROJO}[ERROR] El directorio de destino es remoto: $dirdestino ${NC}"
    	# dentro de la función comprobaciones, sustituir la rama remota por:
    	log "Destino remoto detectado: $dirdestino"
    	# scp-like (user@host:/path) o rsync:// -> usar rsync/ssh
    	if [[ "$dirdestino" =~ ^[^/]+@[^:]+: ]] || [[ "$dirdestino" =~ ^rsync:// ]]; then
        	hostpart="${dirdestino%%:*}"
        	pathpart="${dirdestino#*:}"
        	log "Comprobando acceso SSH/rsync a $hostpart..."
        	#if ssh -o BatchMode=yes -o ConnectTimeout=5 "$hostpart" "test -d '$pathpart' >/dev/null 2>&1"; then
        	if ssh -o BatchMode=no -o PreferredAuthentications=publickey,password -o ConnectTimeout=5 "$hostpart" "test -d '$pathpart' >/dev/null 2>&1"; then
        	#if ssh -o ConnectTimeout=5 "$hostpart" "test -d '$pathpart' >/dev/null 2>&1"; then
            	log "Destino accesible por SSH."
        	else
            	log "No se pudo verificar existencia remota; rsync intentará crear el destino si es necesario."
        	fi
        	sinespacio=0
        	formatoinadecuado=0
        	permisosincorrectos=0
        	return 0
    	else
        	# otros schemes -> rclone
        	if command -v rclone >/dev/null 2>&1; then
            	if rclone ls "$dirdestino" --max-age 1h >/dev/null 2>&1; then
                	log "Destino rclone accesible."
                	sinespacio=0
                	formatoinadecuado=0
                	permisosincorrectos=0
                	return 0
            	else
                	log "No se pudo listar el destino remoto con rclone." "error"
                	return 1
            	fi
        	else
            	log "Ruta remota no soportada y rclone no instalado." "error"
            	return 1
        	fi
    	fi
   	 
    	#read -p "${AMARILLO}Pulse una tecla para continuar...${NC}"
   		return 1
	elif [ -d "$dirdestino" ]; then
    	# --- Manejo especial para origen remoto ---
    	# if is_remote_url "$dirorigen"; then
        # 	if [[ "$dirorigen" =~ ^([^@]+@[^:]+):(.+)$ ]]; then
        #     	origin_host="${BASH_REMATCH[1]}"
        #     	origin_path="${BASH_REMATCH[2]%/}"
        # 	else
        #     	origin_host=""
        #     	origin_path="$dirorigen"
        # 	fi
        # 	log "Origen remoto detectado: ${origin_host}:${origin_path}"
		# 	log "Verificando capacidades del servidor remoto..." "info"
			
		# 	# if ! check_remote_capabilities "$dirorigen"; then
		# 	# 	log "[ALERTA] Servidor remoto restringido detectado (Capado). Asignando valores por defecto seguros." "alerta"
		# 	if [[ "$origin_host" == *strato* ]] || ! ssh -o ConnectTimeout=3 -o BatchMode=no "$origin_host" "true" >/dev/null 2>&1; then
		# 		log "[ALERTA] Servidor remoto restringido detectado (Strato/Capado). Forzando validación SFTP." "alerta"
	
		# 		# Valores por defecto para evitar errores matemáticos y bloqueos
		# 		espacio_origen_bytes=0
		# 		espacio_origen="0.000"
		# 		formato_origen="ext4"
		# 		particion_origen="[unknown]"
				
		# 		# Saltamos el bloque interactivo de cálculo SSH para este origen
		# 		skip_remote_ssh_calc=1
		# 	else
		# 		skip_remote_ssh_calc=0
		# 	fi
		# else
		# 	skip_remote_ssh_calc=0
		# fi
		# # --- COMPROBACIÓN DE ACCESO AL ORIGEN ---
		# if is_remote_url "$dirorigen"; then
		# 	if [[ "$skip_remote_ssh_calc" -eq 1 ]]; then
		# 		# Si está capado (Strato), validamos la existencia usando tu función de SFTP en modo simulación (1)
		# 		log "Validando existencia del directorio origen vía SFTP..."
		# 		descargar_sftp "$dirorigen" "$dirdestino" 1
		# 		if [ $? -eq 0 ]; then
		# 			log "Origen remoto accesible mediante SFTP." "exito"
		# 			espacio_origen_bytes=0
		# 			espacio_origen="0.000"
		# 			formato_origen="ext4"
		# 			particion_origen="[unknown]"
		# 		else
		# 			log "No se pudo conectar por SFTP o no existe el directorio remoto: $dirorigen" "error"
		# 			return 1
		# 		fi
		# 	else
		# 		# Si NO está capado, procedemos con rsync/ssh/rclone estándar
		# 		log "Obteniendo datos del origen remoto estándar: ${origin_host}:${origin_path}"
		# 		if [[ "$dirorigen" =~ ^[^/]+@[^:]+: ]] || [[ "$dirorigen" =~ ^rsync:// ]]; then
		# 			if ssh -o ConnectTimeout=5 "$origin_host" "test -d '$origin_path'" >/dev/null 2>&1; then
		# 				log "Origen remoto accesible."
		# 			else
		# 				log "No se pudo verificar existencia del origen remoto de forma estándar: $dirorigen " "error"
		# 				return 1
		# 			fi
		# 		else
		# 			if command -v rclone >/dev/null 2>&1 && rclone lsf --max-depth 1 "$dirorigen" >/dev/null 2>&1; then
		# 				log "Origen remoto accesible mediante rclone."
		# 			else
		# 				log "No se pudo conectar o no existe el origen remoto con rclone: $dirorigen " "error"
		# 				return 1
		# 			fi
		# 		fi
				
		# 		# Obtener pesos del origen remoto no capado
		# 		log "Obteniendo datos del origen"
		# 		set +e
		# 		espacio_origen_bytes=$(obtener_tamano_dir_bytes "$dirorigen")
		# 		if [ "$espacio_origen_bytes" -gt 0 ] 2>/dev/null; then
		# 			espacio_origen=$(awk -v b="$espacio_origen_bytes" 'BEGIN {printf "%.3f", (b/1073741824)}')
		# 		else
		# 			espacio_origen_bytes=0
		# 			espacio_origen="0.000"
		# 		fi
		# 	fi
		# fi

		# =======================================================
		# --- BLOQUE 1: EXTRACCIÓN Y DETECCIÓN PRELIMINAR -------
		# =======================================================
		if is_remote_url "$dirorigen"; then
			if [[ "$dirorigen" =~ ^[^/]+@[^:]+: ]] || [[ "$dirorigen" =~ ^rsync:// ]]; then
				if [[ "$dirorigen" =~ ^([^@]+@[^:]+):(.+)$ ]]; then
					origin_host="${BASH_REMATCH[1]}"
					origin_path="${BASH_REMATCH[2]%/}"
				else
					origin_host=""
					origin_path="$dirorigen"
				fi
				log "Origen remoto SSH detectado: ${origin_host}:${origin_path}"
				
				if [[ "$origin_host" == *strato* ]] || ! ssh -o ConnectTimeout=3 -o BatchMode=no "$origin_host" "true" >/dev/null 2>&1; then
					log "[ALERTA] Servidor remoto restringido detectado (Strato/Capado). Forzando validación SFTP." "alerta"
					skip_remote_ssh_calc=1
				else
					skip_remote_ssh_calc=0
				fi
			else
				log "Origen remoto Cloud (rclone) detectado: $dirorigen"
				skip_remote_ssh_calc=1
				
				if command -v rclone >/dev/null 2>&1; then
					log "Verificando existencia del directorio en la nube con rclone..."
					if rclone lsf --max-depth 1 "$dirorigen" >/dev/null 2>&1; then
						log "Origen remoto en la nube accesible mediante rclone." "exito"
						espacio_origen_bytes=0
						espacio_origen="0.000"
						formato_origen="rclone"
						particion_origen="[cloud]"
					else
						log "No se pudo conectar o no existe el directorio indicado en tu Drive: $dirorigen" "error"
						return 1
					fi
				else
					log "Ruta Cloud detectada pero rclone no está instalado en el sistema." "error"
					return 1
				fi
			fi
		else
			skip_remote_ssh_calc=0
		fi

		# =======================================================
		# --- BLOQUE 2: COMPROBACIÓN DE ACCESO AL ORIGEN ---------
		# =======================================================
		if is_remote_url "$dirorigen"; then
			# Solo aplicamos la validación SFTP/SSH si la URL remota es de tipo usuario@host
			if [[ "$dirorigen" =~ ^[^/]+@[^:]+: ]] || [[ "$dirorigen" =~ ^rsync:// ]]; then
				if [[ "$skip_remote_ssh_calc" -eq 1 ]]; then
					# Si está capado (Strato), validamos la existencia usando tu función de SFTP en modo simulación (1)
					log "Validando existencia del directorio origen vía SFTP..."
					descargar_sftp "$dirorigen" "$dirdestino" 1
					if [ $? -eq 0 ]; then
						log "Origen remoto accesible mediante SFTP." "exito"
						espacio_origen_bytes=0
						espacio_origen="0.000"
						formato_origen="ext4"
						particion_origen="[unknown]"
					else
						log "No se pudo conectar por SFTP o no existe el directorio remoto: $dirorigen" "error"
						return 1
					fi
				else
					# Si NO está capado, procedemos con rsync/ssh estándar
					log "Obteniendo datos del origen remoto estándar: ${origin_host}:${origin_path}"
					if ssh -o ConnectTimeout=5 "$origin_host" "test -d '$origin_path'" >/dev/null 2>&1; then
						log "Origen remoto accesible."
					else
						log "No se pudo verificar existencia del origen remoto de forma estándar: $dirorigen " "error"
						return 1
					fi
					
					# Obtener pesos del origen remoto no capado
					log "Obteniendo datos del origen"
					set +e
					espacio_origen_bytes=$(obtener_tamano_dir_bytes "$dirorigen")
					if [ "$espacio_origen_bytes" -gt 0 ] 2>/dev/null; then
						espacio_origen=$(awk -v b="$espacio_origen_bytes" 'BEGIN {printf "%.3f", (b/1073741824)}')
					else
						espacio_origen_bytes=0
						espacio_origen="0.000"
					fi
				fi
			else
				# Si es un remoto Cloud (rclone / Google Drive), ya fue validado en el bloque superior.
				# No hacemos nada aquí para evitar que intente conectar usando SFTP.
				:
			fi
		fi

		if is_remote_url "$dirorigen"; then
        	# Marcar `dirorigenC` con el valor remoto para evitar realpath en rutas remotas
        	dirorigenC="$dirorigen"
    	else
        	dirorigenC=$(realpath "$dirorigen")
    	fi
    	#dirorigenC=$(realpath "$dirorigen")
    	dirdestinoC=$(realpath "$dirdestino")
    	if [ "$dirorigenC" == "$dirdestinoC" ]; then
        	log "El directorio de origen y destino no puede ser el mismo, para evitar bucles infinitos de copia." "error"
        	dirsincompatibles=1
    	elif [[ "$dirdestinoC" == "$dirorigenC/"* ]]; then
        	log "[ERROR]: el destino no debe estar dentro del origen, para evitar bucles infinitos de copia." "error"
        	dirsincompatibles=1
    	fi
		# --- PROCESAMIENTO FINAL DE ESPACIO Y FORMATOS ---
		if [[ "$skip_remote_ssh_calc" -eq 0 ]] || ! is_remote_url "$dirorigen"; then
			#Recojer datos de espacio y formato de partición
			#formato_origen=$(df -TBG "$dirorigen" | awk 'NR==2 {print $2}')
			formato_origen=$(obtener_tipo_fs "$dirorigen")
			if [[ $formato_origen == "unknown" || $formato_origen == "-" || $formato_origen == "" ]]; then
				formato_origen="ext4"
			fi
			#espacio_origen_bytes=$(du -sb "$dirorigen" 2>/dev/null | awk '{print $1}')
			espacio_origen_bytes=$(obtener_tamano_dir_bytes "$dirorigen")
			if [[ -z "$espacio_origen_bytes" ]]; then espacio_origen_bytes=0; fi
			espacio_origen=$(awk -v b="$espacio_origen_bytes" '
				function ceil(x){ return (x==int(x)? x : int(x)+1) }
				BEGIN {
					v = b / 1073741824
					v = ceil(v * 1000) / 1000
					if (v == 0 && b > 0) v = 0.001
					printf "%.3f", v
				}')
			# Prevenir nulos si obtener_tamano_dir_bytes falla localmente
			#espacio_origen=$(awk -v b="$espacio_origen_bytes" 'BEGIN {printf "%.3f", (b/1073741824)}')
		fi
		# 3. VOLVEMOS a encender el modo estricto para mantener la seguridad del script
		set -e
    	#Recojer datos de espacio y formato de partición destino
    	#formato_destino=$(df -TBG "$dirdestino" | awk 'NR==2 {print $2}')
    	formato_destino=$(obtener_tipo_fs "$dirdestino")
    	#espacio_destino_bytes=$(df --output=avail -B1 "$dirdestino" | tail -n 1 | tr -d '[:space:]')
    	espacio_destino_bytes=$(obtener_espacio_libre_bytes "$dirdestino")
    	espacio_destino=$(awk -v b="$espacio_destino_bytes" '
        	function ceil(x){ return (x==int(x)? x : int(x)+1) }
        	BEGIN {
            	v = b / 1073741824
            	v = ceil(v * 1000) / 1000
            	if (v == 0 && b > 0) v = 0.001
            	printf "%.3f", v
        	}')
    	log "Espacio ocupado del origen: ${espacio_origen} GB en partición: [$formato_origen]"
    	log "Espacio disponible en destino: ${espacio_destino} GB en partición: [$formato_destino]"
    	log "Comparación de bytes: ${espacio_destino_bytes} - ${espacio_origen_bytes} = $(echo "$espacio_destino_bytes - $espacio_origen_bytes" | bc) bytes quedarn disponibles."

    	#Comprobación de espacio
    	if [[ $espacio_origen_bytes -le $espacio_destino_bytes ]]; then
        	log "Cabe en el destino"
        	sinespacio=0
    	else
        	log "No cabe, elija otro destino"
        	sinespacio=1
    	fi
    	#Comprobación de formato de partición
    	# is_posix_fs() {
    	# 	case "$1" in
    	#     	ext2|ext3|ext4|xfs|btrfs|f2fs|zfs|jfs) return 0 ;;
    	#     	*) return 1 ;;
    	# 	esac
    	# }
    	if is_posix_fs "$formato_origen" && is_posix_fs "$formato_destino"; then
        	log "Origen y destino son sistemas POSIX compatibles, se conservarán los permisos de archivos y directorios"
        	formatoinadecuado=0
    	else
        	log "Destino no soporta permisos/propietarios completos, usar rsync sin metadatos POSIX, se recomienda usar particiones ext4"
        	formatoinadecuado=1
    	fi

    	#Comprovación de permisos de escritura en el destino
    	if [ -w "$dirdestino" ]; then
        	log "Permisos de escritura en el destino: OK"
        	permisosincorrectos=0
    	else
        	log "Permisos de escritura en el destino: NO OK"
        	log "Se intentará usar sudo para el respaldo"
        	permisosincorrectos=1
    	fi
    	return $retorna
	else
    	log "No existe el directorio de destino: $dirdestino " "error"
    	return 1
	fi
}
# fin comprobaciones
# ==============================
# ini respaldo
respaldo(){
	local sup=""
	local comando="rsync"
	local mod="-aAXvh --delete --numeric-ids --progress"
	local excluir="s"
	if [ -f "$DIR_SCRIPT/exclude_list.txt" ]; then
    	#local modexclude="--exclude-from='exclude_list.txt'"
    	#mapfile -t modexclude < <(sed 's/^/--exclude /' "$DIR_SCRIPT/exclude_list.txt")
    	modexclude=( --exclude-from "$DIR_SCRIPT/exclude_list.txt" )
	else
    	#Por defecto se excluyen archivos sensibles de Google Chrome y VirtualBox, además de archivos ocultos
    	#local modexclude="--exclude '.*' --exclude '.cache/google-chrome' --exclude '.config/google-chrome' --exclude 'VirtualBox VMs/'"
    	modexclude=( --exclude '.*' --exclude '.cache/google-chrome' --exclude '.config/google-chrome' --exclude 'VirtualBox VMs/' )
	fi
	local origen="$dirorigen/"
	local fecha=$(date +%Y-%m-%d_%H-%M-%S)
	local nom_pc=$nom_pcu
	local nom_or=${nom_origen:0:40}
	local nom_pc_seguro=$(sanitizar_nombre_directorio "$nom_pc")
	local nom_or_seguro=$(sanitizar_nombre_directorio "$nom_or")
	# normalizar dirdestino sin tocar el prefijo user@host: (si es remoto)
	if is_remote_url "$dirdestino" && [[ "$dirdestino" =~ ^([^@]+@[^:]+):(.+)$ ]]; then
    	hostpart="${BASH_REMATCH[1]}"
    	pathpart="${BASH_REMATCH[2]}"
    	# quitar slashes dobles y trailing slash
    	pathpart="${pathpart//\/\//\/}"
    	pathpart="${pathpart%/}"
    	dirdestino="${hostpart}:${pathpart}"
	else
    	dirdestino=$(expand_path "$dirdestino")
    	dirdestino="${dirdestino%/}"
	fi
	# si es remoto, evita que quede "user@host:/.../user@host:..." (ya normalizado arriba)
	local destino="$dirdestino/$nom_pc_seguro/$nom_or_seguro/"
	#local estado=$1
	local continua=0
	if [[ $sinespacio -eq 0 && $dirsincompatibles -eq 0 && $formatoinadecuado -eq 0 ]]; then
    	log "Se conservarán los permisos de archivos y directorios."
    	continua=1
	elif [[ $sinespacio -eq 0 && $dirsincompatibles -eq 0 && $formatoinadecuado -eq 1 ]]; then
    	log "No se conservarán los permisos de archivos y directorios."
    	continua=1
    	mod="-aHv --delete --numeric-ids --progress --no-perms --no-owner --no-group --chmod=ugo=rwX"
	elif [[ $dirsincompatibles -eq 1 ]]; then
    	log "Directorios incompatibles." "error"
    	continua=0
	else
    	log "No hay suficiente espacio." "error"
    	continua=0
	fi
	if is_remote_url "$dirdestino"; then
    	log "El destino es un directorio remoto"
	elif [ ! -d "$dirdestino" ]; then
    	log "No existe el directorio de destino: $dirdestino " "error"
    	continua=0
	fi
	if [[ $continua -eq 1 ]]; then
    	if [[ $permisosincorrectos -eq 1 ]]; then
        	log "No se tienen permisos de escritura en el destino, se intentará usar sudo"
        	sup="sudo"
    	else
        	log "Se tienen permisos de escritura en el destino"
        	read -rp "$(pintar "Deseas respaldar también archivos de otros usuarios? (s/N): " "prompt")" superuser
        	superuser=${superuser:-n}
        	if [[ $superuser == "s" || $superuser == "S" ]]; then
            	sup="sudo"
        	fi
    	fi
    	if [[ $sup == "sudo" ]]; then

        	# # 1. Solicitar la contraseña de forma segura al inicio (ocultando los caracteres)
        	# read -sp "${AMARILLO}Introduce tu contraseña para sudo: ${NC}" MI_PASSWORD
        	# echo "" # Salto de línea necesario tras ocultar la entrada

        	# # 2. Validar que la contraseña introducida es correcta antes de continuar
        	# echo "$MI_PASSWORD" | sudo -S -v &>/dev/null
        	# if [ $? -ne 0 ]; then
        	# 	echo -e "${ROJO}❌ Contraseña incorrecta. El script se va a cerrar.${NC}"
        	# 	unset MI_PASSWORD # Destruir la variable por seguridad antes de salir
        	# 	exit 1
        	# fi
        	# #ÉXITO: Destruir la variable de contraseña INMEDIATAMENTE de la memoria del script
        	# unset MI_PASSWORD
        	# echo "✅ Contraseña validada correctamente."
        	garantizar_sudo
    	fi

    	log "Directorio de respaldo: $destino"
    	read -rp "$(pintar "Deseas un nombre diferente para organizar los archivos? (s/N): " "prompt")" renombrardestino
    	renombrardestino=${renombrardestino:-n}
    	if [[ $renombrardestino == "s" || $renombrardestino == "S" ]]; then
        	read -rp "$(pintar "Ingrese el nombre del equipo (por defecto: $nom_pc): " "prompt")" nom_pc
        	nom_pc=${nom_pc:-"$nom_pc"}
        	read -rp "$(pintar "Ingrese el nombre del respaldo (por defecto: $nom_or): " "prompt")" nom_origen
        	nom_or=${nom_origen:-"$nom_or"}
        	nom_pc_seguro=$(sanitizar_nombre_directorio "$nom_pc")
        	nom_or_seguro=$(sanitizar_nombre_directorio "$nom_or")
        	destino="$dirdestino/$nom_pc_seguro/$nom_or_seguro/"
    	fi
    	log "Directorio de respaldo: $destino"
    	read -rp "$(pintar "Deseas un respaldo incremental? (S/n): " "prompt")" incremental
    	incremental=${incremental:-s}
    	if [[ $incremental == "n" || $incremental == "N" ]]; then
        	local destino="$dirdestino/$nom_pc/$nom_or-$fecha/"
    	fi
    	log "Directorio de respaldo: $destino"
    	# Crear directorios de destino si no existen
    	if [ -d "$destino" ]; then
        	log "El directorio $destino ya existe."
    	elif is_remote_url "$destino"; then
        	log "El directorio $destino es remoto."
    	else
        	log "El directorio $destino no existe. Creando directorio..."
        	$sup mkdir -p "$destino" || { log "No se pudo crear el directorio $destino" "error"; return 1; }
    	fi

    	read -rp "$(pintar "Deseas excluir archivos sensibles? (S/n): " "prompt")" excluir
    	excluir=${excluir:-s}
    	if [[ $excluir == "n" || $excluir == "N" ]]; then
        	modexclude=()
    	fi
    	log "comando a ejecutar: $sup $comando $mod $modexclude '$origen' '$destino'"
    	read -rp "$(pintar "Deseas modificar las opciones de respaldo? (s/N): " "prompt")" excluir
    	excluir=${excluir:-n}
    	if [[ $excluir == "s" || $excluir == "S" ]]; then
        	read -rp "$(pintar "Ingrese las opciones de respaldo (por defecto: -aAXvh --delete --numeric-ids --progress): " "prompt")" mod
        	mod=${mod:-"-aAXvh --delete --numeric-ids --progress"}
    	fi
    	log "comando a ejecutar: $sup $comando $mod $modexclude '$origen' '$destino'"
    	read -rp "$(pintar "Deseas iniciar el respaldo? (S/n): " "prompt")" confirmacion
    	confirmacion=${confirmacion:-s}
    	if [[ $confirmacion == "s" || $confirmacion == "S" ]]; then
        	log "Iniciando respaldo..."
        	#Calculo de tiempo de inicio
        	#start_time_rsync=`date +"%T"`

        	# Preparar log
        	# logfile="$DIR_SCRIPT/BACKUP-${fecha}.log"
        	# mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
        	# echo "Registro: $logfile"
        	set_logfile "BACKUP-$nom_pcu-$nom_or"

        	#COMANDO DE RESPALDO ($sup $comando $mod $modexclude '$origen' '$destino')
        	# COMANDO DE RESPALDO: construir array seguro y ejecutar
        	# Convertir las cadenas de opciones en arrays para evitar problemas de word-splitting
        	#read -r -a modarr <<< "$mod  --dry-run" #Prueva sin copiar archivos, para ver si hay errores de permisos o espacio
        	read -r -a modarr <<< "$mod" #Copiará los archivos
        	#read -r -a modexarr <<< "$modexclude"
        	local modexarr=( "${modexclude[@]}" )

        	do_rsync "$sup" "$origen" "$destino" "$nom_origen" "$logfile" modarr modexarr #"$MI_PASSWORD"
        	rc=$?
        	# cmd=()
        	# if [[ -n "$sup" ]]; then
        	# 	#cmd+=( "$sup" "rsync" )
        	# 	# rsync pasándole la contraseña por stdin
        	# 	cmd=( "sudo" "-S" "/usr/bin/rsync" )
        	# else
        	# 	cmd+=( "rsync" )
        	# fi
        	# cmd+=( "${modarr[@]}" "${modexclude[@]}" "$origen" "$destino" )

        	# # Mostrar comando (útil para depuración)
        	# echo "Ejecutando: ${cmd[*]}"

        	# Preparar log
        	# logfile="$DIR_SCRIPT/BACKUP-${fecha}.log"
        	# mkdir -p "$(dirname "$logfile")" 2>/dev/null || true
        	# echo "Registro: $logfile"

        	# # Ejecutar rsync
        	# if [[ -n "$sup" ]]; then
        	# 	# Ejecutar rsync con sudo y pasar la contraseña
        	# 	echo "$MI_PASSWORD" | "${cmd[@]}" 2>&1 | tee -a "$logfile"
        	# 	rsync_rc=${PIPESTATUS[1]} # Captura el código de salida de rsync, que es el segundo comando en la tubería
        	# else
        	# 	"${cmd[@]}" 2>&1 | tee -a "$logfile"
        	# 	rsync_rc=${PIPESTATUS[0]}
        	# fi
        	# #rsync_rc=$?

        	# if [[ $rsync_rc -ne 0 ]]; then
        	# 	echo -e "${ROJO}rsync devolvió código $rsync_rc. Revise los errores anteriores.${NC}"
        	# 	echo "rsync RC: $rsync_rc" | tee -a "$logfile"
        	# else
        	# 	echo -e "${VERDE}rsync completado correctamente (código 0).${NC}"
        	# fi

        	# echo -e "${VERDE}"
        	# echo "Respaldo finalizado."

        	# #Calculo de tiempo de fin
        	# end_time_rsync=`date +"%T"`
        	# start_seconds_rsync=$(date -d "$start_time_rsync" +%s)
        	# end_seconds_rsync=$(date -d "$end_time_rsync" +%s)
        	# datediff_rsync=$((end_seconds_rsync - start_seconds_rsync))

        	# elapsed_time_rsync=$(date -d @$datediff_rsync -u +%H:%M:%S)
        	# elapsed_hours_rsync=$((datediff_rsync/3600))
        	# elapsed_minutes_rsync=$(((datediff_rsync % 3600)/60))
        	# elapsed_seconds_rsync=$((datediff_rsync % 60))
        	# opcion2=0
        	# opcion3=0
        	# echo "HORA INICIO: $start_time_rsync"
        	# echo "HORA FIN: $end_time_rsync"
        	# echo "ELAPSED TIME: $elapsed_time_rsync"
        	# echo ""
        	# echo "EL PROCESO DEMORO ${elapsed_hours_rsync} HRS CON ${elapsed_minutes_rsync} MINS Y ${elapsed_seconds_rsync} SEGS EN EJECUTARSE."
        	# echo -e "${NC}"
        	reiniciar_variables
        	echo -e -n "$(pintar "Pulse una tecla para volver al menú principal..." "prompt")"
        	read -r
        	return 0
    	else
        	log "Respaldo cancelado."
        	echo -e -n "$(pintar "Pulse una tecla para volver al menú principal..." "prompt")"
        	read -r
        	return 0
    	fi
	fi
	return 1
}
# fin respaldo
# ==============================
# ini bucle_respaldo_LAMP
bucle_respaldo_LAMP(){
	while [[ "$opcion3" != "0" ]]
	do
    	#invocamos el menú de selección de destino
    	menu_destino
    	norespaldar=0
    	case $opcion3 in
        	1)
            	dirdestino=$DIR_ACTUAL
            	;;
        	2)
            	dirdestino=$DIR_SCRIPT
            	;;
        	3)
            	dirdestino=$DIR_USUARIO
            	;;
        	4)
            	read -rp "$(pintar "Ingrese la ruta del directorio de destino: " "prompt")" dirdestino
            	dirdestino=$(expand_path "$dirdestino")
            	;;
        	0)
            	log "Opción 0. Volver al menú principal"
            	break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
            	;;
        	*)
            	log "Opción no válida"
            	;;
    	esac
    	if [[ $norespaldar -eq 1 ]]; then
        	log "No se realizará el respaldo debido a errores de espacio, formato o permisos." "error"
        	#break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
    	else
        	backup_LAMP
        	rc=$?
        	if [[ $rc -eq 0 ]]; then
            	#read -p "Pulse una tecla para volver al menú principal..."
            	break 2   # sale de while opcion3 y while opcion2 y vuelve al while principal (donde se llama menu)
        	fi
    	fi
	done
	read -p "$(pintar "Pulse una tecla para continuar..." "prompt")"
}
# fin bucle_respaldo_LAMP
# ==============================
# ini backup_LAMP
backup_LAMP(){

	start_time_LAMP=$(date +"%T")
	# fecha=$(date +%Y-%m-%d-%H-%M-%S)
	# logfile="$DIR_SCRIPT/BACKUP-LAMP-${fecha}.log"
	# mkdir -p "$(dirname "$logfile")"
	set_logfile "BACKUP-$nom_pcu-LAMP"

	log "Iniciando respaldo del sistema LAMP..."
	nom_origen="LAMP"
	local DIRECTORIO="$dirdestino"
	local DIRLAMP="$dirdestino/$nom_pcu/$nom_origen"

	# normalizar y comprobar rutas
	dirsincompatibles=0
	dirorigenC=$(realpath "$dirorigen")
	dirdestinoC=$(realpath "$dirdestino")
	if [[ "$dirorigenC" == "$dirdestinoC" ]]; then
    	log "El directorio de origen y destino no puede ser el mismo." "error"
    	dirsincompatibles=1
	elif [[ "$dirdestinoC" == "$dirorigenC/"* ]]; then
    	log "El destino no debe estar dentro del origen." "error"
    	dirsincompatibles=1
	fi

	log 'Espacio en disco'
	#df -TBG "$DIRECTORIO" | tee -a "$logfile"
	mostrar_info_fs "$DIRECTORIO" "$logfile"
	#LIBRE=$(df --output=avail -BG "$DIRECTORIO" | tail -n 1 | tr -d '[:space:]' | tr -d 'G')
	LIBRE=$(obtener_espacio_libre_gb "$DIRECTORIO")
	log "${LIBRE} GB"

	formato_destino=$(obtener_tipo_fs "$DIRECTORIO")
	#echo "formato_destino=$formato_destino DIRECTORIO=$DIRECTORIO"
	if ! is_posix_fs "$formato_destino" ; then
    	log "El sistema de archivos de destino es ${formato_destino}, y no soporta los permisos de Linux, por lo que restaurar podría probocar fallos de permisos, use un disco ext4 para realizar el respaldo." "error"
    	echo -n "$(pintar "¿Desea asumir el riego? (s/N): " "prompt")"
    	read -r arriesgo
    	arriesgo=${arriesgo:-N}
    	if [[ "$arriesgo" =~ ^[nN]$ ]]; then
        	return 1
    	fi
	fi

	garantizar_sudo
	log 'Espacio de workspace'
	#sudo du -s -BG "$dirorigen" 2>&1 | tee -a "$logfile"
	mostrar_tamano_dir_log "$dirorigen" "$logfile"

	log 'Espacio de copia (estimado)'
	#TAM=$(du -csBG /home/"$USER"/.config/filezilla/ /etc/apache2/sites-available/ /home/sql/ /var/lib/ZendFramework* /home/"$USER"/workspace/ 2>/dev/null | awk '/total/ {print $1}' | tr -d 'G')
	TAM=$(obtener_tamano_multiples_dir_gb /home/"$USER"/.config/filezilla/ /etc/apache2/sites-available/ /home/sql/ /var/lib/ZendFramework* /home/"$USER"/workspace/)
	TAM=${TAM:-0}
	log "${TAM} GB "

	rc=0

	if [[ -d "$DIRECTORIO" && $dirsincompatibles -eq 0 ]]; then
    	log "Disco ${DIRECTORIO} montado"

    	if (( LIBRE >= TAM )); then
        	log "El directorio ${DIRECTORIO} tiene ${LIBRE} GB libres y la copia ${TAM} GB"
        	mkdir -p "$DIRLAMP" || log "No se pudo crear $DIRLAMP" "error"

        	# antes de usar do_rsync, inicializar y validar sudo:
        	local rc=0
        	local sudo_ok=""
        	if sudo -n true 2>/dev/null; then
            	sudo_ok="sudo"
        	else
            	# pedir credenciales interactivas (si el usuario acepta) y validar
            	echo -n "$(pintar "Se requieren permisos sudo para algunos elementos. ¿Desea introducir su contraseña? (S/n): " "prompt")"
            	read -r _want_sudo
            	_want_sudo=${_want_sudo:-S}
            	if [[ "$_want_sudo" =~ ^[sS]$ ]]; then
                	if sudo -v 2>/dev/null; then
                    	sudo_ok="sudo"
                	else
                    	log "No se pudo validar sudo. Se intentará continuar sin sudo." "error"
                    	sudo_ok=""
                	fi
            	else
                	log "Continuando sin sudo; algunas operaciones que requieren privilegios fallarán."
                	sudo_ok=""
            	fi
        	fi

        	if [[ -z "$prueba_rsync" ]]; then
            	log "A continuación se pregunta si estas haciendo pruebas. Si respondes 'S' no se copiarán los archivos y solo realizará una simulación, esta configuración durará mientras se ejecute el programa, para cambiarla tienes que salir del programa y volver a ejecutarlo. " "alerta"
            	read -rp "$(pintar "Estas haciendo pruebas? [N/s]: " "prompt")" prueba_rsync
            	prueba_rsync=${prueba_rsync:-n}
        	fi

        	if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then
            	modarr_ref+=(--dry-run)
        	fi

        	# usar epoch timestamps para duración
        	local start_ts=$(date +%s)
        	start_time_LAMP=$(date '+%F %T')

        	if ! command -v mysql &> /dev/null || ! command -v mysqldump &> /dev/null; then
            	log "No es posible respaldar las bases de datos porque falta instalar mysql o mysqldump." "error"
        	else
                # 1. Aseguramos que la carpeta local /home/sql exista y tenga los permisos limpios
                sudo mkdir -p /home/sql
                sudo chmod 755 /home/sql
            	echo -e -n "$(pintar "Deseas respaldar MySQL? [S/n]: " "prompt")"
            	read -r respaldarbd
            	respaldarbd=${respaldarbd:-S}
            	if [[ $respaldarbd == [Ss] ]]; then
                	log "Se realizará el respaldo de MySQL"
                	read -rp "$(pintar "Usuario de MySQL [admin]: " "prompt")" MYSQL_USER
                	MYSQL_USER=${MYSQL_USER:-admin}
                	read -s -rp "$(pintar "Contraseña de MySQL [admin]: " "prompt")" MYSQL_PASS
                	MYSQL_PASS=${MYSQL_PASS:-admin}
                	echo
                	read -rp "$(pintar "Host de MySQL [localhost]: " "prompt")" MYSQL_HOST
                	MYSQL_HOST=${MYSQL_HOST:-localhost}

                	export MYSQL_PWD="$MYSQL_PASS"
                	dbs=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -e "SHOW DATABASES;" -s --skip-column-names 2>>"$logfile" | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' || true)
                	unset MYSQL_PWD

                	if [[ -z "$dbs" ]]; then
                    	log "[WARN]: No se encontraron bases de datos para respaldar." "alerta"
                	else
                    	# Aseguramos que la carpeta local compartida exista con permisos limpios
                    	sudo mkdir -p /home/sql
                    	sudo chmod 755 /home/sql

                    	for db in $dbs; do
                        	log "Procesando base de datos: $db"
                        	
                        	if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then
                            	# --- MODO SIMULACIÓN ---
                            	log "[DRY-RUN] Simulación de volcado para la base de datos '$db'" "alerta"
                            	log "[DRY-RUN] mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p*** $db > /home/sql/${db}.sql"
                            	
                            	# Validamos de forma segura si la base de datos se puede leer sin escribir en disco
                            	if ! mysqldump -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db" > /dev/null 2>>"$logfile"; then
                                	log "Simulación fallida: mysqldump detectó errores en $db" "error"
                                	rc=1
                                	continue
                            	fi
                            	log "[DRY-RUN] Estructura de $db validada con éxito." "exito"
                        	else
                            	# --- MODO REAL ---
                            	log "Exportando volcado real de '$db' hacia /home/sql/${db}.sql..." "menu"
                            	
                            	# Forzamos a que sudo realice la exportación completa hacia la carpeta compartida
                            	if ! sudo sh -c "export MYSQL_PWD='$MYSQL_PASS'; mysqldump --opt -h '$MYSQL_HOST' -u '$MYSQL_USER' '$db' > '/home/sql/${db}.sql'" 2>>"$logfile"; then
                                	log "Error crítico: El volcado real falló para la base de datos $db" "error"
                                	rc=1
                                	continue
                            	fi
                            	log "Base de datos '$db' exportada correctamente." "exito"
                        	fi
                    	done

                    	# CORRECCIÓN DE PROPIETARIOS AL TERMINAR EL BUCLE:
                    	# Si no fue simulación, le damos la propiedad de los archivos a tu usuario sadmin 
                    	# para que el comando rsync posterior pueda empaquetarlos sin fallos de permisos.
                    	if [[ "$prueba_rsync" =~ ^[nN]$ ]]; then
                        	sudo chown -R "${USER}:${USER}" /home/sql
                    	fi
                	fi
            	else
                	log "No se realizará el respaldo de MySQL"
            	fi
        	fi
       	 
        	# Ahora copia cada componente, pero nunca sale si hay un error; marca rc=1 y continúa.
        	if [[ -d "/home/$USER/.config/filezilla/" ]]; then
            	mkdir -p "$DIRLAMP/filezilla"
            	do_rsync "$sudo_ok" "/home/$USER/.config/filezilla" "$DIRLAMP/filezilla" "filezilla"
            	#sudo chown -vR "$USER":"$USER" "$DIRLAMP/filezilla/"* 2>&1 | tee -a "$logfile" || true
            	#Evita el asterisco suelto y el '|| true'
            	cambiar_propietario_contenido "$DIRLAMP/filezilla" "$USER:$USER"
        	else
            	log "No existe el directorio de configuración de filezilla." "error"
            	#rc=1
        	fi

        	if [[ -d "/etc/apache2/sites-available" ]]; then
            	mkdir -p "$DIRLAMP/sites-available"
            	do_rsync "$sudo_ok" "/etc/apache2/sites-available" "$DIRLAMP/sites-available" "apache-sites"
            	#sudo chown -vR "$USER":"$USER" "$DIRLAMP/sites-available/"* 2>&1 | tee -a "$logfile" || true
            	#Si la sincronización trajo una carpeta vacía, no romperá el script
            	cambiar_propietario_contenido "$DIRLAMP/sites-available" "$USER:$USER"
        	else
            	log "No existe el directorio de configuración de sitios de apache." "error"
            	#rc=1
        	fi

        	if [[ -d "/home/sql/" ]]; then
            	mkdir -p "$DIRLAMP/sql"
            	do_rsync "$sudo_ok" "/home/sql" "$DIRLAMP/sql" "sql-files"
            	#sudo chown -vR "$USER":"$USER" "$DIRLAMP/sql/"* 2>&1 | tee -a "$logfile" || true
            	cambiar_propietario_contenido "$DIRLAMP/sql" "$USER:$USER"
        	else
            	log "No existe el directorio del usuario sql." "error"
            	#rc=1
        	fi

        	# ZendFramework puede venir con patrón; usar find para seleccionar
        	zend_src=$(find /var/lib -maxdepth 1 -type d -name 'ZendFramework*' | sort | head -n 1)
        	if [[ -n "$zend_src" ]]; then
            	mkdir -p "$DIRLAMP/ZendFramework"
            	do_rsync "$sudo_ok" "$zend_src" "$DIRLAMP/ZendFramework" "ZendFramework"
        	else
            	log "No existe el directorio de ZendFramework." "error"
            	#rc=1
        	fi

        	if [[ -d "/home/$USER/Documentos/DAW2/" ]]; then
            	mkdir -p "$DIRLAMP/DAW2"
            	do_rsync "$sudo_ok" "/home/$USER/Documentos/DAW2" "$DIRLAMP/DAW2" "DAW2"
        	else
            	log "No existe el directorio de DAW2." "error"
            	#rc=1
        	fi

        	if [[ -d "$dirorigen/" ]]; then
            	mkdir -p "$DIRLAMP/workspace"
            	do_rsync "no" "$dirorigen" "$DIRLAMP/workspace" "workspace"
        	else
            	log "No existe el directorio workspace." "error"
            	#rc=1
        	fi

        	# eliminar cache de forma segura (comprobar existencia)
        	cache_file="$DIRLAMP/workspace/$USER/data/cache/module-config-cache.application.config.cache.php"
        	if [[ -f "$cache_file" ]]; then
            	rm -f "$cache_file" 2>>"$logfile" || log "[WARN] No se pudo eliminar cache"
        	fi

        	log 'Revisar espacio en disco'
        	#df -TBG "$DIRECTORIO" | tee -a "$logfile"
        	mostrar_info_fs "$DIRECTORIO" "$logfile"
        	log 'Revisar espacio de backupLAMP'
        	#sudo du -s -BG "$DIRLAMP" 2>&1 | tee -a "$logfile"
        	mostrar_tamano_dir_log "$DIRLAMP" "$logfile"
    	else
        	log "Espacio insuficiente en ${DIRECTORIO}." "error"
        	#rc=1
    	fi
	else
    	log "Disco ${DIRECTORIO} no montado o directorios incompatibles." "error"
    	#rc=1
	fi

	log "##################################################FIN##################################################"
	date | tee -a "$logfile"
	end_time_LAMP=$(date +"%T")
	# start_seconds_LAMP=$(date -d "$start_time_LAMP" +%s)
	# end_seconds_LAMP=$(date -d "$end_time_LAMP" +%s)
	# datediff_LAMP=$((end_seconds_LAMP - start_seconds_LAMP))

	# elapsed_time_LAMP=$(date -d @"$datediff_LAMP" -u +%H:%M:%S)
	# elapsed_hours_LAMP=$((datediff_LAMP/3600))
	# elapsed_minutes_LAMP=$(((datediff_LAMP % 3600)/60))
	# elapsed_seconds_LAMP=$((datediff_LAMP % 60))
	# al final calcular duración con epoch:
	local end_ts=$(date +%s)
	local datediff_LAMP=$((end_ts - start_ts))
	elapsed_time_LAMP=$(date -u -d @"$datediff_LAMP" +%H:%M:%S)
	elapsed_hours_LAMP=$((datediff_LAMP/3600))
	elapsed_minutes_LAMP=$(((datediff_LAMP % 3600)/60))
	elapsed_seconds_LAMP=$((datediff_LAMP % 60))

	log "HORA INICIO: $start_time_LAMP"
	log "HORA FIN: $end_time_LAMP"
	log "ELAPSED TIME: $elapsed_time_LAMP"
	log ""
	log "EL PROCESO DEMORO ${elapsed_hours_LAMP} HRS CON ${elapsed_minutes_LAMP} MINS Y ${elapsed_seconds_LAMP} SEGS EN EJECUTARSE."

	# opcion2=0
	# opcion3=0
	reiniciar_variables
	log "Respaldo del sistema LAMP completado."
	#echo -e "${NC}"
	return $rc
}
# fin backup_LAMP
# ==============================
# RESTAURAR RESPALDO
# ==============================
# ini select_backup_dir
# select_backup_dir() {
# 	local root="$1"

# 	if [[ ! -d "$root" ]]; then
#     	log "No existe el directorio de backups: $root" "error"
#     	return 1
# 	fi

# 	mapfile -t backups < <(find "$root" -mindepth 2 -maxdepth 4 -type d | sort)
# 	if [[ ${#backups[@]} -eq 0 ]]; then
#     	log "No se encontraron backups en $root." "error"
#     	return 1
# 	fi

# 	echo "Backups disponibles:" >&2
# 	for i in "${!backups[@]}"; do
#     	printf '%3d) %s\n' "$((i+1))" "${backups[i]}" >&2
# 	done

# 	PS3="Seleccione backup [1-${#backups[@]}] o $(( ${#backups[@]} + 1 )) para cancelar: "
# 	exec 3>&1
# 	{ select selected_backup in "${backups[@]}" "Cancelar"; do
#     	if [[ $REPLY -ge 1 && $REPLY -le ${#backups[@]} ]]; then
#         	printf '%s\n' "$selected_backup" >&3
#         	exec 3>&-
#         	return 0
#     	fi
#     	if [[ $REPLY -eq $(( ${#backups[@]} + 1 )) ]]; then
#         	exec 3>&-
#         	return 1
#     	fi
#     	echo "Selección inválida." >&2
# 	done; } 1>&2
# }
select_backup_dir() {
	local root="$1"

	if [[ ! -d "$root" ]]; then
    	log "No existe el directorio de backups: $root" "error"
    	return 1
	fi

	#mapfile -t backups < <(find "$root" -mindepth 2 -maxdepth 4 -type d | sort)
    # Buscamos solo carpetas que contengan la estructura de respaldo real (nivel intermedio)
	mapfile -t backups < <(find "$root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)
	if [[ ${#backups[@]} -eq 0 ]]; then
    	log "No se encontraron backups en $root." "error"
    	return 1
	fi

	# 1. Pintamos el encabezado en cian
	pintar "Backups disponibles en el sistema:" "menu" > /dev/tty
	echo "" > /dev/tty

	# 2. TRUCO: Activamos el color cian para todo lo que imprima 'select' a continuación
	printf '%b' "$CIAN" > /dev/tty

	# 3. El prompt (PS3) primero RESTABLECE el color normal (\e[0m), luego se pinta en magenta,
	# y al final vuelve a dejar el color normal para lo que escriba el usuario.
	PS3="${NC}${MAGENTA_B}[PREGUNTA] Seleccione backup [1-${#backups[@]}] o $(( ${#backups[@]} + 1 )) para cancelar: ${NC}"
	
	exec 3>&1
	{ select selected_backup in "${backups[@]}" "Cancelar"; do
    	# RESTABLECEMOS el color del sistema inmediatamente al elegir para no romper los logs ni otras pantallas
    	printf '%b' "$NC" > /dev/tty

    	if [[ $REPLY -ge 1 && $REPLY -le ${#backups[@]} ]]; then
        	printf '%s\n' "$selected_backup" >&3
        	exec 3>&-
        	return 0
    	fi
    	if [[ $REPLY -eq $(( ${#backups[@]} + 1 )) ]]; then
        	exec 3>&-
        	return 1
    	fi

    	log "Selección inválida. Inténtelo de nuevo." "error"
    	# Si falla, volvemos a activar el cian para cuando 'select' vuelva a pintar la lista
    	printf '%b' "$CIAN" > /dev/tty
	done; } 1>&2
}
# fin select_backup_dir
# ==============================
# ini restaurar_respaldo
restaurar_respaldo() {
	local backup_root="$DIR_SCRIPT"
	local backup_src

	if ! backup_src=$(select_backup_dir "$backup_root"); then
    	log "No hay backups para restaurar en $backup_root." "error"
    	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
    	return 0
	fi

	local restore_dest
    if is_lamp_backup "$backup_src"; then
        restore_dest="$DIR_USUARIO/workspace/"
    else
	    read -rp "$(pintar "Destino de restauracion [por defecto: $DIR_ACTUAL]: " "prompt")" restore_dest
	    restore_dest=${restore_dest:-$DIR_ACTUAL}
	    restore_dest=$(expand_path "$restore_dest")
    fi
	# Normalize tilde expansion immediately (avoid realpath on unexpanded ~)
	restore_dest="${restore_dest/#\~/$HOME}"

	# Normalize backup_src now (it's chosen from select_backup_dir)
	backup_src=$(realpath "$backup_src")

	while true; do
    	# use default again if somehow empty
    	restore_dest=${restore_dest:-$DIR_ACTUAL}
    	# Expand any remaining env/relative parts using a temporary normalized path if possible
    	# But only call realpath after destination existence/creation checks to avoid errors
    	if [[ "$restore_dest" == "$backup_src" || "$restore_dest" == "$backup_src/"* ]]; then
        	log "El destino no puede ser igual al backup ni estar dentro del backup." "error"
        	read -rp "$(pintar "Introduce otro destino (o pulsa ENTER para cancelar): " "prompt")" restore_dest
        	# empty input -> cancel and return to menu
        	if [[ -z "$restore_dest" ]]; then
            	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
            	return 0
        	fi
        	restore_dest="${restore_dest/#\~/$HOME}"
        	restore_dest=$(expand_path "$restore_dest")
        	continue
    	fi

    	if is_lamp_backup "$backup_src"; then
        	# LAMP: destination must already exist
        	if [[ ! -d "$restore_dest" ]]; then
            	log "Para backups LAMP el destino debe existir previamente: $restore_dest" "error"
            	read -rp "$(pintar "Desea introducir otro destino? (S/n): " "prompt")" tryagain
            	tryagain=${tryagain:-S}
            	if [[ "$tryagain" =~ ^[sS]$ ]]; then
                	read -rp "$(pintar "Nuevo destino: " "prompt")" restore_dest
                	restore_dest="${restore_dest/#\~/$HOME}"
                	restore_dest=$(expand_path "$restore_dest")
                	continue
            	else
                	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
                	return 0
            	fi
        	fi
    	else
        	# Non-LAMP: allow creating destination
        	#if [[ ! -d "$restore_dest" ]]; then
        	if is_remote_url "$restore_dest"; then
            	# omitir comprobación -d para remotos (o comprobar con rclone ls si quieres)
            	existe_dst=0
        	else
            	if [ -d "$restore_dest" ]; then
                	existe_dst=0
            	else
                	existe_dst=1
            	fi
        	fi
        	if [[ "$existe_dst" == 1 ]]; then
            	read -rp "$(pintar "El destino '$restore_dest' no existe. ¿Crear? (s/N): " "prompt")" crear
            	crear=${crear:-n}
            	if [[ "$crear" =~ ^[sS]$ ]]; then
                	if ! mkdir -p "$restore_dest"; then
                    	log "Error creando destino: $restore_dest" "error"
                    	read -rp "$(pintar "Introduzca otro destino o pulse ENTER para cancelar: " "prompt")" restore_dest
                    	if [[ -z "$restore_dest" ]]; then
                        	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
                        	return 0
                    	fi
                    	restore_dest="${restore_dest/#\~/$HOME}"
                    	restore_dest=$(expand_path "$restore_dest")
                    	continue
                	fi
            	else
                	read -rp "$(pintar "Introduzca otro destino o pulse ENTER para cancelar: " "prompt")" restore_dest
                	if [[ -z "$restore_dest" ]]; then
                    	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
                    	return 0
                	fi
                	restore_dest="${restore_dest/#\~/$HOME}"
                	restore_dest=$(expand_path "$restore_dest")
                	continue
            	fi
        	fi
    	fi

    	# If we reach here, destination exists (either originally or we created it)
    	# Now safely canonicalize path
    	#restore_dest=$(realpath "$restore_dest")
    	restore_dest="${restore_dest/#\~/$HOME}"
    	# Si necesidad de forzar existencia para LAMP o crear para no-LAMP:
    	if is_lamp_backup "$backup_src"; then
        	if [[ ! -d "$restore_dest" ]]; then
            	log "Para backups LAMP el destino debe existir"; # volver a pedir o abortar
        	fi
    	else
        	#if [[ ! -d "$restore_dest" ]]; then
        	if is_remote_url "$restore_dest"; then
            	# omitir comprobación -d para remotos (o comprobar con rclone ls si quieres)
            	existe_dst=0
        	else
            	if [ -d "$restore_dest" ]; then
                	existe_dst=0
            	else
                	existe_dst=1
            	fi
        	fi
        	if [[ "$existe_dst" == 1 ]]; then
            	read -rp "El destino '$restore_dest' no existe. ¿Crear? (s/N): " crear
            	crear=${crear:-n}
            	[[ "$crear" =~ ^[sS]$ ]] && mkdir -p "$restore_dest"
        	fi
    	fi
    	# ahora canonicalizar (ya existe o fue creado)
    	restore_dest=$(realpath "$restore_dest")

    	# Final safety check: still not inside backup
    	if [[ "$restore_dest" == "$backup_src" || "$restore_dest" == "$backup_src/"* ]]; then
        	log "El destino no puede ser igual al backup ni estar dentro del backup." "error"
        	read -rp "$(pintar "Introduce otro destino: " "prompt")" restore_dest
        	restore_dest="${restore_dest/#\~/$HOME}"
        	restore_dest=$(expand_path "$restore_dest")
        	continue
    	fi

    	break
	done

	local fecha
	# fecha=$(date +%Y-%m-%d-%H-%M-%S)
	# local restore_log="$DIR_SCRIPT/RESTORE-${fecha}.log"
	#mkdir -p "$(dirname "$restore_log")"
	local diro=$(basename "$backup_src")
	local clean_dir="${diro%/}"
	local nom_origen="${clean_dir##*/}"
	local nom_or=${nom_origen:0:40}
	local dird=$(basename "$restore_dest")
	local clean_dird="${dird%/}"
	local nom_destino="${clean_dird##*/}"
	local nom_de=${nom_destino:0:40}

	# (Opcional) keep the previous behavior but call after validation
	set_logfile "RESTORE-$nom_pcu-$nom_or-$nom_de"

	local start_timestamp
	start_timestamp=$(date '+%F %T')
	log "INICIO: $start_timestamp"

	local fs_dest
	#fs_dest=$(df -T "$restore_dest" | awk 'NR==2 {print $2}')
	fs_dest=$(obtener_tipo_fs "$restore_dest")

	local rsync_opts=( -aHv --delete --numeric-ids --progress )
	if ! is_posix_fs "$fs_dest"; then
    	rsync_opts=( -aHv --delete --numeric-ids --progress --no-perms --no-owner --no-group --chmod=ugo=rwX )
	fi

	log "Restaurando desde: $backup_src"
	log "Destino: $restore_dest"

	if is_lamp_backup "$backup_src"; then
    	#restore_lamp "$backup_src" "$restore_dest" "$logfile"
    	#local rc=$?
        restore_lamp "$backup_src" "$restore_dest" "$logfile" || local resultado_restore=$?

	    # Ahora el script continuará vivo de forma garantizada aquí abajo
	    echo ""
	    read -n 1 -s -r -p "$(log "Pulse una tecla para volver al menú principal..." "prompt")"
	    echo ""
	    
	    return 0
	else
    	local diro=$(basename "$restore_dest")
    	local clean_dir="${diro%/}"
    	local nom_des="${clean_dir##*/}"
    	do_rsync "" "$backup_src/" "$restore_dest/" "RESTORE-${fecha}-${nom_des}" "$logfile" rsync_opts
    	local rc=$?
	fi

	local end_timestamp
	end_timestamp=$(date '+%F %T')

	local elapsed
	elapsed=$(( $(date -d "$end_timestamp" +%s) - $(date -d "$start_timestamp" +%s) ))
	local elapsed_formatted
	elapsed_formatted=$(date -u -d "@$elapsed" +%H:%M:%S)

	log "FIN: $end_timestamp"
	log "DURACION: $elapsed_formatted"
	log "HORA INICIO: $start_timestamp"
	log "HORA FIN: $end_timestamp"

	if [[ $rc -eq 0 ]]; then
    	log "Restauración completa." "exito"
	else
    	log "Restauración finalizada con errores (rc=$rc). Revisa $logfile" "error"
	fi
	# opcion2=0
	# opcion3=0
	reiniciar_variables
	read -p "$(pintar "Pulse una tecla para volver al menú..." "prompt")"
	return 0
}
# fin restaurar_respaldo
# ==============================
# ini restore_lamp
restore_lamp() {
	local backup_src="$1"
	local restore_dest="$2"
	local logfile="$3"
	local rc=0

	# Array para almacenar los componentes que fallen durante la restauración
	local errores_resumen=()

	log "Restauración especial LAMP desde $backup_src"

	if [[ ! -d "$backup_src" ]]; then
    	log "El backup LAMP no existe: $backup_src" "error"
    	return 1
	fi

	formato_origen=$(obtener_tipo_fs "$backup_src")
	if ! is_posix_fs "$formato_origen" ; then
    	log "El sistema de archivos de origen es ${formato_origen}, y no soporta los permisos de Linux." "error"
    	echo -n "$(pintar "¿Desea asumir el riesgo? (s/N): " "prompt")"
    	read -r arriesgo
    	arriesgo=${arriesgo:-N}
    	if [[ "$arriesgo" =~ ^[nN]$ ]]; then
        	return 1
    	fi
	fi

	local target_filezilla="$DIR_USUARIO/.config/filezilla/"
	local target_sites="/etc/apache2/sites-available/"
	local target_sql="/home/sql/"
	local target_zend="/var/lib/ZendFramework/"
	local target_daw="/home/$USER/Documentos/DAW2/"
	local target_workspace="$DIR_USUARIO/workspace/"

	# Comprobación de espacio disponible
	log "Comprobando espacio disponible en disco..."
	local tamano_backup_gb
	tamano_backup_gb=$(obtener_tamano_multiples_dir_gb "$backup_src")
	tamano_backup_gb=${tamano_backup_gb:-0}

	local espacio_libre_gb
	espacio_libre_gb=$(df -BG "$DIR_USUARIO" | awk 'NR==2 {print $4}' | tr -cd '0-9')
	espacio_libre_gb=${espacio_libre_gb:-0}

	log "Tamaño aproximado del backup: ${tamano_backup_gb} GB | Espacio libre: ${espacio_libre_gb} GB"

	if [ "$tamano_backup_gb" -gt "$espacio_libre_gb" ]; then
		log "FALTA ESPACIO: El backup necesita ${tamano_backup_gb} GB y solo tienes ${espacio_libre_gb} GB libres." "error"
		echo -n "$(pintar "¿Desea cancelar la operación? (S/n): " "prompt")"
		read -r cancelar_espacio
		cancelar_espacio=${cancelar_espacio:-S}
		if [[ "$cancelar_espacio" =~ ^[sS]$ ]]; then
			return 1
		fi
	fi

	# Asegurar directorios vivos
	mkdir -p "$target_filezilla" "$target_sql" "$target_daw" "$target_workspace"

	if [[ -z "$prueba_rsync" ]]; then
    	log "A continuación se preguntará si estás haciendo pruebas..." "alerta"
    	read -rp "$(pintar "¿Estás haciendo pruebas? [N/s]: " "prompt")" prueba_rsync
    	prueba_rsync=${prueba_rsync:-n}
	fi

	# =========================================================================
	# SUB-FUNCIÓN DE RESTAURACIÓN DE CARPETAS
	# =========================================================================
	restore_path() {
    	local src="$1"
    	local dst="$2"
    	local label="$3"

    	local comando_find="find \"$src\" -mindepth 1 2>/dev/null | head -n 1"
    	if [[ "$dst" == "$target_sites" || "$dst" == "$target_sql" || "$dst" == "$target_zend" ]]; then
        	comando_find="sudo find \"$src\" -mindepth 1 2>/dev/null | head -n 1"
    	fi

    	if [[ -d "$src" && -n "$(eval "$comando_find")" ]]; then
       	 
        	if [[ ! -d "$dst" ]]; then
            	log "El destino $dst no existía. Creándolo..." "alerta"
            	sudo mkdir -p "$dst"
            	sudo chown -R "${USER}:${USER}" "$dst"
        	fi

        	local sup=""
        	if [[ "$dst" == "$target_filezilla" || "$dst" == "$target_sites" || "$dst" == "$target_sql" || "$dst" == "$target_zend" ]]; then
            	sup="sudo"
        	fi

        	log "Restaurando $label desde $src a $dst"

        	local src_fijo="${src%/}/"
        	local dst_fijo="${dst%/}/"
        	
        	# REGENERACIÓN SEGURA DEL ARRAY: 
        	# Copiamos tus parámetros por defecto (-aHv --delete)
        	modarr=("${rsync_opts[@]}")
        	
        	# Si NO es una simulación, inyectamos la red de seguridad sin romper get_rsync_opts
        	if [[ "$prueba_rsync" =~ ^[nN]$ ]]; then
            	local marca_temporal=$(date +"%Y%m%d_%H%M%S")
            	local backup_dir_seguro="/tmp/rsync_backup_${label}_${marca_temporal}"
            	modarr+=( "--backup" "--backup-dir=$backup_dir_seguro" )
        	else
            	modarr+=( "--dry-run" )
        	fi

        	do_rsync "$sup" "$src_fijo" "$dst_fijo" "$label" "$logfile" "modarr"
        	rc=$?
    	else
        	log "No existe o está vacío el directorio de backup $label: $src" "error"
			errores_resumen+=( "Directorio de backup $label (No encontrado/Vacío)" )
        	rc=1
    	fi
	}

	# Ejecución de restauraciones estructurales
	restore_path "$backup_src/filezilla" "$target_filezilla" "FileZilla"
	restore_path "$backup_src/sites-available" "$target_sites" "Apache sites-available"
	restore_path "$backup_src/sql" "$target_sql" "SQL dumps"
	restore_path "$backup_src/DAW2" "$target_daw" "DAW2"
	restore_path "$backup_src/workspace" "$target_workspace" "Workspace"

	# =========================================================================
	# SECCIÓN ZENDFRAMEWORK
	# =========================================================================
	local zend_src
	zend_src=$(sudo find "$backup_src" -maxdepth 1 -type d -name 'ZendFramework*' 2>/dev/null | sort | head -n 1)
	if [[ -n "$zend_src" ]]; then
    	if [[ ! -d "$target_zend" ]]; then
        	sudo mkdir -p "$target_zend"
    	fi
   	 
    	log "Restaurando ZendFramework desde $zend_src a $target_zend"
    	
    	local backup_opts_zf=()
    	get_rsync_opts "$zend_src" "$target_zend" backup_opts_zf
    	if [[ "$prueba_rsync" =~ ^[nN]$ ]]; then
        	local marca_zf=$(date +"%Y%m%d_%H%M%S")
        	backup_opts_zf+=( "--backup" "--backup-dir=/tmp/rsync_backup_Zend_${marca_zf}" )
    	fi
    	
    	modarr=("${backup_opts_zf[@]}")
    	
    	local zend_src_fijo="${zend_src%/}/"
    	local target_zend_fijo="${target_zend%/}/"
    	
    	if ! do_rsync "sudo" "$zend_src_fijo" "$target_zend_fijo" "ZendFramework" "$logfile" "modarr"; then
			errores_resumen+=( "Entorno ZendFramework" )
			rc=1
		fi
	else
    	log "No existe backup de ZendFramework en $backup_src" "error"
		errores_resumen+=( "Librerías ZendFramework (No encontradas)" )
    	rc=1
	fi

	if [[ "$prueba_rsync" =~ ^[nN]$ ]]; then
    	log "Validando configuraciones de Apache..." "menu"
    	if sudo apache2ctl -t &>/dev/null; then
        	sudo systemctl restart apache2 2>/dev/null || true
        	log "¡Entorno Apache reiniciado con éxito!" "exito"
    	else
        	log "Advertencia: Se detectaron fallos de sintaxis en Apache." "alerta"
			errores_resumen+=( "Sintaxis de Apache rota (Revisar archivos sites-available)" )
    	fi
	fi

	# =========================================================================
	# SECCIÓN DE BASES DE DATOS MYSQL
	# =========================================================================
	if ! command -v mysql &> /dev/null; then
    	log "No es posible importar las bases de datos porque falta instalar mysql." "error"
		errores_resumen+=( "Servicio MySQL (Comando no instalado)" )
	else
    	if [[ -d "$backup_src/sql" && -n "$(sudo find "$backup_src/sql" -maxdepth 1 -name '*.sql' -print -quit 2>/dev/null)" ]]; then
        	log "Se han encontrado dumps SQL en $backup_src/sql"
        	
        	read -rp "$(pintar "¿Importar los dumps SQL a MySQL ahora? (s/N): " "prompt")" import_sql
        	import_sql=${import_sql:-n}
        	
        	if [[ "$import_sql" =~ ^[sS]$ ]]; then
            	read -rp "$(pintar "Usuario MySQL [root]: " "prompt")" MYSQL_USER
            	MYSQL_USER=${MYSQL_USER:-root}
            	read -s -rp "$(pintar "Contraseña MySQL: " "prompt")" MYSQL_PASS
            	MYSQL_PASS=${MYSQL_PASS:-admin}
            	echo
            	read -rp "$(pintar "Host MySQL [localhost]: " "prompt")" MYSQL_HOST
            	MYSQL_HOST=${MYSQL_HOST:-localhost}
            	export MYSQL_PWD="$MYSQL_PASS"

            	            	# Cargamos los archivos .sql usando sudo para saltar el bloqueo de lectura de sadmin
            	local archivos_sql=()
            	mapfile -t archivos_sql < <(sudo find "$backup_src/sql" -maxdepth 1 -name "*.sql" 2>/dev/null)

            	for sql in "${archivos_sql[@]}"; do
                	[[ -f "$sql" ]] || continue
                	local dbname
                	dbname=$(basename "$sql" .sql)
                	
                	log "Procesando base de datos: $dbname"
                	
                	if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then
                    	log "[SIMULACIÓN] mysql -h $MYSQL_HOST -u $MYSQL_USER -e 'CREATE DATABASE IF NOT EXISTS $dbname;'"
                	else
                    	log "Importando archivo $sql en la base de datos '$dbname'..." "menu"
                    	
                    	# Usamos sudo cat para leer el archivo .sql con permisos y meterselo a mysql
                    	if ! mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -e "CREATE DATABASE IF NOT EXISTS \`$dbname\`;" 2>>"$logfile"; then
                    		log "No se pudo verificar o crear la base de datos '$dbname'." "error"
							errores_resumen+=( "Base de datos MySQL: $dbname (Fallo al crear)" )
                    		rc=1
                    		continue
                    	fi
                    	
                    	if sudo cat "$sql" | mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "$dbname" 2>>"$logfile"; then
                    		log "Base de datos '$dbname' restaurada con éxito." "exito"
                    	else
                    		log "Error al importar el volcado de '$dbname'." "error"
							errores_resumen+=( "Datos MySQL de: $dbname (Error en inyección SQL)" )
                    		rc=1
                    	fi
                	fi
            	done
            	unset MYSQL_PWD
        	fi
		else
			log "No se encontraron archivos .sql para restaurar en $backup_src/sql" "alerta"
    	fi
	fi
    limpiar_respaldos_temporales
	# =========================================================================
	# 📊 RESUMEN FINAL VISUAL DE ERRORES EN PANTALLA
	# =========================================================================
	echo "" > /dev/tty
	log "==================================================" "menu" > /dev/tty
	log "📋 INFORME FINAL DE LA RESTAURACIÓN" "menu" > /dev/tty
	log "==================================================" "menu" > /dev/tty

	if [ ${#errores_resumen[@]} -eq 0 ]; then
		# Todo ha salido perfecto
		if [[ "$prueba_rsync" =~ ^[sS]$ ]]; then
			pintar "🧪 [SIMULACIÓN] La simulación terminó sin detectar anomalías estructurales." "exito" > /dev/tty
		else
	        pintar "🎉 [ÉXITO] Todo el sistema LAMP ha sido restaurado correctamente sin fallos." "exito" > /dev/tty
		fi
	else
		# Se capturaron problemas en el array interno
		pintar "⚠️ Se detectaron incidencias en los siguientes módulos:" "error" > /dev/tty
		echo "" > /dev/tty
		for elem in "${errores_resumen[@]}"; do
			pintar "   ❌ $elem" "error" > /dev/tty
		done
		echo "" > /dev/tty
		pintar "ℹ️ Consulta el archivo log para ver el detalle técnico de los comandos: $logfile" "alerta" > /dev/tty
	fi
	log "==================================================" "menu" > /dev/tty
	echo "" > /dev/tty

	return "$rc"
}
# fin restore_lamp
# ==============================
# ini limpiar_respaldos_temporales
limpiar_respaldos_temporales() {
    log "Limpiando archivos de resguardo temporales en /tmp..." "menu"
    
    # Borramos de forma segura (-rf) solo los directorios temporales creados por rsync
    # El uso de || true garantiza que si no hay nada que borrar, set -e no mate el script
    sudo rm -rf /tmp/rsync_backup_* 2>/dev/null || true
    
    log "¡Limpieza completada con éxito!" "exito"
}
# fin limpiar_respaldos_temporales
# ==============================

# ==============================
# BUCLE PRINCIPAL
# ==============================
# ini bucle principal
while [[ "$opcion" != "0" ]]
do
# Pintamos menú
menu #invocamos el menú

# case para selección de opción
	case $opcion in
    	1)
    	while [[ $opcion2 -ne 0 ]]
    	do
        	#invocamos el menú de selección de origen
        	menu_origen
        	case $opcion2 in
        	1)
            	log "Opción 1. Respaldo del directorio actual"
            	log "=============================="
            	#Revisar si el DIR_ACTUAL es un directorio válido
            	if [ -d "$DIR_ACTUAL" ]; then
                	dirorigen=$DIR_ACTUAL
                	bucle_respaldo
            	else
                	log "El directorio de origen no es válido." "error"
                	read -p "$(pintar "Pulse una tecla para volver..." "prompt")"
            	fi
            	break
            	;;
        	2)
            	log "Opción 2. Respaldo del directorio del script"
            	log "=============================="
            	#Revisar si el DIR_SCRIPT es un directorio válido
            	if [ -d "$DIR_SCRIPT" ]; then
                	dirorigen=$DIR_SCRIPT
                	bucle_respaldo
            	else
                	log "El directorio de origen no es válido." "error"
                	read -p "$(pintar "Pulse una tecla para volver..." "prompt")"
            	fi
            	break
            	;;
        	3)
            	log "Opción 3. Respaldo del directorio del usuario"
            	log "=============================="
            	#Revisar si el DIR_USUARIO es un directorio válido
            	if [ -d "$DIR_USUARIO" ]; then
                	dirorigen=$DIR_USUARIO
                	bucle_respaldo
            	else
                	log "El directorio de origen no es válido." "error"
                	read -p "$(pintar "Pulse una tecla para volver..." "prompt")"
            	fi
            	break
            	;;
        	4)
            	log "Opción 4. Respaldo del directorio indicado por el usuario"
            	log "=============================="
            	read -p "$(pintar "Ingrese la ruta del directorio de origen: " "prompt")" DIR_ESCRITO
            	DIR_ESCRITO=$(expand_path "$DIR_ESCRITO")
            	#Revisar si el DIR_ESCRITO es un directorio válido
            	if is_remote_url "$DIR_ESCRITO" || [ -d "$DIR_ESCRITO" ]; then
                	if is_remote_url "$DIR_ESCRITO"; then
                    	log "El directorio de origen es remoto: $DIR_ESCRITO"
                	fi
                	dirorigen=$DIR_ESCRITO
                	bucle_respaldo
            	else
                	log "El directorio de origen no es válido." "error"
                	read -p "$(pintar "Pulse una tecla para volver..." "prompt")"
            	fi
            	break
            	;;
        	5)
            	log "Opción 5. Respaldo del sistema LAMP (Directorio /workspace, Bases de datos MySQL, Configuración de Apache, Filezilla y ZendFramework)"
            	log "=============================="
            	dirorigen="/home/$USER/workspace/"
            	if [ -d "$dirorigen" ]; then
                	bucle_respaldo_LAMP
            	else
                	log "El directorio de origen no es válido." "error"
                	read -p "$(pintar "Pulse una tecla para volver..." "prompt")"
            	fi
            	break
            	;;
        	0)
            	log "Opción 0. Volver al menú principal"
            	break
            	;;
        	*)
            	log "Opción no válida"
            	;;
        	esac
        	done
    	;;

	# en el menu:
	2)
    	restaurar_respaldo
    	;;
	3)
		crear_claves_ssh_automatico
		read -rp "$(pintar "Presiona [ENTER] para volver al Menú..." "prompt")"
		;;
	4)
		configurar_google_drive_rclone
		read -rp "$(pintar "Presiona [ENTER] para volver al Menú..." "prompt")"
		;;
	0)
    	log "Bie cha!!" #salimos del case+menú
    	#sleep 3
    	#read -p "Pulse una tecla para salir..."
    	;;
	*)
    	log "Opción '$opcion' no válida..." "error"
    	;;
esac
done
# fin bucle principal
# ==============================

# CALCULO DE TIEMPOS
end_time_LAMP=$(date +"%T")
end_ts=$(date +%s)
datediff_total=$((end_ts - start_ts))
elapsed_time_total=$(date -u -d @"$datediff_total" +%H:%M:%S)
elapsed_hours_total=$((datediff_total/3600))
elapsed_minutes_total=$(((datediff_total % 3600)/60))
elapsed_seconds_total=$((datediff_total % 60))

log "HORA INICIO: $start_time_total"
log "HORA FIN: $end_time_total"
log "TIEMPO TRANSCURRIDO: $elapsed_time_total"
log ""
log "EL PROCESO DEMORO ${elapsed_hours_total} HRS CON ${elapsed_minutes_total} MINS Y ${elapsed_seconds_total} SEGS EN EJECUTARSE."


