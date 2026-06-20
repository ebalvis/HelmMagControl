unit umbthread;
{ Hilo de sondeo Modbus RTU portado a FPC. Usa ISerialTransport (capa serie
  multiplataforma) y notifica a la GUI por Synchronize con metodos con nombre
  (FPC 3.2.2 no admite metodos anonimos, asi que no se usan). }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, umodbus_core, userial;

type
  TRegsEvent = procedure(Sender: TObject; SlaveID: Byte; const Regs: TMbWords) of object;
  TMsgEvent = procedure(Sender: TObject; const Msg: string) of object;

  TWriteItem = record
    SlaveID: Byte;
    Addr: Word;
    Vals: TMbWords;
  end;

  TModbusThread = class(TThread)
  private
    FCfg: TSerialConfig;
    FSlaves: array of Byte;
    FInterval: Integer;
    FSerial: ISerialTransport;
    FConnected: Boolean;
    FQueue: array of TWriteItem;
    FLock: TRTLCriticalSection;
    FIdx: Integer;
    FEvSlave: Byte;
    FEvRegs: TMbWords;
    FEvMsg: string;
    FOnData: TRegsEvent;
    FOnError: TMsgEvent;
    FOnConn: TMsgEvent;
    FOnDisc: TMsgEvent;
    procedure SyncData;
    procedure SyncErr;
    procedure SyncConn;
    procedure SyncDisc;
    function ReadSlave(SlaveID: Byte; out Regs: TMbWords): Boolean;
    procedure DrainQueue;
    function QueueEmpty: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const Cfg: TSerialConfig; const Slaves: array of Byte; IntervalMs: Integer);
    destructor Destroy; override;
    procedure AddWrite(SlaveID: Byte; Addr: Word; const Vals: array of Word);
    property Connected: Boolean read FConnected;
    property OnData: TRegsEvent read FOnData write FOnData;
    property OnError: TMsgEvent read FOnError write FOnError;
    property OnConnected: TMsgEvent read FOnConn write FOnConn;
    property OnDisconnected: TMsgEvent read FOnDisc write FOnDisc;
  end;

implementation

constructor TModbusThread.Create(const Cfg: TSerialConfig; const Slaves: array of Byte; IntervalMs: Integer);
var
  i: Integer;
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FCfg := Cfg;
  SetLength(FSlaves, Length(Slaves));
  for i := 0 to High(Slaves) do FSlaves[i] := Slaves[i];
  FInterval := IntervalMs;
  FConnected := False;
  FIdx := 0;
  InitCriticalSection(FLock);
end;

destructor TModbusThread.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

procedure TModbusThread.AddWrite(SlaveID: Byte; Addr: Word; const Vals: array of Word);
var
  it: TWriteItem;
  i: Integer;
begin
  it.SlaveID := SlaveID;
  it.Addr := Addr;
  SetLength(it.Vals, Length(Vals));
  for i := 0 to High(Vals) do it.Vals[i] := Vals[i];
  EnterCriticalSection(FLock);
  try
    SetLength(FQueue, Length(FQueue) + 1);
    FQueue[High(FQueue)] := it;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TModbusThread.QueueEmpty: Boolean;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FQueue) = 0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TModbusThread.ReadSlave(SlaveID: Byte; out Regs: TMbWords): Boolean;
var
  req, resp: TMbBytes;
  crcRecv, crcCalc: Word;
begin
  Result := False;
  SetLength(Regs, 0);
  req := BuildReadHolding(SlaveID, 0, 8);
  FSerial.Flush;
  if not FSerial.Write(req) then Exit;
  FSerial.Read(5 + 8 * 2, resp);
  if Length(resp) < 5 then Exit;
  crcRecv := resp[High(resp) - 1] or (resp[High(resp)] shl 8);
  crcCalc := ModbusCRC(Copy(resp, 0, Length(resp) - 2));
  if crcRecv <> crcCalc then Exit;
  Result := ParseRegisters(resp, Regs);
end;

procedure TModbusThread.DrainQueue;
var
  it: TWriteItem;
  frame, resp: TMbBytes;
begin
  while True do
  begin
    EnterCriticalSection(FLock);
    try
      if Length(FQueue) = 0 then Break;
      it := FQueue[0];
      if Length(FQueue) > 1 then
        Move(FQueue[1], FQueue[0], (Length(FQueue) - 1) * SizeOf(TWriteItem));
      SetLength(FQueue, Length(FQueue) - 1);
    finally
      LeaveCriticalSection(FLock);
    end;
    frame := BuildWriteMultiple(it.SlaveID, it.Addr, it.Vals);
    FSerial.Flush;
    if FSerial.Write(frame) then
      FSerial.Read(8, resp);
    Sleep(5);
  end;
end;

procedure TModbusThread.Execute;
var
  regs: TMbWords;
  lastRead: QWord;
  i, sum, waitK: Integer;
begin
  sum := 0;
  for i := 0 to High(FSlaves) do sum := sum + FSlaves[i];
  if sum = 0 then
  begin
    FEvMsg := 'No hay direcciones modbus definidas.';
    Synchronize(@SyncErr);
    Exit;
  end;

  FSerial := CreateSerialTransport;
  lastRead := 0;

  while not Terminated do
  begin
    if not FConnected then
    begin
      if FSerial.Open(FCfg) then
      begin
        FConnected := True;
        Synchronize(@SyncConn);
      end
      else
      begin
        FEvMsg := FSerial.LastError;
        Synchronize(@SyncErr);
        // espera ~2 s antes de reintentar, pero interrumpible: si llega
        // Terminate (Desconectar/cerrar) sale en <=100 ms, sin congelar la UI.
        for waitK := 1 to 20 do
        begin
          if Terminated then Break;
          Sleep(100);
        end;
        Continue;
      end;
    end;

    DrainQueue;

    if TThread.GetTickCount64 - lastRead >= QWord(FInterval) then
    begin
      // siguiente slave no nulo
      repeat
        FIdx := (FIdx + 1) mod Length(FSlaves);
      until (FSlaves[FIdx] <> 0) or (FIdx = 0);

      if FSlaves[FIdx] <> 0 then
      begin
        if ReadSlave(FSlaves[FIdx], regs) then
        begin
          FEvSlave := FSlaves[FIdx];
          FEvRegs := regs;
          Synchronize(@SyncData);
        end;
      end;
      lastRead := TThread.GetTickCount64;
    end;

    Sleep(5);
  end;

  if FConnected then FSerial.Close;
end;

procedure TModbusThread.SyncData;
begin
  if Assigned(FOnData) then FOnData(Self, FEvSlave, FEvRegs);
end;

procedure TModbusThread.SyncErr;
begin
  if Assigned(FOnError) then FOnError(Self, FEvMsg);
end;

procedure TModbusThread.SyncConn;
begin
  if Assigned(FOnConn) then FOnConn(Self, '');
end;

procedure TModbusThread.SyncDisc;
begin
  if Assigned(FOnDisc) then FOnDisc(Self, '');
end;

end.
