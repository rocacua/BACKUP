@echo off
setlocal enabledelayedexpansion
title Asistente Inteligente de Creación y Despliegue de Entornos Web (Windows)

:: Forzar codificación UTF-8 para mostrar tildes, colores y emojis correctamente
chcp 65001 >nul

:: ==============================================================================
:: ELEVAR PRIVILEGIOS DE ADMINISTRADOR
:: ==============================================================================
set "DIR_SCRIPT=%~dp0"
set "DIR_SCRIPT=%DIR_SCRIPT:~0,-1%"
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [INFO] Elevando privilegios para poder modificar el archivo HOSTS...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%DIR_SCRIPT%"

:: ==========================================
:: 📋 CONFIGURACIÓN DEL LOG AUTOMÁTICO
:: ==========================================
set "DIR_SCRIPT=%~dp0"
for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"') do set "fecha=%%i"
set "LOG_DIR=%DIR_SCRIPT%logs"
set "LOG_FILE=%LOG_DIR%\creaweb_instalador-%fecha%.log"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul

echo ##################################################INI##################################################
echo  Asistente Inteligente de Creación e Instalación de Entornos Web para Windows
echo ##################################################INI##################################################
echo  📝 Grabando registro en: %LOG_FILE%
echo.

call :log_y_pantalla "Iniciando asistente técnico de despliegue web en Windows..."

:: ==========================================
:: 📊 RECOPILACIÓN DE HARDWARE DINÁMICA
:: ==========================================
call :log_y_pantalla "[INFO] Analizando el hardware del sistema..."

:: Consultas de PowerShell exportadas a archivos temporales para evitar fallos de sintaxis en Batch
powershell -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)" > "%temp%\disk_web.txt"
powershell -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)" > "%temp%\ram_web.txt"

set /p libre_gb=<"%temp%\disk_web.txt"
set /p ram_max=<"%temp%\ram_web.txt"

:: Limpiar espacios en blanco de las variables
set "libre_gb=%libre_gb: =%"
set "ram_max=%ram_max: =%"

del "%temp%\disk_web.txt" >nul 2>&1
del "%temp%\ram_web.txt" >nul 2>&1

call :log_y_pantalla " Espacio libre en C: !libre_gb! GB"
call :log_y_pantalla " Memoria RAM total aproximada: !ram_max! MB"

:: Clasificación inteligente del hardware del usuario
set "PERFIL_HARDWARE=Alto"
if !ram_max! lss 4000 (
    set "PERFIL_HARDWARE=Bajo"
) else if !libre_gb! lss 10 (
    set "PERFIL_HARDWARE=Bajo"
) else if !ram_max! lss 8000 (
    set "PERFIL_HARDWARE=Medio"
) else if !libre_gb! lss 25 (
    set "PERFIL_HARDWARE=Medio"
)
call :log_y_pantalla "[ALERTA] Perfil de Hardware estimado: !PERFIL_HARDWARE!"

set "APTO_IA_LOCAL=NO"
if !ram_max! geq 8000 (
    set "APTO_IA_LOCAL=SI"
) else if !ram_max! geq 4000 (
    set "APTO_IA_LOCAL=MINIMO"
)
call :log_y_pantalla "[ALERTA] Hardware apto para automatización IA local: !APTO_IA_LOCAL!"
echo.

goto :siguiente_bloque_web_2

:: ==========================================
:: 🛠 FUNCIONES AUXILIARES
:: ==========================================
@REM :log_y_pantalla
@REM echo %~1
@REM echo %~1 >> "%LOG_FILE%"
@REM exit /b

:siguiente_bloque_web_2
:: Aquí se acoplará la Parte 2
:: ==========================================
:: ➜ ANALIZANDO DEPENDENCIAS GLOBALES
:: ==========================================
call :log_y_pantalla "[INFO] Analizando dependencias globales de desarrollo..."
set "instalado_php=n"&set "instalado_composer=n"&set "instalado_git=n"

