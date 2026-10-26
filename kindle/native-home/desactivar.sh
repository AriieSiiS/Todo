#!/bin/sh
# Desactiva la reaplicación y recupera el inicio original de Amazon.
set -eu
base=/mnt/us/system/todo-native-home
target=/app/KPPMainApp/js/KPPMainApp.js.hbc
case "$(sha256sum "$target" | cut -d ' ' -f 1)" in
    789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48|ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99)
        original=789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48
        patched=ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99 ;;
    50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86|db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f)
        original=50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86
        patched=db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f ;;
    *) printf '%s\n' 'La interfaz no coincide con una copia reconocida.' >&2; exit 1 ;;
esac
touch "$base/desactivado"
if test "$(sha256sum "$target" | cut -d ' ' -f 1)" = "$patched"; then
    grep -F " $target " /proc/mounts >/dev/null
    umount -l "$target"
    if initctl status kppmainapp | grep -q 'start/running'; then
        restart kppmainapp
        sleep 5
    fi
fi
test "$(sha256sum "$target" | cut -d ' ' -f 1)" = "$original"
printf '%s\n' 'Inicio original restaurado; reaplicación desactivada.'
