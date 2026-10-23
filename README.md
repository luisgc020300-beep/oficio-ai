# Oficio AI

Prototipo funcional para que autónomos y pequeñas empresas de servicios
gestionen clientes, trabajos, presupuestos y agenda. Pensado para
demostraciones a clientes potenciales, no para producción.

## Cómo ejecutar la app

Requisitos: Flutter 3.38+ (estable) y un dispositivo o emulador Android
conectado (`flutter devices` para comprobarlo).

```bash
flutter pub get
flutter run
```

Al arrancar por primera vez, la app precarga datos de ejemplo (3 clientes,
3 trabajos, 2 presupuestos, 2 citas) para que la demo no empiece vacía.
Esos datos solo se escriben si no hay nada guardado todavía -- no
sobrescriben datos reales en arranques posteriores.

## Cómo generar un APK de demostración

```bash
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`, listo
para instalar por sideload en cualquier Android (no requiere cuenta de
Google Play ni firma especial más allá de la de depuración que usa
Flutter por defecto).

## Arquitectura

```
lib/
  core/            # tema, widgets reutilizables, formateadores -- sin
                    # lógica de negocio ni de persistencia
  data/
    models/        # Cliente, Trabajo, Presupuesto, ConceptoPresupuesto, Cita
    repositories/  # CRUD + persistencia de cada modelo (ChangeNotifier)
    local/         # LocalStore (SharedPreferences) + datos de ejemplo
    app_data.dart  # punto único de acceso a los 4 repositorios
  features/
    dashboard/      # panel principal: indicadores, próximos trabajos, actividad
    clients/         # alta, edición, ficha y listado de clientes
    jobs/            # trabajos asociados a un cliente
    quotes/          # presupuestos con conceptos editables y cálculo de IVA/total
    calendar/        # agenda por días
    assistant/       # chat de demostración, sin IA real conectada
  app_shell.dart    # navegación inferior entre los 6 módulos
  main.dart
```

La interfaz nunca accede a `SharedPreferences` directamente: todo pasa
por un repositorio, que es lo único que sabe cómo se guardan los datos.
Cambiar la persistencia en el futuro (una base de datos real, un backend)
significa reescribir los repositorios, no las pantallas.

## Persistencia local -- limitaciones

Los datos se guardan con `shared_preferences`, serializados como JSON por
colección (clientes, trabajos, presupuestos, citas). Es intencionadamente
simple para no depender de plugins nativos (`sqflite`, `hive`...) que no
se han podido probar en un dispositivo real en este entorno:

- Un único usuario, un único dispositivo -- no hay sincronización ni copia
  en la nube.
- Sin límite de tamaño impuesto por la app, pero `shared_preferences` no
  está pensado para volúmenes grandes de datos ni para consultas
  complejas (todo se carga entero en memoria al arrancar).
- Borrar los datos de la app en el dispositivo (o desinstalarla) borra
  también los datos guardados.
- No hay migración de esquema: si el formato de un modelo cambia en el
  futuro, hace falta un paso explícito de migración que hoy no existe.

Para una versión real, el siguiente paso natural es sustituir
`LocalStore` por una base de datos local real (ej. `sqflite` o `drift`)
y, más adelante, un backend -- sin tocar las pantallas, porque toda la
persistencia vive detrás de los repositorios.

## Asistente -- estado real

La pestaña "Asistente" es una interfaz de chat funcional (envía mensajes,
los muestra, hace scroll) pero **no tiene ninguna IA real conectada**.
Responde con un pequeño conjunto de respuestas predefinidas según
palabras clave ("presupuesto", "cliente", "trabajo", "cita"), y lo deja
dicho de forma visible en la propia pantalla ("Modo demostración -- sin
IA real todavía"). Conectarlo a un modelo real (p. ej. la API de Claude)
es trabajo pendiente, no algo que esta versión simule ni oculte.

## Pruebas

```bash
flutter analyze
flutter test
```

- `test/quote_totals_test.dart`: cálculo de presupuestos (subtotal, IVA,
  total) -- la lógica crítica del encargo.
- `test/cliente_repository_test.dart`: CRUD del repositorio de clientes
  contra `SharedPreferences` simulado, incluida la persistencia entre
  instancias y que los datos de ejemplo no sobrescriben datos reales.
- `test/widget_test.dart`: smoke test de arranque de la app completa con
  los datos de ejemplo cargados.

## Limitaciones conocidas y siguientes pasos

- Solo Android -- no se ha generado soporte iOS/web (ver inspección
  inicial del encargo).
- Agenda: vista por días con una franja de 14 días, sin vista mensual
  completa.
- Expediente de la vivienda / exportación a PDF, pasarela de pago real,
  notificaciones push y sincronización multi-dispositivo: fuera de
  alcance de este prototipo.
- El asistente no tiene IA real conectada (ver sección anterior).
- Sin autenticación: la app asume un único usuario del propio
  dispositivo, sin login ni cuentas.
