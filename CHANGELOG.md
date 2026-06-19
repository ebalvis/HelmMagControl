# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

## [0.3.0] - 2026-06-19

### Añadido
- Selector de idioma **Español / Inglés** (desplegable) con cambio en caliente de toda la interfaz, incluido el título de la aplicación.
- Persistencia del idioma elegido en el registro de Windows; en el primer arranque se detecta el idioma del sistema (alternativa: español).
- Indicación de unidad **«ms»** junto al campo de intervalo de refresco.
- Nueva unidad `uLang` que centraliza todos los textos de la interfaz.

### Corregido
- **Seguridad de hilos** en el control remoto TCP: las operaciones sobre la interfaz se serializan al hilo principal mediante `TThread.Synchronize`.
- El comando `READ ALL` numera los canales en base 1, coherente con el resto del protocolo.
- Destructor de `TTcpServerController` marcado como `override`: ahora desactiva y libera correctamente el servidor TCP.
- Cierre de la aplicación: se detiene el hilo Modbus y se libera el servidor TCP.
- Separador decimal del protocolo TCP fijado a punto invariante en entrada y salida.
- Corregidos los acentos de los mensajes en español (estaban dañados en el código fuente original).

### Interno
- Eliminados los *hints* del compilador y el código muerto.
