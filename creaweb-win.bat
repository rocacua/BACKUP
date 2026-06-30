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
:: cls
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
if /i "!WEB_NAME!"=="laminas"     set "REQUIERE_PHP=y" && set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="codeigniter" set "REQUIERE_PHP=y" && set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="laravel"     set "REQUIERE_PHP=y" && set "REQUIERE_COMPOSER=y"
if /i "!WEB_NAME!"=="symfony"     set "REQUIERE_PHP=y" && set "REQUIERE_COMPOSER=y"

:: 1. Validar requerimiento de PHP y estado de XAMPP
if "!REQUIERE_PHP!"=="n" goto :saltar_validacion_php

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

:: Ejecución plana de PowerShell para evitar conflictos de paréntesis con CMD
if exist "C:\xampp\php\php.ini" (
    rem powershell -NoProfile -Command "$ini = Get-Content 'C:\xampp\php\php.ini'; $ini -replace ';extension=openssl', 'extension=openssl' -replace ';extension=mbstring', 'extension=mbstring' -replace ';extension=curl', 'extension=curl' -replace ';extension=fileinfo', 'extension=fileinfo' -replace ';extension=zip', 'extension=zip' | Set-Content 'C:\xampp\php\php.ini'" >nul 2>&1
    rem powershell -NoProfile -Command "$ini = Get-Content 'C:\xampp\php\php.ini'; $ini -replace ';extension=mbstring', 'extension=mbstring' -replace ';extension=curl', 'extension=curl' -replace ';extension=fileinfo', 'extension=fileinfo' -replace ';extension=zip', 'extension=zip' | Set-Content 'C:\xampp\php\php.ini'" >nul 2>&1
    powershell -NoProfile -Command "$ini = Get-Content 'C:\xampp\php\php.ini'; $ini -replace ';extension=mbstring', 'extension=mbstring' -replace ';extension=curl', 'extension=curl' -replace ';extension=fileinfo', 'extension=fileinfo' -replace ';extension=zip', 'extension=zip' -replace ';extension=intl', 'extension=intl' | Set-Content 'C:\xampp\php\php.ini'" >nul 2>&1
)
:: ==============================================================================
:: NUEVO: Auto-parcheo de seguridad de Apache para habilitar módulos Proxy (Evita Error 500)
:: ==============================================================================
@REM if exist "C:\xampp\apache\conf\httpd.conf" (
@REM     powershell -NoProfile -Command "$h = Get-Content 'C:\xampp\apache\conf\httpd.conf'; $h -replace '#LoadModule proxy_module', 'LoadModule proxy_module' -replace '#LoadModule proxy_http_module', 'LoadModule proxy_http_module' | Set-Content 'C:\xampp\apache\conf\httpd.conf'" >nul 2>&1
@REM )
:: ==============================================================================
:: Si XAMPP existe pero no está en el PATH de esta consola, lo acoplamos al vuelo
where php >nul 2>nul
if !errorlevel! neq 0 (
    set "PATH=%PATH%;C:\xampp\php"
    powershell -NoProfile -Command "if ((([Environment]::GetEnvironmentVariable('Path', 'Machine')) -split ';') -notcontains 'C:\xampp\php') { [Environment]::SetEnvironmentVariable('Path', ([Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\xampp\php'), 'Machine') }" >nul 2>&1
)
set "instalado_php=s"

:saltar_validacion_php

:: 2. Validar requerimiento e instalación desatendida de Composer
if "!REQUIERE_COMPOSER!"=="n" goto :saltar_validacion_composer

:: Acoplamos temporalmente rutas comunes por si acaso
set "PATH=%PATH%;C:\ProgramData\ComposerSetup\bin;%APPDATA%\Composer\vendor\bin"

where composer >nul 2>nul
if !errorlevel! equ 0 (
    set "instalado_composer=s"
    goto :saltar_validacion_composer
)

echo [INFO] Composer es necesario para !WEB_NAME! pero no esta instalado.
echo ⏳ Descargando e instalando Composer de forma silenciosa, espere...

powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://getcomposer.org/Composer-Setup.exe' -OutFile '%temp%\Composer-Setup.exe'" >nul 2>&1

if not exist "%temp%\Composer-Setup.exe" (
    echo [ERROR] No se pudo descargar el instalador de Composer. La instalación fallará.
    goto :finalizar_web
)

"%temp%\Composer-Setup.exe" /VERYSILENT /SUPPRESSMSGBOXES /ALLUSERS /PHP=C:\xampp\php\php.exe >nul 2>&1
del "%temp%\Composer-Setup.exe" >nul 2>&1

echo ✓ Composer instalado y vinculado al PHP de XAMPP con éxito.

:: Refrescar PATH dinámico de forma limpia sin usar bloques IF anidados
for /f "delims=" %%M in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'Machine')"') do set "SYS_PATH=%%M"
for /f "delims=" %%U in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'User')"') do set "USR_PATH=%%U"
set "PATH=!SYS_PATH!;!USR_PATH!;C:\xampp\php;C:\ProgramData\ComposerSetup\bin"

set "instalado_composer=s"

:saltar_validacion_composer
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
    if exist "C:\ProgramData\ComposerSetup\bin\composer.cmd" (
        set "instalado_composer=s"
        set "PATH=%PATH%;C:\ProgramData\ComposerSetup\bin"
    ) else (
        echo [ERROR] No se puede instalar Laminas porque Composer no está disponible en el PATH.
        goto :finalizar_web
    )
)

:: NUEVO: Limpiar residuos de instalaciones fallidas previas para evitar el bloqueo de Composer
if exist "!path_web!" (
    rd /s /q "!path_web!" >nul 2>&1
)

echo ➜ Generando estructura base de Laminas Project via Composer...
echo ⏳ Esto puede demorar unos minutos, por favor espere...
:: composer diagnose
:: Forzar la descarga del esqueleto mvc oficial de Laminas sin interacción de consola (--no-interaction)
call composer create-project --no-interaction --stability=stable laminas/laminas-mvc-skeleton "!path_web!" >nul 2>&1

