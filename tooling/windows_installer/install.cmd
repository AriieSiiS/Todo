@echo off
setlocal

set "BASE_DIR=%~dp0"
set "ZIP_PATH=%BASE_DIR%payload.zip"
set "TEMP_PAYLOAD=%TEMP%\todo_installer_payload"
set "TARGET_DIR=%LOCALAPPDATA%\Programs\Todo"
set "DESKTOP_SHORTCUT=%USERPROFILE%\Desktop\Todo.lnk"
set "STARTMENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Todo"
set "STARTMENU_SHORTCUT=%STARTMENU_DIR%\Todo.lnk"

if exist "%TEMP_PAYLOAD%" rmdir /s /q "%TEMP_PAYLOAD%"
mkdir "%TEMP_PAYLOAD%" >nul 2>&1
mkdir "%TARGET_DIR%" >nul 2>&1
mkdir "%STARTMENU_DIR%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP_PATH%' -DestinationPath '%TEMP_PAYLOAD%' -Force"
if errorlevel 1 goto :fail

robocopy "%TEMP_PAYLOAD%" "%TARGET_DIR%" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto :fail

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$shell = New-Object -ComObject WScript.Shell; " ^
  "$desktop = $shell.CreateShortcut('%DESKTOP_SHORTCUT%'); " ^
  "$desktop.TargetPath = '%TARGET_DIR%\todo.exe'; " ^
  "$desktop.WorkingDirectory = '%TARGET_DIR%'; " ^
  "$desktop.IconLocation = '%TARGET_DIR%\todo.exe,0'; " ^
  "$desktop.Save(); " ^
  "$menu = $shell.CreateShortcut('%STARTMENU_SHORTCUT%'); " ^
  "$menu.TargetPath = '%TARGET_DIR%\todo.exe'; " ^
  "$menu.WorkingDirectory = '%TARGET_DIR%'; " ^
  "$menu.IconLocation = '%TARGET_DIR%\todo.exe,0'; " ^
  "$menu.Save()"
if errorlevel 1 goto :fail

start "" "%TARGET_DIR%\todo.exe"
exit /b 0

:fail
echo No se pudo instalar Todo correctamente.
pause
exit /b 1
