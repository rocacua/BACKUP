#!/bin/bash
#start_time_total=`date +"%T"`
SEGUNDOS_INICIO=`date +"%s"`
HORA_INICIO_HUMANA=$(date +%H:%M:%S)
# ==========================================
# 📋 CONFIGURACIÓN DEL LOG AUTOMÁTICO
# ==========================================
# Definimos dónde se guardará el reporte (en el home del usuario ejecutor)
declare -r DIR_SCRIPT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
fecha=$(date +%Y-%m-%d_%H-%M-%S)

# 1. Definir la ruta de la CARPETA de logs y el ARCHIVO de log correctamente
LOG_DIR="$DIR_SCRIPT/logs"
LOG_FILE="$LOG_DIR/instalacion_lamp-${fecha}.log"

# 2. Intentar crear la carpeta de logs si no existe
if [[ ! -d "$LOG_DIR" ]]; then
    # El comando mkdir heredará los permisos de sudo si se ejecuta con él
    mkdir -p "$LOG_DIR" 2>/dev/null
fi

# 3. COMPROBACIÓN CRÍTICA: ¿El script puede escribir en esa carpeta?
if [[ ! -w "$LOG_DIR" ]]; then
    echo "⚠️ Advertencia: No hay permisos de escritura en $LOG_DIR"
    echo "📂 El historial se guardará temporalmente en tu carpeta personal (/home/${USER})."
    
    # Redirección de emergencia a una ruta donde el usuario SIEMPRE tiene permisos
    LOG_DIR="/home/${USER}"
    LOG_FILE="$LOG_DIR/instalacion_lamp-${fecha}.log"
    
    # Intentar asegurar que exista (por si acaso)
    mkdir -p "$LOG_DIR" 2>/dev/null
fi


# 4. Magia de Bash: Duplica la salida de pantalla y la envía al archivo en tiempo real
# 🟢 PASO 1: Guardar la salida (1) y el error (2) originales de la terminal en los canales 3 y 4
exec 3>&1 4>&2
# Activar el log global a través de tee
exec > >(tee -i "$LOG_FILE") 2>&1


echo "📝 Grabando registro en: $LOG_FILE"

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

# ini pintar
pintar() {
	local texto="$1"
	local tipo="${2:-normal}"
	local salto="${3:-1}"
	local color=""
	local etiqueta=""

	# 1. Seleccionar color y etiqueta según el tipo
	case "$tipo" in
    	"error")    color="$ROJO";      etiqueta="[ERROR] " ;;
    	"exito")    color="$VERDE";     etiqueta="[OK] " ;;
    	"alerta")   color="$AMARILLO";  etiqueta="[ALERTA] " ;;
    	"menu")	    color="$CIAN_B";    etiqueta="[MENU] " ;;
    	"prompt")   color="$MAGENTA_B"; etiqueta="[PREGUNTA] " ;;
    	*)          color="$NC";        etiqueta="" ;;
	esac

	# 2. Guardar silenciosamente en el log con su marca de tiempo
	#local marca_tiempo="[$(date --iso-8601=seconds)]"
	#echo "$marca_tiempo ${etiqueta}${texto}" >> "$logfile"

	# 3. Enviar el texto con color a la pantalla
    if [[ $salto -eq 0 ]]; then
        # Usamos printf en vez de echo para que funcione correctamente dentro de $(...)
        printf '%b' "${color}${etiqueta}${texto}${NC}"
    else
        if [ "$tipo" = "error" ]; then
            echo -e "${color}${etiqueta}${texto}${NC}" >&2  # Envia al canal de errores
        else
            echo -e "${color}${etiqueta}${texto}${NC}"  	# Envia al canal normal
        fi
    fi
}
# fin pintar


# Magia de Bash: Duplica la salida de pantalla y la envía al archivo en tiempo real
exec > >(tee -i "$LOG_FILE") 2>&1

pintar "##################################################INI##################################################"
pintar "Instalación de un entorno LAMP: $HORA_INICIO_HUMANA"
pintar "##################################################INI##################################################"

pintar "Actualizar sistema" "menu"
sudo apt update && sudo apt upgrade -y

pintar "instalar Filezilla" "menu"
sudo apt-get install filezilla -y

pintar "Instalar mysql" "menu"
sudo apt-get install mysql-server mysql-client -y

pintar "Instalar apache" "menu"
sudo apt-get install apache2 -y
# Desactivar el host por defecto para crear los nuestros 
#sudo a2dissite 000-default.conf > /dev/null
#sudo systemctl restart apache2
# 1. Añadir el usuario de Apache (www-data) a tu grupo principal para que comparta permisos de lectura
sudo usermod -aG "${USER}" www-data
# 2. Otorgar permisos de ejecución estrictos a las carpetas contenedoras
sudo chmod 750 "/home/${USER}"
sudo chmod 755 "/home/${USER}/workspace"
sudo chmod -R 755 "/home/${USER}/workspace/prueba"
# 3. Forzar a que tu usuario siga siendo el dueño absoluto de los archivos
sudo chown -R "${USER}:${USER}" "/home/${USER}/workspace"


# pintar "Instalar php8.5 con ondrej" "menu"
# sudo apt update && sudo apt upgrade -y
# sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https
# sudo add-apt-repository ppa:ondrej/php -y
# sudo apt install -y php8.5 php8.5-cli php8.5-common php8.5-fpm php8.5-mysql php8.5-zip php8.5-gd php8.5-mbstring php8.5-curl php8.5-xml php8.5-bcmath
# pintar "Instalar php8.3 con ondrej" "menu"
# sudo add-apt-repository ppa:ondrej/php
# sudo apt update
# sudo apt install php8.3 php8.3-cli php8.3-{bz2,curl,mbstring,intl}
# sudo apt install php8.3-fpm
# sudo a2enconf php8.3-fpm
# sudo systemctl restart apache2
# php -v

