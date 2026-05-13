Este directorio contiene scripts para preparar una version compartible de Todo en Windows.

- install.cmd: se ejecuta dentro del instalador autoextraible y copia la app a %LOCALAPPDATA%\Programs\Todo
- create_installer.ps1: genera dos salidas:
  - Todo-Setup.exe: instalador autoextraible
  - Todo-Windows-Portable.zip: version portable de respaldo
