unit umainform;
{ Formulario principal de la app LCL: configuracion serie, 3 paneles de canal,
  selector de idioma e integracion del hilo Modbus sobre ISerialTransport.
  Construido en codigo (sin .lfm). }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  ulang, umbthread, uwanptekpanel, userial, umodbus_core;

type
  TMainForm = class(TForm)
  private
    FThread: TModbusThread;
    FPanels: array [0 .. 2] of TWanptekPanel;
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
begin
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  ClientWidth := 760;
  ClientHeight := 500;

  // --- columna izquierda: 3 paneles de canal ---
  for ax := 0 to 2 do
  begin
    FPanels[ax] := TWanptekPanel.CreatePanel(Self, ax, 1, CoilTitle(ax));
    FPanels[ax].Parent := Self;
    FPanels[ax].SetBounds(8, 8 + ax * 156, 470, 150);
  end;

  // --- columna derecha: configuracion ---
  cx := 490;

  cmbLang := C(Self, cx + 60, 8, 120, [LanguageName(lnEs), LanguageName(lnEn)]);
  lblLang := L(Self, cx, 11, 56, '');
  cmbLang.OnChange := @LangChange;

  btnConnect := TButton.Create(Self);
  btnConnect.Parent := Self;
  btnConnect.SetBounds(cx, 38, 240, 28);
  btnConnect.OnClick := @BtnConnectClick;

  gbSerial := TGroupBox.Create(Self);
  gbSerial.Parent := Self;
  gbSerial.SetBounds(cx, 74, 240, 172);
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
  gbAddr.SetBounds(cx, 252, 240, 110);
  lblX := L(gbAddr, 12, 22, 60, '');  edX := E(gbAddr, 90, 19, 60, '1');
  lblY := L(gbAddr, 12, 50, 60, '');  edY := E(gbAddr, 90, 47, 60, '2');
  lblZ := L(gbAddr, 12, 78, 60, '');  edZ := E(gbAddr, 90, 75, 60, '3');

  gbParams := TGroupBox.Create(Self);
  gbParams.Parent := Self;
  gbParams.SetBounds(cx, 368, 240, 54);
  lblInterval := L(gbParams, 12, 22, 60, '');
  edInterval  := E(gbParams, 90, 19, 80, '1000');
  lblMs := L(gbParams, 176, 22, 30, 'ms');

  gbServer := TGroupBox.Create(Self);
  gbServer.Parent := Self;
  gbServer.SetBounds(cx, 428, 240, 54);
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

  FThread := TModbusThread.Create(cfg, slaves, StrToIntDef(edInterval.Text, 1000));
  FThread.OnData := @OnData;
  FThread.OnConnected := @OnConn;
  FThread.OnDisconnected := @OnDisc;
  FThread.OnError := @OnErr;
  for ax := 0 to 2 do
    FPanels[ax].SetThread(FThread);
  ApplyLanguage;
end;

procedure TMainForm.OnData(Sender: TObject; SlaveID: Byte; const Regs: TMbWords);
var
  ax: Integer;
begin
  for ax := 0 to 2 do
    if FPanels[ax].SlaveID = SlaveID then
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
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  CloseAction := caFree;
  Application.Terminate;
end;

end.