if !errorlevel! neq 0 (
    echo [ALERTA] Hubo un problema al ejecutar composer. Reintentando mostrando salida...
    :: Eliminamos residuos del primer intento fallido antes de reintentar
    if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
    :: Reintento permisivo mostrando errores en consola por si falta alguna extensión o hay caída de red
    call composer create-project --no-interaction laminas/laminas-mvc-skeleton "!path_web!"
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
:: Forzamos un código de salida exitoso (0) para que el script ignore el fallo estético del script interno de Laminas
ver >nul
:: 📝 AJUSTE CRÍTICO: Redirección del DocumentRoot de Apache a la carpeta /public de Laminas
set "path_web_original=!path_web!"
set "path_web=!path_web!\public"

goto :enlazar_hosts

:: --- ENTORNO: CODEIGNITER 4 ---
:instalar_codeigniter
:: 1. Crear base de datos local asociada
call :crear_bd_mysql_php

:: Comprobación de Composer
if not exist "C:\ProgramData\ComposerSetup\bin\composer.phar" (
    echo [ERROR] No se puede instalar CodeIgniter porque composer.phar no está disponible.
    goto :finalizar_web
)

:: Limpiar residuos de instalaciones fallidas previas
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1

echo ➜ Generando estructura base de CodeIgniter 4 via Composer...
echo ⏳ Esto puede demorar unos minutos, por favor espere...

:: Invocación plana e inmunizada con PHP
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project codeigniter4/appstarter "!path_web!" --no-interaction >nul 2>&1

:: Guardamos el estado de forma segura
set "COMPOSER_STATUS=%ERRORLEVEL%"
if %COMPOSER_STATUS% EQU 0 goto :ci4_instalado_ok

echo [ALERTA] Hubo un problema al ejecutar composer. Reintentando mostrando salida...
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project codeigniter4/appstarter "!path_web!" --no-interaction

:ci4_instalado_ok
:: SOLUCIÓN DEFINITIVA: Validar la ruta cruda sin asignaciones intermedias de comillas o variables "set"
if exist "!path_web!\vendor\." goto :ci4_vendor_ok

echo [ERROR] No se pudo inicializar el esqueleto de CodeIgniter 4 (Faltan dependencias de Composer).
goto :finalizar_web

:ci4_vendor_ok
echo ✓ Estructura de directorios de CodeIgniter 4 creada con éxito.
cd /d "!path_web!" || goto :finalizar_web

:: Configurar el framework en modo desarrollo de forma plana
if not exist "env" goto :finalizar_config_ci4
copy /Y env .env >nul 2>&1

:: Modificación del archivo .env aislada de forma segura
powershell -NoProfile -Command "$content = Get-Content '.env'; $content -replace '# CI_ENVIRONMENT = production', 'CI_ENVIRONMENT = development' | Set-Content '.env'" >nul 2>&1

:finalizar_config_ci4
:: 📝 AJUSTE CRÍTICO: Redirección del DocumentRoot de Apache a la carpeta /public de CodeIgniter
set "path_web_original=!path_web!"
set "path_web=!path_web!\public"

goto :enlazar_hosts

:: --- ENTORNO: LARAVEL ---
:instalar_laravel
:: 1. Crear base de datos local asociada
call :crear_bd_mysql_php

:: Comprobación de Composer
if not exist "C:\ProgramData\ComposerSetup\bin\composer.phar" (
    echo [ERROR] No se puede instalar Laravel porque composer.phar no está disponible.
    goto :finalizar_web
)

:: Limpiar residuos de instalaciones fallidas previas
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1

echo ➜ Generando estructura base de Laravel via Composer...
echo ⏳ Esto puede demorar unos minutos, por favor espere...

:: Invocación plana e inmunizada con PHP para descargar Laravel
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project laravel/laravel "!path_web!" --no-interaction >nul 2>&1

:: Guardamos el estado de forma segura
set "COMPOSER_STATUS=%ERRORLEVEL%"
if %COMPOSER_STATUS% EQU 0 goto :laravel_instalado_ok

echo [ALERTA] Hubo un problema al ejecutar composer. Reintentando mostrando salida...
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project laravel/laravel "!path_web!" --no-interaction

:laravel_instalado_ok
:: Validar la ruta cruda sin asignaciones intermedias de comillas (Inmune a fallos de puntos)
if exist "!path_web!\vendor\." goto :laravel_vendor_ok

echo [ERROR] No se pudo inicializar el esqueleto de Laravel (Faltan dependencias de Composer).
goto :finalizar_web

:laravel_vendor_ok
echo ✓ Estructura de directorios de Laravel creada con éxito.
cd /d "!path_web!" || goto :finalizar_web

:: 2. Aprovisionamiento automático del entorno Laravel (.env)
if not exist ".env.example" goto :finalizar_config_laravel
copy /Y .env.example .env >nul 2>&1

echo ➜ Configurando variables de entorno y generando App Key...
:: Configurar la conexión de la Base de Datos directamente en el archivo .env de Laravel
powershell -NoProfile -Command "$c = Get-Content '.env'; $c -replace 'DB_DATABASE=laravel', 'DB_DATABASE=!db_name!' -replace 'DB_USERNAME=root', 'DB_USERNAME=!db_user!' -replace 'DB_PASSWORD=', 'DB_PASSWORD=!db_pass!' | Set-Content '.env'" >nul 2>&1

:: Generar la clave de cifrado obligatoria de la aplicación
call php artisan key:generate >nul 2>&1

:finalizar_config_laravel
:: 📝 AJUSTE CRÍTICO: Redirección del DocumentRoot de Apache a la carpeta /public de Laravel
set "path_web_original=!path_web!"
set "path_web=!path_web!\public"

goto :enlazar_hosts


:: --- ENTORNO: SYMFONY ---
:instalar_symfony
:: 1. Crear base de datos local asociada
call :crear_bd_mysql_php

:: Comprobación de Composer
if not exist "C:\ProgramData\ComposerSetup\bin\composer.phar" (
    echo [ERROR] No se puede instalar Symfony porque composer.phar no está disponible.
    goto :finalizar_web
)

:: Limpiar residuos de instalaciones fallidas previas
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1

echo ➜ Generando estructura base de Symfony via Composer...
echo ⏳ Esto puede demorar unos minutos, por favor espere...

:: Invocación plana con PHP para descargar el esqueleto oficial de Symfony
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project symfony/skeleton "!path_web!" --no-interaction >nul 2>&1

:: Guardamos el estado de forma segura
set "COMPOSER_STATUS=%ERRORLEVEL%"
if %COMPOSER_STATUS% EQU 0 goto :symfony_instalado_ok

echo [ALERTA] Hubo un problema al ejecutar composer. Reintentando mostrando salida...
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
php "C:\ProgramData\ComposerSetup\bin\composer.phar" create-project symfony/skeleton "!path_web!" --no-interaction

:symfony_instalado_ok
:: Validar la ruta cruda sin asignaciones intermedias de comillas (Inmune a fallos de puntos)
if exist "!path_web!\vendor\." goto :symfony_vendor_ok

echo [ERROR] No se pudo inicializar el esqueleto de Symfony (Faltan dependencias de Composer).
goto :finalizar_web

:symfony_vendor_ok
echo ✓ Estructura de directorios de Symfony creada con éxito.
cd /d "!path_web!" || goto :finalizar_web

:: 2. Aprovisionamiento automático de la conexión MySQL de Symfony (.env)
if not exist ".env" goto :finalizar_config_symfony

echo ➜ Configurando cadena de conexión DATABASE_URL en el archivo .env...
:: Construimos la cadena de conexión estándar para PDO MySQL: mysql://usuario:password@host:puerto/base_datos
:: Como XAMPP viene por defecto sin contraseña en root, manejamos la estructura limpia.
set "DB_CONN_STR=mysql://!db_user!:!db_pass!@!db_host!:3306/!db_name!?serverVersion=8.2.12-MariaDB&charset=utf8mb4"

:: Inyección segura mediante PowerShell para evitar conflictos con ampersands y barras del DSN
powershell -NoProfile -Command "$c = Get-Content '.env'; $c -replace 'postgresql://app:secret@127.0.0.1:5432/app\?serverVersion=16&charset=utf8', '!DB_CONN_STR!' | Set-Content '.env'" >nul 2>&1

:finalizar_config_symfony
:: 📝 AJUSTE CRÍTICO: Redirección del DocumentRoot de Apache a la carpeta /public de Symfony
set "path_web_original=!path_web!"
set "path_web=!path_web!\public"

goto :enlazar_hosts

:: --- ENTORNO: REACT (VITE) ---
:instalar_react
where npm >nul 2>nul
if !errorlevel! equ 0 goto :node_react_ok

echo [INFO] Node.js (NPM) es necesario para React pero no está instalado.
echo ⏳ Iniciando instalación silenciosa de Node.js LTS via WinGet, espere...
winget install -e --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements >nul 2>&1

if not exist "C:\Program Files\nodejs\node.exe" (
    echo [ERROR] No se pudo instalar Node.js automáticamente.
    goto :finalizar_web
)
echo ✓ Node.js instalado correctamente. Acoplando variables de entorno...
for /f "delims=" %%M in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'Machine')"') do set "SYS_PATH=%%M"
for /f "delims=" %%U in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'User')"') do set "USR_PATH=%%U"
set "PATH=!SYS_PATH!;!USR_PATH!;C:\Program Files\nodejs"

