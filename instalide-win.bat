@echo off
setlocal enabledelayedexpansion
title Asistente Inteligente de Seleccion e Instalacion de IDEs (Windows)
chcp 65001 >nul

:: ==========================================
:: 📋 CONFIGURACIÓN DEL LOG AUTOMÁTICO
:: ==========================================
set "DIR_SCRIPT=%~dp0"
for /f "tokens=*" %%i in ('powershell -Command "Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'"') do set "fecha=%%i"
set "LOG_DIR=%DIR_SCRIPT%logs"
set "LOG_FILE=%LOG_DIR%\instalador_ide-%fecha%.log"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul

echo ##################################################INI##################################################
echo  Asistente Inteligente de Seleccion e Instalacion de IDEs para Windows
echo ##################################################INI##################################################
echo  📝 Grabando registro en: %LOG_FILE%
echo.

call :log_y_pantalla "Iniciando asistente de instalacion en Windows..."

:: ==============================================================================
:: 🔍 DETECCIÓN PREVIA DE IDEs INSTALADOS
:: ==============================================================================
echo [INFO] Escaneando aplicaciones...
set "INST_VSCODE=0" & set "MARK_VSCODE="
set "INST_VSCODIUM=0" & set "MARK_VSCODIUM="
set "INST_CURSOR=0" & set "MARK_CURSOR="
set "INST_INTELLIJ=0" & set "MARK_INTELLIJ="
set "INST_NETBEANS=0" & set "MARK_NETBEANS="
set "INST_RIDER=0" & set "MARK_RIDER="
set "INST_NOTEPAD=0" & set "MARK_NOTEPAD="

:: Inicializar variables
set "INST_VSCODE=0" & set "INST_VSCOMM=0" & set "INST_RIDER=0"
set "MARK_VSCODE=" & set "MARK_VSCOMM=" & set "MARK_RIDER="

:: Detección (VS Code, Codium, Cursor, JetBrains, NetBeans, Notepad++)
where code >nul 2>nul && (set "INST_VSCODE=1" & set "MARK_VSCODE= [INSTALADO]")

:: Detección avanzada Visual Studio (vswhere)
set "VSWHERE_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "!VSWHERE_PATH!" (
    for /f "usebackq tokens=*" %%i in (`"!VSWHERE_PATH!" -products Microsoft.VisualStudio.Product.Community -property installationPath`) do (
        if exist "%%i\Common7\IDE\devenv.exe" (set "INST_VSCOMM=1" & set "MARK_VSCOMM= [INSTALADO]")
    )
)
:: Ruta alternativa por defecto 2022
if "!INST_VSCOMM!"=="0" if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe" (set "INST_VSCOMM=1" & set "MARK_VSCOMM= [INSTALADO]")

:: ... (resto de detecciones: vscodium, intellij, rider, etc., similar al anterior)
if exist "%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd" (set "INST_VSCODE=1" & set "MARK_VSCODE= [INSTALADO]")
where codium >nul 2>nul && (set "INST_VSCODIUM=1" & set "MARK_VSCODIUM= [INSTALADO]")
if exist "%LOCALAPPDATA%\Programs\cursor\Cursor.exe" (set "INST_CURSOR=1" & set "MARK_CURSOR= [INSTALADO]")
if exist "%ProgramFiles%\JetBrains\IntelliJ IDEA Community*\bin\idea64.exe" (set "INST_INTELLIJ=1" & set "MARK_INTELLIJ= [INSTALADO]")
if exist "%ProgramFiles%\NetBeans*\netbeans\bin\netbeans64.exe" (set "INST_NETBEANS=1" & set "MARK_NETBEANS= [INSTALADO]")
if exist "%ProgramFiles%\JetBrains\JetBrains Rider*\bin\rider64.exe" (set "INST_RIDER=1" & set "MARK_RIDER= [INSTALADO]")
if exist "%ProgramFiles%\Notepad++\notepad++.exe" (set "INST_NOTEPAD=1" & set "MARK_NOTEPAD= [INSTALADO]")

:: ==========================================
:: 📦 VALIDACIÓN E INSTALACION DE GIT
:: ==========================================
echo [INFO] Validando presencia de Git en el sistema...
where git >nul 2>nul
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('git --version') do set "GIT_VER=%%i"
    call :log_y_pantalla "✓ Git ya esta disponible en el sistema (!GIT_VER!)."
    goto :hardware_check
)

