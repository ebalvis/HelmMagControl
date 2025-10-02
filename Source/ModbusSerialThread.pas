unit ModbusSerialThread;

interface

uses
  Classes, SysUtils, Windows, SyncObjs, Generics.Collections, System.Math;

type
  // Tipos de comando Modbus
  TModbusCommand = (mcReadCoils, mcReadDiscreteInputs, mcReadHoldingRegisters, mcReadInputRegisters, mcWriteSingleCoil, mcWriteSingleRegister,
    mcWriteMultipleCoils, mcWriteMultipleRegisters);

  // Configuración del puerto serie
  TSerialConfig = record
    Port: string;
    BaudRate: DWORD;
    DataBits: Byte;
    StopBits: Byte;
    Parity: Char;
    Timeout: DWORD;
  end;

  // Estructura para comandos de escritura asíncrona
  TModbusWriteCommand = record
    Command: TModbusCommand;
    SlaveID: Byte;
    Address: Word;
    Value: Word;
    Values: TArray<Word>;
    BitValue: Boolean;
    BitValues: TArray<Boolean>;
  end;

  // Estructura para datos leídos
  TModbusReadData = record
    SlaveID: Byte;
    Address: Word;
    Count: Word;
    Values: TArray<Word>;
    BitValues: TArray<Boolean>;
    Success: Boolean;
    ErrorMessage: string;
    Timestamp: TDateTime;
  end;

  // Eventos
  TModbusDataEvent = procedure(Sender: TObject; const Data: TModbusReadData) of object;
  TModbusErrorEvent = procedure(Sender: TObject; const ErrorMsg: string) of object;

  TModbusSerialThread = class(TThread)
  private
    FSerialHandle: THandle;
    FSerialConfig: TSerialConfig;
    FReadInterval: Cardinal;
    FSlaveIDs: TBytes;
    FStartAddress: Word;
    FRegisterCount: Word;
    FReadCommand: TModbusCommand;
    FConnected: Boolean;
    FStopEvent: TEvent;

    FWriteQueue: TQueue<TModbusWriteCommand>;
    FWriteQueueLock: TCriticalSection;

    FOnDataReceived: TModbusDataEvent;
    FOnError: TModbusErrorEvent;
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    FProcessTime: Cardinal;

    // MEJORA: Buffer de lectura reutilizable
    FReadBuffer: array [0 .. 511] of Byte;

    function OpenSerialPort: Boolean;
    procedure CloseSerialPort;
    function ConfigureSerialPort: Boolean;
    function SendModbusCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; Count: Word = 1): TModbusReadData;
    function WriteModbusCommand(const WriteCmd: TModbusWriteCommand): Boolean;
    function BuildModbusFrame(Command: TModbusCommand; SlaveID: Byte; Address: Word; CountOrValue: Word; const Values: TArray<Word> = nil): TBytes;
    function ParseModbusResponse(const Response: TBytes; Command: TModbusCommand): TModbusReadData;
    function CalculateCRC(const Data: TBytes): Word;
    procedure ProcessWriteQueue;
    function WriteToSerial(const Data: TBytes): Boolean;
    // MEJORA: Nueva función optimizada
    function ReadFromSerialOptimized(var Buffer: TBytes; ExpectedLength: Integer): Boolean;
    procedure FlushSerialBuffers;
    // MEJORA: Calcular tiempo entre caracteres
    function CalculateCharTime: Cardinal;

    procedure SyncDataReceived;
    procedure SyncError;
    procedure SyncConnected;
    procedure SyncDisconnected;
    function GetQueueEmpty: Boolean;

  var
    FLastReadData: TModbusReadData;
    FLastErrorMsg: string;
    FidxSlave: Integer;

  protected
    procedure Execute; override;

  public
    constructor Create(const SerialConfig: TSerialConfig; SlaveIDs: TBytes; ReadCommand: TModbusCommand; ReadInterval: Cardinal);
    destructor Destroy; override;

    procedure Stop;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; Value: Word); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; BitValue: Boolean); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const Values: TArray<Word>); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const BitValues: TArray<Boolean>); overload;

    property Connected: Boolean read FConnected;
    property ReadInterval: Cardinal read FReadInterval write FReadInterval;
    property SerialConfig: TSerialConfig read FSerialConfig write FSerialConfig;
    property ProcessTime: Cardinal read FProcessTime write FProcessTime;
    property QueueEmpty: Boolean read GetQueueEmpty;

    property OnDataReceived: TModbusDataEvent read FOnDataReceived write FOnDataReceived;
    property OnError: TModbusErrorEvent read FOnError write FOnError;
    property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
    property OnDisconnected: TNotifyEvent read FOnDisconnected write FOnDisconnected;
  end;

