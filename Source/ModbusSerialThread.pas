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
    Port: string; // 'COM1', 'COM2', etc.
    BaudRate: DWORD; // 9600, 19200, 38400, etc.
    DataBits: Byte; // 7, 8
    StopBits: Byte; // 1, 2
    Parity: Char; // 'N', 'E', 'O'
    Timeout: DWORD; // Timeout en ms
  end;

  // Estructura para comandos de escritura asíncrona
  TModbusWriteCommand = record
    Command: TModbusCommand;
    SlaveID: Byte;
    Address: Word;
    Value: Word;
    Values: TArray<Word>; // Para escrituras múltiples
    BitValue: Boolean; // Para coils
    BitValues: TArray<Boolean>; // Para múltiples coils
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

  // Eventos para notificar datos
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

    // Cola para comandos de escritura asíncrona
    FWriteQueue: TQueue<TModbusWriteCommand>;
    FWriteQueueLock: TCriticalSection;

    // Eventos
    FOnDataReceived: TModbusDataEvent;
    FOnError: TModbusErrorEvent;
    FOnConnected: TNotifyEvent;
    FOnDisconnected: TNotifyEvent;
    fProcessTime: Cardinal;

    // Métodos internos
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
    function ReadFromSerial(var Buffer: TBytes; ExpectedLength: Integer): Boolean;
    procedure FlushSerialBuffers;

    // Métodos para sincronización con el hilo principal
    procedure SyncDataReceived;
    procedure SyncError;
    procedure SyncConnected;
    procedure SyncDisconnected;
    function getQueueEmpty: Boolean;

  var
    FLastReadData: TModbusReadData;
    FLastErrorMsg: string;
    FidxSlave: Integer;
  protected
    procedure Execute; override;

  public
    constructor Create(const SerialConfig: TSerialConfig; SlaveIDs: TBytes; ReadCommand: TModbusCommand; ReadInterval: Cardinal);
    destructor Destroy; override;

    // Métodos públicos
    procedure Stop;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; Value: Word); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; BitValue: Boolean); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const Values: TArray<Word>); overload;
    procedure AddWriteCommand(Command: TModbusCommand; SlaveID: Byte; Address: Word; const BitValues: TArray<Boolean>); overload;

    // Propiedades
    property Connected: Boolean read FConnected;
    property ReadInterval: Cardinal read FReadInterval write FReadInterval;
    property SerialConfig: TSerialConfig read FSerialConfig write FSerialConfig;
    property ProcessTime: Cardinal read fProcessTime write fProcessTime;
    property QueueEmpty: Boolean read getQueueEmpty;
    // Eventos
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

procedure TModbusSerialThread.Execute;
var
  LastReadTime: Cardinal;
  ReadData: TModbusReadData;
  aux: Integer;
  procedure NextEquipo;
  begin
    repeat
      FidxSlave := (FidxSlave + 1) mod 3;
    until FSlaveIDs[FidxSlave] <> 0;
  end;