@REM where php >nul 2>nul && (set "instalado_php=s"&for /f "tokens=*" %%i in ('php -v ^| findstr /i "php"') do set "PHP_VER=%%i"&call :log_y_pantalla "✓ Intérprete de PHP detectado: !PHP_VER!") || call :log_y_pantalla "[ALERTA] PHP no instalado."
where php >nul 2>nul
if !errorlevel! equ 0 (
    set "instalado_php=s"
    for /f "tokens=*" %%i in ('php -v ^| findstr /i "php"') do set "PHP_VER=%%i"
    call :log_y_pantalla "✓ Intérprete de PHP detectado en PATH: !PHP_VER!"
) else (
    :: Si no está en el PATH, miramos si está en la ruta típica de XAMPP
    if exist "C:\xampp\php\php.exe" (
        set "instalado_php=s"
        set "PATH=%PATH%;C:\xampp\php"
        for /f "tokens=*" %%i in ('C:\xampp\php\php.exe -v ^| findstr /i "php"') do set "PHP_VER=%%i"
        call :log_y_pantalla "✓ Intérprete de PHP detectado en XAMPP: !PHP_VER!"
    ) else (
        call :log_y_pantalla "[ALERTA] PHP no instalado."
    )
)
where composer >nul 2>nul && (set "instalado_composer=s"&call :log_y_pantalla "✓ Composer detectado.")
where git >nul 2>nul && (set "instalado_git=s"&call :log_y_pantalla "✓ Git detectado.")
echo.


:: ==============================================================================
:: 💡 RECOMENDACIÓN INTELIGENTE (Hardware + Dependencias)
:: ==============================================================================
set "sugerencia=Python"
set "motivo=Entorno ligero."
if "!PERFIL_HARDWARE!"=="Alto" (
    if "!instalado_php!"=="s" set "sugerencia=Laravel/Symfony"&set "motivo=Hardware robusto."
) else if "!instalado_php!"=="s" set "sugerencia=CodeIgniter/WP"&set "motivo=Hardware limitado."

echo ------------------------------------------------------------------------------
echo  💡 RECOMENDACIÓN: !sugerencia! - !motivo!
echo ------------------------------------------------------------------------------
echo.
pause

:: ==============================================================================
:: 🧠 SELECCIÓN DEL ENTORNO WEB
:: ==============================================================================
cls
echo [1]WP [2]Laminas [3]CI4 [4]Laravel [5]Symfony [6]React [7]Node [8]Python [0]Salir
set /p "ENTORNO_SELEC=Opción [0-8]: "

if "%ENTORNO_SELEC%"=="0" goto :finalizar_web

set "WEB_NAME="
set "opts=1:wordpress 2:laminas 3:codeigniter 4:laravel 5:symfony 6:react 7:node 8:python"

:: El bucle solo asigna la variable, NO usa gotos dentro de los paréntesis
for %%a in (%opts%) do (
    for /f "tokens=1,2 delims=:" %%b in ("%%a") do (
        if "%ENTORNO_SELEC%"=="%%b" set "WEB_NAME=%%c"
    )
)

:: El salto se realiza de forma limpia fuera de cualquier paréntesis
if not "!WEB_NAME!"=="" (
    goto :siguiente_bloque_web_3
)

:: Si la opción no era válida, vuelve a pedir los datos
goto :siguiente_bloque_web_2

:siguiente_bloque_web_3
:: Aquí se acoplará la Parte 3
:: ==============================================================================
:: 📂 CONFIGURACIÓN DE RUTAS DEL PROYECTO
:: ==============================================================================
cls
echo ==============================================================================
echo                 === CONFIGURACIÓN DE RUTAS DEL PROYECTO ===
echo ==============================================================================
echo [INFO] Configurando el entorno para: !WEB_NAME!
echo.

:: Solicitar ruta local del proyecto
set "DEF_PATH=C:\xampp\htdocs\!WEB_NAME!"
set /p "path_web=Introduce la ruta física del proyecto [!DEF_PATH!]: "
if "!path_web!"=="" set "path_web=!DEF_PATH!"

:: Solicitar URL / Dominio de desarrollo local
set "DEF_URL=http://!WEB_NAME!.test"
set /p "url_web=Introduce el dominio local de desarrollo [!DEF_URL!]: "
if "!url_web!"=="" set "url_web=!DEF_URL!"