implementation

{ TModbusSerialThread }

constructor TModbusSerialThread.Create(const SerialConfig: TSerialConfig; SlaveIDs: TBytes; ReadCommand: TModbusCommand; ReadInterval: Cardinal);
begin
  inherited Create(False);
  FSerialConfig := SerialConfig;
  FSlaveIDs := SlaveIDs;
  FStartAddress := 0;
  FRegisterCount := 8;
  FReadCommand := ReadCommand;
  FReadInterval := ReadInterval;
  FConnected := False;
  FSerialHandle := INVALID_HANDLE_VALUE;

  FWriteQueue := TQueue<TModbusWriteCommand>.Create;
  FWriteQueueLock := TCriticalSection.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');

  FreeOnTerminate := False;
end;

destructor TModbusSerialThread.Destroy;
begin
  Stop;
  FWriteQueueLock.Free;
  FWriteQueue.Free;
  FStopEvent.Free;
  inherited Destroy;
end;

procedure TModbusSerialThread.Stop;
begin
  Terminate;
  FStopEvent.SetEvent;
  WaitFor;
end;

// MEJORA: Calcular tiempo entre caracteres basado en baudrate
function TModbusSerialThread.CalculateCharTime: Cardinal;
var
  BitsPerChar: Integer;
  CharsPerSecond: Double;
  TimePerChar: Double;
begin
  // Bits por carácter = data bits + start bit + stop bits + parity bit (si existe)
  BitsPerChar := FSerialConfig.DataBits + 1 + FSerialConfig.StopBits;
  if FSerialConfig.Parity <> 'N' then
    Inc(BitsPerChar);

  CharsPerSecond := FSerialConfig.BaudRate / BitsPerChar;
  TimePerChar := 1000.0 / CharsPerSecond; // en milisegundos

  // Tiempo de 3.5 caracteres (estándar Modbus RTU)
  Result := Round(TimePerChar * 3.5);

  // Mínimo 2ms, máximo 20ms
  if Result < 2 then
    Result := 2
  else if Result > 20 then
    Result := 20;
end;

procedure TModbusSerialThread.Execute;
var
  LastReadTime: Cardinal;
  ReadData: TModbusReadData;
  aux: Integer;

  procedure NextEquipo;
  begin
    repeat
      FidxSlave := (FidxSlave + 1) mod Length(FSlaveIDs);
    until (FSlaveIDs[FidxSlave] <> 0) or (FidxSlave = 0);
  end;