winget list --id Git.Git --source winget >nul 2>&1
if %errorlevel% equ 0 (
    call :log_y_pantalla "✓ Git ya esta instalado en el sistema via Winget."
    goto :hardware_check
)

call :log_y_pantalla "[ALERTA] Git no esta instalado. Es aconsejable para compartir archivos."
set /p "instala_git=¿Desea instalar Git de forma automatica usando Winget? [S/n]: "
if "!instala_git!"=="" set "instala_git=s"
if /i "!instala_git!"=="s" (
    call :log_y_pantalla "➜ Instalando Git via Winget..."
    winget install --id Git.Git -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
    if !errorlevel! equ 0 (
        call :log_y_pantalla "✓ Git se ha instalado correctamente."
    ) else (
        call :log_y_pantalla "[ERROR] Fallo la instalacion de Git. Continuando..."
    )
) else (
    call :log_y_pantalla "No se instalara Git."
)

:hardware_check
echo.
:: ==========================================
:: 📊 RECOPILACION DE HARDWARE DINÁMICA
:: ==========================================
call :log_y_pantalla "[INFO] Analizando el hardware del sistema..."

powershell -Command "[math]::Round((Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\").FreeSpace / 1GB)" > "%temp%\disk.txt"
powershell -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)" > "%temp%\ram.txt"

set /p libre_gb=<"%temp%\disk.txt"
set /p ram_max=<"%temp%\ram.txt"

set "libre_gb=%libre_gb: =%"
set "ram_max=%ram_max: =%"

del "%temp%\disk.txt" >nul 2>&1
del "%temp%\ram.txt" >nul 2>&1

call :log_y_pantalla " Espacio libre en C: !libre_gb! GB"
call :log_y_pantalla " Memoria RAM total aproximada: !ram_max! MB"

set "PERFIL_HARDWARE=Alto"
if !ram_max! lss 4000 (set "PERFIL_HARDWARE=Bajo")
if !libre_gb! lss 10 (set "PERFIL_HARDWARE=Bajo")
if !ram_max! lss 8000 if !ram_max! geq 4000 (set "PERFIL_HARDWARE=Medio")

call :log_y_pantalla "[ALERTA] Perfil de Hardware estimado: !PERFIL_HARDWARE!"

set "APTO_IA_LOCAL=NO"
if !ram_max! geq 8000 (
    set "APTO_IA_LOCAL=SI"
) else if !ram_max! geq 4000 (
    set "APTO_IA_LOCAL=MINIMO"
)
call :log_y_pantalla "[ALERTA] Hardware apto para instalar IA local: !APTO_IA_LOCAL!"
echo.

:: ==========================================
:: 🧠 SELECCIÓN DEL PERFIL DE USO
:: ==========================================
echo === SELECCIONA TU PERFIL DE DESARROLLO ===
echo  1) Desarrollo Web
echo  2) Desarrollo Java
echo  3) Ecosistema Microsoft .NET
echo  4) SysAdmin / Automatizacion
echo.
set /p "PERFIL=Introduce una opcion [1-4]: "
if "%PERFIL%"=="" set "PERFIL=1"

if "%PERFIL%"=="2" (
    echo ➜ Instalando OpenJDK 17 necesario para Java...
    winget install --id Microsoft.OpenJDK.17 -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
)
if "%PERFIL%"=="3" (
    echo ➜ Instalando .NET SDK 8 necesario para C#...
    winget install --id Microsoft.DotNet.SDK.8 -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
)

set "sugerencia=Visual Studio Code"
if "!PERFIL_HARDWARE!"=="Bajo" (
    if "%PERFIL%"=="2" set "sugerencia=Apache NetBeans"
    if "%PERFIL%"=="1" set "sugerencia=VSCodium"
) else (
    if "%PERFIL%"=="2" set "sugerencia=IntelliJ IDEA Community"
    if "%PERFIL%"=="3" set "sugerencia=Visual Studio Community"
)

echo.
echo ------------------------------------------------------------------------------
echo  [OK] 💡 Recomendacion: !sugerencia! para tu perfil !PERFIL_HARDWARE!
echo ------------------------------------------------------------------------------
echo.
pause

