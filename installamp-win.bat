@echo off
:: ==============================================================================
:: SCRIPT DE INSTALACIÓN Y APROVISIONAMIENTO ENTORNO DESARROLLO WINDOWS (XAMPP)
:: Basado en installamp.sh - Adaptado para Windows 11
:: ==============================================================================
CHCP 65001 >nul
setlocal enabledelayedexpansion

:: 1. DETECTAR RUTA DEL SCRIPT Y ELEVAR PRIVILEGIOS
set "DIR_SCRIPT=%~dp0"
set "DIR_SCRIPT=%DIR_SCRIPT:~0,-1%"
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ALERTA] Elevando consola de comandos para instalación...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%DIR_SCRIPT%"

:: 2. CONFIGURACIÓN DE RUTAS
set "XAMPP_DIR=C:\xampp"
set "HTDOCS_DIR=%XAMPP_DIR%\htdocs"
set "MYSQL_DIR=%XAMPP_DIR%\mysql"
set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "DIR_PRUEBA=%HTDOCS_DIR%\prueba"

echo [1/3] Comprobando paquetes de software (Winget)...
:: Instalar FileZilla y XAMPP si no existen
where filezilla >nul 2>&1 || winget install --id TimKosse.FileZilla.Client --silent --accept-source-agreements
if not exist "%XAMPP_DIR%" (
    echo [INFO] Descargando XAMPP...
    winget install --id ApacheFriends.XAMPP.8.2 --silent --accept-source-agreements
)

:: 3. CONFIGURAR MYSQL Y PROYECTO
echo [2/3] Configurando base de datos y proyecto PHP...
if not exist "%DIR_PRUEBA%" mkdir "%DIR_PRUEBA%"
(
echo ^<?php
echo $pdo = new PDO^('mysql:host=localhost;charset=utf8mb4', 'root', ''^);
echo $pdo-^>exec^('CREATE DATABASE IF NOT EXISTS prueba_db; CREATE TABLE IF NOT EXISTS prueba_db.mensajes ^(texto VARCHAR^(255^)^); INSERT INTO prueba_db.mensajes VALUES ^('Hola Mundo desde Windows'^);'^);
echo echo 'Entorno Listo';
echo ?^>
) > "%DIR_PRUEBA%\index.php"

:: 4. VIRTUALHOST Y HOSTS
echo [3/3] Configurando VirtualHost en Apache...
set "VHOST_FILE=%XAMPP_DIR%\apache\conf\extra\httpd-vhosts.conf"
echo ^<VirtualHost *:80^>> "%VHOST_FILE%"
echo     ServerName prueba.test>> "%VHOST_FILE%"
echo     DocumentRoot "%DIR_PRUEBA%">> "%VHOST_FILE%"
echo ^</VirtualHost^>> "%VHOST_FILE%"

findstr /i "prueba.test" "%HOSTS_FILE%" >nul 2>&1 || echo 127.0.0.1       prueba.test>> "%HOSTS_FILE%"

echo ==================================================
echo [OK] Entorno configurado: http://prueba.test
echo ==================================================
pause