begin
  LastReadTime := 0;
  FidxSlave := 0;
  aux := 0;

  for var i := 0 to Length(FSlaveIDs) - 1 do
    aux := aux + FSlaveIDs[i];

  if aux = 0 then
    raise Exception.Create('No hay direcciones modbus definidas.');

  while not Terminated do
  begin
    if not FConnected then
    begin
      if OpenSerialPort and ConfigureSerialPort then
      begin
        FConnected := True;
        Synchronize(SyncConnected);
        FlushSerialBuffers;
      end
      else
      begin
        if FStopEvent.WaitFor(2000) = wrSignaled then
          Break;
        Continue;
      end;
    end;

    try
      ProcessWriteQueue;

      if (GetTickCount - LastReadTime) >= FReadInterval then
      begin
        NextEquipo;
        FProcessTime := GetTickCount;
        ReadData := SendModbusCommand(FReadCommand, FSlaveIDs[FidxSlave], FStartAddress, FRegisterCount);
        FProcessTime := GetTickCount - FProcessTime;

        if ReadData.Success then
        begin
          FLastReadData := ReadData;
          Synchronize(SyncDataReceived);
        end
        else
        begin
          FLastErrorMsg := 'Error en lectura periódica: ' + ReadData.ErrorMessage;
          Synchronize(SyncError);
        end;

        LastReadTime := GetTickCount;
      end;

      // MEJORA: Pausa más corta
      if FStopEvent.WaitFor(5) = wrSignaled then
        Break;

    except
      on E: Exception do
      begin
        CloseSerialPort;
        FConnected := False;
        Synchronize(SyncDisconnected);

        FLastErrorMsg := 'Excepción en hilo Modbus: ' + E.Message;
        Synchronize(SyncError);

        if FStopEvent.WaitFor(2000) = wrSignaled then
          Break;
      end;
    end;
  end;

  CloseSerialPort;
end;

