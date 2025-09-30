# HelmMagControl
Este proyecto Delphi, llamado **BHC2000**, es una aplicación de escritorio diseñada para controlar tres fuentes de alimentación de la marca Wanptek a través del protocolo **Modbus RTU**. El objetivo principal del proyecto es generar un campo magnético controlado en tres ejes (X, Y, Z) mediante bobinas de Helmholtz, donde cada eje es alimentado por una fuente de alimentación independiente.

A continuación se detalla la funcionalidad externa del proyecto, describiendo lo que un usuario puede hacer con la aplicación.

### **Interfaz Gráfica y Control Manual**

[cite_start]La aplicación presenta una interfaz gráfica de usuario (GUI) que centraliza el control y la monitorización de las tres fuentes de alimentación[cite: 3].

* **Panel de Control Principal**:
    * [cite_start]**Configuración de la Conexión**: Antes de iniciar la comunicación, el usuario debe configurar los parámetros del puerto serie, incluyendo el **puerto COM**, la **velocidad (baud rate)**, los **bits de datos**, la **paridad** y los **bits de parada**[cite: 2, 3].
    * [cite_start]**Direcciones Modbus**: Se deben especificar las direcciones Modbus (Slave ID) para cada una de las tres fuentes, asociadas a los ejes **X, Y y Z**[cite: 2, 3].
    * [cite_start]**Conexión**: Un botón de **"Conectar"** inicia la comunicación con las fuentes de alimentación a través del puerto serie configurado[cite: 2, 3].
    * **Servidor TCP**: La aplicación puede actuar como un servidor TCP para control remoto. [cite_start]El usuario puede especificar el puerto en el que el servidor escuchará las conexiones entrantes[cite: 2].

* **Visualización por Canal (Ejes X, Y, Z)**:
    [cite_start]La interfaz muestra tres paneles idénticos, cada uno representando una fuente de alimentación para una bobina (Eje X, Eje Y, Eje Z)[cite: 3]. [cite_start]Cada panel, de la clase `TfWanptekDisplay`, simula el frontal de una fuente Wanptek y ofrece la siguiente funcionalidad[cite: 6]:
    * [cite_start]**Pantallas LED**: Muestra en tiempo real los valores de **voltaje, corriente y potencia** de cada fuente[cite: 5, 6].
    * [cite_start]**Ajuste de Voltaje y Corriente**: El usuario puede ajustar los valores de voltaje y corriente deseados mediante **diales giratorios**[cite: 5, 6].
    * [cite_start]**Control de Salida**: Un interruptor **(On/Off)** permite habilitar o deshabilitar la salida de cada fuente de forma individual[cite: 5, 6].
    * [cite_start]**Protección contra Sobrecorriente (OCP)**: Se incluye un interruptor para activar o desactivar la función OCP[cite: 5, 6].
    * [cite_start]**Indicadores de Estado**: LEDs en la interfaz indican el estado de la fuente, como el modo de operación (**CV - Voltaje Constante** o **CC - Corriente Constante**), si la salida está activa (**Power**) o si se ha activado la protección OCP[cite: 5, 6].

### **Comunicación**

* [cite_start]**Modbus en Hilo Dedicado**: Toda la comunicación Modbus se gestiona en un hilo de ejecución separado (`TModbusSerialThread`) para no bloquear la interfaz de usuario[cite: 1]. [cite_start]Este hilo se encarga de leer periódicamente el estado de las fuentes y de enviar los comandos de escritura que el usuario genera al interactuar con la interfaz[cite: 1].

### **Funcionalidad de Control Remoto (Servidor TCP)**

[cite_start]Una de las características más avanzadas del proyecto es su capacidad de ser controlado de forma remota a través de una conexión TCP[cite: 4]. Esto permite automatizar experimentos o integrar el sistema de generación de campo magnético en un sistema de control más grande. [cite_start]El servidor implementa un protocolo basado en comandos de texto simples[cite: 4].

* **Comandos Soportados**:
    * `PING`: Para verificar la conexión.
    * `ALL OFF`: Apaga todas las salidas de las fuentes.
    * `READ ALL`: Devuelve el estado completo de las tres fuentes.
    * `SET V<n> <valor>`: Fija el voltaje del canal `n`.
    * `SET I<n> <valor>`: Fija la corriente del canal `n`.
    * `OUT <n> ON|OFF`: Enciende o apaga la salida del canal `n`.
    * `GET V<n>`, `GET I<n>`, `GET P<n>`: Obtiene el voltaje, la corriente o la potencia de un canal específico.
    * `STATUS <n>`: Consulta el estado de un canal.

En resumen, el proyecto **BHC2000** es una herramienta completa y robusta que permite tanto el control manual detallado como la automatización remota de tres fuentes de alimentación para la generación precisa de campos magnéticos, lo que lo hace ideal para entornos de laboratorio e investigación.
