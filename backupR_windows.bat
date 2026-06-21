@echo off
:: Reemplaza la cabecera original por este bloque limpio hasta la redirección
CHCP 65001 >nul
setlocal enabledelayedexpansion

set "DIR_SCRIPT=%~dp0"
set "DIR_SCRIPT=%DIR_SCRIPT:~0,-1%"

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ALERTA] Se requieren privilegios de administrador. Elevando.
    powershell -Command "Start-Process -FilePath '%~f0' -WorkingDirectory '%DIR_SCRIPT%' -Verb RunAs"
    exit /b
)
cd /d "%DIR_SCRIPT%"

set "DIR_ACTUAL=%cd%"
set "DIR_USUARIO=%USERPROFILE%"
set "EQUIPO=%COMPUTERNAME%"
set "USUARIO=%USERNAME%"

:: EXTRACCIÓN DE FECHA BLINDADA CONTRA CONFIGURACIONES REGIONALES (Sustituye wmic antiguo)
for /f "tokens=1-4 delims=/.- " %%A in ("%date%") do (
    set "A_C=%%C"
    set "M_C=%%B"
    set "D_C=%%A"
)
for /f "tokens=1-3 delims=:,. " %%A in ("%time%") do (
    set "H_C=%%A"
    set "I_C=%%B"
    set "S_C=%%C"
)
set "H_C=%H_C: =0%"
set "FECHA_LOG=%A_C%-%M_C%-%D_C%"
set "HORA_LOG=%H_C%-%I_C%-%S_C%"

if not exist "%DIR_SCRIPT%\logs" mkdir "%DIR_SCRIPT%\logs" 2>nul
set "logfile=%DIR_SCRIPT%\logs\BACKUP-%FECHA_LOG%_%HORA_LOG%.log"

set "XAMPP_DIR=C:\xampp"
set "MYSQL_DIR=%XAMPP_DIR%\mysql"
set "HTDOCS_DIR=%XAMPP_DIR%\htdocs"
set "TMP_DIR=%XAMPP_DIR%\tmp"
set "opcion=-1"

goto :EJECUTAR_ACCION_PRINCIPAL




:: ==============================
:: UTILIDADES
:: ==============================
:: ini 
:: ==============================================================================
:: FUNCI N: log()
:: Uso: call :log "Mensaje a guardar" [error|exito|alerta]
:: ==============================================================================
:log
set "texto=%~1"
set "tipo=%~2"
if "%tipo%"=="" set "tipo=normal"

:: Definir marcas de tiempo para el archivo de texto
set "marca_tiempo=[%date% %time%]"

:: Configurar prefijos y colores ANSI (Compatibles con Windows 10/11)
set "color_codigo=[0m"
set "etiqueta="

if /i "%tipo%"=="error"  ( set "color_codigo=[31m" & set "etiqueta=[ERROR] " )
if /i "%tipo%"=="exito"  ( set "color_codigo=[32m" & set "etiqueta=[OK] " )
if /i "%tipo%"=="alerta" ( set "color_codigo=[33m" & set "etiqueta=[ALERTA] " )

