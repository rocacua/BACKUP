#!/bin/bash

# ==========================================
# 1. OPERACIONES DE ARCHIVOS (100% Universal)
# ==========================================
echo "Creando directorio de BACKUP..."
mkdir -p "/home/${USER}/BACKUP"
cd "/home/${USER}/BACKUP" || exit 1

echo "Copiando scripts desde la carpeta compartida..."
ORIGEN="/media/sf_compartir"

# Validar si la carpeta de VirtualBox está montada antes de copiar
if [ -d "$ORIGEN" ]; then
    cp "$ORIGEN"/panel.sh .
    cp "$ORIGEN"/installamp.sh .
    cp "$ORIGEN"/uninstallamp.sh .
    cp "$ORIGEN"/instalide.sh .
    cp "$ORIGEN"/uninstalide.sh .
    cp "$ORIGEN"/creaweb.sh .
    cp "$ORIGEN"/borraweb.sh .
    cp "$ORIGEN"/backupR.sh .
    cp "$ORIGEN"/cp_pruebas_VB.sh .

    echo "Asignando permisos de ejecución..."
    chmod +x *.sh
    echo "✅ ¡Proceso completado con éxito!"
else
    echo "❌ Error: No se encuentra la ruta '$ORIGEN'. ¿Está montada la carpeta compartida?"
fi