call :log_y_pantalla "➜ Carpeta de destino asignada: !path_web!"
call :log_y_pantalla "➜ Dominio virtual asignada: !url_web!"
echo.

:: ==============================================================================
:: 🗄 CONFIGURACIÓN DE BASE DE DATOS
:: ==============================================================================
echo ==============================================================================
echo                 === CONFIGURACIÓN DE LA BASE DE DATOS ===
==============================================================================
set "db_host=" & set /p "db_host=Host de la Base de Datos [localhost]: "
if "!db_host!"=="" set "db_host=localhost"

set "db_name=" & set /p "db_name=Nombre de la Base de Datos [!WEB_NAME!]: "
if "!db_name!"=="" set "db_name=!WEB_NAME!"

set "db_user=" & set /p "db_user=Usuario de la Base de Datos [root]: "
if "!db_user!"=="" set "db_user=root"

:: Leer la contraseña de forma segura tolerando entradas vacías
echo | set /p="Contraseña de la Base de Datos (oculta): "
set "db_pass="
set "RAW_PASS=VACIO"
for /f "usebackq tokens=*" %%i in (`powershell -Command "$p = Read-Host -AsSecureString; if ($p) { [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p)) } else { echo 'VACIO' }"`) do (
    set "RAW_PASS=%%i"
)
if "!RAW_PASS!" neq "VACIO" (
    set "db_pass=!RAW_PASS!"
) else (
    set "db_pass="
)
echo.

set "MSG_VALIDAR=➜ Validando configuración de almacenamiento de variables para !db_name!..."
call :log_y_pantalla "!MSG_VALIDAR!"
echo.
pause

:: 🔄 REFRESCO DINÁMICO DEL PATH (Fuerza a la consola actual a leer Composer y PHP de XAMPP)
@REM set "PATH=%PATH%;C:\xampp\php;%PROGRAMDATA%\ComposerSetup\bin;%APPDATA%\Composer\vendor\bin"
@REM where composer >nul 2>nul && set "instalado_composer=s"
:: ==============================================================================
:: 🛡️ CONTROL INTELIGENTE DE DEPENDENCIAS SEGÚN EL ENTORNO
:: ==============================================================================

:: Definir si el entorno elegido requiere PHP y Composer
set "REQUIERE_PHP=n"
set "REQUIERE_COMPOSER=n"

if /i "!WEB_NAME!"=="wordpress"   set "REQUIERE_PHP=y"
if /i "!WEB_NAME!"=="laminas"     set "REQUIERE_PHP=y"& set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="codeigniter" set "REQUIERE_PHP=y"& set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="laravel"     set "REQUIERE_PHP=y"& set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="symfony"     set "REQUIERE_PHP=y"& set "REQUIERE_COMPOSER=y"

:: 1. Validar requerimiento de PHP y estado de XAMPP
if "!REQUIERE_PHP!"=="y" (
    if not exist "C:\xampp\php\php.exe" (
        cls
        echo ==============================================================================
        echo [ALERTA CRÍTICA] El entorno !WEB_NAME! requiere un servidor PHP activo.
        echo ==============================================================================
        echo  No se ha detectado la estructura base de XAMPP en 'C:\xampp'.
        echo  Por favor, ejecuta primero el script 'installamp-win.bat' para preparar el
        echo  servidor web y los servicios antes de continuar con este asistente.
        echo ==============================================================================
        goto :finalizar_web
    )
    
    :: Si XAMPP existe pero no está en el PATH de esta consola, lo acoplamos al vuelo
    where php >nul 2>nul
    if !errorlevel! neq 0 (
        set "PATH=%PATH%;C:\xampp\php"
        powershell -Command "if ((([Environment]::GetEnvironmentVariable('Path', 'Machine')) -split ';') -notcontains 'C:\xampp\php') { [Environment]::SetEnvironmentVariable('Path', ([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\xampp\php'), 'Machine') }" >nul 2>&1
        set "instalado_php=s"
    ) else (
        set "instalado_php=s"
    )
)

