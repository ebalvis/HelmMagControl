unit uwanptekpanel;
{ Panel de un canal Wanptek como control reutilizable (TPanel compuesto).
  Decodifica los registros Modbus (igual que el uWanptekDisplay de Delphi),
  pinta los 7-segmentos y LEDs, y envia escrituras al hilo Modbus. }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  useg7, umbthread, umodbus_core;

type
  TWanptekPanel = class(TPanel)
  private
    FAxis: Integer;
    FSlaveID: Byte;
    FThread: TModbusThread;
    FUpdating: Boolean;
    lblTitle: TLabel;
    segV, segI, segP: TSeg7Display;
    shPWR, shCV, shCC, shOCP: TShape;
    tbV, tbI: TTrackBar;
    chkOut, chkOCP: TCheckBox;
    function MakeLed(x, y: Integer; const Cap: string): TShape;
    procedure CtrlChange(Sender: TObject);
    procedure SendSetpoints;
  public
    constructor CreatePanel(AOwner: TComponent; Axis: Integer; SlaveID: Byte; const Title: string);
    procedure SetThread(AThread: TModbusThread);
    procedure SetSlaveID(S: Byte);
    procedure SetTitle(const S: string);
    procedure UpdateRegs(const Regs: TMbWords);
    property SlaveID: Byte read FSlaveID;
  end;

implementation

const
  LED_OFF = TColor($202828);
  LED_GRN = TColor($30C030);
  LED_BLU = TColor($F08030);
  LED_RED = TColor($2020E0);

constructor TWanptekPanel.CreatePanel(AOwner: TComponent; Axis: Integer; SlaveID: Byte; const Title: string);

  function MkSeg(y: Integer; col: TColor): TSeg7Display;
  begin
    Result := TSeg7Display.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(12, y, 212, 42);
    Result.OnColor := col;
    Result.BackColor := TColor($0C0C0C);
    Result.Text := '00.00';
  end;

  function MkUnit(y: Integer; const u: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(230, y + 12, 18, 18);
    Result.Caption := u;
    Result.Font.Color := clSilver;
    Result.Font.Style := [fsBold];
  end;

  function MkSetLabel(x, y: Integer; const cap: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(x, y, 110, 16);
    Result.Caption := cap;
    Result.Font.Color := clSilver;
  end;

begin
  inherited Create(AOwner);
  FAxis := Axis;
  FSlaveID := SlaveID;
  BevelOuter := bvNone;
  BevelInner := bvRaised;
  Color := TColor($2A2A2A);
  Width := 482;
  Height := 170;

  lblTitle := TLabel.Create(Self);
  lblTitle.Parent := Self;
  lblTitle.SetBounds(12, 6, 300, 18);
  lblTitle.Caption := Title;
  lblTitle.Font.Color := TColor($30C0F0);
  lblTitle.Font.Style := [fsBold];

  // Displays apilados (V / A / W), como una fuente real
  segV := MkSeg(28, TColor($2030F0));  MkUnit(28, 'V');
  segI := MkSeg(74, TColor($2030F0));  MkUnit(74, 'A');
  segP := MkSeg(120, TColor($1090F0)); MkUnit(120, 'W');

  // Columna de LEDs de estado
  shPWR := MakeLed(264, 30, 'PWR');
  shCV  := MakeLed(264, 56, 'CV');
  shCC  := MakeLed(264, 82, 'CC');
  shOCP := MakeLed(264, 108, 'OCP');

  // Diales (setpoints) y conmutadores
  MkSetLabel(338, 26, 'V set');
  tbV := TTrackBar.Create(Self);
  tbV.Parent := Self;
  tbV.SetBounds(336, 42, 138, 28);
  tbV.Min := 0; tbV.Max := 3000; tbV.Position := 0;
  tbV.OnChange := @CtrlChange;

  MkSetLabel(338, 74, 'I set');
  tbI := TTrackBar.Create(Self);
  tbI.Parent := Self;
  tbI.SetBounds(336, 90, 138, 28);
  tbI.Min := 0; tbI.Max := 500; tbI.Position := 0;
  tbI.OnChange := @CtrlChange;

  chkOut := TCheckBox.Create(Self);
  chkOut.Parent := Self;
  chkOut.SetBounds(338, 124, 70, 22);
  chkOut.Caption := 'Output';
  chkOut.Font.Color := clSilver;
  chkOut.OnChange := @CtrlChange;

  chkOCP := TCheckBox.Create(Self);
  chkOCP.Parent := Self;
  chkOCP.SetBounds(410, 124, 64, 22);
  chkOCP.Caption := 'OCP';
  chkOCP.Font.Color := clSilver;
  chkOCP.OnChange := @CtrlChange;
end;

function TWanptekPanel.MakeLed(x, y: Integer; const Cap: string): TShape;
var
  lbl: TLabel;
begin
  Result := TShape.Create(Self);
  Result.Parent := Self;
  Result.Shape := stCircle;
  Result.SetBounds(x, y, 14, 14);
  Result.Brush.Color := LED_OFF;
  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(x + 18, y, 40, 14);
  lbl.Caption := Cap;
  lbl.Font.Color := clWhite;
end;

procedure TWanptekPanel.SetThread(AThread: TModbusThread);
begin
  FThread := AThread;
end;

procedure TWanptekPanel.SetSlaveID(S: Byte);
begin
  FSlaveID := S;
end;

procedure TWanptekPanel.SetTitle(const S: string);
begin
  lblTitle.Caption := S;
end;

procedure TWanptekPanel.SendSetpoints;
var
  dataReg: Word;
begin
  if not Assigned(FThread) then Exit;
  dataReg := 0;
  if chkOut.Checked then dataReg := dataReg or (1 shl 8);
  if chkOCP.Checked then dataReg := dataReg or (1 shl 9);
  // Escala de setpoints pendiente de validar con hardware real.
  FThread.AddWrite(FSlaveID, 0, [dataReg, Word(tbV.Position), Word(tbI.Position)]);
end;

procedure TWanptekPanel.CtrlChange(Sender: TObject);
begin
  if FUpdating then Exit;
  SendSetpoints;
end;

procedure TWanptekPanel.UpdateRegs(const Regs: TMbWords);
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
      v := Regs[2] / 100;
      i := Regs[3] / 100;
      p := v * i;
    end
    else
    begin
      v := Regs[4] / 100;
      i := Regs[5] / 100;
      p := 0;
    end;

    segV.Text := FormatFloat('00.00', v);
    segI.Text := FormatFloat('00.00', i);
    segP.Text := FormatFloat('000.0', p);

    if ps then shPWR.Brush.Color := LED_GRN else shPWR.Brush.Color := LED_OFF;
    if ps and not ws then shCV.Brush.Color := LED_GRN else shCV.Brush.Color := LED_OFF;
    if ps and ws then shCC.Brush.Color := LED_BLU else shCC.Brush.Color := LED_OFF;
    if ocp then shOCP.Brush.Color := LED_RED else shOCP.Brush.Color := LED_OFF;

    // refleja setpoints/estado en los controles cuando no hay escrituras en vuelo
    chkOut.Checked := ps;
    chkOCP.Checked := ocp;
  finally
    FUpdating := False;
  end;
end;

end.
