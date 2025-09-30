unit uWanptekDisplay;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, JvExControls, JvSegmentedLEDDisplay, Vcl.Imaging.pngimage, Vcl.ExtCtrls, JvLED, Vcl.StdCtrls, ModbusSerialThread,
  Vcl.WinXCtrls, JvDialButton, System.Actions, Vcl.ActnList, System.Math;

type
  TVoltageTextLut = array [0 .. $0D] of string;
  TCurrentTextLut = array [0 .. $20] of string;

  // Configuración del puerto serie
  TStatusRegister0 = record
    _VID: Byte; // IID(Position of the decimal point in the current data):
    _VPOD: bool; // VPOD(Position of the decimal point in the voltage data):
    _PS: bool; // PS(Status of power out):
    _OS: bool; // OS(Status of OCP):
    _LS: bool; // LS(Status of lock):
    _BL: bool; // BL(Big-endian Or Little-endian):
    _WS: bool; // WS(Status of Work):
    _AS: bool; // AS(Status of alarm):
  end;

  TStatusRegister1 = record
    _IID: Byte; // VID(Position of the decimal point in the voltage data):
    _IPOD: bool; // IPOD(Position of the decimal point in the voltage data):
  end;

  TfWanptekDisplay = class(TForm)
    Label1: TLabel;
    dspPower: TJvSegmentedLEDDisplay;
    dspCurrent: TJvSegmentedLEDDisplay;
    dspVoltaje: TJvSegmentedLEDDisplay;
    ledTX_RX: TJvLED;
    ledCC: TJvLED;
    ledOCP: TJvLED;
    ledCV: TJvLED;
    ledPower: TJvLED;
    Image1: TImage;
    lblModelo: TLabel;
    dialVoltaje: TJvDialButton;
    swOutput: TToggleSwitch;
    swOCP: TToggleSwitch;
    dialCurrent: TJvDialButton;
    Label2: TLabel;
    Label3: TLabel;
    Timer1: TTimer;
    procedure dialVoltajeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure swOutputClick(Sender: TObject);
    procedure swOCPClick(Sender: TObject);
    procedure dialCurrentMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure dialVoltajeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure dialCurrentMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure Timer1Timer(Sender: TObject);
  private
    fModbusReadData: TModbusReadData;
    fSlaveID: Byte;
    fStatusRegister0: TStatusRegister0;
    fStatusRegister1: TStatusRegister1;
    fModbusThread: TModbusSerialThread;
    fFirstRead: Boolean;
    fUpdating: Boolean;
    procedure setModbusReadData(const Value: TModbusReadData);

    procedure WriteCmd;
    function getMeasCurrent: double;
    function getMeasVoltage: double;
    function getMeasPower: double;
    procedure WriteCmdVI(voltaje, current: double);
    { Private declarations }
  public
    { Public declarations }

    class function execute(slaveID: Byte; title: string): TfWanptekDisplay;
    procedure setCurrent(current: double);
    procedure setVoltage(Voltage: double);
    procedure SetOutput(Value: Boolean);
    function GetOutput: Boolean;
    property ModbusThread: TModbusSerialThread read fModbusThread write fModbusThread;
    property ModbusReadData: TModbusReadData read fModbusReadData write setModbusReadData;
    property MeasCurrent: double read getMeasCurrent;
    property MeasVoltage: double read getMeasVoltage;
    property MeasPower: double read getMeasPower;
  end;

const
  VOLTAGE_TEXT_BY_DATA: TVoltageTextLut = ('15V', // 0x00
    '30V', // 0x01
    '60V', // 0x02
    '100V', // 0x03
    '120V', // 0x04
    '150V', // 0x05
    '160V', // 0x06
    '200V', // 0x07
    '300V', // 0x08
    '400V', // 0x09
    '500V', // 0x0A
    '600V', // 0x0B
    '800V', // 0x0C
    '1000V' // 0x0D
    );

  CURRENT_TEXT_BY_DATA: TCurrentTextLut = ('1A', // 0x00
    '2A', // 0x01
    '3A', // 0x02
    '5A', // 0x03
    '6A', // 0x04
    '10A', // 0x05
    '20A', // 0x06
    '30A', // 0x07
    '40A', // 0x08
    '50A', // 0x09
    '60A', // 0x0A
    '80A', // 0x0B
    '100A', // 0x0C
    '150A', // 0x0D
    '200A', // 0x0E
    '400A', // 0x0F
    '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', // 0x10..0x1F (no definidos)
    '15A' // 0x20
    );

var
  fWanptekDisplay: TfWanptekDisplay;

implementation

{$R *.dfm}
{ TfWanptekDisplay }

class function TfWanptekDisplay.execute(slaveID: Byte; title: string): TfWanptekDisplay;
begin
  result := TfWanptekDisplay.create(nil);
  with result do
  begin
    Label1.Caption := title;
    fSlaveID := slaveID;
    fModbusThread := ModbusThread;
    fFirstRead := true;
  end;
end;

function TfWanptekDisplay.getMeasCurrent: double;
begin
  result := dspCurrent.text.ToDouble;
end;

function TfWanptekDisplay.getMeasVoltage: double;
begin
  result := dspVoltaje.text.ToDouble;
end;

function TfWanptekDisplay.getMeasPower: double;
begin
  result := dspPower.text.ToDouble;
end;

procedure TfWanptekDisplay.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := false;
  ledTX_RX.status := false;
end;

procedure TfWanptekDisplay.setModbusReadData(const Value: TModbusReadData);
var
  data: word;
  aux: String;