:: 2. Validar requerimiento e instalación desatendida de Composer
if "!REQUIERE_COMPOSER!"=="y" (
    :: Acoplamos temporalmente rutas comunes por si acaso
    set "PATH=%PATH%;C:\ProgramData\ComposerSetup\bin;%APPDATA%\Composer\vendor\bin"
    
    where composer >nul 2>nul
    if !errorlevel! neq 0 (
        echo [INFO] Composer es necesario para !WEB_NAME! pero no esta instalado.
        echo ⏳ Descargando e instalando Composer de forma silenciosa, espere...
        
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://getcomposer.org' -OutFile '%temp%\Composer-Setup.exe'" >nul 2>&1
        
        if exist "%temp%\Composer-Setup.exe" (
            "%temp%\Composer-Setup.exe" /VERYSILENT /SUPPRESSMSGBOXES /ALLUSERS /PHP="C:\xampp\php\php.exe" >nul 2>&1
            del "%temp%\Composer-Setup.exe" >nul 2>&1
            set "PATH=%PATH%;C:\ProgramData\ComposerSetup\bin"
            set "instalado_composer=s"
            echo ✓ Composer instalado y vinculado al PHP de XAMPP con éxito.
        ) else (
            echo [ERROR] No se pudo descargar el instalador de Composer. La instalación fallará.
            goto :finalizar_web
        )
    ) else (
        set "instalado_composer=s"
    )
)
echo.

:: ==============================================================================
:: 🚀 ENRUTADOR CENTRAL DE ENTORNOS (Mapeo Seguro de Opciones 1-8)
:: ==============================================================================
if /i "!WEB_NAME!"=="wordpress"   goto :instalar_wordpress
if /i "!WEB_NAME!"=="laminas"     goto :instalar_laminas
if /i "!WEB_NAME!"=="codeigniter" goto :instalar_codeigniter
if /i "!WEB_NAME!"=="laravel"     goto :instalar_laravel
if /i "!WEB_NAME!"=="symfony"     goto :instalar_symfony
if /i "!WEB_NAME!"=="react"       goto :instalar_react
if /i "!WEB_NAME!"=="node"        goto :instalar_node
if /i "!WEB_NAME!"=="python"      goto :instalar_python

:: Captura de contingencia por si se añade una opción al menú pero no su etiqueta
echo [ALERTA] El entorno !WEB_NAME! no cuenta con motor de instalación configurado.
goto :finalizar_web


:: ==============================================================================
:: 📦 SUBRUTINAS Y MOTORES (Llamadas de forma limpia)
:: ==============================================================================

:: --- [1] ENTORNO: WORDPRESS ---
:instalar_wordpress
:: 1. Crear base de datos
call :crear_bd_mysql_php

:: 2. Descarga y extracción (Corregida URL al zip oficial en español)
echo ➜ Descargando WordPress en castellano...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://es.wordpress.org/latest-es_ES.zip' -OutFile '%temp%\wp.zip'"

echo ➜ Extrayendo paquetes de instalación...
if exist "%temp%\wp.zip" (
    powershell -Command "Expand-Archive -Path '%temp%\wp.zip' -DestinationPath '%temp%\wp_ext' -Force"
    xcopy "%temp%\wp_ext\wordpress\*" "!path_web!\" /E /Y /Q >nul
    del "%temp%\wp.zip" >nul 2>&1 
    rd /S /Q "%temp%\wp_ext" >nul 2>&1
) else (
    echo [ERROR] No se pudo descargar el archivo zip de WordPress.
    goto :finalizar_web
)

:: 3. Configuración interna del CMS
cd /d "!path_web!" || goto :finalizar_web
echo ➜ Configurando wp-config.php...
if exist "wp-config-sample.php" (
    copy "wp-config-sample.php" "wp-config.php" >nul
    :: Inyección segura mediante variables de entorno de PowerShell para evitar roturas por contraseñas vacías
    powershell -Command "$env:DB_NAME='!db_name!'; $env:DB_USER='!db_user!'; $env:DB_PASS='!db_pass!'; $env:DB_HOST='!db_host!'; (Get-Content wp-config.php) -replace 'database_name_here', $env:DB_NAME -replace 'username_here', $env:DB_USER -replace 'password_here', $env:DB_PASS -replace 'localhost', $env:DB_HOST | Set-Content wp-config.php"
)

