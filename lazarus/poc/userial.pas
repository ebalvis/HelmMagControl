unit userial;
{ Capa serie multiplataforma sin dependencias externas.
  - ISerialTransport: contrato que aisla la E/S serie del protocolo Modbus.
  - Backend Windows (WinAPI, portado de la version Delphi) -> compilado/verificado.
  - Backend POSIX (termios, Linux/macOS) -> compila solo en Unix; pendiente de
    verificacion sobre hardware real.
  El factory CreateSerialTransport devuelve la implementacion de la plataforma. }
{$mode objfpc}{$H+}

interface

uses
  umodbus_core; // TMbBytes

type
  TSerialConfig = record
    Port: string;       // 'COM5' (Windows) o '/dev/ttyUSB0' (POSIX)
    BaudRate: Integer;
    DataBits: Byte;     // 5..8
    StopBits: Byte;     // 1 o 2
    Parity: Char;       // 'N','E','O'
    TimeoutMs: Integer;
  end;

  ISerialTransport = interface
    ['{6E2C0B4A-2F1D-4C3E-9A77-7C2B1E9D4A10}']
    function Open(const Cfg: TSerialConfig): Boolean;
    procedure Close;
    function IsOpen: Boolean;
    procedure Flush;
    function Write(const Data: TMbBytes): Boolean;
    function Read(ExpectedLen: Integer; out Data: TMbBytes): Boolean;
    function LastError: string;
  end;

function CreateSerialTransport: ISerialTransport;

implementation

uses
  SysUtils
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$IFDEF UNIX}, BaseUnix, termio{$ENDIF};

{$IFDEF MSWINDOWS}
type
  TWinSerial = class(TInterfacedObject, ISerialTransport)
  private
    FHandle: THandle;
    FErr: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Open(const Cfg: TSerialConfig): Boolean;
    procedure Close;
    function IsOpen: Boolean;
    procedure Flush;
    function Write(const Data: TMbBytes): Boolean;
    function Read(ExpectedLen: Integer; out Data: TMbBytes): Boolean;
    function LastError: string;
  end;

constructor TWinSerial.Create;
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;
end;

destructor TWinSerial.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TWinSerial.Open(const Cfg: TSerialConfig): Boolean;
var
  dcb: TDCB;
  tmo: TCommTimeouts;
  name: string;
