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

  function MkSeg(x: Integer; col: TColor): TSeg7Display;
  begin
    Result := TSeg7Display.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(x, 22, 118, 44);
    Result.OnColor := col;
    Result.Text := '00.00';
  end;

  function MkUnit(x: Integer; const u: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(x, 38, 16, 16);
    Result.Caption := u;
    Result.Font.Color := clWhite;
    Result.Font.Style := [fsBold];
  end;

begin
  inherited Create(AOwner);
  FAxis := Axis;
  FSlaveID := SlaveID;
  BevelOuter := bvLowered;
  Color := TColor($303030);
  Width := 470;
  Height := 150;

  lblTitle := TLabel.Create(Self);
  lblTitle.Parent := Self;
  lblTitle.SetBounds(8, 4, 240, 16);
  lblTitle.Caption := Title;
  lblTitle.Font.Color := clWhite;
  lblTitle.Font.Style := [fsBold];

  segV := MkSeg(8, TColor($2030F0));   MkUnit(128, 'V');
  segI := MkSeg(150, TColor($2030F0)); MkUnit(270, 'A');
  segP := MkSeg(292, TColor($30C0F0)); MkUnit(412, 'W');

  shPWR := MakeLed(286, 70, 'PWR');
  shCV  := MakeLed(286, 90, 'CV');
  shCC  := MakeLed(360, 70, 'CC');
  shOCP := MakeLed(360, 90, 'OCP');

  tbV := TTrackBar.Create(Self);
  tbV.Parent := Self;
  tbV.SetBounds(8, 70, 180, 28);
  tbV.Min := 0; tbV.Max := 3000; tbV.Position := 0;
  tbV.OnChange := @CtrlChange;

  tbI := TTrackBar.Create(Self);
  tbI.Parent := Self;
  tbI.SetBounds(8, 100, 180, 28);
  tbI.Min := 0; tbI.Max := 500; tbI.Position := 0;
  tbI.OnChange := @CtrlChange;

  chkOut := TCheckBox.Create(Self);
  chkOut.Parent := Self;
  chkOut.SetBounds(200, 124, 80, 20);
  chkOut.Caption := 'Output';
  chkOut.Font.Color := clWhite;
  chkOut.OnChange := @CtrlChange;

  chkOCP := TCheckBox.Create(Self);
  chkOCP.Parent := Self;
  chkOCP.SetBounds(286, 124, 80, 20);
  chkOCP.Caption := 'OCP';
  chkOCP.Font.Color := clWhite;
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