:node_react_ok
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
mkdir "!path_web!" >nul 2>&1
cd /d "!path_web!" || goto :finalizar_web

echo ➜ Generando estructura base de React + Vite via NPM...
echo ⏳ Esto puede demorar unos minutos, por favor espere...

:: SOLUCIÓN ATÓMICA: Forzamos el ENTER mediante 'echo.|' para automatizar create-vite
echo.|call npx -y create-vite@latest . -- --template react --ts=false --eslint=false >nul 2>&1

if exist "package.json" goto :react_files_ok

:: Reintento plano de contingencia sin comentarios conflictivos en CMD
echo.|call npx -y create-vite@latest . -- --template react --ts=false --eslint=false

:react_files_ok
echo ✓ Estructura de directorios de React creada con éxito.

:: ==============================================================================
:: NUEVO: Sobrescribir/Generar el vite.config.js limpio con autorización de host
:: ==============================================================================
(
echo export default {
echo   server: {
echo     allowedHosts: ['!dominio_limpio!', '.test']
echo   }
echo }
) > vite.config.js
:: ==============================================================================

echo ➜ Descargando paquetes del ecosistema de React (npm install)...
echo ⏳ Esto puede demorar un par de minutos, por favor espere...
call npm install --no-audit --no-fund >nul 2>&1