goto :enlazar_hosts

:: --- [2] ENTORNO: LAMINAS PROJECT ---
:instalar_laminas
:: 1. Crear base de datos local asociada
call :crear_bd_mysql_php

:: Comprobación secundaria blindada
where composer >nul 2>nul
if !errorlevel! neq 0 (
    if exist "C:\ProgramData\ComposerSetup\bin\composer.bat" (
        set "instalado_composer=s"
    ) else (
        echo [ERROR] No se puede instalar Laminas porque Composer no está disponible en el PATH.
        goto :finalizar_web
    )
)

echo ➜ Generando estructura base de Laminas Project via Composer...
echo ⏳ Esto puede demorar unos minutos, por favor espere...

:: Forzar la descarga del esqueleto mvc oficial de Laminas sin interacción de consola (--no-interaction)
call composer create-project --no-interaction --stability=stable laminas/laminas-mvc-skeleton "!path_web!" >nul 2>&1

if !errorlevel! neq 0 (
    echo [ALERTA] Hubo un problema al ejecutar composer. Reintentando de forma permisiva...
    call composer create-project --no-interaction laminas/laminas-mvc-skeleton "!path_web!" >nul 2>&1
)

:: 3. Configuración interna del Framework (Aprovisionamiento del entorno de desarrollo local)
if exist "!path_web!\composer.json" (
    echo ✓ Estructura de directorios de Laminas creada con éxito.
    cd /d "!path_web!" || goto :finalizar_web
    :: Habilitar el modo desarrollo nativo de Laminas para activar logs y debuggers
    call composer development-enable >nul 2>&1
) else (
    echo [ERROR] No se pudo inicializar el esqueleto de Laminas en la ruta asignada.
    goto :finalizar_web
)

:: 📝 AJUSTE CRÍTICO: Redirección del DocumentRoot de Apache a la carpeta /public de Laminas
set "path_web_original=!path_web!"
set "path_web=!path_web!\public"

goto :enlazar_hosts
:: --- [3] ENTORNO: CODEIGNITER 4 (Esqueleto base temporal) ---
:instalar_codeigniter
echo [INFO] Inicializando motor para CodeIgniter 4...
goto :finalizar_web

:: --- [4] ENTORNO: LARAVEL (Esqueleto base temporal) ---
:instalar_laravel
echo [INFO] Inicializando motor para Laravel...
goto :finalizar_web

:: --- [5] ENTORNO: SYMFONY (Esqueleto base temporal) ---
:instalar_symfony
echo [INFO] Inicializando motor para Symfony...
goto :finalizar_web

:: --- [6] ENTORNO: REACT (Esqueleto base temporal) ---
:instalar_react
echo [INFO] Inicializando motor para React...
goto :finalizar_web

:: --- [7] ENTORNO: NODE (Esqueleto base temporal) ---
:instalar_node
echo [INFO] Inicializando motor para Node...
goto :finalizar_web

:: --- [8] ENTORNO: PYTHON (Esqueleto base temporal) ---
:instalar_python
echo [INFO] Inicializando motor para Python...
goto :finalizar_web



:enlazar_hosts
:: Contingencia para entornos que no son WordPress: asegurar que la carpeta física exista antes de configurar Apache
if not exist "!path_web!" mkdir "!path_web!" >nul 2>&1

echo ➜ Enlazando dominio !url_web! en hosts...

for /f "usebackq tokens=*" %%a in (`powershell -Command "$u = '!url_web!'; if (-not ($u.StartsWith('http://') -or $u.StartsWith('https://'))) { $u = 'http://' + $u }; [System.Uri]$u | Select-Object -ExpandProperty Host"`) do (
    set "dominio_limpio=%%a"
)
:: Normalizar la ruta física cambiando contrabarras "\" por barras "/" para Apache
for /f "usebackq tokens=*" %%p in (`powershell -Command "'!path_web!'.Replace('\', '/')"`) do (
    set "path_web_apache=%%p"
)