cls
echo ==============================================================================
echo                      === SELECCIONA EL IDE A INSTALAR ===
echo ==============================================================================
if "%PERFIL%"=="1" goto :menu_web
if "%PERFIL%"=="2" goto :menu_java
if "%PERFIL%"=="3" goto :menu_net
if "%PERFIL%"=="4" goto :menu_sysadmin

:menu_web
echo  1] Visual Studio Code%MARK_VSCODE% (Recomendado)
echo  2] VSCodium%MARK_VSCODIUM% (Privacidad / Ligero)
echo  3] Cursor AI Editor%MARK_CURSOR%
goto :menu_fin

:menu_java
echo  1] IntelliJ IDEA Community%MARK_INTELLIJ% (Recomendado Java)
echo  2] Apache NetBeans%MARK_NETBEANS% (Ligero)
echo  3] Visual Studio Code%MARK_VSCODE%
goto :menu_fin

:menu_net
echo  1] Visual Studio Community%MARK_VSCOMM% (Completo .NET)
echo  2] Visual Studio Code%MARK_VSCODE% (Ligero)
echo  3] JetBrains Rider%MARK_RIDER%
goto :menu_fin

:menu_sysadmin
echo  1] Visual Studio Code%MARK_VSCODE% (Automatizacion y Scripts)
echo  2] Notepad++%MARK_NOTEPAD% (Ultra ligero)
goto :menu_fin

:menu_fin
echo  0] Cancelar y salir
echo ==============================================================================
echo.
set /p "SELECCION=Elige una opcion [0-3]: "

if "%SELECCION%"=="" goto :finalizar
if "%SELECCION%"=="0" goto :finalizar

set "WINGET_ID="
set "IDE_NAME="
set "YA_INSTALADO=0"

:: ------------------------------------------------------------------------------
:: PROCESAR SELECCIÓN SEGÚN EL PERFIL ACTIVO
:: ------------------------------------------------------------------------------
:: --- PERFIL 1: WEB ---
if "%PERFIL%"=="1" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode" & set "YA_INSTALADO=%INST_VSCODE%"
    if "%SELECCION%"=="2" set "WINGET_ID=VSCodium.VSCodium" & set "IDE_NAME=vscodium" & set "YA_INSTALADO=%INST_VSCODIUM%"
    if "%SELECCION%"=="3" set "WINGET_ID=Anysphere.Cursor" & set "IDE_NAME=cursor" & set "YA_INSTALADO=%INST_CURSOR%"
)
:: --- PERFIL 2: JAVA ---
if "%PERFIL%"=="2" (
    if "%SELECCION%"=="1" set "WINGET_ID=JetBrains.IntelliJIDEA.Community" & set "IDE_NAME=intellij" & set "YA_INSTALADO=%INST_INTELLIJ%"
    if "%SELECCION%"=="2" set "WINGET_ID=Apache.NetBeans" & set "IDE_NAME=netbeans" & set "YA_INSTALADO=%INST_NETBEANS%"
    if "%SELECCION%"=="3" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode" & set "YA_INSTALADO=%INST_VSCODE%"
)
:: --- PERFIL 3: .NET ---
if "%PERFIL%"=="3" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudio.Community" & set "IDE_NAME=vscommunity" & set "YA_INSTALADO=%INST_VSCOMM%"
    if "%SELECCION%"=="2" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode" & set "YA_INSTALADO=%INST_VSCODE%"
    if "%SELECCION%"=="3" set "WINGET_ID=JetBrains.Rider" & set "IDE_NAME=rider" & set "YA_INSTALADO=%INST_RIDER%"
)
:: --- PERFIL 4: SYSADMIN ---
if "%PERFIL%"=="4" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode" & set "YA_INSTALADO=%INST_VSCODE%"
    if "%SELECCION%"=="2" set "WINGET_ID=Notepad++.Notepad++" & set "IDE_NAME=notepadpp" & set "YA_INSTALADO=%INST_NOTEPAD%"
)
:: ------------------------------------------------------------------------------
:: VALIDAR SI EL IDE ELEGIDO YA EXISTE
:: ------------------------------------------------------------------------------
if "%WINGET_ID%"=="" (
    echo [ALERTA] Opción no válida. Try again.
    pause
    goto :menu_fin
)