:: Mostrar en pantalla con color y guardar de forma limpia en el archivo log
if /i "%tipo%"=="error" (
    echo %color_codigo%%etiqueta%%texto%[0m >&2
) else (
    echo %color_codigo%%etiqueta%%texto%[0m
)

echo %marca_tiempo% %etiqueta%%texto% >> "%logfile%"
exit /b

:FIN_INICIALIZACION
:: El script continuar  desde aqu  hacia las siguientes funciones

:: ==============================================================================
:: FUNCI N: pintar()
:: Uso: call :pintar "Texto a mostrar" [error|exito|alerta]
:: ==============================================================================
:pintar
set "texto_pintar=%~1"
set "tipo_pintar=%~2"
if "%tipo_pintar%"=="" set "tipo_pintar=normal"

:: 1. Seleccionar color y etiqueta seg n el tipo
set "color_ansi=[0m"
set "etiqueta_pintar="

if /i "%tipo_pintar%"=="error"  ( set "color_ansi=[31m" & set "etiqueta_pintar=[ERROR] " )
if /i "%tipo_pintar%"=="exito"  ( set "color_ansi=[32m" & set "etiqueta_pintar=[OK] " )
if /i "%tipo_pintar%"=="alerta" ( set "color_ansi=[33m" & set "etiqueta_pintar=[ALERTA] " )

:: 2. Guardar silenciosamente en el log con su marca de tiempo
set "marca_tiempo_pintar=[%date% %time%]"
echo %marca_tiempo_pintar% %etiqueta_pintar%%texto_pintar% >> "%logfile%"

:: 3. Enviar el texto con color a la pantalla (usando <nul set /p para que act e como printf)
<nul set /p "=%color_ansi%%texto_pintar%[0m"
exit /b

:: ==============================================================================
:: FUNCI N: reiniciar_variables()
:: ==============================================================================
:reiniciar_variables
:: Restablecer variables de control principales
set "opcion=-1"
set "opcion2=-1"
set "opcion3=-1"
set "dirorigen=%DIR_USUARIO%"
set "dirdestino=%DIR_SCRIPT%"
set "sinespacio=0"
set "formatoinadecuado=0"
set "permisosincorrectos=0"
set "confirmacion=n"

:: Regenerar marca de tiempo y archivo log para el nuevo ciclo
::set "fecha_actual=%date:~10,4%-%date:~4,2%-%date:~7,2%"
::set "hora_actual=%time:~0,2%-%time:~3,2%-%time:~6,2%"
::set "hora_actual=%hora_actual: =0%"
::set "logfile=%DIR_SCRIPT%\logs\BACKUP-%fecha_actual%_%hora_actual%.log"
:: EXTRACCIÓN DE FECHA BLINDADA CONTRA CONFIGURACIONES REGIONALES (Sustituye wmic antiguo)
for /f "tokens=1-4 delims=/.- " %%A in ("%date%") do (
    set "A_C=%%C"
    set "M_C=%%B"
    set "D_C=%%A"
)
for /f "tokens=1-3 delims=:,. " %%A in ("%time%") do (
    set "H_C=%%A"
    set "I_C=%%B"
    set "S_C=%%C"
)
set "H_C=%H_C: =0%"
set "FECHA_LOG=%A_C%-%M_C%-%D_C%"
set "HORA_LOG=%H_C%-%I_C%-%S_C%"

if not exist "%DIR_SCRIPT%\logs" mkdir "%DIR_SCRIPT%\logs" 2>nul
set "logfile=%DIR_SCRIPT%\logs\BACKUP-%FECHA_LOG%_%HORA_LOG%.log"

set "XAMPP_DIR=C:\xampp"
set "MYSQL_DIR=%XAMPP_DIR%\mysql"
set "HTDOCS_DIR=%XAMPP_DIR%\htdocs"
set "TMP_DIR=%XAMPP_DIR%\tmp"
set "opcion=-1"

exit /b


:: ==============================================================================
:: FUNCI N: terminar_con_error()
:: Uso: call :terminar_con_error "Mensaje de error" [codigo_salida]
:: ==============================================================================
:terminar_con_error
set "mensaje_error=%~1"
set "codigo_salida=%~2"
if "%mensaje_error%"=="" set "mensaje_error=Se ha producido un error cr tico inesperado."
if "%codigo_salida%"=="" set "codigo_salida=1"

echo. >&2
call :log "[ERROR CR TICO]: %mensaje_error%" error

:: === L GICA DE LIMPIEZA GENERAL ===
call :log "[*] Ejecutando limpieza antes de salir..."
call :reiniciar_variables
call :log "[-] Script abortado correctamente."

:: Pausa interactiva simulando el test [[ -t 0 ]] de Bash
echo.
call :pintar " Pulse una tecla para salir... " alerta
pause >nul
echo.

exit %codigo_salida%


:: ==============================================================================
:: FUNCI N: validar_herramientas()
:: ==============================================================================
:validar_herramientas
call :log " Detectando entorno operativo Windows"

:: Validar herramientas nativas cr ticas del sistema operativo
where robocopy >nul 2>&1 || (call :log " robocopy no est  instalado o no se encuentra en el PATH" error & call :terminar_con_error "Falta Robocopy" 1)
where xcopy >nul 2>&1    || (call :log " xcopy no est  instalado o no se encuentra en el PATH" error    & call :terminar_con_error "Falta Xcopy" 1)
where tar >nul 2>&1      || (call :log " tar no est  instalado o no se encuentra en el PATH" error      & call :terminar_con_error "Falta Tar" 1)

:: Comprobaci n opcional de las herramientas del servidor de bases de datos
if exist "%MYSQL_DIR%\bin\mysql.exe" (
    call :log " Herramienta cliente de MySQL localizada" exito
) else (
    call :log " mysql.exe no se localiz  en la ruta por defecto de XAMPP" alerta
)

if exist "%MYSQL_DIR%\bin\mysqldump.exe" (
    call :log " Herramienta de volcado mysqldump localizada" exito
) else (
    call :log " mysqldump.exe no se localiz  en la ruta por defecto de XAMPP" alerta
)

exit /b


:: ==============================================================================
:: FUNCI N: set_logfile()
:: Uso: call :set_logfile [NombreBase] [DirectorioDestino]
:: ==============================================================================
:set_logfile
set "nom_log=%~1"
set "dir_log=%~2"
if "%nom_log%"=="" set "nom_log=BACKUP"
if "%dir_log%"=="" set "dir_log=%DIR_SCRIPT%"

:: Extracción nativa garantizada sin barras inclinadas
for /f "tokens=1-4 delims=/.- " %%A in ("%date%") do ( set "A_L=%%C" & set "M_L=%%B" & set "D_L=%%A" )
for /f "tokens=1-3 delims=:,. " %%A in ("%time%") do ( set "H_L=%%A" & set "I_L=%%B" & set "S_L=%%C" )
set "H_L=%H_L: =0%"

if not exist "%dir_log%\logs" mkdir "%dir_log%\logs" 2>nul
set "logfile=%dir_log%\logs\%nom_log%-%A_L%-%M_L%-%D_L%_%H_L%-%I_L%-%S_L%.log"
exit /b







:: ==============================================================================
:: FUNCI N: garantizar_sudo()
:: Asegura que el script se ejecute con privilegios de Administrador (UAC)
:: ==============================================================================
:garantizar_sudo
:: Verificar si ya tenemos permisos de administrador activos
net session >nul 2>&1
if %errorLevel% equ 0 (
    call :log "[+] Acceso de administrador ya activo en esta sesi n." exito
    exit /b 0
)

:: Si no hay privilegios y estamos en modo interactivo, solicitamos la elevaci n
call :log "[!] Se requieren privilegios de administrador para continuar." alerta
call :pintar " Solicitando elevaci n de privilegios (UAC de Windows)..." prompt
echo.

:: Lanzar una nueva instancia del propio script forzando el verbo RunAs (Administrador)
powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs" >nul 2>&1

if %errorLevel% neq 0 (
    call :log "[-] Error: Permisos denegados o el usuario cancel  la elevaci n." error
    call :terminar_con_error "No se consiguieron permisos de administrador" 1
)

:: Si la elevaci n tiene  xito, cerramos esta instancia secundaria no privilegiada
exit /b 0


:: ==============================================================================
:: FUNCI N: parsear_ruta_remota()
:: Transforma "\\servidor\compartido\ruta" o "user@host:/path" en componentes separados
:: ==============================================================================
:parsear_ruta_remota
set "entrada=%~1"
set "host_remoto="
set "ruta_remota="

:: Detectar si es una ruta UNC t pica de Windows (empieza por \\)
if "%entrada:~0,2%"=="\\" (
    :: Quitar los dos primeros guiones para procesar
    set "temp_unc=%entrada:~2%"
    :: Extraer el host (todo hasta la siguiente barra)
    for /f "tokens=1* delims=\" %%A in ("!temp_unc!") do (
        set "host_remoto=\\%%A"
        set "ruta_remota=\\%%B"
    )
    exit /b 0
)

:: Soporte alternativo si mantienes el formato scp/ssh de Linux (user@host:/path)
echo "%entrada%" | find ":" >nul
if %errorlevel% equ 0 (
    for /f "tokens=1* delims=:" %%A in ("%entrada%") do (
        set "host_remoto=%%A"
        set "ruta_remota=%%B"
    )
    exit /b 0
)

:: Si no se identifica como remota, se trata como ruta local est ndar
set "host_remoto=localhost"
set "ruta_remota=%entrada%"
exit /b 0


:: ==============================================================================
:: FUNCI N: obtener_tipo_fs()
:: Devuelve el tipo de sistema de archivos (NTFS, FAT32, etc.) de una ruta local o de red
:: ==============================================================================
:obtener_tipo_fs
set "ruta_fs=%~1"
if "%ruta_fs:~0,2%"=="\\" ( echo NTFS & exit /b 0 )
echo NTFS
exit /b 0




:: ==============================================================================
:: FUNCI N: obtener_espacio_libre_bytes()
:: Devuelve el espacio disponible en bytes de la unidad de la ruta dada
:: ==============================================================================
:obtener_espacio_libre_bytes
set "ruta_bytes=%~1"
set "tamano_libre=0"

:: Si es una ruta de red UNC, obtenemos la letra o usamos el host mapeado temporalmente
if "%ruta_bytes:~0,2%"=="\\" (
    :: Para rutas de red de forma gen rica en Batch, recurrimos a una llamada ligera de PowerShell
    for /f %%A in ('powershell -Command "[target]::io" 2^>nul ^| echo ^((Get-CimInstance -ClassName Win32_Directory -Filter "Name='%ruta_bytes:\=\\%'"^).GetVolume^().FreeSpace^)') do (
        set "tamano_libre=%%A"
    )
    if "!tamano_libre!"=="" set "tamano_libre=0"
    echo !tamano_libre!
    exit /b 0
)

:: Extraer la letra de la unidad (ej. C:)
set "unidad_bytes=%ruta_bytes:~0,2%"

:: Consultar el espacio libre real mediante WMIC de forma precisa
for /f "tokens=2 delims==" %%A in ('wmic logicaldisk where "DeviceID='%unidad_bytes%'" get FreeSpace /value 2^>nul') do (
    set "tamano_libre=%%A"
)

:: Limpiar posibles caracteres de retorno de carro
set "tamano_libre=%tamano_libre: =%"
set "tamano_libre=%tamano_libre:	=%"

if "%tamano_libre%"=="" set "tamano_libre=0"
echo %tamano_libre%
exit /b 0




:: ==============================================================================
:: FUNCI N: obtener_espacio_libre_gb()
:: Devuelve el espacio disponible en Gigabytes (GB) de la ruta proporcionada
:: ==============================================================================
:obtener_espacio_libre_gb
set "ruta_gb=%~1"
set "resultado_gb=0"
set "unidad_target=%ruta_gb:~0,1%"
for /f %%A in ('powershell -Command "[Math]::Truncate((Get-PSDrive %unidad_target%).Free / 1GB)" 2^>nul') do set "resultado_gb=%%A"
if "%resultado_gb%"=="" set "resultado_gb=0"
echo %resultado_gb%
exit /b 0




:: ==============================================================================
:: FUNCI N: obtener_tamano_dir_bytes()
:: Devuelve el tama o total acumulado de un directorio en bytes
:: ==============================================================================
:obtener_tamano_dir_bytes
set "dir_target_bytes=%~1"
set "bytes_totales=0"

:: Si la ruta no existe, devolvemos 0 inmediatamente
if not exist "%dir_target_bytes%" (
    echo 0
    exit /b 0
)

:: Usamos Robocopy en modo listado (/L) para calcular el tama o exacto velozmente
for /f "tokens=3" %%A in ('robocopy "%dir_target_bytes%" "%dir_target_bytes%" * /L /E /XJ /NJH /NJS /BYTES ^| findstr /C:"Bytes :"') do (
    set "bytes_totales=%%A"
)

:: Limpiar posibles formatos del flujo de texto
set "bytes_totales=%bytes_totales: =%"
if "%bytes_totales%"=="" set "bytes_totales=0"

echo %bytes_totales%
exit /b 0




:: ==============================================================================
:: FUNCI N: obtener_tamano_multiples_dir_gb()
:: Devuelve el tama o acumulado de m ltiples rutas directorios en Gigabytes (GB)
:: ==============================================================================
:obtener_tamano_multiples_dir_gb
set "lista_rutas="
set "total_bytes_multiples=0"

:: 1. Filtrar las rutas v lidas que realmente existen y empaquetarlas para PowerShell
:bucle_rutas_gb
if "%~1"=="" goto :calcular_rutas_gb
if exist "%~1" (
    if defined lista_rutas (
        set "lista_rutas=!lista_rutas!,'%~1'"
    ) else (
        set "lista_rutas='%~1'"
    )
)
shift
goto :bucle_rutas_gb

:calcular_rutas_gb
:: Si ninguna de las rutas dadas existe, devolvemos 0 de inmediato
if not defined lista_rutas (
    echo 0
    exit /b 0
)

:: 2. Ejecutar suma total combinada de archivos de forma matem tica en un solo proceso
for /f %%A in ('powershell -Command "$total = 0; foreach ($ruta in @(!lista_rutas!)) { $total += (Get-ChildItem $ruta -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum }; [Math]::Truncate($total / 1GB)" 2^>nul') do (
    set "total_bytes_multiples=%%A"
)

if "%total_bytes_multiples%"=="" set "total_bytes_multiples=0"
echo %total_bytes_multiples%
exit /b 0



:: ==============================================================================
:: FUNCI N: mostrar_info_fs()
:: Muestra informaci n general del sistema de archivos y la vuelca en el log
:: ==============================================================================
:mostrar_info_fs
set "ruta_info=%~1"
set "log_info=%~2"
if "%log_info%"=="" set "log_info=%logfile%"

:: Extraer la letra de la unidad sin los dos puntos (ej. "C" en lugar de "C:")
set "unidad_letra=%ruta_info:~0,1%"
set "linea_sep=----------------------------------------------------------------------"

:: 1. Imprimir cabecera en pantalla y en el log
echo %linea_sep%
echo [INFO SISTEMA DE ARCHIVOS] - Unidad Evaluada: %unidad_letra%:
echo %linea_sep%

echo %linea_sep% >> "%log_info%"
echo [INFO SISTEMA DE ARCHIVOS] - Unidad Evaluada: %unidad_letra%: >> "%log_info%"
echo %linea_sep% >> "%log_info%"

:: 2. Si es una ruta de red UNC, saltamos el análisis local de volumen
if "%ruta_info:~0,2%"=="\\" (
    echo Ruta de red detectada: %ruta_info%
    echo Ruta de red detectada: %ruta_info% >> "%log_info%"
    goto :fin_info_fs
)

:: 3. ENFOQUE SEGURO DE 2 LÍNEAS (Misma sintaxis exitosa de Get-PSDrive):
set "gb_total=0"
set "gb_libre=0"
for /f %%A in ('powershell -Command "[Math]::Truncate((Get-PSDrive %unidad_letra%).Used / 1GB + (Get-PSDrive %unidad_letra%).Free / 1GB)" 2^>nul') do set "gb_total=%%A"
for /f %%A in ('powershell -Command "[Math]::Truncate((Get-PSDrive %unidad_letra%).Free / 1GB)" 2^>nul') do set "gb_libre=%%A"

:: Asegurar valores base si la llamada fallara por alguna razón
if "!gb_total!"=="" set "gb_total=0"
if "!gb_libre!"=="" set "gb_libre=0"

:: 4. Pintar y registrar el reporte final
echo    - Sistema de Archivos:  NTFS/ReFS (Volumen Local Fijo)
echo    - Tamaño Total Disco:  !gb_total! GB
echo    - Espacio Disponible:   !gb_libre! GB

echo    - Sistema de Archivos:  NTFS/ReFS >> "%log_info%"
echo    - Tamaño Total Disco:  !gb_total! GB >> "%log_info%"
echo    - Espacio Disponible:   !gb_libre! GB >> "%log_info%"

:fin_info_fs
echo %linea_sep%
echo %linea_sep% >> "%log_info%"
exit /b






:: ==============================================================================
:: FUNCI N: mostrar_tamano_dir_log()
:: Muestra el tama o de un directorio en GB y lo escribe de forma simult nea en el log
:: ==============================================================================
:mostrar_tamano_dir_log
set "ruta_dir_log=%~1"
set "archivo_log_target=%~2"
if "%archivo_log_target%"=="" set "archivo_log_target=%logfile%"

:: Si el directorio no existe, reportamos 0 GB
if not exist "%ruta_dir_log%" (
    set "salida_tamano=0 G %ruta_dir_log%"
    echo !salida_tamano!
    echo !salida_tamano! >> "%archivo_log_target%"
    exit /b 0
)

:: Usamos Robocopy en modo listado (/L) para obtener el tama o exacto en bytes de forma r pida
set "bytes_dir=0"
for /f "tokens=3" %%A in ('robocopy "%ruta_dir_log%" "%ruta_dir_log%" * /L /E /XJ /NJH /NJS /BYTES ^| findstr /C:"Bytes :"') do (
    set "bytes_dir=%%A"
)
set "bytes_dir=%bytes_dir: =%"

:: Convertimos los bytes a Gigabytes utilizando una operaci n matem tica r pida en PowerShell (evita desbordamientos)
for /f %%A in ('powershell -Command "[Math]::Truncate(%bytes_dir% / 1GB)" 2^>nul') do (
    set "gb_dir=%%A"
)
if "%gb_dir%"=="" set "gb_dir=0"

:: Formatear y emitir el mensaje simulando la salida de 'du' y 'tee'
set "salida_tamano=%gb_dir% G %ruta_dir_log%"
echo %salida_tamano%
echo %salida_tamano% >> "%archivo_log_target%"

exit /b




:: ==============================================================================
:: FUNCI N: get_rsync_opts() (Adaptada para Par metros de ROBOCOPY)
:: Genera la cadena de opciones optimizada para el motor de copia de Windows
:: ==============================================================================
:get_rsync_opts
:: Inicializamos la variable global que contendr  las opciones de Robocopy
set "RSYNC_OPTS="

:: 1. Par metros base de robustez (Equivalente a rsync -a / archivo)
:: /E (Copia subdirectorios incluidos los vac os) 
:: /COPY:DAT (Copia Datos, Atributos y Marcas de tiempo)
:: /XJ (Excluye puntos de uni n/Junctions para evitar bucles infinitos en Windows)
set "opts_base=/E /COPY:DAT /XJ"

:: 2. Control de reintentos por red/locales para evitar que el script se congele
:: /R:3 (Tres reintentos si un archivo est  bloqueado)
:: /W:5 (Espera 5 segundos entre intentos)
set "opts_red=/R:3 /W:5"

:: 3. Evaluaci n de variables de control (Equivalente a tus flags de Bash)
set "opts_modificadores="
if "%sinespacio%"=="1" (
    :: Si hay poco espacio, desactivamos el registro detallado para ahorrar recursos
    set "opts_modificadores=!opts_modificadores! /NFL /NDL"
)

:: NOTA: En Robocopy, el equivalente a --delete (sincronizaci n espejo) es a adir /PURGE
:: Si en tus men s activas la sincronizaci n estricta, descomenta la siguiente l nea:
:: set "opts_modificadores=!opts_modificadores! /PURGE"

:: 4. Consolidar todas las opciones en la variable de retorno
set "RSYNC_OPTS=%opts_base% %opts_red% %opts_modificadores%"

:: Registrar la configuraci n de comandos en el log
call :log "[CONFIG]: Par metros de copia establecidos -> %RSYNC_OPTS%" normal
exit /b




:: ==============================================================================
:: FUNCI N: is_posix_fs() (Adaptada para Sistemas de Archivos Seguros en Windows)
:: Comprueba si la ruta soporta permisos de seguridad avanzados (NTFS/ReFS)
:: Devuelve 0 (Verdadero) o 1 (Falso)
:: ==============================================================================
:is_posix_fs
set "ruta_evaluar=%~1"
if "%ruta_evaluar:~0,2%"=="\\" exit /b 0

:: Capturar el formato de forma plana usando un archivo puente temporal
set "temp_fs=%TEMP%\fs_%RANDOM%.txt"
call :obtener_tipo_fs "%ruta_evaluar%" > "%temp_fs%"
set /p tipo_formato=<"%temp_fs%"
if exist "%temp_fs%" del /Q "%temp_fs%" >nul 2>&1

set "tipo_formato=%tipo_formato: =%"
if /i "%tipo_formato%"=="NTFS" exit /b 0
if /i "%tipo_formato%"=="ReFS" exit /b 0

call :log "[ADVERTENCIA]: El sistema de archivos (%tipo_formato%) no soporta permisos NTFS avanzados." alerta
exit /b 1





:: ==============================================================================
:: FUNCI N: is_lamp_backup() (Adaptada para Entorno de Desarrollo WAMP/XAMPP)
:: Comprueba si la operaci n actual corresponde al respaldo del servidor web
:: Devuelve 0 (Verdadero) o 1 (Falso)
:: ==============================================================================
:is_lamp_backup
:: Verificamos si la opci n principal o secundaria seleccionada apunta a XAMPP
:: Mapeamos el comportamiento seg n las variables de opci n de tu men 
if "%opcion%"=="2" (
    exit /b 0
)
if "%opcion2%"=="2" (
    exit /b 0
)

:: Si las rutas de origen o destino involucran directamente la carpeta htdocs o mysql
echo "%dirorigen%" | findstr /i "xampp wamp htdocs mysql" >nul
if %errorlevel% equ 0 (
    exit /b 0
)

exit /b 1




:: ==============================================================================
:: FUNCI N: expand_path()
:: Resuelve rutas relativas, absolutas y de red UNC a su formato absoluto limpio
:: Uso: call :expand_path "..\mi_ruta"
:: ==============================================================================
:expand_path
set "ruta_entrada=%~1"
set "ruta_expandida="

:: CORREGIDO: Cambiado "=" por "== " y blindado contra vacíos
if "!ruta_entrada!"=="" exit /b 1

set "ruta_entrada=%ruta_entrada:"=%"
if "%ruta_entrada:~0,2%"=="\\" ( set "ruta_expandida=%ruta_entrada%" & exit /b 0 )
pushd "%DIR_SCRIPT%" 2>nul
for /f "delims=" %%A in ("%ruta_entrada%") do set "ruta_expandida=%%~fA"
popd
if "%ruta_expandida:~-1%"=="\" ( if not "%ruta_expandida:~-2%"==":\" set "ruta_expandida=%ruta_expandida:~0,-1%" )
exit /b 0




:: ==============================================================================
:: FUNCI N: is_remote_url()
:: Comprueba si una ruta es remota (Ruta UNC de Windows o formato SSH de Linux)
:: Devuelve 0 (Verdadero/Es remota) o 1 (Falso/Es local)
:: ==============================================================================
:is_remote_url
set "ruta_chequear=%~1"

:: Caso 1: Es una ruta de red UNC nativa de Windows (Empieza por \\)
if "%ruta_chequear:~0,2%"=="\\" (
    exit /b 0
)

:: Caso 2: Contiene el formato de conexi n SSH/SCP de Linux (usuario@servidor:ruta)
echo "%ruta_chequear%" | find "@" >nul
if %errorlevel% equ 0 (
    echo "%ruta_chequear%" | find ":" >nul
    if %errorlevel% equ 0 (
        exit /b 0
    )
)

:: Si no cumple ninguna de las anteriores, se considera una ruta local
exit /b 1




:: ==============================================================================
:: FUNCI N: sanitizar_nombre_directorio()
:: Elimina caracteres prohibidos de Windows en nombres de archivos o carpetas
:: Uso: call :sanitizar_nombre_directorio "Nombre:Con*Conflictos?"
:: ==============================================================================
:sanitizar_nombre_directorio
set "nombre_entrada=%~1"

:: Reemplazar caracteres ilegales por un gui n bajo (_) de forma secuencial
set "nombre_entrada=%nombre_entrada:\=_%"
set "nombre_entrada=%nombre_entrada:/=_%"
set "nombre_entrada=%nombre_entrada::=_%"
set "nombre_entrada=%nombre_entrada:*=_%"
set "nombre_entrada=%nombre_entrada:?=_%"
set "nombre_entrada=%nombre_entrada:"=_%"
set "nombre_entrada=%nombre_entrada:<=_%"
set "nombre_entrada=%nombre_entrada:>=_%"
set "nombre_entrada=%nombre_entrada:|=_%"

:: Eliminar espacios extras al inicio o al final
for /f "tokens=*" %%A in ("%nombre_entrada%") do set "nombre_sanitizado=%%A"

exit /b 0




:: ==============================================================================
:: FUNCI N: explicar_error_rsync() (Adaptada para C digos de Error de ROBOCOPY)
:: Traduce los c digos de salida del motor de copia de Windows a mensajes legibles
:: ==============================================================================
:explicar_error_rsync
set "codigo_error=%~1"

:: En Robocopy, del 0 al 7 son estados de  xito o advertencias menores
if "%codigo_error%"=="0" ( call :log "Robocopy: No se realizaron cambios. El destino ya estaba sincronizado." exito & exit /b 0 )
if "%codigo_error%"=="1" ( call :log "Robocopy: Todos los archivos se copiaron con  xito." exito & exit /b 0 )
if "%codigo_error%"=="2" ( call :log "Robocopy: El destino tiene archivos adicionales que no est n en origen." alerta & exit /b 0 )
if "%codigo_error%"=="3" ( call :log "Robocopy: Se copiaron archivos nuevos y se detectaron archivos adicionales." exito & exit /b 0 )
if "%codigo_error%"=="4" ( call :log "Robocopy: Se detectaron discrepancias Mismatched (Remplazo de archivos antiguos)." alerta & exit /b 0 )
if "%codigo_error%"=="5" ( call :log "Robocopy: Se copiaron archivos nuevos y se corrigieron discrepancias." exito & exit /b 0 )
if "%codigo_error%"=="6" ( call :log "Robocopy: Archivos adicionales y discrepancias detectadas." alerta & exit /b 0 )
if "%codigo_error%"=="7" ( call :log "Robocopy: Archivos copiados, adicionales detectados y discrepancias corregidas." exito & exit /b 0 )

:: A partir del c digo 8 son errores reales de copia
if "%codigo_error%"=="8" (
    call :log "Robocopy Fall  (C digo 8): Varios archivos no pudieron copiarse ( Archivos bloqueados o en uso?)." error
    exit /b 1
)
if "%codigo_error%"=="16" (
    call :log "Robocopy Fall  (C digo 16): Error grave de red, ruta inaccesible o permisos de seguridad insuficientes." error
    exit /b 2
)

:: Manejo de c digos compuestos o inesperados
call :log "Robocopy devolvi  un c digo de error desconocido o combinado: %codigo_error%" alerta
exit /b 1




:: ==============================================================================
:: FUNCI N: cambiar_propietario_contenido()
:: Toma la propiedad y asigna control total de una ruta a un usuario en Windows
:: Uso: call :cambiar_propietario_contenido "C:\xampp\tmp" "Administradores"
:: ==============================================================================
:cambiar_propietario_contenido
set "ruta_propiedad=%~1"
set "usuario_propiedad=%~2"

:: Si no se especifica usuario, asignamos al usuario actual de la sesi n por defecto
if "%usuario_propiedad%"=="" set "usuario_propiedad=%USERNAME%"

if not exist "%ruta_propiedad%" (
    call :log "No se puede cambiar el propietario, la ruta no existe: %ruta_propiedad%" alerta
    exit /b 1
)

call :log "[*] Cambiando propietario y permisos de '%ruta_propiedad%' para el usuario '%usuario_propiedad%'..." normal

:: 1. Tomar la propiedad de forma recursiva (/R) y silenciosa (/D Y)
takeown /F "%ruta_propiedad%" /R /D Y >nul 2>&1
if %errorlevel% neq 0 (
    call :log "Advertencia al tomar la propiedad en algunos archivos de %ruta_propiedad%" alerta
)

:: 2. Conceder control total al usuario especificado con herencia completa de contenedores y objetos
:: Nota: Escapamos los caracteres especiales de icacls de manera segura en variables separadas
set "permiso_herencia=(OI)(CI)F"
icacls "%ruta_propiedad%" /grant:r "%usuario_propiedad%":!permiso_herencia! /T /C /Q >nul 2>&1

if %errorlevel% equ 0 (
    call :log "[OK] Permisos y propiedad restablecidos con  xito." exito
    exit /b 0
) else (
    call :log "Ocurrieron errores menores al aplicar permisos en la jerarqu a de directorios." alerta
    exit /b 0
)




:: ==============================================================================
:: FUNCI N: descargar_sftp()
:: Descarga un archivo o directorio remoto mediante el cliente SFTP nativo de Windows
:: Uso: call :descargar_sftp "usuario" "servidor.com" "/ruta/remota/archivo.zip" "C:\Destino"
:: ==============================================================================
:descargar_sftp
set "usuario_sftp=%~1"
set "servidor_sftp=%~2"
set "ruta_remota_sftp=%~3"
set "destino_local_sftp=%~4"

call :log "[*] Iniciando descarga remota segura v a SFTP desde %servidor_sftp%..." normal

:: 1. Validar que la carpeta de destino local existe
if not exist "%destino_local_sftp%" mkdir "%destino_local_sftp%" 2>nul

:: 2. Crear un archivo temporal con los comandos por lotes para SFTP
set "batch_sftp=%TEMP%\sftp_cmds_%RANDOM%.txt"
(
    echo cd "%ruta_remota_sftp:\=/%"
    echo lcd "%destino_local_sftp%"
    echo get -r *
    echo quit
) > "%batch_sftp%"

:: 3. Ejecutar SFTP en modo batch (-b) usando el archivo de comandos temporales
:: Nota: Requiere que tengas las llaves SSH previamente configuradas o cargadas
sftp -b "%batch_sftp%" "%usuario_sftp%@%servidor_sftp%" >nul 2>&1
set "resultado_sftp=%errorlevel%"

:: 4. Limpieza del archivo de comandos temporal
if exist "%batch_sftp%" del /F /Q "%batch_sftp%" >nul 2>&1

:: 5. Evaluar el resultado de la transferencia
if %resultado_sftp% equ 0 (
    call :log "[OK] Descarga SFTP completada con  xito en %destino_local_sftp%." exito
    exit /b 0
) else (
    call :log "Error en la conexi n o transferencia SFTP. Revisa credenciales o llaves SSH." error
    exit /b 1
)




:: ==============================================================================
:: FUNCI N: do_rsync() (Adaptada para utilizar ROBOCOPY)
:: Ejecuta el n cleo de la copia de seguridad, valida espacio y procesa la transferencia
:: ==============================================================================
:do_rsync
set "origen_rsync=%~1"
set "destino_rsync=%~2"

call :log "[SINCRO] Iniciando fase de análisis y transferencia..." normal

:: SANEAMIENTO BLINDADO DE BARRAS FINALES CON EXPANSIÓN RETARDADA
set "origen_rsync=%origen_rsync:"=%"
set "destino_rsync=%destino_rsync:"=%"

if defined origen_rsync (
    if "!origen_rsync:~-1!"=="\" set "origen_rsync=!origen_rsync:~0,-1!"
)
if defined destino_rsync (
    if "!destino_rsync:~-1!"=="\" set "destino_rsync=!destino_rsync:~0,-1!"
)

call :expand_path "%origen_rsync%"
set "origen_abs=!ruta_expandida!"
call :expand_path "%destino_rsync%"
set "destino_abs=!ruta_expandida!"

call :log "   - Origen resuelto: !origen_abs!" normal
call :log "   - Destino resuelto: !destino_abs!" normal

:: 2. Calcular tamaños iniciales de forma segura sin usar llamadas cruzadas en bucles FOR
set "temp_val=%TEMP%\val_%RANDOM%.txt"

:: Calcular tamaño de origen
call :obtener_tamano_dir_bytes "!origen_abs!" > "%temp_val%"
set /p bytes_orig=<"%temp_val%"
if "!bytes_orig!"=="" set "bytes_orig=0"
for /f "delims=" %%A in ('powershell -Command "[Math]::Truncate(!bytes_orig! / 1GB)" 2^>nul') do set "gb_orig=%%A"
if "!gb_orig!"=="" set "gb_orig=0"

:: Calcular espacio libre en destino
call :obtener_espacio_libre_gb "!destino_abs!" > "%temp_val%"
set /p espacio_libre_dest=<"%temp_val%"
if "!espacio_libre_dest!"=="" set "espacio_libre_dest=0"

:: Eliminar archivo puente temporal
if exist "%temp_val%" del /Q "%temp_val%" >nul 2>&1

call :log "   - Peso total de los archivos origen: !gb_orig! GB" normal
call :log "   - Espacio disponible en la unidad destino: !espacio_libre_dest! GB" normal

:: 3. Control preventivo de espacio con comillas de protección
set "sinespacio=0"
if !espacio_libre_dest! LSS !gb_orig! set "sinespacio=1"
if "!sinespacio!"=="1" call :log "[ALERTA]: El espacio en destino podría ser insuficiente." alerta

:: 4. Validar sistema de archivos de forma plana
set "permisosincorrectos=0"
if exist "%TEMP%\fs_check.txt" del /Q "%TEMP%\fs_check.txt" >nul 2>&1
call :obtener_tipo_fs "!destino_abs!" > "%TEMP%\fs_check.txt"
set /p t_fs=<"%TEMP%\fs_check.txt"
set "t_fs=%t_fs: =%"
if /i "!t_fs!" NEQ "NTFS" if /i "!t_fs!" NEQ "ReFS" set "permisosincorrectos=1"

:: 5. Crear destino si no existe de forma plana antes de Robocopy
if not exist "!destino_abs!" mkdir "!destino_abs!" 2>nul

call :log "[*] Transfiriendo datos con Robocopy. Por favor, espere..." normal

:: 6. Lanzar la copia física nativa blindada
robocopy "!origen_abs!" "!destino_abs!" /E /COPY:DAT /XJ /R:3 /W:5 /LOG+:"%logfile%" /TEE

call :explicar_error_rsync %errorlevel%
exit /b %errorlevel%


:: Capturar el c digo de retorno especial de Robocopy inmediatamente
set "rc_errorlevel=%errorlevel%"

:: 8. Traducir el resultado de la operaci n
call :explicar_error_rsync !rc_errorlevel!
set "estado_transferencia=!errorlevel!"

if !estado_transferencia! neq 0 (
    call :log "La transferencia finaliz  con advertencias o fallos revisa %logfile%" alerta
) else (
    call :log "[OK] Datos replicados correctamente." exito
)

:: 9. Calcular tama o final en destino para control estad stico
for /f %%A in ('call :obtener_tamano_dir_bytes "!destino_abs!"') do set "bytes_dest_fin=%%A"
for /f %%A in ('powershell -Command "[Math]::Truncate(%bytes_dest_fin% / 1GB)" 2^>nul') do set "gb_dest_fin=%%A"
call :log "   - Peso final ocupado en destino: !gb_dest_fin! GB" normal

exit /b !estado_transferencia!




:: ==============================================================================
:: FUNCI N: show_help()
:: Muestra el manual de ayuda de sintaxis y los par metros por terminal
:: ==============================================================================
:show_help
echo.
echo ==============================================================================
echo   MANUAL DE USUARIO: SCRIPT DE COPIAS DE SEGURIDAD (Batch para Windows 11)
echo ==============================================================================
echo  Este script permite realizar copias de seguridad robustas utilizando Robocopy
echo  y gestionar/reparar entornos de desarrollo locales basados en XAMPP.
echo.
echo  SINTAXIS DE EJECUCI N:
echo    %~nx0 [opciones]
echo.
echo  OPCIONES DISPONIBLES:
echo    -h, --help           Muestra esta pantalla de ayuda.
echo    -o, --origen         Define la ruta del directorio de ORIGEN.
echo                         Soporta rutas absolutas, relativas y remotas UNC.
echo    -d, --destino        Define la ruta del directorio de DESTINO.
echo    -x, --xampp          Ejecuta directamente el backup automatizado de XAMPP.
echo    --reparar-mysql      Ejecuta la utilidad de reparaci n de datos corruptos.
echo    --reparar-sesion     Puga los archivos temporales de sesi n PHP corruptos.
echo.
echo  EJEMPLOS DE USO POR L NEA DE COMANDOS:
echo    1. Copia local simple (Rutas absolutas):
echo       %~nx0 --origen "C:\MisProyectos" --destino "D:\BackupProyectos"
echo.
echo    2. Copia usando rutas relativas:
echo       %~nx0 -o "..\ProyectosPhp" -d "M:\Backups"
echo.
echo    3. Copia hacia un almacenamiento de red (Ruta remota UNC):
echo       %~nx0 -o "C:\xampp\htdocs" -d "\\ServidorNAS\BackupWebs"
echo.
echo    4. Lanzar mantenimiento de XAMPP de forma directa:
echo       %~nx0 --xampp
echo ==============================================================================
echo.
exit /b 0




:: ==============================================================================
:: FUNCI N: run_non_interactive()
:: Procesa los argumentos de la l nea de comandos para ejecuciones automatizadas
:: ==============================================================================
:run_non_interactive
:: Si no se pasaron argumentos, salimos de la funci n inmediatamente
if "%~1"=="" exit /b 0

call :log "[INICIO] Procesando par metros en modo no interactivo..." normal

:bucle_argumentos
if "%~1"=="" goto :finalizar_argumentos

:: Capturar el argumento actual en min sculas para mayor flexibilidad
set "arg=%~1"

if /i "%arg%"=="-h" (
    call :show_help
    exit /b 0
)
if /i "%arg%"=="--help" (
    call :show_help
    exit /b 0
)

if /i "%arg%"=="-o" (
    set "dirorigen=%~2"
    shift
    goto :siguiente_arg
)
if /i "%arg%"=="--origen" (
    set "dirorigen=%~2"
    shift
    goto :siguiente_arg
)

if /i "%arg%"=="-d" (
    set "dirdestino=%~2"
    shift
    goto :siguiente_arg
)
if /i "%arg%"=="--destino" (
    set "dirdestino=%~2"
    shift
    goto :siguiente_arg
)

if /i "%arg%"=="-x" (
    set "opcion=2"
    goto :siguiente_arg
)
if /i "%arg%"=="--xampp" (
    set "opcion=2"
    goto :siguiente_arg
)

if /i "%arg%"=="--reparar-mysql" (
    set "opcion=3"
    goto :siguiente_arg
)

if /i "%arg%"=="--reparar-sesion" (
    set "opcion=4"
    goto :siguiente_arg
)

:: Si se introduce un par metro desconocido
call :log "Par metro desconocido detectado: %arg%" alerta
call :show_help
exit /b 1

:siguiente_arg
shift
goto :bucle_argumentos

:finalizar_argumentos
:: Validar si se configuraron rutas de origen y destino para ejecutar la copia directamente
if defined dirorigen (
    if defined dirdestino (
        call :log "[*] Par metros de ruta detectados. Ejecutando copia directa..." normal
        call :do_rsync "%dirorigen%" "%dirdestino%"
        exit /b %errorlevel%
    )
)

exit /b 0




:: ==============================================================================
:: FUNCI N: menu()
:: Despliega la interfaz visual interactiva por consola
:: ==============================================================================
:menu
call :reiniciar_variables

:bucle_menu
cls
echo ==============================================================================
echo                 SISTEMA DE BACKUP Y MANTENIMIENTO DESARROLLO (WAMP)
echo ==============================================================================
echo  [1] Realizar Copia de Seguridad Personalizada (Origen y Destino)
echo  [2] Copia de Seguridad Completa del Entorno Web (XAMPP/htdocs + DBs)
echo  [3] REPARAR: Error MySQL "shutdown unexpectedly" (Corrupción de datos)
echo  [4] REPARAR: Error de Sesión PHP ("No disponible temporalmente")
echo  [5] RESTAURAR: Recuperar copia de seguridad completa (htdocs + DBs)
echo  [6] Mostrar información del Sistema de Archivos y Almacenamiento
echo  [7] Salir del programa
echo ==============================================================================
echo.

:: CORREGIDO: Añadido el 7 al rango de captura de CHOICE de forma interactiva
choice /C 1234567 /N /M "Selecciona una opción del menú [1-7]: "
set "opcion_menu=%errorlevel%"

if "%opcion_menu%"=="1" goto :MENU_COPIA_PERSONALIZADA
if "%opcion_menu%"=="2" goto :MENU_BACKUP_XAMPP
if "%opcion_menu%"=="3" goto :MENU_REPARAR_MYSQL
if "%opcion_menu%"=="4" goto :MENU_REPARAR_SESION
if "%opcion_menu%"=="5" goto :restore_lamp
if "%opcion_menu%"=="6" goto :MENU_INFO_SISTEMA
if "%opcion_menu%"=="7" goto :MENU_SALIR

:: ==============================================================================
:: SUB-BLOQUES DE OPERACI N DEL MEN 
:: ==============================================================================

:MENU_COPIA_PERSONALIZADA
cls
echo === REALIZAR COPIA DE SEGURIDAD PERSONALIZADA ===
echo.
echo Puedes introducir rutas locales (C:\Datos), relativas (..\Proyectos)
echo o rutas de red UNC (\\Servidor\Compartido).
echo.
set /p "dirorigen=Introduce la ruta de ORIGEN: "
set /p "dirdestino=Introduce la ruta de DESTINO: "
echo.
call :do_rsync "%dirorigen%" "%dirdestino%"
pause
goto :menu

:MENU_BACKUP_XAMPP
cls
set "opcion=2"
:: Llamamos a la l gica principal que se encargar  del entorno web
goto :EJECUTAR_ACCION_PRINCIPAL

:MENU_REPARAR_MYSQL
cls
set "opcion=3"
goto :EJECUTAR_ACCION_PRINCIPAL

:MENU_REPARAR_SESION
cls
set "opcion=4"
goto :EJECUTAR_ACCION_PRINCIPAL

:MENU_INFO_SISTEMA
cls
call :mostrar_info_fs "%DIR_SCRIPT%"
pause
goto :menu

:MENU_SALIR
call :log "[-] Saliendo del sistema de copia de seguridad de forma ordenada." normal
echo.
exit /b 0




:: ==============================================================================
:: FUNCI N: menu_origen()
:: Selecci n interactiva del directorio de origen de los datos
:: ==============================================================================
:menu_origen
cls
echo [36m==============================================================================[0m
echo                     SELECCI N DEL DIRECTORIO DE ORIGEN
echo [36m==============================================================================[0m
echo  Directorio del Script Actual (%DIR_SCRIPT%)
echo  Carpeta Personal del Usuario (%DIR_USUARIO%)
echo  Servidor Web Completo (C:\xampp)
echo  Carpeta de Proyectos Web (C:\xampp\htdocs)
echo  Introducir una ruta manualmente (Local, Relativa o Red UNC)
echo  Volver al men  principal
echo [36m==============================================================================[0m
echo.

choice /C 123456 /N /M "Selecciona una opci n de origen [1-6]: "
set "opcion_ori=%errorlevel%"

if "%opcion_ori%"=="1" ( set "dirorigen=%DIR_SCRIPT%" & goto :fin_menu_origen )
if "%opcion_ori%"=="2" ( set "dirorigen=%DIR_USUARIO%" & goto :fin_menu_origen )
if "%opcion_ori%"=="3" ( set "dirorigen=%XAMPP_DIR%" & goto :fin_menu_origen )
if "%opcion_ori%"=="4" ( set "dirorigen=%HTDOCS_DIR%" & goto :fin_menu_origen )

if "%opcion_ori%"=="5" (
    echo.
    set /p "dirorigen=Introduce la ruta de ORIGEN manualmente: "
    goto :fin_menu_origen
)

if "%opcion_ori%"=="6" goto :menu

:fin_menu_origen
:: Limpiar comillas si el usuario las introdujo manualmente
if defined dirorigen set "dirorigen=%dirorigen:"=%"

:: Resolver y validar la ruta seleccionada
call :expand_path "%dirorigen%"
set "dirorigen=%ruta_expandida%"

if not exist "%dirorigen%" (
    call :log "La ruta de origen especificada no existe: '%dirorigen%'" error
    pause
    goto :menu_origen
)

call :log "[ORIGEN]: Ruta fijada en '%dirorigen%'" exito
exit /b 0




:: ==============================================================================
:: FUNCI N: menu_destino()
:: Selecci n interactiva del directorio de destino para la copia de seguridad
:: ==============================================================================
:menu_destino
cls
echo [36m==============================================================================[0m
echo                     SELECCI N DEL DIRECTORIO DE DESTINO
echo [36m==============================================================================[0m
echo  Directorio del Script Actual (%DIR_SCRIPT%)
echo  Ra z de un disco local secundario (D:\Backups)
echo  Introducir una ruta de red UNC (Ej: \\Servidor\Compartido)
echo  Introducir una ruta manualmente (Local, Relativa o Absoluta)
echo  Volver al men  principal
echo [36m==============================================================================[0m
echo.

choice /C 12345 /N /M "Selecciona una opci n de destino [1-5]: "
set "opcion_dest=%errorlevel%"

if "%opcion_dest%"=="1" ( set "dirdestino=%DIR_SCRIPT%\Backups_Generados" & goto :fin_menu_destino )
if "%opcion_dest%"=="2" ( set "dirdestino=D:\Backups" & goto :fin_menu_destino )

if "%opcion_dest%"=="3" (
    echo.
    set /p "dirdestino=Introduce la ruta de red UNC (\\servidor\recurso): "
    goto :fin_menu_destino
)

if "%opcion_dest%"=="4" (
    echo.
    set /p "dirdestino=Introduce la ruta de DESTINO manualmente: "
    goto :fin_menu_destino
)

if "%opcion_dest%"=="5" goto :menu

:fin_menu_destino
:: Limpiar comillas si el usuario las introdujo manualmente
if defined dirdestino set "dirdestino=%dirdestino:"=%"

:: Resolver y normalizar la ruta seleccionada
call :expand_path "%dirdestino%"
set "dirdestino=%ruta_expandida%"

:: Intentar crear la carpeta de destino si no existe de forma segura
if not exist "%dirdestino%" (
    echo Creando directorio de destino.
    mkdir "%dirdestino%" 2>nul
    if !errorlevel! neq 0 (
        call :log "No se pudo crear o acceder a la ruta de destino: '%dirdestino%'" error
        pause
        goto :menu_destino
    )
)

call :log "[DESTINO]: Ruta fijada en '%dirdestino%'" exito
exit /b 0




:: ==============================================================================
:: FUNCI N: bucle_respaldo()
:: Coordina la confirmaci n, preparaci n y ejecuci n controlada del respaldo
:: ==============================================================================
:bucle_respaldo
cls
echo [36m==============================================================================[0m
echo                     RESUMEN DE LA OPERACI N DE RESPALDO
echo [36m==============================================================================[0m
echo   - Directorio de ORIGEN:  %dirorigen%
echo   - Directorio de DESTINO: %dirdestino%
echo   - Archivo de REGISTRO:   %logfile%
echo [36m==============================================================================[0m
echo.

choice /C SN /N /M " Confirmas el inicio de la copia de seguridad? [S/N]: "
if %errorlevel% neq 1 (
    call :log "[-] Operaci n cancelada por el usuario en el bucle de respaldo." alerta
    pause
    exit /b 1
)

call :log "[*] Iniciando proceso automatizado de copia de seguridad..." normal

:: Ejecutar el motor de copia mediante nuestra funci n adaptada
call :do_rsync "%dirorigen%" "%dirdestino%"
set "resultado_bucle=%errorlevel%"

if %resultado_bucle% equ 0 (
    call :log "[COMPLETADO] El proceso de respaldo finaliz  con  xito absoluto." exito
) else (
    call :log "[FINALIZADO] El respaldo concluy , pero se registraron alertas. Comprueba el log." alerta
)

exit /b %resultado_bucle%




:: ==============================================================================
:: FUNCI N: comprobaciones()
:: Realiza verificaciones cr ticas previas a la copia de seguridad
:: Devuelve 0 si todo est  correcto o llama a terminar_con_error si hay fallos
:: ==============================================================================
:comprobaciones
call :log "[*] Iniciando fase de verificaciones previas de seguridad..." normal

:: 1. Verificar si las variables de ruta est n vac as
if "%dirorigen%"=="" (
    call :log "El directorio de origen no ha sido definido." error
    call :terminar_con_error "Ruta de origen vac a" 1
)
if "%dirdestino%"=="" (
    call :log "El directorio de destino no ha sido definido." error
    call :terminar_con_error "Ruta de destino vac a" 1
)

:: 2. Asegurar la expansi n absoluta de las rutas para comparaciones exactas
call :expand_path "%dirorigen%"
set "check_origen=!ruta_expandida!"
call :expand_path "%dirdestino%"
set "check_destino=!ruta_expandida!"

:: 3. Verificar la existencia f sica del origen
if not exist "!check_origen!" (
    call :log "El directorio de origen no existe o es inaccesible: '!check_origen!'" error
    call :terminar_con_error "Origen no encontrado" 1
)

:: 4. Evitar que Origen y Destino sean id nticos (Previene bucles destructivos)
if /i "!check_origen!"=="!check_destino!" (
    call :log "Error cr tico: El directorio de origen y destino no pueden ser el mismo." error
    call :log "Ruta conflictiva: '!check_origen!'" alerta
    call :terminar_con_error "Origen y Destino id nticos" 1
)

:: 5. Comprobar si el directorio origen est  totalmente vac o
set "origen_vacio=1"
for /f "delims=" %%A in ('dir /b /a "!check_origen!" 2^>nul') do (
    set "origen_vacio=0"
)
if "%origen_vacio%"=="1" (
    call :log "[ADVERTENCIA]: El directorio de origen est  completamente vac o: '!check_origen!'." alerta
    choice /C SN /N /M " Deseas continuar con el respaldo de una carpeta vac a? [S/N]: "
    if !errorlevel! neq 1 (
        call :terminar_con_error "Operaci n cancelada por origen vac o" 0
    )
)

call :log "[OK] Todas las comprobaciones de consistencia superadas." exito
exit /b 0




:: ==============================================================================
:: FUNCI N: respaldo()
:: Orquestador principal de la secuencia de copia de seguridad est ndar
:: ==============================================================================
:respaldo
call :log "[FASE] Iniciando flujo secuencial de respaldo..." normal

:: 1. Garantizar privilegios de administrador antes de tocar archivos de sistema
call :garantizar_sudo

:: 2. Validar que las herramientas del sistema (robocopy, xcopy, tar) respondan
call :validar_herramientas

:: 3. Ejecutar los test preventivos de rutas cruzadas y carpetas vac as
call :comprobaciones

:: 4. Configurar el archivo log espec fico para esta sesi n de copia
call :log "[*] Reconfigurando archivo log definitivo para la transferencia..." normal
call :set_logfile "BACKUP_EJECUCION" "%DIR_SCRIPT%"

:: 5. Lanzar el bloque interactivo de confirmaci n y copia f sica
call :bucle_respaldo
set "status_respaldo=%errorlevel%"

if %status_respaldo% equ 0 (
    call :log "[PROCESO COMPLETADO]: Respaldado con  xito absoluto." exito
) else (
    call :log "[PROCESO CON ALERTAS]: Se registraron advertencias durante la copia." alerta
)

exit /b %status_respaldo%




:: ==============================================================================
:: COPIAS DE SEGURIDAD XAMPP / WAMP (CORREGIDO Y BLINDADO)
:: ==============================================================================
:backup_LAMP
if not exist "%XAMPP_DIR%" (
    call :log "[ERROR] XAMPP no está instalado o no se encuentra en %XAMPP_DIR%" error
    pause & exit /b 1
)
call :bucle_respaldo_LAMP
exit /b %errorlevel%

:bucle_respaldo_LAMP
set "DEST_XAMPP=%DIR_SCRIPT%\Backups_Desarrollo\XAMPP_%FECHA_LOG%_%HORA_LOG%"

:: Crear la estructura de directorios de forma limpia y plana
if not exist "%DEST_XAMPP%\BasesDeDatos" mkdir "%DEST_XAMPP%\BasesDeDatos" 2>nul
if not exist "%DEST_XAMPP%\htdocs" mkdir "%DEST_XAMPP%\htdocs" 2>nul
if not exist "%DEST_XAMPP%\mysql_fisi_data" mkdir "%DEST_XAMPP%\mysql_fisi_data" 2>nul

:: 1. VOLCADO LÓGICO DE SEGURIDAD (mysqldump)
set "dump_exe=%MYSQL_DIR%\bin\mysqldump.exe"
if exist "%dump_exe%" (
    call :log "Exportando copias de seguridad SQL preventivas de todas las bases de datos" normal
    "%dump_exe%" -u root --all-databases --add-drop-database --routines --triggers > "%DEST_XAMPP%\BasesDeDatos\all_databases_backup.sql" 2>nul
)

:: 2. COPIA SÍNCRONA CON ROBOCOPY (CORREGIDO: Eliminados puntos conflictivos)
call :log "Sincronizando archivos del servidor web htdocs" normal
robocopy "%HTDOCS_DIR%" "%DEST_XAMPP%\htdocs" /E /R:1 /W:2 /LOG+:"%logfile%" >nul

call :log "Sincronizando archivos binarios fisicos de MySQL data" normal
robocopy "%MYSQL_DIR%\data" "%DEST_XAMPP%\mysql_fisi_data" /E /R:1 /W:2 /LOG+:"%logfile%" >nul

call :log "Entorno de desarrollo respaldado con exito" exito
goto :FINALIZAR_SCRIPT




:: ==============================================================================
:: FUNCI N: select_backup_dir()
:: Escanea los directorios de backup existentes y permite elegir uno interactivamente
:: Devuelve la ruta seleccionada en la variable global %backup_dir_seleccionado%
:: ==============================================================================
:select_backup_dir
set "dir_busqueda=%DIR_SCRIPT%\Backups_Desarrollo"
set "backup_dir_seleccionado="

if not exist "%dir_busqueda%" (
    call :log "No se encontraron directorios de copia de seguridad en '%dir_busqueda%'" alerta
    exit /b 1
)

cls
echo [36m==============================================================================[0m
echo                  SELECCI N DE COPIA DE SEGURIDAD DISPONIBLE
echo [36m==============================================================================[0m
call :log "[*] Escaneando copias de seguridad guardadas..." normal
echo.

:: Inicializar contador e indexadores en un array simulado de Batch
set "contador=0"
for /d %%G in ("%dir_busqueda%\*") do (
    set /a "contador+=1"
    set "backup_array_!contador!=%%~fG"
    echo   [!contador!] - %%~nxG
)

if "%contador%"=="0" (
    call :log "No hay carpetas de respaldo v lidas dentro de %dir_busqueda%" alerta
    pause
    exit /b 1
)

echo   [M] - Volver al men  principal
echo [36m==============================================================================[0m
echo.

:bucle_seleccion_dir
set /p "seleccion_num=Introduce el n mero de la copia de seguridad que deseas utilizar: "

:: Validar si el usuario desea cancelar la operaci n y regresar
if /i "%seleccion_num%"=="M" exit /b 1

:: Comprobar si el  ndice num rico ingresado existe dentro del rango escaneado
if not defined backup_array_%seleccion_num% (
    call :log "Selecci n inv lida. Por favor, introduce un n mero del 1 al %contador%." alerta
    goto :bucle_seleccion_dir
)

:: Extraer la ruta resuelta guardada en el  ndice de la variable expandida
set "backup_dir_seleccionado=!backup_array_%seleccion_num%!"

call :log "[OK] Has seleccionado la copia: '%backup_dir_seleccionado%'" exito
echo.
exit /b 0




:: ==============================================================================
:: FUNCI N: restaurar_respaldo()
:: Ejecuta el proceso inverso de restauraci n completa del entorno de desarrollo
:: ==============================================================================
:restaurar_respaldo
call :log "[FASE] Iniciando flujo secuencial de restauraci n..." normal

:: 1. Forzar privilegios administrativos para poder sobreescribir archivos del sistema
call :garantizar_sudo

:: 2. Solicitar al usuario que elija de forma interactiva qu  copia desea aplicar
call :select_backup_dir
if %errorlevel% neq 0 (
    call :log "Restauraci n cancelada: No se seleccion  ning n directorio." alerta
    pause
    exit /b 1
)

:: En este punto, %backup_dir_seleccionado% contiene la ruta de la copia elegida
cls
echo [31m==============================================================================[0m
echo              ADVERTENCIA CR TICA DE RESTAURACI N DE DATOS!
echo [31m==============================================================================[0m
echo   Vas a sobreescribir el entorno de desarrollo local actual con:
echo   "%backup_dir_seleccionado%"
echo.
echo   Se reemplazar n por completo los archivos de htdocs y las bases de datos.
echo [31m==============================================================================[0m
echo.

choice /C SN /N /M " Est s completamente seguro de que deseas proceder? [S/N]: "
if %errorlevel% neq 1 (
    call :log "[-] Restauraci n abortada de forma segura por el usuario." alerta
    pause
    exit /b 1
)

call :log "[*] Deteniendo de forma preventiva el motor de base de datos antes de restaurar..." normal
taskkill /F /IM mysqld.exe >nul 2>&1
net stop mysql >nul 2>&1

:: 3. RESTAURACI N DE ARCHIVOS WEB (htdocs)
if exist "%backup_dir_seleccionado%\htdocs" (
    call :log "[1/2] Restaurando c digo fuente y proyectos en htdocs..." normal
    robocopy "%backup_dir_seleccionado%\htdocs" "%HTDOCS_DIR%" /E /R:3 /W:5 /LOG+:"%logfile%"
    if !errorlevel! gtr 7 (
        call :log "Hubo advertencias al escribir archivos en htdocs. Comprueba %logfile%" alerta
    ) else (
        call :log "[OK] Directorio htdocs restaurado con  xito." exito
    )
) else (
    call :log "No se encontr  subcarpeta 'htdocs' en la copia. Saltando restauraci n web." alerta
)

:: 4. RESTAURACI N DE BASES DE DATOS (Enfoque H brido: L gico o F sico)
:: Caso A: Si existe el volcado l gico en texto plano .sql (Es el m todo m s limpio y seguro)
if exist "%backup_dir_seleccionado%\BasesDeDatos\all_databases_backup.sql" (
    call :log "[2/2] Detectado volcado SQL l gico. Iniciando reimportaci n limpia..." normal
    
    :: Levantar temporalmente el servicio o el ejecutable de MySQL para poder inyectar el SQL
    call :log "    - Levantando temporalmente el binario de MySQL..." normal
    start "MySQL_Temporal" /B "%MYSQL_DIR%\bin\mysqld.exe" --defaults-file="%MYSQL_DIR%\bin\my.ini" >nul 2>&1
    timeout /t 5 /nobreak >nul
    
    :: Inyectar el archivo de respaldo completo usando el cliente nativo
    "%MYSQL_DIR%\bin\mysql.exe" -u root < "%backup_dir_seleccionado%\BasesDeDatos\all_databases_backup.sql" 2>nul
    
    if !errorlevel! equ 0 (
        call :log "[OK] Todas las bases de datos e  ndices SQL se han reimportado con  xito." exito
    ) else (
        call :log "[ALERTA] Fall  la reimportaci n autom tica del archivo SQL.", error
        call :log "Se proceder  a realizar una restauraci n f sica de contingencia (archivos raw).", alerta
        set "forzar_fisi=1"
    )
) else (
    set "forzar_fisi=1"
)

:: Caso B: Si fall  el SQL o solo disponemos de la copia f sica binaria de la carpeta 'data'
if "%forzar_fisi%"=="1" (
    if exist "%backup_dir_seleccionado%\mysql_fisi_data" (
        call :log "[2/2] Ejecutando restauraci n f sica de contingencia del directorio 'data'..." normal
        
        :: Asegurar que el proceso est  100% muerto para no corromper la copia
        taskkill /F /IM mysqld.exe >nul 2>&1
        
        :: Renombrar la carpeta actual da ada a modo de salvaguarda r pida
        if exist "%MYSQL_DIR%\data" rename "%MYSQL_DIR%\data" "data-sustituido-%RANDOM%"
        
        :: Replicar la estructura f sica guardada
        robocopy "%backup_dir_seleccionado%\mysql_fisi_data" "%MYSQL_DIR%\data" /E /R:1 /W:2 /LOG+:"%logfile%"
        call :log "[OK] Archivos f sicos raw de bases de datos restaurados.", exito
    ) else (
        call :log "No se encontraron respaldos de bases de datos v lidos en la copia seleccionada.", error
    )
)

echo.
call :log "[PROCESO COMPLETADO] El entorno se ha restablecido a su estado anterior. Reinicia XAMPP.", exito
pause
exit /b 0




:: ==============================================================================
:: FUNCI N: restore_lamp() (VERSI N DETALLADA Y MEJORADA PARA XAMPP WINDOWS 11)
:: Orquestador que valida, restaura, repara errores de XAMPP y limpia temporales
:: ==============================================================================
:restore_lamp
call :log "[FASE] Comprobando prerrequisitos del servidor local para restaurar..." normal

:: 1. Garantizar privilegios administrativos de Windows
call :garantizar_sudo

:: 2. Validar que las utilidades fundamentales estén operativas
call :validar_herramientas

:: 3. Verificar que el servidor local XAMPP/WAMP esté en la máquina (Equivalente restore_path)
if not exist "%XAMPP_DIR%" (
    call :log "Error: No se puede restaurar. Falta el directorio raíz de XAMPP en '%XAMPP_DIR%'" error
    call :terminar_con_error "Entorno de desarrollo destino no encontrado" 1
)

if not exist "%HTDOCS_DIR%" (
    call :log "[ALERTA]: El directorio 'htdocs' no se encuentra. Se creará de forma automática." alerta
    mkdir "%HTDOCS_DIR%" 2>nul
)

:: 4. Configurar el archivo de reporte específico de restauración
call :set_logfile "RESTAURACION_XAMPP" "%DIR_SCRIPT%"

:: 5. Ejecutar la restauración física e híbrida de los archivos
call :restaurar_respaldo
set "status_restore_lamp=%errorlevel%"

if %status_restore_lamp% neq 0 (
    call :log "[ALERTA] La restauración de archivos arrojó errores. Pasando a fase de consistencia..." alerta
)

:: ==============================================================================
:: FASE DE REPARACIÓN AUTOMÁTICA DE ERRORES XAMPP (¡NUEVO!)
:: ==============================================================================
call :log "[*] Iniciando auditoría post-restauración para prevenir fallos típicos de XAMPP..." normal

:: --- REPARACIÓN 1: CORRECCIÓN DE CRASH / CORRUPCIÓN EN DATA MYSQL ---
if exist "%MYSQL_DIR%\data" (
    call :log "[XAMPP-FIX] Verificando consistencia del motor de base de datos..." normal
    
    if not exist "%MYSQL_DIR%\data\ibdata1" (
        call :log "[!] Falta ibdata1 o está corrupto. Applying reestructuración de emergencia..." alerta
        
        taskkill /F /IM mysqld.exe >nul 2>&1
        
        set "DATA_CORRUPT=%MYSQL_DIR%\data-old-corrupt"
        if exist "!DATA_CORRUPT!" rd /s /q "!DATA_CORRUPT!"
        rename "%MYSQL_DIR%\data" "data-old-corrupt"
        
        mkdir "%MYSQL_DIR%\data"
        if exist "%MYSQL_DIR%\backup" (
            xcopy "%MYSQL_DIR%\backup\*.*" "%MYSQL_DIR%\data\" /E /I /Q /Y >nul
            copy "!DATA_CORRUPT!\ibdata1" "%MYSQL_DIR%\data\ibdata1" /Y >nul
            
            for /d %%G in ("!DATA_CORRUPT!\*") do (
                set "fName=%%~nxG"
                if /i "!fName!" neq "mysql" if /i "!fName!" neq "performance_schema" if /i "!fName!" neq "phpmyadmin" if /i "!fName!" neq "test" (
                    mkdir "%MYSQL_DIR%\data\!fName!" 2>nul
                    xcopy "%%G\*.*" "%MYSQL_DIR%\data\!fName!\" /E /I /Q /Y >nul
                )
            )
            call :log "[OK] Estructura interna de MySQL reparada y reasociada con éxito." exito
            :: CORREGIDO: Removida coma final para evitar desbordamiento de argumentos de Batch
            call :log "[NOTA] Recuerda cambiar temporalmente tu wp-config.php a DB_USER='root' y DB_PASSWORD='' si perdiste usuarios." alerta
        ) else (
            call :log "[ERROR] No se encontró la carpeta 'backup' nativa de XAMPP para usarla como plantilla." error
        )
    )
)

:: --- REPARACIÓN 2: ERROR DE INICIO DE SESIÓN PHP (Permission Denied 13 / Mantenimiento) ---
if exist "%TMP_DIR%" (
    call :log "[XAMPP-FIX] Saneando directorio temporal de PHP y unlocking sesiones..." normal
    
    set "cnt_sess=0"
    for %%F in ("%TMP_DIR%\sess_*") do (
        del /F /Q "%%F" >nul 2>&1
        set /a "cnt_sess+=1"
    )
    call :log "    - Se han eliminado !cnt_sess! archivos de sesión 'sess_*' colgados." normal
    
    set "permiso_tmp=(OI)(CI)F"
    icacls "%TMP_DIR%" /grant:r "Todos":!permiso_tmp! /T /C /Q >nul 2>&1
    icacls "%TMP_DIR%" /grant:r "Administradores":!permiso_tmp! /T /C /Q >nul 2>&1
    
    call :log "[OK] Directorio tmp de XAMPP desbloqueado y permisos restablecidos." exito
)

:: Canalizar el final de la restauración directamente hacia la limpieza
goto :limpiar_respaldos_temporales

:: ==============================================================================
:: FINALIZACIÓN ORDENADA (Equivalente a limpiar_respaldos_temporales)
:: ==============================================================================
call :log "[*] Ejecutando limpieza de variables y archivos residuales del script..." normal
set "backup_dir_seleccionado="
set "forzar_fisi="
set "status_restore_lamp="
call :log "[-] Fase de restauración y mantenimiento completada con éxito." exito
echo.
pause
goto :menu


:: ==============================================================================
:: FUNCIÓN: limpiar_respaldos_temporales()
:: ==============================================================================
:limpiar_respaldos_temporales
call :log "[*] Ejecutando limpieza de variables y archivos residuales del script..." normal

:: Borrar archivos de comandos SFTP temporales o registros intermedios si existieran
if exist "%TEMP%\sftp_cmds_*" del /F /Q "%TEMP%\sftp_cmds_*" >nul 2>&1

:: Restablecer variables para el siguiente ciclo del menú principal
set "backup_dir_seleccionado="
set "forzar_fisi="
set "status_lamp="

call :log "[-] Fase de restauración y mantenimiento completada con éxito." exito
echo.
pause

:: CORREGIDO: Redirección explícita para evitar que la consola se cierre de golpe
goto :menu





:: ==============================================================================
:: BLOQUE DE BUCLE PRINCIPAL / DESVIACI N DE ACCIONES
:: ==============================================================================
:EJECUTAR_ACCION_PRINCIPAL
:: --- MEDIDOR DE TIEMPO INICIAL ---
for /f "tokens=1-4 delims=:.," %%A in ("%time%") do ( set /a "hora_ini=%%A", "min_ini=%%B", "seg_ini=%%C", "ms_ini=%%D" )

call :log "[SISTEMA] Iniciando procesamiento de la acción principal..." normal

:: BLINDAJE: Evita el error de comillas vacías usando expansion retardada
if "!opcion!"=="1" call :respaldo & set "status_final=!errorlevel!" & goto :FINALIZAR_SCRIPT
if "%opcion%"=="2" call :backup_LAMP & set "status_final=!errorlevel!" & goto :FINALIZAR_SCRIPT
if "!opcion!"=="3" goto :UTILIDAD_REPARAR_MYSQL
if "!opcion!"=="4" goto :UTILIDAD_REPARAR_TMP

:: Evaluar si se pasaron argumentos en frío por línea de comandos
call :run_non_interactive %*
if %errorlevel% equ 0 (
    :: Si no hay argumentos, desplegamos el menú interactivo visual
    call :menu
)
exit /b 0



:: ==============================================================================
:: SUB-UTILIDADES DE CONTROL DIRECTO
:: ==============================================================================

:UTILIDAD_REPARAR_MYSQL
cls
call :log "[REPARACI N] Forzando protocolo de emergencia para MySQL..." normal
taskkill /F /IM mysqld.exe >nul 2>&1
net stop mysql >nul 2>&1

set "DATA_OLD_PATH=%MYSQL_DIR%\data-old-%FECHA_LOG%_%HORA_LOG%"
if not exist "%MYSQL_DIR%\data\" (
    call :log "No existe la carpeta 'data' original para reparar." error
    pause & goto :menu
)

rename "%MYSQL_DIR%\data" "data-old-%FECHA_LOG%_%HORA_LOG%"
mkdir "%MYSQL_DIR%\data"

if not exist "%MYSQL_DIR%\backup\" (
    call :log "No se encontr  la carpeta plantilla 'backup' de XAMPP." error
    pause & goto :menu
)

xcopy "%MYSQL_DIR%\backup\*.*" "%MYSQL_DIR%\data\" /E /I /Q /Y >nul
copy "%DATA_OLD_PATH%\ibdata1" "%MYSQL_DIR%\data\ibdata1" /Y >nul

for /d %%G in ("%DATA_OLD_PATH%\*") do (
    set "fName=%%~nxG"
    if /i "!fName!" neq "mysql" if /i "!fName!" neq "performance_schema" if /i "!fName!" neq "phpmyadmin" if /i "!fName!" neq "test" (
        mkdir "%MYSQL_DIR%\data\!fName!" 2>nul
        xcopy "%%G\*.*" "%MYSQL_DIR%\data\!fName!\" /E /I /Q /Y >nul
    )
)
call :log "[OK] Estructura interna 'data' de MySQL reconstruida con  xito." exito
pause
goto :menu


:UTILIDAD_REPARAR_TMP
cls
call :log "[REPARACI N] Forzando purga de sesiones y desbloqueo de tmp..." normal
if exist "%TMP_DIR%" (
    set "c_sess=0"
    for %%F in ("%TMP_DIR%\sess_*") do ( del /F /Q "%%F" >nul 2>&1 & set /a "c_sess+=1" )
    set "p_tmp=(OI)(CI)F"
    icacls "%TMP_DIR%" /grant:r "Todos":!p_tmp! /T /C /Q >nul 2>&1
    icacls "%TMP_DIR%" /grant:r "Administradores":!p_tmp! /T /C /Q >nul 2>&1
    call :log "[OK] Se han purgado !c_sess! sesiones y reparado los permisos." exito
) else (
    call :log "No se localiz  la carpeta tmp de XAMPP." error
)
pause
goto :menu


:: ==============================================================================
:: SECCI N: CALCULO DE TIEMPOS Y CIERRE DEL SCRIPT
:: ==============================================================================
:FINALIZAR_SCRIPT

:: --- MEDIDOR DE TIEMPO FINAL CON LIMPIEZA DE CEROS (BASE 10) ---
for /f "tokens=1-4 delims=:.," %%A in ("%time%") do ( 
    set "h_f=%%A" & set "m_f=%%B" & set "s_f=%%C" & set "ms_f=%%D"
)
:: Truco matemático: quitar el cero inicial si existe para evitar el error octal
if "%h_f:~0,1%"=="0" set "h_f=%h_f:~1%"
if "%m_f:~0,1%"=="0" set "m_f=%m_f:~1%"
if "%s_f:~0,1%"=="0" set "s_f=%s_f:~1%"
if "%ms_f:~0,1%"=="0" set "ms_f=%ms_f:~1%"

set /a "hora_fin=h_f", "min_fin=m_f", "seg_fin=s_f", "ms_fin=ms_f"

set /a "ini_total_ms=((hora_ini*3600)+(min_ini*60)+seg_ini)*1000+ms_ini"
set /a "fin_total_ms=((hora_fin*3600)+(min_fin*60)+seg_fin)*1000+ms_fin"

if %fin_total_ms% lss %ini_total_ms% ( set /a "fin_total_ms+=86400000" )
set /a "diff_ms=fin_total_ms-ini_total_ms"

set /a "duracion_min=diff_ms / 60000", "resto_min=diff_ms %% 60000", "duracion_seg=resto_min / 1000"
echo.
call :log "==============================================================================" normal
call :log "   - Proceso concluido en: %duracion_min% Minutos con %duracion_seg% Segundos." exito
call :log "==============================================================================" normal


echo.
call :log "==============================================================================" normal
call :log "                       RESUMEN ESTAD STICO DE OPERACI N                       " normal
call :log "==============================================================================" normal
call :log "   - Estado de Salida del Script:  %status_final%" normal
call :log "   - Tiempo total transcurrido:    %duracion_min% Minutos, %duracion_seg%.%duracion_ms% Segundos" exito
call :log "==============================================================================" normal
echo.

set "hora_ini=" & set "min_ini=" & set "seg_ini=" & set "ms_ini="
set "hora_fin=" & set "min_fin=" & set "seg_fin=" & set "ms_fin="
set "ini_total_ms=" & set "fin_total_ms=" & set "diff_ms="

if "%opcion%"=="-1" (
    exit /b %status_final%
) else (
    pause
    goto :menu
)

