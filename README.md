# HelmMagControl
**BHC2000** is a desktop application designed to control three Wanptek power supplies through the **Modbus RTU** protocol. The main goal of the project is to generate a controlled magnetic field on three axes (X, Y, Z) using Helmholtz coils, where each axis is driven by an independent power supply.

The following describes the external functionality of the project — what a user can do with the application.

### **Graphical Interface and Manual Control**

The application provides a graphical user interface (GUI) that centralizes the control and monitoring of the three power supplies.

* **Main Control Panel**:
    * **Connection Settings**: Before starting communication, the user configures the serial port parameters: **COM port**, **baud rate**, **data bits**, **parity** and **stop bits**.
    * **Modbus Addresses**: The Modbus addresses (Slave IDs) for each of the three supplies must be specified, associated with axes **X, Y and Z**.
    * **Connection**: A **"Connect"** button starts communication with the power supplies over the configured serial port.
    * **TCP Server**: The application can act as a TCP server for remote control. The user can specify the port the server listens on for incoming connections.

* **Per-Channel View (X, Y, Z axes)**:
    The interface shows three identical panels, each representing a power supply for one coil (X axis, Y axis, Z axis). Each panel, of class `TfWanptekDisplay`, mimics the front panel of a Wanptek supply and provides:
    * **LED Displays**: Real-time **voltage, current and power** readings for each supply.
    * **Voltage and Current Setting**: The user can adjust the target voltage and current values with **rotary dials**.
    * **Output Control**: An **(On/Off)** switch enables or disables each supply's output individually.
    * **Over-Current Protection (OCP)**: A switch enables or disables the OCP function.
    * **Status Indicators**: LEDs show the supply state, such as the operating mode (**CV — Constant Voltage** or **CC — Constant Current**), whether the output is active (**Power**), or whether OCP has tripped.
<img width="705" height="741" alt="gui" src="https://github.com/user-attachments/assets/538794dc-a9fe-423e-9381-89c8bfad3ff2" />

### **Languages**

The application is available in **Spanish** and **English**. A dropdown at the top of the control panel switches the language **on the fly**, without restarting: all labels, status messages and the window title itself are translated. The chosen language is saved in the Windows registry and remembered across sessions; on first launch the system language is detected automatically (falling back to Spanish). The TCP server protocol stays in English, as it is a machine-facing interface.

### **Communication**

* **Modbus on a Dedicated Thread**: All Modbus communication is handled on a separate execution thread (`TModbusSerialThread`) so as not to block the user interface. This thread periodically reads the supplies' status and sends the write commands the user generates by interacting with the interface.

### **Remote Control (TCP Server)**

One of the most advanced features of the project is its ability to be controlled remotely over a TCP connection. This allows experiments to be automated or the magnetic-field generation system to be integrated into a larger control system. The server implements a protocol based on simple text commands.

* **Supported Commands**:
    * `PING`: Check the connection.
    * `ALL OFF`: Turn off all supply outputs.
    * `READ ALL`: Return the full status of the three supplies.
    * `SET V<n> <value>`: Set the voltage of channel `n`.
    * `SET I<n> <value>`: Set the current of channel `n`.
    * `OUT <n> ON|OFF`: Turn the output of channel `n` on or off.
    * `GET V<n>`, `GET I<n>`, `GET P<n>`: Get the voltage, current or power of a specific channel.
    * `STATUS <n>`: Query the status of a channel.

In short, **BHC2000** is a complete and robust tool that allows both detailed manual control and remote automation of three power supplies for the precise generation of magnetic fields, making it ideal for laboratory and research environments.

### **Cross-platform version (Lazarus / Free Pascal)**

In addition to the original Delphi version (`Source/` folder), the project includes a **cross-platform reimplementation in Lazarus / Free Pascal** (`lazarus/` folder), which compiles and runs on **Windows, Linux and macOS** without a commercial license, keeping functional parity with the Delphi version on Windows.

* **`lazarus/app/`** — full application equivalent to BHC2000: the three channels over the real Wanptek KPS3020D front panel, serial port configuration, ES/EN language selector, Modbus thread and TCP server with the same text protocol.
* **`lazarus/poc/`** — portable core (Modbus protocol, `ISerialTransport` serial layer, TCP server with `ssockets`) and *headless* proof-of-concept tests.
* **`lazarus/gui/`** — the hand-drawn 7-segment display widget.

The original JVCL components (LED displays, dials, switches) are replaced by **custom widgets drawn on `Canvas`** (`TSeg7Display`, `TKnob`, `TToggle`), valid on any LCL *widgetset*. Serial communication is isolated behind the `ISerialTransport` interface, with back-ends for Windows (WinAPI) and POSIX (termios).

Build: `lazbuild lazarus/app/bhc.lpi` (requires Lazarus / FPC).
