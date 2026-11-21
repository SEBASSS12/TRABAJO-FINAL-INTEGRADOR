#!/bin/bash
ORIGEN="/srv/tienda_tesoro"
CARPETA="/root/respaldos"
FECHA=$(date +%Y%m%d_%H%M%S)
DESTINO="$CARPETA/respaldo_tienda_$FECHA.tar.gz"
LOG="$CARPETA/respaldo.log"

tar -czf "$DESTINO" -C /srv tienda_tesoro

if [ $? -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - OK - $DESTINO" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - FALLO - $DESTINO" >> "$LOG"
fi
