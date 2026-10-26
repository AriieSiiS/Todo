#!/bin/sh
# Instala únicamente el trabajo nuevo y sus entradas; conserva los archivos nativos.
set -eu
base=/mnt/us/system/todo-koreader
stage="$base/preparacion"
job=/etc/upstart/todo-koreader.conf
plugin=/mnt/us/koreader/plugins/todo.koplugin
kpm=/mnt/us/kmc/kpm/packages/koreader/launch.sh
cd "$stage"
sha256sum -c archivos.sha256
sh ./compatibilidad.sh "$(cat /etc/prettyversion.txt)" \
    "$(sha256sum /app/KPPMainApp/js/KPPMainApp.js.hbc | cut -d ' ' -f 1)"
test -z "$(ps -eo args | grep '^./luajit ./reader.lua' || true)"
test ! -e "$job"
test ! -e "$base/activado"
grep -E '^/dev/root / ext3 ro,' /proc/mounts >/dev/null
test -f "$plugin/main.lua" && test -f "$kpm"
cp -p "$plugin/main.lua" "$base/main-anterior.lua"
cp -p "$kpm" "$base/kpm-anterior.sh"
previous_arranque=0
if test -f "$plugin/arranque.lua"; then
    cp -p "$plugin/arranque.lua" "$base/arranque-anterior.lua"
    previous_arranque=1
fi
rw=0
created=0
cleanup() {
    result=$?
    if test "$result" -ne 0; then
        cp -p "$base/main-anterior.lua" "$plugin/main.lua" || true
        cp -p "$base/kpm-anterior.sh" "$kpm" || true
        if test "$previous_arranque" = 1; then
            cp -p "$base/arranque-anterior.lua" "$plugin/arranque.lua" || true
        else
            rm -f "$plugin/arranque.lua"
        fi
        if test "$created" = 1; then
            if test "$rw" = 0; then mount -o remount,rw / && rw=1; fi
            rm -f "$job"
        fi
    fi
    if test "$rw" = 1; then mount -o remount,ro /; fi
}
trap cleanup EXIT
for name in launch.sh boot.sh; do
    cp "$name" "$base/$name.nuevo"
    chmod 755 "$base/$name.nuevo"
    mv "$base/$name.nuevo" "$base/$name"
done
cp arranque.lua "$plugin/arranque.lua.nuevo"
mv "$plugin/arranque.lua.nuevo" "$plugin/arranque.lua"
cp main.lua "$plugin/main.lua.nuevo"
mv "$plugin/main.lua.nuevo" "$plugin/main.lua"
cp kpm-launch.sh "$kpm.nuevo"
chmod 755 "$kpm.nuevo"
mv "$kpm.nuevo" "$kpm"
mkdir -p /tmp/todo-koreader-iniciado
mount -o remount,rw /
rw=1
cp todo-koreader.conf "$job.nuevo"
chmod 644 "$job.nuevo"
mv "$job.nuevo" "$job"
created=1
mount -o remount,ro /
rw=0
printf '%s\n' 'Comprobando el trabajo de arranque registrado.'
attempts=0
while ! initctl status todo-koreader; do
    attempts=$((attempts + 1))
    test "$attempts" -lt 3
    sleep 1
done
grep -E '^/dev/root / ext3 ro,' /proc/mounts >/dev/null
sha256sum -c instalados.sha256
touch "$base/activado"
printf '%s\n' 'Arranque instalado; sistema original conservado y raíz de solo lectura.'
