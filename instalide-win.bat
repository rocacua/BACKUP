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
echo  1] Visual Studio Code (Recomendado)
echo  2] VSCodium (Privacidad / Ligero)
echo  3] Cursor AI Editor
goto :menu_fin

:menu_java
echo  1] IntelliJ IDEA Community (Recomendado Java)
echo  2] Apache NetBeans (Ligero)
echo  3] Visual Studio Code
goto :menu_fin

:menu_net
echo  1] Visual Studio Community (Completo .NET)
echo  2] Visual Studio Code (Ligero)
echo  3] JetBrains Rider
goto :menu_fin

:menu_sysadmin
echo  1] Visual Studio Code (Automatizacion y Scripts)
echo  2] Notepad++ (Ultra ligero)
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

if "%PERFIL%"=="1" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode"
    if "%SELECCION%"=="2" set "WINGET_ID=VSCodium.VSCodium" & set "IDE_NAME=vscodium"
    if "%SELECCION%"=="3" set "WINGET_ID=Anysphere.Cursor" & set "IDE_NAME=cursor"
)
if "%PERFIL%"=="2" (
    if "%SELECCION%"=="1" set "WINGET_ID=JetBrains.IntelliJIDEA.Community" & set "IDE_NAME=intellij"
    if "%SELECCION%"=="2" set "WINGET_ID=Apache.NetBeans" & set "IDE_NAME=netbeans"
    if "%SELECCION%"=="3" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode"
)
if "%PERFIL%"=="3" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudio.Community" & set "IDE_NAME=visualstudio"
    if "%SELECCION%"=="2" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode"
    if "%SELECCION%"=="3" set "WINGET_ID=JetBrains.Rider" & set "IDE_NAME=rider"
)
if "%PERFIL%"=="4" (
    if "%SELECCION%"=="1" set "WINGET_ID=Microsoft.VisualStudioCode" & set "IDE_NAME=vscode"
    if "%SELECCION%"=="2" set "WINGET_ID=Notepad++.Notepad++" & set "IDE_NAME=notepadpp"
)

if "%WINGET_ID%"=="" (
    echo [ERROR] Seleccion invalida.
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

:: 🚀 INSTALACIÓN PRINCIPAL VÍA WINGET
echo.
echo ➜ Instalando !WINGET_ID! de manera desatendida...
winget install --id %WINGET_ID% -e --source winget --accept-package-agreements --disable-interactivity >> "%LOG_FILE%" 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Hubo un problema al desplegar el software mediante Winget.
    goto :finalizar
)
echo ✓ Instalacion del IDE completada con esco.

:: ⚙ CONFIGURACIÓN AUTOMÁTICA DE EXTENSIONES
if "%IDE_NAME%"=="vscode" (
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
)

echo.
echo ------------------------------------------------------------------------------
echo  🎉 ¡Todo listo! Tu entorno de desarrollo ha sido configurado con exito.
echo ------------------------------------------------------------------------------

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