function TModbusSerialThread.OpenSerialPort: Boolean;
begin
  Result := False;
  try
    if FSerialHandle <> INVALID_HANDLE_VALUE then
      CloseSerialPort;

    FSerialHandle := CreateFile(PChar('\\.\' + FSerialConfig.Port), GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);

    Result := FSerialHandle <> INVALID_HANDLE_VALUE;

    if not Result then
    begin
      FLastErrorMsg := 'No se pudo abrir el puerto ' + FSerialConfig.Port + '. Error: ' + IntToStr(GetLastError);
      Synchronize(SyncError);
    end;

  except
    on E: Exception do
    begin
      FLastErrorMsg := 'Error al abrir puerto serie: ' + E.Message;
      Synchronize(SyncError);
    end;
  end;
end;

procedure TModbusSerialThread.CloseSerialPort;
begin
  try
    if FSerialHandle <> INVALID_HANDLE_VALUE then
    begin
      CloseHandle(FSerialHandle);
      FSerialHandle := INVALID_HANDLE_VALUE;
    end;
  except
    // Ignorar errores de cierre
  end;
end;

function TModbusSerialThread.ConfigureSerialPort: Boolean;
var
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  Result := False;

  if FSerialHandle = INVALID_HANDLE_VALUE then
    Exit;

  try
    FillChar(DCB, SizeOf(DCB), 0);
    DCB.DCBlength := SizeOf(DCB);

    if not GetCommState(FSerialHandle, DCB) then
      Exit;

    DCB.BaudRate := FSerialConfig.BaudRate;
    DCB.ByteSize := FSerialConfig.DataBits;

    case FSerialConfig.StopBits of
      1:
        DCB.StopBits := ONESTOPBIT;
      2:
        DCB.StopBits := TWOSTOPBITS;
    end;

    case FSerialConfig.Parity of
      'N':
        DCB.Parity := NOPARITY;
      'E':
        DCB.Parity := EVENPARITY;
      'O':
        DCB.Parity := ODDPARITY;
    end;

    DCB.Flags := 0;
    DCB.Flags := DCB.Flags or $01; // fBinary
    if DCB.Parity <> NOPARITY then
      DCB.Flags := DCB.Flags or $02; // fParity

    DCB.XonLim := 2048;
    DCB.XoffLim := 512;
    DCB.XonChar := #17;
    DCB.XoffChar := #19;

    if not SetCommState(FSerialHandle, DCB) then
      Exit;

    // MEJORA CRÍTICA: Timeouts optimizados para Modbus RTU
    FillChar(Timeouts, SizeOf(Timeouts), 0);

    // ReadIntervalTimeout: tiempo máximo entre bytes
    // Usar tiempo de 1.5 caracteres para detectar fin de trama rápidamente
    Timeouts.ReadIntervalTimeout := Max(10, CalculateCharTime div 2);

    // ReadTotalTimeoutMultiplier y Constant para timeout total
    Timeouts.ReadTotalTimeoutMultiplier := 0;
    Timeouts.ReadTotalTimeoutConstant := Max(100, FSerialConfig.Timeout);

    // Timeouts de escritura más cortos
    Timeouts.WriteTotalTimeoutMultiplier := 0;
    Timeouts.WriteTotalTimeoutConstant := 100;

    Result := SetCommTimeouts(FSerialHandle, Timeouts);

  except
    on E: Exception do
    begin
      FLastErrorMsg := 'Error configurando puerto serie: ' + E.Message;
      Synchronize(SyncError);
    end;
  end;
end;

procedure TModbusSerialThread.FlushSerialBuffers;
begin
  if FSerialHandle <> INVALID_HANDLE_VALUE then
    PurgeComm(FSerialHandle, PURGE_RXCLEAR or PURGE_TXCLEAR);
end;

function TModbusSerialThread.GetQueueEmpty: Boolean;
begin
  FWriteQueueLock.Enter;
  try
    Result := FWriteQueue.Count = 0;
  finally
    FWriteQueueLock.Leave;
  end;
end;

function TModbusSerialThread.WriteToSerial(const Data: TBytes): Boolean;
var
  BytesWritten: DWORD;
begin
  Result := False;
  if FSerialHandle = INVALID_HANDLE_VALUE then
    Exit;

  try
    Result := WriteFile(FSerialHandle, Data[0], Length(Data), BytesWritten, nil) and (BytesWritten = DWORD(Length(Data)));

    if Result then
      FlushFileBuffers(FSerialHandle);

  except
    on E: Exception do
    begin
      FLastErrorMsg := 'Error escribiendo al puerto serie: ' + E.Message;
      Synchronize(SyncError);
    end;
  end;
end;

// MEJORA CRÍTICA: Nueva función de lectura optimizada
function TModbusSerialThread.ReadFromSerialOptimized(var Buffer: TBytes; ExpectedLength: Integer): Boolean;
var
  BytesRead, TotalRead: DWORD;
  StartTime: DWORD;
  LastByteTime: DWORD;
  InterCharTimeout: Cardinal;
begin
  Result := False;
  TotalRead := 0;
  StartTime := GetTickCount;
  LastByteTime := StartTime;
  SetLength(Buffer, 0);

  if FSerialHandle = INVALID_HANDLE_VALUE then
    Exit;

  // Tiempo entre caracteres (1.5 caracteres según Modbus RTU)
  InterCharTimeout := Max(5, CalculateCharTime div 2);

  try
    // Leer hasta obtener la longitud esperada o timeout
    while (TotalRead < DWORD(ExpectedLength)) and ((GetTickCount - StartTime) < FSerialConfig.Timeout) do
    begin
      BytesRead := 0;

      // Leer lo que esté disponible
      if ReadFile(FSerialHandle, FReadBuffer[TotalRead], SizeOf(FReadBuffer) - TotalRead, BytesRead, nil) and (BytesRead > 0) then
      begin
        TotalRead := TotalRead + BytesRead;
        LastByteTime := GetTickCount;

        // Si hemos leído suficiente, salir
        if (ExpectedLength > 0) and (TotalRead >= DWORD(ExpectedLength)) then
          Break;
      end
      else
      begin
        // Si no hay datos y ha pasado el tiempo entre caracteres,
        // asumir fin de trama
        if (TotalRead > 0) and ((GetTickCount - LastByteTime) >= InterCharTimeout) then
          Break;

        // Pequeña pausa para no saturar CPU
        Sleep(1);
      end;
    end;

    if TotalRead > 0 then
    begin
      SetLength(Buffer, TotalRead);
      Move(FReadBuffer[0], Buffer[0], TotalRead);
      Result := True;
    end;

  except
    on E: Exception do
    begin
      FLastErrorMsg := 'Error leyendo del puerto serie: ' + E.Message;
      Synchronize(SyncError);
    end;
  end;
end;

function TModbusSerialThread.SendModbusCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; Count: Word): TModbusReadData;
var
  Frame: TBytes;
  Response: TBytes;
  ExpectedResponseLength: Integer;
  InterFrameDelay: Cardinal;
  CRCReceived, CRCCalculated: Word;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SlaveID := SlaveID;
  Result.Address := Address;
  Result.Count := Count;
  Result.Timestamp := Now;

  try
    // Limpiar buffers
    FlushSerialBuffers;

    Frame := BuildModbusFrame(Command, SlaveID, Address, Count);

    // Calcular longitud esperada
    case Command of
      mcReadHoldingRegisters, mcReadInputRegisters:
        ExpectedResponseLength := 5 + (Count * 2);
      mcReadCoils, mcReadDiscreteInputs:
        ExpectedResponseLength := 5 + ((Count + 7) div 8);
    else
      ExpectedResponseLength := 8;
    end;

    // MEJORA: Tiempo entre tramas basado en baudrate (3.5 caracteres)
    InterFrameDelay := CalculateCharTime;
    Sleep(InterFrameDelay);

    // Enviar comando
    if not WriteToSerial(Frame) then
    begin
      Result.ErrorMessage := 'Error enviando comando';
      Exit;
    end;

    // MEJORA: Usar función de lectura optimizada
    if not ReadFromSerialOptimized(Response, ExpectedResponseLength) then
    begin
      Result.ErrorMessage := 'Timeout esperando respuesta';
      Exit;
    end;

    if Length(Response) < 3 then
    begin
      Result.ErrorMessage := 'Respuesta muy corta';
      Exit;
    end;

    // Verificar CRC
    if Length(Response) >= 2 then
    begin
      CRCReceived := Response[Length(Response) - 2] or (Response[Length(Response) - 1] shl 8);
      CRCCalculated := CalculateCRC(Copy(Response, 0, Length(Response) - 2));

      if CRCReceived <> CRCCalculated then
      begin
        Result.ErrorMessage := Format('Error de CRC (Calc: $%4.4x, Recv: $%4.4x)', [CRCCalculated, CRCReceived]);
        Exit;
      end;
    end;

    // Parsear respuesta
    Result := ParseModbusResponse(Response, Command);
    Result.SlaveID := SlaveID;
    Result.Address := Address;
    Result.Count := Count;
    Result.Timestamp := Now;

  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TModbusSerialThread.WriteModbusCommand(const WriteCmd: TModbusWriteCommand): Boolean;
var
  Frame: TBytes;
  Response: TBytes;
  Values: TArray<Word>;
  i: Integer;
  InterFrameDelay: Cardinal;
begin
  Result := False;
  try
    FlushSerialBuffers;

    case WriteCmd.Command of
      mcWriteSingleCoil:
        Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, IfThen(WriteCmd.BitValue, $FF00, $0000));

      mcWriteSingleRegister:
        Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, WriteCmd.Value);

      mcWriteMultipleCoils:
        begin
          SetLength(Values, Length(WriteCmd.BitValues));
          for i := 0 to High(WriteCmd.BitValues) do
            Values[i] := IfThen(WriteCmd.BitValues[i], 1, 0);
          Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, Length(WriteCmd.BitValues), Values);
        end;

      mcWriteMultipleRegisters:
        Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, Length(WriteCmd.Values), WriteCmd.Values);
    end;

    // MEJORA: Usar tiempo calculado entre tramas
    InterFrameDelay := CalculateCharTime;
    Sleep(InterFrameDelay);

    if not WriteToSerial(Frame) then
      Exit;

    // MEJORA: Usar función optimizada
    if not ReadFromSerialOptimized(Response, 8) then
      Exit;

    if (Length(Response) >= 2) and ((Response[1] and $80) = 0) then
      Result := True;

  except
    on E: Exception do
    begin
      FLastErrorMsg := 'Error en escritura: ' + E.Message;
      Synchronize(SyncError);
    end;
  end;
