#!/bin/sh
# Conserva el lanzador de KOReader y recupera la interfaz si el lector falla.
set -u
while test "$#" -gt 0; do
    case "$1" in --asap|--kual|--framework_stop) shift ;; *) break ;; esac
done
recuperar() {
    if test -f /mnt/us/system/todo-native-home/activar.sh; then
        sh /mnt/us/system/todo-native-home/activar.sh || true
    fi
    if ! initctl status lab126_gui | grep -q 'start/running'; then
        timeout -s KILL 25 start lab126_gui || true
    fi
    restantes=60
    while test "$restantes" -gt 0; do
        if initctl status kppmainapp | grep -q 'start/running' &&
            timeout -s KILL 2 lipc-set-prop com.lab126.appmgrd start 'app://com.lab126.KPPMainApp?view=KPP_HOME'; then
            return 0
        fi
        sleep 1
        restantes=$((restantes - 1))
    done
    printf '%s\n' 'No se pudo abrir el inicio original; consulta el registro de arranque.' >&2
}
trap recuperar EXIT
if initctl status lab126_gui | grep -q 'start/running' &&
    initctl status kppmainapp | grep -q 'start/running'; then
    timeout -s KILL 2 lipc-set-prop com.lab126.appmgrd stop app://com.lab126.KPPMainApp || true
fi
cd /mnt/us/ || exit 1
UNPACK_DIR=/mnt/us sh koreader/koreader.sh --framework_stop "$@"
