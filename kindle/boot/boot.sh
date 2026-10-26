#!/bin/sh
# Omite USB y recuperación; solo permite un intento por arranque del dispositivo.
set -eu
base=/mnt/us/system/todo-koreader
permitido() {
    test -f "$base/activado" &&
    test ! -e "$base/desactivado" &&
    test ! -e /mnt/us/DESACTIVAR_INICIO_TODO &&
    test -f /mnt/us/koreader/koreader.sh &&
    test "$(lipc-get-prop com.lab126.volumd userstoreIsAvailable 2>/dev/null)" = 1 &&
    test "$(lipc-get-prop com.lab126.volumd driveModeState 2>/dev/null)" = 0
}
permitido || exit 0
mkdir /tmp/todo-koreader-iniciado 2>/dev/null || exit 0
restantes=30
while test "$restantes" -gt 0; do
    permitido || exit 0
    sleep 1
    restantes=$((restantes - 1))
done
permitido || exit 0
if ps -eo args | grep -q '^./luajit ./reader.lua'; then exit 0; fi
printf '%s\n' 'Abriendo KOReader con Todo y la interfaz nativa detenida.'
sh "$base/launch.sh"
