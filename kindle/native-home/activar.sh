#!/bin/sh
# Oculta promociones en la sesión sin sustituir el archivo original del sistema.
set -eu
base=/mnt/us/system/todo-native-home
target=/app/KPPMainApp/js/KPPMainApp.js.hbc
hash() { sha256sum "$1" | cut -d ' ' -f 1; }
test ! -e "$base/desactivado" || exit 0
if test "${1:-}" != prueba; then
    test -f "$base/validado" || exit 0
fi
case "$(hash "$target")" in
    789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48|ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99)
        original=789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48
        patched=ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99
        image="$base/inicio-ece6c579fb0e.hbc"
        ;;
    50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86|db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f)
        original=50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86
        patched=db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f
        image="$base/inicio-db7ceae850d1.hbc"
        ;;
    *) printf '%s\n' 'Firmware diferente: se conserva el inicio original.'; exit 0 ;;
esac
test "$(hash "$target")" != "$patched" || exit 0
test "$(hash "$image")" = "$patched"
mkdir /tmp/todo-native-home.lock 2>/dev/null || exit 0
mounted=0
running=0
if initctl status kppmainapp | grep -q 'start/running'; then running=1; fi
cleanup() {
    result=$?
    if test "$result" -ne 0 && test "$mounted" = 1; then
        touch "$base/desactivado"
        umount -l "$target" || true
        if test "$running" = 1; then timeout -s KILL 20 restart kppmainapp || true; fi
    fi
    rmdir /tmp/todo-native-home.lock
}
trap cleanup EXIT
mount --bind "$image" "$target"
mounted=1
test "$(hash "$target")" = "$patched"
if test "$running" = 1; then
    timeout -s KILL 20 restart kppmainapp
    sleep 3
    first=$(initctl status kppmainapp)
    printf '%s' "$first" | grep -q 'start/running'
    sleep 2
    test "$(initctl status kppmainapp)" = "$first"
fi
printf '%s\n' 'Inicio sin promociones activado para esta sesión.'
