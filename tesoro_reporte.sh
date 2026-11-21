#!/bin/bash
while true; do
    FECHA=$(date '+%Y-%m-%d %H:%M:%S')
    VENTAS=$(wc -l < /srv/tienda_tesoro/ventas/ventas_nov.txt 2>/dev/null || echo 0)
    DISCO=$(df -h / | awk 'NR==2 {print $5}')
    echo "[$FECHA] Tienda El Tesoro - Ventas registradas: $VENTAS | Uso disco: $DISCO" >> /srv/tienda_tesoro/reportes/actividad_tienda.log
    sleep 60
done
