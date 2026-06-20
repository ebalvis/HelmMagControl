unit umainform;
{ Formulario principal de la app LCL: configuracion serie, 3 paneles de canal,
  selector de idioma e integracion del hilo Modbus sobre ISerialTransport.
  Construido en codigo (sin .lfm). }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  ulang, umbthread, uwanptekpanelimg, userial, umodbus_core, utcpserver;

type
  TMainForm = class(TForm)
  private
    FThread: TModbusThread;
    FPanels: array [0 .. 2] of TWanptekPanelImg;
    FSlaveIDs: array [0 .. 2] of Byte;
    FTcp: TTcpServer;
    FFS: TFormatSettings;
    FCmdIn, FCmdOut: string;
    // config
    cmbPort, cmbBaud, cmbParity, cmbStop, cmbLang: TComboBox;
    edData, edX, edY, edZ, edInterval, edSrvPort: TEdit;
    btnConnect: TButton;
    status: TStatusBar;
    gbSerial, gbAddr, gbServer, gbParams: TGroupBox;
    lblPort, lblBaud, lblData, lblParity, lblStop, lblX, lblY, lblZ,
    lblSrvPort, lblInterval, lblMs, lblLang: TLabel;
    procedure ApplyLanguage;
    procedure BtnConnectClick(Sender: TObject);
    procedure LangChange(Sender: TObject);
    procedure OnData(Sender: TObject; SlaveID: Byte; const Regs: TMbWords);
    procedure OnConn(Sender: TObject; const Msg: string);
    procedure OnDisc(Sender: TObject; const Msg: string);
    procedure OnErr(Sender: TObject; const Msg: string);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
    // servidor TCP: ProcessCommand corre en el hilo del servidor y marshala
    // a DoProcess (hilo principal); ParseCmd accede a los paneles.
    function ProcessCommand(const Cmd: string): string;
    procedure DoProcess;
    function ParseCmd(const Cmd: string): string;
  public
    procedure BuildUI;
  end;

implementation

function L(AOwner: TWinControl; x, y, w: Integer; const cap: string): TLabel;
begin
  Result := TLabel.Create(AOwner);
  Result.Parent := AOwner;
  Result.SetBounds(x, y, w, 18);
  Result.Caption := cap;
end;

function E(AOwner: TWinControl; x, y, w: Integer; const txt: string): TEdit;
begin
  Result := TEdit.Create(AOwner);
  Result.Parent := AOwner;
  Result.SetBounds(x, y, w, 24);
  Result.Text := txt;
end;

function C(AOwner: TWinControl; x, y, w: Integer; const items: array of string): TComboBox;
var
  i: Integer;
begin
  Result := TComboBox.Create(AOwner);
  Result.Parent := AOwner;
  Result.SetBounds(x, y, w, 24);
  Result.Style := csDropDownList;
  for i := 0 to High(items) do Result.Items.Add(items[i]);
  if Result.Items.Count > 0 then Result.ItemIndex := 0;
end;

procedure TMainForm.BuildUI;
var
  ax, cx: Integer;
  sb: TScrollBox;
