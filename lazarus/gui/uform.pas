unit uform;
{ Formulario LCL de un canal Wanptek, construido en codigo (sin .lfm).
  Demuestra el reemplazo de la UI JVCL: 7-segmentos propios (TSeg7Display),
  LEDs (TShape) y diales (TTrackBar). Incluye una simulacion para ver los
  displays en movimiento sin hardware. Multiplataforma (LCL). }
{$mode objfpc}{$H+}
{$codepage UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ComCtrls,
  useg7;

type
  TPanelForm = class(TForm)
  private
    segV, segI, segP: TSeg7Display;
    tbV, tbI: TTrackBar;
    chkOut: TCheckBox;
    shPower, shCV, shCC, shOCP: TShape;
    tmr: TTimer;
    FMeasV, FMeasI: Double;
    function MakeLed(x, y: Integer; const Cap: string): TShape;
    procedure OnTick(Sender: TObject);
    procedure DoClose(Sender: TObject; var CloseAction: TCloseAction);
  public
    procedure BuildUI;
  end;

implementation

const
  LED_OFF = TColor($202828);
  LED_PWR = TColor($30C030);
  LED_CV  = TColor($30C030);
  LED_CC  = TColor($2030F0);
  LED_OCP = TColor($2020E0);

function TPanelForm.MakeLed(x, y: Integer; const Cap: string): TShape;
var
  lbl: TLabel;
begin
  Result := TShape.Create(Self);
  Result.Parent := Self;
  Result.Shape := stCircle;
  Result.SetBounds(x, y, 16, 16);
  Result.Brush.Color := LED_OFF;
  lbl := TLabel.Create(Self);
  lbl.Parent := Self;
  lbl.SetBounds(x + 22, y, 50, 16);
  lbl.Caption := Cap;
end;

procedure TPanelForm.BuildUI;

  function MakeSeg(y: Integer): TSeg7Display;
  begin
    Result := TSeg7Display.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(20, y, 190, 58);
  end;

  function MakeUnit(y: Integer; const u: string): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(216, y + 20, 24, 20);
    Result.Caption := u;
    Result.Font.Style := [fsBold];
  end;

  function MakeBar(y, aMax, aPos: Integer; const Cap: string): TTrackBar;
  var
    lbl: TLabel;
  begin
    lbl := TLabel.Create(Self);
    lbl.Parent := Self;
    lbl.SetBounds(20, y, 80, 18);
    lbl.Caption := Cap;
    Result := TTrackBar.Create(Self);
    Result.Parent := Self;
    Result.SetBounds(100, y - 4, 250, 30);
    Result.Min := 0;
    Result.Max := aMax;
    Result.Position := aPos;
  end;

var
  lblTitle: TLabel;
begin
  Caption := 'BHC2000 (LCL) — Bobina eje X';
  Position := poScreenCenter;
  BorderStyle := bsSingle;
  ClientWidth := 380;
  ClientHeight := 360;
  Color := TColor($303030);

  lblTitle := TLabel.Create(Self);
  lblTitle.Parent := Self;
  lblTitle.SetBounds(20, 8, 340, 20);
  lblTitle.Caption := 'BOBINA EJE X';
  lblTitle.Font.Color := clWhite;
  lblTitle.Font.Style := [fsBold];

  segV := MakeSeg(34);   MakeUnit(34, 'V');
  segI := MakeSeg(98);   MakeUnit(98, 'A');
  segP := MakeSeg(162);  MakeUnit(162, 'W');
  segP.OnColor := TColor($30C0F0); // potencia en otro tono

  shPower := MakeLed(252, 36, 'PWR');
  shCV    := MakeLed(252, 60, 'CV');
  shCC    := MakeLed(252, 84, 'CC');
  shOCP   := MakeLed(252, 108, 'OCP');

  tbV := MakeBar(234, 3000, 1250, 'V set');
  tbI := MakeBar(274, 500, 75, 'I set');

  chkOut := TCheckBox.Create(Self);
  chkOut.Parent := Self;
  chkOut.SetBounds(20, 312, 160, 22);
  chkOut.Caption := 'Output ON';
  chkOut.Font.Color := clWhite;

  FMeasV := 0;
  FMeasI := 0;

  tmr := TTimer.Create(Self);
  tmr.Interval := 150;
  tmr.OnTimer := @OnTick;
  tmr.Enabled := True;

  OnClose := @DoClose;
end;

procedure TPanelForm.OnTick(Sender: TObject);
var
  setV, setI: Double;
begin
  if chkOut.Checked then
  begin
    setV := tbV.Position / 100;
    setI := tbI.Position / 100;
    FMeasV := FMeasV + (setV - FMeasV) * 0.35;
    FMeasI := FMeasI + (setI - FMeasI) * 0.35;
  end
  else
  begin
    FMeasV := FMeasV * 0.5;
    FMeasI := FMeasI * 0.5;
    if FMeasV < 0.01 then FMeasV := 0;
    if FMeasI < 0.01 then FMeasI := 0;
  end;

  segV.Text := FormatFloat('00.00', FMeasV);
  segI.Text := FormatFloat('00.00', FMeasI);
  segP.Text := FormatFloat('000.0', FMeasV * FMeasI);

  if chkOut.Checked then shPower.Brush.Color := LED_PWR
  else shPower.Brush.Color := LED_OFF;

  // CV si la tension esta cerca del setpoint; si no, CC (aproximacion)
  if chkOut.Checked and (Abs(tbV.Position / 100 - FMeasV) < 0.2) then
  begin
    shCV.Brush.Color := LED_CV;
    shCC.Brush.Color := LED_OFF;
  end
  else if chkOut.Checked then
  begin
    shCV.Brush.Color := LED_OFF;
    shCC.Brush.Color := LED_CC;
  end
  else
  begin
    shCV.Brush.Color := LED_OFF;
    shCC.Brush.Color := LED_OFF;
  end;
end;

procedure TPanelForm.DoClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
  Application.Terminate;
end;

end.
