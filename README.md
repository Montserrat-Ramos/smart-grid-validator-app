# Smart Grid Validator · Flutter multiplataforma 1.0

Aplicación Flutter única para Android, Web y Windows, conectada con la API FastAPI. La presentación reproduce el diseño oscuro aprobado: menú lateral en web/escritorio, navegación inferior en móvil, tarjetas de métricas, visualizador, validación, reportes, historial y configuración.

## Funciones implementadas

- Login real, registro, sesión invitada, recuperación controlada, refresh token y logout.
- Rutas protegidas y almacenamiento seguro de credenciales.
- Dashboard conectado con métricas y anomalías reales.
- Carga mediante selector nativo o arrastrar/soltar según plataforma.
- Vista previa y detección de formato SGV, MATPOWER y pandapower.
- Catálogo de casos públicos IEEE 14, 33 y 118 buses incorporados en el backend.
- Listado, búsqueda, filtros y eliminación de grafos.
- Visualizador interactivo con pan, zoom, centrado, leyenda, selección y detalle.
- Layout escalable para grafos con cientos de nodos.
- Selección de reglas aplicables al perfil del grafo.
- Validación asíncrona con progreso, polling, pausa del monitoreo, cancelación y resultados.
- Reportes con métricas, severidad, tendencia y detalle de anomalías.
- Exportación funcional a PDF y JSON.
- Historial con búsqueda, estado, rango de fechas, paginación, detalle y eliminación.
- Perfil, foto local, tema, preferencias, notificaciones, seguridad, contraseña y sesiones.
- Diseño responsive para teléfonos pequeños, tabletas, navegador y escritorio.

> Los datasets IEEE son benchmarks públicos. La interfaz los identifica como datos de referencia y no como telemetría SCADA en vivo.

## Arquitectura hexagonal por feature

```text
lib/features/<feature>/
├── domain/          entidades y puertos
├── application/     casos de uso/controladores
├── infrastructure/  API REST y almacenamiento
└── presentation/    vistas y widgets responsive
```

## Requisitos

- Flutter 3.38.3.
- Dart 3.10.
- Android Studio actualizado.
- API ejecutándose en el puerto 8000.

## Paso inicial en Android Studio

1. Abre la carpeta que contiene `pubspec.yaml`.
2. Abre **Terminal**.
3. En Windows ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\bootstrap-platforms.ps1
```

El script genera las carpetas Android y Windows, conserva la carpeta Web incluida, configura Internet local e instala iconos.

## Ejecutar Web

```powershell
flutter pub get
flutter run -d chrome --web-port=8080 `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1
```

## Ejecutar Windows

```powershell
flutter run -d windows `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1
```

## Ejecutar Android Emulator

```powershell
flutter run -d emulator-5554 `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1
```

## Ejecutar en teléfono físico

La API debe iniciar con `--host 0.0.0.0`. Sustituye la IP por la de tu computadora (Localmente):

```powershell
flutter run -d ID_DEL_DISPOSITIVO `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1
```

## Credenciales locales

```text
Correo: admin@smartgrid.local
Contraseña: Admin123*
```

## Compilar entregables

```powershell
flutter build web --release `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1

flutter build apk --release `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1

flutter build windows --release `
  --dart-define=API_BASE_URL=https://smart-grid-validator-api.onrender.com/api/v1
```

## Verificación automática

El workflow `.github/workflows/ci.yml` ejecuta en Flutter 3.38.3:

```text
flutter analyze
flutter test
flutter build web
flutter build apk
flutter build windows
```

La generación de plataformas se realiza en CI antes de compilar para que el repositorio conserve una única base Flutter limpia.