pintar "Instalar umtima versión PHP del repositorio linux (>=php8.3)" "menu"
sudo apt install -y php php-cli php-common php-fpm php-mysql php-zip php-gd php-mbstring php-curl php-xml php-bcmath
sudo systemctl restart apache2
sudo systemctl restart apache2
php -v

pintar "Gestión de imágenes con PHP" "menu"
sudo apt-get install imagemagick php-imagick -y

pintar "Activar RewriteEngine" "menu"
sudo a2enmod rewrite
systemctl restart apache2

pintar "Instalar PHPMyAdmin" "menu"
pintar "Atención, se le preguntará por el servidor, escoja configura el servidor apache2 (no lighttpd) y luego configurar la base de datos con la contraseña que desees y si deseas reinstalar la base de datos para phpmyadmin." "alerta"
pintar "⏳ Pausando el guardado del log para abrir el configurador visual..." "alerta"
# 🟡 PASO 2: Restaurar de forma momentánea los canales 1 y 2 directos a la pantalla
exec 1>&3 2>&4
# Instalar y configurar phpmyadmin con sus menús interactivos
sudo apt-get install phpmyadmin 
sudo systemctl restart apache2
sudo dpkg-reconfigure phpmyadmin
# 🔵 PASO 3: Reactivar el log de Bash para que todo lo que siga se guarde de nuevo en el archivo
exec > >(tee -i -a "$LOG_FILE") 2>&1

pintar "✅ phpMyAdmin instalado. Reanudando grabación del log en: $LOG_FILE" "exito"


pintar "#######################################################################################################"


DB_USER="admin"
DB_PASS="admin"

#Crear usuarios y bases de datos
pintar "Crear usuarios y bases de datos" "menu"
echo -ne "$(pintar "¿Desea crear un nuevo usuario de MySQL? [S|n]: " "prompt" 0)"
read -s new_user_mysql
if [[ "$_want_sudo" =~ ^[nN]$ ]]; then
    # Extraer el usuario y la contraseña actual escrita en el archivo php
    PMA_USER=$(sudo grep "\$dbuser=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")
    PMA_FILE_PASS=$(sudo grep "\$dbpass=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")
    DB_USER="$PMA_USER"
    DB_PASS="$PMA_FILE_PASS"
    pintar "No ha creado nuevo usuario." "alerta"
    #pintar "Recuerde, las claves para acceder a PhpMyAdmin: DB_USER:DB_PASS" "alerta"
else
# Variables de configuración
echo -ne "$(pintar "Nombre del nuevo usuario de MySQL [admin]: " "prompt" 0)"
read -s DB_USER
DB_USER=${DB_USER:-"admin"}
echo -ne "$(pintar "Contraseña del nuevo usuario de MySQL [admin]: " "prompt" 0)"
read -s DB_PASS
DB_PASS=${DB_PASS:-"admin"}

pintar "Configurando usuario y permisos en MySQL..." "menu"

# El comando se ejecuta como sudo para usar la autenticación por socket
sudo mysql <<EOF
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

pintar "¡Usuario MySQL ${DB_USER} creado correctamente!" "exito"

pintar "Comprobar el usuario y passwords de phpmyadmin" "menu"
# sudo nano /etc/phpmyadmin/config-db.php

# --- CONFIGURACIÓN PREVIA ---
# La contraseña definida anteriormente para el usuario 'admin'
ADMIN_PASS="$DB_PASS" 

CONFIG_FILE="/etc/phpmyadmin/config-db.php"

if [ ! -f "$CONFIG_FILE" ]; then
    pintar "⚠️ Error: No se encontró el archivo de phpMyAdmin." "error"
    exit 1
fi

# Extraer el usuario y la contraseña actual escrita en el archivo php
PMA_USER=$(sudo grep "\$dbuser=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")
PMA_FILE_PASS=$(sudo grep "\$dbpass=" "$CONFIG_FILE" | sed -E "s/.*='(.*)';/\1/")

pintar "🔍 Analizando usuario de phpMyAdmin: $PMA_USER..." "menu"

# Comprobar si el usuario ya está dado de alta en MySQL
USER_EXISTS=$(sudo mysql -N -B -e "SELECT COUNT(*) FROM mysql.user WHERE user='${PMA_USER}' AND host='localhost';")

if [ "$USER_EXISTS" -eq 0 ]; then
    pintar "➕ El usuario '$PMA_USER' no existe en MySQL." "alerta"
    pintar "⚙️ Creándolo en MySQL usando la contraseña por defecto del archivo config-db.php..." "menu"
    
    sudo mysql <<EOF
CREATE USER '${PMA_USER}'@'localhost' IDENTIFIED BY '${PMA_FILE_PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${PMA_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    pintar "✅ Usuario creado en MySQL con éxito." "exito"

else
    pintar "🔄 El usuario '$PMA_USER' ya existe en MySQL." "alerta"
    
    # Si la contraseña del archivo php es distinta a la que tú definiste, actualizamos el archivo php
    if [ "$PMA_FILE_PASS" != "$ADMIN_PASS" ]; then
        pintar "📝 Sincronizando el archivo config-db.php con tu contraseña de administrador..." "menu"
        
        # Reemplaza la línea de la contraseña en el archivo usando 'sed'
        sudo sed -i "s/\$dbpass='.*';/\$dbpass='${ADMIN_PASS}';/g" "$CONFIG_FILE"
        
        pintar "✅ Archivo config-db.php actualizado con tu contraseña." "exito"
    else
        pintar "✅ El archivo config-db.php ya está sincronizado con tu contraseña." "exito"
    fi