begin
  FFS := DefaultFormatSettings;
  FFS.DecimalSeparator := '.'; // protocolo TCP: punto invariante
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  ClientWidth := 768;
  ClientHeight := 800;

  // --- columna izquierda: 3 paneles de canal en un scrollbox (como el Delphi) ---
  sb := TScrollBox.Create(Self);
  sb.Parent := Self;
  sb.SetBounds(8, 8, 502, 770);
  sb.HorzScrollBar.Visible := False;
  for ax := 0 to 2 do
  begin
    FPanels[ax] := TWanptekPanelImg.CreatePanel(Self, ax, 1, CoilTitle(ax));
    FPanels[ax].Parent := sb;
    FPanels[ax].SetBounds(0, ax * 258, 482, 252);
  end;

  // --- columna derecha: configuracion ---
  cx := 522;

  cmbLang := C(Self, cx + 60, 8, 120, [LanguageName(lnEs), LanguageName(lnEn)]);
  lblLang := L(Self, cx, 11, 56, '');
  cmbLang.OnChange := @LangChange;

  btnConnect := TButton.Create(Self);
  btnConnect.Parent := Self;
  btnConnect.SetBounds(cx, 38, 240, 28);
  btnConnect.OnClick := @BtnConnectClick;

  gbSerial := TGroupBox.Create(Self);
  gbSerial.Parent := Self;
  gbSerial.SetBounds(cx, 74, 240, 178);
  lblPort   := L(gbSerial, 12, 22, 70, '');
  cmbPort   := C(gbSerial, 90, 19, 130, ['COM1','COM2','COM3','COM4','COM5','COM6','COM7']);
  lblBaud   := L(gbSerial, 12, 50, 70, '');
  cmbBaud   := C(gbSerial, 90, 47, 130, ['9600','19200','38400','57600','115200']);
  cmbBaud.ItemIndex := 1;
  lblData   := L(gbSerial, 12, 78, 70, '');
  edData    := E(gbSerial, 90, 75, 130, '8');
  lblParity := L(gbSerial, 12, 106, 70, '');
  cmbParity := C(gbSerial, 90, 103, 130, ['None','Even','Odd']);
  lblStop   := L(gbSerial, 12, 134, 70, '');
  cmbStop   := C(gbSerial, 90, 131, 130, ['1','2']);

  gbAddr := TGroupBox.Create(Self);
  gbAddr.Parent := Self;
  gbAddr.SetBounds(cx, 258, 240, 122);
  lblX := L(gbAddr, 12, 22, 60, '');  edX := E(gbAddr, 90, 19, 60, '1');
  lblY := L(gbAddr, 12, 50, 60, '');  edY := E(gbAddr, 90, 47, 60, '2');
  lblZ := L(gbAddr, 12, 78, 60, '');  edZ := E(gbAddr, 90, 75, 60, '3');

  gbParams := TGroupBox.Create(Self);
  gbParams.Parent := Self;
  gbParams.SetBounds(cx, 386, 240, 66);
  lblInterval := L(gbParams, 12, 22, 60, '');
  edInterval  := E(gbParams, 90, 19, 80, '1000');
  lblMs := L(gbParams, 176, 22, 30, 'ms');

  gbServer := TGroupBox.Create(Self);
  gbServer.Parent := Self;
  gbServer.SetBounds(cx, 458, 240, 66);
  lblSrvPort := L(gbServer, 12, 22, 60, '');
  edSrvPort  := E(gbServer, 90, 19, 80, '4444');

  status := TStatusBar.Create(Self);
  status.Parent := Self;
  status.SimplePanel := True;

  // idioma guardado/detectado
  SetLanguage(DetectDefaultLanguage);
  cmbLang.ItemIndex := Ord(CurrentLanguage);

  OnClose := @DoClose;
  ApplyLanguage;
end;

procedure TMainForm.ApplyLanguage;
var
  ax: Integer;
begin
  Caption := Tr(siAppTitle);
  lblLang.Caption := Tr(siLblLang);
  gbSerial.Caption := Tr(siGbSerial);
  lblPort.Caption := Tr(siLblPort);
  lblBaud.Caption := Tr(siLblBaud);
  lblData.Caption := Tr(siLblData);
  lblParity.Caption := Tr(siLblParity);
  lblStop.Caption := Tr(siLblStop);
  gbAddr.Caption := Tr(siGbAddr);
  lblX.Caption := Tr(siLblX);
  lblY.Caption := Tr(siLblY);
  lblZ.Caption := Tr(siLblZ);
  gbServer.Caption := Tr(siGbServer);
  lblSrvPort.Caption := Tr(siLblSrvPort);
  gbParams.Caption := Tr(siGbParams);
  lblInterval.Caption := Tr(siLblInterval);

  if Assigned(FThread) then
    btnConnect.Caption := Tr(siDisconnect)
  else
    btnConnect.Caption := Tr(siConnect);

  for ax := 0 to 2 do
    FPanels[ax].SetTitle(CoilTitle(ax));
