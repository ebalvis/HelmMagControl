# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

## [0.4.0] - 2026-06-20

### Añadido
- **Versión multiplataforma en Lazarus / Free Pascal** (carpeta `lazarus/`), con paridad funcional con la versión Delphi en Windows:
  - Aplicación completa con los 3 canales sobre el frontal real Wanptek KPS3020D, configuración del puerto serie, direcciones X/Y/Z, intervalo y puerto del servidor.
  - Internacionalización **Español / Inglés** en caliente (UTF-8 nativo de la LCL).
  - Núcleo Modbus RTU (CRC, tramas, parseo) y capa serie abstracta `ISerialTransport` con back-ends Windows (WinAPI) y POSIX (termios).
  - Servidor TCP del mismo protocolo de texto (`PING`, `SET`, `GET`, `OUT`, `STATUS`, `READ ALL`, `ALL OFF`) en un hilo aparte, con *marshalling* al hilo principal.
  - Widgets propios que reemplazan a los componentes JVCL: display de 7 segmentos (`TSeg7Display`), dial rotatorio (`TKnob`) e interruptor (`TToggle`).

### Corregido (Delphi y Lazarus)
- Endurecida la captura de errores de conexión y del servidor TCP:
  - El reintento de conexión sin puerto ya no congela la interfaz.
  - Ciclo de vida correcto del servidor TCP (arranque idempotente, parada al desconectar).
  - El servidor TCP de Lazarus ya no se cuelga al pararse con un cliente conectado e inactivo (`SO_RCVTIMEO`).
  - Un comando TCP que lance una excepción ya no tumba el servidor.
  - Estado de conexión honesto («Conectando…») y errores de *bind* del servidor visibles en la barra de estado.
  - Cola de escritura del hilo Modbus acotada (deduplicada por slave/registro).
  - El caso degenerado de todos los Slave ID a 0 se notifica y sale limpio en vez de morir en silencio.

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