begin
  LastReadTime := 0;
  FidxSlave := 0;
  aux := 0;
  for var i := 0 to length(FSlaveIDs) - 1 do
    aux := aux + FSlaveIDs[i];
  if aux = 0 then
    raise Exception.Create('No hay direcciones modbus definidas.');
  while not Terminated do
  begin
    // Intentar abrir puerto serie si no está conectado
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
        // Esperar antes de reintentar conexión
        if FStopEvent.WaitFor(2000) = wrSignaled then
          Break;
        Continue;
      end;
    end;

    try
      // Procesar cola de escrituras asíncronas
      ProcessWriteQueue;

      // Realizar lectura periódica
      if (GetTickCount - LastReadTime) >= FReadInterval then
      begin
        NextEquipo;
        fProcessTime := GetTickCount;
        ReadData := SendModbusCommand(FReadCommand, FSlaveIDs[FidxSlave], FStartAddress, FRegisterCount);
        fProcessTime := GetTickCount - fProcessTime;
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

      // Pequeña pausa para no saturar la CPU ni el puerto
      if FStopEvent.WaitFor(10) = wrSignaled then
        Break;

    except
      on E: Exception do
      begin
        CloseSerialPort;
        FConnected := False;
        Synchronize(SyncDisconnected);

        FLastErrorMsg := 'Excepción en hilo Modbus: ' + E.Message;
        Synchronize(SyncError);

        // Pausa antes de reintentar
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
    // Configurar DCB (Device Control Block)
    FillChar(DCB, SizeOf(DCB), 0);
    DCB.DCBlength := SizeOf(DCB);

    if not GetCommState(FSerialHandle, DCB) then
      Exit;

    DCB.BaudRate := FSerialConfig.BaudRate;
    DCB.ByteSize := FSerialConfig.DataBits;

    // Configurar bits de parada
    case FSerialConfig.StopBits of
      1:
        DCB.StopBits := ONESTOPBIT;
      2:
        DCB.StopBits := TWOSTOPBITS;
    end;

    // Configurar paridad
    case FSerialConfig.Parity of
      'N':
        DCB.Parity := NOPARITY;
      'E':
        DCB.Parity := EVENPARITY;
      'O':
        DCB.Parity := ODDPARITY;
    end;

    // Configuraciones para Modbus RTU
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

    // Configurar timeouts
    FillChar(Timeouts, SizeOf(Timeouts), 0);
    Timeouts.ReadIntervalTimeout := MAXDWORD;
    Timeouts.ReadTotalTimeoutConstant := FSerialConfig.Timeout;
    Timeouts.ReadTotalTimeoutMultiplier := 0;
    Timeouts.WriteTotalTimeoutConstant := FSerialConfig.Timeout;
    Timeouts.WriteTotalTimeoutMultiplier := 0;

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
  begin
    PurgeComm(FSerialHandle, PURGE_RXCLEAR or PURGE_TXCLEAR);
  end;
end;

function TModbusSerialThread.getQueueEmpty: Boolean;
begin
  Result := FWriteQueue.Count = 0;
end;

function TModbusSerialThread.WriteToSerial(const Data: TBytes): Boolean;
var
  BytesWritten: DWORD;
begin
  Result := False;
  if FSerialHandle = INVALID_HANDLE_VALUE then
    Exit;

  try
    Result := WriteFile(FSerialHandle, Data[0], length(Data), BytesWritten, nil) and (BytesWritten = DWORD(length(Data)));

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

function TModbusSerialThread.ReadFromSerial(var Buffer: TBytes; ExpectedLength: Integer): Boolean;
var
  BytesRead, TotalRead: DWORD;
  StartTime: DWORD;
  TempBuffer: array [0 .. 255] of Byte;