end;

procedure TMainForm.LangChange(Sender: TObject);
begin
  SetLanguage(TLanguage(cmbLang.ItemIndex));
  ApplyLanguage;
end;

procedure TMainForm.BtnConnectClick(Sender: TObject);
var
  cfg: TSerialConfig;
  slaves: array [0 .. 2] of Byte;
  ax: Integer;
begin
  if Assigned(FThread) then
  begin
    if Assigned(FTcp) then begin FTcp.Stop; FreeAndNil(FTcp); end;
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
    for ax := 0 to 2 do FPanels[ax].SetThread(nil);
    status.SimpleText := Tr(siDisconnected);
    ApplyLanguage;
    Exit;
  end;

  cfg.Port := cmbPort.Text;
  cfg.BaudRate := StrToIntDef(cmbBaud.Text, 19200);
  cfg.DataBits := StrToIntDef(edData.Text, 8);
  cfg.StopBits := StrToIntDef(cmbStop.Text, 1);
  case cmbParity.ItemIndex of
    1: cfg.Parity := 'E';
    2: cfg.Parity := 'O';
  else
    cfg.Parity := 'N';
  end;
  cfg.TimeoutMs := 1000;

  slaves[0] := StrToIntDef(edX.Text, 1);
  slaves[1] := StrToIntDef(edY.Text, 2);
  slaves[2] := StrToIntDef(edZ.Text, 3);
  for ax := 0 to 2 do
  begin
    FSlaveIDs[ax] := slaves[ax];
    FPanels[ax].SetSlaveID(slaves[ax]);
  end;

  FThread := TModbusThread.Create(cfg, slaves, StrToIntDef(edInterval.Text, 1000));
  FThread.OnData := @OnData;
  FThread.OnConnected := @OnConn;
  FThread.OnDisconnected := @OnDisc;
  FThread.OnError := @OnErr;
  for ax := 0 to 2 do
    FPanels[ax].SetThread(FThread);

  FTcp := TTcpServer.Create(StrToIntDef(edSrvPort.Text, 4444), @ProcessCommand);
  FTcp.Start;

  ApplyLanguage;
end;

procedure TMainForm.OnData(Sender: TObject; SlaveID: Byte; const Regs: TMbWords);
var
  ax: Integer;
begin
  for ax := 0 to 2 do
    if FSlaveIDs[ax] = SlaveID then
      FPanels[ax].UpdateRegs(Regs);
end;

procedure TMainForm.OnConn(Sender: TObject; const Msg: string);
begin
  status.SimpleText := Tr(siConnected);
end;

procedure TMainForm.OnDisc(Sender: TObject; const Msg: string);
begin
  status.SimpleText := Tr(siDisconnected);
end;

procedure TMainForm.OnErr(Sender: TObject; const Msg: string);
begin
  status.SimpleText := 'ERROR: ' + Msg;
end;

procedure TMainForm.DoClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if Assigned(FTcp) then begin FTcp.Stop; FreeAndNil(FTcp); end;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  CloseAction := caFree;
  Application.Terminate;
end;

function TMainForm.ProcessCommand(const Cmd: string): string;
begin
  // corre en el hilo del servidor TCP -> marshala el procesado al hilo principal
  FCmdIn := Cmd;
  TThread.Synchronize(nil, @DoProcess);
  Result := FCmdOut;
end;

procedure TMainForm.DoProcess;
begin
  FCmdOut := ParseCmd(FCmdIn);
end;

