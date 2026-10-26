#!/bin/sh
# Representa al lector para comprobar los argumentos y el resultado de salida.
printf 'hijo:%s:%s\n' "$UNPACK_DIR" "$#"
printf '<%s>\n' "$@"
exit "${TODO_TEST_CHILD_EXIT:-0}"
