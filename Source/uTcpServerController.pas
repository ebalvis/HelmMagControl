unit uTcpServerController;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, IdBaseComponent, IdComponent, IdCustomTCPServer, IdTCPServer, IdContext, IdGlobal,
  System.StrUtils,
  System.RegularExpressions;

type
  // Interfaz que tu capa de control real debe implementar (puedes adaptarla).
  IPowerSupplyBackend = interface
    ['{B76F8C6C-1B33-47A9-9D3C-7E6B1EED1B3F}']
    function ChannelCount: Integer;

    // Setpoints
    procedure SetVoltage(AChannel: Integer; AVolts: Double);
    procedure SetCurrent(AChannel: Integer; AAmps: Double);
    procedure SetOutput(AChannel: Integer; AOn: Boolean);

    // Medidas
    function GetVoltage(AChannel: Integer): Double;
    function GetCurrent(AChannel: Integer): Double;
    function GetPower(AChannel: Integer): Double;
    function GetOutput(AChannel: Integer): Boolean; // ON/OFF

    // Global
    procedure AllOff;

    // Opcional: estado extendido en texto (alarma, modo, etc.)
    function GetStatusText(AChannel: Integer): string;
  end;

  TTcpServerController = class(TObject)
    IdTCPServer: TIdTCPServer;
  private
    FBackend: IPowerSupplyBackend;
    function ParseAndExecute(const Cmd: string): string;
    function HandleSetVoltage(const M: TMatch): string;
    function HandleSetCurrent(const M: TMatch): string;
    function HandleOutput(const M: TMatch): string;
    function HandleGetVoltage(const M: TMatch): string;
    function HandleGetCurrent(const M: TMatch): string;
    function HandleGetPower(const M: TMatch): string;
    function HandleStatus(const M: TMatch): string;
    function HandleReadAll: string;
    procedure IdTCPServerConnect(AContext: TIdContext);
  public
    procedure Start(APort: Integer);
    procedure Stop;
    procedure SetBackend(const ABackend: IPowerSupplyBackend);
    procedure IdTCPServerExecute(AContext: TIdContext);
    Constructor Create;
    Destructor Destroy;
  end;

implementation

{ TTcpServerController }
constructor TTcpServerController.Create;
begin
  inherited Create;
  IdTCPServer := TIdTCPServer.Create(nil);

  // ENLAZAR EVENTOS ANTES DE ACTIVAR
  IdTCPServer.OnExecute := IdTCPServerExecute;
  IdTCPServer.OnConnect := IdTCPServerConnect;

  // (opcional)
  IdTCPServer.TerminateWaitTime := 2000;
end;

destructor TTcpServerController.Destroy;
begin
  if Assigned(IdTCPServer) and IdTCPServer.Active then
    IdTCPServer.Active := False;
  IdTCPServer.Free;
  inherited;
end;

procedure TTcpServerController.Start(APort: Integer);
begin
  IdTCPServer.DefaultPort := APort;
  IdTCPServer.Active := True;
end;

procedure TTcpServerController.Stop;
begin
  IdTCPServer.Active := False;
end;

procedure TTcpServerController.SetBackend(const ABackend: IPowerSupplyBackend);
begin
  FBackend := ABackend;
end;

procedure TTcpServerController.IdTCPServerConnect(AContext: TIdContext);
begin
  // Establece UTF-8 como codificación por defecto
  AContext.Connection.IOHandler.DefStringEncoding := IndyTextEncoding_UTF8();
  // AContext.Connection.IOHandler.def.DefAnsiEncoding := IndyTextEncoding_UTF8();
end;

procedure TTcpServerController.IdTCPServerExecute(AContext: TIdContext);
var
  LCmd, LResp: string;
begin
  LCmd := AContext.Connection.IOHandler.ReadLn;
  try
    LResp := ParseAndExecute(Trim(LCmd));
  except
    on E: Exception do
      LResp := 'ERROR ' + E.ClassName + ': ' + E.Message;
  end;

  // Ahora ya no necesitas pasar encoding cada vez
  AContext.Connection.IOHandler.WriteLn(LResp);
end;

function TTcpServerController.ParseAndExecute(const Cmd: string): string;
var
  M: TMatch;