function TMainForm.ParseCmd(const Cmd: string): string;

  function ChOK(x: Integer): Boolean;
  begin Result := (x >= 1) and (x <= 3); end;

  function ChanNum(const tok: string): Integer;
  begin
    if Length(tok) >= 2 then Result := StrToIntDef(Copy(tok, 2, Length(tok) - 1), 0)
    else Result := 0;
  end;

  function OnOff(b: Boolean): string;
  begin if b then Result := 'ON' else Result := 'OFF'; end;

var
  t: array of string;
  cur: string;
  i, n: Integer;
  letter: Char;
  val: Double;
begin
  if Cmd = '' then Exit('ERROR EmptyCommand');
  if SameText(Cmd, 'PING') then Exit('OK PONG');
  if SameText(Cmd, 'ALL OFF') then
  begin
    for n := 0 to 2 do FPanels[n].RemoteSetOutput(False);
    Exit('OK ALL OFF');
  end;
  if SameText(Cmd, 'READ ALL') then
  begin
    Result := 'OK';
    for n := 1 to 3 do
      Result := Result + Format(' CH%d V=%.6f I=%.6f OUT=%s',
        [n, FPanels[n-1].MeasV, FPanels[n-1].MeasI, OnOff(FPanels[n-1].OutputOn)], FFS);
    Exit;
  end;

  // tokenizar por espacios
  SetLength(t, 0); cur := '';
  for i := 1 to Length(Cmd) do
    if Cmd[i] = ' ' then
    begin
      if cur <> '' then begin SetLength(t, Length(t) + 1); t[High(t)] := cur; cur := ''; end;
    end
    else cur := cur + Cmd[i];
  if cur <> '' then begin SetLength(t, Length(t) + 1); t[High(t)] := cur; end;

  if (Length(t) = 3) and SameText(t[0], 'SET') and (Length(t[1]) >= 2) then
  begin
    letter := UpCase(t[1][1]); n := ChanNum(t[1]);
    if not ChOK(n) then Exit('ERROR InvalidChannel');
    if not TryStrToFloat(t[2], val, FFS) then Exit('ERROR BadValue');
    case letter of
      'V': begin FPanels[n-1].RemoteSetV(val); Exit(Format('OK SET V%d=%.6f', [n, val], FFS)); end;
      'I': begin FPanels[n-1].RemoteSetI(val); Exit(Format('OK SET I%d=%.6f', [n, val], FFS)); end;
    end;
    Exit('ERROR UnknownCommand');
  end;

  if (Length(t) = 3) and SameText(t[0], 'OUT') then
  begin
    n := StrToIntDef(t[1], 0);
    if not ChOK(n) then Exit('ERROR InvalidChannel');
    FPanels[n-1].RemoteSetOutput(SameText(t[2], 'ON'));
    Exit(Format('OK OUT %d %s', [n, OnOff(SameText(t[2], 'ON'))]));
  end;

  if (Length(t) = 2) and SameText(t[0], 'GET') and (Length(t[1]) >= 2) then
  begin
    letter := UpCase(t[1][1]); n := ChanNum(t[1]);
    if not ChOK(n) then Exit('ERROR InvalidChannel');
    case letter of
      'V': Exit(Format('OK V%d=%.6f', [n, FPanels[n-1].MeasV], FFS));
      'I': Exit(Format('OK I%d=%.6f', [n, FPanels[n-1].MeasI], FFS));
      'P': Exit(Format('OK P%d=%.6f', [n, FPanels[n-1].MeasP], FFS));
    end;
    Exit('ERROR UnknownCommand');
  end;

  if (Length(t) = 2) and SameText(t[0], 'STATUS') then
  begin
    n := StrToIntDef(t[1], 0);
    if not ChOK(n) then Exit('ERROR InvalidChannel');
    Exit(Format('OK STATUS %d %s', [n, OnOff(FPanels[n-1].OutputOn)]));
  end;

  Result := 'ERROR UnknownCommand';
end;

end.