fi

pintar "🚀 Configuración de phpMyAdmin finalizada con éxito." "exito"

fi # fin if [[ "$_want_sudo" =~ ^[nN]$ ]]; then

DB_NAME="prueba_db"  # Nombre de la base de datos que vamos a crear

pintar "⚙️ Iniciando creación de base de datos y entorno de pruebas..." "menu"

# 1. Crear la Base de Datos e insertar el registro de "Hola Mundo"
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;

USE \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS mensajes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    texto VARCHAR(255) NOT NULL
);
INSERT INTO mensajes (texto) SELECT '¡Hola Mundo desde la base de datos!' 
WHERE NOT EXISTS (SELECT 1 FROM mensajes WHERE texto = '¡Hola Mundo desde la base de datos!');
EOF

pintar "✅ Base de datos '${DB_NAME}' y tabla de pruebas preparadas." "exito"


pintar "#######################################################################################################"


pintar "Creando worckspace" "menu"
# 2. Crear el directorio del espacio de trabajo
DIR_PATH="/home/${USER}/workspace/prueba"
DIR_PRUEBA="/home/${USER}/workspace/prueba"
#echo "Solo creamos $DIR_PATH si no existe"
if [ -d "$DIR_PATH" ]; then
    pintar "Ya existe $DIR_PATH, no lo creamos." "alerta"
else
mkdir -p "$DIR_PATH"
pintar "📁 Directorio creado en: $DIR_PATH" "menu"

# 3. Generar el archivo index.php con la estructura HTML y conexión PDO
cat << 'EOF' > "$DIR_PATH/index.php"
<?define_db_vars?>
EOF

# Inyectar las variables reales de Bash dentro del archivo index.php usando sed
# (Se hace de esta forma para evitar conflictos con la sintaxis nativa de PHP de las variables)
sed -i "s/<?define_db_vars?>/<?php\n\$host = 'localhost';\n\$db = '${DB_NAME}';\n\$user = '${DB_USER}';\n\$pass = '${DB_PASS}';\n?>/" "$DIR_PATH/index.php"

# Añadir el resto del código HTML y PHP al archivo de forma limpia
cat << EOF > "$DIR_PRUEBA/index.php"
<?php
\$host = 'localhost';
\$db = '${DB_NAME}';
\$user = '${DB_USER}';
\$pass = '${DB_PASS}';