begin
  if Cmd = '' then
    Exit('ERROR EmptyCommand');

  // PING
  if SameText(Cmd, 'PING') then
    Exit('OK PONG');

  // ALL OFF
  if SameText(Cmd, 'ALL OFF') then
  begin
    if Assigned(FBackend) then
      FBackend.AllOff;
    Exit('OK ALL OFF');
  end;

  // READ ALL
  if SameText(Cmd, 'READ ALL') then
    Exit(HandleReadAll);

  // SET V{n} {val}
  M := TRegEx.Match(Cmd, '^SET\s+V(\d+)\s+([+-]?\d+(?:\.\d+)?)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleSetVoltage(M));

  // SET I{n} {val}
  M := TRegEx.Match(Cmd, '^SET\s+I(\d+)\s+([+-]?\d+(?:\.\d+)?)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleSetCurrent(M));

  // OUT {n} ON|OFF
  M := TRegEx.Match(Cmd, '^OUT\s+(\d+)\s+(ON|OFF)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleOutput(M));

  // GET V{n}
  M := TRegEx.Match(Cmd, '^GET\s+V(\d+)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleGetVoltage(M));

  // GET I{n}
  M := TRegEx.Match(Cmd, '^GET\s+I(\d+)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleGetCurrent(M));

  // GET P{n}
  M := TRegEx.Match(Cmd, '^GET\s+P(\d+)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleGetPower(M));

  // STATUS {n}
  M := TRegEx.Match(Cmd, '^STATUS\s+(\d+)$', [roIgnoreCase]);
  if M.Success then
    Exit(HandleStatus(M));

  Result := 'ERROR UnknownCommand';
end;

function EnsureChannel(const S: string; MaxCh: Integer): Integer;
begin
  Result := StrToIntDef(S, 0);
  if (Result < 1) or (Result > MaxCh) then
    raise Exception.CreateFmt('InvalidChannel %s (1..%d)', [S, MaxCh]);
end;

function TTcpServerController.HandleSetVoltage(const M: TMatch): string;
var
  ch: Integer;
  val: Double;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  var
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  val := StrToFloat(M.Groups[2].Value, FS);

  // TODO: si tu backend requiere sincronización con GUI, usa TThread.Queue
  FBackend.SetVoltage(ch-1, val);
  Result := Format('OK SET V%d=%.6f', [ch, val]);
end;

function TTcpServerController.HandleSetCurrent(const M: TMatch): string;
var
  ch: Integer;
  val: Double;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  var
  FS := TFormatSettings.Create;
  FS.DecimalSeparator := '.';
  val := StrToFloat(M.Groups[2].Value, FS);
  FBackend.SetCurrent(ch-1, val);
  Result := Format('OK SET I%d=%.6f', [ch, val]);
end;

function TTcpServerController.HandleOutput(const M: TMatch): string;
var
  ch: Integer;
  onoff: Boolean;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  onoff := SameText(M.Groups[2].Value, 'ON');
  FBackend.SetOutput(ch-1, onoff);
  Result := Format('OK OUT %d %s', [ch, IfThen(onoff, 'ON', 'OFF')]);
end;

function TTcpServerController.HandleGetVoltage(const M: TMatch): string;
var
  ch: Integer;
  v: Double;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  v := FBackend.GetVoltage(ch-1);
  Result := Format('OK V%d=%.6f', [ch, v]);
end;

function TTcpServerController.HandleGetCurrent(const M: TMatch): string;
var
  ch: Integer;
  i: Double;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  i := FBackend.GetCurrent(ch-1);
  Result := Format('OK I%d=%.6f', [ch, i]);
end;

function TTcpServerController.HandleGetPower(const M: TMatch): string;
var
  ch: Integer;
  v, i, p: Double;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  v := FBackend.GetVoltage(ch-1);
  i := FBackend.GetCurrent(ch-1);
  p := FBackend.GetPower(ch-1);
  Result := Format('OK P%d=%.6f', [ch, p]);
end;

function TTcpServerController.HandleStatus(const M: TMatch): string;
var
  ch: Integer;
  onoff: Boolean;
  extra: string;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  ch := EnsureChannel(M.Groups[1].Value, FBackend.ChannelCount);
  onoff := FBackend.GetOutput(ch-1);
  if Assigned(FBackend) then
    extra := FBackend.GetStatusText(ch-1);
  Result := Format('OK STATUS %d %s%s', [ch, IfThen(onoff, 'ON', 'OFF'), IfThen(extra <> '', ' ' + extra, '')]);
end;

function TTcpServerController.HandleReadAll: string;
var
  n, ch: Integer;
  parts: TArray<string>;
begin
  if not Assigned(FBackend) then
    Exit('ERROR NoBackend');
  n := FBackend.ChannelCount;
  SetLength(parts, n);
  for ch := 0 to n-1 do
    parts[ch] := Format('CH%d V=%.6f I=%.6f OUT=%s', [ch, FBackend.GetVoltage(ch), FBackend.GetCurrent(ch), IfThen(FBackend.GetOutput(ch), 'ON', 'OFF')]);
  Result := 'OK ' + string.Join(' | ', parts);
end;

end.
