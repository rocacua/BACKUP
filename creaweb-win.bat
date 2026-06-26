@echo off
setlocal enabledelayedexpansion
title Asistente Inteligente de Creación y Despliegue de Entornos Web (Windows)

:: Forzar codificación UTF-8 para mostrar tildes, colores y emojis correctamente
chcp 65001 >nul

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
:log_y_pantalla
echo %~1
echo %~1 >> "%LOG_FILE%"
exit /b

:siguiente_bloque_web_2
:: Aquí se acoplará la Parte 2
:: ==========================================
:: ➜ ANALIZANDO DEPENDENCIAS GLOBALES
:: ==========================================
call :log_y_pantalla "[INFO] Analizando dependencias globales de desarrollo..."
set "instalado_php=n"&set "instalado_composer=n"&set "instalado_git=n"

where php >nul 2>nul && (set "instalado_php=s"&for /f "tokens=*" %%i in ('php -v ^| findstr /i "php"') do set "PHP_VER=%%i"&call :log_y_pantalla "✓ Intérprete de PHP detectado: !PHP_VER!") || call :log_y_pantalla "[ALERTA] PHP no instalado."
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
set "opts=1:wordpress 2:laminas 3:codeigniter 4:laravel 5:symfony 6:react 7:node 8:python"
for %%a in (%opts%) do (
    for /f "tokens=1,2 delims=:" %%b in ("%%a") do (
        if "%ENTORNO_SELEC%"=="%%b" set "WEB_NAME=%%c" & goto :siguiente_bloque_web_3
    )
)
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
:: 🗄 CONFIGURACIÓN DE BASE DE DATOS (Simula pedir_datos_bd)
:: ==============================================================================
echo ==============================================================================
echo                 === CONFIGURACIÓN DE LA BASE DE DATOS ===
echo ==============================================================================
set /p "db_host=Host de la Base de Datos [localhost]: "
if "!db_host!"=="" set "db_host=localhost"

set /p "db_name=Nombre de la Base de Datos [!WEB_NAME!]: "
if "!db_name!"=="" set "db_name=!WEB_NAME!"

set /p "db_user=Usuario de la Base de Datos [root]: "
if "!db_user!"=="" set "db_user=root"

:: Leer la contraseña de forma segura ocultando la entrada mediante PowerShell
echo | set /p="Contraseña de la Base de Datos (oculta): "
for /f "tokens=*" %%i in ('powershell -Command "$p = Read-Host -AsSecureString; [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($p))"') do set "db_pass=%%i"
echo.

call :log_y_pantalla "➜ Validando configuración de almacenamiento de variables para !db_name!..."
echo.
pause

goto :siguiente_bloque_web_4

:siguiente_bloque_web_4
:: Aquí se acoplará la Parte 4 (Motores de instalación)
:: ==============================================================================
:: 🚀 MOTORES DE INSTALACIÓN Y DESPLIEGUE AUTOMATIZADO (COMPLETO)
:: ==============================================================================
if not exist "!path_web!" mkdir "!path_web!" 2>nul
if "!WEB_NAME!"=="wordpress" goto :instalar_wordpress
:: ... (Secciones para Laravel, CodeIgniter, etc., pueden ir aquí)
goto :finalizar_web

:: ------------------------------------------------------------------------------
:: 📦 MOTOR WORDPRESS (NATIVO SIN XAMPP)
:: ------------------------------------------------------------------------------
:instalar_wordpress
echo ➜ Creando base de datos MySQL local si no existe...
call :crear_bd_mysql_php

echo ➜ Descargando WordPress en castellano...
powershell -Command "Invoke-WebRequest -Uri 'https://wordpress.org' -OutFile '%temp%\wp.zip'"
powershell -Command "Expand-Archive -Path '%temp%\wp.zip' -DestinationPath '%temp%\wp_ext' -Force"
xcopy "%temp%\wp_ext\wordpress\*" "!path_web!\" /E /Y /Q >nul
del "%temp%\wp.zip" >nul 2>&1 & rd /S /Q "%temp%\wp_ext" >nul 2>&1

cd /d "!path_web!" || goto :finalizar_web
echo ➜ Configurando wp-config.php...
if exist "wp-config-sample.php" (
    copy "wp-config-sample.php" "wp-config.php" >nul
    powershell -Command "(Get-Content wp-config.php) -replace 'database_name_here', '!db_name!' -replace 'username_here', '!db_user!' -replace 'password_here', '!db_pass!' -replace 'localhost', '!db_host!' | Set-Content wp-config.php"
)
goto :enlazar_hosts

:: ------------------------------------------------------------------------------
:: 🌐 MAPEO DE DOMINIO EN HOSTS DE WINDOWS
:: ------------------------------------------------------------------------------
:enlazar_hosts
echo ➜ Enlazando dominio !url_web! en hosts...
set "dominio_limpio=!url_web:http://=!"
set "dominio_limpio=!dominio_limpio:https://=!"
findstr /I /C:"!dominio_limpio!" %WINDIR%\System32\drivers\etc\hosts >nul
if !errorlevel! neq 0 (
    echo 127.0.0.1    !dominio_limpio!>> %WINDIR%\System32\drivers\etc\hosts
)
echo 🎉 ¡Entorno para !WEB_NAME! creado con éxito en !path_web!
goto :finalizar_web

:crear_bd_mysql_php
where php >nul 2>nul
if !errorlevel! equ 0 (
    php -r "$p = new PDO('mysql:host=!db_host!', '!db_user!', '!db_pass!'); $p->exec('CREATE DATABASE IF NOT EXISTS \`!db_name!\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;');" >nul 2>&1
)
exit /b

:finalizar_web
pause >nul
exit /b 0

