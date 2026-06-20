unit uwanptekpanelimg;
{ Panel de canal con el aspecto real del frontal Wanptek: usa la imagen
  KPS3020D como fondo y superpone los displays de 7 segmentos, LEDs (TShape),
  diales (TKnob) e interruptores (TToggle) en las mismas coordenadas que la
  version Delphi. Misma interfaz publica que TWanptekPanel. }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Math, Controls, Graphics, ExtCtrls, StdCtrls,
  useg7, uknob, utoggle, umbthread, umodbus_core;

const
  TITLEBAR = 20;

type
  TWanptekPanelImg = class(TCustomControl)
  private
    FAxis: Integer;
    FSlaveID: Byte;
    FThread: TModbusThread;
    FUpdating: Boolean;
    FMeasV, FMeasI, FMeasP: Double;
    FBmp: TBitmap;
    FTitle: string;
    segV, segI, segP: TSeg7Display;
    shOCPled, shCC, shPWR, shCV: TShape;
    knV, knI: TKnob;
    swOut, swOCP: TToggle;
    function MkLed(x, y: Integer): TShape;
    procedure CtrlChange(Sender: TObject);
    procedure SendSetpoints;
    procedure LoadBackground;
  protected
    procedure Paint; override;
  public
    constructor CreatePanel(AOwner: TComponent; Axis: Integer; SlaveID: Byte; const Title: string);
    destructor Destroy; override;
    procedure SetThread(AThread: TModbusThread);
    procedure SetSlaveID(S: Byte);
    procedure SetTitle(const S: string);
    procedure UpdateRegs(const Regs: TMbWords);
    function MeasV: Double;
    function MeasI: Double;
    function MeasP: Double;
    function OutputOn: Boolean;
    procedure RemoteSetV(val: Double);
    procedure RemoteSetI(val: Double);
    procedure RemoteSetOutput(b: Boolean);
    property SlaveID: Byte read FSlaveID;
  end;

implementation

const
  LED_OFF = TColor($202828);
  LED_GRN = TColor($30C030);
  LED_BLU = TColor($F08030);
  LED_RED = TColor($2020E0);

procedure TWanptekPanelImg.LoadBackground;
var
  png: TPortableNetworkGraphic;
  path: string;
begin
  path := ExtractFilePath(ParamStr(0)) + 'wanptek_panel.png';
  if not FileExists(path) then Exit;
  png := TPortableNetworkGraphic.Create;
  try
    png.LoadFromFile(path);
    FBmp := TBitmap.Create;
    FBmp.SetSize(png.Width, png.Height);
    FBmp.Canvas.Draw(0, 0, png);
  finally
    png.Free;
  end;
end;

function TWanptekPanelImg.MkLed(x, y: Integer): TShape;
begin
  Result := TShape.Create(Self);
  Result.Parent := Self;
  Result.Shape := stCircle;
  Result.SetBounds(x, y + TITLEBAR, 18, 18);
  Result.Pen.Color := TColor($404040);
  Result.Brush.Color := LED_OFF;
end;

constructor TWanptekPanelImg.CreatePanel(AOwner: TComponent; Axis: Integer; SlaveID: Byte; const Title: string);
var
  dispCol: TColor;

  function MkSeg(y: Integer; col: TColor): TSeg7Display;
  begin
    Result := TSeg7Display.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(147, y + TITLEBAR, 128, 32);
    Result.OnColor := col;
    Result.BackColor := dispCol;
    Result.Text := '00.00';
  end;

  function MkKnob(x, y, amax: Integer): TKnob;
  begin
    Result := TKnob.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(x, y + TITLEBAR, 53, 53);
    Result.Min := 0; Result.Max := amax; Result.Position := 0;
    Result.OnChange := @CtrlChange;
  end;

  function MkToggle(x, y: Integer): TToggle;
  begin
    Result := TToggle.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(x, y + TITLEBAR, 50, 20);
    Result.OnChange := @CtrlChange;
  end;

  procedure MkLbl(x, y, w: Integer; const cap: string);
  var
    lbl: TLabel;
  begin
    lbl := TLabel.Create(Self);
    lbl.Parent := Self;
    lbl.SetBounds(x, y + TITLEBAR, w, 16);
    lbl.Caption := cap;
    lbl.Font.Color := clSilver;
    lbl.Alignment := taCenter;
  end;

