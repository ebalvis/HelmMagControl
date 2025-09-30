# HelmMagControl
**BHC2000**, es una aplicación de escritorio diseñada para controlar tres fuentes de alimentación de la marca Wanptek a través del protocolo **Modbus RTU**. El objetivo principal del proyecto es generar un campo magnético controlado en tres ejes (X, Y, Z) mediante bobinas de Helmholtz, donde cada eje es alimentado por una fuente de alimentación independiente.

A continuación se detalla la funcionalidad externa del proyecto, describiendo lo que un usuario puede hacer con la aplicación.

### **Interfaz Gráfica y Control Manual**

La aplicación presenta una interfaz gráfica de usuario (GUI) que centraliza el control y la monitorización de las tres fuentes de alimentación.

* **Panel de Control Principal**:
    * **Configuración de la Conexión**: Antes de iniciar la comunicación, el usuario debe configurar los parámetros del puerto serie, incluyendo el **puerto COM**, la **velocidad (baud rate)**, los **bits de datos**, la **paridad** y los **bits de parada**.
    * **Direcciones Modbus**: Se deben especificar las direcciones Modbus (Slave ID) para cada una de las tres fuentes, asociadas a los ejes **X, Y y Z**.
    * **Conexión**: Un botón de **"Conectar"** inicia la comunicación con las fuentes de alimentación a través del puerto serie configurado.
    * **Servidor TCP**: La aplicación puede actuar como un servidor TCP para control remoto. El usuario puede especificar el puerto en el que el servidor escuchará las conexiones entrantes.

* **Visualización por Canal (Ejes X, Y, Z)**:
    La interfaz muestra tres paneles idénticos, cada uno representando una fuente de alimentación para una bobina (Eje X, Eje Y, Eje Z)[cite: 3]. Cada panel, de la clase `TfWanptekDisplay`, simula el frontal de una fuente Wanptek y ofrece la siguiente funcionalidad:
    * **Pantallas LED**: Muestra en tiempo real los valores de **voltaje, corriente y potencia** de cada fuente.
    * **Ajuste de Voltaje y Corriente**: El usuario puede ajustar los valores de voltaje y corriente deseados mediante **diales giratorios**.
    * **Control de Salida**: Un interruptor **(On/Off)** permite habilitar o deshabilitar la salida de cada fuente de forma individual.
    * **Protección contra Sobrecorriente (OCP)**: Se incluye un interruptor para activar o desactivar la función OCP.
    * **Indicadores de Estado**: LEDs en la interfaz indican el estado de la fuente, como el modo de operación (**CV - Voltaje Constante** o **CC - Corriente Constante**), si la salida está activa (**Power**) o si se ha activado la protección OCP.

### **Comunicación**

* **Modbus en Hilo Dedicado**: Toda la comunicación Modbus se gestiona en un hilo de ejecución separado (`TModbusSerialThread`) para no bloquear la interfaz de usuario[cite: 1]. Este hilo se encarga de leer periódicamente el estado de las fuentes y de enviar los comandos de escritura que el usuario genera al interactuar con la interfaz.

### **Funcionalidad de Control Remoto (Servidor TCP)**

Una de las características más avanzadas del proyecto es su capacidad de ser controlado de forma remota a través de una conexión TCP[cite: 4]. Esto permite automatizar experimentos o integrar el sistema de generación de campo magnético en un sistema de control más grande. El servidor implementa un protocolo basado en comandos de texto simples.

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