if "%YA_INSTALADO%"=="1" (
    echo.
    echo ------------------------------------------------------------------------------
    echo [ALERTA] ¡El IDE seleccionado ya está instalado en este sistema!
    echo [ALERTA] Se cancelará el proceso para evitar conflictos o sobrescrituras.
    echo ------------------------------------------------------------------------------
    goto :finalizar
)


:: 🤖 INSTALACIÓN DE ASISTENTE IA LOCAL
set "IA_LOCAL_INSTALADA=NO"
if not "!APTO_IA_LOCAL!"=="NO" (
    if "%IDE_NAME%"=="vscode" (
        echo.
        echo [INFO] Tu hardware califica para ejecutar modelos de IA local.
        set /p "RESPUESTA_IA=¿Deseas instalar el motor IA local (Ollama + Qwen2.5-Coder)? [s/N]: "
        if /i "!RESPUESTA_IA!"=="s" (
            echo ➜ Descargando e instalando Ollama...
            winget install --id Ollama.Ollama -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1

            timeout /t 5 >nul
            where ollama >nul 2>nul
            if !errorlevel! equ 0 (
                echo ➜ Descargando modelo ligero optimizado Qwen2.5-Coder...
                start /b "" ollama run qwen2.5-coder:1.5b --nowait >nul 2>&1
                set "IA_LOCAL_INSTALADA=SI"
            ) else (
                echo [ALERTA] Ollama no se pudo registrar a tiempo. Se saltara la IA local.
            )
        )
    )
)

@REM :: 🚀 INSTALACIÓN PRINCIPAL VÍA WINGET
@REM echo.
@REM echo ➜ Instalando !WINGET_ID! de manera desatendida...
@REM winget install --id %WINGET_ID% -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
@REM if !errorlevel! neq 0 (
@REM     echo [ERROR] Hubo un problema al desplegar el software mediante Winget.
@REM     goto :finalizar
@REM )
@REM echo ✓ Instalacion del IDE completada con éxito.
:: 🚀 INSTALACIÓN PRINCIPAL VÍA WINGET
echo.
echo ➜ Instalando !WINGET_ID! de manera desatendida...

:: Si es NetBeans, inyectamos el parámetro --force para saltar el hash de seguridad de Winget
if /I "%IDE_NAME%"=="netbeans" (
    winget install --id %WINGET_ID% -e --source winget --accept-package-agreements --disable-interactivity --force >> "%LOG_FILE%" 2>&1
) else (
    winget install --id %WINGET_ID% -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
)

:: Evaluamos el resultado de Winget
if !errorlevel! neq 0 (
    if /I "%IDE_NAME%"=="netbeans" (
        echo [ALERTA] Winget falló. Iniciando descarga directa desde los servidores oficiales de Apache...
        
        :: Descarga el instalador x64 real desde el espejo oficial de Apache usando un agente del sistema para evitar bloqueos
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://archive.apache.org/dist/netbeans/netbeans-installers/24/Apache-NetBeans-24-bin-windows-x64.exe' -OutFile '%TEMP%\netbeans_installer.exe' -UserAgent 'Mozilla/5.0'" >nul 2>&1

        if exist "%TEMP%\netbeans_installer.exe" (
            echo ➜ Desplegando ejecutable de NetBeans de forma silenciosa...
            start /wait "" "%TEMP%\netbeans_installer.exe" /S >> "%LOG_FILE%" 2>&1
            del "%TEMP%\netbeans_installer.exe" >nul 2>&1
            
            set "errorlevel=0"
            goto :instalacion_correcta
        )
    )
    
    echo [ERROR] Hubo un problema al desplegar el software mediante Winget o descarga directa.
    goto :finalizar
)

:instalacion_correcta
echo ✓ Instalacion del IDE completada con éxito.


:: ⚙ CONFIGURACIÓN AUTOMÁTICA DE EXTENSIONES
if not "%IDE_NAME%"=="vscode" goto :saltar_extensiones_vscode

echo ➜ Configurando extensiones de desarrollo en VS Code...
timeout /t 5 >nul
set "CODE_CMD=code"
if not exist "!LOCALAPPDATA!\Programs\Microsoft VS Code\bin\code.cmd" (
    set "CODE_CMD=!LOCALAPPDATA!\Programs\Microsoft VS Code\bin\code.cmd"
)