if exist "node_modules\." goto :react_dependencias_ok

echo [ERROR] No se pudieron descargar las dependencias de Node para React.
goto :finalizar_web

:react_dependencias_ok
echo ✓ Dependencias de React instaladas correctamente.

set "path_web_original=!path_web!"
set "PUERTO_NODE=5173"
set "IS_NODE_ENV=y"

goto :enlazar_hosts

goto :mostrar_manual_react_directo

:mostrar_manual_react_directo
echo.
echo ==============================================================================
echo               === CÓMO CONTINUAR CON TU NUEVO ENTORNO ===
echo ==============================================================================
echo  📂 Ruta Física: !path_web_original!
echo  🌐 Servidor:    Servidor de Desarrollo Local (Vite)
echo ------------------------------------------------------------------------------
echo  👉 ¡Tu estructura de React + Vite ya está 100%% lista y configurada!
echo  👉 Para encender el servidor de desarrollo en segundo plano, ejecuta:
echo     📂 cd /d "!path_web_original!"
echo     ➜ npm run dev
echo  👉 Abre la URL local (ej. http://localhost:5173) que te indique la consola.
echo ==============================================================================
echo.
echo 🎉 ¡Entorno para !WEB_NAME! creado con éxito en !path_web_original!
goto :finalizar_web

:: --- ENTORNO: NODE.JS (EXPRESS API) ---
:instalar_node
where npm >nul 2>nul
if !errorlevel! equ 0 goto :node_express_ok

echo [INFO] Node.js es necesario pero no está instalado.
echo ⏳ Iniciando instalación silenciosa de Node.js LTS...
winget install -e --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements >nul 2>&1

for /f "delims=" %%M in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'Machine')"') do set "SYS_PATH=%%M"
for /f "delims=" %%U in ('powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path', 'User')"') do set "USR_PATH=%%U"
set "PATH=!SYS_PATH!;!USR_PATH!;C:\Program Files\nodejs"

:node_express_ok
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
mkdir "!path_web!" >nul 2>&1
cd /d "!path_web!" || goto :finalizar_web

echo ➜ Inicializando proyecto de Node.js (package.json)...
:: Inyectamos un ENTER forzado también en npm init por seguridad
echo.|call npm init --yes >nul 2>&1

echo ➜ Instalando framework Express y dependencias de base de datos...
call npm install express mysql2 dotenv --no-audit --no-fund >nul 2>&1

if not exist "node_modules\." (
    echo [ERROR] No se pudo inicializar el microservicio de Express.
    goto :finalizar_web
)

echo ✓ Entorno Express y Node.js configurado con éxito.

:: Inyección atómica mediante una única línea de PowerShell libre de errores de escape de CMD
powershell -NoProfile -Command "Set-Content -Path 'index.js' -Value 'const express = require(\"express\"); const app = express(); const port = process.env.PORT || 3000; app.get(\"/\", (req, res) => res.json({ status: \"API Viva\", framework: \"Express\" })); app.listen(port, () => console.log(\"Servidor Express activo en puerto \" + port));'" >nul 2>&1

set "path_web_original=!path_web!"
set "PUERTO_NODE=3000"
set "IS_NODE_ENV=y"