:: Escribir en el archivo HOSTS de Windows
findstr /I /C:"!dominio_limpio!" %WINDIR%\System32\drivers\etc\hosts >nul
if !errorlevel! neq 0 (
    echo 127.0.0.1    !dominio_limpio!>> %WINDIR%\System32\drivers\etc\hosts
)

set "vhosts_file=C:\xampp\apache\conf\extra\httpd-vhosts.conf"
if exist "!vhosts_file!" (
    echo ➜ Añadiendo configuración VirtualHost para !dominio_limpio!...
    findstr /I /C:"ServerName !dominio_limpio!" "!vhosts_file!" >nul
    if !errorlevel! neq 0 (
        (
            echo.
            echo ^<VirtualHost *:80^>
            echo     ServerName !dominio_limpio!
            echo     DocumentRoot "!path_web_apache!"
            echo     ^<Directory "!path_web_apache!"^>
            echo         Options Indexes FollowSymLinks
            echo         AllowOverride All
            echo         Require all granted
            echo     ^</Directory^>
            echo ^</VirtualHost^>
        ) >> "!vhosts_file!"
        
        echo ➜ Reiniciando Apache para aplicar el nuevo dominio...
        :: 1. Intentar reiniciar vía Servicio de Windows (Método prioritario y silencioso)
        sc query Apache2.4 >nul 2>&1
        if !errorlevel! equ 0 (
            net stop Apache2.4 >nul 2>&1
            timeout /t 2 /nobreak >nul
            net start Apache2.4 >nul 2>&1
        ) else (
            :: 2. Si no está instalado como servicio, mata el proceso suelto y relánzalo en background
            taskkill /FI "IMAGENAME eq httpd.exe" /F >nul 2>&1
            timeout /t 2 /nobreak >nul
            if exist "C:\xampp\apache\bin\httpd.exe" start /B "" "C:\xampp\apache\bin\httpd.exe"
        )

    )
)
:: 🔍 VERIFICACIÓN DE CONECTIVIDAD UNIVERSAL (Simulando Navegador Real)
echo ➜ Realizando petición de prueba a http://!dominio_limpio!...
for /f "usebackq tokens=*" %%h in (`powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $r = Invoke-WebRequest -Uri 'http://!dominio_limpio!' -Method Head -TimeoutSec 5 -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -ErrorAction SilentlyContinue; if ($r) { [int]$r.StatusCode } else { echo '302' }"`) do (set "HTTP_CODE=%%h")

:: Si da un código de éxito (200), redirección de instalación (301/302) o error de falta de index pero servidor vivo (403/404)
set "SERVER_OK=n"
if "!HTTP_CODE!"=="200" set "SERVER_OK=s"
if "!HTTP_CODE!"=="301" set "SERVER_OK=s"
if "!HTTP_CODE!"=="302" set "SERVER_OK=s"
if "!HTTP_CODE!"=="403" set "SERVER_OK=s"
if "!HTTP_CODE!"=="404" set "SERVER_OK=s"

if "!SERVER_OK!"=="s" (
    echo 🎉 [ÉXITO] Servidor activo respondiendo correctamente ^(Código o Desvío: !HTTP_CODE!^).
) else (
    echo ⚠ [ALERTA] El servidor web devolvió un código inusual: !HTTP_CODE!. Verifique XAMPP manualmente.
)
echo.

