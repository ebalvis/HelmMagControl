unit useg7;
{ TSeg7Display: display numerico de 7 segmentos dibujado a mano (Canvas).
  Reemplazo multiplataforma de JvSegmentedLEDDisplay (JVCL, solo Delphi).
  Funciona en cualquier widgetset de la LCL (win32/gtk/qt/cocoa) por usar
  solo Canvas. }
{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Types;

type
  TSeg7Display = class(TGraphicControl)
  private
    FText: string;
    FOnColor: TColor;
    FOffColor: TColor;
    FBackColor: TColor;
    procedure SetText(const AValue: string);
    procedure SetColors(Idx: Integer; AValue: TColor);
    procedure DrawDigit(ox, oy, w, h, t: Integer; c: Char);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Text: string read FText write SetText;
    property OnColor: TColor index 0 read FOnColor write SetColors;
    property OffColor: TColor index 1 read FOffColor write SetColors;
    property BackColor: TColor index 2 read FBackColor write SetColors;
    property Align;
    property Anchors;
  end;

implementation

constructor TSeg7Display.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOnColor := TColor($2030F0);   // rojo-naranja (BGR)
  FOffColor := TColor($202828);  // segmento apagado
  FBackColor := TColor($101010); // fondo oscuro
  FText := '00.00';
  Width := 150;
  Height := 56;
end;

procedure TSeg7Display.SetText(const AValue: string);
begin
  if FText <> AValue then
  begin
    FText := AValue;
    Invalidate;
  end;
end;

procedure TSeg7Display.SetColors(Idx: Integer; AValue: TColor);
begin
  case Idx of
    0: FOnColor := AValue;
    1: FOffColor := AValue;
    2: FBackColor := AValue;
  end;
  Invalidate;
end;

procedure TSeg7Display.DrawDigit(ox, oy, w, h, t: Integer; c: Char);
var
  seg: array [0 .. 6] of Boolean; // a,b,c,d,e,f,g
  ht, midY: Integer;

  procedure HSeg(idx, xL, xR, cy: Integer);
  var
    p: array [0 .. 5] of TPoint;
  begin
    p[0] := Point(xL, cy);
    p[1] := Point(xL + ht, cy - ht);
    p[2] := Point(xR - ht, cy - ht);
    p[3] := Point(xR, cy);
    p[4] := Point(xR - ht, cy + ht);
    p[5] := Point(xL + ht, cy + ht);
    if seg[idx] then Canvas.Brush.Color := FOnColor
    else Canvas.Brush.Color := FOffColor;
    Canvas.Polygon(p);
  end;

  procedure VSeg(idx, cx, yT, yB: Integer);
  var
    p: array [0 .. 5] of TPoint;
  begin
    p[0] := Point(cx, yT);
    p[1] := Point(cx + ht, yT + ht);
    p[2] := Point(cx + ht, yB - ht);
    p[3] := Point(cx, yB);
    p[4] := Point(cx - ht, yB - ht);
    p[5] := Point(cx - ht, yT + ht);
    if seg[idx] then Canvas.Brush.Color := FOnColor
    else Canvas.Brush.Color := FOffColor;
    Canvas.Polygon(p);
  end;

begin
  // a=0 b=1 c=2 d=3 e=4 f=5 g=6
  FillChar(seg, SizeOf(seg), 0);
  case c of
    '0': begin seg[0]:=True; seg[1]:=True; seg[2]:=True; seg[3]:=True; seg[4]:=True; seg[5]:=True; end;
    '1': begin seg[1]:=True; seg[2]:=True; end;
    '2': begin seg[0]:=True; seg[1]:=True; seg[6]:=True; seg[4]:=True; seg[3]:=True; end;
    '3': begin seg[0]:=True; seg[1]:=True; seg[6]:=True; seg[2]:=True; seg[3]:=True; end;
    '4': begin seg[5]:=True; seg[6]:=True; seg[1]:=True; seg[2]:=True; end;
    '5': begin seg[0]:=True; seg[5]:=True; seg[6]:=True; seg[2]:=True; seg[3]:=True; end;
    '6': begin seg[0]:=True; seg[5]:=True; seg[6]:=True; seg[4]:=True; seg[2]:=True; seg[3]:=True; end;
    '7': begin seg[0]:=True; seg[1]:=True; seg[2]:=True; end;
    '8': begin seg[0]:=True; seg[1]:=True; seg[2]:=True; seg[3]:=True; seg[4]:=True; seg[5]:=True; seg[6]:=True; end;
    '9': begin seg[0]:=True; seg[1]:=True; seg[2]:=True; seg[3]:=True; seg[5]:=True; seg[6]:=True; end;
    '-': seg[6]:=True;
  end;

  ht := t div 2;
  if ht < 1 then ht := 1;
  midY := oy + h div 2;
  Canvas.Pen.Style := psClear;

  HSeg(0, ox, ox + w, oy);          // a (arriba)
  HSeg(6, ox, ox + w, midY);        // g (medio)
  HSeg(3, ox, ox + w, oy + h);      // d (abajo)
  VSeg(5, ox, oy, midY);            // f (sup-izq)
  VSeg(1, ox + w, oy, midY);        // b (sup-der)
  VSeg(4, ox, midY, oy + h);        // e (inf-izq)
  VSeg(2, ox + w, midY, oy + h);    // c (inf-der)

  Canvas.Pen.Style := psSolid;
end;

procedure TSeg7Display.Paint;
var
  i, x, mtop, dh, dw, t, dotR: Integer;
  c: Char;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := FBackColor;
  Canvas.FillRect(ClientRect);

  mtop := Height div 8;
  dh := Height - 2 * mtop;
  dw := (dh * 6) div 10;
  t := dh div 7;
  if t < 2 then t := 2;
  dotR := t;
  x := t;

  for i := 1 to Length(FText) do
  begin
    c := FText[i];
    if (c = '.') or (c = ',') then
    begin
      Canvas.Brush.Color := FOnColor;
      Canvas.Pen.Style := psClear;
      Canvas.Ellipse(x, mtop + dh - 2 * dotR, x + 2 * dotR, mtop + dh);
      Canvas.Pen.Style := psSolid;
      Inc(x, 2 * dotR + t);
    end
    else
    begin
      DrawDigit(x, mtop, dw, dh, t, c);
      Inc(x, dw + t + t);
    end;
  end;
end;

end.
