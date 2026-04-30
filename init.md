# Init

## Objetivo

Levantar la base tecnica de una app de tareas personal, multiplataforma y minimalista.

## Decisiones iniciales

- Cliente unico con Flutter.
- Soporte objetivo: Windows, web y Android.
- Persistencia local prevista con Drift y SQLite.
- Sincronizacion prevista con Firebase.
- Integracion prevista con Google Calendar.
- Notificaciones previstas para Android, web y Windows.

## Lo que queda preparado en esta fase

- Repositorio Git inicializado.
- Estructura base del proyecto en `lib/`.
- Primera pantalla de tareas con estilo minimalista.
- Tema visual base en codigo.
- Documentacion inicial para producto y diseno.

## Bloqueadores actuales

- Flutter y Dart no estan disponibles en el entorno actual.
- Aun no existen wrappers generados para `android/`, `web/` y `windows/`.
- Firebase y Google Calendar aun no tienen credenciales configuradas.

## Arranque recomendado cuando Flutter este instalado

1. Abrir esta carpeta como proyecto.
2. Ejecutar `flutter create .`
3. Ejecutar `flutter pub get`
4. Lanzar `flutter run -d chrome` o el dispositivo deseado

