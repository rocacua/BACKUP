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
    echo [ALERTA] Elevando consola de comandos para instalación.
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

::echo [1/3] Comprobando paquetes de software (Winget).
:: Fuerza la actualización del origen oficial limpio antes de instalar
:: Instalar FileZilla y XAMPP si no existen
::where filezilla >nul 2>&1 || winget install --id TimKosse.FileZilla.Client --silent --accept-source-agreements
::if not exist "%XAMPP_DIR%" (
::    echo [INFO] Descargando XAMPP.
::    winget install --id ApacheFriends.XAMPP.8.2 --silent --accept-source-agreements
::)






:: 1. Instalación corporativa limpia de FileZilla Client (Construcción dinámica de URL)
where filezilla >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Descargando e instalando FileZilla Client...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $p1='https://community.chocolatey.org'; $p2='/api/v2/package/filezilla/3.70.6'; $url=$p1+$p2; Invoke-WebRequest -Uri $url -OutFile '%TEMP%\filezilla.zip'; Expand-Archive -Path '%TEMP%\filezilla.zip' -DestinationPath '%TEMP%\fz_extracted' -Force; $setup = Get-ChildItem -Path '%TEMP%\fz_extracted' -Filter '*setup.exe' -Recurse | Select-Object -First 1; Start-Process -FilePath $setup.FullName -ArgumentList '/S' -Wait; Remove-Item '%TEMP%\filezilla.zip'; Remove-Item '%TEMP%\fz_extracted' -Recurse -Force"
)

:: 2. Instalación limpia de XAMPP
if exist "C:\xampp\apache\bin\httpd.exe" goto :siguiente_paso_amp

echo [INFO] Iniciando instalador oficial de XAMPP (ApacheFriends.Xampp)...
echo [ALERTA] Se abrirá una ventana flotante. Completa el asistente pulsando 'Next'.
winget install --id ApacheFriends.Xampp.8.2 -e --source winget --accept-package-agreements --accept-source-agreements

:: Pausa obligatoria para asegurar que el usuario complete el asistente gráfico
echo.
echo [INFO] Cuando el asistente de instalación de XAMPP haya FINALIZADO por completo,
set /p "READY=presiona ENTER en esta consola para configurar los VirtualHosts... "

:siguiente_paso_amp
echo ? Estructura base de XAMPP detectada. Continuando con la configuración de rutas...








:: 3. CONFIGURAR MYSQL Y PROYECTO
echo [2/3] Configurando base de datos y proyecto PHP.
if not exist "%DIR_PRUEBA%" mkdir "%DIR_PRUEBA%"
(
echo ^<?php
echo $pdo = new PDO^("mysql:host=localhost;charset=utf8mb4", "root", ""^);
echo $pdo-^>exec^("CREATE DATABASE IF NOT EXISTS prueba_db; CREATE TABLE IF NOT EXISTS prueba_db.mensajes (texto VARCHAR(255)); INSERT INTO prueba_db.mensajes VALUES ('Hola Mundo desde Windows');"^);
echo echo "Entorno Listo";
echo ?^>
) > "%DIR_PRUEBA%\index.php"


:: 4. VIRTUALHOST Y HOSTS
echo [3/3] Configurando VirtualHost en Apache.
set "VHOST_FILE=%XAMPP_DIR%\apache\conf\extra\httpd-vhosts.conf"

:: Usamos >> en todas las líneas para añadir al final del archivo sin borrarlo
echo.>> "%VHOST_FILE%"
echo ^<VirtualHost *:80^>>> "%VHOST_FILE%"
echo     ServerName prueba.test>> "%VHOST_FILE%"
echo     DocumentRoot "%DIR_PRUEBA%">> "%VHOST_FILE%"
echo     ^<Directory "%DIR_PRUEBA%"^>>> "%VHOST_FILE%"
echo         Options Indexes FollowSymLinks>> "%VHOST_FILE%"
echo         AllowOverride All>> "%VHOST_FILE%"
echo         Require all granted>> "%VHOST_FILE%"
echo     ^</Directory^>>> "%VHOST_FILE%"
echo ^</VirtualHost^>>> "%VHOST_FILE%"

findstr /i "prueba.test" "%HOSTS_FILE%" >nul 2>&1 || echo 127.0.0.1       prueba.test>> "%HOSTS_FILE%"

:: 5. INSTALAR Y ARRANCAR APACHE / MYSQL COMO SERVICIOS AUTOMÁTICOS
echo [INFO] Configurando arranque automático de los servidores...

:: Configuración de Apache
cd /d "%XAMPP_DIR%\apache\bin"
sc query Apache2.4 >nul 2>&1
if %errorlevel% neq 0 (
    httpd.exe -k install >nul 2>&1
)
sc config Apache2.4 start= auto >nul
net start Apache2.4 >nul 2>&1

:: Configuración de MySQL
cd /d "%XAMPP_DIR%\mysql\bin"
sc query mysql >nul 2>&1
if %errorlevel% neq 0 (
    mysqld.exe --install mysql >nul 2>&1
)
sc config mysql start= auto >nul
net start mysql >nul 2>&1

:: 6. PRUEBA DE CONEXIÓN CON PRUEBA.TEST
echo [INFO] Esperando a que los servicios respondan (máximo 15 segundos)...
set "ONLINE=0"

for /l %%i in (1,1,5) do (
    if !ONLINE!==0 (
        :: Intentamos hacer una petición HTTP silenciosa a la web de prueba
        powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://prueba.test' -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
        if !errorlevel! equ 0 (
            set "ONLINE=1"
        ) else (
            :: Si falla, esperamos 3 segundos antes de volver a intentar
            timeout /t 3 >nul
        )
    )
)

echo ==================================================
if !ONLINE!==1 (
    echo [OK] Entorno configurado: http://prueba.test
    echo [OK] Servidores funcionando en segundo plano de forma automática.
    echo [OK] ¡Prueba de conexión exitosa! Abriendo navegador...
    :: Abre la web automáticamente en el navegador por defecto
    start http://prueba.test
) else (
    echo [OK] Entorno configurado: http://prueba.test
    echo [OK] Servidores configurados de forma automática.
    echo [ALERTA] No se pudo verificar la respuesta web de inmediato. Revisa XAMPP.
)
echo ==================================================
pause