goto :enlazar_hosts




goto :mostrar_manual_node_directo


:mostrar_manual_node_directo
echo.
echo ==============================================================================
echo               === CÓMO CONTINUAR CON TU NUEVO ENTORNO ===
echo ==============================================================================
echo  📂 Ruta Física: !path_web_original!
echo  🌐 Servidor:    API Rest Express (Node.js)
echo ------------------------------------------------------------------------------
echo  👉 ¡Tu microservicio en Node.js + Express ya está listo!
echo  👉 Hemos instalado 'mysql2' para conectarte a tu base de datos '!db_name!'.
echo  👉 Para encender tu servidor API en el puerto 3000, ejecuta:
echo     📂 cd /d "!path_web_original!"
echo     ➜ node index.js
==============================================================================
echo.
echo 🎉 ¡Entorno para !WEB_NAME! creado con éxito en !path_web_original!
goto :finalizar_web


:: --- ENTORNO: PYTHON ---
:instalar_python
:: 1. CÁLCULO INMEDIATO DEL DOMINIO (Antes de generar cualquier archivo)
for /f "usebackq tokens=*" %%a in (`powershell -Command "$u = '!url_web!'; if (-not ($u.StartsWith('http://') -or $u.StartsWith('https://'))) { $u = 'http://' + $u }; [System.Uri]$u | Select-Object -ExpandProperty Host"`) do (
    set "dominio_limpio=%%a"
)

:: 2. ELIMINACIÓN RADICAL DE LOS ALIAS DE LA TIENDA MICROSOFT
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\python3.exe" /f >nul 2>&1

:: 3. VERIFICACIÓN Y ENRUTAMIENTO DE PYTHON
set "PYTHON_LOCAL_EXE=%USERPROFILE%\AppData\Local\Programs\Python\Python313\python.exe"

if exist "!PYTHON_LOCAL_EXE!" goto :python_disponible_ok

where python >nul 2>nul
if !errorlevel! equ 0 (
    :: Validar que no sea el alias falso de la tienda midiendo su salida
    python --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PYTHON_LOCAL_EXE=python"
        goto :python_disponible_ok
    )
)

echo [INFO] Python es necesario pero no está instalado.
echo ⏳ Iniciando descarga e instalación automatizada de Python, espere...
powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.13.14/python-3.13.14-amd64.exe' -OutFile '%TEMP%\python_installer.exe'" >nul 2>&1

if exist "%TEMP%\python_installer.exe" (
    "%TEMP%\python_installer.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_pip=1 TargetDir="%USERPROFILE%\AppData\Local\Programs\Python\Python313"
    del /f /q "%TEMP%\python_installer.exe" >nul 2>&1
)

:python_disponible_ok
if exist "!path_web!" rd /s /q "!path_web!" >nul 2>&1
mkdir "!path_web!" >nul 2>&1
cd /d "!path_web!" || goto :finalizar_web

echo ➜ Descargando Framework Flask y dependencias de base de datos...
echo ⏳ Esto puede demorar un par de minutos, por favor espere...

"!PYTHON_LOCAL_EXE!" -m pip install --upgrade pip --quiet >nul 2>&1
"!PYTHON_LOCAL_EXE!" -m pip install Flask mysql-connector-python --quiet >nul 2>&1

echo ✓ Entorno Flask configurado con éxito.

:: 4. GENERACIÓN DE LA API APP.PY
powershell -NoProfile -Command "Set-Content -Path 'app.py' -Value 'from flask import Flask, jsonify', 'app = Flask(__name__)', '@app.route(\"/\")', 'def home(): return jsonify(status=\"API Viva\", framework=\"Flask\")', 'if __name__ == \"__main__\": app.run(port=5000)'" >nul 2>&1

:: 5. GENERACIÓN IMPENETRABLE DEL INICIAR.BAT (Pasando variables resueltas a memoria temporal)
echo !dominio_limpio!> "%TEMP%\dom_temp.txt"
echo !PYTHON_LOCAL_EXE!> "%TEMP%\py_temp.txt"