try {
    \$dsn = "mysql:host=\$host;dbname=\$db;charset=utf8mb4";
    \$options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];
    \$pdo = new PDO(\$dsn, \$user, \$pass, \$options);

    // Consultar el mensaje en la base de datos
    \$stmt = \$pdo->query('SELECT texto FROM mensajes LIMIT 1');
    \$fila = \$stmt->fetch();
    \$mensaje = \$fila ? \$fila['texto'] : 'No se encontraron mensajes.';
} catch (\PDOException \$e) {
    \$mensaje = "Error de conexión: " . \$e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entorno de Desarrollo - Prueba</title>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f4f4f9; margin: 0; }
        .card { background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); text-align: center; }
        h1 { color: #333; }
        p { color: #666; font-size: 1.2rem; font-weight: bold; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Resultado del Test</h1>
        <p><?php echo htmlspecialchars(\$mensaje); ?></p>
    </div>
</body>
</html>
EOF


# Ajustar permisos para que tu usuario común sea el dueño del archivo y no root
chown -R "${USER}:${USER}" "/home/${USER}/workspace"

pintar "✅ Archivo index.php generado correctamente con conexión PDO." "exito"

# ==========================================
# 2. CREACIÓN DE LOS VIRTUALHOSTS EN APACHE
# ==========================================
pintar "📝 Creando configuraciones VirtualHost en Apache..." "menu"

# Vhost para prueba.test (PHP)
sudo tee /etc/apache2/sites-available/prueba.test.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName prueba.test
    DocumentRoot $DIR_PRUEBA
    
    <Directory $DIR_PRUEBA>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/prueba_error.log
    CustomLog \${APACHE_LOG_DIR}/prueba_access.log combined
</VirtualHost>
EOF

# ==========================================
# 3. ACTIVAR SITIOS Y MÓDULOS DE APACHE
# ==========================================
pintar "🔄 Activando sitios web y módulo rewrite..." "menu"
sudo a2ensite prueba.test.conf > /dev/null
sudo a2enmod rewrite > /dev/null

# ==========================================
# 4. CONFIGURACIÓN DEL ARCHIVO /ETC/HOSTS
# ==========================================
pintar "🌐 Agregando dominios locales a /etc/hosts..." "menu"

# Se usa grep de control para asegurar que no duplique las líneas si reejecutas el script
if ! grep -q "prueba.test" /etc/hosts; then
    echo "127.0.1.1       prueba.test" | sudo tee -a /etc/hosts > /dev/null
fi

# ==========================================
# 5. REINICIAR EL SERVICIO DE APACHE
# ==========================================
pintar "🚀 Reiniciando servidor web Apache..." "menu"
sudo systemctl restart apache2

pintar "🎉 ¡Todo listo! Ya puedes abrir tu navegador e ingresar a:" "exito"
pintar "👉 http://prueba.test"

fi #fin if [ ! -d "$DIR_PATH" ]; then


pintar "#######################################################################################################"


pintar "Creando DAW2" "menu"

# Variables de entorno para las rutas
DIR_DAW2="/home/${USER}/Documentos/DAW2"
DIR_PRUEBA="/home/${USER}/workspace/prueba"
if [ -d "$DIR_DAW2" ]; then
    pintar "Ya existe $DIR_DAW2, no lo creamos." "alerta"
else
mkdir -p "$DIR_DAW2"

pintar "⚙️ Iniciando configuración del segundo sitio..." "menu"

# ==========================================
# 1. CREACIÓN DEL SITIO HTML + JAVASCRIPT (DAW2)
# ==========================================
mkdir -p "$DIR_DAW2"

cat << 'EOF' > "$DIR_DAW2/index.html"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Entorno de Desarrollo - DAW2</title>
    <style>
        body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #eef2f3; margin: 0; }
        .box { background: white; padding: 2.5rem; border-radius: 10px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); text-align: center; }
        button { background-color: #007bff; color: white; border: none; padding: 10px 20px; font-size: 1rem; border-radius: 5px; cursor: pointer; transition: 0.2s; }
        button:hover { background-color: #0056b3; }
    </style>
</head>
<body>
    <div class="box">
        <h1>Proyecto DAW2</h1>
        <p>Haz clic en el botón inferior para lanzar el popup de prueba.</p>
        <button id="btnPopup">Lanzar Alerta</button>
    </div>

    <script>
        // Ejecutar el popup inmediatamente al cargar la página
        window.addEventListener('DOMContentLoaded', () => {
            alert('¡Hola mundo desde JavaScript!');
        });

        // Vincular también al botón por comodidad
        document.getElementById('btnPopup').addEventListener('click', () => {
            alert('¡Hola mundo desde JavaScript!');
        });
    </script>
</body>
</html>
EOF

# Ajustar permisos de la carpeta DAW2 para tu usuario
chown -R "${USER}:${USER}" "/home/${USER}/Documentos"
pintar "✅ Archivo index.html creado en DAW2." "exito"


# ==========================================
# 2. CREACIÓN DE LOS VIRTUALHOSTS EN APACHE
# ==========================================
pintar "📝 Creando configuraciones VirtualHost en Apache..." "menu"

# Vhost para daw2.test (HTML)
sudo tee /etc/apache2/sites-available/daw2.test.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName daw2.test
    DocumentRoot $DIR_DAW2
    
    <Directory $DIR_DAW2>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/daw2_error.log
    CustomLog \${APACHE_LOG_DIR}/daw2_access.log combined
</VirtualHost>
EOF


# ==========================================
# 3. ACTIVAR SITIOS Y MÓDULOS DE APACHE
# ==========================================
pintar "🔄 Activando sitios web y módulo rewrite..." "menu"
sudo a2ensite daw2.test.conf > /dev/null
sudo a2enmod rewrite > /dev/null


# ==========================================
# 4. CONFIGURACIÓN DEL ARCHIVO /ETC/HOSTS
# ==========================================
pintar "🌐 Agregando dominios locales a /etc/hosts..." "menu"

# Se usa grep de control para asegurar que no duplique las líneas si reejecutas el script
if ! grep -q "daw2.test" /etc/hosts; then
    echo "127.0.1.1       daw2.test" | sudo tee -a /etc/hosts > /dev/null
fi


# ==========================================
# 5. REINICIAR EL SERVICIO DE APACHE
# ==========================================
pintar "🚀 Reiniciando servidor web Apache..." "menu"
sudo systemctl restart apache2

pintar "🎉 ¡Todo listo! Ya puedes abrir tu navegador e ingresar a:" "exito"
pintar "👉 http://daw2.test"

fi # fin if [ ! -d "$DIR_DAW2" ]; then


pintar "#######################################################################################################"


# Variables de entorno
ZF_DIR="/var/lib/ZendFramework"
ZF_VERSION="1.12.20"
DIR_ZEND_PROJECT="/home/${USER}/workspace/zend_proyecto"
if [ -d "$ZF_DIR" ]; then
    pintar "Ya existe $ZF_DIR, no lo creamos." "alerta"
else
pintar "⚙️ Iniciando la instalación automatizada de Zend Framework 1..." "menu"

# ==========================================
# REPARACIÓN DE ZEND FRAMEWORK MEDIANTE CONTENEDOR AISLADO PHP 7.4
# ==========================================
# ==========================================
# REPARACIÓN ABSOLUTA Y CONFIGURACIÓN LAMP
# ==========================================
pintar "⚙️ Iniciando saneamiento completo del entorno..." "menu"

# 1. Asegurar Docker y esperar estabilización
if ! command -v docker &> /dev/null; then
    pintar "⏳ Instalando Docker en el sistema..."
    sudo apt update && sudo apt install -y docker.io
    sudo systemctl enable docker --now
    sudo usermod -aG docker "${USER}"
    sleep 5
fi

# 🔥 LIMPIEZA CRÍTICA: Desactivar y borrar TODOS los vhosts viejos que tumban Apache
pintar "🧽 Purgando archivos de configuración obsoletos de Apache..." "menu"
sudo a2dissite zend.proxy.conf zend.test.conf zend.local.conf prueba.local.conf daw2.local.conf &>/dev/null
sudo rm -f /etc/apache2/sites-available/zend.proxy.conf
sudo rm -f /etc/apache2/sites-available/zend.test.conf
sudo rm -f /etc/apache2/sites-available/zend.local.conf
sudo rm -f /etc/apache2/sites-available/prueba.local.conf
sudo rm -f /etc/apache2/sites-available/daw2.local.conf

# Borrar residuos físicos
sudo rm -rf "$ZF_DIR"
sudo rm -rf "$DIR_ZEND_PROJECT"
sudo rm -f /usr/local/bin/zf

# 2. Descarga de Zend utilizando la variable correcta (ZF_VERSION)
pintar "📥 Descargando biblioteca Zend..." "menu"
sudo mkdir -p "$ZF_DIR"

# 🔍 CORRECCIÓN AQUÍ: Se utiliza $ZF_VERSION explícitamente en la URL
#sudo curl -4 -L "https://github.com/zendframework/zf1/releases/download/release-1.12.20/ZendFramework-1.12.20-minimal.tar.gz" -o /tmp/zf1.tar.gz
sudo curl -4 -L "https://github.com/zendframework/zf1/releases/download/release-${ZF_VERSION}/ZendFramework-${ZF_VERSION}-minimal.tar.gz" -o /tmp/zf1.tar.gz

if [ ! -s /tmp/zf1.tar.gz ]; then
    pintar "No se pudo descargar el framework. Saltando sección Zend para proteger Apache." "error"
else
    pintar "📦 Extrayendo archivos en $ZF_DIR..." "menu"
    sudo tar -xzf /tmp/zf1.tar.gz -C "$ZF_DIR" --strip-components=1
    sudo rm -f /tmp/zf1.tar.gz
    
    sudo chmod +x "$ZF_DIR/bin/zf.sh"
    sudo ln -sf "$ZF_DIR/bin/zf.sh" /usr/local/bin/zf

    # 1. Creación temporal del proyecto base estructurado
    pintar "🛠️ Generando estructura del proyecto Zend..." "menu"
    mkdir -p "/home/${USER}/workspace"
    
    sudo docker run --rm \
      -v "/home/${USER}/workspace:/apps" \
      -v "$ZF_DIR:/zf" \
      php:7.4-cli bash -c "[ -f /zf/bin/zf.sh ] && /zf/bin/zf.sh create project /apps/zend_proyecto"
      
    # 2. Configuración e inicio del servidor permanente de Zend
    if [ -d "$DIR_ZEND_PROJECT" ]; then
        # 1. Purgar de forma estricta los contenedores viejos para liberar el puerto 8080
        sudo docker stop zend_app zapp_contenedor &>/dev/null
        sudo docker rm zend_app zapp_contenedor &>/dev/null
        sudo rm -f "$DIR_ZEND_PROJECT/.htaccess"

        # 2. Copiar físicamente la librería de Zend dentro del proyecto para evitar symlinks rotos
        sudo rm -rf "$DIR_ZEND_PROJECT/library/Zend"
        sudo mkdir -p "$DIR_ZEND_PROJECT/library"
        sudo cp -R "$ZF_DIR/library/Zend" "$DIR_ZEND_PROJECT/library/"

        # 3. Otorgar permisos totales en tu máquina física para evitar restricciones de lectura
        sudo chmod -R 777 "$DIR_ZEND_PROJECT"
        sudo chown -R "${USER}:${USER}" "$DIR_ZEND_PROJECT"

        # 📄 4. Generar el archivo de configuración de Apache nativo optimizado al vuelo
        sudo tee /tmp/zend_docker_vhost.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/public
    <Directory /var/www/html/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

        pintar "🚀 Levantando contenedor Docker definitivo de Zend con módulo rewrite activo..." "menu"

        # 🐋 5. ARRANQUE BLINDADO CON REWRITE ACTIVO:
        # Ejecutamos un comando en Docker que activa el módulo rewrite internos mediante un enlace 
        # simbólico directo de configuración antes de llamar al arranque oficial 'apache2-foreground'.
        # Esto evita condiciones de carrera y soluciona el error 500 de golpe.
        sudo docker run -d \
          --name zend_app \
          -p 127.0.0.1:8080:80 \
          -v "$DIR_ZEND_PROJECT:/var/www/html" \
          -v "/tmp/zend_docker_vhost.conf:/etc/apache2/sites-available/000-default.conf:ro" \
          php:7.4-apache bash -c "ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load &>/dev/null && apache2-foreground"

        # Borrar el residuo temporal del Host
        sudo rm -f /tmp/zend_docker_vhost.conf

        # 6. Escribir el Proxy inverso limpio para zend.test en el Apache nativo del sistema
        sudo tee /etc/apache2/sites-available/zend.proxy.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName zend.test
    ProxyPreserveHost On
    ProxyPass / http://127.0.0
    ProxyPassReverse / http://127.0.0
</VirtualHost>
EOF
        sudo a2ensite zend.proxy.conf > /dev/null
    fi

fi

# ==========================================
# 6. ASIGNACIÓN ESTRICTA DE IPS E INYECCIÓN DE VHOSTS
# ==========================================
pintar "📝 Reconfigurando arquitectura de red interna aislada..." "menu"

# Purgar configuraciones obsoletas que puedan chocar en memoria
sudo a2dissite 000-default.conf zend.test.conf zend.proxy.conf prueba.test.conf daw2.test.conf &>/dev/null

# 🅰️ VirtualHost para prueba.test en su IP dedicada (127.0.0.10)
sudo tee /etc/apache2/sites-available/prueba.test.conf > /dev/null <<EOF
<VirtualHost 127.0.0.10:80>
    ServerName prueba.test
    DocumentRoot /home/${USER}/workspace/prueba
    <Directory /home/${USER}/workspace/prueba>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# 🅱️ VirtualHost para daw2.test en su IP dedicada (127.0.0.20)
sudo tee /etc/apache2/sites-available/daw2.test.conf > /dev/null <<EOF
<VirtualHost 127.0.0.20:80>
    ServerName daw2.test
    DocumentRoot /home/${USER}/Documentos/DAW2
    <Directory /home/${USER}/Documentos/DAW2>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# 🆃 VirtualHost Proxy para zend.test en su IP dedicada (127.0.0.30)
sudo tee /etc/apache2/sites-available/zend.proxy.conf > /dev/null <<EOF
<VirtualHost 127.0.0.30:80>
    ServerName zend.test
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8080/
    ProxyPassReverse / http://127.0.0.1:8080/
</VirtualHost>
EOF

# ==========================================
# 7. SANEAMIENTO INTEGRAL DEL ARCHIVO /ETC/HOSTS
# ==========================================
pintar "🌐 Mapeando direccionamiento IP unificado en /etc/hosts..." "menu"

# Limpiamos cualquier rastro viejo de estos tres dominios para evitar duplicidades
sudo sed -i '/prueba.test/d' /etc/hosts
sudo sed -i '/daw2.test/d' /etc/hosts
sudo sed -i '/zend.test/d' /etc/hosts

# Inyectamos el nuevo mapa de red limpio e independiente
echo "127.0.0.10      prueba.test" | sudo tee -a /etc/hosts > /dev/null
echo "127.0.0.20      daw2.test"   | sudo tee -a /etc/hosts > /dev/null
echo "127.0.0.30      zend.test"   | sudo tee -a /etc/hosts > /dev/null

# ==========================================
# 8. ACTIVACIÓN Y REINICIO INTEGRAL
# ==========================================
# Forzar carga de módulos proxy
sudo a2enmod proxy proxy_http > /dev/null

# Activar los nuevos archivos virtuales y enterrar el default
sudo a2ensite prueba.test.conf daw2.test.conf zend.proxy.conf > /dev/null
sudo a2dissite 000-default.conf &>/dev/null

# Asegurar los accesos físicos del sistema de archivos al Home
sudo chmod 755 "/home/${USER}"
sudo chmod 755 "/home/${USER}/workspace"
sudo chmod 755 "/home/${USER}/Documentos"

pintar "🔄 Aplicando cambios y reiniciando servidores..." "menu"
sudo systemctl restart apache2
pintar "🎉 ¡Instalador LAMP finalizado con éxito!" "ok"


# # ==========================================
# # 0. INSTALACIÓN DE PHP 7.4-FPM COMPARTIDO
# # ==========================================
# pintar "⚙️ Preparando entorno multi-versión para Zend..." "menu"

# # Aseguramos que el PPA esté activo para poder descargar PHP 7.4
# sudo add-apt-repository ppa:ondrej/php -y && sudo apt update

# pintar "⏳ Instalando PHP 7.4-FPM exclusivo para el entorno heredado..." "menu"

# # Instalamos la versión 7.4 aislada con sus extensiones esenciales
# sudo apt install -y php7.4-fpm php7.4-cli php7.4-common php7.4-mysql php7.4-xml php7.4-mbstring

# # Aseguramos que el módulo de Apache para comunicarse con FPM esté encendido
# sudo a2enmod proxy_fcgi setenvif > /dev/null
# sudo systemctl enable php7.4-fpm --now


# # ==========================================
# # 1. DESCARGA E INSTALACIÓN DE LA LIBRERÍA
# # ==========================================
# # Forzar la eliminación de archivos corruptos o enlaces rotos anteriores usando sudo
# sudo rm -f /tmp/zf1.tar.gz
# sudo rm -f /usr/local/bin/zf
# sudo rm -rf "$DIR_ZEND_PROJECT"
# #sudo rm -rf "$ZF_DIR"

# if [ ! -d "$ZF_DIR" ]; then
#     pintar "📥 Descargando Zend Framework v${ZF_VERSION}..." "menu"
#     sudo mkdir -p "$ZF_DIR"
    
#     # IMPORTANTE: Se cambia wget por curl -L para seguir redirecciones de GitHub de forma segura
#     #sudo curl -L "https://github.com{ZF_VERSION}/ZendFramework-${ZF_VERSION}-minimal.tar.gz" -o /tmp/zf1.tar.gz
#     sudo curl -L "https://github.com/zendframework/zf1/releases/download/release-${ZF_VERSION}/ZendFramework-${ZF_VERSION}-minimal.tar.gz" -o /tmp/zf1.tar.gz
    
#     # COMPROBACIÓN CRÍTICA: Validar si el archivo realmente se descargó y no está vacío
#     if [ ! -s /tmp/zf1.tar.gz ]; then
#         pintar "❌ ERROR CRÍTICO: No se pudo descargar Zend Framework. Comprueba tu conexión a internet." "error"
#         sudo rm -f /tmp/zf1.tar.gz
#         sudo rm -rf "$ZF_DIR"
#         # Opcional: meter aquí un plan de contingencia o saltar esta sección
#     else
#         pintar "📦 Extrayendo archivos en $ZF_DIR..." "menu"
#         sudo tar -xzf /tmp/zf1.tar.gz -C "$ZF_DIR" --strip-components=1
#         sudo rm -f /tmp/zf1.tar.gz
        
#         # Configurar enlace operativo
#         sudo chmod +x "$ZF_DIR/bin/zf.sh"
#         sudo ln -sf "$ZF_DIR/bin/zf.sh" /usr/local/bin/zf
#         pintar "✅ Comando global 'zf' operativo." "exito"
        
#         # Crear esqueleto del proyecto
#         if [ ! -d "$DIR_ZEND_PROJECT" ]; then
#             pintar "🛠️ Creando el esqueleto del proyecto en $DIR_ZEND_PROJECT..." "menu"
#             mkdir -p "/home/${USER}/workspace"
#             /usr/local/bin/zf create project "$DIR_ZEND_PROJECT"
#             ln -s "$ZF_DIR/library/Zend" "$DIR_ZEND_PROJECT/library/Zend"
#             chown -R "${USER}:${USER}" "$DIR_ZEND_PROJECT"
#             pintar "✅ Proyecto base estructurado correctamente." "exito"
#         fi
        
#         # Reiniciar Apache de forma segura
#         pintar "🔄 Reiniciando Apache..." "menu"
#         sudo systemctl restart apache2
#         pintar "✅ Librería ZendFramework instalada globalmente." "exito"
#     fi

# else
#     pintar "🔄 La librería Zend Framework ya existe en $ZF_DIR." "alerta"
# fi



# # ==========================================
# # 2. CONFIGURAR EL COMANDO 'zf' EN EL SISTEMA
# # ==========================================
# # Creamos un enlace simbólico del script ejecutable de Zend hacia la ruta bin global del sistema
# if [ ! -f "$ZF_DIR/bin/zf" ]; then
#     sudo chmod +x "$ZF_DIR/bin/zf.sh"
#     sudo ln -sf "$ZF_DIR/bin/zf.sh" /usr/local/bin/zf
#     pintar "✅ Comando global 'zf' configurado." "exito"
# else
#     pintar "No se creó el archivo $ZF_DIR/bin/zf.sh" "error"
# fi

# # Crear el proyecto (Forzando el uso temporal de PHP 7.4 para evitar el Fatal Error)
# if [ ! -d "$DIR_ZEND_PROJECT" ]; then
#     pintar "🛠️ Generando el esqueleto de Zend con intérprete compatible PHP 7.4..." "menu"
#     mkdir -p "/home/${USER}/workspace"
    
#     # Ejecutamos el creador llamando explícitamente a php7.4
#     sudo php7.4 /usr/local/bin/zf create project "$DIR_ZEND_PROJECT"
    
#     sudo ln -s "$ZF_DIR/library/Zend" "$DIR_ZEND_PROJECT/library/Zend"
#     sudo chown -R "${USER}:${USER}" "$DIR_ZEND_PROJECT"
# fi

# # ==========================================
# # 3. CREACIÓN DEL PROYECTO BASE (SKELETON)
# # ==========================================
# if [ ! -d "$DIR_ZEND_PROJECT" ]; then
#     pintar "🛠️ Creando la estructura del proyecto en $DIR_ZEND_PROJECT..." "menu"
#     mkdir -p "/home/${USER}/workspace"
    
#     # Ejecutamos la herramienta de Zend para inicializar el esqueleto del proyecto
#     /usr/local/bin/zf create project "$DIR_ZEND_PROJECT"
    
#     # Creamos un enlace simbólico interno a la librería para que PHP la reconozca de inmediato
#     ln -s "$ZF_DIR/library/Zend" "$DIR_ZEND_PROJECT/library/Zend"
    
#     # Corregir los dueños de los archivos para tu usuario de escritorio
#     chown -R "${USER}:${USER}" "$DIR_ZEND_PROJECT"
#     pintar "✅ Esqueleto de Zend Framework creado exitosamente." "exito"
# else
#     pintar "🔄 El directorio del proyecto $DIR_ZEND_PROJECT ya existe." "alerta"
# fi


# # ==========================================
# # 4. CREACIÓN DEL VIRTUALHOST Y HOSTS PARA ZEND
# # ==========================================
# pintar "📝 Creando VirtualHost para zend.test aislado en Apache con PHP 7.4..." "menu"

# sudo tee /etc/apache2/sites-available/zend.test.conf > /dev/null <<EOF
# <VirtualHost *:80>
#     ServerName zend.test
#     DocumentRoot $DIR_ZEND_PROJECT/public

#     <Directory $DIR_ZEND_PROJECT/public>
#         Options Indexes FollowSymLinks
#         AllowOverride All
#         Require all granted
#     </Directory>

#     # Enviar peticiones PHP de este Host al socket en segundo plano de PHP 7.4
#     <FilesMatch \.php$>
#         SetHandler "proxy:unix:/var/run/php/php7.4-fpm.sock|fcgi://localhost"
#     </FilesMatch>

#     ErrorLog \${APACHE_LOG_DIR}/zend_error.log
#     CustomLog \${APACHE_LOG_DIR}/zend_access.log combined
# </VirtualHost>
# EOF

# # Activar módulos de proxy en Apache requeridos por FPM
# sudo a2enmod proxy proxy_fcgi setenvif > /dev/null

# # Activar el nuevo sitio .test y apagar el default
# sudo a2ensite zend.test.conf > /dev/null
# sudo a2dissite 000-default.conf > /dev/null

# # Agregar zend.test al archivo hosts si no existe
# if ! grep -q "zend.test" /etc/hosts; then
#     echo "127.0.1.1       zend.test" | sudo tee -a /etc/hosts > /dev/null
# fi

# pintar "🔄 Reiniciando servicios..." "menu"
# sudo systemctl restart php7.4-fpm
# sudo systemctl restart apache2

# pintar "[OK] 🎉 ¡Entorno Multi-PHP configurado con éxito!" "exito"


# ==========================================
# 5. REINICIAR APACHE
# ==========================================
pintar "🔄 Reiniciando Apache para aplicar cambios..." "menu"
sudo systemctl restart apache2

pintar "🎉 ¡Proyecto Zend listo! Abre en tu navegador:" "exito"
pintar "👉 http://zend.test"

fi # fin if [ ! -d "$ZF_DIR" ]; then


pintar "#######################################################################################################"


# --- CONFIGURACIÓN PREVIA (Debe coincidir con los pasos anteriores) ---
#DB_NAME="prueba_db"  # Nombre de la base de datos que creamos antes
BACKUP_USER="sql"    # Nombre del usuario del sistema solicitado

if [ -d "/home/$BACKUP_USER" ]; then
    pintar "Ya existe /home/$BACKUP_USER, no lo creamos" "alerta"
else
pintar "⚙️ Iniciando la creación del usuario del sistema y el respaldo de la Base de Datos..." "menu"

# ==========================================
# 1. CREACIÓN DEL USUARIO DEL SISTEMA 'sql'
# ==========================================
# Comprobar si el usuario del sistema ya existe para evitar errores
if ! id "$BACKUP_USER" &>/dev/null; then
    pintar "👤 Creando el usuario del sistema '${BACKUP_USER}'..." "menu"
    # --m create_home: Fuerza la creación de /home/sql
    # --system: Crea un usuario de servicio sin caducidad ni login directo de escritorio
    if ! id "$BACKUP_USER" &>/dev/null; then
        sudo useradd -m -s /bin/bash --system "$BACKUP_USER"
    fi
    pintar "✅ Usuario del sistema '${BACKUP_USER}' creado correctamente." "exito"
else
    pintar "🔄 El usuario del sistema '${BACKUP_USER}' ya existe." "alerta"
fi

# Definir la ruta de destino dentro de su home
TARGET_DIR="/home/${BACKUP_USER}"
BACKUP_FILE="${TARGET_DIR}/${DB_NAME}_backup.sql"


# ==========================================
# 2. EXPORTACIÓN DE LA BASE DE DATOS (mysqldump)
# ==========================================
pintar "📥 Exportando la base de datos '${DB_NAME}' mediante mysqldump..." "menu"

# Ejecutamos mysqldump con privilegios sudo utilizando la autenticación por socket
# --single-transaction: Evita bloquear las tablas durante el volcado (buena práctica)
#sudo mysqldump --single-transaction "$DB_NAME" > "$BACKUP_FILE"
mysqldump --single-transaction "$DB_NAME" > /tmp/backup_tmp.sql
sudo mv /tmp/backup_tmp.sql "$BACKUP_FILE"
sudo chown "${BACKUP_USER}:${BACKUP_USER}" "$BACKUP_FILE"
sudo chmod 600 "$BACKUP_FILE"
if [ $? -eq 0 ]; then
    pintar "✅ Archivo SQL generado con éxito en temporal: $BACKUP_FILE" "exito"
else
    pintar "⚠️ Error al intentar exportar la base de datos." "error"
    exit 1
fi


# ==========================================
# 3. ASIGNACIÓN DE PERMISOS CORRECTOS
# ==========================================
pintar "🔑 Ajustando los permisos del archivo para el usuario '${BACKUP_USER}'..." "menu"

# Cambiar el dueño y el grupo del archivo generado para que pertenezca a 'sql' y no a root
sudo chown "${BACKUP_USER}:${BACKUP_USER}" "$BACKUP_FILE"

# Asignar permisos estrictos de lectura y escritura únicamente para el usuario dueño (chmod 600)
sudo chmod 600 "$BACKUP_FILE"

pintar "🎉 ¡Todo listo! El respaldo se encuentra protegido en:" "exito"
pintar "👉 $BACKUP_FILE"

fi # fin if [ ¡ -d "/home/$BACKUP_USER" ]; then


pintar "#######################################################################################################"


# CALCULO DE TIEMPOS
# end_time_LAMP=$(date +"%T")
# end_ts=$(date +%s)
# datediff_total=$((end_ts - start_ts))
# elapsed_time_total=$(date -u -d @"$datediff_total" +%H:%M:%S)
# elapsed_hours_total=$((datediff_total/3600))
# elapsed_minutes_total=$(((datediff_total % 3600)/60))
# elapsed_seconds_total=$((datediff_total % 60))
# pintar "HORA INICIO: $start_time_total" "exito"
# pintar "HORA FIN: $end_time_total" "exito"
# pintar "TIEMPO TRANSCURRIDO: $elapsed_time_total" "exito"
# pintar ""
# pintar "EL PROCESO DEMORO ${elapsed_hours_total} HRS CON ${elapsed_minutes_total} MINS Y ${elapsed_seconds_total} SEGS EN EJECUTARSE." "exito"

## Guardar el segundo exacto de finalización
SEGUNDOS_FIN=$(date +%s)
HORA_FIN_HUMANA=$(date +%H:%M:%S)

# Calcular la diferencia matemática en segundos netos
DIFERENCIA_SEGUNDOS=$(( SEGUNDOS_FIN - SEGUNDOS_INICIO ))

# Extraer horas, minutos y segundos matemáticamente de la diferencia sin usar comandos externos 'date'
HORAS=$(( DIFERENCIA_SEGUNDOS / 3600 ))
MINUTOS=$(( (DIFERENCIA_SEGUNDOS % 3600) / 60 ))
SEGUNDOS=$(( DIFERENCIA_SEGUNDOS % 60 ))

pintar "==================================================" "exito"
pintar "📅 HORA INICIO: $HORA_INICIO_HUMANA" "exito"
pintar "📅 HORA FIN: $HORA_FIN_HUMANA" "exito"
pintar "⏳ EL PROCESO DEMORÓ $HORAS HRS CON $MINUTOS MINS Y $SEGUNDOS SEGS EN EJECUTARSE." "exito"
pintar "==================================================" "exito"