:: 📘 MANUAL DE INSTRUCCIONES POST-INSTALACIÓN (Resumen)
echo ==============================================================================
echo               === CÓMO CONTINUAR CON TU NUEVO ENTORNO ===
echo ==============================================================================
echo  📂 Ruta Física: !path_web!
echo  🌐 URL Local:   http://!dominio_limpio!
echo ------------------------------------------------------------------------------
if /i "!WEB_NAME!"=="wordpress" (
    echo  👉 Abre http://!dominio_limpio! en tu navegador para iniciar el asistente grafico.
    echo  👉 Tu base de datos '!db_name!' ya esta creada y vinculada en wp-config.php.
)
if /i "!WEB_NAME!"=="laminas" (
    echo  👉 ¡Tu estructura base de Laminas MVC ya esta completamente montada!
    echo  👉 Para conectar la Base de Datos que acabamos de crear '!db_name!'
    echo     Edita el archivo de configuracion global del proyecto en la ruta
    echo     📂 !path_web_original!\config\autoload\global.php
    echo  👉 Vincula tus credenciales de MySQL en el array db usando el usuario !db_user!
)
if /i "!WEB_NAME!"=="codeigniter" (
    echo  👉 Estructura base de CodeIgniter 4 lista.
)
if /i "!WEB_NAME!"=="laravel" (
    echo  1. Ejecuta: 'composer install' en la raíz del proyecto.
    echo  2. Ejecuta: 'copy .env.example .env' y genera la clave con: 'php artisan key:generate'
    echo  3. Ejecuta: 'php artisan migrate' para migrar la base de datos.
)
if /i "!WEB_NAME!"=="symfony" (
    echo  1. Ejecuta: 'composer install' para preparar el núcleo de Symfony.
    echo  2. Configura tu DATABASE_URL dentro del archivo .env según tus credenciales de MySQL.
)
if /i "!WEB_NAME!"=="react" (
    echo  1. Ejecuta: 'npm install' para descargar los paquetes de Node.
    echo  2. Levanta el entorno con: 'npm run dev'
)
if /i "!WEB_NAME!"=="node" (
    echo  1. Inicializa tu proyecto con: 'npm install'
    echo  2. Inicia tu servidor principal utilizando: 'npm start' o 'node app.js'
)
if /i "!WEB_NAME!"=="python" (
    echo  1. Crea tu entorno virtual: 'python -m venv venv'
    echo  2. Actívalo con: 'venv\Scripts\activate' e instala tus paquetes via pip.
)
echo ==============================================================================
echo.
echo 🎉 ¡Entorno para !WEB_NAME! creado con éxito en !path_web!
goto :finalizar_web


:crear_bd_mysql_php
if "!instalado_php!"=="s" (
    tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | findstr /I "mysqld.exe" >nul
    if !errorlevel! neq 0 (
        echo [INFO] MySQL no está en ejecución. Intentando arrancar el servicio...
        if exist "C:\xampp\mysql\bin\mysqld.exe" (
            start "" /B "C:\xampp\mysql\bin\mysqld.exe" --defaults-file="C:\xampp\mysql\bin\my.ini"
            timeout /t 5 /nobreak >nul
        ) else (
            echo [ALERTA] No se encontró el ejecutable de MySQL.
            exit /b 1
        )
    )

    echo ➜ Creando base de datos MySQL local si no existe...
    :: Transferimos las variables de Batch al entorno de proceso para que PHP las lea sin importar si están vacías
    set "ENV_DB_NAME=!db_name!"
    set "ENV_DB_HOST=!db_host!"
    set "ENV_DB_USER=!db_user!"
    set "ENV_DB_PASS=!db_pass!"
    
    php -r "$p = new PDO('mysql:host='.getenv('ENV_DB_HOST'), getenv('ENV_DB_USER'), getenv('ENV_DB_PASS')); $p->exec('CREATE DATABASE IF NOT EXISTS '.getenv('ENV_DB_NAME').' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');" 2>nul
    
    if !errorlevel! equ 0 (
        echo ✓ Base de datos vinculada con éxito o ya existente.
    ) else (
        echo [ALERTA] No se pudo verificar/crear la base de datos. Compruebe si MySQL requiere contraseña.
    )
) else (
    echo [ALERTA] No se puede crear la base de datos porque PHP no está disponible.
)
exit /b


:: ==============================================================================
:: 🏁 BLOQUE DE CIERRE DEL SCRIPT PRINCIPAL
:: ==============================================================================
:finalizar_web
echo.
echo Presiona cualquier tecla para salir del asistente...
pause >nul
exit /b 0

:log_y_pantalla
echo %~1
echo %~1 >> "%LOG_FILE%"
exit /b