begin
  inherited Create(AOwner);
  FAxis := Axis;
  FSlaveID := SlaveID;
  FTitle := Title;
  Color := TColor($202830);
  LoadBackground;
  Width := 482;
  Height := 232 + TITLEBAR + 84; // + franja de control inferior

  if Assigned(FBmp) then
    dispCol := FBmp.Canvas.Pixels[300, 150] // zona negra del display (img nativa 611x391)
  else
    dispCol := clBlack;

  // displays V / A / W (coords Delphi)
  segV := MkSeg(62, TColor($2030F0));
  segI := MkSeg(103, TColor($2030F0));
  segP := MkSeg(148, TColor($1090F0));

  // LEDs centrados sobre los circulos reales del bisel (detectados en la imagen)
  shOCPled := MkLed(57, 67);   // O.C.P  -> centro (66,76)
  shCC     := MkLed(57, 119);  // C.C    -> centro (66,128)
  shPWR    := MkLed(408, 68);  // Output -> centro (417,77)
  shCV     := MkLed(406, 120); // C.V    -> centro (415,129)

  // --- franja de control inferior (debajo del frontal): diales e interruptores ---
  MkLbl(40, 238, 66, 'V set');
  knV := MkKnob(46, 256, 3000);
  MkLbl(130, 238, 66, 'I set');
  knI := MkKnob(136, 256, 500);
  MkLbl(228, 238, 64, 'Output');
  swOut := MkToggle(235, 258);
  MkLbl(316, 238, 64, 'OCP');
  swOCP := MkToggle(323, 258);
end;

destructor TWanptekPanelImg.Destroy;
begin
  FBmp.Free;
  inherited Destroy;
end;

procedure TWanptekPanelImg.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(0, 0, Width, Height);
  // La imagen original (611x391) se estira al espacio 482x232, igual que el
  // Image1 del Delphi, para que las coordenadas de los overlays cuadren.
  if Assigned(FBmp) then
    Canvas.StretchDraw(Rect(0, TITLEBAR, 482, TITLEBAR + 232), FBmp);
  // titulo del eje en la franja superior
  Canvas.Font.Color := TColor($30C0F0);
  Canvas.Font.Style := [fsBold];
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(10, 2, FTitle);
  Canvas.Brush.Style := bsSolid;
end;

procedure TWanptekPanelImg.SetThread(AThread: TModbusThread);
begin
  FThread := AThread;
end;

procedure TWanptekPanelImg.SetSlaveID(S: Byte);
begin
  FSlaveID := S;
end;

procedure TWanptekPanelImg.SetTitle(const S: string);
begin
  FTitle := S;
  Invalidate;
end;

procedure TWanptekPanelImg.SendSetpoints;
var
  dataReg: Word;
begin
  if not Assigned(FThread) then Exit;
  dataReg := 0;
  if swOut.Checked then dataReg := dataReg or (1 shl 8);
  if swOCP.Checked then dataReg := dataReg or (1 shl 9);
  // escala de setpoints pendiente de validar con hardware
  FThread.AddWrite(FSlaveID, 0, [dataReg, Word(knV.Position), Word(knI.Position)]);
end;

procedure TWanptekPanelImg.CtrlChange(Sender: TObject);
begin
  if FUpdating then Exit;
  SendSetpoints;
end;

procedure TWanptekPanelImg.UpdateRegs(const Regs: TMbWords);
var
  st0: Word;
  ps, ocp, ws: Boolean;
  v, i, p: Double;
begin
  if Length(Regs) < 6 then Exit;
  FUpdating := True;
  try
    st0 := Regs[0];
    ps  := (st0 and (1 shl 8)) <> 0;
    ocp := (st0 and (1 shl 9)) <> 0;
    ws  := (st0 and (1 shl 12)) <> 0;

    if ps then
    begin
      v := Regs[2] / 100; i := Regs[3] / 100; p := v * i;
    end
    else
    begin
      v := Regs[4] / 100; i := Regs[5] / 100; p := 0;
    end;

    FMeasV := v; FMeasI := i; FMeasP := p;
    segV.Text := FormatFloat('00.00', v);
    segI.Text := FormatFloat('00.00', i);
    segP.Text := FormatFloat('000.0', p);

    if ps then shPWR.Brush.Color := LED_GRN else shPWR.Brush.Color := LED_OFF;
    if ps and not ws then shCV.Brush.Color := LED_GRN else shCV.Brush.Color := LED_OFF;
    if ps and ws then shCC.Brush.Color := LED_BLU else shCC.Brush.Color := LED_OFF;
    if ocp then shOCPled.Brush.Color := LED_RED else shOCPled.Brush.Color := LED_OFF;

    swOut.Checked := ps;
    swOCP.Checked := ocp;
  finally
    FUpdating := False;
  end;
end;

function TWanptekPanelImg.MeasV: Double; begin Result := FMeasV; end;
function TWanptekPanelImg.MeasI: Double; begin Result := FMeasI; end;
function TWanptekPanelImg.MeasP: Double; begin Result := FMeasP; end;
function TWanptekPanelImg.OutputOn: Boolean; begin Result := swOut.Checked; end;

procedure TWanptekPanelImg.RemoteSetV(val: Double);
begin
  FUpdating := True;
  knV.Position := EnsureRange(Round(val * 100), knV.Min, knV.Max);
  FUpdating := False;
  SendSetpoints;
end;

procedure TWanptekPanelImg.RemoteSetI(val: Double);
begin
  FUpdating := True;
  knI.Position := EnsureRange(Round(val * 100), knI.Min, knI.Max);
  FUpdating := False;
  SendSetpoints;
end;

procedure TWanptekPanelImg.RemoteSetOutput(b: Boolean);
begin
  FUpdating := True;
  swOut.Checked := b;
  FUpdating := False;
  SendSetpoints;
end;

end.
