#!/bin/bash
# Simula los servicios del Kindle para comprobar las decisiones de arranque.
set -eu
ticks=0
sleep() { ticks=$((ticks + 1)); }
lipc-get-prop() {
    test "${TODO_TEST_SERVICE_ERROR:-0}" = 0 || return 1
    if test "$2" = driveModeState; then
        if test "${TODO_TEST_USB_LATER:-0}" = 1 && test "$ticks" -gt 0; then printf '1\n';
        else printf '%s\n' "${TODO_TEST_USB:-0}"; fi
    elif test "$2" = userstoreIsAvailable; then printf '1\n';
    else return 1; fi
}
initctl() {
    if test "$2" = kppmainapp; then
        if test "$ticks" -lt "${TODO_TEST_GUI_DELAY:-0}"; then printf 'kppmainapp stop/waiting\n';
        else printf 'kppmainapp start/running\n'; fi
    elif test "${TODO_TEST_GUI_ACTIVE:-0}" = 1; then printf 'lab126_gui start/running\n';
    else printf 'lab126_gui stop/waiting\n'; fi
}
start() { test "$1" = lab126_gui; printf 'recuperar-interfaz\n'; }
lipc-set-prop() {
    if test "$1" = com.lab126.appmgrd && test "$2" = stop &&
        test "$3" = app://com.lab126.KPPMainApp; then
        printf 'cerrar-inicio-original\n'
        return 0
    fi
    test "$1" = com.lab126.appmgrd && test "$2" = start &&
        test "$3" = 'app://com.lab126.KPPMainApp?view=KPP_HOME' || return 1
    printf 'abrir-inicio-original\n'
    test "${TODO_TEST_HOME_ERROR:-0}" = 0
}
timeout() { shift 3; "$@"; }
ps() { if test "${TODO_TEST_READER_ACTIVE:-0}" = 1; then printf './luajit ./reader.lua\n'; fi; }
script=$1
shift
source "$script"
