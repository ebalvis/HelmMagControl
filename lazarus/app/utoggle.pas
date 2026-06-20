unit utoggle;
{ TToggle: interruptor deslizante dibujado a mano (reemplazo de TToggleSwitch).
  Clic para conmutar. Multiplataforma (Canvas LCL). }
{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics;

type
  TToggle = class(TGraphicControl)
  private
    FChecked: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetChecked(v: Boolean);
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Checked: Boolean read FChecked write SetChecked;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TToggle.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 50;
  Height := 20;
  FChecked := False;
end;

procedure TToggle.SetChecked(v: Boolean);
begin
  if v <> FChecked then
  begin
    FChecked := v;
    Invalidate;
    if Assigned(FOnChange) then FOnChange(Self);
  end;
end;

procedure TToggle.Paint;
var
  tx: Integer;
begin
  Canvas.Pen.Style := psClear;
  // pista
  if FChecked then Canvas.Brush.Color := TColor($30C030)
  else Canvas.Brush.Color := TColor($555555);
  Canvas.RoundRect(0, 0, Width, Height, Height, Height);
  // pulgar
  if FChecked then tx := Width - Height else tx := 0;
  Canvas.Brush.Color := TColor($F0F0F0);
  Canvas.Ellipse(tx + 2, 2, tx + Height - 2, Height - 2);
  Canvas.Pen.Style := psSolid;
end;

procedure TToggle.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button = mbLeft then
    SetChecked(not FChecked);
end;

end.
