#!/bin/bash
# Simula únicamente el montaje y el servicio; nunca ejecuta esas acciones reales.
set -eu
mount() {
    printf 'accion:montar\n'
    test "${TODO_TEST_FAIL_MOUNT:-0}" = 0 || return 1
    cp "$3" "$TODO_TEST_ROOT/anterior"
    cp "$2" "$3"
}
umount() {
    printf 'accion:desmontar\n'
    cp "$TODO_TEST_ROOT/anterior" "$2"
}
restart() {
    printf 'accion:recargar\n'
    test "${TODO_TEST_FAIL_RESTART:-0}" = 0
}
initctl() {
    if test "${TODO_TEST_RUNNING:-1}" = 1; then
        printf 'kppmainapp start/running, process 123\n'
    else
        printf 'kppmainapp stop/waiting\n'
    fi
}
sleep() { :; }
timeout() { shift 3; "$@"; }
activation=$1
shift
source "$activation"