end;

function TModbusSerialThread.BuildModbusFrame(Command: TModbusCommand; SlaveID: Byte; Address: Word; CountOrValue: Word; const Values: TArray<Word>): TBytes;
var
  Frame: TBytes;
  Len: Integer;
  CRC: Word;
  i, j, ByteCount: Integer;
begin
  case Command of
    mcReadCoils:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $01;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcReadDiscreteInputs:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $02;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcReadHoldingRegisters:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $03;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcReadInputRegisters:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $04;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcWriteSingleCoil:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $05;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcWriteSingleRegister:
      begin
        SetLength(Frame, 8);
        Frame[0] := SlaveID;
        Frame[1] := $06;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
      end;

    mcWriteMultipleRegisters:
      begin
        ByteCount := Length(Values) * 2;
        SetLength(Frame, 9 + ByteCount);
        Frame[0] := SlaveID;
        Frame[1] := $10;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
        Frame[6] := ByteCount;

        for i := 0 to High(Values) do
        begin
          Frame[7 + i * 2] := Hi(Values[i]);
          Frame[8 + i * 2] := Lo(Values[i]);
        end;
      end;

    mcWriteMultipleCoils:
      begin
        ByteCount := (CountOrValue + 7) div 8;
        SetLength(Frame, 9 + ByteCount);
        Frame[0] := SlaveID;
        Frame[1] := $0F;
        Frame[2] := Hi(Address);
        Frame[3] := Lo(Address);
        Frame[4] := Hi(CountOrValue);
        Frame[5] := Lo(CountOrValue);
        Frame[6] := ByteCount;

        for i := 0 to ByteCount - 1 do
        begin
          Frame[7 + i] := 0;
          for j := 0 to 7 do
          begin
            if (i * 8 + j) < Length(Values) then
              if Values[i * 8 + j] <> 0 then
                Frame[7 + i] := Frame[7 + i] or (1 shl j);
          end;
        end;
      end;
  end;

  // Calcular y agregar CRC
  Len := Length(Frame);
  CRC := CalculateCRC(Copy(Frame, 0, Len - 2));
  Frame[Len - 2] := Lo(CRC);
  Frame[Len - 1] := Hi(CRC);

  Result := Frame;