begin
  Result := False;
  Close;
  name := '\\.\' + Cfg.Port; // soporta COM10+ y COM1..9
  FHandle := CreateFile(PChar(name), GENERIC_READ or GENERIC_WRITE, 0, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if FHandle = INVALID_HANDLE_VALUE then
  begin
    FErr := Format('No se pudo abrir %s (error %d)', [Cfg.Port, GetLastError]);
    Exit;
  end;

  FillChar(dcb, SizeOf(dcb), 0);
  dcb.DCBlength := SizeOf(dcb);
  if not GetCommState(FHandle, dcb) then
  begin
    FErr := 'GetCommState fallo'; Close; Exit;
  end;

  dcb.BaudRate := Cfg.BaudRate;
  dcb.ByteSize := Cfg.DataBits;
  case Cfg.StopBits of
    2: dcb.StopBits := TWOSTOPBITS;
  else
    dcb.StopBits := ONESTOPBIT;
  end;
  case UpCase(Cfg.Parity) of
    'E': dcb.Parity := EVENPARITY;
    'O': dcb.Parity := ODDPARITY;
  else
    dcb.Parity := NOPARITY;
  end;
  dcb.Flags := 1; // fBinary
  if dcb.Parity <> NOPARITY then
    dcb.Flags := dcb.Flags or 2; // fParity

  if not SetCommState(FHandle, dcb) then
  begin
    FErr := 'SetCommState fallo'; Close; Exit;
  end;

  // Timeouts estilo Modbus RTU: ReadFile retorna al pasar el tiempo total.
  FillChar(tmo, SizeOf(tmo), 0);
  tmo.ReadIntervalTimeout := 20;
  tmo.ReadTotalTimeoutMultiplier := 0;
  tmo.ReadTotalTimeoutConstant := Cfg.TimeoutMs;
  tmo.WriteTotalTimeoutMultiplier := 0;
  tmo.WriteTotalTimeoutConstant := 100;
  if not SetCommTimeouts(FHandle, tmo) then
  begin
    FErr := 'SetCommTimeouts fallo'; Close; Exit;
  end;

  Flush;
  Result := True;
end;

procedure TWinSerial.Close;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
end;

function TWinSerial.IsOpen: Boolean;
begin
  Result := FHandle <> INVALID_HANDLE_VALUE;
end;

procedure TWinSerial.Flush;
begin
  if IsOpen then
    PurgeComm(FHandle, PURGE_RXCLEAR or PURGE_TXCLEAR);
end;

function TWinSerial.Write(const Data: TMbBytes): Boolean;
var
  written: DWORD;
begin
  if not IsOpen then Exit(False);
  if Length(Data) = 0 then Exit(True);
  written := 0;
  if WriteFile(FHandle, Data[0], DWORD(Length(Data)), written, nil) then
    Result := (written = DWORD(Length(Data)))
  else
    Result := False;
  if Result then
    FlushFileBuffers(FHandle)
  else
    FErr := 'WriteFile fallo';
end;

function TWinSerial.Read(ExpectedLen: Integer; out Data: TMbBytes): Boolean;
var
  buf: array [0 .. 1023] of Byte;
  total, got: DWORD;
begin
  SetLength(Data, 0);
  if not IsOpen then Exit(False);
  total := 0;
  while total < DWORD(ExpectedLen) do
  begin
    got := 0;
    if ReadFile(FHandle, buf[total], DWORD(ExpectedLen) - total, got, nil) then
    begin
      if got > 0 then
        total := total + got
      else
        Break; // timeout (COMMTIMEOUTS)
    end
    else
      Break; // error
  end;
  if total > 0 then
  begin
    SetLength(Data, total);
    Move(buf[0], Data[0], total);
  end;
  Result := total >= DWORD(ExpectedLen);
end;

function TWinSerial.LastError: string;
begin
  Result := FErr;
end;
{$ENDIF MSWINDOWS}

{$IFDEF UNIX}
type
  TPosixSerial = class(TInterfacedObject, ISerialTransport)
  private
    FFd: cint;
    FErr: string;
    FTimeoutMs: Integer;
    function BaudConst(B: Integer): cuint;
  public
    constructor Create;
    destructor Destroy; override;
    function Open(const Cfg: TSerialConfig): Boolean;
    procedure Close;
    function IsOpen: Boolean;
    procedure Flush;
    function Write(const Data: TMbBytes): Boolean;
    function Read(ExpectedLen: Integer; out Data: TMbBytes): Boolean;
    function LastError: string;
  end;

constructor TPosixSerial.Create;
begin
  inherited Create;
  FFd := -1;
end;

destructor TPosixSerial.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TPosixSerial.BaudConst(B: Integer): cuint;
begin
  case B of
    9600:   Result := B9600;
    19200:  Result := B19200;
    38400:  Result := B38400;
    57600:  Result := B57600;
    115200: Result := B115200;
  else
    Result := B19200;
  end;
end;

function TPosixSerial.Open(const Cfg: TSerialConfig): Boolean;
var
  t: Termios;
  spd: cuint;
begin
  Result := False;
  Close;
  FTimeoutMs := Cfg.TimeoutMs;
  FFd := FpOpen(Cfg.Port, O_RDWR or O_NOCTTY or O_NONBLOCK);
  if FFd < 0 then
  begin
    FErr := Format('No se pudo abrir %s (errno %d)', [Cfg.Port, fpgeterrno]);
    Exit;
  end;

  FillChar(t, SizeOf(t), 0);
  if tcgetattr(FFd, t) <> 0 then
  begin
    FErr := 'tcgetattr fallo'; Close; Exit;
  end;

  spd := BaudConst(Cfg.BaudRate);
  cfsetispeed(t, spd);
  cfsetospeed(t, spd);

  // Modo raw
  t.c_cflag := t.c_cflag or cuint(CREAD or CLOCAL);
  t.c_cflag := t.c_cflag and not cuint(CSIZE);
  case Cfg.DataBits of
    5: t.c_cflag := t.c_cflag or cuint(CS5);
    6: t.c_cflag := t.c_cflag or cuint(CS6);
    7: t.c_cflag := t.c_cflag or cuint(CS7);
  else
    t.c_cflag := t.c_cflag or cuint(CS8);
  end;
  // Paridad
  case UpCase(Cfg.Parity) of
    'E': begin t.c_cflag := t.c_cflag or cuint(PARENB);
               t.c_cflag := t.c_cflag and not cuint(PARODD); end;
    'O': t.c_cflag := t.c_cflag or cuint(PARENB or PARODD);
  else
    t.c_cflag := t.c_cflag and not cuint(PARENB);
  end;
  // Bits de parada
  if Cfg.StopBits = 2 then
    t.c_cflag := t.c_cflag or cuint(CSTOPB)
  else
    t.c_cflag := t.c_cflag and not cuint(CSTOPB);

  t.c_lflag := 0;                 // sin canonico, sin echo
  t.c_iflag := cuint(IGNPAR);     // ignora errores de paridad
  t.c_oflag := 0;
  t.c_cc[VMIN] := 0;
  t.c_cc[VTIME] := 0;             // no bloqueante; el timeout lo gestionamos por reloj

  if tcsetattr(FFd, TCSANOW, t) <> 0 then
  begin
    FErr := 'tcsetattr fallo'; Close; Exit;
  end;

  Flush;
  Result := True;
end;

procedure TPosixSerial.Close;
begin
  if FFd >= 0 then
  begin
    fpClose(FFd);
    FFd := -1;
  end;
end;

function TPosixSerial.IsOpen: Boolean;
begin
  Result := FFd >= 0;
end;

procedure TPosixSerial.Flush;
begin
  if IsOpen then
    fpfsync(FFd);
end;

function TPosixSerial.Write(const Data: TMbBytes): Boolean;
var
  n: ssize_t;
begin
  if not IsOpen then Exit(False);
  if Length(Data) = 0 then Exit(True);
  n := fpWrite(FFd, Data[0], Length(Data));
  Result := n = ssize_t(Length(Data));
  if not Result then FErr := 'write fallo';
end;

function TPosixSerial.Read(ExpectedLen: Integer; out Data: TMbBytes): Boolean;
var
  buf: array [0 .. 1023] of Byte;
  total: Integer;
  n: ssize_t;
  deadline: QWord;
begin
  SetLength(Data, 0);
  if not IsOpen then Exit(False);
  total := 0;
  deadline := GetTickCount64 + QWord(FTimeoutMs);
  while (total < ExpectedLen) and (GetTickCount64 < deadline) do
  begin
    n := fpRead(FFd, buf[total], ExpectedLen - total);
    if n > 0 then
      total := total + n
    else
      fpNanoSleep(1); // 1 ms aprox; cede CPU mientras llegan bytes
  end;
  if total > 0 then
  begin
    SetLength(Data, total);
    Move(buf[0], Data[0], total);
  end;
  Result := total >= ExpectedLen;
end;

function TPosixSerial.LastError: string;
begin
  Result := FErr;
end;
{$ENDIF UNIX}

function CreateSerialTransport: ISerialTransport;
begin
  {$IFDEF MSWINDOWS}
  Result := TWinSerial.Create;
  {$ENDIF}
  {$IFDEF UNIX}
  Result := TPosixSerial.Create;
  {$ENDIF}
end;

end.