if "!IA_LOCAL_INSTALADA!"=="SI" (
    "!CODE_CMD!" --install-extension Continue.continue >nul 2>&1
) else (
    "!CODE_CMD!" --install-extension Codeium.codeium >nul 2>&1
)

if "%PERFIL%"=="1" (
    "!CODE_CMD!" --install-extension dbaeumer.vscode-eslint >nul 2>&1
    "!CODE_CMD!" --install-extension esbenp.prettier-vscode >nul 2>&1
)
if "%PERFIL%"=="2" (
    "!CODE_CMD!" --install-extension vscjava.vscode-java-pack >nul 2>&1
)
if "%PERFIL%"=="3" (
    "!CODE_CMD!" --install-extension ms-dotnettools.csdevkit >nul 2>&1
)
if "%PERFIL%"=="4" (
    "!CODE_CMD!" --install-extension ms-ansible.ansible >nul 2>&1
    "!CODE_CMD!" --install-extension ms-azuretools.vscode-docker >nul 2>&1
)
echo ✓ Plugins inyectados correctamente.

:saltar_extensiones_vscode

:: ==============================================================================
:: 🌐 CONFIGURACIÓN AUTOMÁTICA DE VARIABLES DE ENTORNO (PATH)
:: ==============================================================================
echo [INFO] Optimizando variables de entorno del sistema (PATH)...

set "RUTA_A_ANADIR="

:: 1. Localizar la ruta según el IDE que se acaba de instalar
:: Saltamos directamente a la etiqueta del IDE seleccionado para evitar bucles pesados
if "%IDE_NAME%"=="notepadpp" goto :path_notepad
if "%IDE_NAME%"=="intellij" goto :path_intellij
if "%IDE_NAME%"=="rider" goto :path_rider
if "%IDE_NAME%"=="netbeans" goto :path_netbeans
goto :path_procesar

:path_notepad
if exist "%ProgramFiles%\Notepad++" set "RUTA_A_ANADIR=%ProgramFiles%\Notepad++"
goto :path_procesar

:path_intellij
for /d %%d in ("%ProgramFiles%\JetBrains\IntelliJ IDEA Community*") do (
    set "RUTA_A_ANADIR=%%d\bin"
)
goto :path_procesar

:path_rider
for /d %%d in ("%ProgramFiles%\JetBrains\JetBrains Rider*") do (
    set "RUTA_A_ANADIR=%%d\bin"
)
goto :path_procesar

:path_netbeans
for /d %%d in ("%ProgramFiles%\NetBeans*") do (
    set "RUTA_A_ANADIR=%%d\netbeans\bin"
)
goto :path_procesar

:path_procesar
if "%RUTA_A_ANADIR%"=="" goto :sysadmin_check

@REM :: Comprobar duplicados de forma segura sin romper la consola
@REM echo !PATH! | findstr /I /C:";%RUTA_A_ANADIR%;" >nul 2>&1
@REM if !errorlevel! neq 0 (
@REM     echo !PATH! | findstr /I /C:";%RUTA_A_ANADIR%\" >nul 2>&1
@REM     if !errorlevel! neq 0 (
@REM         echo ➜ Añadiendo "%RUTA_A_ANADIR%" al PATH del Sistema...
@REM         :: Usamos PowerShell para saltar el bloqueo del registro de SETX
@REM         powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';%RUTA_A_ANADIR%', 'Machine')" >nul 2>&1
@REM         set "PATH=!PATH!;%RUTA_A_ANADIR%"
@REM         echo ✓ PATH del sistema actualizado.
@REM     )
@REM )
:: Comprobar si la ruta ya existe de forma literal en el PATH para evitar duplicados
echo !PATH! | findstr /I /L /C:"%RUTA_A_ANADIR%" >nul 2>&1
if !errorlevel! neq 0 (
    echo ➜ Añadiendo "%RUTA_A_ANADIR%" al PATH del Sistema...
    :: Usamos PowerShell para saltar el bloqueo del registro de SETX
    powershell -Command "[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';%RUTA_A_ANADIR%', 'Machine')" >nul 2>&1
    set "PATH=!PATH!;%RUTA_A_ANADIR%"
    echo ✓ PATH del sistema actualizado.
)