begin
  if Value.slaveID = fSlaveID then
    try
      fUpdating := true;
      ledTX_RX.status := true;
      Timer1.Enabled := true;
      fModbusReadData := Value;
      fStatusRegister0._AS := (Value.Values[0] and (1 shl 13)) > 0; // alarma
      fStatusRegister0._WS := (Value.Values[0] and (1 shl 12)) > 0;
      fStatusRegister0._BL := (Value.Values[0] and (1 shl 11)) > 0;
      fStatusRegister0._LS := (Value.Values[0] and (1 shl 10)) > 0;
      fStatusRegister0._OS := (Value.Values[0] and (1 shl 9)) > 0;
      fStatusRegister0._PS := (Value.Values[0] and (1 shl 8)) > 0; // power activado
      fStatusRegister0._VPOD := (Value.Values[0] and (1 shl 4)) > 0;
      fStatusRegister0._VID := (Value.Values[0] and $0F) + ((Value.Values[0] and $F0) shr 5);
      fStatusRegister1._IPOD := (Value.Values[1] and (1 shl 12)) > 0;
      fStatusRegister1._IID := ((Value.Values[1] and $F00) shr 8) + ((Value.Values[1] and $F000) shr 13);
      lblModelo.Caption := VOLTAGE_TEXT_BY_DATA[fStatusRegister0._VID] + '/' + CURRENT_TEXT_BY_DATA[fStatusRegister1._IID];
      ledPower.status := fStatusRegister0._PS;
      ledCV.status := not fStatusRegister0._WS and fStatusRegister0._PS;
      ledCC.status := fStatusRegister0._WS and fStatusRegister0._PS;
      ledOCP.status := fStatusRegister0._OS;
      if fStatusRegister0._PS then
      begin
        dspVoltaje.text := FormatFloat('00.00', Value.Values[2] / 100);
        dspCurrent.text := FormatFloat('00.00', Value.Values[3] / 100);
        dspPower.text := FormatFloat('000.0', Value.Values[2] * Value.Values[3] / 10000);
      end
      else
      begin
        dspVoltaje.text := FormatFloat('00.00', Value.Values[4] / 100);
        dspCurrent.text := FormatFloat('00.00', Value.Values[5] / 100);
        dspPower.text := '000,0';
      end;
      if fFirstRead then
      begin
        fFirstRead := false;
        aux := copy(VOLTAGE_TEXT_BY_DATA[fStatusRegister0._VID], 1, length(VOLTAGE_TEXT_BY_DATA[fStatusRegister0._VID]) - 1);
        dialVoltaje.max := aux.toInteger * 10;
        aux := copy(CURRENT_TEXT_BY_DATA[fStatusRegister1._IID], 1, length(CURRENT_TEXT_BY_DATA[fStatusRegister1._IID]) - 1);
        dialCurrent.max := aux.toInteger * 10;
      end;
      if fModbusThread.QueueEmpty then
      begin
        if dialVoltaje.tag = 0 then
          dialVoltaje.position := round(Value.Values[4] / 10);
        if dialCurrent.tag = 0 then
          dialCurrent.position := round(Value.Values[5] / 10);
        if fStatusRegister0._PS then
          swOutput.state := tssOn
        else
          swOutput.state := tssOff;
        if fStatusRegister0._OS then
          swOCP.state := tssOn
        else
          swOCP.state := tssOff;
      end;
    finally
      fUpdating := false;
    end;
end;

procedure TfWanptekDisplay.swOCPClick(Sender: TObject);
begin
  if not fUpdating then
    WriteCmd
end;

procedure TfWanptekDisplay.swOutputClick(Sender: TObject);
begin
  if not fUpdating then
    WriteCmd
end;

procedure TfWanptekDisplay.WriteCmd;
begin
  var
  dataReg := ifthen(swOutput.state = tssOn, (1 shl 8), 0) + ifthen(swOCP.state = tssOn, (1 shl 9), 0);
  fModbusThread.AddWriteCommand(mcWriteMultipleRegisters, fSlaveID, 0, [dataReg, dialVoltaje.position * 10, dialCurrent.position * 10])
end;

procedure TfWanptekDisplay.WriteCmdVI(voltaje, current: double);
begin
  var
  dataReg := ifthen(swOutput.state = tssOn, (1 shl 8), 0) + ifthen(swOCP.state = tssOn, (1 shl 9), 0);
  fModbusThread.AddWriteCommand(mcWriteMultipleRegisters, fSlaveID, 0, [dataReg, round(voltaje * 10), round(current * 10)])
end;

procedure TfWanptekDisplay.dialCurrentMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  dialCurrent.tag := 1;
end;

procedure TfWanptekDisplay.dialCurrentMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  dialCurrent.tag := 0;
  WriteCmd
end;

procedure TfWanptekDisplay.dialVoltajeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  dialVoltaje.tag := 1;
end;

procedure TfWanptekDisplay.dialVoltajeMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  dialVoltaje.tag := 0;
  WriteCmd
end;

procedure TfWanptekDisplay.setVoltage(Voltage: double);
begin
  dialVoltaje.position := round(Voltage * 10);
  WriteCmd;
end;

procedure TfWanptekDisplay.setCurrent(current: double);
begin
  dialCurrent.position := round(current * 10);
  WriteCmd;
end;

procedure TfWanptekDisplay.SetOutput(Value: Boolean);
begin
  if Value then
    swOutput.state := tssOn
  else
    swOutput.state := tssOff;
end;

function TfWanptekDisplay.GetOutput: Boolean;
begin
  result := swOutput.state = tssOn;
end;

end.
