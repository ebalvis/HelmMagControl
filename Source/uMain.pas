unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, ModbusSerialThread, Vcl.ComCtrls, JvAppStorage, JvAppRegistryStorage, JvComponentBase, JvFormPlacement,
  JvExControls, JvSegmentedLEDDisplay, Vcl.ExtCtrls, uWanptekDisplay, System.ImageList, Vcl.ImgList, System.Actions, Vcl.ActnList, IdBaseComponent, IdComponent,
  IdCustomTCPServer, IdTCPServer, uTcpServerController;

type
  TBackendWanptek = class(TInterfacedObject, IPowerSupplyBackend)
  public
    function ChannelCount: Integer;

    procedure SetVoltage(AChannel: Integer; AVolts: Double);
    procedure SetCurrent(AChannel: Integer; AAmps: Double);
    procedure SetOutput(AChannel: Integer; AOn: Boolean);

    function GetVoltage(AChannel: Integer): Double;
    function GetCurrent(AChannel: Integer): Double;
    function GetPower(AChannel: Integer): Double;
    function GetOutput(AChannel: Integer): Boolean;

    procedure AllOff;
    function GetStatusText(AChannel: Integer): string;
  end;

  TfMain = class(TForm)
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    cmbPuerto: TComboBox;
    cmbBaudios: TComboBox;
    edtBits: TEdit;
    cmbParidad: TComboBox;
    cmbStopBit: TComboBox;
    StatusBar1: TStatusBar;
    GroupBox2: TGroupBox;
    Label8: TLabel;
    edtEjeX: TEdit;
    Label6: TLabel;
    edtEjeY: TEdit;
    Label7: TLabel;
    edtEjeZ: TEdit;
    JvFormStorage1: TJvFormStorage;
    JvAppRegistryStorage1: TJvAppRegistryStorage;
    GroupBox3: TGroupBox;
    Label9: TLabel;
    ScrollBox1: TScrollBox;
    Panel1: TPanel;
    btnConnect: TButton;
    ActionList1: TActionList;
    actConectar: TAction;
    ImageList1: TImageList;
    IdTCPServer1: TIdTCPServer;
    GroupBox4: TGroupBox;
    Label10: TLabel;
    edtRefresco: TEdit;
    edtPuerto: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure actConectarExecute(Sender: TObject);
    procedure ActionList1Update(Action: TBasicAction; var Handled: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
    SlaveIDs: TBytes;
    fServer: TTcpServerController;
    FBackend: IPowerSupplyBackend;
    ReadInterval: Cardinal;
    FModbusThread: TModbusSerialThread;
    FConnected: Boolean;
    fWanptekDisplays: array [0 .. 2] of TfWanptekDisplay;
    function GetSerialConfig: TSerialConfig;
    // Eventos del hilo Modbus
    procedure OnModbusDataReceived(Sender: TObject; const Data: TModbusReadData);
    procedure OnModbusError(Sender: TObject; const ErrorMsg: string);
    procedure OnModbusConnected(Sender: TObject);
    procedure OnModbusDisconnected(Sender: TObject);
  public
    { Public declarations }
  end;

var
  fMain: TfMain;

const
  Titles: array [0 .. 2] of string = ('BOBINA EJE X', 'BOBINA EJE Y', 'BOBINA EJE Z');

implementation

{$R *.dfm}

procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  fServer.Stop;
end;

procedure TfMain.FormCreate(Sender: TObject);
begin
  FConnected := False;

  // Configurar controles
  cmbPuerto.Items.Clear;
  cmbPuerto.Items.Add('COM1');
  cmbPuerto.Items.Add('COM2');
  cmbPuerto.Items.Add('COM3');
  cmbPuerto.Items.Add('COM4');
  cmbPuerto.Items.Add('COM5');
  cmbPuerto.Items.Add('COM6');
  cmbPuerto.ItemIndex := 4;

  cmbBaudios.Items.Clear;
  cmbBaudios.Items.Add('9600');
  cmbBaudios.Items.Add('19200');
  cmbBaudios.Items.Add('38400');
  cmbBaudios.Items.Add('57600');
  cmbBaudios.Items.Add('115200');
  cmbBaudios.ItemIndex := 1;

  cmbParidad.Items.Clear;
  cmbParidad.Items.Add('None');
  cmbParidad.Items.Add('Even');
  cmbParidad.Items.Add('Odd');
  cmbParidad.ItemIndex := 0;

  cmbStopBit.Items.Clear;
  cmbStopBit.Items.Add('1');
  cmbStopBit.Items.Add('2');
  cmbStopBit.ItemIndex := 0;
  JvFormStorage1.RestoreFormPlacement;
  setLength(SlaveIDs, 3);
  SlaveIDs[0] := StrToIntDef(edtEjeX.Text, 1);
  SlaveIDs[1] := StrToIntDef(edtEjeY.Text, 1);
  SlaveIDs[2] := StrToIntDef(edtEjeZ.Text, 1);
  ReadInterval := StrToIntDef(edtRefresco.Text, 1000);
  for var i := 0 to 2 do
  begin
    fWanptekDisplays[i] := TfWanptekDisplay.execute(SlaveIDs[i], Titles[i]);
    fWanptekDisplays[i].BorderStyle := bsNone; // muy importante
    fWanptekDisplays[i].Parent := ScrollBox1;
    fWanptekDisplays[i].Align := alTop; // evita que se expanda solo
    fWanptekDisplays[i].Enabled := False;
    fWanptekDisplays[i].Show;
  end;
  FBackend := TBackendWanptek.Create;
  fServer := TTcpServerController.Create;
  fServer.SetBackend(FBackend);
end;

function TfMain.GetSerialConfig: TSerialConfig;
begin
  Result.Port := cmbPuerto.Text;
  Result.BaudRate := StrToIntDef(cmbBaudios.Text, 9600);
  Result.DataBits := StrToIntDef(edtBits.Text, 8);
  Result.StopBits := StrToIntDef(cmbStopBit.Text, 1);

  case cmbParidad.ItemIndex of
    0:
      Result.Parity := 'N';
    1:
      Result.Parity := 'E';
    2:
      Result.Parity := 'O';
  else
    Result.Parity := 'N';
  end;

  Result.Timeout := 1000; // 1 segundo de timeout
end;

procedure TfMain.actConectarExecute(Sender: TObject);
var
  SerialConfig: TSerialConfig;

begin
  if actConectar.tag = 1 then
  begin

    if Assigned(FModbusThread) then
    begin
      StatusBar1.Panels[1].Text := 'Deteniendo hilo existente...';
      FModbusThread.Stop;
      FModbusThread.Free;
      FModbusThread := nil;
      OnModbusDisconnected(nil);
    end;
  end
  else
  begin

    if Assigned(FModbusThread) then
    begin
      StatusBar1.Panels[1].Text := 'Deteniendo hilo existente...';
      FModbusThread.Stop;
      FModbusThread.Free;
      FModbusThread := nil;
    end;

    try
      // Obtener configuración
      SerialConfig := GetSerialConfig;
      // Crear y configurar el hilo
      FModbusThread := TModbusSerialThread.Create(SerialConfig, SlaveIDs, mcReadHoldingRegisters, ReadInterval);
      for var i := 0 to length(fWanptekDisplays) - 1 do
        if Assigned(fWanptekDisplays[i]) then
          fWanptekDisplays[i].ModbusThread := FModbusThread;
      // Asignar eventos
      FModbusThread.OnDataReceived := OnModbusDataReceived;
      FModbusThread.OnError := OnModbusError;
      FModbusThread.OnConnected := OnModbusConnected;
      FModbusThread.OnDisconnected := OnModbusDisconnected;
      fServer.Start(StrToIntDef(edtPuerto.Text, 4444));
    except
      on E: Exception do
      begin
        StatusBar1.Panels[1].Text := 'Error iniciando comunicación Modbus: ' + E.Message;
      end;
    end;
  end;
end;

procedure TfMain.ActionList1Update(Action: TBasicAction; var Handled: Boolean);
var
  en: Boolean;
begin
  if not Assigned(FModbusThread) then
    en := true
  else
    en := not(FModbusThread.Connected);
  GroupBox1.Enabled := en;
  GroupBox2.Enabled := en;
  GroupBox3.Enabled := en
end;

procedure TfMain.btnConnectClick(Sender: TObject);
begin

end;

// Eventos del hilo Modbus
procedure TfMain.OnModbusDataReceived(Sender: TObject; const Data: TModbusReadData);
var
  Msg: string;
begin
  fWanptekDisplays[0].ModbusReadData := Data;
  fWanptekDisplays[1].ModbusReadData := Data;
  fWanptekDisplays[2].ModbusReadData := Data;
end;

procedure TfMain.OnModbusError(Sender: TObject; const ErrorMsg: string);
begin
  StatusBar1.Panels[1].Text := 'ERROR: ' + ErrorMsg;
end;

procedure TfMain.OnModbusConnected(Sender: TObject);
begin
  actConectar.Caption := 'Desconectar Modbus';
  actConectar.tag := 1;
  StatusBar1.Panels[1].Text := 'Conectado al dispositivo Modbus';
  for var i := 0 to 2 do
    fWanptekDisplays[i].Enabled := true;
end;

procedure TfMain.OnModbusDisconnected(Sender: TObject);
begin
  actConectar.Caption := 'Conectar Modbus';
  actConectar.tag := 0;
  StatusBar1.Panels[1].Text := 'Desconectado del dispositivo Modbus';
  for var i := 0 to 2 do
    fWanptekDisplays[i].Enabled := False;
end;
{ ==== Implementación ==== }

function TBackendWanptek.ChannelCount: Integer;
begin
  // Devuelve el nº de canales que gestionas
  Result := 3;
end;

procedure TBackendWanptek.SetVoltage(AChannel: Integer; AVolts: Double);
begin
  fMain.fWanptekDisplays[AChannel].SetVoltage(AVolts);
  // EJEMPLO A: llamando a tu UI (formularios embebidos)
  // TThread.Queue(nil,
  // procedure
  // begin
  // // fWanptekDisplay[AChannel].SetVoltage(AVolts);  // <-- tu método real
  // end);

  // EJEMPLO B: usando tu hilo Modbus directamente (sin UI)
  // ModbusThread.WriteSetpointVoltage(AChannel, AVolts);
end;

procedure TBackendWanptek.SetCurrent(AChannel: Integer; AAmps: Double);
begin
  fMain.fWanptekDisplays[AChannel].SetCurrent(AAmps);
end;

procedure TBackendWanptek.SetOutput(AChannel: Integer; AOn: Boolean);
begin
  fMain.fWanptekDisplays[AChannel].SetOutput(AOn);
  // fWanptekDisplay[AChannel].SetOutput(AOn);
  // ModbusThread.WriteOutput(AChannel, AOn);
end;

function TBackendWanptek.GetVoltage(AChannel: Integer): Double;
begin
  Result := fMain.fWanptekDisplays[AChannel].MeasVoltage;
end;

function TBackendWanptek.GetCurrent(AChannel: Integer): Double;
begin
  Result := fMain.fWanptekDisplays[AChannel].MeasCurrent;
end;

function TBackendWanptek.GetPower(AChannel: Integer): Double;
begin
  Result := fMain.fWanptekDisplays[AChannel].MeasPower;
end;

function TBackendWanptek.GetOutput(AChannel: Integer): Boolean;
begin
  Result := fMain.fWanptekDisplays[AChannel].GetOutput;
end;

procedure TBackendWanptek.AllOff;
var
  ch: Integer;
begin
  for ch := 0 to ChannelCount - 1 do
    SetOutput(ch, False);
end;

function TBackendWanptek.GetStatusText(AChannel: Integer): string;
begin
  // Devuelve info adicional (p. ej. 'CV', 'CC', alarmas…)
  Result := '';
end;

end.