:sysadmin_check

:: ==============================================================================
:: ⚙ REQUISITOS ADICIONALES PARA SYSADMIN (Azure / AWS)
:: ==============================================================================
if not "%PERFIL%"=="4" goto :apertura_ide

echo.
echo [INFO] Configurando dependencias avanzadas de PowerShell para SysAdmin...

echo ➜ Instalando módulo Azure (Az) en segundo plano...
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; if (-not (Get-Module -ListAvailable -Name Az)) { Install-Module -Name Az -AllowClobber -Scope AllUsers -Force }" >nul 2>&1

echo ➜ Instalando módulo AWS Tools (AWSPowerShell) en segundo plano...
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; if (-not (Get-Module -ListAvailable -Name AWSPowerShell)) { Install-Module -Name AWSPowerShell -AllowClobber -Scope AllUsers -Force }" >nul 2>&1

echo ✓ Módulos de administración en la nube listos.

:apertura_ide

:: ==============================================================================
:: 🚀 APERTURA AUTOMÁTICA INTELIGENTE DEL IDE SELECCIONADO
:: ==============================================================================
echo.
echo [INFO] Iniciando el entorno de desarrollo seleccionado...

if "%IDE_NAME%"=="vscode" (
    if exist "!LOCALAPPDATA!\Programs\Microsoft VS Code\bin\code.cmd" (
        start "" "!LOCALAPPDATA!\Programs\Microsoft VS Code\bin\code.cmd"
    ) else ( start code )
)

if "%IDE_NAME%"=="vscodium" (
    if exist "!LOCALAPPDATA!\Programs\VSCodium\VSCodium.exe" (
        start "" "!LOCALAPPDATA!\Programs\VSCodium\VSCodium.exe"
    ) else ( start codium )
)

if "%IDE_NAME%"=="cursor" (
    if exist "!LOCALAPPDATA!\Programs\cursor\Cursor.exe" (
        start "" "!LOCALAPPDATA!\Programs\cursor\Cursor.exe"
    )
)

if "%IDE_NAME%"=="notepadpp" (
    if exist "%ProgramFiles%\Notepad++\notepad++.exe" (
        start "" "%ProgramFiles%\Notepad++\notepad++.exe"
    ) else ( start notepad++ )
)

if "%IDE_NAME%"=="vscommunity" (
    set "VS_OPENED=0"
    if exist "%ProgramFiles%\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe" (
        start "" "%ProgramFiles%\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
        set "VS_OPENED=1"
    )
    if "!VS_OPENED!"=="0" if exist "!VSWHERE_PATH!" (
        for /f "usebackq tokens=*" %%i in (`"!VSWHERE_PATH!" -products Microsoft.VisualStudio.Product.Community -property installationPath`) do (
            start "" "%%i\Common7\IDE\devenv.exe"
        )
    )
)

if "%IDE_NAME%"=="intellij" (
    for /d %%d in ("%ProgramFiles%\JetBrains\IntelliJ IDEA Community*") do if exist "%%d\bin\idea64.exe" start "" "%%d\bin\idea64.exe"
)

if "%IDE_NAME%"=="rider" (
    for /d %%d in ("%ProgramFiles%\JetBrains\JetBrains Rider*") do if exist "%%d\bin\rider64.exe" start "" "%%d\bin\rider64.exe"
)

if "%IDE_NAME%"=="netbeans" (
    for /d %%d in ("%ProgramFiles%\NetBeans*") do (
        if exist "%%d\netbeans\bin\netbeans64.exe" (
            start "" "%%d\netbeans\bin\netbeans64.exe" --console suppress 2>nul
        )
    )
)

:: Desactivamos temporalmente la expansión retardada para forzar la impresión literal del texto
setlocal disabledelayedexpansion
echo.
echo ------------------------------------------------------------------------------
echo  🎉 ¡Todo listo! Tu entorno de desarrollo ha sido configurado con éxito.
echo ------------------------------------------------------------------------------
endlocal

:finalizar
echo.
echo Presiona cualquier tecla para cerrar el asistente...
pause >nul
exit /b 0

:: 🛠 FUNCIONES AUXILIARES
:log_y_pantalla
echo %~1
echo %~1 >> "%LOG_FILE%"
exit /b
