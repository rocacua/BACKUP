BACKUP Script
=============

**Resumen**
-----------
Script de backup para sincronizar directorios locales y remotos usando `rsync` (y `rclone` para remotes no-SSH). Soporta exclusiones, logging, detección de remotos y creación automática de rutas remotas.

**Requisitos**
--------------
- Linux (probado en Debian/Ubuntu/Mint)
- `rsync` (>=3.1)
- `ssh` (cliente) y, para backups remotos por SSH, `openssh-server` en destino
- `rclone` (opcional) para remotes tipo `remote:subpath`
- (opcional) `sudo` si necesitas respaldar archivos protegidos

**Archivos**
-----------
- [backupR.sh](backupR.sh): script principal
- [exclude_list.txt](exclude_list.txt): patrones a excluir
- `logs/`: directorio de salida para logs (`logs/BACKUP-YYYY-MM-DD_HH-MM-SS.log`)

**Novedades importantes**
-------------------------
- **Logging centralizado:** funciones `log()` y `err()` generan logs en `logs/` con timestamp.
- **Modo no interactivo:** opción `--non-interactive` con flags `--src` y `--dst` (ver ejemplos abajo). Ideal para `cron`/automatización.
- **Detección de remotos:** reconoce rutas scp-like (`user@host:/path`), `rclone`-style (`remote:subpath`) y ajusta el comportamiento.
- **Creación remota de directorios:** para destinos SSH se añade `--rsync-path="mkdir -p 'ruta' && rsync"` para crear la ruta destino antes de transferir.
- **Opciones rsync adaptativas:** el script usa opciones más conservadoras cuando alguno de los extremos es remoto (evita ejecutar `df`/`du` sobre remotos).

**Uso interactivo**
-------------------
Ejecuta:

```bash
./backupR.sh
```

Sigue los menús para elegir origen y destino. Puedes usar rutas locales, scp-like o `rclone` remotes.

**Uso no interactivo (ejemplos)**
-------------------------------

- Dry-run (verifica sin transferir):

```bash
./backupR.sh --non-interactive --src /ruta/origen --dst user@host:/ruta/destino --dry-run
```

- Transferencia real (asegúrate de tener claves SSH configuradas y quitar `--dry-run`):

```bash
./backupR.sh --non-interactive --src /ruta/origen --dst user@host:/ruta/destino
```

**Requisitos para ejecución no interactiva**
------------------------------------------
- Configura autenticación por clave SSH sin contraseña (o usar `ssh-agent`):

```bash
ssh-keygen -t ed25519
ssh-copy-id user@host
```

- Si la copia requiere privilegios remotos, considera configurar `sudo` sin contraseña con cuidado.

**Comportamiento técnico clave**
-------------------------------
- `--rsync-path`: se usa para ejecutar `mkdir -p` en el host remoto en la misma conexión SSH que `rsync`, evitando errores al crear rutas anidadas.
- Evitamos ejecutar utilidades locales (`df`, `du`, `realpath`) sobre cadenas que identifican remotos; el script detecta remotos y cambia las comprobaciones.
- Si el destino es `remote:subpath` y `rclone` está instalado, el script puede optar por `rclone` como alternativa cuando `rsync`/SSH no aplican.

**Logs**
--------
- Los logs se escriben en `logs/BACKUP-YYYY-MM-DD_HH-MM-SS.log`.
- En `--dry-run` verás el comando completo (incluyendo `--rsync-path`) y la lista simulada de archivos.

**Errores comunes y soluciones**
-------------------------------
- `Permission denied (publickey,password)`: falta de clave pública. Genera e instala una llave con `ssh-copy-id`.
- `rsync: [Receiver] mkdir "..." failed: No such file or directory`: el script añade `--rsync-path`; si ves rutas duplicadas, normaliza la variable `--dst` y evita `//` dobles.
- `df`/`du` fallando en remotos: indica que el script intentó medir espacio sobre un remote; usa `--dry-run` y revisa `get_rsync_opts()`.

**Integración en cron (ejemplo)**
--------------------------------
Configura autenticación sin contraseña y prueba primero con `--dry-run`.

```bash
# Backup diario a las 03:00 (ajusta rutas y usuario)
0 3 * * * /ruta/a/directorio/backupR.sh --non-interactive --src /origen --dst user@host:/destino >> /ruta/a/directorio/logs/cron-backup-$(date +\%F).log 2>&1
```

**Buenas prácticas**
--------------------
- Probar siempre con `--dry-run` antes de ejecuciones automáticas.
- Mantener las claves SSH con `ssh-agent` o `ssh-key` y restringir permisos.
- Revisar y personalizar `exclude_list.txt` para descartar ficheros innecesarios.
