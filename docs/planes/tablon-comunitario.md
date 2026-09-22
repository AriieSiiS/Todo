# Plan funcional: Tablón comunitario de objetivos

> Estado: especificación funcional acordada. La arquitectura técnica está pendiente y deberá definirse en un plan separado antes de programar.
>
> Nota de origen en Todo: `note-1790034119436014-7bbdff`.

## Resumen

Crear una PWA independiente de Todo, en un repositorio hermano, donde las personas compartan objetivos mediante tablones públicos o privados.

Todo solo conserva la nota original y la referencia a este documento. La nueva aplicación no reutilizará la navegación, el snapshot ni las tareas de Todo.

## Funcionamiento del producto

- Acceso completo mediante una cuenta de Google.
- Perfil con nombre, avatar, enlace compartible, tablones públicos y tablones privados compartidos con el visitante.
- Amistades mutuas mediante solicitud, aceptación, rechazo y eliminación.
- Varios tablones por persona; todos los objetivos deben pertenecer a uno.
- Tablones públicos visibles únicamente desde el perfil o un enlace directo, sin buscador ni novedades globales.
- Tablones privados visibles para el propietario y los amigos que este añada.
- Enlaces secretos, revocables y específicos para un tablón. Sin cuenta permiten consultar, pero no reaccionar ni comentar.
- El propietario administra el tablón, los objetivos y los miembros; los demás no pueden editar sus contenidos.

Cada objetivo tendrá título, descripción opcional, fecha objetivo opcional, hitos ordenables y estado derivado:

- Sin hitos, funciona como un objetivo simple de 0 % o 100 %.
- Con hitos, todos tienen el mismo peso y el porcentaje se calcula automáticamente.
- 0 % corresponde a «Pendiente», entre 1 % y 99 % a «En curso» y 100 % a «Logrado».
- «Marcar como logrado» completa todos los hitos; reabrirlo conserva su historial.

Los usuarios con cuenta podrán:

- Elegir una reacción por objetivo entre 👍, ❤️, 👏, 🔥 y 🎉; podrán cambiarla o retirarla.
- Escribir comentarios de hasta 1.000 caracteres.
- Editar o eliminar sus propios comentarios.
- Consultar comentarios y reacciones en tiempo real.
- Recibir avisos dentro de la aplicación por solicitudes de amistad, comentarios, reacciones y objetivos logrados. No se generan avisos por acciones propias.

## Modelo funcional y permisos

Entidades necesarias: perfil, solicitud de amistad, amistad, tablón, miembro del tablón, objetivo, hito, reacción, comentario, aviso y enlace de invitado.

Reglas obligatorias:

- Los datos de Todo no se comparten ni se importan.
- Solo el propietario modifica o elimina sus tablones y objetivos.
- Un miembro aceptado puede leer, comentar y reaccionar en un tablón privado.
- Eliminar una amistad retira también el acceso a los tablones privados asociados.
- Cualquier usuario con cuenta puede consultar un tablón público si llega al perfil o al enlace.
- Un invitado sin cuenta puede leer mediante un enlace válido, pero no interactuar.
- Revocar o regenerar un enlace invalida inmediatamente el anterior.
- Los invitados ven el contenido completo del tablón, incluidos comentarios, nombres públicos y recuentos de reacciones.
- El propietario puede retirar cualquier comentario de sus tablones; el autor también puede retirar el suyo.
- Eliminar un tablón exige confirmación y revoca todos sus enlaces.

## Fases y validación

1. Crear este documento y enlazarlo desde la nota de Todo.
2. Preparar un plan técnico separado que decida tecnología, alojamiento, esquema físico, seguridad y estructura del nuevo repositorio.
3. Construir cuentas, perfiles, amistades y navegación adaptable.
4. Incorporar tablones, miembros, objetivos, hitos y cálculo automático del progreso.
5. Añadir comentarios, reacciones, avisos internos y actualización en tiempo real.
6. Añadir perfiles compartibles y enlaces web de solo lectura.
7. Completar accesibilidad, instalación como PWA, pruebas de permisos y despliegue.

Pruebas de aceptación:

- Un desconocido no puede consultar un tablón privado sin un enlace válido.
- Un enlace revocado deja de funcionar.
- Un invitado nunca puede modificar datos.
- Un amigo eliminado pierde inmediatamente el acceso privado.
- Los tablones públicos no aparecen en búsquedas ni en unas novedades globales.
- El progreso coincide con los hitos completados y alcanza exactamente el 100 %.
- Reacciones, comentarios y avisos no se duplican.
- La interfaz funciona correctamente en móvil y escritorio.
- La PWA puede instalarse y abrirse como aplicación independiente.

## Supuestos y límites

- Este documento es únicamente funcional; no fija marco de desarrollo, API ni proveedor.
- Antes de programar será obligatorio redactar y aprobar el plan técnico.
- El código vivirá en un repositorio hermano independiente.
- Quedan fuera de la primera versión: chat privado, edición colaborativa, novedades globales, búsqueda de perfiles, comentarios anónimos, correo, notificaciones del sistema y aplicaciones nativas.
- La idea de palabras en la pantalla de bloqueo tendrá su propio documento después de terminar y enlazar este.
