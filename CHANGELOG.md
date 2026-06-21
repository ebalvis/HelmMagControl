# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.4.0] - 2026-06-20

### Added
- **Cross-platform version in Lazarus / Free Pascal** (`lazarus/` folder), with functional parity with the Delphi version on Windows:
  - Full application with the 3 channels over the real Wanptek KPS3020D front panel, serial port configuration, X/Y/Z addresses, refresh interval and server port.
  - **Spanish / English** internationalization on the fly (native LCL UTF-8).
  - Modbus RTU core (CRC, frames, parsing) and abstract serial layer `ISerialTransport` with Windows (WinAPI) and POSIX (termios) back-ends.
  - TCP server with the same text protocol (`PING`, `SET`, `GET`, `OUT`, `STATUS`, `READ ALL`, `ALL OFF`) on a separate thread, with marshalling to the main thread.
  - Custom widgets replacing the JVCL components: 7-segment display (`TSeg7Display`), rotary dial (`TKnob`) and switch (`TToggle`).

### Fixed (Delphi and Lazarus)
- Hardened error handling for the connection and the TCP server:
  - Retrying to connect with no port no longer freezes the interface.
  - Correct TCP server lifecycle (idempotent start, stop on disconnect).
  - The Lazarus TCP server no longer hangs when stopped with a connected, idle client (`SO_RCVTIMEO`).
  - A TCP command that raises an exception no longer takes the server down.
  - Honest connection status ("Connecting…") and server *bind* errors shown in the status bar.
  - The Modbus thread's write queue is bounded (deduplicated by slave/register).
  - The degenerate case of all Slave IDs at 0 is reported and exits cleanly instead of dying silently.

## [0.3.0] - 2026-06-19

### Added
- **Spanish / English** language selector (dropdown) with on-the-fly switching of the entire interface, including the application title.
- Persistence of the chosen language in the Windows registry; on first launch the system language is detected (fallback: Spanish).
- A **"ms"** unit hint next to the refresh-interval field.
- New `uLang` unit that centralizes all interface texts.

### Fixed
- **Thread safety** in the TCP remote control: operations on the interface are serialized to the main thread via `TThread.Synchronize`.
- The `READ ALL` command numbers channels from 1, consistent with the rest of the protocol.
- The `TTcpServerController` destructor marked as `override`: now correctly deactivates and frees the TCP server.
- Application shutdown: the Modbus thread is stopped and the TCP server is freed.
- The TCP protocol decimal separator is fixed to an invariant dot on both input and output.
- Fixed the accents in the Spanish messages (they were corrupted in the original source code).

### Internal
- Removed compiler *hints* and dead code.
