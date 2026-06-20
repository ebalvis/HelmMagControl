unit uknob;
{ TKnob: dial rotatorio dibujado a mano (reemplazo de JvDialButton).
  Se arrastra verticalmente para variar el valor; la marca indica la posicion
  en un barrido de 270 grados (hueco abajo). Multiplataforma (Canvas LCL). }
{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Math;

type
  TKnob = class(TGraphicControl)
  private
    FMin, FMax, FPosition: Integer;
    FDragging: Boolean;
    FStartY, FStartPos: Integer;
    FOnChange: TNotifyEvent;
    procedure SetPosition(v: Integer);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Min: Integer read FMin write FMin;
    property Max: Integer read FMax write FMax;
    property Position: Integer read FPosition write SetPosition;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TKnob.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMin := 0; FMax := 100; FPosition := 0;
  Width := 53; Height := 53;
end;

procedure TKnob.SetPosition(v: Integer);
begin
  if v < FMin then v := FMin;
  if v > FMax then v := FMax;
  if v <> FPosition then
  begin
    FPosition := v;
    Invalidate;
    if Assigned(FOnChange) then FOnChange(Self);
  end;
end;

procedure TKnob.Paint;
var
  cx, cy, r: Integer;
  frac, ang: Double;
  ex, ey: Integer;
begin
  cx := Width div 2;
  cy := Height div 2;
  r := Math.Min(cx, cy) - 2;

  // cuerpo del knob
  Canvas.Pen.Width := 2;
  Canvas.Pen.Color := TColor($707070);
  Canvas.Brush.Color := TColor($242424);
  Canvas.Ellipse(cx - r, cy - r, cx + r, cy + r);
  // rebaje interior
  Canvas.Pen.Style := psClear;
  Canvas.Brush.Color := TColor($1A1A1A);
  Canvas.Ellipse(cx - r + 4, cy - r + 4, cx + r - 4, cy + r - 4);
  Canvas.Pen.Style := psSolid;

  // marca indicadora (-135..+135 grados, 0 = arriba, horario)
  if FMax > FMin then frac := (FPosition - FMin) / (FMax - FMin) else frac := 0;
  ang := DegToRad(-135 + frac * 270);
  ex := cx + Round(r * 0.72 * Sin(ang));
  ey := cy - Round(r * 0.72 * Cos(ang));
  Canvas.Pen.Width := 3;
  Canvas.Pen.Color := TColor($30C0F0);
  Canvas.Line(cx, cy, ex, ey);
  Canvas.Brush.Color := TColor($30C0F0);
  Canvas.Pen.Style := psClear;
  Canvas.Ellipse(ex - 3, ey - 3, ex + 3, ey + 3);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 1;
end;

procedure TKnob.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
  begin
    FDragging := True;
    FStartY := Y;
    FStartPos := FPosition;
  end;
end;

procedure TKnob.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  delta, np: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then
  begin
    delta := FStartY - Y; // arrastrar hacia arriba aumenta
    np := FStartPos + Round(delta * (FMax - FMin) / 150.0);
    SetPosition(np);
  end;
end;

procedure TKnob.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  FDragging := False;
end;

end.