end;

function TModbusSerialThread.ParseModbusResponse(const Response: TBytes; Command: TModbusCommand): TModbusReadData;
var
  i, ByteCount: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  if Length(Response) < 3 then
  begin
    Result.ErrorMessage := 'Respuesta muy corta';
    Exit;
  end;

  if (Response[1] and $80) = $80 then
  begin
    Result.ErrorMessage := 'Error Modbus código: ' + IntToStr(Response[2]);
    Exit;
  end;

  case Command of
    mcReadHoldingRegisters, mcReadInputRegisters:
      begin
        if Length(Response) < 5 then
        begin
          Result.ErrorMessage := 'Respuesta incompleta para registros';
          Exit;
        end;

        ByteCount := Response[2];
        SetLength(Result.Values, ByteCount div 2);
        for i := 0 to High(Result.Values) do
          Result.Values[i] := (Response[3 + i * 2] shl 8) or Response[4 + i * 2];
      end;

    mcReadCoils, mcReadDiscreteInputs:
      begin
        if Length(Response) < 4 then
        begin
          Result.ErrorMessage := 'Respuesta incompleta para coils';
          Exit;
        end;

        ByteCount := Response[2];
        SetLength(Result.BitValues, Result.Count);
        for i := 0 to Result.Count - 1 do
          Result.BitValues[i] := (Response[3 + (i div 8)] and (1 shl (i mod 8))) <> 0;
      end;
  end;

  Result.Success := True;
end;

