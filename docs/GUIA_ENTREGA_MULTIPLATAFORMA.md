# Guía de entrega multiplataforma

## Producto cubierto

Una sola base Flutter genera:

1. Web desplegable.
2. APK/App Bundle Android.
3. Ejecutable Windows.

La API FastAPI es compartida por las tres aplicaciones.

## Demostración sugerida

1. Mostrar la URL web desplegada.
2. Iniciar sesión.
3. Cargar `red_con_anomalias.json`.
4. Visualizar el grafo.
5. Ejecutar la validación.
6. Mostrar el historial.
7. Abrir la misma cuenta desde Android o Windows y comprobar que los datos son
   los mismos porque provienen de la API central.

## Evidencias para el repositorio

- Captura de `flutter analyze` sin errores.
- Captura de `flutter test`.
- Captura de la aplicación web.
- Captura de Android.
- Captura de Windows.
- URL del backend y Swagger.
- URL del frontend web.

## Alcance conservado

La adaptación no agrega funciones fuera del MVP. Mantiene:

- login;
- carga JSON;
- grafos;
- validación;
- reportes;
- configuración.

Solo cambia la capa de presentación y la configuración de conectividad para que
el mismo producto funcione correctamente en diferentes tamaños y sistemas.
