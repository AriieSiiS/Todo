#!/bin/sh
# Cada firmware se admite únicamente junto a la interfaz nativa inspeccionada.
set -eu
test "$#" = 2
case "$1" in
    'Kindle 5.19.2.0.1 (~~otaVersion~~)')
        esperada=789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48
        limpia=ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99
        ;;
    'Kindle 5.17.1.0.4 (~~otaVersion~~)')
        esperada=50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86
        limpia=db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f
        ;;
    *)
        printf '%s\n' 'El firmware no tiene una compatibilidad de arranque comprobada.' >&2
        exit 1
        ;;
esac
if test "$2" != "$esperada" && test "$2" != "$limpia"; then
    printf '%s\n' 'La interfaz nativa no coincide con la inspeccionada para este firmware.' >&2
    exit 1
fi