function TModbusSerialThread.CalculateCRC(const Data: TBytes): Word;
var
  CRC: Word;
  i, j: Integer;
begin
  CRC := $FFFF;
  for i := 0 to High(Data) do
  begin
    CRC := CRC xor Data[i];
    for j := 0 to 7 do
    begin
      if (CRC and 1) = 1 then
        CRC := (CRC shr 1) xor $A001
      else
        CRC := CRC shr 1;
    end;
  end;
  Result := CRC;
end;

procedure TModbusSerialThread.ProcessWriteQueue;
var
  WriteCmd: TModbusWriteCommand;
begin
  FWriteQueueLock.Enter;
  try
    while FWriteQueue.Count > 0 do
    begin
      WriteCmd := FWriteQueue.Dequeue;
      FWriteQueueLock.Leave;
      try
        WriteModbusCommand(WriteCmd);
        // MEJORA: Pausa más corta
        Sleep(5);
      finally
        FWriteQueueLock.Enter;
      end;
    end;
  finally
    FWriteQueueLock.Leave;
  end;
end;

// Métodos para agregar comandos de escritura
procedure TModbusSerialThread.AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; Value: Word);
var
  WriteCmd: TModbusWriteCommand;
begin
  FillChar(WriteCmd, SizeOf(WriteCmd), 0);
  WriteCmd.Command := Command;
  WriteCmd.SlaveID := SlaveID;
  WriteCmd.Address := Address;
  WriteCmd.Value := Value;

  FWriteQueueLock.Enter;
  try
    FWriteQueue.Enqueue(WriteCmd);
  finally
    FWriteQueueLock.Leave;
  end;
end;

procedure TModbusSerialThread.AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; BitValue: Boolean);
var
  WriteCmd: TModbusWriteCommand;
begin
  FillChar(WriteCmd, SizeOf(WriteCmd), 0);
  WriteCmd.Command := Command;
  WriteCmd.SlaveID := SlaveID;
  WriteCmd.Address := Address;
  WriteCmd.BitValue := BitValue;

  FWriteQueueLock.Enter;
  try
    FWriteQueue.Enqueue(WriteCmd);
  finally
    FWriteQueueLock.Leave;
  end;
end;

procedure TModbusSerialThread.AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const Values: TArray<Word>);
var
  WriteCmd: TModbusWriteCommand;
begin
  FillChar(WriteCmd, SizeOf(WriteCmd), 0);
  WriteCmd.Command := Command;
  WriteCmd.SlaveID := SlaveID;
  WriteCmd.Address := Address;
  WriteCmd.Values := Copy(Values);

  FWriteQueueLock.Enter;
  try
    FWriteQueue.Enqueue(WriteCmd);
  finally
    FWriteQueueLock.Leave;
  end;
end;

procedure TModbusSerialThread.AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const BitValues: TArray<Boolean>);
var
  WriteCmd: TModbusWriteCommand;
begin
  FillChar(WriteCmd, SizeOf(WriteCmd), 0);
  WriteCmd.Command := Command;
  WriteCmd.SlaveID := SlaveID;
  WriteCmd.Address := Address;
  WriteCmd.BitValues := Copy(BitValues);

  FWriteQueueLock.Enter;
  try
    FWriteQueue.Enqueue(WriteCmd);
  finally
    FWriteQueueLock.Leave;
  end;
end;

// Métodos de sincronización
procedure TModbusSerialThread.SyncDataReceived;
begin
  if Assigned(FOnDataReceived) then
    FOnDataReceived(Self, FLastReadData);
end;

procedure TModbusSerialThread.SyncError;
begin
  if Assigned(FOnError) then
    FOnError(Self, FLastErrorMsg);
end;

procedure TModbusSerialThread.SyncConnected;
begin
  if Assigned(FOnConnected) then
    FOnConnected(Self);
end;

procedure TModbusSerialThread.SyncDisconnected;
begin
  if Assigned(FOnDisconnected) then
    FOnDisconnected(Self);
end;

end.