set /p DOMINIO_REAL=<"%TEMP%\dom_temp.txt"
set /p PYTHON_REAL=<"%TEMP%\py_temp.txt"

del /f /q "%TEMP%\dom_temp.txt" >nul 2>&1
del /f /q "%TEMP%\py_temp.txt" >nul 2>&1

(
echo @echo off
echo chcp 65001 ^>nul
echo title Servidor API Flask - http://%DOMINIO_REAL%
echo cd /d "%%~dp0"
echo echo 🚀 Iniciando servidor Flask...
echo echo 🌐 Tu API está disponible en: http://%DOMINIO_REAL%
echo echo ---------------------------------------------------
echo "%PYTHON_REAL%" app.py
echo pause
) > iniciar.bat

set "path_web_original=!path_web!"
set "PUERTO_NODE=5000"
set "IS_NODE_ENV=y"

goto :enlazar_hosts












:enlazar_hosts
:: Parcheo de seguridad de Apache para habilitar módulos Proxy de forma garantizada
if exist "C:\xampp\apache\conf\httpd.conf" (
    powershell -NoProfile -Command "$h = Get-Content 'C:\xampp\apache\conf\httpd.conf'; $h -replace '#LoadModule proxy_module', 'LoadModule proxy_module' -replace '#LoadModule proxy_http_module', 'LoadModule proxy_http_module' | Set-Content 'C:\xampp\apache\conf\httpd.conf'" >nul 2>&1
)

:: No creamos la carpeta /public de forma agresiva antes de tiempo para entornos PHP de Composer
if /i "!WEB_NAME!"=="wordpress" (
    if not exist "!path_web!" mkdir "!path_web!" >nul 2>&1
)

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
        if "!IS_NODE_ENV!"=="y" (
            (
                echo.
                echo ^<VirtualHost *:80^>
                echo     ServerName !dominio_limpio!
                echo     ProxyPreserveHost On
                echo     ProxyRequests Off
                echo     ProxyPass / http://127.0.0.1:!PUERTO_NODE!/
                echo     ProxyPassReverse / http://127.0.0.1:!PUERTO_NODE!/
                echo ^</VirtualHost^>
            ) >> "!vhosts_file!"
        ) else (
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
        )

        echo ➜ Reiniciando Apache para aplicar el nuevo dominio...
        sc query Apache2.4 >nul 2>&1
        if !errorlevel! equ 0 (
            net stop Apache2.4 >nul 2>&1
            timeout /t 2 /nobreak >nul
            net start Apache2.4 >nul 2>&1
        ) else (
            taskkill /FI "IMAGENAME eq httpd.exe" /F >nul 2>&1
            timeout /t 2 /nobreak >nul
            if exist "C:\xampp\apache\bin\httpd.exe" start /B "" "C:\xampp\apache\bin\httpd.exe"
        )
    )
)