begin
  Result := False;
  TotalRead := 0;
  StartTime := GetTickCount;
  SetLength(Buffer, 0);

  if FSerialHandle = INVALID_HANDLE_VALUE then
    Exit;

  try
    while (TotalRead < DWORD(ExpectedLength)) and ((GetTickCount - StartTime) < FSerialConfig.Timeout) do
    begin
      BytesRead := 0;
      if ReadFile(FSerialHandle, TempBuffer[0], SizeOf(TempBuffer), BytesRead, nil) and (BytesRead > 0) then
      begin
        SetLength(Buffer, length(Buffer) + BytesRead);
        Move(TempBuffer[0], Buffer[TotalRead], BytesRead);
        TotalRead := TotalRead + BytesRead;

        // Para Modbus RTU, si no hay más datos en un tiempo, asumir fin de trama
        if ExpectedLength <= 0 then
        begin
          Sleep(10); // Esperar un poco más
          if not ReadFile(FSerialHandle, TempBuffer[0], 1, BytesRead, nil) or (BytesRead = 0) then
            Break
          else
          begin
            SetLength(Buffer, length(Buffer) + 1);
            Buffer[TotalRead] := TempBuffer[0];
            TotalRead := TotalRead + 1;
          end;
        end;
      end
      else
        Sleep(1);
    end;

    Result := TotalRead > 0;

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
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SlaveID := SlaveID;
  Result.Address := Address;
  Result.Count := Count;
  Result.Timestamp := Now;

  try
    // Limpiar buffers antes de enviar
    FlushSerialBuffers;

    // Construir trama Modbus RTU
    Frame := BuildModbusFrame(Command, SlaveID, Address, Count);

    // Calcular longitud esperada de respuesta
    case Command of
      mcReadHoldingRegisters, mcReadInputRegisters:
        ExpectedResponseLength := 5 + (Count * 2); // SlaveID + Function + ByteCount + Data + CRC
      mcReadCoils, mcReadDiscreteInputs:
        ExpectedResponseLength := 5 + ((Count + 7) div 8); // SlaveID + Function + ByteCount + Data + CRC
    else
      ExpectedResponseLength := 8; // Respuesta estándar
    end;

    // Esperar tiempo entre tramas (3.5 caracteres mínimo para Modbus RTU)
    Sleep(4);

    // Enviar comando
    if not WriteToSerial(Frame) then
    begin
      Result.ErrorMessage := 'Error enviando comando';
      Exit;
    end;

    // Leer respuesta
    if not ReadFromSerial(Response, ExpectedResponseLength) then
    begin
      Result.ErrorMessage := 'Timeout esperando respuesta';
      Exit;
    end;

    if length(Response) < 3 then
    begin
      Result.ErrorMessage := 'Respuesta muy corta';
      Exit;
    end;

    // Verificar CRC
    if length(Response) >= 2 then
    begin
      var
      CRCReceived := Response[length(Response) - 2] or (Response[length(Response) - 1] shl 8);
      var
      CRCCalculated := CalculateCRC(Copy(Response, 0, length(Response) - 2));
      if CRCReceived <> CRCCalculated then
      begin
        Result.ErrorMessage := 'Error de CRC en respuesta';
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
          SetLength(Values, length(WriteCmd.BitValues));
          for i := 0 to High(WriteCmd.BitValues) do
            Values[i] := IfThen(WriteCmd.BitValues[i], 1, 0);
          Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, length(WriteCmd.BitValues), Values);
        end;

      mcWriteMultipleRegisters:
        Frame := BuildModbusFrame(WriteCmd.Command, WriteCmd.SlaveID, WriteCmd.Address, length(WriteCmd.Values), WriteCmd.Values);
    end;

    // Esperar tiempo entre tramas
    Sleep(4);

    // Enviar comando
    if not WriteToSerial(Frame) then
      Exit;

    // Leer respuesta de confirmación
    if not ReadFromSerial(Response, 8) then
      Exit;

    // Verificar que no sea una respuesta de error
    if (length(Response) >= 2) and ((Response[1] and $80) = 0) then
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
  i, ByteCount: Integer;
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
        ByteCount := length(Values) * 2;
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

        // Convertir bits a bytes
        for i := 0 to ByteCount - 1 do
        begin
          Frame[7 + i] := 0;
          var
            j: Integer;
          for j := 0 to 7 do
          begin
            if (i * 8 + j) < length(Values) then
              if Values[i * 8 + j] <> 0 then
                Frame[7 + i] := Frame[7 + i] or (1 shl j);
          end;
        end;
      end;
  end;

  // Calcular y agregar CRC
  Len := length(Frame);
  // SetLength(Frame, Len + 2);
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

  if length(Response) < 3 then
  begin
    Result.ErrorMessage := 'Respuesta muy corta';
    Exit;
  end;

  // Verificar función de respuesta
  if (Response[1] and $80) = $80 then
  begin
    Result.ErrorMessage := 'Error Modbus código: ' + IntToStr(Response[2]);
    Exit;
  end;

  case Command of
    mcReadHoldingRegisters, mcReadInputRegisters:
      begin
        if length(Response) < 5 then
        begin
          Result.ErrorMessage := 'Respuesta incompleta para registros';
          Exit;
        end;

        ByteCount := Response[2];
        SetLength(Result.Values, ByteCount div 2);
        for i := 0 to High(Result.Values) do
        begin
          Result.Values[i] := (Response[3 + i * 2] shl 8) or Response[4 + i * 2];
        end;
      end;

    mcReadCoils, mcReadDiscreteInputs:
      begin
        if length(Response) < 4 then
        begin
          Result.ErrorMessage := 'Respuesta incompleta para coils';
          Exit;
        end;

        ByteCount := Response[2];
        SetLength(Result.BitValues, Result.Count);
        for i := 0 to Result.Count - 1 do
        begin
          Result.BitValues[i] := (Response[3 + (i div 8)] and (1 shl (i mod 8))) <> 0;
        end;
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
        // Pequeña pausa entre comandos de escritura
        Sleep(10);
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