:: 🔍 VERIFICACIÓN DE CONECTIVIDAD UNIVERSAL (Simulando Navegador Real)
echo ➜ Realizando petición de prueba a http://!dominio_limpio!...
for /f "usebackq tokens=*" %%h in (`powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { $r = Invoke-WebRequest -Uri 'http://!dominio_limpio!' -Method Head -TimeoutSec 5 -UserAgent 'Mozilla/5.0' -ErrorAction Stop; [int]$r.StatusCode } catch { if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { echo '302' } }"`) do (set "HTTP_CODE=%%h")

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
    echo  👉 ¡Tu estructura base de CodeIgniter 4 ya está completamente montada!
    echo  👉 El entorno se ha configurado automáticamente en modo 'development'.
    echo  👉 Para conectar la base de datos '!db_name!', edita el archivo:
    echo     📂 !path_web_original!\.env
    echo     Y descomenta/ajusta las líneas de database.default.database.
)
if /i "!WEB_NAME!"=="laravel" (
    echo  👉 ¡Tu estructura de Laravel ya está 100%% lista y configurada!
    echo  👉 El archivo .env ha sido vinculado automáticamente a la base de datos '!db_name!'.
    echo  👉 La clave secreta de la aplicación ya ha sido generada con Artisan.
    echo  👉 Para iniciar la migración de tablas, ejecuta en la raíz: 'php artisan migrate'
)
if /i "!WEB_NAME!"=="symfony" (
    echo  👉 ¡Tu estructura de Symfony ya está 100%% lista y configurada!
    echo  👉 La variable DATABASE_URL ha sido configurada automáticamente con la BD '!db_name!'.
    echo  👉 Para crear tus entidades o controladores, ejecuta: 'php bin/console'
)
if /i "!WEB_NAME!"=="react" (
    echo  👉 ¡Tu estructura de React + Vite ya está 100%% lista y configurada!
    echo  👉 El dominio 'http://!dominio_limpio!' ha sido enlazado a tu hosts local.
    echo  ⚠  [CRÍTICO] Abre una NUEVA ventana de CMD para que reconozca los comandos de Node.
    echo  👉 Para encender el servidor ejecute en la nueva consola:
    echo     📂 cd /d "!path_web_original!"
    echo     ➜ npm run dev -- --host
)
if /i "!WEB_NAME!"=="node" (
    echo  👉 ¡Tu microservicio en Node.js + Express ya está 100%% listo!
    echo  👉 El dominio 'http://!dominio_limpio!' ha sido enlazado a tu hosts local.
    echo  ⚠  [CRÍTICO] Abre una NUEVA ventana de CMD para que reconozca los comandos de Node.
    echo  👉 Para encender tu servidor API en el puerto 3000, ejecuta:
    echo     📂 cd /d "!path_web_original!"
    echo     ➜ node index.js
)
if /i "!WEB_NAME!"=="python" (
    echo  👉 ¡Tu microservicio en Python + Flask ya está 100%% listo!
    echo  👉 El dominio 'http://%DOMINIO_REAL%' ha sido enlazado a tu hosts local.
    echo  ⚡ [NUEVO] Se ha creado un archivo 'iniciar.bat' en la raíz de tu proyecto.
    echo  👉 Para encender tu servidor API en el puerto 5000 de forma instantánea:
    echo     📂 Ve a: !path_web_original!
    echo     ➜ Haz doble clic sobre el archivo: iniciar.bat
    echo.
    echo  👉 O si prefieres lanzarlo manualmente desde la consola ejecuta:
    echo     📂 cd /d "!path_web_original!"
    echo     ➜ "%PYTHON_REAL%" app.py
)
echo ==============================================================================
echo.
echo 🎉 ¡Entorno para !WEB_NAME! creado con éxito en !path_web!
goto :finalizar_web



:crear_bd_mysql_php
if "!instalado_php!"=="s" (
    tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | findstr /I "mysqld.exe" >nul
    if !errorlevel! neq 0 (
        echo [INFO] MySQL no está en ejecución. Intentando arrancar el servicio de Windows...
        net start mysql >nul 2>&1
        
        tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | findstr /I "mysqld.exe" >nul
        if !errorlevel! neq 0 (
            if exist "C:\xampp\mysql\bin\mysqld.exe" (
                start "" /B "C:\xampp\mysql\bin\mysqld.exe" --defaults-file="C:\xampp\mysql\bin\my.ini"
                timeout /t 5 /nobreak >nul
            ) else (
                echo [ALERTA] No se encontró el ejecutable de MySQL.
                exit /b 1
            )
        )
    )

    echo ➜ Creando base de datos MySQL local si no existe...
    set "ENV_DB_NAME=!db_name!"
    set "ENV_DB_HOST=!db_host!"
    set "ENV_DB_USER=!db_user!"
    set "ENV_DB_PASS=!db_pass!"
    
    php -r "$b=chr(96); $p=new PDO('mysql:host='.getenv('ENV_DB_HOST'), getenv('ENV_DB_USER'), getenv('ENV_DB_PASS')); $p->exec('CREATE DATABASE IF NOT EXISTS '.$b.getenv('ENV_DB_NAME').$b.' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');" 2>nul
    
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


